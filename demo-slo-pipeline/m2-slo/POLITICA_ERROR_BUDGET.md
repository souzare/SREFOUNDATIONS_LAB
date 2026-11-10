# Política de Error Budget – serviço `cell-app`

SLOs (janela móvel de 7 dias): **disponibilidade 99%** e **latência 95% < 300 ms**.
Orçamento de disponibilidade = 1% das requisições do período.

| Orçamento restante | Estado | O que é permitido |
|---|---|---|
| > 50% | Verde | Deploys normais pelo pipeline, com canário. |
| 25% a 50% | Amarelo | Só mudanças pequenas. Priorizar melhorias de confiabilidade no backlog. |
| 0% a 25% | Laranja | Só correções e mudanças de confiabilidade. Alerta de error budget ativo. |
| ≤ 0% | Vermelho | **Congelamento**: o gate do pipeline **bloqueia** qualquer deploy. |

## Exceções
Um deploy com o orçamento esgotado só é liberado por **override explícito**: justificativa registrada
(`reason`) e aprovação de uma segunda pessoa no environment `slo-override` do GitHub. Toda exceção
entra no post-mortem do período.

## Consequências (o que torna o SLO um compromisso, não um número)
- Orçamento esgotado = sem lançamento de funcionalidades; o backlog só aceita itens de confiabilidade.
- Equipe de desenvolvimento e SRE alinham as melhorias diariamente até o orçamento se recuperar.
- Burn rate acima de 14,4x por 1 h (e 5 min) = incidente: aciona o plantão.
