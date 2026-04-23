# S05e Claude receipt detail snapshot

## Intent

S05e делает Claude receipt в timeline честнее. После S05d GUI мог создать custom receipt, но выбранная Claude session всё ещё выглядела почти статично. Теперь детали receipt берутся из daemon-owned snapshot, а не из UI легенды.

## Scope

- `core-daemon` сохраняет latest receipt snapshot в repo-local state.
- `core-daemon` отдаёт read-only `claude-receipt-snapshot` query.
- Swift получает typed DTO и рендерит result, prompt bytes, event count, tool bounds, persistence, duration/cost/model and warnings.
- Timeline и Inspector используют snapshot как read-only evidence.

## Non-scope

- Claude transcript.
- Receipt history.
- Resume/history lifecycle.
- Native approvals.
- Platform tools.
- Tracing handoff.
- Raw prompt persistence in UI.
