# VISUAL-CHECK

## Surface checked

- Start surface when `Provider = Claude`.
- Composer status line when `Provider = Claude`.
- Inspector Summary tab with `ClaudeRuntimeStatusView`.

## Semantic result

PASS with one deliberate limitation.

The GUI now says Claude Code is found as a local runtime status boundary, while Claude turns remain locked. The visible start button changes from a Codex action into a locked Claude label, the composer says `status only`, and the Inspector card shows runtime status without claiming sessions, approvals or tracing.

## Native/design notes

- The card uses existing macOS material/card grammar and stays inside the inspector.
- The status pill is secondary; it does not compete with timeline focus.
- Some details are still engineer-facing (`Binary`, `Node`, `CLI signals`). This is acceptable for S05a because the slice is a boundary proof, not final provider onboarding.

## Fail-closed visual law

A user can see that Claude exists locally, but cannot reasonably infer that Claude chat already works.
