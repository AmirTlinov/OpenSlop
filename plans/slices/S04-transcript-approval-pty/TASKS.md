# TASKS

- [x] Зафиксировать narrow scope: `live turn -> successive transcript snapshots`.
- [x] Доказать fresh-process boundary и выделить rehydration law для Codex thread lifecycle.
- [x] Добавить daemon-owned runtime registry для первого turn до materialization.
- [x] Протянуть `thread/read`, `thread/resume`, `turn/start` в provider/core-daemon/gui path.
- [x] Разрезать blocking submit на streaming successive snapshots и terminal snapshot.
- [x] Добавить live probe и cold-read proof для transcript lane.
- [x] Протянуть server-initiated approval request lane из `codex app-server` в provider/core-daemon/SwiftUI.
- [x] Сделать minimal native approval sheet с `Разрешить` / `Отклонить`.
- [x] Добавить live approval proof для `commandExecution/requestApproval`.
- [x] Перестать терять typed `commandExecution` и minimal `fileChange` activity внутри streaming transcript path.
- [x] Протянуть `command`, optional `processId`, optional `exitCode` и command output до GUI как отдельную timeline surface.
- [x] Обновить slice docs, AGENTS карты и pinned schema subset.
