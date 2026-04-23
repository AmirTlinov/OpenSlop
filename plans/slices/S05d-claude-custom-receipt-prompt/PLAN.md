# S05d Claude custom receipt prompt

## Intent

S05d делает следующий маленький шаг после S05c: пользователь может ввести один bounded Claude receipt prompt в native start surface, а OpenSlop проводит его через `WorkbenchCore -> core-daemon -> claude-bridge` и сохраняет read-only receipt в `session_list`.

Это не полноценный Claude session lifecycle. Слайс не открывает resume, history, approvals, tools, tracing и произвольный диалоговый режим.

## Owning surfaces

- `apps/macos-app/Sources/OpenSlopApp/WorkbenchStartSurfaceView.swift`
- `apps/macos-app/Sources/OpenSlopApp/WorkbenchRootView.swift`
- `apps/macos-app/Sources/OpenSlopApp/TimelinePanelView.swift`
- `apps/macos-app/Sources/WorkbenchCore/ClaudeReceiptPromptPolicy.swift`
- `services/core-daemon/src/main.rs`
- `apps/macos-app/Sources/OpenSlopClaudeCustomReceiptProbe/main.swift`

## Boundary

Prompt boundedness проверяется до запуска Claude bridge. Пустой и слишком большой prompt возвращают daemon error, а не молчаливый success.

GUI показывает отдельную receipt-form. Codex composer не переиспользуется для Claude.
