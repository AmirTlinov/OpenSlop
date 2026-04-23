# S05c-claude-receipt-session — read-only Claude receipt session

## Outcome

Дать пользователю первую честную native-shell способность для Claude: создать read-only receipt session из реального bounded Claude turn.

S05c продолжает S05b. Он не открывает Claude chat. Он materialize'ит доказанный receipt в `session_list`, чтобы UI перестал быть только status/probe boundary.

## Touches

- `services/core-daemon`
- `domains/session`
- `domains/provider`
- `apps/macos-app/WorkbenchCore`
- `apps/macos-app/OpenSlopApp`

## Out of scope

- Произвольный Claude chat.
- Claude session resume.
- Native approvals.
- Platform tools через Agent SDK/MCP.
- Tracing handoff.

## Canonical choice for this slice

`claude-materialize-proof-session` запускает реальный S05b proof, делает `upsert_runtime_session` со стабильным id `claude-turn-proof-latest`, а GUI показывает эту session как read-only receipt.
