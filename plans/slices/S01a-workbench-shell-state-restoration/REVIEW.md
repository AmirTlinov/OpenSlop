# REVIEW

## Reviewers
- native-ui-reviewer
- perf-reviewer

## What must be checked
- persisted state не утекает в runtime truth;
- shell shortcuts реально делают главные действия быстрее;
- inspector toggle остаётся честной layout truth, а не визуальным фокусом-ловушкой;
- reference images не выдают semantic anchors за pixel baseline.

## Required evidence
- `swift build --package-path apps/macos-app`
- `make smoke-shell-state`

## Verdict

- verdict: PASS with notes
- reviewer: explorer subagent `Meitner the 7th`
- date: 2026-04-23

## What review confirmed

- `WorkbenchShellState` остаётся app-owned persistence surface и не лезет в runtime truth.
- `WorkbenchRootView` реально грузит и сохраняет shell state, а selection reconcile происходит после загрузки session list.
- keyboard paths для refresh, start, inspector toggle и submit появились и укладываются в честный shell scope.
- `docs/design/reference-images/` содержит semantic shell anchors и README не выдаёт их за screenshot baseline.

## Non-blocking notes

- Изначально был статусный drift: `ROADMAP.md` уже помечал `S01a` как `done`, пока slice-local `STATUS.md` ещё стоял `in_review`. Это выровнено.
- В shell есть provider picker с `Claude`, но live submit path пока только у Codex. UI теперь прямо пишет, что Claude runtime ещё planned в `S05`.
- Reviewer-blocker про потерю `selectedSessionID` на load failure снят: `WorkbenchRootView` больше не затирает persisted selection в error path, а `OpenSlopShellStateProbe` теперь проверяет сохранение выбора при пустом available list.

## Re-review after blocker fix

- verdict: PASS with notes
- reviewer: explorer subagent `Poincare the 7th`
- date: 2026-04-23

Что подтвердил re-review:
- blocker по потере persisted selection снят;
- `make smoke-shell-state` теперь доказывает и path с пустым available session list;
- slice-local truth согласована с фактическим closure state.
