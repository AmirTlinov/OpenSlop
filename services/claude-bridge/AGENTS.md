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
- S05a реализует `status --json` для локального Claude Code CLI.
- Bridge проверяет `claude --version` и `claude --help`, возвращает `claude_runtime_status`.
- S05b добавляет `turn-proof --json`: один реальный Claude CLI turn, prompt через stdin, `stream-json`, `--no-session-persistence`, low-cost proof model и fail-closed receipt.
- Full GUI chat, session mirror, native approvals, tracing и Agent SDK tools пока planned.

Owning slice: `S05-claude-runtime`, текущий sub-slice `S05b-claude-turn-proof`.
