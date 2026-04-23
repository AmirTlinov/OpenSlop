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
- read-only `git-review-snapshot` operation из S06a.
- fail-closed `claude-runtime-status` operation из S05a.
- real non-persistent `claude-turn-proof` operation из S05b.
- read-only `claude-materialize-proof-session` operation из S05c.
- bounded custom Claude receipt prompt validation из S05d.
- read-only Claude receipt detail snapshot из S05e.

Текущая карта ответственности:
- stdio transport между GUI и daemon;
- runtime registry для тех Codex sessions, у которых первый turn ещё не materialized на диск;
- daemon-owned mapping из transcript snapshot в `session_list` summary;
- streaming successive transcript snapshots во время активного turn;
- transport для typed command snapshots без отдельного PTY surface: daemon просто ретранслирует enriched provider snapshot;
- native approval event для активного Codex turn и ожидание решения по тому же stdio transport;
- raw `codex-command-exec-stream` output events и final `codex-command-exec` result без записи этого contour в `session_list`;
- bounded nested `codex-command-exec-control-stream` dialogue для same-connection `write` и `terminate`;
- fail-closed timeout для `codex-command-exec-control-stream`, если follow-up `write/terminate` не пришёл примерно за 5 секунд;
- bounded interactive follow-up control для standalone `codex-command-exec-control-stream`: repeated output-paced `write`, one `closeStdin`, optional `terminate`;
- standalone PTY resize follow-up для того же bounded contour: initial `tty` + `size`, same-connection `resize`, strict `processId` check и дальнейший fail-closed dialogue;
- честные error responses, когда session пережила restart раньше первого completed turn;
- daemon-owned Git snapshot для Inspector: Swift не вызывает `git` сам, а только показывает typed response;
- daemon-owned Claude runtime status: Swift не вызывает `claude` сам и не открывает Claude turn path без bridge proof.
- daemon-owned Claude turn proof: Swift получает typed receipt через `claude-turn-proof`, но GUI dialog/session lifecycle остаются закрыты.
- daemon-owned Claude receipt materialization: successful proof upsert'ится в `session_list` как read-only Claude session, но submit/resume/approval/tools не открываются.
- daemon-owned Claude prompt policy: empty и >512 bytes prompt отклоняются до запуска `claude-bridge`.
- daemon-owned Claude receipt snapshot: latest proof детали лежат в `.openslop/state/claude-receipt-latest.json` и читаются через `claude-receipt-snapshot`; это не transcript/history.
