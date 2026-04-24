# workspace

Назначение: Рабочие корни, project profiles, worktrees, preview targets и provider defaults.

Когда идти сюда:
- Когда задача касается открытия проекта, выбора worktree, project-level preferences или preview routing.

Соседи: session, git, browser, harness

Карта:
```text
workspace
├─ AGENTS.md
├─ docs/
│  └─ context.mmd
└─ rust/workspace-domain/
   └─ src/active_plan.rs
```

Текущее состояние:
- Материализована карта домена.
- `workspace-domain` держит repo-level active plan projection из `ROADMAP.md` и `plans/slices/*`.
- Эта projection не является live verify/harness truth. Она показывает состояние slice-документов.
