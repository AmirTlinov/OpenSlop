# PREFLIGHT

## Decision-changing questions

1. Принимает ли реальный `codex app-server` same-connection `command/exec/resize` для PTY-backed standalone exec?
2. Можно ли доказать resize в уже существующем bounded control contour, не делая ложный transcript bridge claim?
3. Достаточно ли fixed proof command без отдельной resize UI-поверхности?

## Cheap probe verdict

- На этой машине реальный `codex app-server` принимает `tty=true` + initial `size=80x24` + same-connection `command/exec/resize(size=100x40)`.
- Honest proof требует, чтобы сам процесс после `SIGWINCH` напечатал новую геометрию. RPC ack сам по себе не считается доказательством.

## Scope lock

- Слайс живёт только в standalone `command/exec-control` lane.
- В scope: provider-domain, core-daemon, WorkbenchCore transport, fixed resize probe, smoke target.
- Вне scope: transcript pane control, arbitrary resize UI, reconnect, multi-client, kill semantics, full PTY runtime.

## Hidden risk

- PTY output chunking дробит линии иначе, чем предыдущий stdio contour. Значит control boundary должен опираться на marker-first proof command, а не на ожидание целой строки в первом delta.
