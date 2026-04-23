# Codex app-server contract subset — v0.123.0

Это pinned subset реального `codex app-server` контракта для S03 и текущего узкого шага S04.

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
- `ServerRequest` для server-initiated approval requests;
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
- на этой машине default thread policy возвращает `sandbox.type = dangerFullAccess`, поэтому сам по себе `approvalPolicy = on-request` не поднимал approval для workspace edits;
- для живого proof target текущий approval-enabled turn идёт через override:
  - `approvalPolicy = "untrusted"`
  - `approvalsReviewer = "user"`
  - `sandboxPolicy = { "type": "readOnly" }`
- live proof для этого шага закреплён на `commandExecution/requestApproval` и показал real approval event для `python3 -c "print(123)"`.
