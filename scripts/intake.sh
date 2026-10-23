#!/usr/bin/env bash
#
# .specs/factory/intake.sh — seleção interativa de issues + tipo de branch.
#
# Fluxo:
#   1. Lê as issues abertas atribuídas a você no GitLab (glab).
#   2. Multi-seleção com fzf (TAB marca várias, ENTER confirma).
#   3. Para cada issue escolhida, pergunta o tipo de branch e monta o nome:
#        feat    -> feat/<descricao-kebab>
#        release -> release-v<versao>      (ex.: release-v1.2.0.0)
#        hotfix  -> hotfix-v<versao>       (ex.: hotfix-v1.2.0.1)
#   4. Grava .specs/factory/selected.tsv com:  IID \t TITLE \t TYPE \t BRANCH
#
# O Maestro (skill /factory) lê esse arquivo para criar 1 floor por issue,
# com a branch correta, e resolver o alvo do MR por tipo (feat->release,
# release->main, hotfix->main). Este script NÃO cria branch, NÃO faz push e
# NÃO abre MR: ele só captura a sua escolha.
#
# Dependências: glab (autenticado), jq, e fzf OU gum.
# Rode no Ground, a partir da raiz do repositório:  bash .specs/factory/intake.sh
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_DIR="$ROOT/.specs/factory"
SELECTED="$OUT_DIR/selected.tsv"
mkdir -p "$OUT_DIR"

die() { printf 'intake: %s\n' "$*" >&2; exit 1; }

# --- 0. dependências -------------------------------------------------------
command -v glab >/dev/null || die "glab não encontrado no PATH."
command -v jq   >/dev/null || die "jq não encontrado no PATH."
if command -v fzf >/dev/null; then
  PICKER=fzf
elif command -v gum >/dev/null; then
  PICKER=gum
else
  die "instale fzf OU gum para a seleção interativa."
fi
glab auth status >/dev/null 2>&1 || die "glab não autenticado — rode 'glab auth login'."

# --- 1. buscar issues abertas atribuídas a você ----------------------------
# API REST estável; cada linha vira "IID<TAB>TÍTULO". Ajuste a query se precisar.
mapfile -t ISSUES < <(
  glab api "issues?scope=assigned_to_me&state=opened&per_page=100" \
    | jq -r '.[] | [ (.iid|tostring), (.title|gsub("[\t\n]";" ")) ] | @tsv'
)
[ "${#ISSUES[@]}" -gt 0 ] || die "nenhuma issue aberta atribuída a você."

# --- 2. multi-seleção ------------------------------------------------------
choose_multi() {
  if [ "$PICKER" = fzf ]; then
    printf '%s\n' "${ISSUES[@]}" \
      | fzf --multi --delimiter='\t' --with-nth=1,2 \
            --prompt='Issues (TAB marca, ENTER confirma)> '
  else
    printf '%s\n' "${ISSUES[@]}" \
      | gum choose --no-limit --header='Escolha as issues'
  fi
}

choose_one() { # $1 = header; stdin = opções (uma por linha)
  if [ "$PICKER" = fzf ]; then
    fzf --prompt="$1> "
  else
    gum choose --header="$1"
  fi
}

CHOSEN="$(choose_multi)"
[ -n "${CHOSEN:-}" ] || die "nada selecionado."

# --- 3. tipo de branch por issue + nome da branch --------------------------
: > "$SELECTED"
while IFS=$'\t' read -r IID TITLE _rest; do
  [ -n "${IID:-}" ] || continue
  TYPE="$(printf 'feat\nrelease\nhotfix\n' | choose_one "Tipo de branch p/ #$IID — $TITLE")"
  case "$TYPE" in
    feat)
      read -r -p "feat: descrição curta (kebab-case) p/ #$IID: " DESC
      DESC="$(printf '%s' "$DESC" | tr '[:upper:] ' '[:lower:]-' | tr -cs 'a-z0-9-' '-' | sed 's/^-//;s/-$//')"
      [ -n "$DESC" ] || die "descrição vazia para feat."
      BRANCH="feat/${DESC}"
      ;;
    release)
      read -r -p "release versão (formato v1.x.x.x) p/ #$IID: " V
      [[ "$V" =~ ^v[0-9]+(\.[0-9]+){3}$ ]] || die "versão de release inválida: '$V' (esperado v1.x.x.x)."
      BRANCH="release-${V}"
      ;;
    hotfix)
      read -r -p "hotfix versão (formato v1.x.x.x) p/ #$IID: " V
      [[ "$V" =~ ^v[0-9]+(\.[0-9]+){3}$ ]] || die "versão de hotfix inválida: '$V' (esperado v1.x.x.x)."
      BRANCH="hotfix-${V}"
      ;;
    *)
      die "tipo inválido: '$TYPE'."
      ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$IID" "$TITLE" "$TYPE" "$BRANCH" >> "$SELECTED"
done <<< "$CHOSEN"

# --- 4. resumo -------------------------------------------------------------
echo
echo "Gravado em: $SELECTED"
echo "IID  | TÍTULO | TIPO | BRANCH"
column -t -s$'\t' "$SELECTED"
echo
echo "Agora, no terminal Maestro, rode:  /factory-next   (processa o selected.tsv),"
echo "ou  /factory <texto da issue>  para uma issue específica."
