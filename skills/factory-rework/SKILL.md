---
name: factory-rework
description: Devolve ao builder um job da Software Factory (needs-human ou aprovado) com feedback do humano e reexecuta build, review e approve. Use como `/factory-rework <job-id> <nota>` no terminal Maestro do Ground.
---

# /factory-rework

Argumentos: **$ARGUMENTS** (primeiro token = id do job; o resto = nota do humano).

1. Leia `job.json` do job; `stage` ∈ `needs-human|approved|plan-review`; senão pare.
2. Grave a nota em `<FLOOR_PATH>/.specs/factory/jobs/<id>/human-feedback-<k>.md` (k = próximo número livre). Rework de humano **zera** o contador `reworks` (novo orçamento), mas `round` continua crescendo.
3. Se o builder ainda existe (`maestri list`), reutilize-o; senão recrute **Factory Builder** novo no floor e dê a ele a mensagem completa de tarefa (inclui os caminhos de `spec.md`, `plan.md`, `checks.md`, `build.md` e do feedback).
4. `maestri ask "<builder>" "<cabeçalho ROUND=<n+1>> TASK: rework conforme human-feedback-<k>.md; trate cada ponto, recommite (lint/test/build verdes), acrescente '## Round <n+1>' a build.md terminando com BUILD: DONE."`
5. stage `review`, `round += 1`; continue a skill `factory` no **passo 3 (Review)** — revisores novos, os 4 em paralelo, depois approver.
6. Mova a Note do job para `Factory · Em andamento` (`maestri note stack …`) e atualize o resumo dela.
