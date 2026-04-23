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

Этого достаточно для текущего честного contour:
`core-daemon -> codex app-server -> thread/start -> first live turn -> read-only transcript snapshot`.

Важная граница текущего runtime:
- до первого завершённого turn thread ещё не materialized на диск;
- после materialization cold `thread/read` может вернуть архивный `thread.status.type = notLoaded`;
- перед новым интерактивным turn на cold thread нужен `thread/resume`.
