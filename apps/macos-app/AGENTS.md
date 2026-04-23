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
   │  ├─ CodexCommandExec.swift
   │  ├─ CodexCommandExecControlSurface.swift
   │  ├─ CodexTerminalSurface.swift
   │  ├─ RepoRootLocator.swift
   │  └─ CoreDaemonClient.swift
   ├─ OpenSlopApp/
   │  ├─ OpenSlopApp.swift
   │  ├─ WorkbenchSeed.swift
   │  ├─ WorkbenchRootView.swift
   │  ├─ ApprovalSheetView.swift
   │  ├─ CommandExecControlPaneView.swift
   │  ├─ TerminalPaneView.swift
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
   ├─ OpenSlopCommandExecProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecControlProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecControlSurfaceProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecControlTimeoutProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecInteractiveProbe/
   │  └─ main.swift
   ├─ OpenSlopCommandExecResizeProbe/
   │  └─ main.swift
   └─ OpenSlopCommandExecResizeSurfaceProbe/
      └─ main.swift
```

Сюда идут задачи про window shell, layout, toolbar, keyboard navigation и рендеринг native surfaces.

Текущий реальный proof target для S04 sub-slices:
- `WorkbenchCore/CoreDaemonClient.swift` держит long-lived stdio transport к `core-daemon --serve-stdio`.
- `WorkbenchRootView` отправляет live turn, получает successive daemon-owned transcript snapshots, показывает native approval sheet и не владеет runtime truth.
- `WorkbenchSeed` и `TimelinePanelView` различают `agent`, `command`, `fileChange` и generic `tool`, чтобы command output не превращался в текстовый суп.
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
- Важная граница остаётся честной: resize mode теперь materialized в inspector только как fixed proof surface. Он не превращён в arbitrary terminal UI и не пробивает transcript contour.
