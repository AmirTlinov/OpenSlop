# REVIEW

## Reviewers

- native-ui-reviewer
- architecture-reviewer

## What must be checked

- UI looks less mocky without hiding real state.
- Planned Browser and Verify surfaces cannot be mistaken for live features.
- Swift remains a view adapter and does not invent provider/browser facts.
- System macOS chrome/materials are used without custom fake glass.
- Existing proof rails still pass.

## Required evidence

- `swift build --package-path apps/macos-app --product OpenSlopApp`
- `make smoke-shell-state`
- `make smoke-timeline-empty-state`
- `make smoke-git-review`
- semantic visual check against user screenshots and `DESIGN.md`

## First reviewer pass

- verdict: BLOCKED
- reviewer: `Nash the 3rd`
- blockers:
  - Sidebar rendered planned/non-wired features as live actions.
  - Claude looked selectable/live in the start surface without an S05 warning.

## Blocker fixes

- Sidebar top actions now carry visible `Codex start`, `S11` or `planned` pills.
- Start surface now shows a Claude S05 warning when Claude is selected.
- Inspector now defaults to Summary, not Browser.

## Re-review

- verdict: PASS
- reviewer: `Descartes the 3rd`
- checked:
  - planned sidebar rows show `S11` or `planned` pills;
  - Claude selected state shows S05 warning and live Codex actions are disabled;
  - Browser says S07 planned and URL field is disabled;
  - Verify says S09/S10 planned;
  - native direction uses hidden title bar, unified toolbar, sidebar list, `.bar`, `.regularMaterial`, inspector tabs.

## Verdict

- verdict: PASS
