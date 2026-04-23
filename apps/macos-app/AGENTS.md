# macos-app

`apps/macos-app` владеет только UI и view-adapter логикой. Истина runtime не должна утекать сюда.

Карта:
```text
macos-app
├─ AGENTS.md
├─ Package.swift
└─ Sources/OpenSlopApp/
   ├─ OpenSlopApp.swift
   ├─ WorkbenchSeed.swift
   ├─ WorkbenchRootView.swift
   ├─ SidebarPanelView.swift
   ├─ TimelinePanelView.swift
   ├─ InspectorPanelView.swift
   └─ ComposerBarView.swift
```

Сюда идут задачи про window shell, layout, toolbar, keyboard navigation и рендеринг native surfaces.
