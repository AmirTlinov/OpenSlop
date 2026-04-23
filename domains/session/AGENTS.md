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
- S05c добавляет read-only Claude receipt session summary через `upsert_runtime_session`; это не full Claude dialog lifecycle.
- S05d сохраняет тот же singleton session id для custom receipt prompt. Это latest receipt, не история Claude turns.
- S05e добавляет detail snapshot для этого singleton id. `session_list` остаётся summary, детали читаются отдельным daemon query.
