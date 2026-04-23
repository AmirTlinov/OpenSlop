use serde::{Deserialize, Serialize};
use session_domain::bootstrap_session_projection;
use std::env;
use std::io::{self, BufRead, Write};

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

    if args.iter().any(|arg| arg == "--heartbeat") {
        println!(r#"{{"service":"core-daemon","status":"ok","scope":"bootstrap"}}"#);
        return;
    }

    if args.as_slice() == ["--query", "session-list"] {
        println!("{}", session_list_json(true));
        return;
    }

    if args.as_slice() == ["--serve-stdio"] {
        if let Err(error) = serve_stdio() {
            eprintln!("core-daemon stdio server failed: {error}");
            std::process::exit(1);
        }
        return;
    }

    eprintln!(
        "OpenSlop core-daemon bootstrap seed. Supported flags: --heartbeat | --query session-list | --serve-stdio"
    );
}

fn session_list_json(pretty: bool) -> String {
    let projection = bootstrap_session_projection();
    if pretty {
        serde_json::to_string_pretty(&projection).expect("bootstrap session projection should serialize")
    } else {
        serde_json::to_string(&projection).expect("bootstrap session projection should serialize")
    }
}

fn serve_stdio() -> io::Result<()> {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut writer = io::BufWriter::new(stdout.lock());

    for line in stdin.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let response = handle_stdio_request(&line);
        writeln!(writer, "{response}")?;
        writer.flush()?;
    }

    Ok(())
}

fn handle_stdio_request(line: &str) -> String {
    match serde_json::from_str::<StdioRequest>(line) {
        Ok(request) if request.query == "session-list" => session_list_json(false),
        Ok(request) => serde_json::to_string(&ErrorResponse {
            kind: "error",
            message: format!("unsupported query: {}", request.query),
        })
        .expect("error response should serialize"),
        Err(error) => serde_json::to_string(&ErrorResponse {
            kind: "error",
            message: format!("invalid request: {error}"),
        })
        .expect("error response should serialize"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn handles_session_list_request() {
        let response = handle_stdio_request(r#"{"query":"session-list"}"#);
        assert!(response.contains("session_list"));
        assert!(response.contains("s02-event-spine"));
    }

    #[test]
    fn rejects_unknown_query() {
        let response = handle_stdio_request(r#"{"query":"unknown"}"#);
        assert!(response.contains("\"kind\":\"error\""));
    }
}
