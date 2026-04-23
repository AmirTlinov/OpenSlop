# core-daemon

`core-daemon` — источник истины для OpenSlop: session projections, provider lifecycle, IPC и дальше event spine.

Сейчас materialized:
- `session_list` projection и persisted store из S02;
- первый live Codex bootstrap lane из S03: `initialize -> thread/start -> session_list materialization`.
