# M5 – Ferramentas e Automação (pipeline com gate de SLO)

Pipeline no GitHub Actions: build versionado, gate de SLO, canário com rollback e promoção.

**O roteiro da aula (comandos, o que mostrar e o que falar) está no [README raiz](../README.md), seção "Passo 4".**

| Arquivo | Para que serve |
|---|---|
| `../../.github/workflows/demo-slo-pipeline.yml` | o pipeline (publica o release `good`/`bad`/`fix` na branch `demo` → lint/test → build → gate → canário → promoção) |
| `slo_gate.py` | consulta o Datadog e bloqueia o deploy quando o error budget acabou (código 2) |
| `canary_verify.py` | mede o SLI da versão canário e decide entre promover (0) e fazer rollback (1) |
| `reset.sh` | redefine a branch `demo` (force push só nela) e volta as células à versão base; roda pela ação `reset` do `demo-ops` |
