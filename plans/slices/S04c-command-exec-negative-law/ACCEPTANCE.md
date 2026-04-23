# ACCEPTANCE

- `core-daemon` unit tests доказывают:
  - wrong `processId` для `write` даёт error и wait-loop принимает следующий correct `write`;
  - wrong `processId` для `terminate` даёт error и wait-loop принимает следующий correct `terminate`;
  - standalone `codex-command-exec-write` и `codex-command-exec-terminate` вне active control stream отвергаются.
- `WorkbenchCore` имеет bounded witness surface для control-stream, где error response можно увидеть и ответить следующим control request без перезапуска daemon connection.
- `OpenSlopCommandExecControlNegativeProbe` доказывает end-to-end:
  - stable daemon pid;
  - stable correct `processId` across output events;
  - wrong `write` и wrong `terminate` оба получают ожидаемые error messages;
  - после каждого wrong follow-up тот же live lane принимает correct follow-up;
  - live output содержит `READY` и echoed `PING`;
  - final `stdout/stderr` остаются пустыми.
- Слайс не заявляет multi-client law, reconnect semantics, PTY pane и proven `resize`.
