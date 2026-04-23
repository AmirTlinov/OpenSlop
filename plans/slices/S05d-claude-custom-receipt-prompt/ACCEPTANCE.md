# ACCEPTANCE

S05d закрыт только если:

- Claude start surface содержит отдельное поле `Claude receipt prompt`.
- Поле не выглядит как generic dialog composer.
- Empty prompt fail-closed отклоняется до запуска bridge.
- Prompt больше 512 bytes fail-closed отклоняется до запуска bridge.
- Valid custom marker prompt проходит через real Claude proof.
- `session_list` содержит `claude-turn-proof-latest` с custom marker в title.
- Submit для Claude остаётся закрыт.
- Bottom composer не появляется для Claude receipt session.
- Review и visual-check зафиксированы в slice docs.
