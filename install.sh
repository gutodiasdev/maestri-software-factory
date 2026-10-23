#!/usr/bin/env bash
#
# install.sh — instala a Software Factory como skills + agentes para Kiro CLI OU Claude Code.
#
# Uso:
#   ./install.sh --target kiro    [--global] [--dest <dir>] [--dry-run]
#   ./install.sh --target claude  [--global] [--dest <dir>] [--dry-run]
#
#   --target kiro|claude   obrigatório. Qual CLI.
#   --global               instala em ~/.kiro ou ~/.claude (vale para todos os projetos).
#                          Sem --global, instala no projeto (.kiro/ ou .claude/ em --dest).
#   --dest <dir>           raiz do projeto alvo (padrão: diretório atual). Ignorado com --global.
#   --dry-run              só mostra o que faria.
#
# O que copia:
#   skills/*            -> <base>/skills/            (factory*, tlc-discover, tlc-spec-lean, tlc-plan, tlc-implement)
#   agents/<cli>/*      -> <base>/agents/            (.json+prompts p/ kiro; .md p/ claude)
# Para o alvo claude, reescreve caminhos .kiro/ -> .claude/ nos arquivos de skill copiados.
set -euo pipefail

TARGET=""; GLOBAL=0; DEST="$(pwd)"; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2;;
    --global) GLOBAL=1; shift;;
    --dest)   DEST="${2:-}"; shift 2;;
    --dry-run) DRY=1; shift;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    *) echo "argumento desconhecido: $1" >&2; exit 2;;
  esac
done
[ "$TARGET" = kiro ] || [ "$TARGET" = claude ] || { echo "use --target kiro|claude" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
DOT=".${TARGET}"                      # .kiro ou .claude
if [ "$GLOBAL" = 1 ]; then BASE="$HOME/$DOT"; else BASE="$DEST/$DOT"; fi
SKILLS="$BASE/skills"; AGENTS="$BASE/agents"

run() { if [ "$DRY" = 1 ]; then echo "DRY  $*"; else eval "$*"; fi; }

echo "Instalando Software Factory para '$TARGET' em: $BASE"
run "mkdir -p '$SKILLS' '$AGENTS'"

# --- skills ---
run "cp -r '$HERE/skills/.' '$SKILLS/'"
if [ "$TARGET" = claude ]; then
  # a fonte usa caminhos .kiro/ ; adapta os arquivos de skill copiados para .claude/
  if [ "$DRY" = 1 ]; then
    echo "DRY  sed -i 's#\\.kiro/#.claude/#g' nos SKILL.md de $SKILLS"
  else
    grep -rlZ '\.kiro/' "$SKILLS" 2>/dev/null | xargs -0 -r sed -i 's#\.kiro/#.claude/#g' || true
  fi
fi

# --- agentes ---
if [ "$TARGET" = kiro ]; then
  run "mkdir -p '$AGENTS/prompts'"
  run "cp '$HERE/agents/kiro/'*.json '$AGENTS/'"
  run "cp '$HERE/agents/kiro/prompts/'*.md '$AGENTS/prompts/'"
else
  run "cp '$HERE/agents/claude/'*.md '$AGENTS/'"
fi

echo
echo "OK. Próximos passos:"
echo "  1) Copie AGENTS.sample.md (kiro) ou CLAUDE.sample.md (claude) para a raiz do projeto e preencha o bloco factory.*"
echo "  2) No Maestri, rode scripts/setup-maestri-${TARGET}.sh dentro de um terminal do app para criar os presets."
echo "  3) Abra o preset 'Factory Maestro' no Ground e rode /factory <feature> (ou use scripts/intake.sh p/ GitLab)."
