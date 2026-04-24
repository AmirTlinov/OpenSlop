# ACCEPTANCE

## Functional

- Timeline показывает события как спокойную историю работы.
- Сырые command output, PTY details и Claude receipt proof не доминируют в центре.
- Подробности можно раскрыть рядом с событием.
- Статус события остаётся видимым: работа, внимание, доказано, неизвестно.
- `Следы` остаются местом для evidence-heavy поверхностей.
- GUI не заявляет новых runtime capabilities.

## Visual

- Центр не выглядит как debug log.
- Нет сетки равноправных тяжёлых карточек.
- Provider/model selection остаётся в composer/start surface.
- Header показывает session title, workspace, branch, provider и human status.

## Proof

- `swift build --package-path apps/macos-app --product OpenSlopApp`
- `swift build --package-path apps/macos-app`
- `make smoke-timeline-empty-state`
- `make smoke-execution-profile`
- `make doctor`
- `git diff --check`
