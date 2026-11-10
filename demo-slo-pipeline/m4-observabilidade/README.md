# M4 – Monitoramento e Indicadores de Nível de Serviço

Dashboard, APM e logs no Datadog; investigação de uma falha "desconhecida" por traces.

**O roteiro da aula (comandos, o que mostrar e o que falar) está no [README raiz](../README.md), seção "Passo 3".**

| Arquivo | Para que serve |
|---|---|
| `create-dashboard.sh` | cria o dashboard (SLOs, sucesso e p95 por célula, requisições por versão, logs de erro) a partir de `dashboard.json` |
| `dashboard.json` | definição do dashboard (placeholders `__RUN__`, `__SLO_AVAIL__`, `__SLO_LAT__`) |
| `../scripts/inject-fault.sh` | injeta erro ou latência em uma célula (`latency 800`, `error 20`, `clear`) |
| `reset.sh` | apaga o dashboard e limpa as falhas |
