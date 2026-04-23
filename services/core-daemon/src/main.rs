use provider_domain::{
    CodexRuntimeRegistry, CodexThreadBootstrap, read_codex_transcript, submit_codex_turn,
};
use serde::{Deserialize, Serialize};
use session_domain::{
    SessionSummary, load_persisted_session_projection, proof_session_id, reset_session_store,
    session_store_path, upsert_proof_session, upsert_runtime_session,
};
use std::env;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{LazyLock, Mutex};

static CODEX_RUNTIME_REGISTRY: LazyLock<Mutex<CodexRuntimeRegistry>> =
    LazyLock::new(|| Mutex::new(CodexRuntimeRegistry::new()));

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct StdioRequest {
    operation: Option<String>,
    query: Option<String>,
    session_id: Option<String>,
    input_text: Option<String>,
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
        "OpenSlop core-daemon supports: --heartbeat | --query session-list | --start-codex-session | --read-codex-transcript <session-id> _ | --submit-codex-turn <session-id> <input> | --serve-stdio | --reset-session-store | --upsert-proof-session | --print-session-store-path"
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
    writer: &mut impl Write,
) -> Result<String, String> {
    let mut registry = CODEX_RUNTIME_REGISTRY
        .lock()
        .map_err(|_| "codex runtime registry lock poisoned".to_string())?;

    let transcript = registry
        .stream_turn(repo_root, session_id, input_text, |snapshot| {
            let payload = serde_json::to_string(&CodexTranscriptStreamEventResponse {
                kind: "codex_transcript_stream_event",
                session_id: session_id.to_string(),
                snapshot,
            })
            .map_err(|error| error.to_string())?;
            writeln!(writer, "{payload}").map_err(|error| error.to_string())?;
            writer.flush().map_err(|error| error.to_string())
        })
        .map_err(|error| error.to_string())?;

    let session = map_transcript_to_session(repo_root, session_id, &transcript);
    upsert_runtime_session(repo_root, &session).map_err(|error| error.to_string())?;
    serialize_payload(&transcript, pretty)
}

fn serialize_payload<T: Serialize>(payload: &T, pretty: bool) -> Result<String, String> {
    if pretty {
        serde_json::to_string_pretty(payload).map_err(|error| error.to_string())
    } else {
        serde_json::to_string(payload).map_err(|error| error.to_string())
    }
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
    let stdout = io::stdout();
    let mut writer = io::BufWriter::new(stdout.lock());

    for line in stdin.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let request = match serde_json::from_str::<StdioRequest>(&line) {
            Ok(request) => request,
            Err(error) => {
                writeln!(
                    writer,
                    "{}",
                    serialize_error(format!("invalid request: {error}"))
                )?;
                writer.flush()?;
                continue;
            }
        };

        if handle_streaming_stdio_request(&request, repo_root, &mut writer)? {
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
    let operation = request.operation.or(request.query).unwrap_or_default();

    match operation.as_str() {
        "session-list" => match session_list_json(repo_root, false) {
            Ok(payload) => payload,
            Err(message) => serialize_error(message),
        },
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
        other => serialize_error(format!("unsupported operation: {other}")),
    }
}

fn handle_streaming_stdio_request(
    request: &StdioRequest,
    repo_root: &Path,
    writer: &mut impl Write,
) -> io::Result<bool> {
    let operation = request
        .operation
        .clone()
        .or(request.query.clone())
        .unwrap_or_default();

    if operation != "codex-submit-turn-stream" {
        return Ok(false);
    }

    let response = match (request.session_id.as_deref(), request.input_text.as_deref()) {
        (Some(session_id), Some(input_text)) => {
            match codex_submit_turn_stream_json(repo_root, session_id, input_text, false, writer) {
                Ok(payload) => payload,
                Err(message) => serialize_error(message),
            }
        }
        (None, _) => serialize_error("missing sessionId".to_string()),
        (_, None) => serialize_error("missing inputText".to_string()),
    };

    writeln!(writer, "{response}")?;
    writer.flush()?;
    Ok(true)
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
}
