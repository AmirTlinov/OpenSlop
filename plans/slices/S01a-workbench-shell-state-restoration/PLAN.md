# S01a-workbench-shell-state-restoration — Persisted shell state

## Goal

Сдвинуть S01 из planned в честный рабочий contour: первый native shell запоминает выбор сессии и базовые shell-предпочтения, умеет быстро вернуть inspector и получает первые semantic reference images для visual review.

## Touches

- `apps/macos-app`
- `docs/design/reference-images`
- `plans/slices/S01-workbench-shell`

## Non-goals

В этот слайс не входят:
- full split geometry persistence;
- multi-window restoration;
- screenshot automation;
- дизайн-polish beyond current shell anatomy.

## Truth surface

Слайс честно закрыт, если репозиторий доказывает четыре факта:
1. shell помнит selection/provider/effort/inspector visibility между перезапусками;
2. у главных shell-действий есть keyboard path;
3. inspector visibility остаётся частью layout truth и может быть возвращена без мышиного пылесоса;
4. reference images существуют как semantic anchors, не притворяясь pixel baseline.
