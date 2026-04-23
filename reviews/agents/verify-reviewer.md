# verify-reviewer

Назначение: Проверь gate model, UNKNOWN/STALE semantics и quality of context packs.

Что считаем blocking finding:
- нарушение owning boundary;
- ложный успех без доказательства;
- деградация native UX или perf без явной причины;
- скрытая сложность, которую slice не признаёт.
