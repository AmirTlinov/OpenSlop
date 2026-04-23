# S04e-command-exec-control-pane — Guided standalone `command/exec` proof pane

## Goal

Дать первый нативный product surface для already-proven same-connection `command/exec` control lane: отдельный inspector pane, который запускает fixed proof command, показывает live output и честно проводит пользователя через текущий bounded contour `write -> terminate`.

## Touches

- `apps/macos-app`
- `plans/slices`

## Non-goals

В этот слайс не входят:
- full interactive terminal runtime;
- reconnect и multi-client;
- `resize`;
- session/transcript truth для standalone exec;
- transcript readback claim;
- arbitrary control order.

## Truth surface

Слайс честно закрыт, если репозиторий доказывает четыре факта:
1. native inspector умеет запустить fixed standalone proof command вне session/transcript truth;
2. pane показывает stable `processId`, live output и текущий control stage;
3. pane честно ведёт bounded contour: один `write`, потом один `terminate`;
4. docs и UI не притворяются general-purpose exec surface, full terminal runtime, reconnect или resize surface.
