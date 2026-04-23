# S04f-command-exec-control-timeout-law — Fail-closed timeout for missing control follow-up

## Goal

Закрыть честную дыру shipped proof surface из S04e: если inspector pane не прислал ожидаемый `write` или `terminate`, standalone `codex-command-exec-control-stream` не должен молча виснуть бесконечно.

## Touches

- `services/core-daemon`
- `apps/macos-app`
- `plans/slices`

## Non-goals

В этот слайс не входят:
- full terminal runtime;
- outbound control для live transcript lane;
- `resize`;
- reconnect и multi-client;
- arbitrary control order;
- новый provider contract.

## Truth surface

Слайс честно закрыт, если репозиторий доказывает четыре факта:
1. `core-daemon` завершает standalone control lane явной ошибкой, если follow-up `write` или `terminate` не пришёл примерно за 5 секунд;
2. error message доезжает до GUI как явный fail-closed сигнал;
3. уже доказанный contour `READY -> write -> PING -> terminate` не ломается;
4. docs и UI не выдают этот watchdog за general-purpose terminal safety story.
