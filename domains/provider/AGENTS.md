# provider

Назначение: Provider registry, capability snapshots, app-server contracts и provider-specific adapters.

Когда идти сюда:
- Когда интегрируется Codex, Claude или следующий движок.
- Когда нужен exact protocol subset или version pinning для provider boundary.

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
- Materialized exact contract subset для `initialize` и `thread/start` на `codex-cli 0.123.0`.
- `rust/provider-domain` владеет первым live Codex bootstrap lane через app-server stdio.
