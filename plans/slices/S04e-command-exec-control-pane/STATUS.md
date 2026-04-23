# STATUS

- status: done
- depends_on: S04c
- reviewers: Hume the 17th
- current_scope: guided standalone `command/exec` proof pane в inspector с fixed proof command и one-write/one-terminate contour без resize и reconnect claims
- closure_receipt: `cargo test -p provider-domain` + `cargo test -p core-daemon` + `swift build --package-path apps/macos-app` + `make smoke-codex-command-exec-control` + `make smoke-codex-command-exec-control-negative` + `make smoke-codex-command-exec-control-surface` + `VISUAL-CHECK.md` + reviewer PASS
