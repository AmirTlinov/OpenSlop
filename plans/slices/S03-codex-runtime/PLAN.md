# S03-codex-runtime — Codex bootstrap lane

## Outcome
Сделать первый честный live Codex path через app-server: `core-daemon` поднимает `codex app-server`, проходит `initialize`, вызывает `thread/start` и materialize-ит реальную Codex-thread в `session_list` projection.

## Touches
- domains/provider
- domains/session
- services/core-daemon
- apps/macos-app

## Out of scope
- `turn/start` и streaming timeline
- native approvals UI
- `thread/resume` / `thread/fork`
- `command/exec` и PTY
- полная нормализация событий

## Canonical choice for this slice
- Canonical `session_id` пока равен `provider_thread_id` Codex.
- Happy-path proof идёт через локальный `codex-cli 0.123.0`.
- Missing-binary и runtime failures обязаны выходить как daemon-owned error response.
- Schema pinning в этом шаге узкая: checked-in exact contract subset для `initialize` и `thread/start`.
