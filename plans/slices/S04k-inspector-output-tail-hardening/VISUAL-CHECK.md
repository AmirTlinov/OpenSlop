# VISUAL CHECK

## Scope
Проверяем bounded tail presentation для terminal-heavy inspector surfaces.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/README.md`

## What was checked
- inspector остаётся вторичной рабочей поверхностью и не превращается в giant dump wall;
- clipped output честно маркируется caption'ом про скрытый верх;
- live terminal command card в timeline выглядит компактнее и отсылает к Inspector;
- standalone proof pane и live terminal pane читаются как родственные native blocks;
- live terminal pane не получил fake prompt, stdin controls или другие ложные affordances.

## Honest note
Пиксельного baseline пока нет. Проверка semantic-only и завязана на смысловую иерархию окна.
