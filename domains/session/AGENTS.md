# session

Назначение: Threads, turns, transcript timeline, active state, resume, fork и PTY linkage.

Когда идти сюда:
- Когда меняется lifecycle сессий, canonical events, transcript model или active turn behavior.
- Когда daemon materializes session projections и session truth surfaces.

Соседи: provider, artifact, approval, verify

Карта:
```text
session
├─ AGENTS.md
├─ docs/
│  └─ context.mmd
├─ .agents/skills/
│  ├─ SKILLS.md
│  └─ event-spine/SKILL.md
└─ rust/
   └─ session-domain/
      ├─ Cargo.toml
      └─ src/lib.rs
```

Текущее состояние:
- S02 materializes первый настоящий persisted session projection path.
- `rust/session-domain` держит bootstrap sessions, SQLite-backed persisted truth и rehydration.
- Session store живёт в repo-local runtime path `.openslop/state/session-store.sqlite3`.
- Domain-local skill package фиксирует локальные инварианты этого slice.
