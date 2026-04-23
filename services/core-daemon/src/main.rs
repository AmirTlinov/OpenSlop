use session_domain::bootstrap_session_projection;
use std::env;

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();

    if args.iter().any(|arg| arg == "--heartbeat") {
        println!(r#"{{"service":"core-daemon","status":"ok","scope":"bootstrap"}}"#);
        return;
    }

    if args.as_slice() == ["--query", "session-list"] {
        let projection = bootstrap_session_projection();
        println!(
            "{}",
            serde_json::to_string_pretty(&projection)
                .expect("bootstrap session projection should serialize")
        );
        return;
    }

    eprintln!(
        "OpenSlop core-daemon bootstrap seed. Supported flags: --heartbeat | --query session-list"
    );
}
