# VISUAL CHECK

## Scope
Проверяем streaming transcript lane, typed command card и native approval sheet внутри уже существующей native anatomy.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/README.md`

## What was checked
- sidebar остаётся навигацией по session list;
- центр остаётся timeline/transcript surface;
- inspector остаётся вторичным контекстом;
- composer остаётся нижней командной строкой;
- streaming snapshots не превращают GUI в transport dump.
- command activity читается отдельной карточкой с monospaced detail и вторичной meta-строкой для `PTY` / `exit`;
- raw terminal passthrough показывается только как escaped secondary marker вроде `stdin raw "\n"` и не выглядит как человеческий prompt;
- command output не смешивается с assistant prose в один bubble;
- approval показывается как отдельный native sheet, а не как inline JSON или transport dump;
- sheet даёт короткое решение: `Разрешить` / `Отклонить`, без псевдо-терминального шума.

## Honest note
Пиксельных reference-images в проекте пока нет. Для этого шага visual check сделан по смысловой анатомии и native поведению, не по screenshot baseline.
