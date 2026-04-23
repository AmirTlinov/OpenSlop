# ADR-002 — SwiftUI shell with AppKit heavy surfaces

Status: accepted

## Context
The product needs native macOS shell quality and also heavy surfaces like transcript, diff and terminal.

## Decision
Use SwiftUI for app shell, window composition and state routing. Use AppKit-backed surfaces where rendering density, virtualization or mature controls matter.

## Consequences
- Faster path to a native-feeling shell.
- Better control over heavy rendering hotspots.
- Some bridge code is expected and accepted.
