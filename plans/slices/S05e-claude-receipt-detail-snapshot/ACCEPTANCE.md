# ACCEPTANCE

S05e закрыт только если:

- Custom Claude receipt materialization сохраняет daemon-owned snapshot.
- Snapshot живёт в repo-local state, не в Swift-only state.
- `claude-receipt-snapshot` отдаёт typed read-only details.
- Wrong session id получает fail-closed mismatch error.
- Timeline показывает real proof fields: result, prompt bytes, event count, tool/malformed counts, persistence and timeout.
- Inspector summary показывает receipt result and bounds.
- GUI не показывает raw prompt как историю.
- Full Claude dialog, resume, approvals, tools and tracing остаются закрыты.
- Probe доказывает materialize -> fetch snapshot -> fields match.
