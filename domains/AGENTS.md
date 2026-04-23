# domains

`domains/` содержит bounded contexts. Это основная продуктовая карта.

Карта:
```text
domains
├─ workspace/
├─ session/
├─ provider/
├─ approval/
├─ git/
├─ artifact/
├─ browser/
├─ harness/
├─ verify/
└─ search/
```

Правило: доменные инварианты и контракты живут здесь. `apps/` и `services/` — адаптеры и composition roots.
