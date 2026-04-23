# S05a-claude-runtime-status — Claude runtime boundary

## Outcome

Доказать первый честный Claude contour: локальный Claude Code runtime найден или не найден, bridge возвращает typed status, `core-daemon` отдаёт этот status в GUI, а интерфейс не притворяется, что Claude turns уже реализованы.

## Touches

- `domains/provider`
- `services/claude-bridge`
- `services/core-daemon`
- `apps/macos-app`

## Out of scope

- Claude turn streaming.
- Session mirror/resume внутри OpenSlop.
- Native approval bridge для Claude.
- Tracing handoff.
- Custom platform tools через Agent SDK.

## Canonical choice for this slice

S05a использует локальный Claude Code CLI как discovery boundary. Полный Agent SDK bridge остаётся S05b+, потому что сначала нужна честная runtime-видимость без fake chat UI.
