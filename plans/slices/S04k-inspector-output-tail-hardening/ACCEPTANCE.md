# ACCEPTANCE

- `WorkbenchCore/BoundedOutputTail.swift` materialize'ит shared tail projector с явными полями:
  - `visibleText`,
  - `didClip`,
  - `hiddenLineCount`,
  - `hiddenCharacterCount`,
  - total counts.
- `DaemonCodexTerminalSurfaceProjector` больше не отдаёт inspector весь `item.text` целиком. Он отдаёт bounded tail для live terminal pane.
- `TerminalPaneView` показывает tail summary, если верх реально скрыт, и остаётся read-only/live-only surface.
- `CommandExecControlPaneView` использует тот же bounded renderer для `controlTrail` и `mergedOutput`.
- `WorkbenchSeed` для live terminal command item показывает bounded tail preview и явно отсылает к Inspector вместо полного output dump.
- `OpenSlopTerminalTailProbe` доказывает deterministic clipping на synthetic terminal transcript:
  - large output clips,
  - hidden lines reported,
  - latest lines survive,
  - small output stays untouched.
- `OpenSlopTerminalSurfaceProbe` всё ещё доказывает live end-to-end materialization read-only terminal pane.
- `OpenSlopCommandExecResizeSurfaceProbe` всё ещё доказывает, что bounded renderer не ломает standalone proof pane truth.
