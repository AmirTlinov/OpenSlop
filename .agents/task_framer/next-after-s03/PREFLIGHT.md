# Next after S03

## Что закрываем следующим
Не весь S04 целиком.
Следом закрываем первый честный кусок S04: daemon-owned read-only transcript lane для уже materialized Codex session.
Цель: убрать seeded timeline из центра, прочитать реальную session truth и отдельно показать agent output vs tool activity.
Approval center, PTY drawer, turn submit и virtualization — не в этом куске.

## Вопросы
1. Первый источник transcript truth — `thread/read` snapshot или notification/event capture?
2. Approval нужно тащить в этот же кусок, или честно оставить следующим после read-only transcript?
3. Seeded/bootstrap sessions остаются временно, или для transcript lane уже нужен invariant `live-only truth`?

## Cheap probe
Для live session из S03 один раз проверить: `thread/read` на текущем pinned `codex app-server` вообще возвращает непустые turns/items по `provider_thread_id`.
Если да — идём в snapshot transcript lane.
Если нет — следующий кусок надо начинать с capture/persistence контракта, а не с UI.
