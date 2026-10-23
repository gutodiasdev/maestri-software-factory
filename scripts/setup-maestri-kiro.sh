#!/usr/bin/env bash
# Cria no Maestri os presets da Software Factory (um por papel, lançando o Kiro CLI com o agente certo).
# Rode DENTRO de um terminal do Maestri (precisa de MAESTRI_SOCKET), de preferência o do Maestro.
# Idempotente: se o preset já existe, só atualiza o comando. Não apaga nada.
set -u
M="${MAESTRI_CLI:-maestri}"
command -v "$M" >/dev/null 2>&1 || { echo "maestri CLI não encontrada: rode isto num terminal do Maestri." >&2; exit 1; }
"$M" debug >/dev/null 2>&1 || { echo "Sem conexão com o Maestri (rode 'maestri debug')." >&2; exit 1; }

existing="$("$M" preset list 2>&1)"

# nome do preset | agente Kiro | Maestro Mode
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
  cmd="kiro-cli chat --agent $agent"      # direto, sem wrapper: o Maestri retoma a sessão pelo nome do programa
  # só o Maestro aparece no Quick Start; os demais são recrutados pelo Maestro
  qs=off; [ "$maestro" = on ] && qs=on
  if grep -Fq "\"$name\"" <<<"$existing" || grep -Fq "$name" <<<"$existing"; then
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
echo "Pronto. Próximo passo: abra um terminal com o preset 'Factory Maestro' no Ground do workspace e rode /factory <feature>."
