# Codex app-server contract subset — v0.123.0

Это pinned subset реального `codex app-server` контракта для S03.

Дата генерации: 2026-04-23  
Проверенный binary: `codex-cli 0.123.0`

Команда источника:

```sh
codex app-server generate-json-schema --out /tmp/openslop-codex-schema
```

В репозиторий положен только slice-owned subset:
- JSON-RPC envelope для line-delimited stdio request/reply;
- `initialize` request/response;
- `thread/start` request/response.

Этого достаточно для текущего честного куска S03:
`core-daemon -> codex app-server -> initialize -> thread/start -> session_list materialization`.
