# Session Event Spine

## Когда использовать

Используй этот skill, когда задача касается session projection, daemon query, canonical session list или первого реального IPC path между core-daemon и GUI.

## Локальные инварианты

- Первая живая session projection принадлежит daemon, не hardcoded SwiftUI seed.
- Sidebar и probe читают одну и ту же daemon truth surface.
- Для S02 нужен узкий proof target: хотя бы одна реальная session доходит из daemon в UI path.
- Не раздувай это в полный event bus раньше времени.

## Первый proof target

`./target/debug/core-daemon --query session-list` -> `OpenSlopProbe` -> `WorkbenchRootView`.
