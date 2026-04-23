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
   │  ├─ RepoRootLocator.swift
   │  └─ CoreDaemonClient.swift
   ├─ OpenSlopApp/
   │  ├─ OpenSlopApp.swift
   │  ├─ WorkbenchSeed.swift
   │  ├─ WorkbenchRootView.swift
   │  ├─ SidebarPanelView.swift
   │  ├─ TimelinePanelView.swift
   │  ├─ InspectorPanelView.swift
   │  └─ ComposerBarView.swift
   ├─ OpenSlopProbe/
   │  └─ main.swift
   ├─ OpenSlopCodexProbe/
   │  └─ main.swift
   └─ OpenSlopTurnProbe/
      └─ main.swift
```

Сюда идут задачи про window shell, layout, toolbar, keyboard navigation и рендеринг native surfaces.

Текущий реальный proof target для S04:
- `WorkbenchCore/CoreDaemonClient.swift` держит long-lived stdio transport к `core-daemon --serve-stdio`.
- `WorkbenchRootView` отправляет live turn, получает successive daemon-owned transcript snapshots и не владеет runtime truth.
- `OpenSlopTurnProbe` доказывает reuse daemon PID, streaming progress и наличие user/agent transcript items после completed turn.
