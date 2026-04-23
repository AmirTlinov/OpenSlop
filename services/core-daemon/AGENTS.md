# core-daemon

`core-daemon` — источник истины для OpenSlop: session projections, provider lifecycle, IPC и дальше event spine.

Сейчас materialized:
- `session_list` projection и persisted store из S02;
- live Codex bootstrap lane из S03;
- первый live turn round-trip из текущего шага S04.

Текущая карта ответственности:
- stdio transport между GUI и daemon;
- runtime registry для тех Codex sessions, у которых первый turn ещё не materialized на диск;
- daemon-owned mapping из transcript snapshot в `session_list` summary;
- честные error responses, когда session пережила restart раньше первого completed turn.
