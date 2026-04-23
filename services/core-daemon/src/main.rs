use std::env;

fn main() {
    let heartbeat = env::args().any(|arg| arg == "--heartbeat");

    if heartbeat {
        println!(r#"{{"service":"core-daemon","status":"ok","scope":"bootstrap"}}"#);
        return;
    }

    eprintln!("OpenSlop core-daemon bootstrap seed. Run with --heartbeat.");
}
