#!/usr/bin/env bash
# Cria no Maestri os presets da Software Factory lançando o CLAUDE CODE com o papel certo.
# Rode DENTRO de um terminal do Maestri (precisa de conexão com o app), de preferência o do Maestro.
# Idempotente: se o preset já existe, só atualiza o comando. Não apaga nada.
#
# Como o Claude Code recebe o papel: cada preset chama o wrapper .claude/agents/_run.sh <papel>,
# que injeta o corpo de .claude/agents/<papel>.md como system prompt (frontmatter removido).
# A flag usada é `--append-system-prompt`; AJUSTE se a sua versão do Claude Code usar outra.
set -u
M="${MAESTRI_CLI:-maestri}"
command -v "$M" >/dev/null 2>&1 || { echo "maestri CLI não encontrada: rode isto num terminal do Maestri." >&2; exit 1; }
"$M" debug >/dev/null 2>&1 || { echo "Sem conexão com o Maestri (rode 'maestri debug')." >&2; exit 1; }

# diretório dos agentes Claude (workspace por padrão; ajuste para ~/.claude/agents se instalou global)
AGENTS_DIR="${CLAUDE_AGENTS_DIR:-.claude/agents}"
[ -d "$AGENTS_DIR" ] || { echo "Não achei $AGENTS_DIR. Rode o install.sh --target claude primeiro." >&2; exit 1; }

# wrapper que inicia o Claude Code com o prompt do papel
RUN="$AGENTS_DIR/_run.sh"
cat > "$RUN" <<'RUNSH'
#!/usr/bin/env bash
# uso: _run.sh <nome-do-agente>  — inicia o Claude Code com o prompt daquele papel.
set -u
agent="${1:?uso: _run.sh <agente>}"
dir="$(cd "$(dirname "$0")" && pwd)"
file="$dir/$agent.md"
[ -f "$file" ] || { echo "papel não encontrado: $file" >&2; exit 1; }
# remove o frontmatter YAML (tudo até o segundo '---') e usa o resto como system prompt
prompt="$(awk 'p;/^---$/{n++; if(n==2) p=1}' "$file")"
# AJUSTE a flag conforme a sua versão do Claude Code (ex.: --system-prompt / --append-system-prompt):
exec claude --append-system-prompt "$prompt"
RUNSH
chmod +x "$RUN"

existing="$("$M" preset list 2>&1)"

# nome do preset | papel (arquivo .claude/agents/<papel>.md) | Maestro Mode
ROWS=(
  "Factory Maestro|factory-maestro|on"
  "Factory Spec Writer|factory-spec-writer|off"
  "Factory Builder|factory-builder|off"
  "Factory Reviewer Security|factory-reviewer-security|off"
  "Factory Reviewer API|factory-reviewer-api|off"
  "Factory Reviewer Data|factory-reviewer-data|off"
  "Factory Reviewer Code|factory-reviewer-code|off"
  "Factory Approver|factory-approver|off"
)

for row in "${ROWS[@]}"; do
  IFS='|' read -r name agent maestro <<<"$row"
  cmd="bash $RUN $agent"
  qs=off; [ "$maestro" = on ] && qs=on
  if grep -Fq "$name" <<<"$existing"; then
    echo "• atualizando: $name"
    "$M" preset set "$name" --command "$cmd" --maestro "$maestro" --quick-start "$qs" || echo "  ! falhou: $name"
  else
    echo "• criando:     $name"
    "$M" preset create "$name" --command "$cmd" --maestro "$maestro" --quick-start "$qs" || echo "  ! falhou: $name"
  fi
done

echo
"$M" preset list
echo
echo "Pronto. Abra um terminal com o preset 'Factory Maestro' no Ground do workspace e rode /factory <feature>."
echo "Obs.: confira a flag de system prompt em $RUN conforme a sua versão do Claude Code."
