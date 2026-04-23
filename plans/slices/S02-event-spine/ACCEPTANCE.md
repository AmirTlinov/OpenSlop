# ACCEPTANCE

- `./target/debug/core-daemon --query session-list` печатает JSON projection `kind=session_list`.
- `core-daemon --serve-stdio` обслуживает line-based `session-list` queries без перезапуска процесса на каждый запрос.
- `swift run --package-path apps/macos-app OpenSlopProbe` делает две последовательные query по одному long-lived stdio transport и фиксирует reuse по PID.
- `WorkbenchRootView` использует daemon-backed sessions в sidebar вместо hardcoded списка и показывает transport summary.
- `make smoke` проходит и включает CLI query + probe path.
- Есть slice-local review artifact и visual-check для обновлённой shell anatomy.
