# S05b Claude turn proof preflight

## Decisions

1. If Claude auth/runtime fails, S05b returns a fail-closed receipt. It does not wait for secrets and does not fake success.
2. WorkbenchCore gets a probe/receipt path only. No user-facing Claude chat action in this slice.
3. Closure proof is a linked bundle: bridge stream-json receipt -> core-daemon operation -> WorkbenchCore probe -> slice review.

## Cheap probe

See `context-probe.txt`.

## Boundary

S05b proves one real Claude turn through `claude-bridge -> core-daemon -> WorkbenchCore`. It does not claim session mirror, resume, native approvals, tools, tracing, or GUI chat.
