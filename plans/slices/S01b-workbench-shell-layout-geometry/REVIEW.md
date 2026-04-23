# REVIEW

## Reviewers

- native-ui-reviewer
- perf-reviewer

## What must be checked

- Geometry stays local to native shell state.
- No runtime/session truth moved into `apps/macos-app`.
- AppKit bridge is narrow and does not become a second architecture.
- SwiftUI split restore is described as preferred/observed geometry, not exact pixel truth.
- Proof covers save/load/sanitize/legacy state.

## Required evidence

- `swift build --package-path apps/macos-app --product OpenSlopApp`
- `make smoke-shell-state`
- semantic visual check against `DESIGN.md` and `docs/design/reference-images/`

## Verdict

- verdict: PASS
- reviewer: reviewer subagent `Nash`
- date: 2026-04-23

## What review confirmed

- Geometry stayed inside app-owned shell state and `UserDefaults`.
- No new runtime/session truth touched `services/core-daemon` or session projections.
- `WorkbenchLayoutGeometryBridge` stayed narrow: one window-size observer and one split width reader.
- Restore semantics are honest: persisted window default size plus preferred/observed split widths, not pixel-perfect split truth.
- Proof covers restore, sanitize and legacy state fallback.

## Evidence

- `swift build --package-path apps/macos-app --product OpenSlopApp` — PASS
- `make smoke-shell-state` — PASS
- Probe output confirmed `1680x980`, sidebar `336`, inspector `388`, unsafe sanitize, and legacy default layout.

## Non-blocking notes

- A future slice can add a tiny runtime resize witness for the observer path itself. It is not required for S01b closure.
