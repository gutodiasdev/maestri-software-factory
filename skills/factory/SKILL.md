---
name: factory
description: Orquestra a Software Factory no Maestri (Maestro Mode): spec → build → 4 revisões em paralelo → approver → trabalho pronto na branch local (push e MR são manuais seus), com um Floor (git worktree) por job. Use como `/factory <feature>` no terminal Maestro do Ground. Não use em terminais de floor nem para tarefas pequenas fora do fluxo.
---

# /factory — orquestrador

Feature recebida: **$ARGUMENTS**

```
feature → spec-writer → [plan gate] → builder → [security, api, data, code] → ESPERA OS 4
                                         ▲                                      │
                                         └─── algum CHANGES: retoma o builder ◄─┤
                                                                                ▼ todos PASS
                pronto (push+MR manual) ◄── APPROVE ── approver ── ESCALATE → needs-human
```

Você é o **único** que escreve `job.json`. Regras de ouro: arquivos são a verdade; só você decide a etapa; `VERDICT:`/`APPROVE`/`ESCALATE` se **leem** do arquivo, nunca da sua impressão; o builder é **retomado**, nunca recriado (máx. `factory.max_reworks`); revisores são **novos a cada rodada** (independência). **A fábrica trabalha só localmente: nunca faz `git push`, nunca abre MR, nunca faz merge/land em nenhuma branch.** O desfecho de um APPROVE é o trabalho **commitado na branch local do floor**; `push` para o `origin` e criação do MR são **manuais, seus**, até segunda ordem.

## Convenções (use em todas as etapas)

- **MEU_NOME**: o nome em `You:` de `maestri list`. Vai em toda tarefa, para o agente responder.
- **CFG**: leia o bloco `factory.*` de `AGENTS.md` (plan_gate, auto_land, max_reworks, base_branch, release_branch). `base_branch: current` ⇒ `git branch --show-current` no Ground.
- **SKILLS por fase**: leia `factory.phases.<fase>.skill` de `AGENTS.md` para resolver **SKILL_DISCOVER**, **SKILL_PLAN**, **SKILL_BUILD**. Linha ausente ⇒ default: `discover=tlc-discover`, `plan=tlc-spec-lean`, `build=tlc-spec-lean`. Cada fase injeta `SKILL=<nome>` na tarefa do agente (ver *Mensagem de tarefa*), e os gates que você roda dependem da skill — veja *Contratos de fase* abaixo.
- **TIPO/BRANCH**: a feature normalmente vem do intake. Procure a linha desta issue em `.specs/factory/selected.tsv` (TAB: `IID⟶TÍTULO⟶TYPE⟶BRANCH`):
  - achou ⇒ use `TYPE` (`feat|release|hotfix`) e `BRANCH` dela.
  - não achou ⇒ pergunte ao usuário o tipo e monte: `feat` ⇒ `feat/<slug>`; `release` ⇒ `release-v<versão>`; `hotfix` ⇒ `hotfix-v<versão>`. **Nunca invente versão**: para release/hotfix sem versão, pergunte; sem resposta, escale (**6b**).
- **MR_TARGET** (apenas **informativo** — para onde VOCÊ abrirá o MR manualmente depois; a fábrica não abre):
  - `feat` ⇒ a **release atual**: `factory.release_branch` de `AGENTS.md`, senão a `release-v*` mais recente entre as branches conhecidas localmente (`git branch -a`/`-r`, **sem rede**). Nenhuma conhecida ⇒ pergunte ao usuário (ou registre `mr_target: "<definir>"` e siga).
  - `release` ⇒ `main`.
  - `hotfix` ⇒ `main`.
- **FLOOR_PATH**: caminho do clone, da linha do floor em `maestri floor list`. **JOB_DIR** (relativo ao floor): `.specs/factory/jobs/<id>`. Você lê/escreve em `<FLOOR_PATH>/<JOB_DIR>/…` a partir do Ground.
- **Mensagem de tarefa** (cabeçalho fixo, depois a tarefa):
  `JOB_ID=<id> JOB_DIR=<JOB_DIR> FEATURE=<slug> BASE=<sha> ROUND=<n> SKILL=<skill da fase> MAESTRO="<MEU_NOME>"` + `TASK: …` + a linha final *"Ao terminar, responda com `maestri ask "<MEU_NOME>" "<resumo>"` conforme o protocolo da fábrica."* (`SKILL` = SKILL_PLAN na spec, SKILL_BUILD no build; o agente lê `.kiro/skills/<SKILL>/SKILL.md` e segue o contrato daquela fase.)
- **Codinomes**: invente um por agente (curto, sem repetir o papel). Registre `papel → codinome` em `job.json.agents`.
- **Status do floor** a cada transição: `maestri floor status "<etapa: o que acontece>" --state working --progress k/5 --floor "<floor>"` (etapas: 1 spec, 2 build, 3 review, 4 approve, 5 pronto). `--state review`/`blocked`/`done` também notificam o usuário: use só quando verdade.
- **job.json** (modelo; reescreva a cada transição, e atualize a Note do job no painel kanban, veja *Painel* abaixo):
  ```json
  { "id": "001", "feature": "<texto original>", "slug": "<slug>", "floor": "001-<slug>", "branch": "<BRANCH>",
    "branch_type": "feat|release|hotfix", "mr_target": "<branch alvo — informativo p/ o MR manual>",
    "base_branch": "<branch>", "base": "<sha>", "stage": "spec|plan-review|build|review|approve|approved|needs-human|merged|failed",
    "round": 1, "reworks": 0, "agents": {"spec-writer": "", "builder": "", "approver": ""},
    "reviews": {"security": "", "api": "", "data": "", "code": ""}, "decision": "", "updated": "<ISO>" }
  ```

## Contratos de fase (qual gate rodar por skill)

A skill de cada fase define o artefato, o token de pronto e **se há validador** para você rodar. Resolva a skill (SKILL_PLAN/SKILL_BUILD) e use a linha correspondente. Skill desconhecida ⇒ trate como a linha genérica: confira que o artefato existe e que o token é a 1ª linha, e **pule os validadores**.

| Fase | Skill | Artefato(s) que você confere | Token (1ª linha) | Validadores que você roda (exit 0) |
| --- | --- | --- | --- | --- |
| plan | `tlc-spec-lean` (default) | `.specs/features/<slug>/plan.md` + `checks.md` e `JOB_DIR/spec.md` | `SPEC: READY` em `spec.md` | `validate_plan.py <slug>` e `validate_checks.py <slug>` |
| plan | `tlc-plan` | `.tasks/<slug>.md` e `JOB_DIR/spec.md` | `SPEC: READY` em `spec.md` | nenhum (sem scripts — pule o gate) |
| plan | *(outra)* | `JOB_DIR/spec.md` | `SPEC: READY` | nenhum |
| build | `tlc-spec-lean` (default) | `JOB_DIR/build.md` + commits | `BUILD: DONE` | `check_commit.py` é do builder; você confere commits + working tree limpo |
| build | `tlc-implement` | `.checks/<slug>.md` + `JOB_DIR/build.md` + commits | `BUILD: DONE` | nenhum (sem scripts — pule o gate) |
| build | *(outra)* | `JOB_DIR/build.md` + commits | `BUILD: DONE` | nenhum |

Caminho dos validadores: `python3 .kiro/skills/<SKILL_PLAN>/scripts/<nome>.py <slug> --root <FLOOR_PATH>` (só existem na `tlc-spec-lean`). **Verify é sempre uma verificação independente** (agente novo, nunca o builder), disparada pelo revisor de código (passo 3): na `tlc-spec-lean` é o Verifier dela + `validate_verification.py`; numa skill de build sem validador (ex.: `tlc-implement`) é o Verifier da própria skill sobre o artefato de checks dela, sem o script. A `tlc-spec-lean` fica sempre instalada por ser o default de plan/build e trazer os validadores.

## 0. Abrir o job

1. `maestri list` (sei quem sou e quem já existe) e `maestri preset list`: devem existir os 7 presets **Factory Spec Writer, Factory Builder, Factory Reviewer Security, Factory Reviewer API, Factory Reviewer Data, Factory Reviewer Code, Factory Approver**. Faltou algum ⇒ pare e peça ao usuário para rodar `.specs/factory/setup-maestri.sh` (ou criar os presets em Settings → Terminal → Quick Start).
2. Estou no **Ground**? (`maestri floor list` marca onde estou.) Se estou num floor, pare: `/factory` roda só no Ground.
3. Higiene do Ground: `git status --porcelain --untracked-files=no` deve estar **vazio**. O floor nasce do commit atual (mudança não commitada não vai junto). Sujo ⇒ `maestri floor status "Ground com mudanças não commitadas — commite ou guarde antes do /factory" --state blocked --floor "Ground"`, avise o usuário e **pare**.
4. **id** = (maior id em `.specs/factory/index.md` do Ground) + 1, 3 dígitos (`001` se o arquivo não existe). **slug** = kebab-case ≤ 40 chars da feature. Resolva agora **`branch_type`** e **`BRANCH`** (convenção *TIPO/BRANCH*) e o **`mr_target`** (convenção *MR_TARGET*, só informativo). Floor `"<id>-<slug>"`, branch = **`<BRANCH>`** (ex.: `feat/<slug>`, `release-v1.x.x.x`, `hotfix-v1.x.x.x`).
5. `maestri floor create "<id>-<slug>" --branch "<BRANCH>"` (**sem** `--copy-ground`: isso copiaria o canvas do Ground, inclusive este terminal, para dentro do floor). `maestri floor list` ⇒ FLOOR_PATH. `BASE = git -C <FLOOR_PATH> rev-parse HEAD`.
6. Confirme que `<FLOOR_PATH>/.kiro/agents/factory-builder.json` existe (`.kiro/` e `.specs/` são ignorados pelo git; o floor deve ter copiado). Se faltar: `cp -r .kiro <FLOOR_PATH>/.kiro` e `cp AGENTS.md <FLOOR_PATH>/AGENTS.md` se necessário.
7. `mkdir -p <FLOOR_PATH>/.specs/factory/jobs/<id>`; escreva `job.json` (stage `spec`, com `branch_type`/`mr_target`); acrescente ao `index.md` do Ground a linha `| <id> | <slug> | <floor> | spec | <data> |`; crie a Note do job no painel (seção *Painel*).

## 1. Spec

1. `maestri recruit "<codinome>" --preset "Factory Spec Writer" --floor "<floor>"`. Espere alguns segundos (o agente está subindo).
2. `maestri ask "<codinome>" "<cabeçalho SKILL=SKILL_PLAN> TASK: escreva a spec da feature abaixo com a skill de plan (SKILL_PLAN; default tlc-spec-lean ⇒ plan.md + checks.md) e o resumo JOB_DIR/spec.md. Se a feature chegou crua, formate-a antes com a skill de discover (SKILL_DISCOVER). FEATURE_TEXT: <$ARGUMENTS>"`.
3. Ao chegar a resposta, aplique o **contrato da fase plan** (tabela *Contratos de fase*) para SKILL_PLAN: **leia** `<FLOOR_PATH>/<JOB_DIR>/spec.md` e confira o token (`SPEC: READY` na 1ª linha). Se SKILL_PLAN tem validadores (só a `tlc-spec-lean`), rode-os você mesmo com `--root`: `python3 .kiro/skills/<SKILL_PLAN>/scripts/validate_plan.py <slug> --root <FLOOR_PATH>` e `validate_checks.py <slug> --root <FLOOR_PATH>` — **exit 0** ambos. (Se o spec-writer escolheu o atalho só-`checks.md`, `validate_plan` não se aplica: confira o motivo em `spec.md`.) Skill sem validador ⇒ confira só artefato + token.
   - `BLOCKED:`/exit ≠ 0 ⇒ **uma** nova tentativa (`maestri ask` com o erro). Persistindo ⇒ vá a **6b (escalar)**.
4. `maestri dismiss "<codinome>"`.
5. **Plan gate**: se `factory.plan_gate: human` ⇒ stage `plan-review`; `maestri floor status "plan pronto — revise o artefato de plan (.specs/features/<slug>/plan.md na tlc-spec-lean; .tasks/<slug>.md na tlc-plan) e rode /factory-continue <id>" --state review --floor "<floor>"`; `maestri notify "Job <id>: plan aguardando sua revisão"`; **PARE aqui**. (Retomado por `/factory-continue`.) Se `auto`, siga.

## 2. Build

1. stage `build`, status `2/5`. Leia o `## Handoff` da spec de checks (`checks.md` na `tlc-spec-lean`; `.checks/<slug>.md` na `tlc-implement`): `one builder` ⇒ um lote; `handoff` ⇒ lotes sequenciais **só quando o anterior fecha verde** (testes+build passam).
2. `maestri recruit "<codinome>" --preset "Factory Builder" --floor "<floor>"`; `maestri ask "<codinome>" "<cabeçalho SKILL=SKILL_BUILD> TASK: implemente [BATCH n de m | tudo] conforme a spec da fase de plan (BUILD da skill SKILL_BUILD; default tlc-spec-lean). Commits convencionais na branch do floor. Não dispare Verifier nem revisores. Nunca faça git push."`.
3. Ao terminar cada lote, aplique o **contrato da fase build** para SKILL_BUILD: `build.md` com 1ª linha `BUILD: DONE`; `git -C <FLOOR_PATH> log --oneline <BASE>..HEAD` tem commits; `git -C <FLOOR_PATH> status --porcelain --untracked-files=no` vazio (sujo ⇒ peça ao builder para commitar). `BUILD: BLOCKED` ⇒ **6b**.
4. **Não dispense o builder** (a sessão precisa sobreviver para o rework). stage → `review`, `round = 1`.

## 3. Review (paralelo) — rodada N

1. Recrute **4 revisores novos** no floor (independência: nunca reuse os da rodada anterior): presets Security, API, Data, Code. Opcional, pois o usuário pediu o visual: `maestri band create "Reviewers <id>" "<a>" "<b>" "<c>" "<d>" --without-me`.
2. `mkdir -p <FLOOR_PATH>/<JOB_DIR>/round-<N>`.
3. Dispare os 4 **de uma vez**, que já é o "espera todos" nativo:
   `maestri ask --batch '{"<a>": "<cabeçalho ROUND=N> TASK: revise pelo ângulo security → JOB_DIR/round-N/review-security.md", "<b>": "… api → review-api.md", "<c>": "… data → review-data.md", "<d>": "<cabeçalho SKILL=SKILL_BUILD> … code (Verifier da skill de build SKILL_BUILD + code review) → review-code.md e o relatório de verificação (`.specs/features/<slug>/verification.md` na tlc-spec-lean; o relatório que a skill de build define, nas demais)"}'`
   Timeout do shell grande (revisão leva minutos). Se estourar, **não reenvie**: `ls <FLOOR_PATH>/<JOB_DIR>/round-N/` a cada ~30–60 s e `maestri check` em quem demorar.
4. **A rodada só termina quando os 4 arquivos existem** e a 1ª linha de cada é `VERDICT: PASS` ou `VERDICT: CHANGES`. Arquivo ausente/1ª linha inválida ⇒ peça **uma** correção àquele revisor; persistindo, trate como escalada (**6b**). Registre os 4 veredictos em `job.json.reviews`.
5. Dispense os 4 revisores (a Band se desfaz).

## 4. Decisão da rodada

- **Algum `CHANGES`** e `reworks < factory.max_reworks` ⇒ `reworks += 1`, `round += 1`; junte os `must-fix` das reviews com CHANGES; `maestri ask "<builder>" "<cabeçalho ROUND=N> TASK: rework. Trate todos os must-fix de: <caminhos round-(N-1)/review-*.md com CHANGES>. Recommite, lint/test/build verdes, acrescente '## Round N' a build.md terminando com BUILD: DONE."` Confirme como em 2.3. Volte ao passo **3** (revisores novos).
- **Algum `CHANGES`** e orçamento esgotado ⇒ **6b** (motivo: "rework esgotado").
- **Os 4 `PASS`** ⇒ passo 5.

## 5. Approver

stage `approve`, status `4/5`. Recrute **Factory Approver**; `maestri ask "<codinome>" "<cabeçalho SKILL=SKILL_BUILD> TASK: decida APPROVE ou ESCALATE → JOB_DIR/decision.md"`. Leia `decision.md`: 1ª linha `APPROVE` ou `ESCALATE`. Dispense o approver.

## 6a. APPROVE → trabalho pronto na branch local (push + MR você faz manualmente)

A fábrica **não** faz `git push`, **não** abre MR e **não** faz merge/land em nenhuma branch. Os commits ficam na branch local do floor (`<BRANCH>`). O `mr_target` fica registrado só como lembrete do destino quando VOCÊ for abrir o MR à mão (`feat` → release atual; `release`/`hotfix` → `main`).

1. **Arquive** o job (sobrevive mesmo se o floor sair depois): `mkdir -p .specs/factory/archive/<id>` e `cp -r <FLOOR_PATH>/.specs/factory/jobs/<id>/. .specs/factory/archive/<id>/` e `cp -r <FLOOR_PATH>/.specs/features/<slug> .specs/factory/archive/<id>/feature` (se existir).
2. Confirme o floor limpo (`git -C <FLOOR_PATH> status --porcelain --untracked-files=no` vazio; sujo ⇒ peça ao builder para commitar). Dispense o builder e qualquer agente remanescente do job.
3. stage `approved`; `index.md` atualizado; Note do job → raia `Factory · Precisa de você`.
4. **Deixe o floor de pé** (o trabalho vive na branch `<BRANCH>`): `maestri floor status "APPROVE — pronto: faça push de <BRANCH> e abra o MR → <mr_target> manualmente" --state review --floor "<floor>"` + `maestri notify "Job <id> aprovado: push + MR manuais (branch <BRANCH> → <mr_target>)"`. **Fim.**

> A fábrica **nunca toca o `origin`**. Push para o `origin` e criação do MR são **manuais, seus**, até segunda ordem. Quando o MR for mergeado, feche o job com `/factory-approve <id>` (que só arquiva/marca e, com sua confirmação, remove o floor) ou remova o floor manualmente.

## 6b. ESCALATE / falha (needs-human)

1. **Nada de merge, push ou MR.** Escreva `<FLOOR_PATH>/<JOB_DIR>/escalation.md`: quem escalou, motivo (cite `decision.md`/review/BLOCKED), o que olhar primeiro. Arquive como em 6a.1. Deixe o floor de pé; **dispense os agentes** que ainda estiverem rodando, exceto o builder (para `/factory-rework`).
2. stage `needs-human`; `maestri floor status "needs human: <motivo curto>" --state review --floor "<floor>"`; `maestri notify "Job <id> precisa de você: <motivo>"`; `index.md` atualizado.
3. Diga ao usuário: ver `escalation.md` e então `/factory-approve <id>` (aceitar como está) ou `/factory-rework <id> "<nota>"`.

## Painel (kanban de Fichários)

Cada job tem **uma Note** `Job <id> · <slug>` (5-8 linhas: feature, stage, round/reworks, vereditos, floor/branch, mr_target, próximo comando) guardada numa de três **raias** (Fichários nomeados; um Fichário nomeado continua no canvas mesmo vazio):

| Raia (Fichário) | Quando o job está em |
| --- | --- |
| `Factory · Em andamento` | `spec`, `build`, `review`, `approve` |
| `Factory · Precisa de você` | `plan-review`, `needs-human`, `approved` (pronto — faça push + MR manualmente) |
| `Factory · Concluídos` | `merged` |

- Criar: `maestri note create "<resumo>" --name "Job <id> · <slug>" --stack "Factory · Em andamento"`.
- Mudar de raia: `maestri note stack "Job <id> · <slug>" "<raia>"`. Atualizar o texto: `maestri note edit`/`write` (a **primeira linha** da Note não muda o nome porque ele foi fixado com `--name`).
- Se `maestri note` falhar (Note não conectada, raia inexistente), **não trave o job**: o `job.json` e o `index.md` são a verdade; registre o erro em `job.json.notes_error` e siga.

## Fim de job

Sempre deixe `job.json`, `index.md`, a Note do job (raia correta) e o status do floor coerentes. Resuma ao usuário em ≤ 5 linhas: id, stage final, floor/branch, `mr_target` (lembrete do destino do MR manual), onde ler (`decision.md`/`escalation.md`), próximo comando.
