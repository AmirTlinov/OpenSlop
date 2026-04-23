# S02-event-spine — Event spine

## Outcome
Построить первый честный event-spine path: core-daemon отдаёт daemon-owned `session_list` projection, probe и macOS shell читают её и UI показывает реальные sessions вместо hardcoded sidebar списка.

## Touches
- services/core-daemon
- domains/session
- apps/macos-app
- tools/repo-lint

## Out of scope
- Полный event bus.
- Долгоживущие subscriptions.
- Настоящий thread/turn persistence beyond this first projection.
- Browser, diff и verify integrations.
