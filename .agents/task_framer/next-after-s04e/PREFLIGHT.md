# Next after S04e — preflight

status: preflight_not_needed

true_goal: После S04e выбрать следующий bounded slice, который честно двигает незакрытый S04.
Нужен шаг без нового probe и без ложного прыжка в general-purpose terminal.

least_lie_interpretation: Самый честный следующий slice — не полировка standalone inspector pane, а minimal live transcript control transport.
Граница slice: только write + graceful close stdin + terminate поверх уже существующих `command/exec` операций.
`resize`, `virtualization`, `reconnect`, `multi-client` и `arbitrary control order` остаются вне claims.

honest_acceptance: Из live transcript lane есть surfaced control path до runtime для `write` / `close stdin` / `terminate`.
Есть bounded proof/UI path и evidence, но без claims про full terminal, resize или virtualization.

critical_questions: []

next_move_for_parent: Формулировать следующий slice как minimal live transcript control transport, а не как standalone `closeStdin` follow-up.
В acceptance сразу прибить `write + close stdin + terminate`; `resize` и `virtualization` оставить отдельными slice.

possible_parent_miss: Отдельный standalone `closeStdin` slice выглядит дешёво и приятно, но это ложный прогресс: главный незакрытый gap всё ещё в live transcript control transport.

first_target_file: unknown

minimal_change_shape: протянуть outbound control из live transcript lane к уже существующим `write`/`terminate` операциям и открыть `closeStdin` path без расширения claims

first_command: unknown

hard_blocker: none

cheap_probe_already_done:
- live transcript terminal lane сейчас не показывает surfaced outbound control transport; в repo видны только standalone операции `codex-command-exec`, `codex-command-exec-stream`, `codex-command-exec-control-stream`, `codex-command-exec-write`, `codex-command-exec-terminate`.
- В standalone `command/exec/write` уже протянут `closeStdin` через contract -> Swift DTO -> `CoreDaemonClient` -> provider validation, но отдельного proof/UI slice для graceful close stdin пока нет.
