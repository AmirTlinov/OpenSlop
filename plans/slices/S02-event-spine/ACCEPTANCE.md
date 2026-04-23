# ACCEPTANCE

- `./target/debug/core-daemon --query session-list` печатает JSON projection `kind=session_list`.
- `swift run --package-path apps/macos-app OpenSlopProbe` читает projection через тот же client path.
- `WorkbenchRootView` использует daemon-backed sessions в sidebar вместо hardcoded списка.
- `make smoke` проходит и включает probe path.
- Есть slice-local review artifact и visual-check для обновлённой shell anatomy.
