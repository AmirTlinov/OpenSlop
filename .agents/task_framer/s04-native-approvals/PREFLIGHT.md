# S04 native approvals — preflight

## 1) Scope verdict
Следующий честный slice — не «все approvals для S04», а один daemon-owned active approval для Codex `app-server`, с минимальным native sheet/popover UI и явным approve/deny path.

Самый узкий честный вариант: сначала закрыть только `item/commandExecution/requestApproval`. Вне scope: `item/fileChange/requestApproval`, `item/permissions/requestApproval`, approval cache/policy amendments, PTY, virtualization, global approval center и любой общий S04-polish.

## 2) Вопросы/ответы, которые меняют реализацию

### Q1. Approval truth приходит из transcript или из server->client request lane?
**Текущий ответ:** из отдельного server->client request lane. Cheap probe по полному `codex app-server` schema показал `item/commandExecution/requestApproval`, `item/fileChange/requestApproval` и `item/permissions/requestApproval` как server-initiated requests. Текущий transport в `provider-domain` любые входящие сообщения с `method` просто пропускает.

**Почему это меняет ход:** первый шаг живёт в provider/core-daemon transport и daemon-owned state. Одним только transcript/UI это не закрыть.

### Q2. Какой approval family брать первой?
**Текущий ответ:** только `item/commandExecution/requestApproval`.

**Почему это меняет ход:** это самый маленький реальный approve/deny path без PTY. `fileChange` пока слепой без diff surface, а `permissions` уже тащит широкий policy UX.

### Q3. Что в минимальном UI значит «deny»?
**Текущий ответ:** safest default — маппить на `cancel`, а не на `decline`.

**Почему это меняет ход:** schema различает «отклонить и продолжить turn» и «отклонить и сразу прервать turn». Для fail-closed первого slice нельзя прятать этот выбор под одной неявной кнопкой.

### Q4. Нужен ли уже сейчас queue/approval center?
**Текущий ответ:** нет. Для первого slice достаточно одного active approval, привязанного к выбранной session.

**Почему это меняет ход:** иначе slice расползётся в sidebar/inspector center, session queues и broad native polish.

## 3) Recommended narrow slice
Сделать daemon-owned single active `commandExecution` approval lane: `core-daemon` держит pending approval state и request id, GUI показывает один native sheet с command/cwd/reason и кнопками `Approve` / `Deny`, а ответ уходит назад в тот же живой app-server transport.

Least-lie acceptance: живой turn доходит до pending approval, GUI показывает native approval sheet без polling from UI, `Approve` продолжает turn, `Deny` fail-closed прерывает turn, transcript lane после решения остаётся daemon-owned.

## 4) Cheap probe
Уже выполнен один cheap probe: `codex app-server generate-json-schema --out /tmp/openslop-approval-probe...`.

Что он подтвердил:
- approvals для `turn/start` приходят server->client request'ами, а не как transcript-only surface;
- есть три разные семьи: `item/commandExecution/requestApproval`, `item/fileChange/requestApproval`, `item/permissions/requestApproval`;
- у command/file-change deny есть два разных смысла: `decline` и `cancel`.

## 5) Post-implementation note
Реальный коммит сохранил этот же основной proof target: живой `commandExecution` approval lane.

Заодно в transport добавлен minimal shared parsing/response path и для `item/fileChange/requestApproval`, потому что это тот же server-request contour и он дешёвый по коду. `item/permissions/requestApproval` по-прежнему вне scope.
