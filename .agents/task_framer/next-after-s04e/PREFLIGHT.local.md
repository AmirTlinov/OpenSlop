# Local preflight note

`task_framer` предложил следующим продуктовым шагом live transcript control transport.

Я сознательно закрыл более близкую дыру в уже shipped S04e surface: standalone control lane мог молча виснуть, если follow-up `write` или `terminate` не пришёл. Это fail-closed fix, не новый scope.
