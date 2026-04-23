# S06a-readonly-git-review-surface — Read-only Git review surface

## Goal

Дать первый честный Git review слой в Inspector: branch/head, dirty status, changed files, bounded diff и bounded file preview.

## Scope

Входит:
- daemon-owned Git snapshot;
- typed Swift DTO и client method;
- read-only Inspector pane;
- dirty fixture proof с tracked modified + untracked file;
- fail-closed non-git path.

## Non-goals

Не входит:
- stage, commit, revert, checkout и apply patch;
- artifact registry;
- worktree/session binding;
- provider turn diff semantics;
- full S06 artifact lifecycle.

## Truth surface

Git truth берётся одним daemon snapshot. Swift показывает уже готовый snapshot и не вызывает `git` сам.

Snapshot не мутирует repository. Proof сравнивает `git status --porcelain=v1 -z`, `.git/index` и `HEAD` до и после чтения. Git reads идут с `GIT_OPTIONAL_LOCKS=0`.
