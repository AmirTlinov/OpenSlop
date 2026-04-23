# REVIEW

## Reviewers
- architecture-reviewer
- perf-reviewer

## What must be checked
- Граница owning domains не пробита.
- Слайс не тащит лишний scope.
- Acceptance доказан реальными артефактами.
- Если тронут GUI, он сверяется с `DESIGN.md` и relevant reference images.

## Current posture

S02 всё ещё не закрыт целиком. Сейчас landed уже второй load-bearing proof target внутри S02: long-lived local stdio IPC для `session_list`.

## Landed proof targets

### 1. First proof target
- daemon-owned `session_list` projection materialized в `domains/session/rust/session-domain`;
- `core-daemon` умеет `--query session-list`;
- sidebar больше не зависит от hardcoded session list.

### 2. Second proof target
- `core-daemon` умеет `--serve-stdio` и держит line-delimited request/reply path;
- `WorkbenchCore/CoreDaemonClient.swift` держит long-lived process и сериализует запросы через actor;
- `OpenSlopProbe` делает два round-trip по одному и тому же daemon process;
- `WorkbenchRootView` показывает transport summary с reused daemon PID.

## Local evidence

- `cargo test -p core-daemon` -> PASS
- `cargo test -p session-domain` -> PASS
- `./target/debug/core-daemon --query session-list` -> PASS
- `swift build --package-path apps/macos-app --product OpenSlopApp` -> PASS
- `swift run --package-path apps/macos-app OpenSlopProbe` -> PASS with `reused=true`
- `make smoke` -> PASS
- `VISUAL-CHECK.md` -> updated

## Independent reviewer verdict

Verdict: PASS for this narrow sub-slice.

Strongest positive:
- Сам узкий runtime-path честный и доказан end-to-end: один живой daemon process, reuse по PID, один shared client path для probe и GUI.

Still-open scope for full S02:
1. persisted session truth;
2. projection rehydration beyond bootstrap data;
3. restart-safe continuation without seed-only bootstrap path.

## Next closure bar for S02

- persisted daemon-owned session truth;
- projection rehydration from real store;
- updated review verdict after those remaining blockers are закрыты.
