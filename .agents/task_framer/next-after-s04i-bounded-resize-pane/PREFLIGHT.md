# next after S04i — bounded resize pane preflight

Recommended next slice: `S04j-command-exec-bounded-resize-pane`

Decision-changing questions:
1. Should the next step stay in standalone `command/exec` control, or try to bridge transcript terminal control now?
   - Current best answer: stay standalone; `S04h` proved the live transcript `processId -> command/exec/write` bridge is rejected.
2. Is `kill` a real upstream control surface, or are we still limited to `write` / `resize` / `terminate`?
   - Current best answer: current generated schema shows `write`, `resize`, `terminate`; no `kill` hit was found.
3. Should resize stay bounded to fixed presets in the existing proof pane, or expand to window-coupled/freeform terminal sizing?
   - Current best answer: keep fixed presets; `S04i` explicitly kept window-coupled drag and visual terminal fidelity out of scope.
4. Should this pane remain proof-owned with the fixed command, or open arbitrary exec as a general terminal surface?
   - Current best answer: remain proof-owned; the current pane and docs still describe a bounded proof lane.

Cheap probe:
```sh
tmp=$(mktemp -d) && codex app-server generate-json-schema --out "$tmp" >/dev/null && { rg -n 'command/exec/(resize|terminate|kill)' "$tmp/ClientRequest.json"; rg -n 'Pane не обещает reconnect, resize|no active command/exec' apps/macos-app/Sources/OpenSlopApp/CommandExecControlPaneView.swift plans/slices/S04h-live-transcript-control-witness/REVIEW.md; }
```
