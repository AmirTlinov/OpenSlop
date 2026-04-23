# REVIEW

## Reviewers
- provider-reviewer-codex
- architecture-reviewer
- native-ui-reviewer

## What must be checked
- Граница owning domains не пробита.
- Слайс не притворяется PTY или full approval center решением.
- Acceptance доказан живыми проверками.
- GUI остаётся thin client и держит нативную анатомию `sidebar -> timeline -> inspector -> composer`.

## Current posture

S04 пока не закрыт целиком. В этом коммите закрыт следующий proof target: `daemon-owned native approval lane` поверх уже существующего streaming transcript path.

## Local evidence

- `cargo test -p provider-domain` -> PASS
- `cargo test -p session-domain` -> PASS
- `cargo test -p core-daemon` -> PASS
- `cargo build -p core-daemon` -> PASS
- `swift build --package-path apps/macos-app --product OpenSlopApp` -> PASS
- `swift build --package-path apps/macos-app --product OpenSlopTurnProbe` -> PASS
- `swift build --package-path apps/macos-app --product OpenSlopApprovalProbe` -> PASS
- `swift run --package-path apps/macos-app OpenSlopTurnProbe` -> PASS
- `swift run --package-path apps/macos-app OpenSlopApprovalProbe` -> PASS
- `make smoke-codex-turn` -> PASS
- `make smoke-codex-approval` -> PASS

## Changed surfaces

- `.agents/task_framer/s04-live-turn-resume/PREFLIGHT.md`
- `.agents/task_framer/s04-streaming-transcript/PREFLIGHT.md`
- `.agents/task_framer/s04-native-approvals/PREFLIGHT.md`
- `domains/provider/rust/provider-domain/src/lib.rs`
- `domains/provider/contracts/codex-app-server/v0.123.0/*`
- `services/core-daemon/src/main.rs`
- `apps/macos-app/Sources/WorkbenchCore/*`
- `apps/macos-app/Sources/OpenSlopApp/*`
- `apps/macos-app/Sources/OpenSlopApprovalProbe/main.swift`
- `apps/macos-app/Sources/OpenSlopTurnProbe/main.swift`
- `plans/slices/S04-transcript-approval-pty/*`

## Reviewer verdicts

### Fast reviewer pass
Reviewer: `Jason the 10th` (`explorer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none for текущего узкого scope.

Non-blocking findings:
- этот коммит закрывает только streaming transcript lane, не весь S04;
- visual check пока semantic-only, потому что screenshot baselines ещё не заведены;
- `session_id == provider_thread_id` остаётся временным законом только для текущего runtime contour.

What is proven:
- bootstrap -> live turn -> successive transcript snapshots -> terminal snapshot проходит end-to-end;
- `core-daemon` reuse удерживает первый turn в живом runtime до materialization;
- cold transcript read после materialization честно возвращает архивный `thread.status.type = notLoaded`;
- contract subset и slice docs синхронизированы с текущим protocol surface.

### Streaming reviewer pass
Reviewer: `Hubble the 10th` (`explorer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none for текущего узкого scope.

Non-blocking findings:
- `selectedEffort` пока UI-only и не влияет на runtime;
- `looksLikeLiveCodexThread` остаётся хрупкой UUID-эвристикой.

What is proven:
- long-lived `core-daemon` stdio держит daemon-owned streaming transcript lane end-to-end;
- `OpenSlopTurnProbe` подтверждает PID reuse, in-progress snapshots и финальный `agent: OK`;
- GUI остаётся thin client и только перерисовывает successive transcript snapshots.

### Native approval reviewer pass
Reviewer: `Parfit the 11th` (`explorer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none для текущего bounded scope.

Non-blocking findings:
- `permissions/requestApproval` пока вне scope и при реальном срабатывании потребует отдельного graceful path;
- approval continuation сейчас живёт в `@State`, так что на резком обрыве стрима возможен edge-case вокруг cleanup;
- visual proof остаётся semantic-only без pixel baseline;
- preflight для `s04-native-approvals` изначально фиксировал `commandExecution`-only, а реализация заодно добавила minimal file-change compatibility.

What is proven:
- `core-daemon` остаётся единственным владельцем живого `codex-submit-turn-stream` runtime;
- provider не теряет server-initiated approval requests и отвечает JSON-RPC response на тот же request id;
- GUI показывает native approval sheet и возвращает решение через `codex-resolve-approval`;
- bounded slice merge-ready по функциональной линии, без притворства что закрыт весь S04.

## Closure note

Следующий честный runtime шаг уже отдельно: PTY, richer command output surface и virtualization. Этот коммит их не симулирует.
