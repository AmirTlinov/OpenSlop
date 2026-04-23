# VISUAL CHECK

## Scope
Проверяем эволюцию существующего standalone proof pane в mode-aware inspector surface.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/README.md`

## What was checked
- pane остаётся вторичным inspector surface;
- resize mode не мимикрирует под full terminal app;
- segmented picker читается как bounded proof switch, не как feature zoo;
- кнопки resize mode остаются fixed и не обещают arbitrary geometry control.

## Honest note
Пока semantic visual check. Пиксельного baseline у проекта всё ещё нет.
