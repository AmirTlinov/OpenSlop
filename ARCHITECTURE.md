# ARCHITECTURE

## Верхняя форма

OpenSlop строится как local-first система из трёх слоёв:
1. `apps/macos-app` — нативный GUI;
2. `services/core-daemon` — источник истины, event spine и runtime-оркестратор;
3. provider и tool sidecars — boundary code для Codex, Claude, browser automation и следующих движков.

## Главный архитектурный закон

UI не владеет долгоживущим состоянием. Истина принадлежит core daemon, который держит:
- sessions и turns;
- canonical events;
- projections для UI;
- provider capability snapshots;
- artifact registry;
- verify и harness сигналы.

## Process topology

- `OpenSlop.app` рендерит UI и диспатчит команды.
- `core-daemon` хранит факты, поднимает providers и sidecars, пишет event log и обслуживает IPC.
- `codex app-server`, `claude-bridge`, `browser-runner` живут как отдельные процессы.
- Тяжёлые артефакты уходят в blob store. Быстрые представления живут в SQLite projections.

## Bounded contexts

В `domains/` лежат продуктовые контексты:
- `workspace`
- `session`
- `provider`
- `approval`
- `git`
- `artifact`
- `browser`
- `harness`
- `verify`
- `search`

Каждый домен получает свою карту, диаграмму и потом свой код. Доменные инварианты не должны стекаться в `apps/` и `services/`.

## Capability model

Providers не сплющиваются до message-in/message-out. У каждого есть capability snapshot: resume, fork, approvals, tool streaming, custom tools, tracing, browser hooks, sandbox controls и другие возможности. UI строится поверх общего канона событий и capability extensions.

## Platform-owned surfaces

Следующие поверхности принадлежат продукту, а не отдельному provider:
- browser;
- verify;
- harness;
- artifact registry;
- git review;
- repo search.

Это держит UX цельным и убирает зависимость от случайных фич одного вендора.

## Документы, которые нельзя путать

- `PHILOSOPHY.md` — намерение проекта;
- `ARCHITECTURE.md` — стабильная верхняя карта;
- `DESIGN.md` — дизайн-грамматика;
- `ROADMAP.md` — flagship-путь;
- `docs/architecture/*.mmd` — схемы и topology;
- `plans/slices/*` — детали выполнения.


## UI projection discipline

GUI показывает только три вида данных: daemon-owned facts, app-owned local settings и честные unknown states. Planned browser, harness, map и verify surfaces не должны выглядеть как готовые runtime-фичи до появления owning projections. Composer владеет draft execution profile, а session projection владеет правдой уже созданной сессии.
