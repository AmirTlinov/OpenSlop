# provider-reviewer-codex

Назначение: Проверь честность Codex integration: app-server path, session lifecycle, approvals и schema strategy.

Что считаем blocking finding:
- нарушение owning boundary;
- ложный успех без доказательства;
- деградация native UX или perf без явной причины;
- скрытая сложность, которую slice не признаёт.
