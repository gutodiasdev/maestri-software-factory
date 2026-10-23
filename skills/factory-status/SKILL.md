---
name: factory-status
description: Mostra o estado dos jobs da Software Factory (stage, round, reviews, floor) lendo index.md e os job.json. Somente leitura. Use como `/factory-status [job-id]`.
---

# /factory-status

Somente leitura: não recrute, não escreva, não notifique.

1. Leia `.specs/factory/index.md` (Ground) e, para cada job (ou só `$ARGUMENTS` se dado), o `job.json` em `<FLOOR_PATH>/.specs/factory/jobs/<id>/` (ou em `.specs/factory/archive/<id>/` se o floor já foi removido).
2. `maestri floor list` para o status ao vivo dos floors.
3. Imprima uma tabela: `id | feature | stage | round/reworks | security·api·data·code | floor | próximo passo` — o próximo passo é o comando exato (`/factory-continue 001`, `/factory-approve 001`, `/factory-rework 001 "…"` ou "aguardando agentes").
