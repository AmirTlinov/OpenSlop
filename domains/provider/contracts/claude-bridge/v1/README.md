# Claude bridge contract subset — v1

This is the narrow local Claude bridge contract.

Current proof boundaries:
- `services/claude-bridge/bin/claude-bridge.mjs status --json` checks the local Claude Code CLI and returns `claude_runtime_status`.
- `services/claude-bridge/bin/claude-bridge.mjs turn-proof --json` reads a prompt from stdin, runs one real non-persistent Claude Code turn, and returns `claude_turn_proof_result`.
- `core-daemon` exposes these as `claude-runtime-status` and `claude-turn-proof`.
- `WorkbenchCore` may probe this path. GUI chat for Claude stays closed until a later lifecycle slice.

S05b turn-proof invariants:
- prompt goes over stdin, not argv;
- model defaults to low-cost `haiku` unless `OPEN_SLOP_CLAUDE_PROOF_MODEL` overrides it;
- tools are disabled through the Claude CLI proof invocation;
- `--no-session-persistence` is part of the command;
- malformed stream JSON, timeout, or tool-use events make `success=false`.

Not claimed yet:
- Claude GUI chat.
- Session mirror/resume inside OpenSlop.
- Native approval bridge.
- Platform tools through Agent SDK/MCP.
- Tracing handoff.
