# REVIEW

## Local validation

- `cargo test -p provider-domain` -> PASS
- `cargo test -p core-daemon` -> PASS
- `swift build --package-path apps/macos-app` -> PASS
- `make smoke-codex-terminal-interaction` -> PASS
  - `streamed_terminal_items=3`
  - `live_terminal_items=4`
  - `final_terminal_items=1`
  - `live_process_ids=<single process id>`
  - `readback_retained_terminal=false`
- `make smoke-codex-terminal-surface` -> PASS
  - `streamed_surface=true`
  - `final_surface=true`
  - `readback_surface=false`
  - `surface_stdin="\n"`
  - `surface_output="\r\nDONE\r\n"`
  - `surface_exit=0`

## Subagent review

Reviewer: `Lovelace the 17th` (`explorer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none for current bounded scope.

Non-blocking findings:
- visual proof пока semantic-only и без pixel baseline;
- новый smoke `smoke-codex-terminal-surface` стоит держать в регулярной регрессии вместе с остальными S04 smoke;
- retry в probes пока завязан на текст ошибки empty-rollout и позже может потребовать более структурный signal.

What is proven:
- `DaemonCodexTerminalSurfaceProjector` materialize'ит terminal surface только из streamed transcript command item с non-empty `processId` и `terminalStdin`;
- inspector рендерит terminal pane отдельным блоком и не выдаёт его за interactive terminal surface;
- docs и UI не обещают `write` / `terminate` / `resize`, reconnect и multi-client;
- `make smoke-codex-terminal-surface` и `OpenSlopTerminalInteractionProbe` подтверждают live-only boundary и отсутствие утечки в ordinary readback.
