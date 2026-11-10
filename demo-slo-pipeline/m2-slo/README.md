# M2 – Objetivos de Nível de Serviço e Error Budgeting

SLO como código no Datadog e a política que lhe dá consequência.

**O roteiro da aula (comandos, o que mostrar e o que falar) está no [README raiz](../README.md), seção "Passo 1".**

| Arquivo | Para que serve |
|---|---|
| `create-slos.sh` | cria os SLOs (disponibilidade 99% e latência 95% < 300 ms, janela 7d) e os monitores de error budget e burn rate; publica `DD_SLO_IDS` no GitHub |
| `calc_error_budget.py` | reproduz as contas dos slides (43 min, 7.440 logins, 250 tíquetes) |
| `POLITICA_ERROR_BUDGET.md` | estados verde/amarelo/laranja/vermelho e o processo de exceção |
| `reset.sh` | apaga SLOs e monitores e inicia um novo `demo_run` (orçamento volta a 100%) |
