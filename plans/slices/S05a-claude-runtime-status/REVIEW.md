# REVIEW

## Reviewers

- provider-reviewer-claude
- architecture-reviewer
- native-ui-reviewer

## What must be checked

- GUI не притворяется, что Claude chat работает.
- Provider boundary живёт в `services/claude-bridge` + `domains/provider`, а не в Swift view state.
- Status fail-closed и не открывает submit/start для Claude.
- Smoke доказывает реальный local contour.

## Local evidence

- `node services/claude-bridge/bin/claude-bridge.mjs status --json` — PASS, returns `claude_runtime_status available=true version=2.1.118 (Claude Code)`.
- `node services/claude-bridge/bin/claude-bridge.mjs nonsense --json` — PASS, returns `available=false` with unsupported-command warning.
- `./target/debug/core-daemon --claude-runtime-status` — PASS, returns `claude_runtime_status available=true bridge=0.1.0`.
- `RUST_TEST_THREADS=1 cargo test -p provider-domain` — PASS, 16 tests.
- `cargo test -p core-daemon` — PASS, 15 tests.
- `swift build --package-path apps/macos-app` — PASS.
- `make smoke-claude-runtime-status` — PASS, `OpenSlopClaudeStatusProbe` observed `available=true version=2.1.118 (Claude Code) bridge=0.1.0`.
- `make smoke-shell-state` — PASS.
- `make smoke-timeline-empty-state` — PASS.
- `make smoke-git-review` — PASS.
- `python3 tools/repo-lint/check_repo_shape.py` — PASS.
- `git diff --check` — PASS.

## Visual check

See `VISUAL-CHECK.md`.

## Reviewer verdicts

### Provider / architecture re-review

Reviewer: `Kant the 4th` (`reviewer`, 2026-04-24)

Verdict: PASS / GOOD

Blocking findings:
- none.

What is proven:
- `startCodexSession()` hard-gates on `canStartCodexSession`, which is Codex-only;
- `submitTurn()` hard-gates on `canSubmitTurn`, which is Codex-only and live-session-only;
- Start surface `.onSubmit` no longer bypasses disabled state;
- Claude status UI says status boundary only;
- bridge unsupported states are fail-closed;
- core-daemon treats non-zero bridge exit as unavailable.

### Native UI re-review

Reviewer: `Aristotle the 4th` (`reviewer`, 2026-04-24)

Verdict: PASS / GOOD

Blocking findings:
- none.

Non-blocking findings:
- under Claude, the prompt field still visually resembles chat; acceptable because submit is fail-closed;
- sidebar `Новый чат` remains generic and should become `Новая Codex session` until Claude turns exist;
- inspector card is still engineer-facing with `Binary`, `Node`, and `CLI signals`; acceptable for a boundary proof slice.

## Closure verdict

S05a is merge-ready. It proves a local Claude runtime status boundary and does not claim Claude turns, session mirror, native approvals or tracing.
