# S04j-command-exec-resize-pane — Native fixed resize proof mode in inspector

## Goal

Поднять уже доказанный standalone PTY resize contour в настоящий нативный inspector surface: один fixed proof mode для `80x24 -> 100x40`, без открытия arbitrary terminal UI и без transcript bridge claim.

## Touches

- `apps/macos-app`
- `plans/slices`
- `ROADMAP.md`

## Non-goals

В этот слайс не входят:
- новый runtime law в provider/core-daemon;
- arbitrary rows/cols controls;
- transcript stdin/resize bridge;
- full terminal runtime;
- general-purpose command editor.

## Truth surface

Слайс закрыт честно, если репозиторий доказывает четыре факта:
1. inspector pane даёт выбрать fixed proof mode `Interactive stdin` или `PTY resize`;
2. shared surface truth materialize'ится как `controlTrail`, а resize живёт там как first-class control marker;
3. resize mode даёт только fixed follow-up actions: `resize 100x40`, потом `stdin + close`;
4. `OpenSlopCommandExecResizeSurfaceProbe` подтверждает end-to-end, что GUI/shared surface держат честный resize witness без притворства full terminal UI.
