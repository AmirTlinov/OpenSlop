# REVIEW

## Reviewers
- provider-reviewer-claude
- architecture-reviewer

## What must be checked
- Граница owning domains не пробита.
- Слайс не тащит лишний scope.
- Acceptance доказан реальными артефактами.
- Если тронут GUI, он сверяется с `DESIGN.md` и relevant reference images.

## Required evidence
- локальные проверки, которые реально подтверждают slice outcome;
- список changed surfaces;
- reviewer verdict c blocking или non-blocking выводом.
