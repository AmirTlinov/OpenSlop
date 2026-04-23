# S04g-command-exec-bounded-interactive-stdin — Bounded standalone interactive stdin proof lane

## Goal

Расширить уже доказанный standalone `command/exec` control contour от fixed `one-write -> terminate` proof к более честной bounded interactive семантике: repeated output-paced `write`, один `closeStdin`, optional `terminate`, всё ещё вне transcript truth.

## Touches

- `services/core-daemon`
- `apps/macos-app`
- `plans/slices`

## Non-goals

В этот слайс не входят:
- live transcript control transport;
- full terminal runtime;
- reconnect и multi-client;
- `resize`;
- kill как отдельный более сильный contract;
- persistence claim для interactive stdin trail.

## Truth surface

Слайс честно закрыт, если репозиторий доказывает четыре факта:
1. standalone `codex-command-exec-control-stream` принимает repeated output-paced `write` requests, один `closeStdin` и optional `terminate`;
2. native pane показывает честный `stdin trail`, live output и bounded control affordances;
3. fail-closed timeout из S04f не теряется;
4. docs и UI не притворяются live transcript terminal control или full PTY runtime.
