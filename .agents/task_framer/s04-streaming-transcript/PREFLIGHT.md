# S04 streaming transcript preflight

Контекст: внутри `S04-transcript-approval-pty` уже закрыт первый proof target — `first live turn round-trip + daemon-owned read-only transcript snapshot`.

## Вопросы / проверки

1. **Под `streaming transcript lane` здесь имеется в виду polling successive transcript snapshots, а не push-notifications или token-deltas?**  
   Текущий лучший ответ: **скорее да**. Нынешний long-lived stdio transport в `CoreDaemonClient` остаётся request/reply. Если нужен push, это уже не узкий шаг внутри текущего contour.

2. **Cheap probe:** на реальном `codex-cli 0.123.0` во время активного turn `thread/read(includeTurns=true)` правда возвращает `turn.status = inProgress` и частичные `items`, или partial visibility появляется только после terminal state?  
   Текущий лучший ответ: **live = unknown**. Но `provider-domain` test stub уже моделирует именно этот contour: первый `thread/read` даёт user item + `inProgress`, следующий — final agent item + `completed`.

3. **Active-turn truth остаётся daemon-owned, а GUI только перерисовывает successive snapshots?**  
   Текущий лучший ответ: **да**. `apps/macos-app/AGENTS.md` прямо запрещает утечку runtime truth в UI. Если GUI начнёт владеть turn lifecycle, шаг сразу распухнет и пробьёт границу owning surface.

4. **Первый streaming slice остаётся transcript-only: без approvals, PTY, virtualization и без попытки красиво решать tool-chatter?**  
   Текущий лучший ответ: **да**. Это совпадает с `S04 PLAN` и `S04 REVIEW`; иначе шаг снова смешается с соседними незакрытыми темами.

## Очень короткий verdict

Самый узкий честный next step: **разрезать текущий blocking `submit-turn -> wait terminal snapshot` на `start turn` + daemon-owned polling `thread/read` до terminal state, а GUI оставить thin renderer successive transcript snapshots**.

Если cheap probe покажет, что mid-turn `thread/read` не даёт partial items, надо **сразу остановиться и переопределить шаг**, а не начинать UI-стриминг на ложной предпосылке.
