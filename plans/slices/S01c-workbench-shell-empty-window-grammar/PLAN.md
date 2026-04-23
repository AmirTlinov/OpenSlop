# S01c-workbench-shell-empty-window-grammar — Empty window grammar

## Goal

Закрыть честный остаток S01: центр workbench больше не притворяется `S04` proof lane, когда transcript пустой или недоступен.

## Touches

- `apps/macos-app`
- `plans/slices/S01-workbench-shell`

## Scope

В слайс входит:
- first-class empty/unavailable center surface;
- removal of synthetic `S04` badge from generic shell header;
- removal of synthetic fallback cards from timeline;
- small proof projector for empty timeline states.

## Non-goals

В слайс не входят:
- loading/error phase semantics;
- daemon/runtime state model changes;
- new provider behavior;
- screenshot automation;
- redesign of transcript item rendering.

## Truth surface

Empty state строится только на грубой typed truth, которая уже есть в shell:
- selected session present / absent;
- transcript item count: `nil` / `0` / `>0`.

Summary strings не выбирают состояние центра и не являются phase truth.
Если transcript содержит items, timeline показывает реальные items. Если items нет, центр показывает честный empty/unavailable surface без proof-storytelling.
