# S02-event-spine — Event spine

## Outcome
Построить первый честный event-spine path целиком для `session_list`: daemon-owned persisted session truth живёт в repo-local store, core-daemon отдаёт rehydrated projection, app и probe говорят с ним через long-lived local stdio IPC, а UI показывает реальные sessions вместо hardcoded sidebar списка.

## Touches
- services/core-daemon
- domains/session
- apps/macos-app
- tools/repo-lint

## Out of scope
- Полный event bus.
- Unix socket transport.
- Настоящий thread/turn persistence beyond `session_list`.
- Browser, diff и verify integrations.
