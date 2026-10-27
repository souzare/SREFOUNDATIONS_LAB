# Roteiro de experimentos (Gremlin)

> Regra de ouro: **hipótese → raio pequeno → observar → expandir**. Mantenha o botão **Halt All** do Gremlin à mão.
> Os tipos de ataque disponíveis dependem do seu plano Gremlin; se algum não estiver liberado, use um equivalente (ex.: Process Killer no lugar de Shutdown).

## Preparação

1. Gremlin UI → *Agents / Clients*: confirme o host `sre-lab-host` online.
2. Abra o dashboard `:8081`. Aguarde ~30 s: as 3 células devem estar verdes (≥ 99%).
3. Anote o baseline (média e p95) na folha abaixo.

## Experimento 1 – Shutdown de UMA célula (raio = 1 container)

- **Hipótese:** "Se `cell-a` cair, apenas os clientes de `cell-a` falham; `cell-b` e `cell-c` permanecem ≥ 99%."
- **Gremlin:** *Infrastructure → Containers* → selecione o container `cell-a` (nome ou label `cell=a`) → ataque **Shutdown** (sem reboot, ~60 s).
- **Observe:** dashboard (sucesso da célula A cai para 0%; B e C intactas).
- **Discussão:** o que foi *contido*? Qual foi o impacto no SLO global (≈ 1/3 dos clientes)? O router poderia reencaminhar para outra célula? (Veja `nginx.conf`: desligamos o failover de propósito. Failover espalha a falha e **aumenta** o raio.)

## Experimento 2 – Latência em outra célula (magnitude crescente)

- **Hipótese:** "Latência de 500 ms em `cell-b` aumenta o p95 de B, sem violar o SLO; 4000 ms viola (timeout do router = 3 s)."
- **Gremlin:** ataque **Latency** no container `cell-b`, porta de origem/destino `8000`, magnitude 500 ms por 2 min; repita com 4000 ms.
- **Observe:** p95 da célula B; com 4000 ms aparecem 504 → sucesso cai.
- **Discussão:** diferença entre **degradação** e **indisponibilidade**; quais SLIs revelam cada uma (latência × erros — dimensões VALET).

## Experimento 3 – Recursos (CPU) em `cell-c`

- **Hipótese:** "Consumo de CPU em `cell-c` eleva a latência de C (limite de 0,5 CPU), sem afetar A e B (isolamento de recursos)."
- **Gremlin:** ataque **CPU** no container `cell-c`, 1 core, 80%, 2 min.
- **Discussão:** por que `cpus: 0.5` no compose importa para conter o raio? (*noisy neighbor*).

## Experimento 4 – Expandindo o raio

- **Hipótese:** "Atacar as 3 células ao mesmo tempo derruba 100% do serviço."
- **Gremlin:** alvo = todos os containers com label `tier=cell`; ataque **Shutdown** (curto, 30 s).
- **Discussão:** quando ampliar o raio é aceitável? (ambiente, horário, confiança acumulada, *abort conditions*). Como esse resultado alimenta MTTR, RTO e estratégia de DR (Módulo 6)?

## Opcional – Gremlin Scenario

Monte um *Scenario* com os passos 1 → 2 → 4 em sequência (raio crescente) e use **Status Checks** apontando para o dashboard (`/api/stats`) como condição de abortar.

## Folha de hipóteses (copie por experimento)

| Campo | Preenchimento |
|-------|---------------|
| Hipótese | |
| Alvo (blast radius) | |
| Ataque e magnitude | |
| Baseline (sucesso/p95) | |
| Resultado observado | |
| Hipótese confirmada? | |
| O que aprendemos / ação de melhoria | |

## Notas do instrutor

- Tempo: Exp. 1 e 2 são suficientes para 60 min; 3 e 4 para 90 min.
- Erro comum dos alunos: confundir **blast radius** com **magnitude**.
- Gancho com o curso: "Minimizar o raio da explosão" (M6), Westrum generativo, *Game Days* e depois post-mortem *blameless* (M7).
- Extensão: adicionar um `shared-db` usado por todas as células e mostrar que o raio real passa a ser 100% (dependência compartilhada).
