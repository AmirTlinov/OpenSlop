# ACCEPTANCE

- Главное окно больше не выглядит как инженерный мок: слева системный rail, в центре calm workbench surface, справа inspector tabs.
- Start surface похожа по смыслу на Codex new-chat area, но не копирует пиксели.
- Browser tab не притворяется живым browser preview и явно говорит S07.
- Verify tab не притворяется harness и явно говорит S09/S10.
- Git Review остаётся daemon-owned и read-only.
- `make smoke-shell-state` и `make smoke-timeline-empty-state` зелёные.
- `swift build --package-path apps/macos-app --product OpenSlopApp` зелёный.
