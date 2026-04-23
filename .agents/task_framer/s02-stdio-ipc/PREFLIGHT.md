# S02 stdio IPC — preflight

status: preflight_not_needed

true_goal: Убрать per-query launch `core-daemon` из app-side path.
Доказать минимальный long-lived local stdio channel для `session_list`.

least_lie_interpretation: Первый bounded ход — не весь IPC layer и не subscriptions.
Нужен один daemon process, один tiny request/response contract и reuse из Swift-side client.

honest_acceptance: Один запущенный daemon обслуживает как минимум два последовательных `session-list` запроса по stdin/stdout без перезапуска.
`OpenSlopProbe` или тот же `WorkbenchCore` path читает оба ответа через один process lifetime.

critical_questions: []

next_move_for_parent: Сначала зафиксировать минимальный stdio envelope и daemon loop только для `session-list`.
Потом перевести `WorkbenchCore/CoreDaemonClient.swift` с one-shot `Process()` на reuse одного процесса.

possible_parent_miss: Без явной границы кадра ответов stdio-proof быстро упрётся в парсинг и deadlock.

first_target_file: services/core-daemon/src/main.rs

minimal_change_shape: Добавить explicit `--stdio` mode с tiny request/response loop для `session-list`, затем тонко переписать `CoreDaemonClient` на persistent process + stdin/stdout round-trip.

first_command: swift run --package-path apps/macos-app OpenSlopProbe

hard_blocker: none
