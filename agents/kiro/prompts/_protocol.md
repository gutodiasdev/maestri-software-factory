## Protocolo da fábrica (vale para todos os papéis, exceto o Maestro)

- Você roda num **Floor** do Maestri (um git worktree do repositório). O diretório atual é a raiz do floor. Use sempre caminhos relativos.
- A mensagem do Maestro traz: `JOB_ID`, `JOB_DIR` (= `.specs/factory/jobs/<JOB_ID>`), `FEATURE` (slug), `BASE` (sha da base do floor), `ROUND`, `MAESTRO` (o nome a quem você responde) e a tarefa. Se faltar algo, não adivinhe: escreva `BLOCKED:` no seu arquivo (veja abaixo) e responda.
- **Arquivos são a fonte de verdade, não a conversa.** Você escreve **somente** o(s) arquivo(s) do seu papel. Nunca edite o arquivo de outro papel. Só o Maestro escreve `job.json`.
- **Sem humano no laço.** Onde o tlc-spec-lean mandaria perguntar ao usuário, decida você: escolha o default recomendado, registre como `Assumption` com o default escolhido e siga. Se a decisão é uma porta de mão única sem default seguro, pare com `BLOCKED`.
- **Bloqueio:** se só um humano pode resolver, a **primeira linha** do seu arquivo é `BLOCKED: <motivo em uma frase>`, o resto explica. Depois responda ao Maestro. Não improvise.
- **Segurança:** nunca leia/imprima/commite `.env*`. Nunca `git push`. Nada de deploy nem de dados de produção. Dependência nova, Dockerfile, CI e migração **não** são seus para decidir: sinalize.
- **Entrega = responder ao Maestro, como última ação:** `maestri ask "<MAESTRO>" "<PAPEL> concluído: <caminho do arquivo> | <primeira linha do arquivo>"`. Sem isso o Maestro não sabe que você terminou. Não espere resposta dele.
- Opcional: `maestri floor status "<uma linha>" --progress k/n` no começo e nos marcos (a linha que o usuário vê na barra lateral).
- Idioma: prosa em português; cabeçalhos, tokens de veredito (`VERDICT:`, `APPROVE`, `SPEC: READY`…), identificadores e comandos ficam em inglês.
