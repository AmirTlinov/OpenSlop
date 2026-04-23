# ACCEPTANCE

- В `domains/provider/contracts/codex-app-server/v0.123.0/witnesses/` лежит raw witness для live transcript control feasibility.
- Witness поднимает `codex app-server` по stdio, делает `initialize -> thread/start -> turn/start`, ждёт live `item/commandExecution/terminalInteraction`, берёт его `processId` и пытается на той же связи вызвать:
  - `command/exec/write(deltaBase64=...)`
  - `command/exec/write(closeStdin=true)`
- Witness печатает честный verdict:
  - `live_transcript_control_feasibility=confirmed`, или
  - `live_transcript_control_feasibility=rejected`, или
  - `live_transcript_control_feasibility=ambiguous`.
- Текущий smoke считается зелёным, если witness смог честно ответить `confirmed` или `rejected`.
- Docs фиксируют итоговый boundary без ложных GUI claims.
