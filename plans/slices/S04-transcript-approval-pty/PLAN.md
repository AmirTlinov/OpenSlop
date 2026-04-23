# S04-transcript-approval-pty — First live turn streaming lane

## Outcome
Сделать следующий честный runtime path после bootstrap: пользователь отправляет prompt в живую Codex session, `core-daemon` доводит turn до terminal state и GUI получает daemon-owned successive transcript snapshots во время активного turn.

## Touches
- domains/provider
- domains/session
- services/core-daemon
- apps/macos-app

## Out of scope
- approvals
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
- Checked-in schema subset расширен только до `thread/read`, `thread/resume` и `turn/start`.
