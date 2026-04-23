# Task preflight

## Goal
Выбрать следующий честный bounded slice после закрытого `S04c-command-exec-negative-law`, не обещая то, чего repo ещё не доказал.

## Constraints
- `S04-transcript-approval-pty` ещё `in progress`.
- Уже доказаны: streaming transcript, native approvals, typed command surface, raw terminalInteraction witness, live terminalInteraction passthrough, standalone/same-connection `command/exec` proof и negative law.
- Не доказаны и не должны притворяться доказанными: multi-client, reconnect, PTY pane, proven `resize`, full interactive PTY runtime.

## Decision-shaping questions
1. Следующий ход остаётся внутри `S04`, чтобы материализовать первый product surface поверх уже доказанного live terminal signal, или честнее переключиться на другой top-level slice вроде `S05`?
2. Если идти дальше внутри `S04`, следующий bounded шаг — это read-only PTY surface на уже существующем live signal, или сразу интерактивный control lane (`write/terminate/resize`) в product UI?
3. Нужна ли virtualization как первый шаг, или она честно идёт сразу после появления отдельного terminal surface с реальной нагрузкой?
4. Должен ли следующий slice опираться на существующий live turn/transcript contour, или на отдельный `command/exec` proof lane вне transcript truth?

## Cheap probe
`rg -n "resize|PTY pane|terminal pane|reconnect|multi-client" apps services domains plans/slices/S04*`

Что probe подтвердил сейчас:
- `resize` implementation не найдена в `apps/`, `services/` и `domains/`;
- claims про `PTY pane`, `reconnect` и `multi-client` встречаются только как explicit non-claims / pending;
- `plans/slices/S04-transcript-approval-pty/STATUS.md` и `REVIEW.md` называют pending именно `PTY product surface и virtualization`.

## Verdict
Следующий честный slice сейчас — не `S05` и не virtualization-first.

Брать узкий `S04`-sub-slice: первый product surface для PTY как read-only/live-only terminal pane поверх уже доказанного `terminalStdin` / `processId` contour, без claims про reconnect, multi-client, proven `resize` и full interactive control.

Interactive stdin/write/terminate UI и настоящий `resize` лучше оставить следующим шагом после этого, когда появится честная product surface и отдельный visual/probe proof для неё.
