# core-daemon

`core-daemon` — источник истины для OpenSlop: session projections, provider lifecycle, IPC и дальше event spine.

Сейчас materialized:
- `session_list` projection и persisted store из S02;
- live Codex bootstrap lane из S03;
- daemon-owned streaming transcript lane из текущего шага S04.
- nested stdio approval dialogue для live Codex turns из текущего approval sub-slice S04.

Текущая карта ответственности:
- stdio transport между GUI и daemon;
- runtime registry для тех Codex sessions, у которых первый turn ещё не materialized на диск;
- daemon-owned mapping из transcript snapshot в `session_list` summary;
- streaming successive transcript snapshots во время активного turn;
- native approval event для активного Codex turn и ожидание решения по тому же stdio transport;
- честные error responses, когда session пережила restart раньше первого completed turn.
