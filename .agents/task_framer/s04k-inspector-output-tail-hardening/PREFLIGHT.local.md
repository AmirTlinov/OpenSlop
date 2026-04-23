status: answered

true_goal: Укрепить inspector output surfaces после S04j без ложного шага в live terminal control.
Снять риск тяжёлых монопространственных дампов в inspector и живом command card.

assumptions:
- live transcript `processId -> command/exec/write` bridge не reopen'ится;
- live read-only terminal pane и standalone proof pane пока остаются отдельными surfaces;
- следующий честный шаг — render-hardening, а не новый control transport.

minimal_slice:
- bounded tail projector для больших monospaced output surfaces;
- live terminal pane показывает хвост и честно сообщает про скрытый верх;
- standalone command/exec proof pane использует тот же bounded renderer;
- live terminal command card перестаёт дублировать весь output dump и отсылает к Inspector.

cheap_probe:
- synthetic terminal tail probe на 200+ строк, который доказывает clipping и сохранение последних строк.
