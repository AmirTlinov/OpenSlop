# S02 event spine — minimal preflight

## Status
preflight_not_needed

## Scope
Первый честный bounded-шаг S02 — тонкий вертикальный срез `core-daemon -> IPC -> macOS sidebar`.
Цель шага: убрать hardcoded sidebar list из `WorkbenchSeed.preview` и читать tiny session projection из daemon.
Вне scope: полный event log, transcript, artifact/blob path, search и полное закрытие S02.

## What the repo already says
- `ADR-001`: source of truth живёт в `services/core-daemon`, а `apps/macos-app` — IPC client.
- `services/core-daemon/src/main.rs` сейчас умеет только `--heartbeat`.
- `apps/macos-app` сейчас стартует `WorkbenchRootView(seed: .preview)` и кормит sidebar через `ProjectSeed` из `WorkbenchSeed.preview`.
- `plans/slices/S02-event-spine/ACCEPTANCE.md` уже требует: UI читает session list из daemon, session truth переживает restart UI.

## Biggest uncertainty
Не назван источник первой реальной session.
Если это не зафиксировать, proof легко выродится в пустой список, который честно ничего не доказывает.

## Cheap probe result
В репозитории пока не зафиксирован конкретный IPC transport.
Значит следующий ход надо выбирать по самому дешёвому доказуемому пути, не раздувая дизайн.

## Recommended first proof target
Одна daemon-owned session materialized вне UI, доступна как tiny projection по минимальному IPC пути и отображается в sidebar вместо `WorkbenchSeed.preview.projects`.
Timeline, inspector и composer пока можно оставить seeded, чтобы не тащить лишний scope.

## Likely first touched surfaces
- `services/core-daemon/src/main.rs`
- `apps/macos-app/Sources/OpenSlopApp/WorkbenchRootView.swift`
- `apps/macos-app/Sources/OpenSlopApp/SidebarPanelView.swift`
- `apps/macos-app/Sources/OpenSlopApp/WorkbenchSeed.swift`

## Anti-foam guardrail
Не пытаться сейчас закрыть весь S02.
Держать патч узким: только daemon-owned session list projection и её чтение из app.
