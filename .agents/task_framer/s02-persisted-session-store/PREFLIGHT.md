status: need_answers

true_goal: убрать seed-only bootstrap из session truth
сделать узкий daemon-owned persisted source + rehydration для `session_list`, без большого persistence/event-bus слоя

least_lie_interpretation: нужен не “почти S02 целиком”, а один честный промежуточный truth surface
он должен переживать restart и поднимать projection из реального store, а не из hardcoded seeds

honest_acceptance: после рестарта daemon восстанавливает `session_list` не из `bootstrap_session_projection()`
rehydration идёт из persisted daemon-owned state
полный event bus и большая persistence stack в этот шаг не втянуты

critical_questions:
- question: в этот slice уже должен входить хотя бы один daemon-side mutation path session truth, который переживает restart, или первый шаг честно ограничен только load-or-init/rehydration?
  current_best_answer: unknown
  why_it_changes_next_move: это решает, трогаем ли только bootstrap/query path или сразу IPC/write path

next_move_for_parent: сначала снять рамку по mutation path
потом резать один bounded patch вокруг daemon-owned load/rehydrate boundary

possible_parent_miss: если сейчас нет mutation path, легко случайно сделать persisted seed-cache и назвать это restart-safe continuation

first_target_file: services/core-daemon/src/main.rs

minimal_change_shape: заменить прямой вызов `bootstrap_session_projection()` на daemon-owned load/rehydrate boundary

first_command: unknown

hard_blocker: none
