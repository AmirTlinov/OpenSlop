# REVIEW

## Local validation

- `cargo test -p provider-domain` -> PASS
- `cargo test -p core-daemon` -> PASS
- `swift build --package-path apps/macos-app` -> PASS
- `make smoke-codex-command-exec-control` -> PASS
  - `output_events=2`
  - `write_sent=true`
  - `terminate_sent=true`
  - `joined_output="READY\nPING\n"`
- `make smoke-codex-command-exec-control-negative` -> PASS
  - `control_errors=2`
  - `wrong_write_rejected=true`
  - `wrong_terminate_rejected=true`
- `make smoke-codex-command-exec-control-surface` -> PASS
  - `stage=completed`
  - `merged_output="READY\nPING\n"`
  - `final_stdout=""`
  - `final_stderr=""`

## Subagent review

Reviewer: `Hume the 17th` (`explorer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none after status/review sync and surface narrowing to fixed proof command.

Non-blocking findings:
- contour остаётся строго fixed: `first output -> write`, `next output -> terminate`; это допустимо для proof lane, но не для full runtime;
- если upstream когда-нибудь поменяет порядок signal-ов, pane может зависнуть в ожидании stage change;
- pixel baseline всё ещё отсутствует, visual check semantic-only.

What is proven:
- UI model `DaemonCodexCommandExecControlSurface` и live probe используют один и тот же bounded contour;
- native inspector рендерит guided standalone exec proof pane без ложных claims про resize, reconnect и arbitrary control order;
- `make smoke-codex-command-exec-control-surface` подтверждает `stage=completed`, stable `processId`, `merged_output="READY\nPING\n"` и пустые final buffers;
- текущий слайс честно narrowed до fixed proof command и не выдает себя за general-purpose exec terminal.
