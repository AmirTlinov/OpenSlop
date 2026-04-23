# git

Назначение: Repo status, branches, worktrees, diff materialization и patch review facts.

Когда идти сюда:
- Когда меняется review pane, branch awareness, staged files или worktree model.

Соседи: workspace, artifact, harness

Карта:
```text
git
├─ AGENTS.md
├─ docs/
│  └─ context.mmd
└─ rust/
   └─ git-domain/
      ├─ Cargo.toml
      └─ src/
         ├─ lib.rs
         └─ review_snapshot.rs
```

Текущее состояние:
- S06a materialized первый read-only `GitReviewSnapshot`.
- Домен владеет Git snapshot contract: branch/head, dirty state, changed files, bounded diff и bounded file preview.
- Snapshot только читает Git/worktree и не stage/commit/write.
- Artifact registry, worktree/session binding и full patch lifecycle остаются planned parent S06 work.
