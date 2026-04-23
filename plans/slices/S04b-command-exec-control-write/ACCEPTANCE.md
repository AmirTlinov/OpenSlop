# ACCEPTANCE

- В `domains/provider/contracts/codex-app-server/v0.123.0/v2/` лежат:
  - `CommandExecWriteParams.json`
  - `CommandExecTerminateParams.json`
  - `CommandExecResizeParams.json`
- `provider-domain` умеет один bounded same-connection control loop для streaming `command/exec`.
- `core-daemon` умеет `codex-command-exec-control-stream` и nested control dialogue без session-store claims.
- `WorkbenchCore` умеет во время output events отправить follow-up `write` и `terminate`.
- `OpenSlopCommandExecControlProbe` доказывает end-to-end:
  - stable daemon pid;
  - stable client `processId` across output events;
  - live output содержит `READY` и echoed `PING` после follow-up write;
  - final response приходит после follow-up terminate;
  - final `stdout/stderr` остаются пустыми.
- Слайс не заявляет reconnect, transcript readback, PTY pane и доказанный `resize` surface.
