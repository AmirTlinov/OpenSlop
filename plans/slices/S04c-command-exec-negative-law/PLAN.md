# S04c-command-exec-negative-law — Wrong `processId` rejection without lane collapse

## Goal

Доказать следующий честный negative law после S04b: live `codex-command-exec-control-stream` отвергает wrong `processId` для `write` и `terminate`, не отдаёт ложный control и продолжает ждать правильный follow-up на той же живой связи.

## Touches

- `services/core-daemon`
- `apps/macos-app`

## Non-goals

В этот слайс не входят:
- multi-client shared runtime claims;
- reconnect и readback;
- PTY pane;
- `resize` как доказанный runtime surface;
- новые session/transcript truth claims.

## Truth surface

Слайс честно закрыт, если репозиторий доказывает четыре факта:
1. wrong `processId` для `codex-command-exec-write` внутри active control dialogue получает явный error и не захватывает lane;
2. после этого correct `write` на той же связи всё ещё доезжает и меняет live output;
3. wrong `processId` для `codex-command-exec-terminate` тоже получает явный error, после чего correct `terminate` на той же связи завершает process;
4. standalone `write/terminate` вне `codex-command-exec-control-stream` остаются запрещённым contour и не притворяются cross-connection law.
