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
   └─ OpenSlopProbe/
      └─ main.swift
```

Сюда идут задачи про window shell, layout, toolbar, keyboard navigation и рендеринг native surfaces.

Текущий реальный proof target для S02:
- `WorkbenchCore/CoreDaemonClient.swift` читает session projection из `target/debug/core-daemon`.
- `OpenSlopProbe` использует тот же путь без GUI.
- `WorkbenchRootView` показывает реальный session list вместо hardcoded sidebar списка.
