---
name: factory-approve
description: Finaliza um job da Software Factory aprovado ou escalado que o humano aceitou — arquiva e marca como pronto. A fábrica NÃO faz push, NÃO abre MR e NÃO faz merge/land; push para o origin e criação do MR são manuais seus. Use como `/factory-approve <job-id>` no terminal Maestro do Ground, só quando você pediu.
---

# /factory-approve

Job: **$ARGUMENTS**. Este comando finaliza localmente um job **aprovado** ou **escalado** que você aceitou. A fábrica trabalha só localmente: **nunca** faz `git push`, **nunca** abre MR e **nunca** faz merge/land em `main` nem em qualquer outra branch. Push para o `origin` e criação do MR são **seus, manuais**, até segunda ordem.

1. `job.json` do job: `stage` ∈ `approved|needs-human`; senão pare. Mostre ao usuário, em 5 linhas: `decision.md`/`escalation.md`, `git -C <FLOOR_PATH> diff --stat <BASE>..HEAD`, e o lembrete **branch `<BRANCH>` → MR para `<mr_target>`** (destino conforme o tipo: feat → release atual; release/hotfix → `main`).
2. Se `stage = needs-human`, o humano que digitou este comando está aceitando os gatilhos de escalada: registre `escalation_accepted_by: human` em `job.json`.
3. Arquive o job se ainda não está em `.specs/factory/archive/<id>/`.
4. Confirme o floor limpo (`git -C <FLOOR_PATH> status --porcelain --untracked-files=no` vazio; sujo ⇒ peça ao builder para commitar). O trabalho está pronto e commitado na branch local `<BRANCH>`.
5. **Instrua o passo manual** (a fábrica não executa): `maestri floor status "pronto: faça push de <BRANCH> e abra o MR → <mr_target>" --state review --floor "<floor>"`. Diga ao usuário os comandos que **ele** roda quando quiser, fora da fábrica: `git push -u origin <BRANCH>` e abrir o MR com destino `<mr_target>`.
6. **Só quando o usuário disser explicitamente que o MR já foi mergeado**, feche o job: stage `merged`, `index.md` e Note do job → raia `Factory · Concluídos`; remova o floor com a confirmação da interface: `maestri floor delete "<floor>"` (mantém a branch); `maestri floor status "job <id> concluído (MR mergeado)" --state done --floor "Ground"`. Enquanto o usuário não confirmar o merge, **deixe o floor de pé** e pare após o passo 5.
7. **Sem `git push`, sem MR, sem land/merge automático.** Tudo que toca `origin`/`main` é manual, feito por você.
