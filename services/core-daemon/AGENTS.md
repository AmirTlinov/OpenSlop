# core-daemon

`core-daemon` — источник истины для OpenSlop: session projections, provider lifecycle, IPC и дальше event spine.

Сейчас materialized:
- `session_list` projection и persisted store из S02;
- live Codex bootstrap lane из S03;
- daemon-owned streaming transcript lane из текущего шага S04.
- nested stdio approval dialogue для live Codex turns из текущего approval sub-slice S04.
- typed `commandExecution` transcript surface поверх того же streaming contour.
- standalone connection-scoped `command/exec` proof lane из S04a.
- bounded same-connection `command/exec` control proof lane из S04b.

Текущая карта ответственности:
- stdio transport между GUI и daemon;
- runtime registry для тех Codex sessions, у которых первый turn ещё не materialized на диск;
- daemon-owned mapping из transcript snapshot в `session_list` summary;
- streaming successive transcript snapshots во время активного turn;
- transport для typed command snapshots без отдельного PTY surface: daemon просто ретранслирует enriched provider snapshot;
- native approval event для активного Codex turn и ожидание решения по тому же stdio transport;
- raw `codex-command-exec-stream` output events и final `codex-command-exec` result без записи этого contour в `session_list`;
- bounded nested `codex-command-exec-control-stream` dialogue для same-connection `write` и `terminate`;
- честные error responses, когда session пережила restart раньше первого completed turn.
