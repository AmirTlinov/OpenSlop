# ROADMAP

Это flagship roadmap проекта. Он задаёт порядок вертикальных слайсов, зависимости и closure shape. Детали живут в `plans/slices/*`.

Первый доказуемый цикл проекта: `repo doctor` -> `core-daemon heartbeat` -> `macOS shell build`. Пока этот цикл не зелёный, любая большая архитектура остаётся лишь разговором.


| Slice | Outcome | Depends on | Status |
| --- | --- | --- | --- |
| `S00-repo-constitution` | Конституция репозитория, карты, buildable seeds | — | in progress |
| `S01-workbench-shell` | Первое настоящее окно workbench | S00 | planned |
| `S02-event-spine` | Canonical event log, IPC, projections | S00 | done |
| `S03-codex-runtime` | Полный Codex path через app-server | S02 | planned |
| `S04-transcript-approval-pty` | Нативный transcript, approvals, PTY | S03 | planned |
| `S05-claude-runtime` | Claude runtime через bridge | S02 | planned |
| `S06-git-review-artifacts` | Diff, artifacts, worktrees | S02 | planned |
| `S07-browser-preview` | Встроенный native preview browser | S01,S02 | planned |
| `S08-browser-automation` | Browser automation, replay, trace | S07 | planned |
| `S09-harness-sensors` | Evidence ingestion и probes | S02,S06,S07 | planned |
| `S10-verify-context-packs` | Gates и context packs | S09 | planned |
| `S11-scale-search-performance` | Search, caching, scale budgets | S02,S06,S10 | planned |
| `S12-review-visual-conformance` | Reviewer pipeline и visual checks | S01,S10,S11 | planned |
| `S13-design-accessibility-polish` | Keyboard-first polish и accessibility | S12 | planned |
| `S14-release-engineering` | Packaging, compatibility matrix, release lanes | S03,S05,S11,S13 | planned |


## Closure law для каждого слайса

Каждый слайс закрывается только когда есть:
- код и документы в owning surfaces;
- зелёная локальная проверка нужного уровня;
- reviewer verdict из `reviews/agents/`;
- visual сверка с `DESIGN.md` и референсами, если slice трогает GUI;
- git commit на `main` или рабочую ветку с понятным scope.

## Общая стратегия

1. Сначала ставим карты, границы и минимальные рабочие артефакты.
2. Потом строим event spine и native shell.
3. Затем подключаем Codex и Claude как first-class execution engines.
4. После этого поднимаем browser, harness, verify и review.
5. В конце шлифуем scale, accessibility и release engineering.
