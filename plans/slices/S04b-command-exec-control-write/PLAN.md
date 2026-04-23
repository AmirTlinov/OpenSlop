# S04b-command-exec-control-write — Same-connection write + terminate proof lane

## Goal

Доказать следующий честный control law после S04a: standalone streaming `command/exec` с client-supplied `processId` принимает follow-up `command/exec/write` и `command/exec/terminate` на той же живой связи через `provider-domain -> core-daemon -> WorkbenchCore -> probe`.

## Touches

- `domains/provider`
- `services/core-daemon`
- `apps/macos-app`

## Non-goals

В этот слайс не входят:
- PTY pane;
- reconnect и readback;
- transcript/session truth;
- background control registry вне bounded proof dialogue;
- `resize` как доказанный surface.

## Truth surface

Слайс честно закрыт, если репозиторий доказывает четыре факта:
1. live streaming `command/exec` с `streamStdin=true` и client `processId` держится на той же связи;
2. follow-up `command/exec/write` доезжает mid-flight и меняет live output;
3. follow-up `command/exec/terminate` доезжает на той же связи и завершает process;
4. весь contour остаётся вне `session_list`, transcript truth и reconnect claims.
