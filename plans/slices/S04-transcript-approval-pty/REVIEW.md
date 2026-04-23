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

S04 пока не закрыт целиком. Исторически здесь уже были закрыты live passthrough для raw `item/commandExecution/terminalInteraction` и первый read-only/live-only terminal pane в inspector. Interactive terminal control и virtualization всё ещё pending.

Typed `commandExecution` transcript surface и raw upstream witness уже были закрыты раньше в этом же slice.

## Local evidence

- `cargo test -p provider-domain` -> PASS
- `cargo test -p core-daemon` -> PASS
- `cargo build -p core-daemon` -> PASS
- `swift build --package-path apps/macos-app` -> PASS
- `swift run --package-path apps/macos-app OpenSlopTurnProbe` -> PASS
- `swift run --package-path apps/macos-app OpenSlopApprovalProbe` -> PASS
- `swift run --package-path apps/macos-app OpenSlopTerminalInteractionProbe` -> PASS
- `swift run --package-path apps/macos-app OpenSlopTerminalSurfaceProbe` -> PASS
- `make smoke-codex-turn` -> PASS
- `make smoke-codex-approval` -> PASS
- `make smoke-codex-terminal-interaction-witness` -> PASS
- `make smoke-codex-terminal-interaction` -> PASS
- `make smoke-codex-terminal-surface` -> PASS

## Changed surfaces

- `.agents/task_framer/s04-live-turn-resume/PREFLIGHT.md`
- `.agents/task_framer/s04-streaming-transcript/PREFLIGHT.md`
- `.agents/task_framer/s04-native-approvals/PREFLIGHT.md`
- `.agents/task_framer/next-slice-after-s04/preflight.md`
- `.agents/task_framer/s04-next-slice/PREFLIGHT.md`
- `.agents/task_framer/s04-terminal-interaction-witness/PREFLIGHT.md`
- `.agents/task_framer/s04-terminal-interaction-passthrough/PREFLIGHT.md`
- `domains/provider/rust/provider-domain/src/lib.rs`
- `domains/provider/contracts/codex-app-server/v0.123.0/*`
- `services/core-daemon/src/main.rs`
- `apps/macos-app/Sources/WorkbenchCore/*`
- `apps/macos-app/Sources/OpenSlopApp/*`
- `apps/macos-app/Sources/OpenSlopApprovalProbe/main.swift`
- `apps/macos-app/Sources/OpenSlopTerminalInteractionProbe/main.swift`
- `apps/macos-app/Sources/OpenSlopTurnProbe/main.swift`
- `apps/macos-app/Package.swift`
- `plans/slices/S04-transcript-approval-pty/*`
- `Makefile`
- `plans/slices/S04-transcript-approval-pty/diagrams/terminal-interaction-witness.mmd`
- `plans/slices/S04-transcript-approval-pty/diagrams/terminal-interaction-passthrough.mmd`
- `domains/provider/contracts/codex-app-server/v0.123.0/witnesses/terminal_interaction_witness.py`

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

### Typed command surface reviewer pass
Reviewer: `Kepler the 13th` (`reviewer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none для текущего bounded scope.

Non-blocking findings:
- visual proof остаётся semantic-only без screenshot baseline;
- до усиления probe живой fail-closed proof для `processId` и `exitCode` был слабее acceptance. После reviewer pass probe усилен и теперь валится, если эти поля исчезнут.

What is proven:
- provider больше не схлопывает `commandExecution` в generic tool и накладывает live overlay поверх successive snapshot contour;
- Swift transcript mirror принимает `command`, `processId`, `exitCode`, а timeline рисует command отдельно от assistant prose;
- scope не уехал в PTY: runtime слушает только `item/started`, `item/completed`, `item/commandExecution/outputDelta`, `item/fileChange/outputDelta`, без `command/exec/*` и без terminal pane;
- живой `OpenSlopApprovalProbe` подтверждает `transcript_contains_command=true`, `transcript_has_process_id=true`, `transcript_has_exit_code=true`, `contains_done=true`, `final_turn=completed`.

### Terminal interaction witness reviewer pass
Reviewer: `Pasteur the 13th` (`reviewer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none для текущего bounded scope.

Non-blocking findings:
- README/PLAN не должны трактовать FAIL witness как доказанное отсутствие сигнала навсегда; это только negative run.
- текущий repo-local proof для `params.stdin` закреплён на живом значении `"\n"`. Более экзотические значения стоит утверждать только с сохранённым артефактом.

What is proven:
- raw witness идёт в правильной boundary и отделяет upstream `codex app-server` truth от продуктового provider/core-daemon/gui gap;
- `make smoke-codex-terminal-interaction-witness` проходит и подтверждает, что `codex app-server 0.123.0` может слать live `item/commandExecution/terminalInteraction`;
- repo-local live proof показал raw `params.stdin = "\n"`, значит это уже upstream stdin/control traffic, а не автоматически user-friendly prompt;
- sub-slice честно не притворяется PTY UI, stdin/write API, resize, kill или reconnect surface.

### Terminal interaction passthrough reviewer pass
Reviewer: `Cicero the 14th` (`reviewer`, 2026-04-23)

Verdict: PASS

Blocking findings:
- none для текущего bounded scope.

Non-blocking findings:
- UI surface доказан кодом и semantic visual check, но без отдельного visual witness.
- текущее представление `terminalStdin` сознательно lossy для будущего PTY lane: repeated chunks склеиваются, empty chunks отбрасываются.

What is proven:
- provider-domain парсит `item/commandExecution/terminalInteraction` и вешает `terminalStdin` на существующий `command` item, не смешивая его с output;
- merge держит это поле внутри live overlay и не вводит новый transcript item kind;
- Swift transcript model принимает `terminalStdin`, а command card показывает escaped marker вроде `stdin raw "\n"` как secondary detail;
- live smoke подтверждает честную live-only картину: stable command item id, stable process id, raw payload `"\n"`, ordinary readback без `terminalStdin`;
- после reviewer pass probe усилен: теперь он требует не только final streamed transcript, но и хотя бы один промежуточный streamed snapshot с `terminalStdin`.

## Closure note

Первый read-only/live-only terminal pane теперь уже materialized отдельным sub-slice. Следующий честный runtime шаг уже уже отдельно: interactive stdin/write/resize/kill и virtualization.
