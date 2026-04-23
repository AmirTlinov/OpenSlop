# ACCEPTANCE

- `core-daemon` умеет пройти live `initialize -> thread/start` через локальный `codex app-server` по stdio.
- Результат `thread/start` materialize-ится в существующий `session_list` projection как реальная Codex session.
- GUI-кнопка `Запустить` создаёт такую session и выбирает её в sidebar.
- Есть отдельный probe, который доказывает: daemon process reused, `provider_thread_id == session_id`, и созданная Codex session реально попала в projection.
- В `domains/provider/contracts/` лежит pinned exact schema subset для текущего slice-owned protocol surface.
