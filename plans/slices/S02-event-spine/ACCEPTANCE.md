# ACCEPTANCE

- `./target/debug/core-daemon --query session-list` печатает JSON projection `kind=session_list`.
- `core-daemon --serve-stdio` обслуживает line-based `session-list` queries без перезапуска процесса на каждый запрос.
- Session truth хранится в repo-local persisted store, а не собирается только из bootstrap-кода.
- `./target/debug/core-daemon --reset-session-store` и `--upsert-proof-session` дают воспроизводимый rehydration proof path.
- `swift run --package-path apps/macos-app OpenSlopProbe` делает две последовательные query по одному long-lived stdio transport, фиксирует reuse по PID и подтверждает наличие persisted proof session.
- `WorkbenchRootView` использует daemon-backed sessions в sidebar вместо hardcoded списка и показывает transport summary.
- `make smoke` проходит и включает store reset + persisted proof + probe path.
- Есть slice-local review artifact и visual-check для обновлённой shell anatomy.
