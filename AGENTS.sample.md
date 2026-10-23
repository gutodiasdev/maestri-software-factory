# AGENTS.md — <seu-projeto>

> Copie este arquivo para a raiz do seu projeto (como `AGENTS.md` para Kiro CLI, ou
> `CLAUDE.md` para Claude Code) e preencha. É a **única** fonte de conhecimento
> específico do repositório para a Software Factory: se algo aqui estiver errado, o
> agente erra junto. Mantenha curto e verdadeiro.

## Setup de um checkout novo

```bash
# ex.: npm install   |   pnpm i   |   poetry install
<comando de instalação de dependências>
```

- Versão de runtime exigida (Node/Python/…): <...>
- **Nunca** leia, imprima, copie ou commite `.env*`. O `.env.example` mostra as variáveis.

## Comandos

| Objetivo | Comando |
| --- | --- |
| Testes unitários | `<...>` |
| Um arquivo de teste | `<...>` |
| Testes e2e | `<...>` (precisa de infra; **não** rode na fábrica sem pedir) |
| Cobertura | `<...>` |
| Build / typecheck | `<...>` |
| Lint | `<...>` (se tiver `--fix`, rode antes de commitar e commite o resultado) |
| Dev server | `PORT=<porta> <...>` |

## Convenções do stack

- Framework, estrutura de pastas, validação de entrada, autenticação/autorização.
- Padrão de testes (onde ficam, como mockar dados; teste nasce do comportamento, não da implementação).
- Padrão de commits (ex.: Conventional Commits) e de nomes de branch.
- Mudanças de **mão única** (migração de schema, índice, chave de join, deploy): a fábrica
  **escala para humano** (ESCALATE), nunca faz sozinha.

## Software Factory (Maestri + Kiro/Claude)

Fluxo: `feature → spec-writer → builder → [security, api, data, code] → ESPERA OS 4 → approver`.
A fábrica trabalha **só localmente**: nunca faz `git push`, abre MR ou faz merge/land.
O trabalho fica commitado na branch local do Floor; **push e MR são manuais seus**.

```
factory.plan_gate: human        # human = para após o plan.md p/ você revisar; auto = segue sozinho
factory.auto_land: false         # mantenha false (a fábrica não faz merge/land)
factory.max_reworks: 2           # CHANGES devolve ao MESMO builder, no máx. 2 vezes (3 rounds)
factory.base_branch: current     # current = branch que o Ground tem checada; ou um nome fixo
factory.dev_port_base: 8100      # porta do floor = base + número do job
factory.release_branch: release-v1.0.0.0   # alvo (informativo) dos MRs de feat; ajuste à sua release
```

### Skills por fase (configurável)

Cada fase roda uma **skill**. O padrão usa as skills do Tech Leads Club que já vêm empacotadas;
você pode trocar a skill de qualquer fase pela que preferir, sem abrir mão das que já usa.

```
factory.phases.discover.skill: tlc-discover   # feature crua → documento de design
factory.phases.plan.skill:     tlc-spec-lean   # PLAN + CHECKS → plan.md + checks.md
factory.phases.build.skill:    tlc-spec-lean   # BUILD → build.md (VERIFY = verificação independente, ver abaixo)
```

- **Default (recomendado):** `tlc-spec-lean` em plan e build. Ela traz validadores Python que a
  fábrica roda como **gates duros** (`validate_plan.py`, `validate_checks.py`, `check_commit.py`,
  `validate_verification.py`) e o Verifier independente — é o que sustenta "arquivos são a verdade".
- **Override decomposto:** troque **plan e build juntos** para `tlc-plan` + `tlc-implement` (o par
  do catálogo TLC, também empacotado). Elas produzem outro contrato de artefatos (`.tasks/`,
  `.checks/`) e **não** trazem validadores: a fábrica confere só o artefato + token da fase e
  **pula os gates de script**. Nunca troque só uma das duas — os artefatos de plan e build precisam
  casar.
- **Qualquer skill:** aponte a fase para o nome de uma skill instalada em `.kiro/skills/` (Kiro) ou
  `.claude/skills/` (Claude). A fábrica injeta `SKILL=<nome>` na tarefa do agente, que lê o
  `SKILL.md` dela e segue o contrato daquela fase.
- **Verify** é sempre uma verificação independente (agente novo, nunca o builder), feita pelo revisor
  de código: na `tlc-spec-lean`, o Verifier dela + `validate_verification.py`; numa skill de build sem
  validador (ex.: `tlc-implement`), o Verifier da própria skill. Omitir uma linha `factory.phases.*`
  usa o default acima.

Tipos de branch (vindos do intake ou perguntados): `feat/<descrição>`, `release-v1.x.x.x`,
`hotfix-v1.x.x.x`. Alvo do MR (que **você** abre manualmente): `feat → release`,
`release → main`, `hotfix → main`.

Escalar para humano (ESCALATE) sempre que o diff: criar/alterar migração/schema/índice;
mexer em CI/Docker/variáveis de ambiente/deploy; alterar guards/autorização/validação global;
adicionar/atualizar dependência; tocar segredo/`.env*`; ou quando um revisor deixou dúvida
que só um humano resolve.

Estado de runtime da fábrica fica em `.specs/factory/` (ignorado pelo git).
