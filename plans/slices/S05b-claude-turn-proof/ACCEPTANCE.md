# ACCEPTANCE

- `claude-bridge turn-proof --json` читает prompt из stdin и возвращает typed `claude_turn_proof_result`.
- Prompt не передаётся через argv.
- Bridge использует `stream-json`, `--no-session-persistence`, disabled tools, low-cost proof model и bounded timeout.
- Malformed stream JSON, timeout или tool-use events делают `success=false`.
- `core-daemon --claude-turn-proof` возвращает тот же typed receipt.
- Stdio operation `claude-turn-proof` работает через long-lived daemon transport.
- `WorkbenchCore` декодирует receipt через тот же daemon transport.
- `OpenSlopClaudeTurnProofProbe` подтверждает exact marker, real stream events, zero tools, no timeout и no session persistence.
- GUI не получает Claude chat action в этом slice.
