# S05a Claude runtime preflight

## Questions that change implementation

1. First runtime boundary: use the local Claude Code CLI now, then move to Agent SDK when a full turn bridge is scoped.
2. Proof depth: discovery/status only. A live answer is not required for S05a.
3. GUI scope: expose a fail-closed Claude status. Do not draw a fake Claude chat.

## Cheap probe

See `claude-runtime-probe.txt`.

## Slice boundary

S05a proves whether a local Claude runtime boundary exists, records capabilities, exposes it through `core-daemon` and the native GUI, and keeps full Claude sessions out of scope.
