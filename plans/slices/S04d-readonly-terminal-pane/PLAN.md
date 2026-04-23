# S04d-readonly-terminal-pane — First live-only terminal pane in native inspector

## Goal

Materialize первый честный PTY product surface внутри GUI: read-only/live-only terminal pane в inspector поверх уже доказанного streamed transcript contour, где есть `processId`, raw `terminalStdin` и command output.

## Touches

- `apps/macos-app`
- `plans/slices/S04-transcript-approval-pty`

## Non-goals

В этот слайс не входят:
- interactive stdin control;
- `write` / `terminate` / `resize` UI;
- reconnect и multi-client claims;
- persistence claim для terminal pane через ordinary readback;
- virtualization.

## Truth surface

Слайс честно закрыт, если репозиторий доказывает четыре факта:
1. `WorkbenchCore` materialize'ит отдельный terminal surface только из streamed transcript, когда есть non-empty `processId` и `terminalStdin`;
2. native inspector показывает terminal pane отдельно от command card и не смешивает его с agent prose;
3. terminal pane остаётся read-only/live-only и сам пишет об этом в UI;
4. ordinary readback не притворяется владельцем этого surface.
