---
name: factory-next
description: Pega o primeiro item não marcado do backlog da Software Factory (.specs/factory/backlog.md) e roda o fluxo /factory nele. Use como `/factory-next` no terminal Maestro do Ground, à mão ou via Routine do Maestri.
---

# /factory-next

1. Leia `.specs/factory/backlog.md` (Ground). Itens são linhas `- [ ] <feature>`. O primeiro `- [ ]` é o próximo. Linhas `- [~] (job NNN)` estão em andamento, `- [x]` concluídas.
2. **Trava de concorrência**: se já existe um job nos stages `spec|plan-review|build|review|approve` em `.specs/factory/index.md` e o usuário não pediu paralelismo, **não comece outro** (floors paralelos competem por porta, CPU e contexto): responda "job <id> ainda em andamento" e pare. Uma Routine que dispara este comando de tempos em tempos depende disso para não empilhar jobs.
3. Sem item `- [ ]` ⇒ diga "backlog vazio" e pare (sem notificação).
4. Marque o item `- [~] (job <id>) <feature>` **antes** de iniciar e execute o fluxo completo da skill `factory` com o texto do item como `$ARGUMENTS`.
5. Ao fim do job (merged/approved), marque `- [x] (job <id>)`; se escalou, mantenha `- [~] (job <id>, needs-human)`.
