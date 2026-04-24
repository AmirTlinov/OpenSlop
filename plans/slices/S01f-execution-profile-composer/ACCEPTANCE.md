# ACCEPTANCE

## Functional

- Daemon отдаёт `execution_profile_status` с профилями Codex и Claude.
- Codex profile имеет `runtimeLevel=live`.
- Claude profile имеет `runtimeLevel=receiptOnly` или `unavailable`.
- Composer показывает выбранному provider честный status line.
- Start surface показывает тот же daemon-owned status.
- Model list берётся из projection, если projection доступен.

## Proof

- `cargo test -p core-daemon`
- `swift build --package-path apps/macos-app --product OpenSlopApp`
- `make smoke-execution-profile`
- `git diff --check`
