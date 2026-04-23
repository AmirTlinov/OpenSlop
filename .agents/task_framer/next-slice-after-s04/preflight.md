# Task preflight

## Goal
Выбрать самый ценный узкий следующий slice после S04 native approval lane без scope creep.

## Constraints
Repo-evidence first. Выбор только между PTY, command output surface, richer transcript item mapping или узкой альтернативой. Нужен bounded step, а не цепочка зависимых мини-рефакторингов.

## Decision-shaping questions
1. Что уже обещано roadmap/slice-артефактами сразу после S04, а что является лишь соблазнительной инфраструктурой?
2. Какой кандидат даёт пользовательски видимый прирост и при этом не требует сначала решить 2-3 соседних слоя?
3. Где proof surface уже почти готова, так что следующий slice может закрыться с ясным review/evidence, а не повиснуть на missing substrate?

## Cheap probe
Сверить формулировки в ROADMAP + plans/slices + AGENTS по PTY/output/transcript и найти ближайший already-shaped vertical slice.
