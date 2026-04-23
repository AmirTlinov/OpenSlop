# VISUAL CHECK

## Scope
Проверяем только текущую read-only transcript lane внутри уже существующей native anatomy.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/README.md`

## What was checked
- sidebar остаётся навигацией по session list;
- центр остаётся timeline/transcript surface;
- inspector остаётся вторичным контекстом;
- composer остаётся нижней командной строкой;
- transcript rows не превращают GUI в transport dump.

## Honest note
Пиксельных reference-images в проекте пока нет. Для этого шага visual check сделан по смысловой анатомии и native поведению, не по screenshot baseline.
