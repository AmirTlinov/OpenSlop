# S04a-command-exec-proof — Standalone `command/exec` proof lane

## Goal

Закрыть отдельный честный contour для standalone `command/exec` через `provider-domain -> core-daemon -> WorkbenchCore -> probe` без притворства transcript lane, session truth или PTY UX.

## Touches

- `domains/provider`
- `services/core-daemon`
- `apps/macos-app`

## Non-goals

В этот слайс не входят:
- `command/exec/write`, `resize`, `terminate`;
- reconnect и readback;
- transcript materialization;
- отдельный terminal pane;
- запись этого contour в `session_list` или session store.

## Truth surface

Слайс считается честно закрытым, если репозиторий доказывает два факта:
1. buffered `command/exec` возвращает `stdout`, `stderr` и `exitCode` в final response;
2. streaming `command/exec` шлёт connection-scoped `outputDelta` с client-supplied `processId`, а final response после этого держит только `exitCode` и пустые `stdout/stderr`.
