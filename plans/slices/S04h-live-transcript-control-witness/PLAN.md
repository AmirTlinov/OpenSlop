# S04h-live-transcript-control-witness — Raw feasibility witness for live transcript stdin control

## Goal

Проверить на сырой границе `codex app-server`, можно ли использовать live `processId` из `item/commandExecution/terminalInteraction` как мост к `command/exec/write` и `closeStdin` на той же связи.

## Touches

- `domains/provider`
- `plans/slices`
- `Makefile`

## Non-goals

В этот слайс не входят:
- `core-daemon` transport для live transcript stdin control;
- GUI-кнопки `Отправить stdin` для transcript pane;
- `resize`, reconnect, multi-client и full terminal runtime;
- claims про history, ordinary readback и persistence;
- переписывание standalone `command/exec` proof lane.

## Truth surface

Слайс считается честно закрытым, если репозиторий доказывает один из двух фактов:
1. live `processId` из `item/commandExecution/terminalInteraction` действительно принимает `command/exec/write` на той же app-server связи;
2. такой вызов явно отвергается или остаётся честно ambiguous, и docs не притворяются готовым live transcript control bridge.
