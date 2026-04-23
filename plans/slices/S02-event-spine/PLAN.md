# S02-event-spine — Event spine

## Outcome
Построить первый честный event-spine path и сразу убрать главный remaining blocker этого шага: core-daemon держит daemon-owned `session_list` projection, app и probe говорят с ним через long-lived local stdio IPC, а UI показывает реальные sessions вместо hardcoded sidebar списка.

## Touches
- services/core-daemon
- domains/session
- apps/macos-app
- tools/repo-lint

## Out of scope
- Полный event bus.
- Unix socket transport.
- Настоящий thread/turn persistence beyond this first projection.
- Browser, diff и verify integrations.
