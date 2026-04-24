# ACCEPTANCE

## Functional

- `core-daemon --active-plan-projection` отдаёт `active_plan_projection`.
- stdio operation `active-plan-projection` отдаёт тот же typed contour.
- Projection строится из `ROADMAP.md`, `STATUS.md`, `REVIEW.md`, `VISUAL-CHECK.md`.
- Inspector `План` показывает фокус плана, ближайшие слайсы и markers `proof/review/visual`.
- Swift не парсит markdown и не выдумывает runtime truth.

## Visual

- Правая панель остаётся лёгкой.
- Она называется и ощущается как план проекта, не как live verify dashboard.
- Missing/unknown markers видимы, но не выглядят как green success.

## Proof

- `cargo test -p workspace-domain -p core-daemon`
- `swift build --package-path apps/macos-app --product OpenSlopApp`
- `swift build --package-path apps/macos-app`
- `make smoke-active-plan`
- `make daemon-active-plan-projection`
- `make doctor`
- `git diff --check`
