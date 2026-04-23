# S06a preflight — read-only Git review surface

## true_goal

Дать маленький read-only Git review slice после S04, без расползания в полноценный Git-клиент.

## least_lie_interpretation

UI показывает branch/status, changed files и bounded diff/file preview в Inspector. Git не мутируется. Worktree/session/artifact registry не входят, если не нужны для доказательства.

## honest_acceptance

На dirty-fixture видно ветку, статус, список изменённых файлов. Выбор файла открывает ограниченный preview/diff в Inspector. Проверка доказывает, что slice ничего не stage/commit/write в Git не делает.

## critical_questions

Нет вопросов, которые меняют реализацию сейчас.

## risk

Главный риск — случайно начать Git client. Защита: только read-only fixture proof и bounded preview.
