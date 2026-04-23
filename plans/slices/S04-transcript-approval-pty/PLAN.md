# S04-transcript-approval-pty — Streaming transcript + native approval lane

## Outcome
Сделать следующий честный runtime path после bootstrap: пользователь отправляет prompt в живую Codex session, `core-daemon` доводит turn до terminal state, GUI получает daemon-owned successive transcript snapshots во время активного turn, умеет ответить на живой Codex approval request через native sheet и больше не теряет typed `commandExecution`-правду внутри transcript surface.

## Touches
- domains/provider
- domains/session
- services/core-daemon
- apps/macos-app

## Out of scope
- PTY и `command/exec`
- virtualized rendering и scale-polish
- Claude parity

## Canonical choice for this slice
- `session_id` пока совпадает с `provider_thread_id` Codex.
- Новый bootstrap session получает status `needs_first_turn`.
- Первый turn обязан завершиться в том же живом daemon runtime, где session была создана. До этого rollout ещё не materialized на диск.
- После первого завершённого turn cold `thread/read` разрешён и может вернуть архивный `thread.status.type = notLoaded`.
- Перед новым интерактивным turn на cold thread нужен `thread/resume`.
- Текущий streaming contour делается через daemon-owned polling successive `thread/read` snapshots, не через push token-deltas и не через GUI-owned polling.
- Текущий approval contour делается через server-initiated JSON-RPC request lane. `core-daemon` во время активного streaming turn пишет approval event наружу и ждёт решение по тому же stdio transport.
- Typed command surface идёт внутри уже существующего transcript contour: provider слушает live notifications, накладывает их на successive `thread/read` snapshots и не открывает отдельный PTY transport раньше времени.
- Для живого proof approval-enabled turn идёт через turn-level override:
  - `approvalPolicy = "untrusted"`
  - `approvalsReviewer = "user"`
  - `sandboxPolicy = { "type": "readOnly" }`
- В текущем sub-slice закрыт `commandExecution/requestApproval` и совместимый minimal mapping для `fileChange/requestApproval`. `permissions/requestApproval` пока вне scope.
- В текущем sub-slice закрыт typed `commandExecution` transcript surface:
  - live `item/started`, `item/completed`, `item/commandExecution/outputDelta` и `item/fileChange/outputDelta` больше не теряются;
  - optional `processId` и `exitCode` доезжают до GUI;
  - timeline показывает command card отдельно от agent prose.
