# S01d-native-workbench-polish — Native shell polish

## Goal

Сделать текущий macOS GUI заметно ближе к настоящему Codex-style workbench, без fake runtime claims.

## Scope

Входит:
- системный window chrome: hidden title bar + unified toolbar;
- более плотный системный sidebar;
- центральная start/composer surface вместо инженерного unavailable-экрана;
- Inspector tabs: Summary / Verify / Browser;
- honest planned/unavailable wording для browser/verify;
- сохранение daemon-owned runtime truth.

## Non-goals

Не входит:
- Claude runtime;
- настоящий browser preview;
- browser automation;
- full verify/harness;
- новый provider state model;
- pixel clone Codex Desktop.

## Truth boundary

Этот slice меняет shell presentation. Он не добавляет новых runtime возможностей. Browser tab остаётся planned S07 surface, Verify tab остаётся pre-harness overview, а Git Review продолжает брать truth только из daemon snapshot.
