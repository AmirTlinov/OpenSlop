# TASKS

- [x] Закрепить exact schema subset для `command/exec` в `domains/provider/contracts/`.
- [x] Добавить в `provider-domain` отдельные buffered и streaming `command/exec` helpers вне session registry.
- [x] Сохранить raw `outputDelta` как base64 payload и не смешивать его с transcript text.
- [x] Протянуть `codex-command-exec` и `codex-command-exec-stream` через `core-daemon --serve-stdio`.
- [x] Добавить `WorkbenchCore` DTO и client methods для standalone exec lane.
- [x] Добавить `OpenSlopCommandExecProbe` и smoke-target.
- [x] Обновить routing docs и contract README.
