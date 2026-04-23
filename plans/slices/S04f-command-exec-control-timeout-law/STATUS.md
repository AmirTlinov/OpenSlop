# STATUS

- status: done
- depends_on: S04e
- reviewers: Cicero
- current_scope: fail-closed timeout примерно 5 секунд для missing `write/terminate` follow-up внутри standalone `codex-command-exec-control-stream`
- closure_receipt: `cargo test -p provider-domain` + `cargo test -p core-daemon` + `swift build --package-path apps/macos-app` + `make smoke-codex-command-exec-control-timeout` + `make smoke-codex-command-exec-control` + `make smoke-codex-command-exec-control-negative` + `make smoke-codex-command-exec-control-surface` + reviewer PASS
