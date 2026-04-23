# S04 live turn resume — preflight

## Вопросы / проверки

1. **Scope check:** этот шаг правда закрывается как `fresh process -> resume/load existing thread -> first live turn -> read-only transcript`, без approvals, PTY и общего S04 UI-polish?
   - Если нет, работа опять расползётся и спрячёт реальный blocker.

2. **Identity check:** для этого шага всё ещё честно держать `session_id == provider_thread_id` из S03?
   - Если нет, следующий ход уже не про resume, а про session/provider identity mapping.

3. **Contract check + cheap probe:** нужно ли сначала допинить `thread/resume` в checked-in contract subset и подтвердить failure existing probe `swift run --package-path apps/macos-app OpenSlopTurnProbe` на fresh app-server boundary?
   - Если probe падает на старом thread id до resume/load, следующий узкий шаг — adapter-owned hydration перед `turn/start` и `thread/read`, не UI.
   - Если probe уже проходит, гипотеза про fresh-process boundary ложная, и ход работ меняется.

## Очень короткий verdict

Не трогать transcript UI первым ходом.
Самый узкий next step — fail-closed rehydration существующего Codex thread в provider/core-daemon boundary, затем уже read-only transcript lane поверх этого.
