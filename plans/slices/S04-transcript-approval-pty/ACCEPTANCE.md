# ACCEPTANCE

- `core-daemon` по long-lived stdio transport умеет пройти `thread/start -> live turn -> successive transcript snapshots -> terminal snapshot` без смены daemon PID.
- GUI-кнопка `Отправить` показывает не только финальный ответ, но и хотя бы один in-progress transcript snapshot во время активного turn.
- Во время approval-enabled turn `core-daemon` умеет принять server-initiated approval request от Codex, отдать его в GUI и дождаться решения по тому же stdio transport.
- GUI показывает native approval sheet с минимумом честных деталей: kind, command/cwd или grant-root/reason, и кнопки `Разрешить` / `Отклонить`.
- `OpenSlopApprovalProbe` доказывает живой `commandExecution/requestApproval` и completed turn после approve.
- `OpenSlopTurnProbe` доказывает: daemon process reused, в потоке были streaming snapshots, финальный transcript содержит user prompt и agent final answer `OK`.
- `provider-domain` честно различает две границы lifecycle:
  - до первого turn thread ещё не materialized и требует тот же живой runtime;
  - после materialization cold transcript read возможен, а интерактивный turn идёт через `thread/resume`.
- Текущий live approval proof опирается на turn-level override `approvalPolicy = untrusted` + `sandboxPolicy = readOnly`, потому что default session policy на этой машине возвращает `dangerFullAccess` и сама по себе approval не поднимает.
- Exact schema subset для текущего protocol surface лежит в `domains/provider/contracts/`.
