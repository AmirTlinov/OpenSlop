# PREFLIGHT

## Decision-changing questions

1. Есть ли уже честно доказанный resize runtime, который GUI пока скрывает?
2. Можно ли materialize'ить resize в том же standalone proof pane без transcript bridge claim?
3. Нужно ли для этого новый runtime slice, или достаточно app-owned surface refactor?

## Cheap probe verdict

- После `S04i` runtime уже доказан: `make smoke-codex-command-exec-resize` проходит на живом Codex.
- Текущий pane всё ещё пишет, что resize не обещан и не даёт никакого resize affordance.
- Значит следующий честный шаг живёт в `apps/macos-app`: fixed proof mode для уже доказанного PTY resize contour.

## Scope lock

- В scope: shared control surface, inspector pane, one fixed resize affordance, surface probe, docs.
- Вне scope: arbitrary rows/cols UI, transcript bridge, full terminal runtime, новый provider/core-daemon law.

## Hidden risk

- `stdinTrail` уже давно хранит не только stdin, но и control markers. Для resize mode это станет ещё менее честным названием. Лучше materialize'ить `controlTrail`, сохранив backward-compatible alias для старых proof lanes.
