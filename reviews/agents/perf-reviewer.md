# perf-reviewer

Назначение: Проверь budgets, lazy-loading, virtualization и отсутствие needless rerender storms.

Что считаем blocking finding:
- нарушение owning boundary;
- ложный успех без доказательства;
- деградация native UX или perf без явной причины;
- скрытая сложность, которую slice не признаёт.
