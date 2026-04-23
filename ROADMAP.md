# ROADMAP

Это flagship roadmap проекта. Он задаёт порядок вертикальных слайсов, зависимости и closure shape. Детали живут в `plans/slices/*`.

Первый доказуемый цикл проекта: `repo doctor` -> `core-daemon heartbeat` -> `macOS shell build`. Пока этот цикл не зелёный, любая большая архитектура остаётся лишь разговором.


| Slice | Outcome | Depends on | Status |
| --- | --- | --- | --- |
| `S00-repo-constitution` | Конституция репозитория, карты, buildable seeds | — | done |
| `S01-workbench-shell` | Первое настоящее окно workbench | S00 | done |
| `S01a-workbench-shell-state-restoration` | Persisted shell state, inspector toggle и первые semantic shell references | S00 | done |
| `S01b-workbench-shell-layout-geometry` | Persisted window/sidebar/inspector geometry для shell layout | S01a | done |
| `S01c-workbench-shell-empty-window-grammar` | Honest empty/unavailable center grammar без S04 proof placeholders | S01b | done |
| `S01d-native-workbench-polish` | Native shell polish: sidebar, start surface, inspector tabs without fake runtime | S01c,S06a | done |
| `S02-event-spine` | Canonical event log, IPC, projections | S00 | done |
| `S03-codex-runtime` | Live Codex bootstrap lane через app-server | S02 | done |
| `S04-transcript-approval-pty` | Live turn transcript, native approvals и read-only/live terminal ceiling | S03 | done |
| `S04a-command-exec-proof` | Standalone connection-scoped `command/exec` proof lane | S03 | done |
| `S04b-command-exec-control-write` | Same-connection `command/exec` write + terminate proof lane | S04a | done |
| `S04c-command-exec-negative-law` | Wrong `processId` rejection without false control takeover | S04b | done |
| `S04d-readonly-terminal-pane` | First read-only/live-only terminal pane in native inspector | S04-transcript-approval-pty | done |
| `S04e-command-exec-control-pane` | Guided standalone `command/exec` proof pane in inspector | S04c | done |
| `S04f-command-exec-control-timeout-law` | Fail-closed timeout for missing `write/terminate` follow-up in standalone control lane | S04e | done |
| `S04g-command-exec-bounded-interactive-stdin` | Bounded standalone `write + closeStdin + terminate` proof lane with interactive stdin trail | S04f | done |
| `S04h-live-transcript-control-witness` | Raw witness for live transcript `processId -> command/exec/write` feasibility | S04d | done |
| `S04i-command-exec-resize-proof` | Standalone PTY `command/exec` resize proof lane | S04g | done |
| `S04j-command-exec-resize-pane` | Native fixed resize proof mode in inspector pane | S04e,S04i | done |
| `S04k-inspector-output-tail-hardening` | Bounded tail rendering for live terminal and proof output surfaces | S04d,S04j | done |
| `S05-claude-runtime` | Claude runtime через bridge | S02 | planned |
| `S05a-claude-runtime-status` | Первый fail-closed Claude runtime status через bridge | S02,S01d | done |
| `S05b-claude-turn-proof` | Первый реальный non-persistent Claude turn receipt через bridge -> daemon -> WorkbenchCore probe | S05a | done |
| `S05c-claude-receipt-session` | Read-only Claude receipt session в `session_list` и native shell | S05b,S02 | done |
| `S05d-claude-custom-receipt-prompt` | Custom bounded Claude receipt prompt из native GUI до daemon-owned receipt | S05c | done |
| `S06-git-review-artifacts` | Diff, artifacts, worktrees | S02 | planned |
| `S06a-readonly-git-review-surface` | Read-only branch/status/diff/file preview в Inspector | S02,S01 | done |
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
