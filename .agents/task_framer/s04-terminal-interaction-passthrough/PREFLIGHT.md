# S04 terminal interaction passthrough — preflight

## Scope verdict
Честный следующий шаг внутри S04 — read-only live passthrough для `item/commandExecution/terminalInteraction`.

Граница жёсткая:
- без PTY pane;
- без `write` / `resize` / `kill`;
- без обещания replay после `thread/read` и cold read.

## Вопросы, которые реально меняют решение

1. Это live-only overlay или уже новая persisted truth surface?
   Сейчас ответ: только live-only overlay.

2. Минимальная форма — новый item kind или допполе у существующего `command` item?
   Сейчас ответ: допполе у существующего `command` item. Это не разрывает transcript model лишней сущностью.

3. Показывать ли raw `stdin` как есть?
   Сейчас ответ: да, но только в escaped виде, чтобы control traffic не выглядел пустотой или “человеческим prompt”.

4. Нужен ли сразу terminal UI?
   Сейчас ответ: нет. Достаточно довести сигнал до Swift transcript model и дать минимальный visible marker в command card.

## Cheap probe

Один live smoke:
- поймать `terminalInteraction` в streaming transcript;
- убедиться, что он приклеен к тому же `command` item;
- потом сделать обычный `fetchCodexTranscript` и проверить, что `terminalStdin` не replay'ится как архивная truth.

## Cheap probe result

Live proof подтвердил честную форму этого шага:
- final streamed transcript держит `terminalStdin`;
- ordinary readback не держит `terminalStdin`;
- в текущем живом прогоне ordinary readback вообще вернул `readback_command_items=0`, поэтому claims остаются строго live-only.
