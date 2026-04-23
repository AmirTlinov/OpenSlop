# STATUS

- status: done
- depends_on: S04b
- reviewers: Aristotle the 16th
- current_scope: wrong `processId` rejection внутри live `codex-command-exec-control-stream` плюс standalone outside-stream rejection без multi-client и reconnect claims
- closure_receipt: `cargo test -p core-daemon` + `cargo test -p provider-domain` + `make smoke-codex-command-exec-control` + `make smoke-codex-command-exec-control-negative` + reviewer PASS
