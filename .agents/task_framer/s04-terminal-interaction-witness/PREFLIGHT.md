# S04 terminal interaction witness — preflight

## Scope verdict
Следующий честный шаг внутри S04 — не PTY UI и не `command/exec`, а raw witness на границе `codex app-server`.

Нужно доказать один факт: живой upstream вообще шлёт `item/commandExecution/terminalInteraction` в `turn/start` contour или нет.

## Вопросы, которые реально меняют решение

1. Это шаг только про доказательство live `terminalInteraction`, или уже про полноценный PTY control path?
   Сейчас ответ: только про доказательство. Это держит слайс маленьким и честным.

2. Если live runtime не даст `terminalInteraction`, мы продолжаем S04 или режем PTY claims и уходим в отдельный `command/exec` lane?
   Сейчас ответ: режем claims и не притворяемся PTY surface.

3. Если live runtime даст `terminalInteraction`, где теряется сигнал: в upstream или уже в provider/core-daemon/gui boundary?
   Сейчас ответ: это и должен отделить raw witness.

## Cheap probe

Запустить `codex app-server` напрямую по stdio, дать turn с командой:

`python3 -c "print('READY'); input(); print('DONE')"`

и смотреть только raw notification stream.

## Cheap probe result

Живой ad-hoc probe на этой машине уже увидел:

- `item/commandExecution/outputDelta`
- `item/commandExecution/terminalInteraction`

Это сразу сузило развилку: upstream сигнал существует. Потеря находится уже после raw app-server boundary.
