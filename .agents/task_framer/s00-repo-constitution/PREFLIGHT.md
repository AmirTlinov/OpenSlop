# S00 preflight

## Подлинная цель

Сделать первый load-bearing commit для нового flagship-репозитория OpenSlop: поставить корневые карты, bounded-context топологию, slice roadmap и минимальные рабочие seeds, чтобы дальнейшая реализация шла по устойчивому маршруту, а не по chat-only памяти.

## Наименее ложная интерпретация

Первый слайс должен быть тонким, но реальным. Он не может состоять только из красивых документов. Ему нужны хотя бы один buildable macOS seed, один buildable daemon seed и одна shape-проверка репозитория.

## Вопросы, которые реально меняют первый слайс

1. Нужен ли уже в S00 buildable seed, или хватит только карт и roadmap?
   - Да, нужен. Иначе получится декоративная оболочка без опорного артефакта.
2. Нужно ли материализовать сразу все planned roots?
   - Да, но честно. Только карты и минимальные entrypoints. Без fake code stubs и без энциклопедий.

## Cheap probe

Репозиторий пустой и ещё не инициализирован как git-репозиторий. Значит, S00 должен владеть и git bootstrap, и первичной структурой.

## Следующий шаг

Создать `main`-репозиторий, root docs, domain routers, slice folders, reviewer profiles, minimal macOS shell seed, minimal core-daemon heartbeat и repo-shape doctor.
