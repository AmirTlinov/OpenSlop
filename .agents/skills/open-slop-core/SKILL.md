---
name: open-slop-core
description: >-
  Core router for OpenSlop when a task crosses multiple domains and needs
  product-wide context: native macOS workbench, provider plurality, event
  spine, browser, harness, and fail-closed verify.
---

# OpenSlop Core

## Когда использовать

Используй этот skill, когда задача пересекает несколько доменов сразу и ей нужен общий продуктовый контекст: native macOS workbench, provider plurality, event spine, browser, harness и fail-closed verify.

## Главные инварианты

- UI не источник истины.
- Provider integration идёт через capability model.
- Browser, verify, harness и artifacts принадлежат платформе.
- `AGENTS.md` остаётся картой. Подробности идут в owning docs.
- Реализация идёт вертикальными слайсами с review closure.

## Стартовое чтение

1. `PHILOSOPHY.md`
2. `ARCHITECTURE.md`
3. `DESIGN.md`
4. `ROADMAP.md`
