# S05b-claude-turn-proof — first real Claude turn receipt

## Outcome

Доказать первый настоящий Claude turn через `claude-bridge -> core-daemon -> WorkbenchCore probe`.

Это receipt-слайс. Он открывает не чат, а честную возможность сказать: локальный Claude Code CLI может ответить на один bounded prompt через наш bridge, daemon и Swift client.

## Touches

- `domains/provider`
- `services/claude-bridge`
- `services/core-daemon`
- `apps/macos-app/WorkbenchCore`
- `apps/macos-app/OpenSlopClaudeTurnProofProbe`

## Out of scope

- User-facing Claude chat.
- Session mirror/resume.
- Native Claude approvals.
- Platform tools через Agent SDK/MCP.
- Tracing handoff.
- Browser/harness coupling.

## Canonical choice for this slice

Prompt идёт через stdin. Claude запускается как subprocess через `spawn`, `stream-json`, `--no-session-persistence`, disabled tools и low-cost proof model.

Closure считается честным только если реальный marker возвращается через bridge, daemon operation и Swift probe.
