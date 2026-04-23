# native-ui-reviewer

Назначение: Проверь анатомию окна, native affordances, hierarchy, keyboard-first путь и соответствие DESIGN.md.

Что считаем blocking finding:
- нарушение owning boundary;
- ложный успех без доказательства;
- деградация native UX или perf без явной причины;
- скрытая сложность, которую slice не признаёт.
