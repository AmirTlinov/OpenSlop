# STATUS

- status: done
- depends_on: S04g
- reviewers: Mill the 6th
- current_scope: standalone PTY `command/exec` resize proof lane с fixed marker-based witness и без GUI resize affordance
- closure_receipt: `cargo test -p provider-domain` + `cargo test -p core-daemon` + `swift build --package-path apps/macos-app` + `make smoke-codex-command-exec-control` + `make smoke-codex-command-exec-control-negative` + `make smoke-codex-command-exec-control-timeout` + `make smoke-codex-command-exec-interactive` + `make smoke-codex-command-exec-resize` + reviewer PASS
