# REVIEW

## Local validation

- `cargo test -p core-daemon` -> PASS
- `cargo test -p provider-domain` -> PASS
- `make smoke-codex-command-exec-control` -> PASS
  - `output_events=2`
  - `write_sent=true`
  - `terminate_sent=true`
  - `joined_output="READY\nPING\n"`
- `make smoke-codex-command-exec-control-negative` -> PASS
  - `output_events=2`
  - `control_errors=2`
  - `wrong_write_rejected=true`
  - `wrong_terminate_rejected=true`
  - `joined_output="READY\nPING\n"`
  - `final_stdout=""`
  - `final_stderr=""`

## Subagent review

Reviewer: `Aristotle the 16th` (`explorer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none after status/review sync in this slice.

Non-blocking findings:
- `streamCodexCommandWithControlWitness(...)` — это bounded witness rail для proof contour. Он не должен разрастись в молчаливый generic product API без нового slice;
- current proof покрывает только wrong `write` и wrong `terminate` внутри одного live connection contour;
- `apps/macos-app/Package.swift` изменён технически по делу, потому что новый executable probe должен существовать как buildable target.

What is proven:
- `core-daemon` отвергает wrong `processId` для `write` и `terminate`, но не роняет свой wait-loop;
- `WorkbenchCore` умеет увидеть error frame внутри control dialogue и отправить следующий correct follow-up без collapse соединения;
- end-to-end negative probe доказывает `wrong write -> error -> correct write -> PING -> wrong terminate -> error -> correct terminate -> final result`;
- standalone `codex-command-exec-write` и `codex-command-exec-terminate` вне active control stream остаются запрещённым contour.

Visual check:
- not required; product window GUI surface did not change.
