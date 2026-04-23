# ADR-001 — Core daemon is source of truth

Status: accepted

## Context
Long-running agent sessions, provider streams, approvals and artifacts must survive UI restarts.

## Decision
`services/core-daemon` owns canonical events, projections, provider lifecycle and persisted truth. `apps/macos-app` acts as a client over IPC.

## Consequences
- UI stays thin and restart-safe.
- Domain truth does not leak into view state.
- Provider adapters stay attachable without re-architecting the app shell.
