# ACCEPTANCE

- `make doctor` проходит.
- `cargo run -p core-daemon -- --heartbeat` отдаёт heartbeat.
- `swift build --package-path apps/macos-app` собирает seed-shell.
- `VISUAL-CHECK.md` фиксирует semantic visual check seed-shell против `DESIGN.md`.
- Все домены имеют `AGENTS.md` и `docs/context.mmd`.
- Все slice folders имеют `PLAN.md`, `TASKS.md`, `ACCEPTANCE.md`, `STATUS.md`, `REVIEW.md` и `diagrams/flow.mmd`.
