# Claude bridge contract subset — v1

This is the narrow S05a contract for local Claude runtime discovery.

Current proof boundary:
- `services/claude-bridge/bin/claude-bridge.mjs status --json` checks the local Claude Code CLI.
- `core-daemon` exposes the result as `claude-runtime-status`.
- The native GUI may show this as provider status.

Not claimed yet:
- Claude turn streaming.
- Session mirror.
- Native approval bridge.
- Tracing handoff.
- Agent SDK custom tools.
