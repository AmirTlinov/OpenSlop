# S04h live transcript control witness — preflight

## Scope verdict
Следующий честный шаг после read-only terminal pane — не мост в GUI control и не новый PTY runtime.

Нужно проверить один узкий вопрос на сырой границе `codex app-server`: можно ли тем же `processId`, который приходит в live `item/commandExecution/terminalInteraction`, управлять через `command/exec/write` и `closeStdin`.

## Вопросы, которые реально меняют решение

1. Можно ли строить live transcript stdin control поверх уже доказанного standalone `command/exec/write`?
   Сейчас ответ: неизвестно, пока raw witness не попробует это на том же app-server connection.

2. Если `command/exec/write` отвергнет такой `processId`, что это меняет?
   Это сразу режет ложный следующий шаг. Значит текущий live transcript pane остаётся read-only по upstream-правде.

3. Если raw witness даст success, надо ли сразу тащить это в GUI?
   Нет. Сначала нужен bounded bridge slice без claims про history, reconnect, resize и persistence.

## Cheap probe

Запустить `codex app-server` напрямую, дождаться live `item/commandExecution/terminalInteraction`, затем на той же связи отправить:
- `command/exec/write(deltaBase64="PING\n")`
- `command/exec/write(closeStdin=true)`

и зафиксировать один из честных исходов:
- confirmed;
- rejected;
- ambiguous.
