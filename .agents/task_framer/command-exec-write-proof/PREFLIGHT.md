# Task preflight

## Goal

Доказать следующий честный control fact после S04a: один standalone `command/exec` с client-supplied `processId` принимает follow-up `command/exec/write` на той же связи, отдаёт ожидаемый `outputDelta` и затем завершается через follow-up `terminate`, без transcript/session truth claims.

## Constraints

Нельзя притворяться готовым PTY runtime, reconnect, multi-process registry или terminal pane.
Нельзя выдавать `resize` за доказанный surface раньше живого write-lane.
Нельзя писать этот contour в `session_list` или session store.

## Decision-shaping questions

1. Что сейчас важнее доказать: сам факт same-connection follow-up write или уже общую control surface для `write|terminate|resize`?
2. Где минимальная честная граница transport shape: proof-specific nested dialogue или полноценный background control registry?
3. Какой самый узкий сценарий устойчив к ложной уверенности и не требует PTY: `write + terminate` сейчас или сначала `write + closeStdin`?

## Cheap probe

Сверить live schema `CommandExecWriteParams`, `CommandExecTerminateParams`, `CommandExecResizeParams` и убедиться, что узкое место уже не в контракте, а в connection ownership и transport shape.

## Local verdict

Следующий честный слайс — не весь control plane. Следующий честный слайс — bounded same-connection `write + terminate` proof lane.

`resize` честен только после живого control channel и не должен быть первым target.
