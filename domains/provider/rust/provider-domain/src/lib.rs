use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::HashMap;
use std::fmt::{Display, Formatter};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::thread;
use std::time::{Duration, Instant};

const TRANSPORT: &str = "stdio";
const RESPONSE_TIMEOUT: Duration = Duration::from_secs(5);
const TURN_COMPLETION_TIMEOUT: Duration = Duration::from_secs(45);
const TURN_POLL_INTERVAL: Duration = Duration::from_millis(800);
const SUPPRESSED_NOTIFICATION_METHODS: &[&str] =
    &["thread/started", "turn/started", "turn/completed"];

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CodexThreadBootstrap {
    pub kind: String,
    pub transport: String,
    pub cli_version: String,
    pub initialize: CodexInitializeSummary,
    pub capabilities: CodexCapabilitySnapshot,
    pub thread_id: String,
    pub cwd: String,
    pub model: String,
    pub model_provider: String,
    pub approval_policy: String,
    pub sandbox_mode: String,
    pub reasoning_effort: Option<String>,
    pub instruction_sources: Vec<String>,
    pub thread_status: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CodexInitializeSummary {
    pub user_agent: String,
    pub codex_home: String,
    pub platform_family: String,
    pub platform_os: String,
    pub suppressed_notification_methods: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CodexCapabilitySnapshot {
    pub initialize: bool,
    pub thread_start: bool,
    pub thread_resume: bool,
    pub notification_suppression: bool,
    pub turn_start: bool,
    pub thread_read: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CodexTranscriptSnapshot {
    pub kind: String,
    pub thread_id: String,
    pub preview: String,
    pub thread_status: String,
    pub turn_count: usize,
    pub last_turn_status: Option<String>,
    pub items: Vec<CodexTranscriptEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CodexTranscriptEntry {
    pub id: String,
    pub turn_id: String,
    pub kind: String,
    pub title: String,
    pub text: String,
    pub turn_status: String,
}

pub struct CodexRuntimeRegistry {
    binary: PathBuf,
    sessions: HashMap<String, CodexAppServerProcess>,
}

#[derive(Debug)]
pub enum CodexRuntimeError {
    BinaryLaunch(std::io::Error),
    BinaryMissing(String),
    MissingPipe(&'static str),
    StdinWrite(std::io::Error),
    VersionFailed(String),
    ResponseTimeout {
        method: String,
        waited_ms: u128,
        stderr: String,
    },
    Json(serde_json::Error),
    ServerError {
        method: String,
        code: i64,
        message: String,
    },
    InvalidResponse {
        method: String,
        message: String,
    },
    ThreadNeedsLiveRuntime {
        thread_id: String,
    },
    TurnDidNotComplete {
        thread_id: String,
        waited_ms: u128,
    },
}

impl Display for CodexRuntimeError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            CodexRuntimeError::BinaryLaunch(error) => {
                write!(f, "не удалось запустить codex: {error}")
            }
            CodexRuntimeError::BinaryMissing(path) => write!(f, "не найден codex binary: {path}"),
            CodexRuntimeError::MissingPipe(name) => {
                write!(f, "codex app-server не дал pipe для {name}")
            }
            CodexRuntimeError::StdinWrite(error) => {
                write!(f, "не удалось записать запрос в codex app-server: {error}")
            }
            CodexRuntimeError::VersionFailed(message) => {
                write!(f, "не удалось получить версию codex: {message}")
            }
            CodexRuntimeError::ResponseTimeout {
                method,
                waited_ms,
                stderr,
            } => {
                write!(
                    f,
                    "codex app-server не ответил на {method} за {waited_ms}ms: {stderr}"
                )
            }
            CodexRuntimeError::Json(error) => write!(f, "json decode error: {error}"),
            CodexRuntimeError::ServerError {
                method,
                code,
                message,
            } => {
                write!(
                    f,
                    "codex app-server вернул ошибку на {method}: [{code}] {message}"
                )
            }
            CodexRuntimeError::InvalidResponse { method, message } => {
                write!(
                    f,
                    "codex app-server вернул неожиданный ответ на {method}: {message}"
                )
            }
            CodexRuntimeError::ThreadNeedsLiveRuntime { thread_id } => {
                write!(
                    f,
                    "thread {thread_id} ещё не materialized на диск; первый turn нужно завершить в том же живом daemon runtime, где session была создана"
                )
            }
            CodexRuntimeError::TurnDidNotComplete {
                thread_id,
                waited_ms,
            } => {
                write!(
                    f,
                    "turn для thread {thread_id} не дошёл до terminal state за {waited_ms}ms"
                )
            }
        }
    }
}

impl std::error::Error for CodexRuntimeError {}

impl From<serde_json::Error> for CodexRuntimeError {
    fn from(value: serde_json::Error) -> Self {
        CodexRuntimeError::Json(value)
    }
}

pub fn start_codex_session(repo_root: &Path) -> Result<CodexThreadBootstrap, CodexRuntimeError> {
    let binary = codex_binary();
    start_codex_session_with_binary(repo_root, &binary)
}

pub fn read_codex_transcript(
    repo_root: &Path,
    thread_id: &str,
) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
    let binary = codex_binary();
    read_codex_transcript_with_binary(repo_root, &binary, thread_id)
}

pub fn submit_codex_turn(
    repo_root: &Path,
    thread_id: &str,
    input_text: &str,
) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
    let binary = codex_binary();
    submit_codex_turn_with_binary(repo_root, &binary, thread_id, input_text)
}

impl Default for CodexRuntimeRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl CodexRuntimeRegistry {
    pub fn new() -> Self {
        Self {
            binary: codex_binary(),
            sessions: HashMap::new(),
        }
    }

    pub fn start_session(
        &mut self,
        repo_root: &Path,
    ) -> Result<CodexThreadBootstrap, CodexRuntimeError> {
        let cli_version = read_codex_version(&self.binary)?;
        let mut process = CodexAppServerProcess::launch(repo_root, &self.binary)?;
        let initialize = process.initialize()?;
        let start = process.start_thread(repo_root)?;
        let thread_id = start.thread.id.clone();

        self.sessions.insert(thread_id.clone(), process);

        Ok(CodexThreadBootstrap {
            kind: "codex_session_bootstrap".to_string(),
            transport: TRANSPORT.to_string(),
            cli_version,
            initialize,
            capabilities: capability_snapshot(),
            thread_id,
            cwd: start.cwd,
            model: start.model,
            model_provider: start.model_provider,
            approval_policy: start.approval_policy,
            sandbox_mode: start.sandbox.kind,
            reasoning_effort: start.reasoning_effort,
            instruction_sources: start.instruction_sources,
            thread_status: start.thread.status.kind,
        })
    }

    pub fn has_loaded_session(&mut self, thread_id: &str) -> bool {
        let is_running = self
            .sessions
            .get_mut(thread_id)
            .map(|process| process.is_running())
            .unwrap_or(false);

        if !is_running {
            self.sessions.remove(thread_id);
        }

        is_running
    }

    pub fn read_transcript(
        &mut self,
        repo_root: &Path,
        thread_id: &str,
    ) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
        let process = self.ensure_session_process(repo_root, thread_id)?;
        process.read_transcript(thread_id)
    }

    pub fn submit_turn(
        &mut self,
        repo_root: &Path,
        thread_id: &str,
        input_text: &str,
    ) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
        let process = self.ensure_session_process(repo_root, thread_id)?;
        process.start_turn(thread_id, input_text)?;
        process.wait_for_terminal_transcript(thread_id)
    }

    fn ensure_session_process(
        &mut self,
        repo_root: &Path,
        thread_id: &str,
    ) -> Result<&mut CodexAppServerProcess, CodexRuntimeError> {
        let existing_is_running = self
            .sessions
            .get_mut(thread_id)
            .map(|process| process.is_running())
            .unwrap_or(false);

        if !existing_is_running {
            self.sessions.remove(thread_id);

            let mut process = CodexAppServerProcess::launch(repo_root, &self.binary)?;
            process.initialize()?;
            process.resume_thread(thread_id)?;
            self.sessions.insert(thread_id.to_string(), process);
        }

        self.sessions
            .get_mut(thread_id)
            .ok_or_else(|| CodexRuntimeError::InvalidResponse {
                method: "runtime-registry".to_string(),
                message: format!("thread {thread_id} is not attached to registry"),
            })
    }
}

pub fn start_codex_session_with_binary(
    repo_root: &Path,
    binary: &Path,
) -> Result<CodexThreadBootstrap, CodexRuntimeError> {
    let cli_version = read_codex_version(binary)?;
    let mut process = CodexAppServerProcess::launch(repo_root, binary)?;

    let initialize = process.initialize()?;
    let start = process.start_thread(repo_root)?;

    Ok(CodexThreadBootstrap {
        kind: "codex_session_bootstrap".to_string(),
        transport: TRANSPORT.to_string(),
        cli_version,
        initialize,
        capabilities: capability_snapshot(),
        thread_id: start.thread.id,
        cwd: start.cwd,
        model: start.model,
        model_provider: start.model_provider,
        approval_policy: start.approval_policy,
        sandbox_mode: start.sandbox.kind,
        reasoning_effort: start.reasoning_effort,
        instruction_sources: start.instruction_sources,
        thread_status: start.thread.status.kind,
    })
}

pub fn read_codex_transcript_with_binary(
    repo_root: &Path,
    binary: &Path,
    thread_id: &str,
) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
    let mut process = CodexAppServerProcess::launch(repo_root, binary)?;
    process.initialize()?;
    match process.read_transcript(thread_id) {
        Ok(snapshot) => Ok(snapshot),
        Err(CodexRuntimeError::ServerError { message, .. })
            if is_thread_not_loaded_message(&message) =>
        {
            process.resume_thread(thread_id)?;
            process.read_transcript(thread_id)
        }
        Err(error) => Err(error),
    }
}

pub fn submit_codex_turn_with_binary(
    repo_root: &Path,
    binary: &Path,
    thread_id: &str,
    input_text: &str,
) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
    let mut process = CodexAppServerProcess::launch(repo_root, binary)?;
    process.initialize()?;
    process.resume_thread(thread_id)?;
    process.start_turn(thread_id, input_text)?;
    process.wait_for_terminal_transcript(thread_id)
}

fn capability_snapshot() -> CodexCapabilitySnapshot {
    CodexCapabilitySnapshot {
        initialize: true,
        thread_start: true,
        thread_resume: true,
        notification_suppression: true,
        turn_start: true,
        thread_read: true,
    }
}

fn codex_binary() -> PathBuf {
    std::env::var_os("OPEN_SLOP_CODEX_BIN")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("codex"))
}

fn read_codex_version(binary: &Path) -> Result<String, CodexRuntimeError> {
    let output = Command::new(binary)
        .arg("--version")
        .output()
        .map_err(|error| match error.kind() {
            std::io::ErrorKind::NotFound => {
                CodexRuntimeError::BinaryMissing(binary.display().to_string())
            }
            _ => CodexRuntimeError::BinaryLaunch(error),
        })?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        return Err(CodexRuntimeError::VersionFailed(stderr));
    }

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if stdout.is_empty() {
        return Err(CodexRuntimeError::VersionFailed(
            "пустой stdout".to_string(),
        ));
    }

    Ok(stdout.replace("codex-cli ", ""))
}

struct CodexAppServerProcess {
    child: Child,
    stdin: ChildStdin,
    stdout_rx: Receiver<String>,
    stderr_rx: Receiver<String>,
}

impl CodexAppServerProcess {
    fn launch(repo_root: &Path, binary: &Path) -> Result<Self, CodexRuntimeError> {
        let mut child = Command::new(binary)
            .arg("app-server")
            .arg("--listen")
            .arg("stdio://")
            .current_dir(repo_root)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|error| match error.kind() {
                std::io::ErrorKind::NotFound => {
                    CodexRuntimeError::BinaryMissing(binary.display().to_string())
                }
                _ => CodexRuntimeError::BinaryLaunch(error),
            })?;

        let stdin = child
            .stdin
            .take()
            .ok_or(CodexRuntimeError::MissingPipe("stdin"))?;
        let stdout = child
            .stdout
            .take()
            .ok_or(CodexRuntimeError::MissingPipe("stdout"))?;
        let stderr = child
            .stderr
            .take()
            .ok_or(CodexRuntimeError::MissingPipe("stderr"))?;

        let stdout_rx = spawn_reader(stdout);
        let stderr_rx = spawn_reader(stderr);

        Ok(Self {
            child,
            stdin,
            stdout_rx,
            stderr_rx,
        })
    }

    fn initialize(&mut self) -> Result<CodexInitializeSummary, CodexRuntimeError> {
        let params = json!({
            "clientInfo": {
                "name": "openslop-core-daemon",
                "version": env!("CARGO_PKG_VERSION")
            },
            "capabilities": {
                "optOutNotificationMethods": SUPPRESSED_NOTIFICATION_METHODS
            }
        });

        let response: InitializeResponse = self.request_parse(1, "initialize", &params)?;

        Ok(CodexInitializeSummary {
            user_agent: response.user_agent,
            codex_home: response.codex_home,
            platform_family: response.platform_family,
            platform_os: response.platform_os,
            suppressed_notification_methods: SUPPRESSED_NOTIFICATION_METHODS
                .iter()
                .map(|value| value.to_string())
                .collect(),
        })
    }

    fn start_thread(&mut self, repo_root: &Path) -> Result<ThreadStartResponse, CodexRuntimeError> {
        let params = json!({
            "cwd": repo_root.display().to_string(),
            "approvalPolicy": "never",
            "serviceName": "OpenSlop",
            "sessionStartSource": "startup"
        });

        self.request_parse(2, "thread/start", &params)
    }

    fn start_turn(&mut self, thread_id: &str, input_text: &str) -> Result<(), CodexRuntimeError> {
        let params = json!({
            "threadId": thread_id,
            "input": [
                {
                    "type": "text",
                    "text": input_text
                }
            ]
        });

        self.request_value(3, "turn/start", &params).map(|_| ())
    }

    fn resume_thread(&mut self, thread_id: &str) -> Result<(), CodexRuntimeError> {
        let params = json!({
            "threadId": thread_id
        });

        match self.request_value(3, "thread/resume", &params) {
            Ok(_) => Ok(()),
            Err(CodexRuntimeError::ServerError {
                code: _, message, ..
            }) if is_rollout_missing_message(&message) => {
                Err(CodexRuntimeError::ThreadNeedsLiveRuntime {
                    thread_id: thread_id.to_string(),
                })
            }
            Err(error) => Err(error),
        }
    }

    fn read_transcript(
        &mut self,
        thread_id: &str,
    ) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
        match self.read_transcript_value(thread_id, true) {
            Ok(value) => parse_transcript_snapshot(value),
            Err(CodexRuntimeError::ServerError { message, .. })
                if is_materialization_gap_message(&message) =>
            {
                let value = self.read_transcript_value(thread_id, false)?;
                parse_transcript_snapshot(value)
            }
            Err(error) => Err(error),
        }
    }

    fn wait_for_terminal_transcript(
        &mut self,
        thread_id: &str,
    ) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
        let started = Instant::now();

        loop {
            if started.elapsed() > TURN_COMPLETION_TIMEOUT {
                return Err(CodexRuntimeError::TurnDidNotComplete {
                    thread_id: thread_id.to_string(),
                    waited_ms: TURN_COMPLETION_TIMEOUT.as_millis(),
                });
            }

            match self.read_transcript(thread_id) {
                Ok(snapshot) if is_terminal_status(snapshot.last_turn_status.as_deref()) => {
                    return Ok(snapshot);
                }
                Ok(_) => {
                    thread::sleep(TURN_POLL_INTERVAL);
                }
                Err(CodexRuntimeError::ServerError { message, .. })
                    if message.contains("not materialized yet")
                        || message
                            .contains("includeTurns is unavailable before first user message") =>
                {
                    thread::sleep(TURN_POLL_INTERVAL);
                }
                Err(error) => return Err(error),
            }
        }
    }

    fn read_transcript_value(
        &mut self,
        thread_id: &str,
        include_turns: bool,
    ) -> Result<Value, CodexRuntimeError> {
        let mut params = json!({
            "threadId": thread_id
        });

        if include_turns {
            params["includeTurns"] = Value::Bool(true);
        }

        self.request_value(4, "thread/read", &params)
    }

    fn request_parse<P, R>(
        &mut self,
        id: u64,
        method: &str,
        params: &P,
    ) -> Result<R, CodexRuntimeError>
    where
        P: Serialize,
        R: for<'de> Deserialize<'de>,
    {
        let value = self.request_value(id, method, params)?;
        serde_json::from_value(value).map_err(CodexRuntimeError::Json)
    }

    fn request_value<P>(
        &mut self,
        id: u64,
        method: &str,
        params: &P,
    ) -> Result<Value, CodexRuntimeError>
    where
        P: Serialize,
    {
        let request = JsonRpcRequest { id, method, params };
        let mut payload = serde_json::to_vec(&request)?;
        payload.push(b'\n');
        self.stdin
            .write_all(&payload)
            .map_err(CodexRuntimeError::StdinWrite)?;
        self.stdin.flush().map_err(CodexRuntimeError::StdinWrite)?;

        let deadline = Instant::now() + RESPONSE_TIMEOUT;

        loop {
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                return Err(CodexRuntimeError::ResponseTimeout {
                    method: method.to_string(),
                    waited_ms: RESPONSE_TIMEOUT.as_millis(),
                    stderr: self.stderr_snapshot(),
                });
            }

            let line = self.stdout_rx.recv_timeout(remaining).map_err(|_| {
                CodexRuntimeError::ResponseTimeout {
                    method: method.to_string(),
                    waited_ms: RESPONSE_TIMEOUT.as_millis(),
                    stderr: self.stderr_snapshot(),
                }
            })?;

            let message: Value = serde_json::from_str(&line)?;
            if message.get("method").is_some() {
                continue;
            }

            let response_id = message
                .get("id")
                .and_then(|value| value.as_u64())
                .ok_or_else(|| CodexRuntimeError::InvalidResponse {
                    method: method.to_string(),
                    message: line.clone(),
                })?;

            if response_id != id {
                continue;
            }

            if let Some(error) = message.get("error") {
                let code = error
                    .get("code")
                    .and_then(|value| value.as_i64())
                    .unwrap_or(-1);
                let message = error
                    .get("message")
                    .and_then(|value| value.as_str())
                    .unwrap_or("unknown error")
                    .to_string();
                return Err(CodexRuntimeError::ServerError {
                    method: method.to_string(),
                    code,
                    message,
                });
            }

            return message.get("result").cloned().ok_or_else(|| {
                CodexRuntimeError::InvalidResponse {
                    method: method.to_string(),
                    message: line,
                }
            });
        }
    }

    fn stderr_snapshot(&self) -> String {
        let lines: Vec<String> = self.stderr_rx.try_iter().collect();
        if lines.is_empty() {
            return "no stderr captured".to_string();
        }
        lines.join("\n")
    }

    fn is_running(&mut self) -> bool {
        match self.child.try_wait() {
            Ok(None) => true,
            Ok(Some(_)) => false,
            Err(_) => false,
        }
    }
}

impl Drop for CodexAppServerProcess {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

fn spawn_reader<T>(stream: T) -> Receiver<String>
where
    T: std::io::Read + Send + 'static,
{
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let reader = BufReader::new(stream);
        for line in reader.lines() {
            match line {
                Ok(line) => {
                    if tx.send(line).is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
    });
    rx
}

fn parse_transcript_snapshot(value: Value) -> Result<CodexTranscriptSnapshot, CodexRuntimeError> {
    let thread = value
        .get("thread")
        .ok_or_else(|| CodexRuntimeError::InvalidResponse {
            method: "thread/read".to_string(),
            message: value.to_string(),
        })?;

    let thread_id = thread_string(thread, "id")?;
    let preview = thread
        .get("preview")
        .and_then(|value| value.as_str())
        .unwrap_or("")
        .to_string();
    let thread_status = thread_status_string(thread.get("status"));
    let turns = thread
        .get("turns")
        .and_then(|value| value.as_array())
        .cloned()
        .unwrap_or_default();

    let mut items = Vec::new();
    let mut last_turn_status = None;

    for turn in turns.iter() {
        let turn_id = turn_string(turn, "id")?;
        let turn_status = turn
            .get("status")
            .and_then(|value| value.as_str())
            .unwrap_or("unknown")
            .to_string();
        last_turn_status = Some(turn_status.clone());

        for item in turn
            .get("items")
            .and_then(|value| value.as_array())
            .cloned()
            .unwrap_or_default()
            .iter()
        {
            items.push(parse_transcript_item(item, &turn_id, &turn_status));
        }
    }

    Ok(CodexTranscriptSnapshot {
        kind: "codex_transcript_snapshot".to_string(),
        thread_id,
        preview,
        thread_status,
        turn_count: turns.len(),
        last_turn_status,
        items,
    })
}

fn parse_transcript_item(item: &Value, turn_id: &str, turn_status: &str) -> CodexTranscriptEntry {
    let item_type = item
        .get("type")
        .and_then(|value| value.as_str())
        .unwrap_or("unknown");
    let item_id = item
        .get("id")
        .and_then(|value| value.as_str())
        .unwrap_or("item-unknown")
        .to_string();

    match item_type {
        "userMessage" => CodexTranscriptEntry {
            id: item_id,
            turn_id: turn_id.to_string(),
            kind: "user".to_string(),
            title: "User prompt".to_string(),
            text: extract_user_message_text(item),
            turn_status: turn_status.to_string(),
        },
        "agentMessage" => CodexTranscriptEntry {
            id: item_id,
            turn_id: turn_id.to_string(),
            kind: "agent".to_string(),
            title: match item.get("phase").and_then(|value| value.as_str()) {
                Some("final_answer") => "Assistant reply".to_string(),
                Some(phase) => format!("Assistant {phase}"),
                None => "Assistant reply".to_string(),
            },
            text: item
                .get("text")
                .and_then(|value| value.as_str())
                .unwrap_or("")
                .to_string(),
            turn_status: turn_status.to_string(),
        },
        other => CodexTranscriptEntry {
            id: item_id,
            turn_id: turn_id.to_string(),
            kind: "tool".to_string(),
            title: format!("Tool activity · {other}"),
            text: extract_generic_item_text(item).unwrap_or_else(|| other.to_string()),
            turn_status: turn_status.to_string(),
        },
    }
}

fn extract_user_message_text(item: &Value) -> String {
    item.get("content")
        .and_then(|value| value.as_array())
        .map(|parts| {
            parts
                .iter()
                .filter_map(|part| part.get("text").and_then(|value| value.as_str()))
                .collect::<Vec<_>>()
                .join("\n")
        })
        .unwrap_or_default()
}

fn extract_generic_item_text(item: &Value) -> Option<String> {
    for key in ["text", "command", "title", "name", "reason"] {
        if let Some(text) = item.get(key).and_then(|value| value.as_str()) {
            if !text.is_empty() {
                return Some(text.to_string());
            }
        }
    }
    None
}

fn thread_string(thread: &Value, key: &str) -> Result<String, CodexRuntimeError> {
    thread
        .get(key)
        .and_then(|value| value.as_str())
        .map(ToString::to_string)
        .ok_or_else(|| CodexRuntimeError::InvalidResponse {
            method: "thread/read".to_string(),
            message: format!("missing thread field {key}"),
        })
}

fn turn_string(turn: &Value, key: &str) -> Result<String, CodexRuntimeError> {
    turn.get(key)
        .and_then(|value| value.as_str())
        .map(ToString::to_string)
        .ok_or_else(|| CodexRuntimeError::InvalidResponse {
            method: "thread/read".to_string(),
            message: format!("missing turn field {key}"),
        })
}

fn thread_status_string(status: Option<&Value>) -> String {
    match status {
        Some(Value::Object(map)) => map
            .get("type")
            .and_then(|value| value.as_str())
            .unwrap_or("unknown")
            .to_string(),
        Some(Value::String(value)) => value.to_string(),
        _ => "unknown".to_string(),
    }
}

fn is_terminal_status(status: Option<&str>) -> bool {
    matches!(
        status,
        Some("completed" | "failed" | "cancelled" | "interrupted")
    )
}

fn is_materialization_gap_message(message: &str) -> bool {
    message.contains("not materialized yet")
        || message.contains("includeTurns is unavailable before first user message")
}

fn is_rollout_missing_message(message: &str) -> bool {
    message.contains("no rollout found for thread id")
}

fn is_thread_not_loaded_message(message: &str) -> bool {
    message.contains("thread not loaded")
}

#[derive(Serialize)]
struct JsonRpcRequest<'a, T> {
    id: u64,
    method: &'a str,
    params: &'a T,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct InitializeResponse {
    user_agent: String,
    codex_home: String,
    platform_family: String,
    platform_os: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ThreadStartResponse {
    thread: ThreadRecord,
    model: String,
    model_provider: String,
    cwd: String,
    approval_policy: String,
    sandbox: SandboxPolicy,
    reasoning_effort: Option<String>,
    instruction_sources: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ThreadRecord {
    id: String,
    status: ThreadStatus,
}

#[derive(Debug, Deserialize)]
struct ThreadStatus {
    #[serde(rename = "type")]
    kind: String,
}

#[derive(Debug, Deserialize)]
struct SandboxPolicy {
    #[serde(rename = "type")]
    kind: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;
    use tempfile::tempdir;

    #[test]
    fn bootstrap_session_reads_initialize_and_thread_start() {
        let repo = tempdir().expect("temp repo should exist");
        let binary = write_stub_codex_binary(repo.path(), false);

        let bootstrap = start_codex_session_with_binary(repo.path(), &binary)
            .expect("bootstrap should succeed");

        assert_eq!(bootstrap.kind, "codex_session_bootstrap");
        assert_eq!(bootstrap.transport, TRANSPORT);
        assert_eq!(bootstrap.cli_version, "0.123.0-stub");
        assert_eq!(bootstrap.thread_id, "thread-stub-001");
        assert_eq!(bootstrap.model, "gpt-5.4");
        assert_eq!(bootstrap.approval_policy, "never");
        assert_eq!(bootstrap.thread_status, "idle");
        assert!(bootstrap.capabilities.initialize);
        assert!(bootstrap.capabilities.thread_resume);
        assert!(bootstrap.capabilities.turn_start);
        assert_eq!(bootstrap.initialize.codex_home, "/tmp/codex-home");
        assert_eq!(
            bootstrap.initialize.suppressed_notification_methods.len(),
            3
        );
    }

    #[test]
    fn bootstrap_session_surfaces_server_error() {
        let repo = tempdir().expect("temp repo should exist");
        let binary = write_stub_codex_binary(repo.path(), true);

        let error = start_codex_session_with_binary(repo.path(), &binary)
            .expect_err("bootstrap should fail");
        let message = error.to_string();
        assert!(message.contains("thread/start"));
        assert!(message.contains("stubbed failure"));
    }

    #[test]
    fn runtime_registry_keeps_first_turn_alive_before_materialization() {
        let repo = tempdir().expect("temp repo should exist");
        let binary = write_stub_codex_binary(repo.path(), false);
        let mut registry = CodexRuntimeRegistry {
            binary: binary.clone(),
            sessions: HashMap::new(),
        };

        let bootstrap = registry
            .start_session(repo.path())
            .expect("bootstrap should succeed");

        let pre_turn_snapshot = registry
            .read_transcript(repo.path(), &bootstrap.thread_id)
            .expect("pre-turn transcript should load from live runtime");
        assert_eq!(pre_turn_snapshot.turn_count, 0);
        assert!(pre_turn_snapshot.items.is_empty());

        let snapshot = registry
            .submit_turn(repo.path(), &bootstrap.thread_id, "Reply with exactly OK.")
            .expect("turn should complete");

        assert_eq!(snapshot.thread_id, bootstrap.thread_id);
        assert_eq!(snapshot.last_turn_status.as_deref(), Some("completed"));
        assert_eq!(snapshot.items.len(), 2);
        assert_eq!(snapshot.items[0].kind, "user");
        assert_eq!(snapshot.items[1].kind, "agent");
        assert_eq!(snapshot.items[1].text, "OK");
    }

    #[test]
    fn fresh_process_submit_turn_requires_materialized_rollout() {
        let repo = tempdir().expect("temp repo should exist");
        let binary = write_stub_codex_binary(repo.path(), false);
        let bootstrap = start_codex_session_with_binary(repo.path(), &binary)
            .expect("bootstrap should succeed");

        let error = submit_codex_turn_with_binary(
            repo.path(),
            &binary,
            &bootstrap.thread_id,
            "Reply with exactly OK.",
        )
        .expect_err("fresh process should fail before first turn materializes");

        assert!(error.to_string().contains("ещё не materialized на диск"));
    }

    #[test]
    fn read_transcript_returns_completed_snapshot_after_materialization() {
        let repo = tempdir().expect("temp repo should exist");
        let binary = write_stub_codex_binary(repo.path(), false);
        let mut registry = CodexRuntimeRegistry {
            binary: binary.clone(),
            sessions: HashMap::new(),
        };
        let bootstrap = registry
            .start_session(repo.path())
            .expect("bootstrap should succeed");
        registry
            .submit_turn(repo.path(), &bootstrap.thread_id, "Reply with exactly OK.")
            .expect("turn should complete");

        let snapshot =
            read_codex_transcript_with_binary(repo.path(), &binary, &bootstrap.thread_id)
                .expect("transcript should load");

        assert_eq!(snapshot.turn_count, 1);
        assert_eq!(snapshot.last_turn_status.as_deref(), Some("completed"));
        assert!(snapshot.preview.contains("Reply with exactly OK."));
    }

    fn write_stub_codex_binary(repo_root: &Path, fail_thread_start: bool) -> PathBuf {
        let path = repo_root.join("codex-stub.py");
        let script = r#"#!/usr/bin/env python3
import json
import os
import sys

FAIL_THREAD_START = __FAIL_THREAD_START__
STATE_FILE = os.path.join(os.getcwd(), 'codex_stub_state.json')
DEFAULT_STATE = {
    'thread_started': False,
    'turn_started': False,
    'thread_id': 'thread-stub-001',
    'read_count': 0,
    'prompt': '',
    'completed': False,
}

def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r', encoding='utf-8') as fh:
            loaded = json.load(fh)
            state = dict(DEFAULT_STATE)
            state.update(loaded)
            return state
    return dict(DEFAULT_STATE)

def save_state(state):
    with open(STATE_FILE, 'w', encoding='utf-8') as fh:
        json.dump(state, fh)

STATE = load_state()
args = sys.argv[1:]
if args == ['--version']:
    print('codex-cli 0.123.0-stub')
    raise SystemExit(0)

if args[:3] == ['app-server', '--listen', 'stdio://']:
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        msg = json.loads(raw)
        method = msg.get('method')
        if method == 'initialize':
            print(json.dumps({'id': msg['id'], 'result': {
                'userAgent': 'stub-client/0.123.0',
                'codexHome': '/tmp/codex-home',
                'platformFamily': 'unix',
                'platformOs': 'macos'
            }}), flush=True)
            continue
        if method == 'thread/start':
            if FAIL_THREAD_START:
                print(json.dumps({'id': msg['id'], 'error': {'code': -32000, 'message': 'stubbed failure'}}), flush=True)
                continue
            STATE['thread_started'] = True
            save_state(STATE)
            print(json.dumps({'id': msg['id'], 'result': {
                'thread': {
                    'id': STATE['thread_id'],
                    'status': {'type': 'idle'}
                },
                'model': 'gpt-5.4',
                'modelProvider': 'openai_responses_only',
                'cwd': '/tmp/repo',
                'approvalPolicy': 'never',
                'sandbox': {'type': 'dangerFullAccess'},
                'reasoningEffort': 'xhigh',
                'instructionSources': ['/tmp/global/AGENTS.md', '/tmp/repo/AGENTS.md']
            }}), flush=True)
            continue
        if method == 'thread/resume':
            if not STATE['completed']:
                print(json.dumps({'id': msg['id'], 'error': {'code': -32600, 'message': f"no rollout found for thread id {msg['params']['threadId']}"}}), flush=True)
                continue
            print(json.dumps({'id': msg['id'], 'result': {
                'thread': {
                    'id': STATE['thread_id'],
                    'status': {'type': 'idle'}
                }
            }}), flush=True)
            continue
        if method == 'turn/start':
            STATE['turn_started'] = True
            STATE['read_count'] = 0
            STATE['prompt'] = msg['params']['input'][0]['text']
            STATE['completed'] = False
            save_state(STATE)
            print(json.dumps({'id': msg['id'], 'result': {
                'turn': {
                    'id': 'turn-stub-001',
                    'items': [],
                    'status': 'inProgress',
                    'error': None,
                    'startedAt': None,
                    'completedAt': None,
                    'durationMs': None,
                }
            }}), flush=True)
            continue
        if method == 'thread/read':
            if not STATE['turn_started']:
                print(json.dumps({'id': msg['id'], 'result': {
                    'thread': {
                        'id': STATE['thread_id'],
                        'preview': '',
                        'status': {'type': 'idle'},
                        'turns': []
                    }
                }}), flush=True)
                continue
            STATE['read_count'] += 1
            completed = STATE['read_count'] >= 2
            items = [
                {
                    'type': 'userMessage',
                    'id': 'item-1',
                    'content': [
                        {'type': 'text', 'text': STATE['prompt'], 'text_elements': []}
                    ]
                }
            ]
            STATE['completed'] = completed
            save_state(STATE)
            if completed:
                items.append({
                    'type': 'agentMessage',
                    'id': 'item-2',
                    'text': 'OK',
                    'phase': 'final_answer',
                    'memoryCitation': None,
                })
            print(json.dumps({'id': msg['id'], 'result': {
                'thread': {
                    'id': STATE['thread_id'],
                    'forkedFromId': None,
                    'preview': STATE['prompt'],
                    'ephemeral': False,
                    'modelProvider': 'openai_responses_only',
                    'createdAt': 1,
                    'updatedAt': 2,
                    'status': {'type': 'idle' if completed else 'active'},
                    'path': '/tmp/rollout.jsonl',
                    'cwd': '/tmp/repo',
                    'cliVersion': '0.123.0-stub',
                    'source': 'vscode',
                    'agentNickname': None,
                    'agentRole': None,
                    'gitInfo': None,
                    'name': None,
                    'turns': [{
                        'id': 'turn-stub-001',
                        'items': items,
                        'status': 'completed' if completed else 'inProgress',
                        'error': None,
                        'startedAt': 1,
                        'completedAt': 2 if completed else None,
                        'durationMs': 123 if completed else None,
                    }]
                }
            }}), flush=True)
            continue
        print(json.dumps({'id': msg.get('id', 0), 'error': {'code': -32601, 'message': 'unsupported'}}), flush=True)
    raise SystemExit(0)

print('unsupported args', args, file=sys.stderr)
raise SystemExit(1)
"#.replace("__FAIL_THREAD_START__", if fail_thread_start { "True" } else { "False" });
        fs::write(&path, script).expect("stub script should write");
        let mut permissions = fs::metadata(&path)
            .expect("metadata should exist")
            .permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&path, permissions).expect("permissions should update");
        path
    }
}
