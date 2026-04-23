use provider_domain::{CodexThreadBootstrap, start_codex_session};
use serde::{Deserialize, Serialize};
use session_domain::{
    SessionSummary, load_persisted_session_projection, proof_session_id, reset_session_store,
    session_store_path, upsert_proof_session, upsert_runtime_session,
};
use std::env;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum StdioRequest {
    Operation { operation: String },
    LegacyQuery { query: String },
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    kind: &'static str,
    message: String,
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
        "OpenSlop core-daemon supports: --heartbeat | --query session-list | --start-codex-session | --serve-stdio | --reset-session-store | --upsert-proof-session | --print-session-store-path"
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
    let bootstrap = start_codex_session(repo_root).map_err(|error| error.to_string())?;
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

fn map_bootstrap_to_session(repo_root: &Path, bootstrap: &CodexThreadBootstrap) -> SessionSummary {
    SessionSummary {
        id: bootstrap.thread_id.clone(),
        title: format!("Codex thread {}", short_thread_id(&bootstrap.thread_id)),
        workspace: repo_root
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("workspace")
            .to_string(),
        branch: current_branch(repo_root),
        provider: "Codex".to_string(),
        status: bootstrap.thread_status.clone(),
    }
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

fn serve_stdio(repo_root: &Path) -> io::Result<()> {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut writer = io::BufWriter::new(stdout.lock());

    for line in stdin.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let response = handle_stdio_request(&line, repo_root);
        writeln!(writer, "{response}")?;
        writer.flush()?;
    }

    Ok(())
}

fn handle_stdio_request(line: &str, repo_root: &Path) -> String {
    let operation = match serde_json::from_str::<StdioRequest>(line) {
        Ok(StdioRequest::Operation { operation }) => operation,
        Ok(StdioRequest::LegacyQuery { query }) => query,
        Err(error) => return serialize_error(format!("invalid request: {error}")),
    };

    match operation.as_str() {
        "session-list" => match session_list_json(repo_root, false) {
            Ok(payload) => payload,
            Err(message) => serialize_error(message),
        },
        "codex-start-session" => match codex_start_session_json(repo_root, false) {
            Ok(payload) => payload,
            Err(message) => serialize_error(message),
        },
        other => serialize_error(format!("unsupported operation: {other}")),
    }
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
                notification_suppression: true,
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
        assert_eq!(session.status, "idle");
        assert!(session.title.contains("thread-a"));
    }
}
