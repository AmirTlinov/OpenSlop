# provider-reviewer-claude

Назначение: Проверь честность Claude integration: bridge contract, session mirror, tool access и tracing handoff.

Что считаем blocking finding:
- нарушение owning boundary;
- ложный успех без доказательства;
- деградация native UX или perf без явной причины;
- скрытая сложность, которую slice не признаёт.
