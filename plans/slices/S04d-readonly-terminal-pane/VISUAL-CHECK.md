# VISUAL CHECK

## Scope
Проверяем первый read-only/live-only terminal pane внутри уже существующей native anatomy.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/README.md`

## What was checked
- terminal pane живёт внутри inspector и не ломает базовую схему `sidebar -> timeline -> inspector -> composer`;
- pane выглядит как вторичный контекст, не как главный transcript surface;
- pane не притворяется интерактивным терминалом: нет fake prompt, stdin control и resize affordances;
- raw stdin показывается отдельно и явно как escaped marker;
- output читается монопространственно и не смешивается с карточкой command item;
- рядом с pane есть ясная live-only note про ordinary readback.

## Honest note
Пиксельного baseline пока нет. Для этого шага visual check semantic-only и привязан к native анатомии.
