# ACCEPTANCE

- `core-daemon` по long-lived stdio transport умеет пройти `thread/start -> live turn -> successive transcript snapshots -> terminal snapshot` без смены daemon PID.
- GUI-кнопка `Отправить` показывает не только финальный ответ, но и хотя бы один in-progress transcript snapshot во время активного turn.
- Во время approval-enabled turn `core-daemon` умеет принять server-initiated approval request от Codex, отдать его в GUI и дождаться решения по тому же stdio transport.
- GUI показывает native approval sheet с минимумом честных деталей: kind, command/cwd или grant-root/reason, и кнопки `Разрешить` / `Отклонить`.
- Во время tool-using turn provider перестаёт схлопывать `commandExecution` в generic `tool`: command, output, optional `processId` и optional `exitCode` проходят end-to-end.
- GUI показывает `commandExecution` отдельной timeline-карточкой с monospaced detail, не смешивая command output с agent prose.
- `OpenSlopApprovalProbe` доказывает живой `commandExecution/requestApproval`, typed command transcript item и completed turn после approve.
- `OpenSlopTurnProbe` доказывает: daemon process reused, в потоке были streaming snapshots, финальный transcript содержит user prompt и agent final answer `OK`.
- `provider-domain` честно различает две границы lifecycle:
  - до первого turn thread ещё не materialized и требует тот же живой runtime;
  - после materialization cold transcript read возможен, а интерактивный turn идёт через `thread/resume`.
- `provider-domain` честно использует live notification overlay только как надстройку над существующим `thread/read -> successive snapshots` contour. Отдельный PTY lane сюда ещё не притворяется.
- Raw witness `domains/provider/contracts/codex-app-server/v0.123.0/witnesses/terminal_interaction_witness.py` умеет напрямую проверить upstream `item/commandExecution/terminalInteraction` без участия provider/core-daemon/gui.
- `provider-domain` умеет приклеить raw `item/commandExecution/terminalInteraction` к уже существующему `command` item как optional `terminalStdin`, не смешивая его с `aggregatedOutput`.
- Swift transcript model и command card умеют показать этот сигнал как escaped raw marker, не выдавая его за user-friendly terminal prompt.
- `OpenSlopTerminalInteractionProbe` доказывает end-to-end: хотя бы один in-progress streamed snapshot и final streamed transcript держат `terminalStdin`, ordinary readback не держит `terminalStdin`, а live passthrough остаётся строго read-only.
- `WorkbenchCore` умеет materialize'ить отдельный read-only/live-only terminal surface из streamed transcript только при наличии `processId` и `terminalStdin`.
- native inspector умеет показать terminal pane отдельно от command card, не выдавая его за interactive terminal.
- `OpenSlopTerminalSurfaceProbe` доказывает end-to-end: streamed transcript materialize'ит terminal surface, final streamed transcript тоже, ordinary readback — нет.
- Текущий live approval proof опирается на turn-level override `approvalPolicy = untrusted` + `sandboxPolicy = readOnly`, потому что default session policy на этой машине возвращает `dangerFullAccess` и сама по себе approval не поднимает.
- Exact schema subset для текущего protocol surface лежит в `domains/provider/contracts/`.

## Closure boundary

S04 считается закрытым на current ceiling: live transcript, native approvals, typed command transcript, terminalInteraction passthrough и read-only/live-only terminal pane. Interactive transcript terminal control не заявляется, потому что raw same-connection witness уже показал current upstream reject для `processId -> command/exec/write`. Virtualization не является S04 acceptance blocker.
