# ACCEPTANCE

- `services/claude-bridge/bin/claude-bridge.mjs status --json` возвращает typed `claude_runtime_status`.
- Status является fail-closed: отсутствие `claude` или сбой bridge не открывают Claude turn path.
- `core-daemon` поддерживает `--claude-runtime-status` и stdio operation `claude-runtime-status`.
- Swift `WorkbenchCore` декодирует status через тот же daemon transport, что и остальные GUI paths.
- GUI показывает Claude status только как runtime boundary и прямо говорит, что turn bridge ещё не заявлен.
- `OpenSlopClaudeStatusProbe` подтверждает local end-to-end path и не допускает ложного claim про `bridgeTurnStreaming`, native approvals или tracing.
