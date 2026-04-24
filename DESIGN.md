# DESIGN

## Дизайн-цель

OpenSlop должен выглядеть как быстрый и взрослый macOS workbench. Он не копирует веб-IDE и не имитирует терминал. Он собирает лучшие macOS affordances вокруг агентной работы.

## Базовая анатомия окна

Окно делится на четыре рабочие зоны:
1. `sidebar` — спокойная карта задач: сегодня, в работе, нужно внимание, готовые итоги, проекты;
2. `timeline` — центральная narrative-поверхность текущей работы;
3. `inspector` — контекст по запросу: план и следы, позже map/browser/files;
4. `composer` — нижняя командная панель, где выбираются agent, model, effort, policy и prompt.

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
- Toolbar не владеет provider/model selection. Это живёт в composer рядом с намерением пользователя.
- Browser, map и files появляются как first-class surfaces только когда за ними есть projection.
- Verify не показывается как главный tab до harness/verify доменов. На поверхности остаются короткие human signals: `готово`, `нужно внимание`, `не доказано`, `устарело`.

## Антипаттерны

- вложенные rounded-card гробы;
- стеклянный шум ради моды;
- giant markdown wall вместо операционного UI;
- fake planned tabs как будто они уже live;
- смешивание agent stream, terminal dump и verify-сигналов в один текстовый суп;
- pixel-perfect зависимость от одного референса.

## Premium minimalism rule

Главный экран показывает работу, а не внутреннюю кухню. Доказательства остаются доступными во `Следах`, но не доминируют над разговором. Любой visible элемент должен быть `live fact`, `local setting`, `real command` или честный `unknown`. Planned-only поверхности не занимают primary UI.

## Timeline narrative rule

Центральный timeline — это история работы, а не лог-дамп. User prompt, agent reply, command, file change и receipt result идут по лёгкой вертикальной линии. Основная строка говорит человеческим языком. Raw output, stdin, process id, byte counts, bridge details и receipt proof раскрываются только по запросу или живут во `Следах`.

## Plan pane rule

Inspector `План` показывает repo-level vertical slice projection из daemon. Он не должен выглядеть как live verify dashboard. `proof`, `review` и `visual` markers отражают slice-документы, а не runtime harness truth.

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
