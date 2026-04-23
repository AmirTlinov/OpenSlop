# Task preflight

## Goal
Проверить, честен ли следующий узкий шаг после S04: raw `command/exec` proof через provider -> core-daemon без PTY pane и без write/resize/kill UI.

## Constraints
Нельзя притворяться новым persistent terminal lane, reconnect, transcript readback или готовым PTY UX. Нужен один proof slice с ясной границей и живой проверкой.

## Decision-shaping questions
1. Не путаем ли мы thread-bound `commandExecution` contour из S04 со standalone connection-scoped `command/exec` lane?
2. Что должно быть доказано first-class: daemon-owned live exec transport или уже user-facing terminal UX?
3. Какая минимальная truth surface остаётся честной, если `command/exec/outputDelta` живёт только на исходном соединении, а финальный response пустеет при streaming?

## Cheap probe
Сверить живую schema `codex app-server generate-json-schema` и repo subset: есть ли уже pinned contract для `command/exec` request/response, и где именно зашиты connection-scoped / final-response semantics.

## Local verdict
Главный риск ложной уверенности: принять raw `command/exec` за естественное продолжение transcript lane. Это другой контур. Он standalone, connection-scoped и без readback.

Следующим стоит доказать не PTY, а более узкий факт: `core-daemon` может владеть одним live `command/exec` вызовом, сохранить границу процесса и честно довести `outputDelta` + final `exitCode` до своего API без claims про reconnect, persistence и terminal UI.
