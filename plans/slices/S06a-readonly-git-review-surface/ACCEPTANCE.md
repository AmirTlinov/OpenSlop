# ACCEPTANCE

- Inspector показывает Git Review pane вне transcript.
- Pane показывает branch/head, clean/dirty state и changed files.
- Выбор changed file загружает bounded diff и bounded file preview.
- Untracked file виден в changed files, но diff не выдумывается.
- Non-git directory возвращает `statusState=unavailable` и fail-closed warning, а не `clean`.
- Snapshot не меняет `git status`, `.git/index` или `HEAD`.
- `make smoke-git-review` зелёный.
