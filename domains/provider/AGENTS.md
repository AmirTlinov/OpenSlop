# provider

Назначение: Provider registry, capability snapshots, app-server contracts и provider-specific adapters.

Когда идти сюда:
- Когда интегрируется Codex, Claude или следующий движок.
- Когда нужен exact protocol subset или version pinning для provider boundary.
- Когда нужно разрулить session lifecycle на provider-стороне: bootstrap, cold read, resume, turn.

Соседи: session, approval, browser, verify

Карта:
```text
provider
├─ AGENTS.md
├─ docs/
│  └─ context.mmd
├─ contracts/
│  └─ codex-app-server/
│     └─ v0.123.0/
└─ rust/
   └─ provider-domain/
```

Текущее состояние:
- Materialized exact contract subset для `initialize`, `thread/start`, `thread/read`, `thread/resume` и `turn/start` на `codex-cli 0.123.0`.
- В pinned subset теперь лежит и `ServerNotification.json`, потому что текущий runtime опирается на live notifications для typed command surface.
- `rust/provider-domain` владеет двумя честными путями:
  - live bootstrap + streaming turn через живой runtime registry;
  - cold transcript read и resume перед новым интерактивным turn после materialization.
- В S04 добавлен server-request lane для native approvals:
  - парсятся `item/commandExecution/requestApproval` и `item/fileChange/requestApproval`;
  - provider отвечает JSON-RPC response на тот же server request id;
  - unsupported `item/permissions/requestApproval` пока вне scope этого шага.
- В следующем sub-slice S04 provider перестал терять `commandExecution`-правду:
  - live `item/started`, `item/completed`, `item/commandExecution/outputDelta` и `item/fileChange/outputDelta` накладываются на successive snapshots;
  - `command`, optional `processId`, optional `exitCode` и aggregated output доходят до GUI как typed transcript items;
  - `item/commandExecution/terminalInteraction` пока сознательно не materialized в продуктовый PTY lane.
- Важная граница: до первого completed turn thread ещё не materialized на диск.
- Ещё одна важная граница: на этой машине default Codex thread стартует с `dangerFullAccess`, поэтому approval-enabled turn для живого proof сейчас делает turn-level override на `approvalPolicy = untrusted` и `sandboxPolicy = readOnly`.
