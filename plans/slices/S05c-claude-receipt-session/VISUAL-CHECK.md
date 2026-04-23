# VISUAL-CHECK

## Surface checked

- Start surface with `Provider=Claude`.
- Toolbar start action with `Provider=Claude`.
- Sidebar action label.
- Timeline for `claude-turn-proof-latest`.

## Semantic result

PASS after visual reviewer blockers were fixed.

Verified behavior:
- Start surface says `Создать Claude receipt session`, not chat.
- Claude mode overrides generic empty-state title/detail/recovery text with receipt/read-only copy.
- Claude mode hides prompt textbox and task suggestions on the start surface.
- Toolbar says `Claude receipt`, not generic launch.
- Sidebar says `Новая session`, not `Новый чат`.
- Timeline renders a single read-only evidence card for the materialized receipt.
- Submit remains disabled for Claude.
- Bottom composer is hidden for Claude receipt sessions.

## Fail-closed visual law

A user may infer that a bounded Claude receipt can be created. A user must not infer that arbitrary Claude chat, resume, approvals, tools or tracing are implemented.
