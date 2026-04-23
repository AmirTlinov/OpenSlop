# Task preflight

## Goal
Выбрать следующий честный bounded slice после закрытого `S04d-readonly-terminal-pane`, не притворяясь full terminal runtime.

## Constraints
- read-only/live-only terminal pane по streamed transcript уже done;
- standalone `command/exec` streaming и same-connection `write` / `terminate` proof уже done;
- `core-daemon` control lane пока bounded и proof-shaped;
- не доказаны: reconnect, resize, multi-client, transcript readback для standalone exec.

## Decision-shaping questions
1. Следующий шаг должен оставаться внутри transcript contour, или честнее уже раскрыть отдельный standalone `command/exec` product surface?
2. Можно ли прямо сейчас честно сделать full interactive terminal, или текущий daemon contour тянет только guided control lane?
3. Что даст пользователю видимый прирост уже сейчас, не обещая нового runtime закона?

## Cheap probe
Быстрый reread текущих surfaces показал:
- transcript terminal pane уже есть, но он live-only и lossy;
- standalone `command/exec` control lane уже доказан end-to-end;
- `core-daemon` всё ещё ждёт bounded follow-up contour, не общий async terminal runtime.

## Verdict
Следующий честный slice — guided standalone `command/exec` control pane в inspector.

Он должен:
- запускать standalone exec вне session/transcript truth;
- показывать live output и stable `processId`;
- честно вести пользователя через текущий bounded contour: один `write`, потом один `terminate`;
- не обещать resize, reconnect и full terminal runtime.
