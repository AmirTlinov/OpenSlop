# ACCEPTANCE

- `core-daemon --claude-materialize-proof-session` запускает реальный Claude proof и возвращает `claude_proof_session_materialized`.
- Daemon upsert'ит `SessionSummary` с `provider=Claude` и `status=receipt_proven` или `receipt_failed`.
- Swift `WorkbenchCore` вызывает materialization через daemon stdio, не через прямой `claude`.
- `OpenSlopClaudeReceiptSessionProbe` видит exact marker и находит session в `session_list`.
- GUI Start при `Provider=Claude` создаёт только read-only receipt session.
- Submit/чат для Claude остаются disabled/fail-closed.
- Timeline показывает receipt как read-only evidence, без claims про resume, approvals, tools или tracing.
