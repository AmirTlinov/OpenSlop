# VISUAL-CHECK

Дата: 2026-04-23

## Scope

Семантическая visual-сверка seed-shell в `apps/macos-app/Sources/OpenSlopApp/WorkbenchRootView.swift` против `DESIGN.md`.

## Что проверено

- Есть четыре главные поверхности окна: `sidebar`, `timeline`, `inspector`, `composer`.
- Верхняя панель уже задаёт native toolbar grammar: provider switcher и короткие actions.
- Центральная часть построена как workbench, а не как giant chat wall.
- `timeline` и `inspector` разведены в разные поверхности через split layout.
- `composer` живёт отдельно в нижней панели и не смешан с transcript.
- Seed-shell использует SwiftUI как shell layer. Это соответствует текущему архитектурному решению S00.

## Что ещё сознательно не закрыто

- Нет runtime screenshot baseline. Это отложено в `S01-workbench-shell`.
- Нет AppKit-heavy surfaces. Это следующая зрелость, не цель S00.
- Нет настоящих browser/diff/verify tabs. S00 фиксирует только анатомию оболочки.

## Verdict

Для S00 visual shape честный и достаточный: seed-shell уже следует `DESIGN.md` по смыслу и не притворяется финальным GUI.
