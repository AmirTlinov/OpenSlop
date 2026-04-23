# VISUAL CHECK

## Scope
Проверяем первый native pane для guided standalone `command/exec` proof contour.

## Reference basis
- `DESIGN.md`
- `docs/design/window-layout.mmd`
- `docs/design/reference-images/README.md`

## What was checked
- pane живёт в inspector и остаётся вторичным инструментальным surface;
- pane не маскируется под full terminal app;
- fixed proof command читается как bounded операционная truth, не как general-purpose terminal editor;
- stdin input читается как операционный control, не как giant markdown wall;
- output идёт в отдельном monospaced box;
- stage читается быстро: `idle`, `running`, `awaitingWrite`, `awaitingTerminate`, `completed`, `failed`;
- рядом есть честная note про fixed proof command и bounded contour без resize и reconnect promises.

## Honest note
Пока только semantic visual check. Пиксельного baseline у проекта всё ещё нет.
