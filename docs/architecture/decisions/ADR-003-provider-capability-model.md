# ADR-003 — Provider capability model

Status: accepted

## Context
Codex and Claude expose different strengths. A lowest-common-denominator abstraction would flatten useful power.

## Decision
Normalize events and session identity, but model provider-specific abilities as capabilities and extensions.

## Consequences
- One UI can host multiple providers honestly.
- Strong provider features remain reachable.
- Feature planning becomes explicit through capability snapshots.
