use serde::{Deserialize, Serialize};
use session_domain::{
    load_persisted_session_projection, proof_session_id, reset_session_store, session_store_path,
    upsert_proof_session,
};
use std::env;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};

#[derive(Debug, Deserialize)]
struct StdioRequest {
    query: String,
}

#[derive(Debug, Serialize)]
struct ErrorResponse {
    kind: &'static str,
    message: String,
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

    if args.as_slice() == ["--serve-stdio"] {
        if let Err(error) = serve_stdio(&repo_root) {
            eprintln!("core-daemon stdio server failed: {error}");
            std::process::exit(1);
        }
        return;
    }

    if args.as_slice() == ["--reset-session-store"] {
        match reset_session_store(&repo_root) {
            Ok(()) => println!("session store reset: {}", session_store_path(&repo_root).display()),
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
        "OpenSlop core-daemon supports: --heartbeat | --query session-list | --serve-stdio | --reset-session-store | --upsert-proof-session | --print-session-store-path"
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
    let projection = load_persisted_session_projection(repo_root).map_err(|error| error.to_string())?;
    if pretty {
        serde_json::to_string_pretty(&projection).map_err(|error| error.to_string())
    } else {
        serde_json::to_string(&projection).map_err(|error| error.to_string())
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
    match serde_json::from_str::<StdioRequest>(line) {
        Ok(request) if request.query == "session-list" => match session_list_json(repo_root, false) {
            Ok(payload) => payload,
            Err(message) => serialize_error(message),
        },
        Ok(request) => serialize_error(format!("unsupported query: {}", request.query)),
        Err(error) => serialize_error(format!("invalid request: {error}")),
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

        let response = handle_stdio_request(r#"{"query":"session-list"}"#, temp.path());
        assert!(response.contains(proof_session_id()));
    }
}
