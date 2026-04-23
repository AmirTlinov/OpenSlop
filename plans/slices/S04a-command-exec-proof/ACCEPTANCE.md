# ACCEPTANCE

- В `domains/provider/contracts/codex-app-server/v0.123.0/v2/` лежат:
  - `CommandExecParams.json`
  - `CommandExecResponse.json`
  - `CommandExecOutputDeltaNotification.json`
- `provider-domain` умеет buffered `command/exec` без session/thread lifecycle.
- `provider-domain` умеет streaming `command/exec` с raw output events и client-supplied `processId`.
- `core-daemon` по long-lived stdio transport умеет:
  - `codex-command-exec`
  - `codex-command-exec-stream`
- `WorkbenchCore` умеет декодировать final result и output events этого contour.
- `OpenSlopCommandExecProbe` доказывает end-to-end:
  - buffered exec сохраняет `stdout` и `stderr` в final response;
  - streaming exec получает output events на одном `processId`;
  - streaming final response оставляет `stdout` и `stderr` пустыми.
- Слайс не делает claims про write / resize / terminate / reconnect / transcript readback / PTY pane.
