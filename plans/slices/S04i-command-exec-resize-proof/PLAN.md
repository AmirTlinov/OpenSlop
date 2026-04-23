# S04i-command-exec-resize-proof — Standalone PTY resize proof lane

## Goal

Доказать один узкий law внутри уже существующего standalone `command/exec-control` contour: PTY-backed `command/exec` на той же связи принимает `resize`, и живой процесс действительно видит новую геометрию.

## Touches

- `domains/provider`
- `services/core-daemon`
- `apps/macos-app`
- `plans/slices`

## Non-goals

В этот слайс не входят:
- live transcript stdin / resize bridge;
- general-purpose terminal runtime;
- reconnect, multi-client и background PTY registry;
- resize affordance в inspector pane;
- window-coupled drag resize, repaint claims и visual terminal fidelity.

## Truth surface

Слайс закрыт честно, если репозиторий доказывает четыре факта:
1. provider-domain умеет передать `tty=true`, initial `size` и follow-up `command/exec/resize` в pinned Codex contract;
2. `core-daemon` принимает `codex-command-exec-resize` только внутри `codex-command-exec-control-stream` и продолжает bounded dialogue fail-closed;
3. `WorkbenchCore` умеет сериализовать resize request без product claim про transcript control;
4. `OpenSlopCommandExecResizeProbe` показывает marker-based PTY witness: процесс видит `SIZE1:80x24`, потом `SIZE2:100x40`, потом `READ:PING`, а lane завершается `exit=0`.

## Proof note

PTY output в этом contour может дробиться и эхо-контрольные байты приходят не так чисто, как в предыдущем stdio proof. Поэтому resize witness использует marker-first command и не делает fake promise про clean terminal transcript.
