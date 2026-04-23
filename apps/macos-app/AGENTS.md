# macos-app

`apps/macos-app` владеет только UI и view-adapter логикой. Истина runtime не должна утекать сюда.

Карта:
```text
macos-app
├─ AGENTS.md
├─ Package.swift
└─ Sources/
   ├─ WorkbenchCore/
   │  ├─ SessionProjection.swift
   │  ├─ CodexSessionBootstrap.swift
   │  ├─ CodexTranscriptSnapshot.swift
   │  ├─ CodexApprovalRequest.swift
   │  ├─ BoundedOutputTail.swift
   │  ├─ WorkbenchShellState.swift
   │  ├─ WorkbenchTimelineEmptyState.swift
   │  ├─ CodexCommandExec.swift
   │  ├─ CodexCommandExecControlSurface.swift
   │  ├─ CodexTerminalSurface.swift
   │  ├─ GitReviewSnapshot.swift
   │  ├─ ClaudeRuntimeStatus.swift
   │  ├─ ClaudeTurnProofResult.swift
   │  ├─ ClaudeProofSessionMaterialization.swift
   │  ├─ ClaudeReceiptPromptPolicy.swift
   │  ├─ ClaudeReceiptSnapshot.swift
   │  ├─ RepoRootLocator.swift
   │  └─ CoreDaemonClient.swift
   ├─ OpenSlopApp/
   │  ├─ OpenSlopApp.swift
   │  ├─ WorkbenchSeed.swift
   │  ├─ WorkbenchRootView.swift
   │  ├─ WorkbenchStartSurfaceView.swift
   │  ├─ WorkbenchLayoutGeometryBridge.swift
   │  ├─ ApprovalSheetView.swift
   │  ├─ MonospacedTailBlockView.swift
   │  ├─ CommandExecControlPaneView.swift
   │  ├─ GitReviewPaneView.swift
   │  ├─ TerminalPaneView.swift
   │  ├─ ClaudeRuntimeStatusView.swift
   │  ├─ SidebarPanelView.swift
   │  ├─ TimelinePanelView.swift
   │  ├─ InspectorPanelView.swift
   │  └─ ComposerBarView.swift
   ├─ OpenSlopProbe/
   │  └─ main.swift
   ├─ OpenSlopCodexProbe/
   │  └─ main.swift
   ├─ OpenSlopApprovalProbe/
   │  └─ main.swift
   ├─ OpenSlopTurnProbe/
   │  └─ main.swift
   ├─ OpenSlopTerminalInteractionProbe/
   │  └─ main.swift
   ├─ OpenSlopTerminalSurfaceProbe/
   │  └─ main.swift
   ├─ OpenSlopTerminalTailProbe/
   │  └─ main.swift
   ├─ OpenSlopShellStateProbe/
   │  └─ main.swift
   ├─ OpenSlopTimelineEmptyStateProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecControlProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecControlSurfaceProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecControlNegativeProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecControlTimeoutProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecInteractiveProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecResizeProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecResizeSurfaceProbe/
   │  └─ main.swift
   ├─ OpenSlopGitReviewProbe/
   │  └─ main.swift
   ├─ OpenSlopClaudeStatusProbe/
   │  └─ main.swift
   ├─ OpenSlopClaudeTurnProofProbe/
   │  └─ main.swift
   ├─ OpenSlopClaudeReceiptSessionProbe/
   │  └─ main.swift
   ├─ OpenSlopClaudeCustomReceiptProbe/
   │  └─ main.swift
   └─ OpenSlopClaudeReceiptSnapshotProbe/
      └─ main.swift
```

Сюда идут задачи про window shell, layout, toolbar, keyboard navigation и рендеринг native surfaces.

Текущий реальный proof target для S04 sub-slices:
- `WorkbenchCore/CoreDaemonClient.swift` держит long-lived stdio transport к `core-daemon --serve-stdio`.
- `WorkbenchRootView` отправляет live turn, получает successive daemon-owned transcript snapshots, показывает native approval sheet и не владеет runtime truth.
- `WorkbenchCore/WorkbenchShellState.swift` держит app-owned shell state для selection/provider/effort/inspector visibility и не лезет в runtime truth.
- `WorkbenchSeed` и `TimelinePanelView` различают `agent`, `command`, `fileChange` и generic `tool`, чтобы command output не превращался в текстовый суп.
- `SidebarPanelView` уже materialize'ит native empty state для пустого session list, а shell actions получили keyboard path для refresh/start/submit/toggle inspector.
- `OpenSlopShellStateProbe` доказывает save/load/reconcile для persisted shell state без запуска window automation.
- `OpenSlopTurnProbe` доказывает reuse daemon PID, streaming progress и наличие user/agent transcript items после completed turn.
- `OpenSlopApprovalProbe` доказывает live `commandExecution` approval request, typed command transcript item и completed turn после approve.
- `WorkbenchCore` теперь держит и standalone `command/exec` DTO + client methods для buffered и streaming proof lane.
- `OpenSlopCommandExecProbe` доказывает отдельный contour: buffered final stdout/stderr, streaming output events с client-supplied `processId` и пустой final `stdout/stderr` после streaming.
- `OpenSlopCommandExecControlProbe` доказывает следующий law: one same-connection streaming exec принимает follow-up `write`, echo'ит `PING`, потом завершается через follow-up `terminate`.
- `WorkbenchCore/CodexTerminalSurface.swift` materialize'ит первый read-only/live-only terminal surface только из streamed transcript, когда есть `processId` и raw `terminalStdin`.
- `TerminalPaneView` показывает этот surface в inspector как честный live-only pane без stdin control, resize и reconnect claims.
- Отдельный raw witness на provider boundary уже показал текущий upstream reject для `live processId -> command/exec/write`, поэтому transcript terminal pane остаётся read-only не по осторожности, а по доказанной границе.
- `WorkbenchCore/CodexCommandExecControlSurface.swift` теперь держит более честную UI truth как `controlTrail`: live output, stable `processId`, stage `awaitingControl`, resize / stdin / terminate markers и final exit.
- `CommandExecControlPaneView` теперь даёт два fixed proof mode:
  - `Interactive stdin`
  - `PTY resize`
  При этом pane остаётся bounded proof surface и не притворяется full terminal UI.
- `OpenSlopCommandExecControlSurfaceProbe` доказывает, что GUI surface и probe share one same-connection proof contour с `READY -> PING -> terminate`.
- `OpenSlopCommandExecControlTimeoutProbe` доказывает fail-closed contour: если GUI не прислал ожидаемый follow-up control, lane падает примерно за 5 секунд и не зависает молча.
- `OpenSlopCommandExecInteractiveProbe` доказывает следующий contour: `READY -> PING-1 -> PING-2 -> closeStdin -> CLOSED`, zero exit и честный `stdin trail`.
- `OpenSlopCommandExecResizeProbe` отдельно доказывает PTY contour: `tty=true`, initial `80x24`, same-connection `resize -> 100x40`, затем `write+closeStdin`, и процесс сам печатает новую геометрию.
- `OpenSlopCommandExecResizeSurfaceProbe` доказывает уже app-owned surface truth для resize mode: `controlTrail="[resize 100x40]\\nPING\\n[close-stdin]\\n"` и completed stage.
- `WorkbenchCore/BoundedOutputTail.swift` даёт shared bounded tail projector для terminal-heavy monospaced surfaces. Это app-owned presentation hardening, не новая runtime truth.
- `TerminalPaneView` и `CommandExecControlPaneView` рендерят inspector output через bounded tail block и честно помечают скрытый верх, когда clipping реально сработал.
- `WorkbenchSeed` для live terminal command item держит timeline компактнее: вместо полного dump показывает bounded tail preview и отсылает к Inspector.
- `OpenSlopTerminalTailProbe` доказывает deterministic clipping на synthetic terminal transcript и сохраняет последние строки без порчи маленького вывода.
- Важная граница остаётся честной: resize mode теперь materialized в inspector только как fixed proof surface. Он не превращён в arbitrary terminal UI и не пробивает transcript contour.

- `WorkbenchLayoutGeometryBridge.swift` держит узкий AppKit/SwiftUI мост для observed shell geometry. Он остаётся только native layout persistence.
- `OpenSlopShellStateProbe` доказывает shell layout geometry save/load/sanitize и legacy default restore.

- `WorkbenchTimelineEmptyStateProjector` строит center empty/unavailable state только из existing shell truth. Он запрещает synthetic S04/proof-storytelling в пустом timeline.
- `OpenSlopTimelineEmptyStateProbe` доказывает no-session, empty-transcript, unavailable-transcript и live-transcript nil-empty-state paths.

- `WorkbenchCore/GitReviewSnapshot.swift` и `GitReviewPaneView.swift` materialize S06a read-only Git review surface. UI показывает daemon snapshot и не вызывает Git напрямую.
- `OpenSlopGitReviewProbe` доказывает dirty fixture, selected file preview, non-git warning и no-mutation law.

- `WorkbenchStartSurfaceView.swift` materializes S01d native start/composer surface. It is presentation-only and does not add runtime truth.
- `InspectorPanelView` now has Summary / Verify / Browser tabs. Browser and Verify tabs are honest planned/pre-harness surfaces, not live feature claims.

- `WorkbenchCore/ClaudeRuntimeStatus.swift`, `ClaudeRuntimeStatusView.swift` и `OpenSlopClaudeStatusProbe` materialize S05a: GUI показывает только real Claude runtime status boundary и не открывает fake Claude turns.
- `WorkbenchCore/ClaudeTurnProofResult.swift` и `OpenSlopClaudeTurnProofProbe` materialize S05b: один реальный non-persistent Claude turn проходит через daemon. GUI dialog для Claude всё ещё закрыт.
- `WorkbenchCore/ClaudeProofSessionMaterialization.swift` и `OpenSlopClaudeReceiptSessionProbe` materialize S05c: Claude receipt можно создать как read-only session summary. Submit/dialog/resume для Claude остаются закрыты.
- `WorkbenchCore/ClaudeReceiptPromptPolicy.swift` и `OpenSlopClaudeCustomReceiptProbe` materialize S05d: пользовательский bounded Claude receipt prompt проходит через daemon-owned validation и real proof, но full Claude lifecycle остаётся закрыт.
- `WorkbenchCore/ClaudeReceiptSnapshot.swift` и `OpenSlopClaudeReceiptSnapshotProbe` materialize S05e: selected Claude receipt session читает daemon-owned latest snapshot и показывает реальные proof bounds в timeline/inspector.
