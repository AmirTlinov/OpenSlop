# S01b-workbench-shell-layout-geometry — Shell layout geometry

## Goal

Закрыть честный S01-gap: workbench shell запоминает размеры главного окна, sidebar и inspector между перезапусками.

## Touches

- `apps/macos-app`
- `plans/slices/S01-workbench-shell`

## Scope

В слайс входит только app-owned layout geometry:
- default window size из persisted shell state;
- observed window content size после resize;
- preferred sidebar width;
- preferred inspector width;
- proof для save/load/sanitize/legacy state.

## Non-goals

В этот слайс не входят:
- loading/error phase model;
- runtime/session state;
- multi-window-specific geometry keys;
- pixel-perfect split restore claims;
- browser, Claude или extra polish.

## Truth surface

Geometry — это локальное предпочтение native shell. Оно не уходит в daemon, event spine, provider runtime или session truth.

SwiftUI split widths трактуются честно: это preferred/restored geometry плюс observed feedback, а не обещание абсолютного пикселя внутри platform split host.
