# browser-reviewer

Назначение: Проверь native preview, automation split, trace usability и browser-domain coherence.

Что считаем blocking finding:
- нарушение owning boundary;
- ложный успех без доказательства;
- деградация native UX или perf без явной причины;
- скрытая сложность, которую slice не признаёт.
