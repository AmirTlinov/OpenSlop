# STATUS

- status: done
- depends_on: S04-transcript-approval-pty
- reviewers: Lovelace the 17th
- current_scope: первый read-only/live-only terminal pane в native inspector поверх streamed transcript contour без interactive control и persistence claims
- closure_receipt: `cargo test -p provider-domain` + `cargo test -p core-daemon` + `swift build --package-path apps/macos-app` + `make smoke-codex-terminal-interaction` + `make smoke-codex-terminal-surface` + `VISUAL-CHECK.md` + reviewer PASS
