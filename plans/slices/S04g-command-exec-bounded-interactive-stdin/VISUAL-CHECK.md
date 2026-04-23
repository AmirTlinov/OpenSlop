# VISUAL CHECK

## Scope
Проверяем эволюцию существующего standalone proof pane в более интерактивный bounded surface.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/README.md`

## What was checked
- pane остаётся вторичным inspector surface и не выглядит как отдельное terminal приложение;
- `stdin trail` читается как proof evidence, не как fake shell history;
- control buttons остаются bounded: write, close stdin, terminate;
- supporting copy честно говорит про fixed output-paced proof command и не обещает live transcript control.

## Honest note
Пока semantic visual check. Пиксельного baseline у проекта всё ещё нет.
