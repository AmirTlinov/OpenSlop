# S04 next slice — preflight after `645391e`

## 1) Scope verdict
Следующий честный sub-slice внутри S04 — не «полный PTY», не virtualization-first и не ещё один approval sweep.

Самый узкий правдивый ход: перестать терять `exec`-правду в текущем daemon-owned turn path. То есть провести typed `exec` / command-output surface через provider -> core-daemon -> GUI и сохранить optional `processId` как честную точку будущего PTY linkage.

## 2) Вопросы / ответы, которые реально меняют решение

### Q1. Следующий ход остаётся внутри уже доказанного `thread/read -> successive snapshots` contour или надо сразу прыгать в отдельный `command/exec` PTY lane?
**Текущий ответ:** сначала остаёмся внутри уже доказанного contour.

**Почему это меняет решение:** в живой schema `command/exec` уже есть, но repo пока не нормализовал этот owner-boundary в docs и коде, а текущий transcript model ещё даже `exec` честно не несёт. Прыжок сразу в отдельный PTY lane опирался бы на ложную поверхность данных.

### Q2. Нужна ли virtualization / AppKit-heavy terminal surface раньше typed command surface?
**Текущий ответ:** нет.

**Почему это меняет решение:** ADR-002 зовёт AppKit и virtualization там, где уже есть тяжёлая честная поверхность. Сейчас такой поверхности ещё нет: `exec` схлопывается в generic `tool` текст.

### Q3. Нужно ли перед PTY добивать ещё одну approval-family, например `permissions/requestApproval`?
**Текущий ответ:** не как mainline следующий шаг.

**Почему это меняет решение:** `STATUS.md` после `645391e` прямо фиксирует, что approvals lane уже done, а pending — `PTY и virtualization`. `permissions/requestApproval` остаётся отдельным graceful-path долгом, но не главным следующим slice.

### Q4. Какой минимальный инвариант должен быть у следующего slice, чтобы дальше PTY вообще был честным?
**Текущий ответ:** `exec` больше не теряется при парсинге и рендере: сохраняются item kind, command output и optional `processId`, а command output не смешивается с agent text в один суп.

**Почему это меняет решение:** без этого следующий PTY-шаг не к чему привязывать. Будет либо ложный terminal UI, либо новый transport без опоры в уже живом runtime contour.

## 3) Recommended narrow slice
Сделать typed `exec` transcript surface в уже существующем live-turn path: provider перестаёт схлопывать `exec` в generic `tool`, core-daemon и GUI протаскивают command/output/processId как отдельный честный item, а timeline показывает command-output отдельной карточкой, не смешанной с agent prose.

Least-lie acceptance: approval-enabled или tool-using turn даёт хотя бы один `exec` item, GUI показывает его как distinct command-output surface, и optional `processId` доезжает end-to-end без запуска ещё одного standalone PTY UI.

## 4) Cheap probe if needed
Уже выполнен один cheap probe:

```sh
tmp=$(mktemp -d) && codex app-server generate-json-schema --out "$tmp" >/dev/null && rg -n '"exec"|processId|aggregated from stdout and stderr|Identifier for the underlying PTY process' "$tmp" | sed -n '1,40p'
```

Что он подтвердил на локальном живом `codex app-server`:
- в turn/thread schemas есть `exec` items c aggregated command output;
- у них есть optional `processId` как точка PTY linkage;
- отдельно существует более широкий `command/exec` lane с `outputDelta`, `write`, `resize`, `kill`.

Именно поэтому следующий честный sub-slice — сначала перестать терять `exec`-структуру и `processId`, а не прыгать сразу в full PTY UI или virtualization.
