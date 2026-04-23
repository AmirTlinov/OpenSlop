# STATUS

- status: done
- depends_on: S04e, S04i
- reviewers: Averroes the 7th
- current_scope: native fixed resize proof mode в inspector pane поверх уже доказанного standalone PTY resize contour
- closure_receipt: `swift build --package-path apps/macos-app` + `make smoke-codex-command-exec-control-surface` + `make smoke-codex-command-exec-interactive` + `make smoke-codex-command-exec-resize` + `make smoke-codex-command-exec-resize-surface` + reviewer PASS
