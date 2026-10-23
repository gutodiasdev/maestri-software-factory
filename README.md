# Maestri Software Factory

Uma **fábrica de software visual**: você digita `/factory <feature>` e um time de agentes
escreve a spec, implementa numa branch própria, revisa de 4 ângulos em paralelo e aprova — tudo
orquestrado no canvas do **[Maestri](https://www.themaestri.app)**, rodando com **Kiro CLI** ou
**Claude Code**.

```
feature → spec-writer → [plan gate] → builder → [security, api, data, code] → ESPERA OS 4
                           ▲                                                    │
                           └──── algum CHANGES: retoma o MESMO builder ◄────────┤
                                                                                ▼ todos PASS
              pronto na branch local ◄── APPROVE ── approver ── ESCALATE → needs-human
```

Cada job roda num **Floor** do Maestri (um `git worktree` com branch própria, copy-on-write),
então vários jobs rodam em paralelo sem colidir. A fábrica trabalha **só localmente**: ela
**nunca** faz `git push`, **nunca** abre Merge Request e **nunca** faz merge/land. O trabalho
fica commitado na branch local; **push para o `origin` e criação do MR são manuais, seus**.

Cada fase da fábrica roda uma **skill**, e você escolhe qual. Por padrão usa as do **Tech Leads
Club** que já vêm no pacote: `tlc-discover` (descoberta de features cruas) e `tlc-spec-lean`
(PLAN → CHECKS → BUILD → VERIFY, default de plan e build). Como alternativa plugável vem também o
par `tlc-plan` + `tlc-implement`. Troque a skill de qualquer fase no bloco `factory.phases.*` do
`AGENTS.md`/`CLAUDE.md` — veja [Skills incluídas](#skills-incluídas).

---

## Índice

- [Como funciona](#como-funciona)
- [O que vem no pacote](#o-que-vem-no-pacote)
- [Pré-requisitos](#pré-requisitos)
- [Instalação rápida (npx)](#instalação-rápida-npx)
- [Instalação (Kiro CLI)](#instalação-kiro-cli)
- [Instalação (Claude Code)](#instalação-claude-code)
- [Configuração do projeto](#configuração-do-projeto-agentsmd--claudemd)
- [Setup no Maestri](#setup-no-maestri)
- [Usando a fábrica](#usando-a-fábrica)
- [Fluxo GitLab (intake)](#fluxo-gitlab-intake-de-issues)
- [Skills incluídas](#skills-incluídas)
- [Regras de ouro](#regras-de-ouro)
- [Atribuição e licença](#atribuição-e-licença)

---

## Como funciona

O **Maestri** é a camada de canvas/orquestração em volta dos seus agentes de terminal — ele não é
um agente. Quem executa o laço é um **terminal com Maestro Mode ligado** (o *Maestro*), rodando a
skill `/factory`. O Maestro:

1. cria um **Floor** por job (branch `feat/…`, `release-v…` ou `hotfix-v…`);
2. **recruta** os agentes na hora certa (spec-writer → builder → 4 revisores → approver), cada um
   conectado às **Notes** que são a fonte de verdade (`spec`, `build`, `review-*`, `decision`);
3. **espera os 4 revisores** (o round só fecha quando os 4 arquivos `VERDICT:` existem);
4. em `CHANGES`, **retoma o mesmo builder** (no máx. 2 vezes); em `PASS`, chama o approver;
5. em `APPROVE`, deixa o trabalho pronto na branch local e te avisa para fazer **push + MR
   manualmente**; em `ESCALATE`, marca `needs-human` e notifica.

Os agentes nunca carregam nada específico do repositório: leem tudo do `AGENTS.md`/`CLAUDE.md`
do projeto. Trocar o stack = trocar esse arquivo, não os agentes.

## O que vem no pacote

```
maestri-software-factory/
├── install.sh                     # instalador dual-CLI (--target kiro|claude)
├── AGENTS.sample.md               # template de config (Kiro) — contém o bloco factory.*
├── CLAUDE.sample.md               # idem para Claude Code
├── skills/                        # fonte canônica das skills (SKILL.md), igual p/ as duas CLIs
│   ├── factory/  factory-next/  factory-continue/
│   ├── factory-approve/  factory-rework/  factory-status/
│   ├── tlc-spec-lean/  tlc-discover/      # (Tech Leads Club, CC-BY-4.0) — defaults das fases
│   └── tlc-plan/  tlc-implement/          # (Tech Leads Club, CC-BY-4.0) — override plugável de plan+build
├── agents/
│   ├── kiro/                      # agentes Kiro: factory-*.json + prompts/*.md
│   └── claude/                    # agentes Claude: factory-*.md (subagent format)
└── scripts/
    ├── intake.sh                  # seleção interativa de issues do GitLab (glab + fzf/gum)
    ├── setup-maestri-kiro.sh      # cria os presets no Maestri (lançam kiro-cli --agent)
    └── setup-maestri-claude.sh    # cria os presets no Maestri (lançam claude com o papel)
```

## Pré-requisitos

- **Maestri** instalado (macOS/Windows; há build Linux — confirme suporte a Maestro Mode e Floors).
- **Kiro CLI** *e/ou* **Claude Code** instalados (o Maestri lança o CLI que você escolher).
- **git** (Floors precisam de repositório git).
- Opcional: **glab** (GitLab) ou **gh** (GitHub) logados — só para o seu push/MR manual e para o
  intake de issues; a fábrica em si nunca os chama.
- Para o intake: **jq** e **fzf** (ou **gum**).

## Instalação rápida (npx)

Sem clonar nada, direto do GitHub (requer Node ≥ 16):

```bash
# Kiro CLI (no projeto atual):
npx -y "github:gutodiasdev/maestri-software-factory#v0.1.3" -- --target kiro
# Claude Code:
npx -y "github:gutodiasdev/maestri-software-factory#v0.1.3" -- --target claude
# opções: --global (instala em ~/.kiro|~/.claude) · --dest <dir> · --dry-run (prévia)
```

Isso copia as skills para `.kiro/skills/` (ou `.claude/skills/`) e os agentes para `.kiro/agents/`
(ou `.claude/agents/`). Sem a tag `#v0.1.3`, usa a última versão da branch `main`. As seções
abaixo mostram a instalação manual equivalente.

### Atualizar e remover

A instalação registra um manifesto em `.kiro/.factory-manifest.json` (ou `.claude/…`) com a versão
e a lista de arquivos. Com ele, atualizar e remover são limpos — **sem** tocar no seu
`AGENTS.md`/`CLAUDE.md` nem em outras skills/agentes seus:

```bash
# atualizar (troque a tag pela versão nova; remove arquivos que saíram da versão anterior):
npx -y "github:gutodiasdev/maestri-software-factory#v0.1.3" -- update --target kiro
# remover só o que a fábrica instalou:
npx -y "github:gutodiasdev/maestri-software-factory#v0.1.3" -- uninstall --target kiro
# ver a versão do pacote:
npx -y "github:gutodiasdev/maestri-software-factory" -- --version
```

`install` (padrão) sobrescreve os arquivos gerenciados; `update` faz o mesmo **e** apaga órfãos de
versões anteriores; `uninstall` remove apenas o que a fábrica instalou. Todos aceitam `--global` e
`--dest <dir>`.

## Instalação (Kiro CLI)

No projeto onde a fábrica vai rodar:

```bash
# a partir da raiz deste repositório:
./install.sh --target kiro --dest /caminho/do/seu/projeto
# ou global (todos os projetos):
./install.sh --target kiro --global
```

Isso copia:

- `skills/*` → `.kiro/skills/` (ou `~/.kiro/skills/`)
- `agents/kiro/*.json` + `prompts/*.md` → `.kiro/agents/`

As skills aparecem como slash commands (`/factory`, `/factory-next`, …). Os agentes ficam
disponíveis para `kiro-cli chat --agent factory-*`.

Instalação manual equivalente:

```bash
mkdir -p .kiro/skills .kiro/agents/prompts
cp -r skills/.               .kiro/skills/
cp agents/kiro/*.json        .kiro/agents/
cp agents/kiro/prompts/*.md  .kiro/agents/prompts/
```

## Instalação (Claude Code)

```bash
./install.sh --target claude --dest /caminho/do/seu/projeto
# ou:  ./install.sh --target claude --global
```

Isso copia:

- `skills/*` → `.claude/skills/` (com os caminhos `.kiro/` reescritos para `.claude/`)
- `agents/claude/*.md` → `.claude/agents/` (formato de subagente do Claude Code)

> **Nota sobre launch do Claude Code:** o `setup-maestri-claude.sh` cria um wrapper
> `.claude/agents/_run.sh` que injeta o corpo de cada `.claude/agents/<papel>.md` como system
> prompt via `claude --append-system-prompt`. Ajuste essa flag se a sua versão do Claude Code
> usar outra (ex.: `--system-prompt`).

## Configuração do projeto (AGENTS.md / CLAUDE.md)

Copie o template para a raiz do projeto e preencha:

```bash
cp AGENTS.sample.md  /caminho/do/projeto/AGENTS.md     # Kiro
cp CLAUDE.sample.md  /caminho/do/projeto/CLAUDE.md     # Claude Code
```

Preencha **como montar um checkout novo, como subir o dev server numa porta, e como rodar
testes/build/lint** — os agentes leem tudo dali. Ajuste o bloco `factory.*` (plan gate, reworks,
branch base, `release_branch` alvo dos MRs de feat) e, se quiser, o bloco `factory.phases.*` para
escolher a skill de cada fase (default: `tlc-discover` na descoberta, `tlc-spec-lean` em plan e
build; alternativa `tlc-plan` + `tlc-implement`).

## Setup no Maestri

1. Crie um **Workspace** apontando para o projeto. Ative a sincronização `AGENTS.md`↔`CLAUDE.md`
   se usar as duas CLIs.
2. Dentro de um terminal do Maestri, crie os presets dos papéis:
   ```bash
   bash scripts/setup-maestri-kiro.sh      # para Kiro CLI
   # ou
   bash scripts/setup-maestri-claude.sh    # para Claude Code
   ```
   Isso cria os presets **Factory Maestro, Spec Writer, Builder, Reviewer Security/API/Data/Code,
   Approver**. Só o Maestro vai para o Quick Start; os demais o Maestro recruta sozinho.
3. No **Ground** do workspace, abra um terminal com o preset **Factory Maestro** (já nasce com
   **Maestro Mode** ligado). Configure **Floor Hooks** (Setup: instalar deps; Run: subir dev server
   numa porta própria).

Detalhes de canvas, Notes, conexões, Floors e comandos `maestri …`: veja a documentação oficial do
Maestri em <https://www.themaestri.app/docs> e os prompts dos papéis em `agents/`.

## Usando a fábrica

No terminal **Factory Maestro** (Ground):

```
/factory adicionar campo de tempo de leitura estimado nos posts
```

Acompanhe no canvas: o Maestro cria o Floor, recruta spec-writer → builder → 4 revisores (numa
Band) → approver. Comandos auxiliares:

```
/factory-status [id]          # estado dos jobs (somente leitura)
/factory-continue <id>        # libera o plan gate após você revisar o plan.md
/factory-next                 # pega o 1º item não marcado do backlog
/factory-approve <id>         # finaliza um job aprovado/escalado (arquiva; sem push/MR/land)
/factory-rework <id> "<nota>" # devolve ao builder com feedback
```

No fim de um APPROVE, o trabalho está commitado na branch local do Floor. **Você** faz o push e o
MR manualmente — a fábrica te lembra do destino certo (feat → release, release/hotfix → main):

```bash
git push -u origin <branch-do-floor>
# depois abra o MR no GitLab/GitHub com destino <release|main>
```

## Fluxo GitLab (intake de issues)

Para começar a partir das suas issues atribuídas no GitLab:

```bash
bash scripts/intake.sh
```

Ele lista as issues abertas atribuídas a você (`glab`), deixa você escolher várias (`fzf`/`gum`),
pergunta o **tipo de branch** por issue (feat/release/hotfix) e grava `.specs/factory/selected.tsv`.
Depois, no Maestro, `/factory-next` cria um Floor por issue selecionada com a branch certa.
(O agente `factory-issue-fetcher` faz a versão "somente leitura" que escreve o backlog.)

## Skills incluídas

| Skill | O que faz |
| --- | --- |
| `factory` | orquestrador: roda o laço spec→build→review→approve, 1 Floor por job |
| `factory-next` | pega o 1º item não marcado do backlog e roda `/factory` nele |
| `factory-continue` | libera o plan gate e retoma na fase de build |
| `factory-approve` | finaliza job aprovado/escalado (arquiva e marca; **sem** push/MR/land) |
| `factory-rework` | devolve ao builder com feedback e reexecuta build/review/approve |
| `factory-status` | mostra o estado dos jobs (somente leitura) |
| `tlc-spec-lean` | spec dirigida por obrigações: PLAN → CHECKS → BUILD → VERIFY (TLC) — **default** de plan e build |
| `tlc-discover` | transforma uma ideia crua em documento de design (TLC) — **default** da descoberta |
| `tlc-plan` | corta trabalho decidido em tarefas com critérios observáveis (TLC) — alternativa de plan |
| `tlc-implement` | extrai checklist, constrói e prova com verifier independente (TLC) — alternativa de build |

As quatro últimas são do **Tech Leads Club** e vêm instaladas. A skill de cada fase é configurável
em `factory.phases.*` (veja [Configuração do projeto](#configuração-do-projeto-agentsmd--claudemd)):
o default é `tlc-discover` + `tlc-spec-lean`; para o caminho decomposto, troque **plan e build
juntos** para `tlc-plan` + `tlc-implement`. Em skills sem validador (tlc-plan/tlc-implement) a
fábrica confere artefato + token e pula os gates de script; o **verify** continua sendo uma
verificação independente — o Verifier da própria skill de build (o da `tlc-spec-lean` no default).

## Regras de ouro

- **Arquivos são a fonte de verdade**, não a conversa. Cada papel escreve só o seu arquivo; só o
  Maestro escreve `job.json`.
- **Local-only:** a fábrica nunca faz `git push`, MR ou merge/land. `git push`, `reset --hard`,
  `clean`, `rm -rf` estão em `deny` em todos os papéis.
- **Verifier independente:** quem revisa/verifica nunca é quem construiu.
- **Escalar em vez de adivinhar** em portas de mão única (migração, schema, deploy, autorização).
- **Nunca** ler/imprimir/commitar `.env*`.

## Atribuição e licença

- Código próprio da fábrica: **MIT** (veja [`LICENSE`](LICENSE)).
- `skills/tlc-spec-lean/`, `skills/tlc-discover/`, `skills/tlc-plan/` e `skills/tlc-implement/`:
  **© Tech Leads Club**, licenciadas **CC-BY-4.0** (https://github.com/tech-leads-club). Incluídas
  aqui sem alterações (exceto reescrita de caminhos na instalação), com a licença e autoria
  preservadas no frontmatter de cada `SKILL.md`.
