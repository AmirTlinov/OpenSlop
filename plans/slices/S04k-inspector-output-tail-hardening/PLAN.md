# S04k-inspector-output-tail-hardening — Bounded tail для inspector output surfaces

## Goal

Укрепить live read-only terminal pane после S04j: большие terminal/output dumps больше не должны раздувать inspector и live command card в тяжёлую простыню. Inspector держит только честный хвост вывода и явно говорит, что верх скрыт.

## Touches

- `apps/macos-app`
- `plans/slices/S04-transcript-approval-pty`

## Non-goals

В этот слайс не входят:
- live transcript control bridge;
- `write` / `terminate` / `resize` для transcript terminal pane;
- full transcript virtualization;
- persistence claims для clipped output;
- новый provider/core-daemon protocol.

## Truth surface

Слайс честно закрыт, если репозиторий доказывает четыре факта:
1. output-heavy inspector surfaces materialize только bounded tail, а не весь накопленный dump;
2. UI явно сообщает, что верх скрыт, когда clipping реально сработал;
3. live terminal command card в timeline остаётся компактным и не дублирует полный dump, если этот command уже pinned в Inspector;
4. live read-only boundary не меняется: pane по-прежнему не притворяется interactive terminal.
