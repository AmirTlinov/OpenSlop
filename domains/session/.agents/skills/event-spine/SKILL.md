# Session Event Spine

## Когда использовать

Используй этот skill, когда задача касается session projection, daemon query, session truth store или первого реального IPC path между core-daemon и GUI.

## Локальные инварианты

- Session truth принадлежит daemon-owned domain code.
- Sidebar и probe читают одну и ту же daemon truth surface.
- Persisted store живёт в repo-local runtime path `.openslop/state/session-store.sqlite3`.
- Для S02 нужен узкий proof chain: persisted store -> daemon query/stdio -> probe -> GUI.
- Не раздувай это в полный event bus раньше времени.

## Текущий proof target

`reset store` -> `upsert proof session` -> `session-list` query -> `OpenSlopProbe` -> `WorkbenchRootView`.
