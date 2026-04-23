# REVIEW

## Reviewers

- provider-reviewer-claude
- architecture-reviewer
- native-ui-reviewer copy check

## What must be checked

- Claude proof uses a real CLI turn, not fixture success.
- Prompt goes through stdin and avoids argv payload risk.
- `core-daemon` owns the runtime boundary; Swift only asks daemon.
- Receipt remains fail-closed on missing runtime, timeout, malformed stream or tool-use events.
- Slice does not claim GUI chat, session mirror, approvals, tools or tracing.

## Local evidence

- `node services/claude-bridge/bin/claude-bridge.mjs status --json | jq '{kind, available, bridge, cliVersion, warnings}'` — PASS, `available=true`, `bridge.version=0.2.0`, `cliVersion=2.1.118 (Claude Code)`.
- `printf 'Reply with exactly OPENSLOP_CLAUDE_OK and nothing else.\n' | node services/claude-bridge/bin/claude-bridge.mjs turn-proof --json | jq ...` — PASS, `success=true`, `resultText=OPENSLOP_CLAUDE_OK`, `eventCount=5`, `toolUseCount=0`, `malformedEventCount=0`, `sessionPersistence=disabled`, `model=claude-haiku-4-5-20251001`, `exitCode=0`, `timedOut=false`, `totalCostUsd=0.012447999999999999`.
- `cargo build -p core-daemon && ./target/debug/core-daemon --claude-turn-proof | jq ...` — PASS, `success=true`, exact marker, no tools, no malformed events, no timeout, non-persistent receipt, `totalCostUsd=0.001846`.
- `make smoke-claude-turn-proof` — PASS, `OpenSlopClaudeTurnProofProbe ok: marker=OPENSLOP_CLAUDE_OK model=claude-haiku-4-5-20251001 events=5 cost=0.001686`.
- `RUST_TEST_THREADS=1 cargo test -p provider-domain` — PASS, 17 tests.
- `cargo test -p core-daemon` — PASS, 15 tests.
- `make smoke-claude-runtime-status` — PASS, `available=true version=2.1.118 (Claude Code) bridge=0.2.0`.
- `swift build --package-path apps/macos-app` — PASS.
- `node --check services/claude-bridge/bin/claude-bridge.mjs` — PASS.
- `python3 tools/repo-lint/check_repo_shape.py` — PASS.
- `git diff --check` — PASS.

## Visual check

See `VISUAL-CHECK.md`.

## Reviewer verdicts

### Provider / architecture review

Reviewer: `Tesla the 4th` (`reviewer`, 2026-04-24)

Verdict: PASS / GOOD

Blocking findings:
- none.

What is proven:
- real Claude turn path exists and is not fixture success;
- prompt goes through stdin;
- bridge uses `stream-json`, `--no-session-persistence`, disabled tools, timeout and low-cost model;
- `core-daemon` owns the Claude boundary;
- Swift only asks daemon;
- GUI chat, session mirror, native approvals, platform tools and tracing remain unclaimed.

Reviewer negative checks:
- PATH without `claude` returned `success=false`, `runtimeAvailable=false`;
- `OPEN_SLOP_CLAUDE_PROOF_TIMEOUT_MS=1` returned `success=false`, `timedOut=true`;
- fake Claude emitting `tool_use` returned `success=false`, `toolUseCount=1`.

Non-blocking findings fixed after review:
- tightened GUI copy from “proof exists/proves” to “probe-only turn receipt / proof only as probe”.

### Native UI / visual review

Reviewer: `Leibniz the 4th` (`reviewer`, 2026-04-24)

Verdict: PASS / GOOD

Blocking findings:
- none.

What is proven:
- GUI diff is copy-only;
- no new Claude chat button, resume path, approval UI, tool UI or tracing surface;
- changed copy keeps Claude closed;
- `OpenSlopClaudeTurnProofProbe` is not a user-facing GUI action.

Non-blocking findings fixed after review:
- tightened optimistic copy to probe-only wording.

## Closure verdict

S05b is merge-ready. It proves one bounded non-persistent Claude receipt turn through `claude-bridge -> core-daemon -> WorkbenchCore probe` and does not claim Claude GUI chat, session mirror, native approvals, platform tools or tracing.
