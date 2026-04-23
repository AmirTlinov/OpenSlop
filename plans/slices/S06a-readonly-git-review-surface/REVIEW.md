# REVIEW

## Reviewers

- architecture-reviewer
- native-ui-reviewer

## What must be checked

- Swift does not become Git truth owner.
- Snapshot is read-only and bounded.
- Non-git/failure path is not reported as clean.
- UI remains Inspector secondary surface, not a full Git client.
- Probe proves dirty fixture and no mutation.

## Required evidence

- `cargo test -p git-domain -p core-daemon`
- `swift build --package-path apps/macos-app --product OpenSlopApp`
- `make smoke-git-review`
- semantic visual check against `DESIGN.md` and `docs/design/reference-images/`

## First reviewer pass

- verdict: BLOCKED
- reviewer: `Harvey the 3rd`
- blockers:
  - Git status failure could still render as clean.
  - No-mutation proof compared status and HEAD, but not `.git/index`.

## Blocker fixes

- `GitReviewSnapshot.statusState` now carries `dirty`, `clean`, `unknown` or `unavailable`.
- UI renders non-clean empty file lists as Git status unavailable, not worktree clean.
- Git reads use `GIT_OPTIONAL_LOCKS=0`.
- `OpenSlopGitReviewProbe` now compares status bytes, `HEAD` and `.git/index` bytes across two daemon snapshot requests.

## Re-review

- verdict: PASS
- reviewer: `Wegener the 3rd`
- checked:
  - `make smoke-git-review` PASS;
  - dirty fixture reports `statusState=dirty`;
  - non-git path reports `statusState=unavailable`;
  - corrupt index extra probe reports `statusState=unknown` with warning;
  - no-mutation proof covers status bytes, `.git/index` bytes and `HEAD`;
  - UI has refresh/select/all-diff only and no mutation affordances.

## Verdict

- verdict: PASS
