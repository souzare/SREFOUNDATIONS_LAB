# Roteiro do aluno – Investigando um incidente

Contexto: a API de pedidos começou a retornar erros 500. O alarme `sre-lab-orders-lambda-errors` disparou.

## Parte 1 – Investigação humana (10 min, sem IA)

Use apenas: CloudWatch Metrics, Logs Insights, X-Ray e CloudTrail Event history.

| Pergunta | Sua resposta |
|----------|--------------|
| Quando o problema começou? | |
| Qual SLI foi afetado (disponibilidade, latência, erros)? | |
| Qual componente falha (API GW, Lambda, DynamoDB)? | |
| O que mudou pouco antes? (CloudTrail) | |
| Hipótese de causa raiz | |
| Como confirmar a hipótese? | |

Dica de Logs Insights:
```
fields @timestamp, @message
| filter @message like /order_failed/
| sort @timestamp desc
| limit 20
```

## Parte 2 – Investigação com IA (10 min)

1. Inicie a investigação a partir do alarme (botão **Investigate**).
2. Registre: hipóteses geradas, evidências citadas, ordem de confiança.
3. Aceite ou descarte cada achado justificando.

| Item | Humano | IA |
|------|--------|----|
| Tempo até a hipótese | | |
| Causa raiz identificada | | |
| Evidências usadas | | |
| Correlacionou mudança (CloudTrail)? | | |

## Parte 3 – Discussão (blameless)

- Onde a IA ajudou? Onde precisou de validação humana?
- Que SLO/alerta teria detectado antes? Qual o MTTD/MTTR deste incidente?
- Que ação preventiva evitaria a recorrência (IaC, validação de config, canary, política de IAM)?
- Escreva 3 itens de ação para um post-mortem *blameless*.
