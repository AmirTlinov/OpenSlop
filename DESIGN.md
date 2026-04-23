# DESIGN

## Дизайн-цель

OpenSlop должен выглядеть как быстрый и взрослый macOS workbench. Он не копирует веб-IDE и не имитирует терминал. Он собирает лучшие macOS affordances вокруг агентной работы.

## Базовая анатомия окна

Окно делится на четыре рабочих зоны:
1. `sidebar` — проекты, сессии, очереди, pinned и running lanes;
2. `timeline` — центральная narrative-поверхность текущей сессии;
3. `inspector` — verify, diff, browser, files, artifacts, metrics;
4. `composer` — нижняя командная панель с provider, model, effort, policy и prompt.

## Что делает интерфейс нативным

- split views и inspector-паттерн из macOS;
- toolbar с короткими действиями и сегментами;
- keyboard-first navigation;
- быстрые sheets и popovers для approvals;
- real scrolling surfaces без тяжёлого перерендера;
- AppKit для тяжёлых контролов, SwiftUI для shell и композиции.

## Визуальная грамматика

- Один сильный фокус на экране. Нет десятка равноправных карточек.
- Типографика сильнее декоративного хрома.
- Sidebar, timeline и inspector должны читаться с первого взгляда.
- Browser и diff — это first-class surfaces, не всплывающие игрушки.
- Verify состояния должны читаться моментально: `PASS`, `FAIL`, `UNKNOWN`, `STALE`, `BLOCKED`, `DEGRADED`.

## Антипаттерны

- вложенные rounded-card гробы;
- стеклянный шум ради моды;
- giant markdown wall вместо операционного UI;
- смешивание agent stream, terminal dump и verify-сигналов в один текстовый суп;
- pixel-perfect зависимость от одного референса.

## Visual conformance

GUI сверяется с референсами семантически:
- анатомия окна;
- hierarchy;
- плотность;
- macOS-native поведение;
- discoverability для клавиатуры.

Reference images живут в `docs/design/reference-images/` и в slice-local `reference-images/`, когда это нужно.

## Доступность

- Все основные действия обязаны иметь keyboard path.
- Контраст и selected state должны быть читаемыми без hover.
- Screen-reader friendliness важен с первых реальных экранов, не в последнюю неделю.

## Provider status surfaces

Если provider выбран, но его runtime path ещё не доказан, GUI обязан показывать fail-closed status. Status card говорит, что реально найдено, какие capabilities только CLI-level, и какие bridge-возможности ещё planned.
