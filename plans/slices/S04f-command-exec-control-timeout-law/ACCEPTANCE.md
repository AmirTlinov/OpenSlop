# ACCEPTANCE

- `services/core-daemon/src/main.rs` держит bounded timeout только внутри active wait на follow-up control request:
  - `command/exec write`,
  - `command/exec terminate`.
- Timeout завершает lane явной ошибкой с fail-closed смыслом и не маскируется под тихий EOF.
- `OpenSlopCommandExecControlTimeoutProbe` доказывает два отрицательных contour:
  - после `READY` нет `write` -> явная ошибка примерно за 5 секунд;
  - после `READY -> PING` нет `terminate` -> явная ошибка примерно за 5 секунд.
- `CommandExecControlPaneView` честно подсказывает пользователю, что missing follow-up завершит proof lane в `failed`.
- Regression proof остаётся зелёным:
  - `OpenSlopCommandExecControlProbe`,
  - `OpenSlopCommandExecControlNegativeProbe`,
  - `OpenSlopCommandExecControlSurfaceProbe`.
- Слайс не заявляет live transcript control transport, `resize`, reconnect, multi-client или full terminal runtime.
