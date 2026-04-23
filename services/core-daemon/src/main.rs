use git_domain::load_git_review_snapshot;
use provider_domain::{
    ClaudeRuntimeStatus, ClaudeTurnProofResult, CodexApprovalDecision, CodexApprovalRequest,
    CodexCommandExecControlRequest, CodexCommandExecOutputDelta, CodexCommandExecOutputStream,
    CodexCommandExecParams, CodexCommandExecResizeParams, CodexCommandExecResult,
    CodexCommandExecTerminalSize, CodexCommandExecTerminateParams, CodexCommandExecWriteParams,
    CodexRuntimeRegistry, CodexThreadBootstrap, exec_codex_command, read_codex_transcript,
    stream_codex_command, stream_codex_command_with_control, submit_codex_turn,
};
use serde::{Deserialize, Serialize};
use session_domain::{
    SessionSummary, load_persisted_session_projection, proof_session_id, reset_session_store,
    session_store_path, upsert_proof_session, upsert_runtime_session,
};
use std::cell::RefCell;
use std::env;
use std::fs;
use std::io::{self, BufRead, Write};
use std::os::fd::{AsRawFd, RawFd};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, Instant};

const COMMAND_EXEC_CONTROL_WAIT_TIMEOUT: Duration = Duration::from_secs(5);
const CLAUDE_TURN_PROOF_PROMPT: &str = "Reply with exactly OPENSLOP_CLAUDE_OK and nothing else.";
const CLAUDE_RECEIPT_PROMPT_MAX_BYTES: usize = 512;
const CLAUDE_RECEIPT_SESSION_ID: &str = "claude-turn-proof-latest";

static CODEX_RUNTIME_REGISTRY: LazyLock<Mutex<CodexRuntimeRegistry>> =
    LazyLock::new(|| Mutex::new(CodexRuntimeRegistry::new()));

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct StdioRequest {
    operation: Option<String>,
    query: Option<String>,
    session_id: Option<String>,
    input_text: Option<String>,
    approval_id: Option<String>,
    approval_decision: Option<String>,
    command: Option<Vec<String>>,
    cwd: Option<String>,
    process_id: Option<String>,
    stream_stdout_stderr: Option<bool>,
    tty: Option<bool>,
    cols: Option<u16>,
    rows: Option<u16>,
    delta_base64: Option<String>,
    close_stdin: Option<bool>,
    git_path: Option<String>,
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    kind: &'static str,
    message: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CodexTranscriptStreamEventResponse {
    kind: &'static str,
    session_id: String,
    snapshot: provider_domain::CodexTranscriptSnapshot,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CodexApprovalRequestEventResponse {
    kind: &'static str,
    session_id: String,
    approval: CodexApprovalRequest,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CodexCommandExecResultResponse {
    kind: &'static str,
    exit_code: i32,
    stdout: String,
    stderr: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CodexCommandExecOutputEventResponse {
    kind: &'static str,
    process_id: String,
    stream: CodexCommandExecOutputStream,
    delta_base64: String,
    cap_reached: bool,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CodexSessionBootstrapResponse {
    kind: String,
    session: SessionSummary,
    provider_thread_id: String,
    transport: String,
    cli_version: String,
    model: String,
    model_provider: String,
    approval_policy: String,
    sandbox_mode: String,
    reasoning_effort: Option<String>,
    instruction_sources: Vec<String>,
    initialize: provider_domain::CodexInitializeSummary,
    capabilities: provider_domain::CodexCapabilitySnapshot,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ClaudeProofSessionMaterializationResponse {
    kind: String,
    session: SessionSummary,
    proof: ClaudeTurnProofResult,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ClaudeReceiptSnapshotResponse {
    kind: String,
    session: SessionSummary,
    proof: ClaudeTurnProofResult,
    prompt_policy: ClaudeReceiptPromptPolicySnapshot,
    storage_path: String,
    lifecycle_boundary: String,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ClaudeReceiptPromptPolicySnapshot {
    max_bytes: usize,
    prompt_bytes: usize,
    bounded: bool,
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let repo_root = repo_root();

    if args.iter().any(|arg| arg == "--heartbeat") {
        println!(r#"{{"service":"core-daemon","status":"ok","scope":"bootstrap"}}"#);
        return;
    }

    if args.as_slice() == ["--query", "session-list"] {
        match session_list_json(&repo_root, true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.as_slice() == ["--start-codex-session"] {
        match codex_start_session_json(&repo_root, true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.as_slice() == ["--git-review-snapshot"] {
        match git_review_snapshot_json(&repo_root, None, true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.as_slice() == ["--claude-runtime-status"] {
        match claude_runtime_status_json(&repo_root, true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.as_slice() == ["--claude-turn-proof"] {
        match claude_turn_proof_json(&repo_root, CLAUDE_TURN_PROOF_PROMPT, true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.as_slice() == ["--claude-materialize-proof-session"] {
        match claude_materialize_proof_session_json(&repo_root, CLAUDE_TURN_PROOF_PROMPT, true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.as_slice() == ["--claude-receipt-snapshot"] {
        match claude_receipt_snapshot_json(&repo_root, None, true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.len() == 3 && args[0] == "--read-codex-transcript" {
        match codex_read_transcript_json(&repo_root, &args[1], true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.len() == 3 && args[0] == "--submit-codex-turn" {
        match codex_submit_turn_json(&repo_root, &args[1], &args[2], true) {
            Ok(payload) => println!("{payload}"),
            Err(error) => exit_with_error(error),
        }
        return;
    }

    if args.as_slice() == ["--serve-stdio"] {
        if let Err(error) = serve_stdio(&repo_root) {
            eprintln!("core-daemon stdio server failed: {error}");
            std::process::exit(1);
        }
        return;
    }

    if args.as_slice() == ["--reset-session-store"] {
        match reset_session_store(&repo_root) {
            Ok(()) => println!(
                "session store reset: {}",
                session_store_path(&repo_root).display()
            ),
            Err(error) => exit_with_error(error.to_string()),
        }
        return;
    }

    if args.as_slice() == ["--upsert-proof-session"] {
        match upsert_proof_session(&repo_root) {
            Ok(()) => println!("proof session persisted: {}", proof_session_id()),
            Err(error) => exit_with_error(error.to_string()),
        }
        return;
    }

    if args.as_slice() == ["--print-session-store-path"] {
        println!("{}", session_store_path(&repo_root).display());
        return;
    }

    eprintln!(
        "OpenSlop core-daemon supports: --heartbeat | --query session-list | --start-codex-session | --git-review-snapshot | --claude-runtime-status | --claude-turn-proof | --claude-materialize-proof-session | --claude-receipt-snapshot | --read-codex-transcript <session-id> _ | --submit-codex-turn <session-id> <input> | --serve-stdio | --reset-session-store | --upsert-proof-session | --print-session-store-path"
    );
}

fn repo_root() -> PathBuf {
    if let Ok(explicit) = env::var("OPEN_SLOP_REPO_ROOT") {
        if !explicit.is_empty() {
            return PathBuf::from(explicit);
        }
    }

    env::current_dir().expect("current dir should be available")
}

fn exit_with_error(message: String) -> ! {
    eprintln!("{message}");
    std::process::exit(1);
}

fn session_list_json(repo_root: &Path, pretty: bool) -> Result<String, String> {
    let projection =
        load_persisted_session_projection(repo_root).map_err(|error| error.to_string())?;
    if pretty {
        serde_json::to_string_pretty(&projection).map_err(|error| error.to_string())
    } else {
        serde_json::to_string(&projection).map_err(|error| error.to_string())
    }
}

fn git_review_snapshot_json(
    repo_root: &Path,
    focused_path: Option<&str>,
    pretty: bool,
) -> Result<String, String> {
    let snapshot = load_git_review_snapshot(repo_root, focused_path);
    serialize_payload(&snapshot, pretty)
}

fn claude_runtime_status_json(repo_root: &Path, pretty: bool) -> Result<String, String> {
    let status = load_claude_runtime_status(repo_root);
    serialize_payload(&status, pretty)
}

fn claude_turn_proof_json(
    repo_root: &Path,
    input_text: &str,
    pretty: bool,
) -> Result<String, String> {
    let bounded_prompt = bounded_claude_receipt_prompt(input_text)?;
    let proof = load_claude_turn_proof(repo_root, &bounded_prompt);
    serialize_payload(&proof, pretty)
}

fn claude_materialize_proof_session_json(
    repo_root: &Path,
    input_text: &str,
    pretty: bool,
) -> Result<String, String> {
    let bounded_prompt = bounded_claude_receipt_prompt(input_text)?;
    let proof = load_claude_turn_proof(repo_root, &bounded_prompt);
    let session = map_claude_proof_to_session(repo_root, &proof);
    upsert_runtime_session(repo_root, &session).map_err(|error| error.to_string())?;
    save_claude_receipt_snapshot(repo_root, &session, &proof)?;
    serialize_payload(
        &ClaudeProofSessionMaterializationResponse {
            kind: "claude_proof_session_materialized".to_string(),
            session,
            proof,
        },
        pretty,
    )
}

fn claude_receipt_snapshot_json(
    repo_root: &Path,
    session_id: Option<&str>,
    pretty: bool,
) -> Result<String, String> {
    let snapshot = load_claude_receipt_snapshot(repo_root)?;
    if let Some(session_id) = session_id {
        if session_id != snapshot.session.id {
            return Err(format!(
                "Claude receipt snapshot mismatch: requested={session_id} available={}",
                snapshot.session.id
            ));
        }
    }
    serialize_payload(&snapshot, pretty)
}

fn save_claude_receipt_snapshot(
    repo_root: &Path,
    session: &SessionSummary,
    proof: &ClaudeTurnProofResult,
) -> Result<(), String> {
    let snapshot = build_claude_receipt_snapshot(repo_root, session, proof);
    let path = claude_receipt_snapshot_path(repo_root);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let payload = serde_json::to_string_pretty(&snapshot).map_err(|error| error.to_string())?;
    fs::write(&path, payload).map_err(|error| error.to_string())
}

fn load_claude_receipt_snapshot(repo_root: &Path) -> Result<ClaudeReceiptSnapshotResponse, String> {
    let path = claude_receipt_snapshot_path(repo_root);
    let payload = fs::read_to_string(&path)
        .map_err(|error| format!("Claude receipt snapshot unavailable: {error}"))?;
    serde_json::from_str(&payload)
        .map_err(|error| format!("Claude receipt snapshot invalid: {error}"))
}

fn build_claude_receipt_snapshot(
    repo_root: &Path,
    session: &SessionSummary,
    proof: &ClaudeTurnProofResult,
) -> ClaudeReceiptSnapshotResponse {
    ClaudeReceiptSnapshotResponse {
        kind: "claude_receipt_snapshot".to_string(),
        session: session.clone(),
        proof: proof.clone(),
        prompt_policy: ClaudeReceiptPromptPolicySnapshot {
            max_bytes: CLAUDE_RECEIPT_PROMPT_MAX_BYTES,
            prompt_bytes: proof.prompt_bytes,
            bounded: proof.prompt_bytes <= CLAUDE_RECEIPT_PROMPT_MAX_BYTES,
        },
        storage_path: claude_receipt_snapshot_path(repo_root)
            .display()
            .to_string(),
        lifecycle_boundary:
            "read-only latest receipt; no Claude dialog, resume, approvals, tools or tracing"
                .to_string(),
    }
}

fn claude_receipt_snapshot_path(repo_root: &Path) -> PathBuf {
    repo_root.join(".openslop/state/claude-receipt-latest.json")
}

fn bounded_claude_receipt_prompt(input_text: &str) -> Result<String, String> {
    let trimmed = input_text.trim();

    if trimmed.is_empty() {
        return Err("missing Claude receipt prompt".to_string());
    }

    let byte_count = trimmed.as_bytes().len();
    if byte_count > CLAUDE_RECEIPT_PROMPT_MAX_BYTES {
        return Err(format!(
            "Claude receipt prompt too large: {byte_count}/{CLAUDE_RECEIPT_PROMPT_MAX_BYTES} bytes"
        ));
    }

    Ok(trimmed.to_string())
}

fn claude_bridge_script(repo_root: &Path) -> PathBuf {
    repo_root.join("services/claude-bridge/bin/claude-bridge.mjs")
}

fn load_claude_runtime_status(repo_root: &Path) -> ClaudeRuntimeStatus {
    let bridge_script = claude_bridge_script(repo_root);
    if !bridge_script.is_file() {
        return ClaudeRuntimeStatus::unavailable(format!(
            "claude-bridge script missing: {}",
            bridge_script.display()
        ));
    }

    let output = Command::new("node")
        .arg(&bridge_script)
        .args(["status", "--json"])
        .current_dir(repo_root)
        .output();

    let output = match output {
        Ok(output) => output,
        Err(error) => {
            return ClaudeRuntimeStatus::unavailable(format!(
                "failed to launch claude-bridge via node: {error}"
            ));
        }
    };

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();

    if stdout.is_empty() {
        let reason = if stderr.is_empty() {
            format!(
                "claude-bridge exited without JSON, status={}",
                output.status
            )
        } else {
            format!(
                "claude-bridge exited without JSON, status={}, stderr={stderr}",
                output.status
            )
        };
        return ClaudeRuntimeStatus::unavailable(reason);
    }

    match ClaudeRuntimeStatus::from_bridge_json(&stdout) {
        Ok(status) if output.status.success() => status,
        Ok(status) => ClaudeRuntimeStatus::unavailable(format!(
            "claude-bridge exited non-zero: {}; bridge available={}; warnings={}",
            output.status,
            status.available,
            status.warnings.join("; ")
        )),
        Err(error) => ClaudeRuntimeStatus::unavailable(format!(
            "claude-bridge returned invalid runtime JSON: {error}; stdout={stdout}"
        )),
    }
}

fn load_claude_turn_proof(repo_root: &Path, input_text: &str) -> ClaudeTurnProofResult {
    let bridge_script = claude_bridge_script(repo_root);
    if !bridge_script.is_file() {
        return ClaudeTurnProofResult::unavailable(format!(
            "claude-bridge script missing: {}",
            bridge_script.display()
        ));
    }

    if input_text.trim().is_empty() {
        return ClaudeTurnProofResult::unavailable("missing Claude turn proof prompt");
    }

    let mut child = match Command::new("node")
        .arg(&bridge_script)
        .args(["turn-proof", "--json"])
        .current_dir(repo_root)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => child,
        Err(error) => {
            return ClaudeTurnProofResult::unavailable(format!(
                "failed to launch claude turn proof via node: {error}"
            ));
        }
    };

    match child.stdin.as_mut() {
        Some(stdin) => {
            if let Err(error) = stdin.write_all(input_text.as_bytes()) {
                return ClaudeTurnProofResult::unavailable(format!(
                    "failed to write Claude proof prompt to bridge stdin: {error}"
                ));
            }
        }
        None => {
            return ClaudeTurnProofResult::unavailable("claude-bridge stdin unavailable");
        }
    }

    let output = match child.wait_with_output() {
        Ok(output) => output,
        Err(error) => {
            return ClaudeTurnProofResult::unavailable(format!(
                "failed to wait for claude turn proof: {error}"
            ));
        }
    };

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();

    if stdout.is_empty() {
        let reason = if stderr.is_empty() {
            format!(
                "claude turn proof exited without JSON, status={}",
                output.status
            )
        } else {
            format!(
                "claude turn proof exited without JSON, status={}, stderr={stderr}",
                output.status
            )
        };
        return ClaudeTurnProofResult::unavailable(reason);
    }

    match ClaudeTurnProofResult::from_bridge_json(&stdout) {
        Ok(proof) if output.status.success() => proof,
        Ok(proof) => {
            proof.with_warning(format!("claude turn proof exit status: {}", output.status))
        }
        Err(error) => ClaudeTurnProofResult::unavailable(format!(
            "claude-bridge returned invalid turn proof JSON: {error}; stdout={stdout}"
        )),
    }
}

fn codex_start_session_json(repo_root: &Path, pretty: bool) -> Result<String, String> {
    let bootstrap = with_codex_runtime_registry(|runtime| runtime.start_session(repo_root))?;
    let session = map_bootstrap_to_session(repo_root, &bootstrap);
    upsert_runtime_session(repo_root, &session).map_err(|error| error.to_string())?;

    let response = CodexSessionBootstrapResponse {
        kind: "codex_session_bootstrap".to_string(),
        session,
        provider_thread_id: bootstrap.thread_id,
        transport: bootstrap.transport,
        cli_version: bootstrap.cli_version,
        model: bootstrap.model,
        model_provider: bootstrap.model_provider,
        approval_policy: bootstrap.approval_policy,
        sandbox_mode: bootstrap.sandbox_mode,
        reasoning_effort: bootstrap.reasoning_effort,
        instruction_sources: bootstrap.instruction_sources,
        initialize: bootstrap.initialize,
        capabilities: bootstrap.capabilities,
    };

    if pretty {
        serde_json::to_string_pretty(&response).map_err(|error| error.to_string())
    } else {
        serde_json::to_string(&response).map_err(|error| error.to_string())
    }
}

fn codex_read_transcript_json(
    repo_root: &Path,
    session_id: &str,
    pretty: bool,
) -> Result<String, String> {
    let transcript = with_codex_runtime_registry(|runtime| {
        if runtime.has_loaded_session(session_id) {
            runtime.read_transcript(repo_root, session_id)
        } else {
            read_codex_transcript(repo_root, session_id)
        }
    })?;
    let session = map_transcript_to_session(repo_root, session_id, &transcript);
    upsert_runtime_session(repo_root, &session).map_err(|error| error.to_string())?;
    serialize_payload(&transcript, pretty)
}

fn codex_submit_turn_json(
    repo_root: &Path,
    session_id: &str,
    input_text: &str,
    pretty: bool,
) -> Result<String, String> {
    let transcript = with_codex_runtime_registry(|runtime| {
        if runtime.has_loaded_session(session_id) {
            runtime.submit_turn(repo_root, session_id, input_text)
        } else {
            submit_codex_turn(repo_root, session_id, input_text)
        }
    })?;
    let session = map_transcript_to_session(repo_root, session_id, &transcript);
    upsert_runtime_session(repo_root, &session).map_err(|error| error.to_string())?;
    serialize_payload(&transcript, pretty)
}

fn codex_submit_turn_stream_json(
    repo_root: &Path,
    session_id: &str,
    input_text: &str,
    pretty: bool,
    reader: &mut impl BufRead,
    writer: &mut impl Write,
) -> Result<String, String> {
    let mut registry = CODEX_RUNTIME_REGISTRY
        .lock()
        .map_err(|_| "codex runtime registry lock poisoned".to_string())?;
    let bridge = RefCell::new(CodexTurnStreamBridge {
        reader,
        writer,
        session_id: session_id.to_string(),
    });

    let transcript = registry
        .stream_turn_with_approvals(
            repo_root,
            session_id,
            input_text,
            |snapshot| bridge.borrow_mut().emit_snapshot(snapshot),
            |approval| bridge.borrow_mut().wait_for_approval(&approval),
        )
        .map_err(|error| error.to_string())?;

    let session = map_transcript_to_session(repo_root, session_id, &transcript);
    upsert_runtime_session(repo_root, &session).map_err(|error| error.to_string())?;
    serialize_payload(&transcript, pretty)
}

fn codex_command_exec_json(
    repo_root: &Path,
    params: &CodexCommandExecParams,
    pretty: bool,
) -> Result<String, String> {
    let result = exec_codex_command(repo_root, params).map_err(|error| error.to_string())?;
    serialize_payload(&map_command_exec_result(result), pretty)
}

fn codex_command_exec_stream_json(
    repo_root: &Path,
    params: &CodexCommandExecParams,
    pretty: bool,
    writer: &mut impl Write,
) -> Result<String, String> {
    let bridge = RefCell::new(CodexCommandExecStreamBridge { writer });
    let result = stream_codex_command(repo_root, params, |delta| {
        bridge.borrow_mut().emit_output(delta)
    })
    .map_err(|error| error.to_string())?;
    serialize_payload(&map_command_exec_result(result), pretty)
}

fn codex_command_exec_control_stream_json(
    repo_root: &Path,
    params: &CodexCommandExecParams,
    pretty: bool,
    stdin_fd: RawFd,
    reader: &mut io::BufReader<impl io::Read>,
    writer: &mut impl Write,
) -> Result<String, String> {
    let bridge = RefCell::new(CodexCommandExecControlBridge {
        reader,
        writer,
        stdin_fd,
        process_id: params
            .process_id
            .clone()
            .ok_or_else(|| "missing processId".to_string())?,
        awaiting_followup_control: true,
    });
    let result = stream_codex_command_with_control(repo_root, params, |delta| {
        bridge.borrow_mut().emit_output_and_wait_for_control(delta)
    })
    .map_err(|error| error.to_string())?;
    serialize_payload(&map_command_exec_result(result), pretty)
}

struct CodexTurnStreamBridge<'a, R: BufRead, W: Write> {
    reader: &'a mut R,
    writer: &'a mut W,
    session_id: String,
}

impl<R: BufRead, W: Write> CodexTurnStreamBridge<'_, R, W> {
    fn emit_snapshot(
        &mut self,
        snapshot: provider_domain::CodexTranscriptSnapshot,
    ) -> Result<(), String> {
        let payload = serde_json::to_string(&CodexTranscriptStreamEventResponse {
            kind: "codex_transcript_stream_event",
            session_id: self.session_id.clone(),
            snapshot,
        })
        .map_err(|error| error.to_string())?;
        writeln!(self.writer, "{payload}").map_err(|error| error.to_string())?;
        self.writer.flush().map_err(|error| error.to_string())
    }

    fn wait_for_approval(
        &mut self,
        approval: &CodexApprovalRequest,
    ) -> Result<CodexApprovalDecision, String> {
        wait_for_approval_decision(self.reader, self.writer, &self.session_id, approval)
    }
}

struct CodexCommandExecStreamBridge<'a, W: Write> {
    writer: &'a mut W,
}

impl<W: Write> CodexCommandExecStreamBridge<'_, W> {
    fn emit_output(&mut self, delta: CodexCommandExecOutputDelta) -> Result<(), String> {
        let payload = serde_json::to_string(&CodexCommandExecOutputEventResponse {
            kind: "codex_command_exec_output_event",
            process_id: delta.process_id,
            stream: delta.stream,
            delta_base64: delta.delta_base64,
            cap_reached: delta.cap_reached,
        })
        .map_err(|error| error.to_string())?;
        writeln!(self.writer, "{payload}").map_err(|error| error.to_string())?;
        self.writer.flush().map_err(|error| error.to_string())
    }
}

struct CodexCommandExecControlBridge<'a, R: io::Read, W: Write> {
    reader: &'a mut io::BufReader<R>,
    writer: &'a mut W,
    stdin_fd: RawFd,
    process_id: String,
    awaiting_followup_control: bool,
}

impl<R: io::Read, W: Write> CodexCommandExecControlBridge<'_, R, W> {
    fn emit_output_and_wait_for_control(
        &mut self,
        delta: CodexCommandExecOutputDelta,
    ) -> Result<Option<CodexCommandExecControlRequest>, String> {
        let payload = serde_json::to_string(&CodexCommandExecOutputEventResponse {
            kind: "codex_command_exec_output_event",
            process_id: delta.process_id,
            stream: delta.stream,
            delta_base64: delta.delta_base64,
            cap_reached: delta.cap_reached,
        })
        .map_err(|error| error.to_string())?;
        writeln!(self.writer, "{payload}").map_err(|error| error.to_string())?;
        self.writer.flush().map_err(|error| error.to_string())?;

        if self.awaiting_followup_control {
            let control = wait_for_command_exec_control(
                self.reader,
                self.writer,
                self.stdin_fd,
                &self.process_id,
            )?;
            self.awaiting_followup_control = match &control {
                CodexCommandExecControlRequest::Write(params) => !params.close_stdin,
                CodexCommandExecControlRequest::Resize(_) => true,
                CodexCommandExecControlRequest::Terminate(_) => false,
            };
            return Ok(Some(control));
        }

        Ok(None)
    }
}

fn wait_for_approval_decision(
    reader: &mut impl BufRead,
    writer: &mut impl Write,
    session_id: &str,
    approval: &CodexApprovalRequest,
) -> Result<CodexApprovalDecision, String> {
    let payload = serde_json::to_string(&CodexApprovalRequestEventResponse {
        kind: "codex_approval_request",
        session_id: session_id.to_string(),
        approval: approval.clone(),
    })
    .map_err(|error| error.to_string())?;
    writeln!(writer, "{payload}").map_err(|error| error.to_string())?;
    writer.flush().map_err(|error| error.to_string())?;

    loop {
        let Some(request) =
            read_next_stdio_request(reader, writer).map_err(|error| error.to_string())?
        else {
            return Err("stdio closed while waiting for approval decision".to_string());
        };

        let operation = request
            .operation
            .as_deref()
            .or(request.query.as_deref())
            .unwrap_or_default()
            .to_string();
        if operation != "codex-resolve-approval" {
            writeln!(
                writer,
                "{}",
                serialize_error(format!(
                    "unsupported operation while waiting for approval: {operation}"
                ))
            )
            .map_err(|error| error.to_string())?;
            writer.flush().map_err(|error| error.to_string())?;
            continue;
        }

        if request.session_id.as_deref() != Some(session_id) {
            writeln!(
                writer,
                "{}",
                serialize_error("approval sessionId does not match active turn".to_string())
            )
            .map_err(|error| error.to_string())?;
            writer.flush().map_err(|error| error.to_string())?;
            continue;
        }

        if request.approval_id.as_deref() != Some(approval.approval_id.as_str()) {
            writeln!(
                writer,
                "{}",
                serialize_error("approvalId does not match active approval".to_string())
            )
            .map_err(|error| error.to_string())?;
            writer.flush().map_err(|error| error.to_string())?;
            continue;
        }

        match request.approval_decision.as_deref() {
            Some("accept") => return Ok(CodexApprovalDecision::Accept),
            Some("cancel") => return Ok(CodexApprovalDecision::Cancel),
            Some(other) => {
                writeln!(
                    writer,
                    "{}",
                    serialize_error(format!("unsupported approvalDecision: {other}"))
                )
                .map_err(|error| error.to_string())?;
                writer.flush().map_err(|error| error.to_string())?;
            }
            None => {
                writeln!(
                    writer,
                    "{}",
                    serialize_error("missing approvalDecision".to_string())
                )
                .map_err(|error| error.to_string())?;
                writer.flush().map_err(|error| error.to_string())?;
            }
        }
    }
}

fn wait_for_command_exec_control(
    reader: &mut io::BufReader<impl io::Read>,
    writer: &mut impl Write,
    stdin_fd: RawFd,
    process_id: &str,
) -> Result<CodexCommandExecControlRequest, String> {
    loop {
        let Some(request) = read_next_stdio_request_with_timeout(
            reader,
            writer,
            stdin_fd,
            COMMAND_EXEC_CONTROL_WAIT_TIMEOUT,
            "command/exec control follow-up",
        )
        .map_err(map_command_exec_control_wait_error)?
        else {
            return Err("stdio closed while waiting for command/exec control".to_string());
        };

        let operation = request
            .operation
            .as_deref()
            .or(request.query.as_deref())
            .unwrap_or_default()
            .to_string();
        if operation != "codex-command-exec-write"
            && operation != "codex-command-exec-resize"
            && operation != "codex-command-exec-terminate"
        {
            writeln!(
                writer,
                "{}",
                serialize_error(format!(
                    "unsupported operation while waiting for command/exec control: {operation}"
                ))
            )
            .map_err(|error| error.to_string())?;
            writer.flush().map_err(|error| error.to_string())?;
            continue;
        }

        if request.process_id.as_deref() != Some(process_id) {
            let message = match operation.as_str() {
                "codex-command-exec-write" => {
                    "write processId does not match active command/exec".to_string()
                }
                "codex-command-exec-resize" => {
                    "resize processId does not match active command/exec".to_string()
                }
                _ => "terminate processId does not match active command/exec".to_string(),
            };
            writeln!(writer, "{}", serialize_error(message)).map_err(|error| error.to_string())?;
            writer.flush().map_err(|error| error.to_string())?;
            continue;
        }

        if operation == "codex-command-exec-write" {
            return Ok(CodexCommandExecControlRequest::Write(
                CodexCommandExecWriteParams {
                    process_id: process_id.to_string(),
                    delta_base64: request.delta_base64,
                    close_stdin: request.close_stdin.unwrap_or(false),
                },
            ));
        }

        if operation == "codex-command-exec-resize" {
            return Ok(CodexCommandExecControlRequest::Resize(
                build_command_exec_resize_params(&request)?,
            ));
        }

        return Ok(CodexCommandExecControlRequest::Terminate(
            CodexCommandExecTerminateParams {
                process_id: process_id.to_string(),
            },
        ));
    }
}

fn serialize_payload<T: Serialize>(payload: &T, pretty: bool) -> Result<String, String> {
    if pretty {
        serde_json::to_string_pretty(payload).map_err(|error| error.to_string())
    } else {
        serde_json::to_string(payload).map_err(|error| error.to_string())
    }
}

fn map_command_exec_result(result: CodexCommandExecResult) -> CodexCommandExecResultResponse {
    CodexCommandExecResultResponse {
        kind: "codex_command_exec_result",
        exit_code: result.exit_code,
        stdout: result.stdout,
        stderr: result.stderr,
    }
}

fn build_command_exec_params(request: &StdioRequest) -> Result<CodexCommandExecParams, String> {
    let command = request
        .command
        .clone()
        .ok_or_else(|| "missing command".to_string())?;
    let size = build_command_exec_terminal_size(request)?;

    Ok(CodexCommandExecParams {
        command,
        cwd: request.cwd.clone(),
        process_id: request.process_id.clone(),
        stream_stdout_stderr: request.stream_stdout_stderr.unwrap_or(false),
        stream_stdin: false,
        tty: request.tty.unwrap_or(false),
        size,
    })
}

fn build_command_exec_control_params(
    request: &StdioRequest,
) -> Result<CodexCommandExecParams, String> {
    let mut params = build_command_exec_params(request)?;
    params.stream_stdout_stderr = true;
    params.stream_stdin = true;
    Ok(params)
}

fn build_command_exec_terminal_size(
    request: &StdioRequest,
) -> Result<Option<CodexCommandExecTerminalSize>, String> {
    match (request.cols, request.rows) {
        (Some(cols), Some(rows)) => Ok(Some(CodexCommandExecTerminalSize { cols, rows })),
        (None, None) => Ok(None),
        _ => Err("command/exec size requires both cols and rows".to_string()),
    }
}

fn build_command_exec_resize_params(
    request: &StdioRequest,
) -> Result<CodexCommandExecResizeParams, String> {
    let process_id = request
        .process_id
        .clone()
        .ok_or_else(|| "missing processId".to_string())?;
    let size = build_command_exec_terminal_size(request)?
        .ok_or_else(|| "missing command/exec resize size".to_string())?;

    Ok(CodexCommandExecResizeParams { process_id, size })
}

fn map_bootstrap_to_session(repo_root: &Path, bootstrap: &CodexThreadBootstrap) -> SessionSummary {
    SessionSummary {
        id: bootstrap.thread_id.clone(),
        title: format!("Codex thread {}", short_thread_id(&bootstrap.thread_id)),
        workspace: workspace_name(repo_root),
        branch: current_branch(repo_root),
        provider: "Codex".to_string(),
        status: "needs_first_turn".to_string(),
    }
}

fn map_transcript_to_session(
    repo_root: &Path,
    session_id: &str,
    transcript: &provider_domain::CodexTranscriptSnapshot,
) -> SessionSummary {
    SessionSummary {
        id: session_id.to_string(),
        title: transcript_title(session_id, transcript),
        workspace: workspace_name(repo_root),
        branch: current_branch(repo_root),
        provider: "Codex".to_string(),
        status: transcript.thread_status.clone(),
    }
}

fn map_claude_proof_to_session(repo_root: &Path, proof: &ClaudeTurnProofResult) -> SessionSummary {
    let title = if proof.success {
        let result = proof.result_text.trim();
        if result.is_empty() {
            "Claude receipt proven".to_string()
        } else {
            format!("Claude receipt: {}", short_text(result, 48))
        }
    } else {
        "Claude receipt failed".to_string()
    };

    SessionSummary {
        id: CLAUDE_RECEIPT_SESSION_ID.to_string(),
        title,
        workspace: workspace_name(repo_root),
        branch: current_branch(repo_root),
        provider: "Claude".to_string(),
        status: if proof.success {
            "receipt_proven".to_string()
        } else {
            "receipt_failed".to_string()
        },
    }
}

fn transcript_title(
    session_id: &str,
    transcript: &provider_domain::CodexTranscriptSnapshot,
) -> String {
    if !transcript.preview.trim().is_empty() {
        return transcript.preview.trim().to_string();
    }
    format!("Codex thread {}", short_thread_id(session_id))
}

fn workspace_name(repo_root: &Path) -> String {
    repo_root
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or("workspace")
        .to_string()
}

fn short_thread_id(thread_id: &str) -> &str {
    let boundary = thread_id
        .char_indices()
        .nth(8)
        .map(|(idx, _)| idx)
        .unwrap_or(thread_id.len());
    &thread_id[..boundary]
}

fn short_text(value: &str, max_chars: usize) -> String {
    if value.chars().count() <= max_chars {
        return value.to_string();
    }

    let mut output = value.chars().take(max_chars).collect::<String>();
    output.push('…');
    output
}

fn current_branch(repo_root: &Path) -> String {
    let output = Command::new("git")
        .arg("-C")
        .arg(repo_root)
        .args(["branch", "--show-current"])
        .output();

    match output {
        Ok(output) if output.status.success() => {
            let branch = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if branch.is_empty() {
                "unknown".to_string()
            } else {
                branch
            }
        }
        _ => "unknown".to_string(),
    }
}

fn with_codex_runtime_registry<T>(
    action: impl FnOnce(&mut CodexRuntimeRegistry) -> Result<T, provider_domain::CodexRuntimeError>,
) -> Result<T, String> {
    let mut registry = CODEX_RUNTIME_REGISTRY
        .lock()
        .map_err(|_| "codex runtime registry lock poisoned".to_string())?;
    action(&mut registry).map_err(|error| error.to_string())
}

fn serve_stdio(repo_root: &Path) -> io::Result<()> {
    let stdin = io::stdin();
    let stdin_fd = stdin.as_raw_fd();
    let stdout = io::stdout();
    let mut reader = io::BufReader::new(stdin.lock());
    let mut writer = io::BufWriter::new(stdout.lock());

    while let Some(request) = read_next_stdio_request(&mut reader, &mut writer)? {
        if handle_streaming_stdio_request(&request, repo_root, stdin_fd, &mut reader, &mut writer)?
        {
            continue;
        }

        let response = handle_parsed_stdio_request(request, repo_root);
        writeln!(writer, "{response}")?;
        writer.flush()?;
    }

    Ok(())
}

#[cfg(test)]
fn handle_stdio_request(line: &str, repo_root: &Path) -> String {
    let request = match serde_json::from_str::<StdioRequest>(line) {
        Ok(request) => request,
        Err(error) => return serialize_error(format!("invalid request: {error}")),
    };
    handle_parsed_stdio_request(request, repo_root)
}

fn handle_parsed_stdio_request(request: StdioRequest, repo_root: &Path) -> String {
    let operation = request
        .operation
        .as_deref()
        .or(request.query.as_deref())
        .unwrap_or_default();

    match operation {
        "session-list" => match session_list_json(repo_root, false) {
            Ok(payload) => payload,
            Err(message) => serialize_error(message),
        },
        "git-review-snapshot" => {
            match git_review_snapshot_json(repo_root, request.git_path.as_deref(), false) {
                Ok(payload) => payload,
                Err(message) => serialize_error(message),
            }
        }
        "claude-runtime-status" => match claude_runtime_status_json(repo_root, false) {
            Ok(payload) => payload,
            Err(message) => serialize_error(message),
        },
        "claude-turn-proof" => {
            let input_text = request
                .input_text
                .as_deref()
                .unwrap_or(CLAUDE_TURN_PROOF_PROMPT);
            match claude_turn_proof_json(repo_root, input_text, false) {
                Ok(payload) => payload,
                Err(message) => serialize_error(message),
            }
        }
        "claude-materialize-proof-session" => {
            let input_text = request
                .input_text
                .as_deref()
                .unwrap_or(CLAUDE_TURN_PROOF_PROMPT);
            match claude_materialize_proof_session_json(repo_root, input_text, false) {
                Ok(payload) => payload,
                Err(message) => serialize_error(message),
            }
        }
        "claude-receipt-snapshot" => {
            match claude_receipt_snapshot_json(repo_root, request.session_id.as_deref(), false) {
                Ok(payload) => payload,
                Err(message) => serialize_error(message),
            }
        }
        "codex-start-session" => match codex_start_session_json(repo_root, false) {
            Ok(payload) => payload,
            Err(message) => serialize_error(message),
        },
        "codex-read-transcript" => match request.session_id.as_deref() {
            Some(session_id) => match codex_read_transcript_json(repo_root, session_id, false) {
                Ok(payload) => payload,
                Err(message) => serialize_error(message),
            },
            None => serialize_error("missing sessionId".to_string()),
        },
        "codex-submit-turn" => match (request.session_id.as_deref(), request.input_text.as_deref())
        {
            (Some(session_id), Some(input_text)) => {
                match codex_submit_turn_json(repo_root, session_id, input_text, false) {
                    Ok(payload) => payload,
                    Err(message) => serialize_error(message),
                }
            }
            (None, _) => serialize_error("missing sessionId".to_string()),
            (_, None) => serialize_error("missing inputText".to_string()),
        },
        "codex-command-exec" => match build_command_exec_params(&request) {
            Ok(params) => match codex_command_exec_json(repo_root, &params, false) {
                Ok(payload) => payload,
                Err(message) => serialize_error(message),
            },
            Err(message) => serialize_error(message),
        },
        "codex-command-exec-write"
        | "codex-command-exec-resize"
        | "codex-command-exec-terminate" => serialize_error(format!(
            "{operation} is only supported inside codex-command-exec-control-stream"
        )),
        other => serialize_error(format!("unsupported operation: {other}")),
    }
}

fn handle_streaming_stdio_request(
    request: &StdioRequest,
    repo_root: &Path,
    stdin_fd: RawFd,
    reader: &mut io::BufReader<impl io::Read>,
    writer: &mut impl Write,
) -> io::Result<bool> {
    let operation = request
        .operation
        .clone()
        .or(request.query.clone())
        .unwrap_or_default();

    let response = match operation.as_str() {
        "codex-submit-turn-stream" => {
            match (request.session_id.as_deref(), request.input_text.as_deref()) {
                (Some(session_id), Some(input_text)) => {
                    match codex_submit_turn_stream_json(
                        repo_root, session_id, input_text, false, reader, writer,
                    ) {
                        Ok(payload) => payload,
                        Err(message) => serialize_error(message),
                    }
                }
                (None, _) => serialize_error("missing sessionId".to_string()),
                (_, None) => serialize_error("missing inputText".to_string()),
            }
        }
        "codex-command-exec-stream" => match build_command_exec_params(request) {
            Ok(params) => match codex_command_exec_stream_json(repo_root, &params, false, writer) {
                Ok(payload) => payload,
                Err(message) => serialize_error(message),
            },
            Err(message) => serialize_error(message),
        },
        "codex-command-exec-control-stream" => match build_command_exec_control_params(request) {
            Ok(params) => {
                match codex_command_exec_control_stream_json(
                    repo_root, &params, false, stdin_fd, reader, writer,
                ) {
                    Ok(payload) => payload,
                    Err(message) => serialize_error(message),
                }
            }
            Err(message) => serialize_error(message),
        },
        _ => return Ok(false),
    };

    writeln!(writer, "{response}")?;
    writer.flush()?;
    Ok(true)
}

fn read_next_stdio_request(
    reader: &mut impl BufRead,
    writer: &mut impl Write,
) -> io::Result<Option<StdioRequest>> {
    loop {
        let mut line = String::new();
        let bytes_read = reader.read_line(&mut line)?;
        if bytes_read == 0 {
            return Ok(None);
        }

        if line.trim().is_empty() {
            continue;
        }

        match serde_json::from_str::<StdioRequest>(&line) {
            Ok(request) => return Ok(Some(request)),
            Err(error) => {
                writeln!(
                    writer,
                    "{}",
                    serialize_error(format!("invalid request: {error}"))
                )?;
                writer.flush()?;
            }
        }
    }
}

fn read_next_stdio_request_with_timeout(
    reader: &mut io::BufReader<impl io::Read>,
    writer: &mut impl Write,
    stdin_fd: RawFd,
    timeout: Duration,
    wait_label: &str,
) -> io::Result<Option<StdioRequest>> {
    let started = Instant::now();

    loop {
        let remaining = timeout.saturating_sub(started.elapsed());
        if remaining.is_zero() {
            return Err(io::Error::new(
                io::ErrorKind::TimedOut,
                format!("timed out while waiting for {wait_label}"),
            ));
        }

        let Some(line) = read_next_stdio_line_with_timeout(reader, stdin_fd, remaining)? else {
            return Ok(None);
        };

        if line.trim().is_empty() {
            continue;
        }

        match serde_json::from_str::<StdioRequest>(&line) {
            Ok(request) => return Ok(Some(request)),
            Err(error) => {
                writeln!(
                    writer,
                    "{}",
                    serialize_error(format!("invalid request: {error}"))
                )?;
                writer.flush()?;
            }
        }
    }
}

fn read_next_stdio_line_with_timeout(
    reader: &mut io::BufReader<impl io::Read>,
    stdin_fd: RawFd,
    timeout: Duration,
) -> io::Result<Option<String>> {
    if stdin_fd >= 0 && reader.buffer().is_empty() {
        wait_for_stdio_input(stdin_fd, timeout)?;
    }

    let mut line = String::new();
    let bytes_read = reader.read_line(&mut line)?;
    if bytes_read == 0 {
        return Ok(None);
    }

    Ok(Some(line))
}

fn wait_for_stdio_input(stdin_fd: RawFd, timeout: Duration) -> io::Result<()> {
    let timeout_ms = timeout.as_millis().min(i32::MAX as u128) as i32;
    let mut poll_fd = libc::pollfd {
        fd: stdin_fd,
        events: libc::POLLIN,
        revents: 0,
    };

    let result = unsafe { libc::poll(&mut poll_fd, 1, timeout_ms) };
    if result == 0 {
        return Err(io::Error::new(
            io::ErrorKind::TimedOut,
            "stdio follow-up timed out",
        ));
    }

    if result < 0 {
        return Err(io::Error::last_os_error());
    }

    Ok(())
}

fn map_command_exec_control_wait_error(error: io::Error) -> String {
    if error.kind() == io::ErrorKind::TimedOut {
        return format!(
            "timed out while waiting for command/exec control after {}s; proof lane fails closed",
            COMMAND_EXEC_CONTROL_WAIT_TIMEOUT.as_secs()
        );
    }

    error.to_string()
}

fn serialize_error(message: String) -> String {
    serde_json::to_string(&ErrorResponse {
        kind: "error",
        message,
    })
    .expect("error response should serialize")
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn handles_session_list_request() {
        let temp = tempdir().expect("temp dir should exist");
        let response = handle_stdio_request(r#"{"query":"session-list"}"#, temp.path());
        assert!(response.contains("session_list"));
        assert!(response.contains("s02-event-spine"));
    }

    #[test]
    fn rejects_unknown_query() {
        let temp = tempdir().expect("temp dir should exist");
        let response = handle_stdio_request(r#"{"query":"unknown"}"#, temp.path());
        assert!(response.contains("\"kind\":\"error\""));
    }

    #[test]
    fn persisted_proof_session_survives_restart_boundary() {
        let temp = tempdir().expect("temp dir should exist");
        reset_session_store(temp.path()).expect("store should reset");
        upsert_proof_session(temp.path()).expect("proof session should persist");

        let response = handle_stdio_request(r#"{"operation":"session-list"}"#, temp.path());
        assert!(response.contains(proof_session_id()));
    }

    #[test]
    fn maps_bootstrap_to_runtime_session() {
        let temp = tempdir().expect("temp dir should exist");
        let bootstrap = CodexThreadBootstrap {
            kind: "codex_session_bootstrap".to_string(),
            transport: "stdio".to_string(),
            cli_version: "0.123.0".to_string(),
            initialize: provider_domain::CodexInitializeSummary {
                user_agent: "openslop/0.123.0".to_string(),
                codex_home: "/tmp/codex".to_string(),
                platform_family: "unix".to_string(),
                platform_os: "macos".to_string(),
                suppressed_notification_methods: vec!["thread/started".to_string()],
            },
            capabilities: provider_domain::CodexCapabilitySnapshot {
                initialize: true,
                thread_start: true,
                thread_resume: true,
                notification_suppression: true,
                turn_start: true,
                thread_read: true,
            },
            thread_id: "thread-abc12345".to_string(),
            cwd: temp.path().display().to_string(),
            model: "gpt-5.4".to_string(),
            model_provider: "openai_responses_only".to_string(),
            approval_policy: "never".to_string(),
            sandbox_mode: "dangerFullAccess".to_string(),
            reasoning_effort: Some("xhigh".to_string()),
            instruction_sources: vec![],
            thread_status: "idle".to_string(),
        };

        let session = map_bootstrap_to_session(temp.path(), &bootstrap);
        assert_eq!(session.id, bootstrap.thread_id);
        assert_eq!(session.provider, "Codex");
        assert_eq!(session.status, "needs_first_turn");
        assert!(session.title.contains("thread-a"));
    }

    #[test]
    fn maps_transcript_preview_to_session_title() {
        let temp = tempdir().expect("temp dir should exist");
        let transcript = provider_domain::CodexTranscriptSnapshot {
            kind: "codex_transcript_snapshot".to_string(),
            thread_id: "thread-abc12345".to_string(),
            preview: "Reply with exactly OK.".to_string(),
            thread_status: "idle".to_string(),
            turn_count: 1,
            last_turn_status: Some("completed".to_string()),
            items: vec![],
        };

        let session = map_transcript_to_session(temp.path(), &transcript.thread_id, &transcript);
        assert_eq!(session.title, "Reply with exactly OK.");
        assert_eq!(session.status, "idle");
    }

    #[test]
    fn maps_claude_proof_to_readonly_session_summary() {
        let temp = tempdir().expect("temp dir should exist");
        let proof = ClaudeTurnProofResult {
            kind: "claude_turn_proof_result".to_string(),
            runtime: "claude-code-cli".to_string(),
            success: true,
            runtime_available: true,
            bridge: provider_domain::ClaudeBridgeSummary {
                name: "claude-bridge".to_string(),
                version: "0.2.0".to_string(),
                transport: "stdio-json".to_string(),
            },
            model: Some("claude-haiku-4-5-20251001".to_string()),
            session_id: Some("claude-session".to_string()),
            result_text: "OPENSLOP_CLAUDE_OK".to_string(),
            assistant_text: "OPENSLOP_CLAUDE_OK".to_string(),
            event_count: 5,
            event_types: vec!["assistant".to_string(), "result:success".to_string()],
            tool_use_count: 0,
            malformed_event_count: 0,
            session_persistence: "disabled".to_string(),
            total_cost_usd: Some(0.001),
            duration_ms: Some(1000),
            exit_code: Some(0),
            signal: None,
            timed_out: false,
            prompt_bytes: 55,
            warnings: vec![],
        };

        let session = map_claude_proof_to_session(temp.path(), &proof);

        assert_eq!(session.id, "claude-turn-proof-latest");
        assert_eq!(session.provider, "Claude");
        assert_eq!(session.status, "receipt_proven");
        assert!(session.title.contains("OPENSLOP_CLAUDE_OK"));
    }

    #[test]
    fn stores_and_reads_claude_receipt_snapshot() {
        let temp = tempdir().expect("temp dir should exist");
        let proof = ClaudeTurnProofResult {
            kind: "claude_turn_proof_result".to_string(),
            runtime: "claude-code-cli".to_string(),
            success: true,
            runtime_available: true,
            bridge: provider_domain::ClaudeBridgeSummary {
                name: "claude-bridge".to_string(),
                version: "0.2.0".to_string(),
                transport: "stdio-json".to_string(),
            },
            model: Some("claude-haiku-4-5-20251001".to_string()),
            session_id: Some("claude-session".to_string()),
            result_text: "OPENSLOP_CLAUDE_DETAIL_OK".to_string(),
            assistant_text: "OPENSLOP_CLAUDE_DETAIL_OK".to_string(),
            event_count: 5,
            event_types: vec!["assistant".to_string(), "result:success".to_string()],
            tool_use_count: 0,
            malformed_event_count: 0,
            session_persistence: "disabled".to_string(),
            total_cost_usd: Some(0.001),
            duration_ms: Some(1000),
            exit_code: Some(0),
            signal: None,
            timed_out: false,
            prompt_bytes: 62,
            warnings: vec![],
        };
        let session = map_claude_proof_to_session(temp.path(), &proof);

        save_claude_receipt_snapshot(temp.path(), &session, &proof)
            .expect("snapshot should persist");
        let payload = claude_receipt_snapshot_json(temp.path(), Some(&session.id), false)
            .expect("snapshot should read");
        let snapshot: ClaudeReceiptSnapshotResponse =
            serde_json::from_str(&payload).expect("snapshot json should decode");

        assert_eq!(snapshot.kind, "claude_receipt_snapshot");
        assert_eq!(snapshot.session.id, CLAUDE_RECEIPT_SESSION_ID);
        assert_eq!(snapshot.proof.result_text, "OPENSLOP_CLAUDE_DETAIL_OK");
        assert_eq!(
            snapshot.prompt_policy.max_bytes,
            CLAUDE_RECEIPT_PROMPT_MAX_BYTES
        );
        assert_eq!(snapshot.prompt_policy.prompt_bytes, 62);
        assert!(snapshot.prompt_policy.bounded);
        assert!(
            snapshot
                .lifecycle_boundary
                .contains("read-only latest receipt")
        );
    }

    #[test]
    fn rejects_claude_receipt_snapshot_session_mismatch() {
        let temp = tempdir().expect("temp dir should exist");
        let proof = ClaudeTurnProofResult::unavailable("synthetic failed proof");
        let session = map_claude_proof_to_session(temp.path(), &proof);

        save_claude_receipt_snapshot(temp.path(), &session, &proof)
            .expect("snapshot should persist");
        let response = handle_stdio_request(
            r#"{"operation":"claude-receipt-snapshot","sessionId":"wrong-session"}"#,
            temp.path(),
        );

        assert!(response.contains("\"kind\":\"error\""));
        assert!(response.contains("Claude receipt snapshot mismatch"));
    }

    #[test]
    fn rejects_empty_claude_receipt_prompt_before_bridge() {
        let temp = tempdir().expect("temp dir should exist");
        let response = handle_stdio_request(
            r#"{"operation":"claude-materialize-proof-session","inputText":"   "}"#,
            temp.path(),
        );

        assert!(response.contains("\"kind\":\"error\""));
        assert!(response.contains("missing Claude receipt prompt"));
    }

    #[test]
    fn rejects_oversized_claude_receipt_prompt_before_bridge() {
        let temp = tempdir().expect("temp dir should exist");
        let too_large = "x".repeat(CLAUDE_RECEIPT_PROMPT_MAX_BYTES + 1);
        let request = serde_json::json!({
            "operation": "claude-materialize-proof-session",
            "inputText": too_large,
        });
        let response = handle_stdio_request(&request.to_string(), temp.path());

        assert!(response.contains("\"kind\":\"error\""));
        assert!(response.contains("Claude receipt prompt too large"));
        assert!(response.contains("513/512 bytes"));
    }

    #[test]
    fn rejects_command_exec_without_command() {
        let temp = tempdir().expect("temp dir should exist");
        let response = handle_stdio_request(r#"{"operation":"codex-command-exec"}"#, temp.path());
        assert!(response.contains("\"kind\":\"error\""));
        assert!(response.contains("missing command"));
    }

    #[test]
    fn rejects_streaming_command_exec_without_process_id() {
        let temp = tempdir().expect("temp dir should exist");
        let request = StdioRequest {
            operation: Some("codex-command-exec-stream".to_string()),
            query: None,
            session_id: None,
            input_text: None,
            approval_id: None,
            approval_decision: None,
            command: Some(vec!["printf-streamed".to_string()]),
            cwd: None,
            process_id: None,
            stream_stdout_stderr: Some(true),
            tty: None,
            cols: None,
            rows: None,
            delta_base64: None,
            close_stdin: None,
            git_path: None,
        };
        let mut reader = io::BufReader::new(io::Cursor::new(Vec::<u8>::new()));
        let mut writer = Vec::<u8>::new();

        let handled =
            handle_streaming_stdio_request(&request, temp.path(), -1, &mut reader, &mut writer)
                .expect("stream request should return error payload");

        assert!(handled);
        let text = String::from_utf8(writer).expect("writer should be utf8");
        assert!(text.contains("\"kind\":\"error\""));
        assert!(text.contains("processId"));
    }

    #[test]
    fn rejects_standalone_command_exec_write_operation() {
        let temp = tempdir().expect("temp dir should exist");
        let response = handle_stdio_request(
            r#"{"operation":"codex-command-exec-write","processId":"proc-1","deltaBase64":"UElORwo="}"#,
            temp.path(),
        );
        assert!(response.contains("\"kind\":\"error\""));
        assert!(response.contains("only supported inside codex-command-exec-control-stream"));
    }

    #[test]
    fn rejects_standalone_command_exec_terminate_operation() {
        let temp = tempdir().expect("temp dir should exist");
        let response = handle_stdio_request(
            r#"{"operation":"codex-command-exec-terminate","processId":"proc-1"}"#,
            temp.path(),
        );
        assert!(response.contains("\"kind\":\"error\""));
        assert!(response.contains("only supported inside codex-command-exec-control-stream"));
    }

    #[test]
    fn rejects_standalone_command_exec_resize_operation() {
        let temp = tempdir().expect("temp dir should exist");
        let response = handle_stdio_request(
            r#"{"operation":"codex-command-exec-resize","processId":"proc-1","cols":100,"rows":40}"#,
            temp.path(),
        );
        assert!(response.contains("\"kind\":\"error\""));
        assert!(response.contains("only supported inside codex-command-exec-control-stream"));
    }

    #[test]
    fn command_exec_control_accepts_close_stdin_write() {
        let mut reader = io::BufReader::new(io::Cursor::new(
            br#"{"operation":"codex-command-exec-write","processId":"proc-1","closeStdin":true}
"#
            .to_vec(),
        ));
        let mut writer = Vec::<u8>::new();

        let control = wait_for_command_exec_control(&mut reader, &mut writer, -1, "proc-1")
            .expect("close stdin write should succeed");

        let text = String::from_utf8(writer).expect("writer should be utf8");
        assert!(text.is_empty());
        match control {
            CodexCommandExecControlRequest::Write(params) => {
                assert_eq!(params.process_id, "proc-1");
                assert_eq!(params.delta_base64, None);
                assert!(params.close_stdin);
            }
            other => panic!("expected write control, got {other:?}"),
        }
    }

    #[test]
    fn command_exec_write_rejects_wrong_process_id_and_keeps_waiting() {
        let mut reader = io::BufReader::new(io::Cursor::new(
            br#"{"operation":"codex-command-exec-write","processId":"wrong-proc","deltaBase64":"UElORwo="}
{"operation":"codex-command-exec-write","processId":"proc-1","deltaBase64":"UElORwo="}
"#
            .to_vec(),
        ));
        let mut writer = Vec::<u8>::new();

        let control = wait_for_command_exec_control(&mut reader, &mut writer, -1, "proc-1")
            .expect("write should recover");

        let text = String::from_utf8(writer).expect("writer should be utf8");
        assert!(text.contains("write processId does not match active command/exec"));
        match control {
            CodexCommandExecControlRequest::Write(params) => {
                assert_eq!(params.process_id, "proc-1");
                assert_eq!(params.delta_base64.as_deref(), Some("UElORwo="));
                assert!(!params.close_stdin);
            }
            other => panic!("expected write control, got {other:?}"),
        }
    }

    #[test]
    fn command_exec_control_accepts_resize() {
        let mut reader = io::BufReader::new(io::Cursor::new(
            br#"{"operation":"codex-command-exec-resize","processId":"proc-1","cols":100,"rows":40}
"#
            .to_vec(),
        ));
        let mut writer = Vec::<u8>::new();

        let control = wait_for_command_exec_control(&mut reader, &mut writer, -1, "proc-1")
            .expect("resize should succeed");

        let text = String::from_utf8(writer).expect("writer should be utf8");
        assert!(text.is_empty());
        match control {
            CodexCommandExecControlRequest::Resize(params) => {
                assert_eq!(params.process_id, "proc-1");
                assert_eq!(params.size.cols, 100);
                assert_eq!(params.size.rows, 40);
            }
            other => panic!("expected resize control, got {other:?}"),
        }
    }

    #[test]
    fn command_exec_resize_rejects_wrong_process_id_and_keeps_waiting() {
        let mut reader = io::BufReader::new(io::Cursor::new(
            br#"{"operation":"codex-command-exec-resize","processId":"wrong-proc","cols":100,"rows":40}
{"operation":"codex-command-exec-resize","processId":"proc-1","cols":100,"rows":40}
"#
            .to_vec(),
        ));
        let mut writer = Vec::<u8>::new();

        let control = wait_for_command_exec_control(&mut reader, &mut writer, -1, "proc-1")
            .expect("resize should recover");

        let text = String::from_utf8(writer).expect("writer should be utf8");
        assert!(text.contains("resize processId does not match active command/exec"));
        match control {
            CodexCommandExecControlRequest::Resize(params) => {
                assert_eq!(params.process_id, "proc-1");
                assert_eq!(params.size.cols, 100);
                assert_eq!(params.size.rows, 40);
            }
            other => panic!("expected resize control, got {other:?}"),
        }
    }

    #[test]
    fn command_exec_terminate_rejects_wrong_process_id_and_keeps_waiting() {
        let mut reader = io::BufReader::new(io::Cursor::new(
            br#"{"operation":"codex-command-exec-terminate","processId":"wrong-proc"}
{"operation":"codex-command-exec-terminate","processId":"proc-1"}
"#
            .to_vec(),
        ));
        let mut writer = Vec::<u8>::new();

        let control = wait_for_command_exec_control(&mut reader, &mut writer, -1, "proc-1")
            .expect("terminate should recover");

        let text = String::from_utf8(writer).expect("writer should be utf8");
        assert!(text.contains("terminate processId does not match active command/exec"));
        match control {
            CodexCommandExecControlRequest::Terminate(params) => {
                assert_eq!(params.process_id, "proc-1");
            }
            other => panic!("expected terminate control, got {other:?}"),
        }
    }
}
