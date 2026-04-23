# ACCEPTANCE

- `core-daemon` по long-lived stdio transport умеет пройти `thread/start -> live turn -> successive transcript snapshots -> terminal snapshot` без смены daemon PID.
- GUI-кнопка `Отправить` показывает не только финальный ответ, но и хотя бы один in-progress transcript snapshot во время активного turn.
- `OpenSlopTurnProbe` доказывает: daemon process reused, в потоке были streaming snapshots, финальный transcript содержит user prompt и agent final answer `OK`.
- `provider-domain` честно различает две границы lifecycle:
  - до первого turn thread ещё не materialized и требует тот же живой runtime;
  - после materialization cold transcript read возможен, а интерактивный turn идёт через `thread/resume`.
- Exact schema subset для текущего protocol surface лежит в `domains/provider/contracts/`.
