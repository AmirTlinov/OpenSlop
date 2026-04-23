# S05c Claude receipt session preflight

## Decisions

1. S05b proved one real Claude turn receipt, not session lifecycle or GUI chat.
2. S05c adds one user-visible ability: run the bounded Claude receipt from the native shell and materialize it as a read-only session summary.
3. The receipt remains probe/session evidence. It does not unlock arbitrary Claude chat, resume, native approvals, platform tools or tracing.

## Critical questions

- Should S05c use real Claude again or reuse the S05b receipt fixture?
  - Current answer: real Claude again. Fixture success would be a lie.
- Should S05c create full Claude chat lifecycle?
  - Current answer: no. It only creates a read-only receipt session and keeps chat submit closed.
- What proof closes S05c?
  - Current answer: daemon operation materializes a Claude session, WorkbenchCore probe verifies `session_list`, GUI copy stays fail-closed, reviewer verdicts pass.

## Cheap probe result

Current repo already has:
- `claude-turn-proof` through bridge -> daemon -> Swift probe;
- SQLite-backed `session_list` with `upsert_runtime_session`;
- Start surface provider switch where Claude start is currently disabled.

## Boundary

S05c wires a first minimal Claude session materialization path. It is deliberately read-only.
