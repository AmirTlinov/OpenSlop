# ACCEPTANCE

## Functional

- Toolbar не содержит Codex/Claude segmented switch.
- Toolbar не содержит provider-specific `Запустить` / `Claude receipt` action.
- Composer содержит выбор агента, модели и effort.
- Empty/start surface тоже даёт выбрать агента, модель и effort.
- Claude остаётся receipt-only/status boundary и не притворяется полноценным чатом.
- Inspector больше не показывает fake browser tab как primary surface.
- Inspector больше не показывает `Verify` как полноценный harness.

## Visual

- Sidebar читает работу как everyday queues, а не как инженерный список сущностей.
- Proof output спрятан во вкладку `Следы`.
- Main timeline не начинает экран с raw transcript summary.

## Proof

- `swift build --package-path apps/macos-app --product OpenSlopApp`
