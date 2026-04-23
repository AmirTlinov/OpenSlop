# ACCEPTANCE

- `WorkbenchCore/CodexTerminalSurface.swift` materialize'ит `DaemonCodexTerminalSurface` только когда transcript item:
  - kind=`command`,
  - имеет non-empty `processId`,
  - имеет non-empty `terminalStdin`.
- `InspectorPanelView` показывает `TerminalPaneView` как отдельный native блок внутри inspector.
- `TerminalPaneView` честно пишет, что surface read-only/live-only, показывает:
  - command,
  - process id,
  - raw `stdin` marker,
  - aggregated output,
  - optional exit code.
- `OpenSlopTerminalSurfaceProbe` доказывает end-to-end:
  - хотя бы один streamed snapshot materialize'ит terminal surface;
  - final streamed transcript тоже materialize'ит terminal surface;
  - ordinary readback terminal surface не materialize'ит;
  - surface держит stable `itemId`, non-empty `processId`, non-empty `terminalStdin`, non-empty live output и final output с `DONE`.
- Слайс не заявляет interactive control, `resize`, reconnect, multi-client и virtualization.
