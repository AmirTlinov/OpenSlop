# S05e Claude receipt detail snapshot preflight

## Decisions

1. S05d stores only a read-only session summary plus the latest proof response in the materialization call.
2. S05e adds daemon-owned detail snapshot for the singleton `claude-turn-proof-latest` receipt.
3. Swift may cache and render the snapshot, but it is not the source of truth.

## Critical questions

- Where should receipt detail truth live?
  - Current answer: `core-daemon` repo-local state.
- Should S05e create receipt history?
  - Current answer: no. This is latest singleton receipt only.
- Which details can be shown without expanding scope?
  - Current answer: result, prompt bytes, event count, tool/malformed counts, persistence, timeout, model/cost/duration and warnings. Raw prompt is not shown as history.

## Cheap probe result

`session_list` only has summary fields. A selected/restarted UI needs a separate `claude-receipt-snapshot` read-only query to render proof details honestly.

## Boundary

S05e is read-only receipt detail. It does not unlock Claude transcript, history, resume, approvals, platform tools or tracing.
