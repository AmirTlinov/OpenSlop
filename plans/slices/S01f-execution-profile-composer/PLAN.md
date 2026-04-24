# S01f execution profile composer

## Outcome

Composer и start surface получают daemon-owned capability snapshot по Codex/Claude. GUI больше не полагается только на локальный provider/model draft и показывает честный runtime level: `live`, `receiptOnly` или `unavailable`.

## Ownership

- `core-daemon` владеет `execution-profile-status` projection.
- `WorkbenchCore` владеет DTO и client call.
- `OpenSlopApp` только отображает capability status и использует provider models из projection.

## Boundaries

Slice не открывает full Claude chat, не добавляет remote providers и не меняет Codex turn protocol. Claude остаётся receipt-only до отдельного lifecycle bridge slice.
