# S01g premium timeline

## Outcome

Центральный timeline становится спокойной narrative-поверхностью. Он показывает ход работы человеческим языком, а доказательства и технический хвост остаются доступными по раскрытию или во вкладке `Следы`.

## Ownership

- `WorkbenchSeed` владеет presentation-проекцией уже существующих daemon facts.
- `TimelinePanelView` владеет только рендерингом timeline.
- `core-daemon` не меняется в этом slice.

## Boundaries

Slice не добавляет новую runtime truth, не включает fake browser/map/verify и не удаляет доказательства. Он меняет плотность и язык центральной поверхности.
