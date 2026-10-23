---
name: factory-continue
description: Libera o plan gate de um job da Software Factory depois que o humano revisou plan.md/checks.md, e retoma na fase de build. Use como `/factory-continue <job-id>` no terminal Maestro do Ground.
---

# /factory-continue

Job: **$ARGUMENTS** (id de 3 dígitos, ex.: `001`).

1. Ache o floor do job em `.specs/factory/index.md` e leia `<FLOOR_PATH>/.specs/factory/jobs/<id>/job.json`. `stage` precisa ser `plan-review`; senão diga em que estágio está e pare.
2. Releia o artefato de plan da **skill de plan** (`factory.phases.plan.skill` de `AGENTS.md`, default `tlc-spec-lean` ⇒ `<FLOOR_PATH>/.specs/features/<slug>/plan.md` e `checks.md`; `tlc-plan` ⇒ `.tasks/<slug>.md`): se o humano editou **e** a skill tem validadores (só a `tlc-spec-lean`), rode de novo `validate_plan.py`/`validate_checks.py` (`--root <FLOOR_PATH>`); exit ≠ 0 ⇒ pare e mostre o erro. Skill sem validador ⇒ confira só o artefato. **Não** reescreva o plan; ele é do humano agora.
3. Registre `plan_approved_by: human` em `job.json`, stage `build`, e continue a skill `factory` a partir do **passo 2 (Build)**, reutilizando floor, BASE e FLOOR_PATH.
4. Mova a Note do job de volta para a raia `Factory · Em andamento` (`maestri note stack "Job <id> · <slug>" "Factory · Em andamento"`).
