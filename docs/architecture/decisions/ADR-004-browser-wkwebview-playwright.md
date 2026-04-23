# ADR-004 — Split preview browser and automation engine

Status: accepted

## Context
The workbench needs a native browser pane for people and a strong automation engine for agents and traces.

## Decision
Use `WKWebView` for the in-app preview surface and a separate automation sidecar for replay, traces and scripted control.

## Consequences
- UI stays native and responsive.
- Browser automation can scale independently.
- Trace artifacts stay provider-neutral.
