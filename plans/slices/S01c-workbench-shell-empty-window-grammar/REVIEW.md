# REVIEW

## Reviewers

- native-ui-reviewer
- architecture-reviewer

## What must be checked

- Empty state uses existing shell truth only.
- No new loading/error runtime semantics are claimed.
- Timeline no longer uses synthetic proof cards as fallback.
- Header no longer hardcodes `S04` as generic shell identity.
- Live transcript rendering remains unchanged in spirit.

## Required evidence

- `swift build --package-path apps/macos-app --product OpenSlopApp`
- `make smoke-timeline-empty-state`
- semantic visual check against `DESIGN.md` and S01 reference images

## Verdict

- verdict: PASS
- reviewer: reviewer subagents `Parfit the 2nd` and `Kepler the 2nd`
- date: 2026-04-23

## First review blocker

`PLAN.md` initially left a bad phrase implying empty state could be chosen from summary strings. That conflicted with the code and with the S01c truth boundary.

## Blocker fix

`PLAN.md` now says empty state is chosen only from typed shell facts:
- selected session present / absent;
- transcript item count: `nil` / `0` / `>0`.

It also states that summary strings are not phase truth.

## Final review confirmation

- Synthetic fallback timeline cards are gone.
- Generic header no longer hardcodes `S04`.
- Empty center state is projected from selected session presence and transcript item count.
- Live transcript path still renders real timeline items.
- `OpenSlopTimelineEmptyStateProbe` forbids `S04`, `proof target`, and caller-authored summary leakage.

## Evidence

- `swift build --package-path apps/macos-app --product OpenSlopApp` — PASS
- `make smoke-timeline-empty-state` — PASS
- `make smoke-shell-state` — PASS

## Non-blocking notes

A later cleanup can split `hasSelectedSession` from `selectedSessionTitle` to make the projector API even purer. It is not needed for S01c closure.
