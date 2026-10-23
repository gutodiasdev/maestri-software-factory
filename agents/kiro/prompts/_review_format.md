
## Formato obrigatório da review

Arquivo: `JOB_DIR/round-<ROUND>/review-<ângulo>.md` (crie a pasta se faltar). **A primeira linha é exatamente `VERDICT: PASS` ou `VERDICT: CHANGES`** — o Maestro lê só isso para decidir. Depois:

- `## Resumo` — 2-3 linhas.
- `## Achados` — uma linha por achado: `[must-fix|nit] <arquivo>:<linha> — o que está errado → o que mudar`. `must-fix` = quebra o ângulo (bloqueia). `nit` = opcional (nunca bloqueia). `VERDICT: CHANGES` **se e somente se** houver ao menos um `must-fix`. Sem `file:line`, não é achado.
- `## O que verifiquei` — o que você leu/rodou (comandos e exit codes), para o Approver confiar sem refazer.

Regras: você é **somente leitura** sobre o código (nunca conserte, nunca commite, nunca edite outro arquivo da fábrica). Revise **o diff** `git diff BASE..HEAD` e o contexto que ele toca, contra `spec.md`, `plan.md` e `checks.md`. Prefira achados concretos e verificáveis a opiniões; não repita o que o lint/tsc já pega. Rodar `npm run test`/`build` é permitido; subir o dev server **não** (exige bancos remotos). Em dúvida entre PASS e CHANGES, descreva o risco e decida pelo critério: *um humano sensato bloquearia o merge por isso?*
