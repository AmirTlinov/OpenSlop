# VISUAL CHECK

## Scope
Проверяем первый semantic reference set для workbench shell и базовые shell affordances.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/workbench-shell-empty.svg`
- `docs/design/reference-images/workbench-shell-live.svg`
- `docs/design/reference-images/workbench-shell-inspector-hidden.svg`

## What was checked
- shell всё ещё читается как `sidebar -> timeline -> inspector -> composer`;
- состояние с видимым и скрытым inspector остаётся понятным;
- sidebar empty state выглядит native и не сводится к серому текстовому хвосту;
- reference images прямо помечены semantic и не выдают себя за screenshot baseline.

## Honest note
Reference images в этом слайсе — semantic wireframes. Они задают анатомию и иерархию, но не заменяют будущий visual-conformance pipeline.
