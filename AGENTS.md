# OpenSlop

Это корневой роутер проекта. Он нужен, чтобы агент быстро понял карту репозитория и пошёл в правильный домен без пылесоса по дереву.

Сначала читай:
1. `PHILOSOPHY.md`
2. `ARCHITECTURE.md`
3. `DESIGN.md`
4. `ROADMAP.md`

Карта проекта:
```text
.
├─ AGENTS.md
├─ README.md
├─ PHILOSOPHY.md
├─ ARCHITECTURE.md
├─ DESIGN.md
├─ ROADMAP.md
├─ .agents/skills/              # тонкий routing layer для агентной памяти
├─ docs/
│  ├─ architecture/             # верхнеуровневые .mmd и ADR
│  └─ design/                   # дизайн-грамматика и reference-images
├─ plans/slices/                # вертикальные слайсы flagship-пути
├─ domains/                     # bounded contexts
│  ├─ workspace/
│  ├─ session/
│  ├─ provider/
│  ├─ approval/
│  ├─ git/
│  ├─ artifact/
│  ├─ browser/
│  ├─ harness/
│  ├─ verify/
│  └─ search/
├─ shared-kernel/               # только минимальные общие примитивы
├─ apps/macos-app/              # нативная оболочка
├─ services/
│  ├─ core-daemon/              # источник истины и runtime spine
│  ├─ claude-bridge/            # будущий Claude Agent SDK bridge
│  └─ browser-runner/           # будущий automation sidecar
├─ reviews/agents/              # reviewer-профили для closure каждого слайса
└─ tools/                       # репозиторные утилиты и проверки
```

Куда идти по типу задачи:
- Окно, layout, toolbar, sidebar, inspector, composer: `DESIGN.md` -> `apps/macos-app/AGENTS.md`
- Event spine, session truth, projections, IPC: `ARCHITECTURE.md` -> `services/core-daemon/AGENTS.md` -> `domains/session/AGENTS.md`
- Codex и Claude adapters: `domains/provider/AGENTS.md` -> `services/core-daemon/` или `services/claude-bridge/`
- Browser pane, automation, trace, preview: `domains/browser/AGENTS.md` -> `docs/design/` -> `services/browser-runner/`
- Fail-closed evidence, gates, context packs: `domains/harness/AGENTS.md` и `domains/verify/AGENTS.md`
- Slice execution: `ROADMAP.md` -> `plans/AGENTS.md` -> нужный `plans/slices/Sxx-*/`
- Reviewer closure: `reviews/AGENTS.md`

Правила карты:
- `AGENTS.md` остаётся коротким и routing-first.
- `.mmd` лежат рядом с owning surface, а не в одной общей свалке.
- Реализация идёт по вертикальным слайсам. Каждый слайс закрывается review-артефактом, visual-check и git-коммитом.
- Planned surfaces помечаются как planned. Не выдавай будущую структуру за уже реализованную.
