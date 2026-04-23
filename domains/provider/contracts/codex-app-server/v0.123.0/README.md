# Codex app-server contract subset — v0.123.0

Это pinned subset реального `codex app-server` контракта для S03, текущего transcript contour S04 и standalone `command/exec` proof lane S04a.

Дата генерации: 2026-04-23  
Проверенный binary: `codex-cli 0.123.0`

Команда источника:

```sh
codex app-server generate-json-schema --out /tmp/openslop-codex-schema
```

В репозиторий положен только slice-owned subset:
- JSON-RPC envelope для line-delimited stdio request/reply;
- `initialize` request/response;
- `thread/start` request/response;
- `thread/read` request/response;
- `thread/resume` request/response;
- `turn/start` request/response.
- standalone `command/exec` request/response;
- `command/exec/outputDelta` notification;
- `ServerRequest` для server-initiated approval requests;
- `ServerNotification` для live transcript overlay;
- `CommandExecutionRequestApproval*`;
- `FileChangeRequestApproval*`.

Этого достаточно для текущего честного contour:
`core-daemon -> codex app-server -> thread/start -> live turn -> successive transcript snapshots -> native approval request -> approval response -> terminal snapshot`.

Важная граница текущего runtime:
- до первого завершённого turn thread ещё не materialized на диск;
- после materialization cold `thread/read` может вернуть архивный `thread.status.type = notLoaded`;
- перед новым интерактивным turn на cold thread нужен `thread/resume`.
- текущий streaming lane строится через daemon-owned polling successive `thread/read` snapshots.

Важная S04-specific реальность:
- approvals приходят server->client request'ами, не transcript-only surface;
- typed command surface опирается на live notifications:
  - `item/started`
  - `item/completed`
  - `item/commandExecution/outputDelta`
  - `item/fileChange/outputDelta`
- на этой машине default thread policy возвращает `sandbox.type = dangerFullAccess`, поэтому сам по себе `approvalPolicy = on-request` не поднимал approval для workspace edits;
- для живого proof target текущий approval-enabled turn идёт через override:
  - `approvalPolicy = "untrusted"`
  - `approvalsReviewer = "user"`
  - `sandboxPolicy = { "type": "readOnly" }`
- live proof для этого шага закреплён на `commandExecution/requestApproval` и показал real approval event для `python3 -c "print(123)"`.
- `item/commandExecution/terminalInteraction` видно в schema, но этот sub-slice сознательно не объявляет его готовым PTY surface.
- Для отделения raw upstream truth от продуктовой boundary добавлен witness:
  - `domains/provider/contracts/codex-app-server/v0.123.0/witnesses/terminal_interaction_witness.py`
  - `make smoke-codex-terminal-interaction-witness`
  - witness идёт напрямую в `codex app-server` по stdio, ловит raw notifications и отвечает только на один вопрос: пришёл ли live `item/commandExecution/terminalInteraction`.
- Этот witness не доказывает готовый PTY UX. Он доказывает более узкий факт: upstream может прислать live `item/commandExecution/terminalInteraction` до нашего provider/core-daemon/gui слоя.
- Важная live-находка от witness на 2026-04-23: `params.stdin` в живом smoke пришёл как `"\n"`. Это значит, что `terminalInteraction` на upstream-уровне уже несёт raw stdin/control traffic и не должен автоматически трактоваться как user-friendly prompt.
- Следующий уже продуктовый шаг поверх witness закрыт отдельно:
  - provider/core-daemon/Swift теперь умеют довозить raw `terminalInteraction` как live `terminalStdin` на существующем `command` item;
  - `make smoke-codex-terminal-interaction` подтверждает этот passthrough end-to-end;
  - ordinary readback не используется как источник истины для этого сигнала и в текущем live proof вообще вернул `readback_command_items=0`.

Важная S04a-specific реальность:
- `command/exec` живёт вне `thread/start`, `turn/start`, transcript snapshot и `session_list` truth.
- Текущий repo-local subset закреплён файлами:
  - `v2/CommandExecParams.json`
  - `v2/CommandExecResponse.json`
  - `v2/CommandExecOutputDeltaNotification.json`
- Buffered `command/exec` возвращает `stdout`, `stderr` и `exitCode` в final response.
- Streaming `command/exec` шлёт `command/exec/outputDelta` как connection-scoped notifications; streamed bytes не дублируются в final response.
- Текущий продуктовый proof для этого contour ограничен строго:
  - `provider-domain` поднимает свежий `codex app-server`, делает `initialize`, вызывает standalone `command/exec`;
  - `core-daemon` ретранслирует raw output deltas наружу по своему stdio transport;
  - `WorkbenchCore` и `OpenSlopCommandExecProbe` доказывают buffered и streaming semantics;
  - write / resize / terminate, reconnect, transcript readback и PTY pane сюда пока не заявлены.
- Текущий proof не заявляет long-running guarantee сверх локального timeout window этого слайса. Для действительно долгих интерактивных процессов нужен отдельный PTY/runtime slice.

Важная S04b-specific реальность:
- follow-up control для `command/exec` живёт только на той же связи и на том же client-supplied `processId`;
- в pinned subset теперь лежат и:
  - `v2/CommandExecWriteParams.json`
  - `v2/CommandExecTerminateParams.json`
  - `v2/CommandExecResizeParams.json`
- текущий product proof этого шага всё ещё узкий:
  - доказан same-connection `write` и `terminate`;
  - `resize` пока только pinned в contract subset и явно не объявлен доказанным surface;
  - control dialogue сейчас bounded и proof-owned, без reconnect и без background PTY registry claims.
