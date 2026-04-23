true_goal:
- выбрать следующий smallest honest slice после S01b, не выдумывая phase truth.
- дожать остаток S01 как честную window grammar и empty shell presentation.

least_lie_interpretation:
- следующий ход не про loading/error semantics.
- это узкий UI-only slice в `apps/macos-app`: убрать synthetic runtime-storytelling и показать first-class empty state там, где truth уже есть.

critical_questions: []

honest_acceptance:
- центр окна больше не притворяется `S04` proof lane и не рассказывает будущую runtime-историю.
- path без transcript рендерится как честный empty/unavailable surface, а не как synthetic карточки.
- live transcript и текущие inspector surfaces продолжают работать без новых phase claims.

next_move_for_parent:
- сузить следующий slice до first-class empty window grammar внутри `S01`.
- начать с timeline fallback: убрать `S04` badge и synthetic proof cards, затем отрендерить честный empty center state на уже существующей truth.

possible_parent_miss:
- empty не заблокирован; заблокированы только loading/error, а нынешние synthetic `S04` плейсхолдеры как раз маскируют честный empty state.

first_target_file:
- apps/macos-app/Sources/OpenSlopApp/WorkbenchSeed.swift

minimal_change_shape:
- заменить fallback без transcript на узкий empty/unavailable model без `S04` и proof-storytelling; `TimelinePanelView` должен показать его как first-class empty surface, а не как карточки-заменители.

first_command:
- swift build --package-path apps/macos-app --product OpenSlopApp

hard_blocker:
- none
