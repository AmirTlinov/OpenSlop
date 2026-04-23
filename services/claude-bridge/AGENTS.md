# claude-bridge

Boundary код для Claude runtime. Доменные решения остаются в `domains/provider` и `domains/session`.

Карта:
```text
claude-bridge
├─ AGENTS.md
├─ package.json
└─ bin/
   └─ claude-bridge.mjs
```

Текущее состояние:
- S05a реализует только `status --json` для локального Claude Code CLI.
- Bridge проверяет `claude --version` и `claude --help`, возвращает `claude_runtime_status`.
- Full turn streaming, session mirror, native approvals, tracing и Agent SDK tools пока planned.

Owning slice: `S05-claude-runtime`, текущий sub-slice `S05a-claude-runtime-status`.
