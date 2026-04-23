status: answered

true_goal: Выбрать следующий честный bounded шаг после S04k, чтобы вернуть движение по S01 shell без ложного claim про полный polish.

critical_questions:
- question: Нам нужен весь S01 целиком прямо сейчас, или честнее закрыть узкий sub-slice на state restoration + shell affordances?
  current_best_answer: честнее узкий sub-slice
  why_it_changes_next_move: Иначе scope раздуется до всего window shell и reference pipeline сразу.
- question: Нужно ли уже сейчас тащить реальный screenshot automation?
  current_best_answer: нет, semantic reference images достаточно для первого shell шага
  why_it_changes_next_move: Иначе slice уедет в будущий visual-conformance tooling.
- question: Layout restoration должен включать полноценное split-size persistence?
  current_best_answer: нет, для первого шага достаточно selection/provider/effort/inspector visibility
  why_it_changes_next_move: Полное persistence для split geometry заметно расширяет реализацию и proof.

next_move_for_parent: S01a-workbench-shell-state-restoration. Узко: persisted shell state, inspector toggle, keyboard path, first semantic reference images.
