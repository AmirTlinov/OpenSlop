# S01e workbench IA reset

## Outcome

OpenSlop перестаёт выглядеть как инженерный proof-пульт. Первый экран становится спокойным workbench: sidebar ведёт по задачам, composer владеет выбором агента/модели, inspector показывает план и следы без fake browser/verify tabs.

## Ownership

- `apps/macos-app` владеет только shell, layout и view-adapter логикой.
- Runtime truth остаётся в `core-daemon` и существующих projections.
- Planned browser/harness/verify surfaces не показываются как primary UI.

## Boundaries

В slice не входят daemon-owned active plan projection, file heat map, browser preview и полноценный Claude chat. Они остаются следующими слайсами.
