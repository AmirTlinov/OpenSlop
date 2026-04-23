use serde::{Deserialize, Serialize};
use std::fmt::{Display, Formatter};
use std::io::{BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::time::{Duration, Instant};

const TRANSPORT: &str = "stdio";
const RESPONSE_TIMEOUT: Duration = Duration::from_secs(5);
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
    pub notification_suppression: bool,
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
    ResponseStreamClosed {
        method: String,
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
            CodexRuntimeError::ResponseStreamClosed { method, stderr } => {
                write!(
                    f,
                    "stdout codex app-server закрылся во время {method}: {stderr}"
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
        capabilities: CodexCapabilitySnapshot {
            initialize: true,
            thread_start: true,
            notification_suppression: true,
        },
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
        let params = InitializeParams {
            client_info: ClientInfo {
                name: "openslop-core-daemon".to_string(),
                version: env!("CARGO_PKG_VERSION").to_string(),
            },
            capabilities: Some(InitializeCapabilities {
                opt_out_notification_methods: Some(
                    SUPPRESSED_NOTIFICATION_METHODS
                        .iter()
                        .map(|value| value.to_string())
                        .collect(),
                ),
            }),
        };

        let response: InitializeResponse = self.request(1, "initialize", &params)?;

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
        let params = ThreadStartParams {
            cwd: Some(repo_root.display().to_string()),
            approval_policy: Some("never".to_string()),
            service_name: Some("OpenSlop".to_string()),
            session_start_source: Some("startup".to_string()),
        };

        self.request(2, "thread/start", &params)
    }

    fn request<P, R>(&mut self, id: u64, method: &str, params: &P) -> Result<R, CodexRuntimeError>
    where
        P: Serialize,
        R: for<'de> Deserialize<'de>,
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
                let waited_ms = RESPONSE_TIMEOUT.as_millis();
                return Err(CodexRuntimeError::ResponseTimeout {
                    method: method.to_string(),
                    waited_ms,
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

            let message: serde_json::Value = serde_json::from_str(&line)?;
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

            let result =
                message
                    .get("result")
                    .ok_or_else(|| CodexRuntimeError::InvalidResponse {
                        method: method.to_string(),
                        message: line.clone(),
                    })?;

            return serde_json::from_value(result.clone()).map_err(CodexRuntimeError::Json);
        }
    }

    fn stderr_snapshot(&self) -> String {
        let lines: Vec<String> = self.stderr_rx.try_iter().collect();
        if lines.is_empty() {
            return "no stderr captured".to_string();
        }
        lines.join("\n")
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
    std::thread::spawn(move || {
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

#[derive(Serialize)]
struct JsonRpcRequest<'a, T> {
    id: u64,
    method: &'a str,
    params: &'a T,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct InitializeParams {
    client_info: ClientInfo,
    capabilities: Option<InitializeCapabilities>,
}

#[derive(Serialize)]
struct ClientInfo {
    name: String,
    version: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct InitializeCapabilities {
    opt_out_notification_methods: Option<Vec<String>>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ThreadStartParams {
    cwd: Option<String>,
    approval_policy: Option<String>,
    service_name: Option<String>,
    session_start_source: Option<String>,
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
        assert!(bootstrap.capabilities.thread_start);
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

    fn write_stub_codex_binary(repo_root: &Path, fail_thread_start: bool) -> PathBuf {
        let path = repo_root.join("codex-stub.py");
        let script = r#"#!/usr/bin/env python3
import json
import sys

FAIL_THREAD_START = __FAIL_THREAD_START__
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
        if msg.get('method') == 'initialize':
            print(json.dumps({'id': msg['id'], 'result': {
                'userAgent': 'stub-client/0.123.0',
                'codexHome': '/tmp/codex-home',
                'platformFamily': 'unix',
                'platformOs': 'macos'
            }}), flush=True)
            continue
        if msg.get('method') == 'thread/start':
            if FAIL_THREAD_START:
                print(json.dumps({'id': msg['id'], 'error': {'code': -32000, 'message': 'stubbed failure'}}), flush=True)
                continue
            print(json.dumps({'id': msg['id'], 'result': {
                'thread': {
                    'id': 'thread-stub-001',
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
