# S03 codex runtime — short preflight

## 1) Первый кусок
Закрываем не весь S03.
Первый честный кусок: `core-daemon` поднимает `codex app-server`, проходит `initialize`, вызывает `thread/start` и материализует одну реальную Codex-thread в уже существующий `session_list` projection.

Вне этого куска: `turn/start`, streaming timeline, native approvals, `thread/resume` / `thread/fork`, `command/exec`, полная нормализация всех событий.

## 2) Вопросы, которые меняют решение
1. Первый кусок обязан дойти до реального `turn/start`, или честно можно остановиться на `thread/start -> session_list`?
   - Это решает, тащим ли сразу timeline/event-stream или держим scope в provider + session bootstrap.
2. Канонический `session_id` рождается в OpenSlop, или в первом куске принимаем `threadId` Codex как первичный ключ?
   - Это меняет контракт между `domains/provider` и `domains/session`.
3. Первый кусок считаем happy-path only при уже готовом локальном `codex`, или missing-login / missing-binary тоже обязаны выйти в daemon-owned fail-closed state?
   - Это меняет acceptance и первые UI/error surfaces.
4. Пинним protocol/schema версию сразу, или первый кусок допускает тонкий adapter поверх текущего generated schema?
   - Это меняет объём защитного кода и риск дрейфа.

## 3) Cheap probe
```sh
tmp=$(mktemp -d); codex --version; codex app-server generate-json-schema --out "$tmp" >/dev/null && rg -o '"(initialize|thread/start|thread/resume|thread/fork|turn/start)"' "$tmp/ClientRequest.json" | sort -u
```

Что проверяет: есть ли в локальном Codex явная граница между bootstrap thread lifecycle и полноценным turn path.
Текущий сигнал: да, на `codex-cli 0.123.0` видны `initialize`, `thread/start`, `thread/resume`, `thread/fork`, `turn/start`. Значит первый кусок можно честно резать как `initialize + thread/start -> session_list`, не таща сразу весь turn/approval path.
