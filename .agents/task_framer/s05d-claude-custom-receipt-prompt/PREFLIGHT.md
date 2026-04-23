# S05d Claude custom receipt prompt preflight

## Decisions

1. S05c materialized only a fixed bounded receipt session.
2. S05d adds one user-visible ability: user can supply a bounded Claude receipt prompt from the native start surface.
3. This is still not Claude chat. It is one-shot receipt generation with no resume, no multi-turn state, no approvals, no tools and no tracing.

## Critical questions

- Should the Claude prompt reuse the chat composer?
  - Current answer: no. Reusing chat composer would visually promise chat.
- Should the prompt be persisted as transcript/session history?
  - Current answer: not in S05d. Persisted truth remains latest receipt summary only.
- What proof closes S05d?
  - Current answer: custom marker prompt through WorkbenchCore -> daemon -> Claude receipt, plus visual review that GUI says receipt prompt rather than chat.

## Cheap probe result

Current daemon already accepts `inputText` on `claude-materialize-proof-session`. S05d needs GUI wiring, bounded prompt copy and a custom-marker probe.

## Boundary

S05d is custom receipt prompt input. It does not unlock arbitrary Claude chat.
