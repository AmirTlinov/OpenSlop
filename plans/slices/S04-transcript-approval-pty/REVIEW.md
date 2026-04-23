# REVIEW

## Reviewers
- provider-reviewer-codex
- architecture-reviewer
- native-ui-reviewer

## What must be checked
- Граница owning domains не пробита.
- Слайс не притворяется approvals/PTy решением.
- Acceptance доказан живыми проверками.
- GUI остаётся thin client и держит нативную анатомию `sidebar -> timeline -> inspector -> composer`.

## Current posture

S04 пока не закрыт целиком. В этом коммите закрыт только первый proof target: `first live turn round-trip + daemon-owned read-only transcript snapshot`.

## Local evidence

- `cargo test -p provider-domain` -> PASS
- `cargo test -p session-domain` -> PASS
- `cargo test -p core-daemon` -> PASS
- `swift build --package-path apps/macos-app --product OpenSlopApp` -> PASS
- `swift build --package-path apps/macos-app --product OpenSlopTurnProbe` -> PASS
- `swift run --package-path apps/macos-app OpenSlopTurnProbe` -> PASS
- `make smoke-codex-turn` -> PASS

## Changed surfaces

- `.agents/task_framer/s04-live-turn-resume/PREFLIGHT.md`
- `domains/provider/rust/provider-domain/src/lib.rs`
- `domains/provider/contracts/codex-app-server/v0.123.0/*`
- `services/core-daemon/src/main.rs`
- `apps/macos-app/Sources/WorkbenchCore/*`
- `apps/macos-app/Sources/OpenSlopApp/*`
- `apps/macos-app/Sources/OpenSlopTurnProbe/main.swift`
- `plans/slices/S04-transcript-approval-pty/*`

## Reviewer verdicts

### Fast reviewer pass
Reviewer: `Jason the 10th` (`explorer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none for текущего узкого scope.

Non-blocking findings:
- этот коммит закрывает только первый proof target, не весь S04;
- visual check пока semantic-only, потому что screenshot baselines ещё не заведены;
- `session_id == provider_thread_id` остаётся временным законом только для текущего runtime contour.

What is proven:
- bootstrap -> first live turn -> read-only transcript snapshot проходит end-to-end;
- `core-daemon` reuse удерживает первый turn в живом runtime до materialization;
- cold transcript read после materialization честно возвращает архивный `thread.status.type = notLoaded`;
- contract subset и slice docs синхронизированы с текущим protocol surface.

## Closure note

Следующий честный runtime шаг уже отдельно: approvals, PTY, streaming transcript и virtualization. Этот коммит их не симулирует.
