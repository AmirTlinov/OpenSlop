# VISUAL CHECK

## Scope
Проверяем маленькое GUI-уточнение вокруг уже существующего proof pane.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/README.md`

## What was checked
- pane остаётся во вторичном inspector surface;
- новый timeout copy читается как операционная truth, не как ложное обещание full runtime safety;
- основной акцент всё ещё на fixed proof command и stage badge;
- error/timeout мысль находится в supporting copy и не захламляет pane.

## Honest note
Пока semantic visual check. Пиксельного baseline у проекта всё ещё нет.
