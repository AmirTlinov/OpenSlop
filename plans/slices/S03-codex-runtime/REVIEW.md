# REVIEW

## Reviewers
- provider-reviewer-codex
- architecture-reviewer

## What must be checked
- Граница owning domains не пробита.
- Слайс не тащит `turn/approval/PTY` scope раньше времени.
- Acceptance доказан реальными артефактами.
- GUI не превратился в transport dashboard.

## Current posture

S03 закрыт как узкий Codex bootstrap lane, а не как полный runtime.

## Local evidence

- `cargo test -p provider-domain` -> PASS
- `cargo test -p session-domain` -> PASS
- `cargo test -p core-daemon` -> PASS
- `swift build --package-path apps/macos-app --product OpenSlopApp` -> PASS
- `swift build --package-path apps/macos-app --product OpenSlopCodexProbe` -> PASS
- `make smoke` -> PASS
- `make smoke-codex-session` -> PASS
- `./target/debug/core-daemon --start-codex-session` -> PASS
- `swift run --package-path apps/macos-app OpenSlopCodexProbe` -> PASS

## Changed surfaces

- `domains/provider/rust/provider-domain`
- `domains/provider/contracts/codex-app-server/v0.123.0`
- `domains/session/rust/session-domain/src/lib.rs`
- `services/core-daemon/src/main.rs`
- `apps/macos-app/Sources/WorkbenchCore/*`
- `apps/macos-app/Sources/OpenSlopApp/*`
- `apps/macos-app/Sources/OpenSlopCodexProbe/main.swift`
- `plans/slices/S03-codex-runtime/*`

## Reviewer verdicts

### provider-reviewer-codex
Verdict: PASS with concerns

Blocking findings:
- none for current bounded scope.

Non-blocking findings:
- version pinning пока документарный; runtime ещё не fail-closed по drift версии;
- GUI пока proof-heavy по language и не выглядит как зрелый runtime UX;
- canonical `session_id == provider_thread_id` годится для bootstrap lane, но не должен бесконечно остаться final identity law.

What is proven:
- live `initialize -> thread/start -> session_list materialization` проходит end-to-end;
- pinned schema subset реально лежит в `domains/provider/contracts/codex-app-server/v0.123.0`;
- daemon reuse и materialization в projection подтверждены живым probe.

### architecture-reviewer
Verdict: GOOD

Blocking findings:
- none in this scope.

Non-blocking findings:
- `session-domain` пока смешивает seeded bootstrap sessions и live truth в одном projection;
- timeline/inspector в GUI ещё partly seeded/demo, не fully daemon-derived.

What is proven:
- `provider-domain` владеет Codex bootstrap;
- `core-daemon` владеет orchestration и IPC;
- `session-domain` владеет persisted projection;
- GUI остаётся thin client и не становится source of truth.

## Closure note

S03 честно закрыт только как bootstrap lane. `turn/start`, streaming, approvals, resume/fork и richer runtime UX остаются следующими slice targets.
