# ACCEPTANCE

- `core-daemon` по long-lived stdio transport умеет пройти `thread/start -> first turn -> transcript snapshot` без смены daemon PID.
- GUI-кнопка `Отправить` доводит первый live turn до completed и показывает user/agent transcript items.
- Отдельный probe доказывает: daemon process reused, transcript содержит user prompt и agent final answer `OK`.
- `provider-domain` честно различает две границы lifecycle:
  - до первого turn thread ещё не materialized и требует тот же живой runtime;
  - после materialization cold transcript read возможен, а интерактивный turn идёт через `thread/resume`.
- Exact schema subset для текущего protocol surface лежит в `domains/provider/contracts/`.
