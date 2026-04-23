# ACCEPTANCE

- Shell state хранит `windowWidth`, `windowHeight`, `sidebarWidth`, `inspectorWidth`.
- Старый persisted state без `layout` грузится с безопасной default geometry.
- Unsafe geometry sanitizes до documented bounds.
- Main window получает initial default size из persisted shell state.
- Sidebar и inspector получают persisted preferred widths.
- Observed window/sidebar/inspector widths пишутся обратно в local shell state.
- Geometry остаётся app-owned shell state и не уходит в runtime truth.
- `make smoke-shell-state` зелёный.
