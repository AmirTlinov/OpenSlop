# S01h active plan projection

## Outcome

Правый Inspector `План` перестаёт быть заглушкой. Он показывает repo-level план вертикальных слайсов из `ROADMAP.md` и `plans/slices/*`, включая markers по proof, review и visual check.

## Ownership

- `domains/workspace/rust/workspace-domain` читает repo-owned plan files и строит projection.
- `core-daemon` отдаёт `active-plan-projection` через CLI и stdio.
- `WorkbenchCore` держит typed DTO и client call.
- `InspectorPanelView` только показывает projection и не парсит markdown.

## Boundaries

Slice не создаёт live review runner, verify gates, browser map, session-to-slice tracking или harness truth. Это repo-plan projection, а не runtime verification.
