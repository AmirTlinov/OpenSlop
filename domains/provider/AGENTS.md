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
- `rust/provider-domain` владеет двумя честными путями:
  - live bootstrap + first turn через живой runtime registry;
  - cold transcript read и resume перед новым интерактивным turn после materialization.
- Важная граница: до первого completed turn thread ещё не materialized на диск.
