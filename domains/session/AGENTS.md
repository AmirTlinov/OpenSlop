# session

Назначение: Threads, turns, transcript timeline, active state, resume, fork и PTY linkage.

Когда идти сюда:
- Когда меняется lifecycle сессий, canonical events, transcript model или active turn behavior.

Соседи: provider, artifact, approval, verify

Карта:
```text
session
├─ AGENTS.md
└─ docs/
   └─ context.mmd
```

Текущее состояние:
- Материализована карта домена.
- Код появится по owning slices, когда домен станет активным фронтом реализации.
