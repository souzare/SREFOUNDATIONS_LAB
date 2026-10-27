# Guia do Instrutor – como rodar e o que explicar

Formato: **Comandos** (o que você executa) → **Mostrar** (o que aparece na tela) → **Falar** (roteiro para os alunos).
Duração total sugerida: ~2h30 (Lab 1: 80 min · intervalo · Lab 2: 55 min · fechamento 10 min).

---

## 0. Checklist antes da aula (D-1)

- [ ] Repositório publicado (público) no GitHub com esta pasta.
- [ ] Conta Gremlin Free criada; Team ID/Secret em mãos.
- [ ] AWS CLI configurada (`aws sts get-caller-identity`) + Session Manager plugin instalado.
- [ ] **Lab 1 no ar** (bootstrap leva 3–5 min):
  ```bash
  export GREMLIN_TEAM_ID=...  GREMLIN_TEAM_SECRET=...
  export REPO_URL=https://github.com/SEU_USUARIO/sre-chaos-lab.git
  cd lab1-gremlin-blast-radius && ./scripts/deploy.sh
  ```
  Confirme no Gremlin (*Agents/Clients*) que `sre-lab-host` está online. Abra o dashboard com `./scripts/port-forward.sh 8081`.
- [ ] **Lab 2 no ar** e aquecido:
  ```bash
  cd lab2-cloudwatch-investigations && ./scripts/deploy.sh && ./scripts/load.sh 60
  ```
- [ ] Faça um ensaio completo de cada falha e tire **prints** (plano B).
- [ ] Imprima/compartilhe `EXPERIMENTOS.md` (folha de hipóteses) e `ROTEIRO_ALUNO.md`. **Não** compartilhe `NOTAS_INSTRUTOR.md`.

---

# LAB 1 – Gremlin e raio da explosão (80 min)

## 1.1 Abertura (10 min) – sem comandos

**Falar:**
- "Módulo 6: *antifragilidade* — não esperamos a falha acontecer, nós a provocamos de forma controlada para aprender."
- "Chaos Engineering não é quebrar por quebrar: é o **método científico** — hipótese, experimento, observação, aprendizado."
- Dois conceitos-chave (escreva no quadro):
  - **Blast radius (raio da explosão)** = *quem* é afetado: 1 container → 1 célula → tudo.
  - **Magnitude** = *quão forte*: 200 ms ou 4000 ms de latência.
- "Começamos com raio e magnitude pequenos e só ampliamos com confiança." (Gremlin tem o botão **Halt All** — mostre onde fica.)

## 1.2 Apresentar a arquitetura (10 min)

**Mostrar:** diagrama do `lab1-gremlin-blast-radius/README.md` e o dashboard (`http://localhost:8081`).

**Falar:**
- "Temos **3 células** idênticas. Cada cliente (1–30) é fixado em uma célula pelo router. É a ideia de *cell-based architecture*: se uma célula falha, o impacto é só ~1/3 dos clientes."
- "O dashboard é o nosso **SLI por célula**: % de sucesso e latência. Verde = dentro do SLO de 99% (Módulo 2)."
- "Reparem no `nginx.conf`: desliguei o failover de propósito. Se eu redirecionasse clientes da célula doente para as saudáveis, eu **espalharia a falha** — aumentaria o raio."

**Perguntar:** "Qual é o SLO do serviço? Quanto de *error budget* temos?" (99% → 1% das requisições.)

## 1.3 Experimento 1 – Shutdown de UMA célula (15 min)

**Preencher a folha de hipóteses com a turma antes de rodar.**
Hipótese: "Se `cell-a` cair, só os clientes de A falham; B e C seguem ≥ 99%."

**Comandos:** (na UI do Gremlin) *Infrastructure → Containers* → selecionar `cell-a` → ataque **Shutdown** → Run.

**Mostrar:** a linha da `cell-a` ficando vermelha (0%) enquanto B e C continuam verdes.

**Falar:**
- "Isso é o raio da explosão **contido**. O impacto global é ~1/3, não 100%."
- "O que cada um percebeu? Quanto tempo levou para *detectarmos*? (MTTD) E para recuperar? (MTTR)".

**Perguntas aos alunos:** "E se o router redirecionasse? Melhor ou pior?" (Resposta: depende — evacuação de célula protege usuários, mas pode derrubar as demais por sobrecarga; é uma decisão de projeto.)

## 1.4 Experimento 2 – Latência, magnitude crescente (15 min)

Hipótese: "500 ms de latência em `cell-b` aumenta o p95 mas não viola o SLO; 4000 ms viola (timeout do router = 3 s)."

**Comandos:** Gremlin → container `cell-b` → ataque **Latency** (porta 8000), 500 ms por 2 min. Depois repita com 4000 ms.

**Mostrar:** p95 de B subindo; com 4000 ms o sucesso cai (504).

**Falar:**
- "Aqui o **raio é o mesmo** (só a célula B), mas a **magnitude** mudou e o efeito também."
- "Degradação ≠ indisponibilidade. Repare como a *disponibilidade* só cai quando a latência passa do timeout. Por isso medimos latência E erros (dimensões VALET)."

## 1.5 Experimento 3 – CPU na `cell-c` (10 min)

Hipótese: "CPU alta em C sobe a latência de C e não afeta A/B."

**Comandos:** Gremlin → `cell-c` → ataque **CPU** (1 core, 2 min).

**Falar:** "Cada container tem limite de 0,5 CPU (`docker-compose.yml`). Sem limites, um *noisy neighbor* poderia espalhar o problema — isolamento de recursos também contém o raio."

## 1.6 Experimento 4 – Expandir o raio (10 min)

Hipótese: "Atacar as 3 células ao mesmo tempo derruba 100% do serviço."

**Comandos:** Gremlin → selecionar `cell-a`, `cell-b` e `cell-c` (label `tier=cell`) → **Shutdown** curto (30 s).

**Falar:**
- "Só expandimos depois de aprender nos passos anteriores. Em produção, isso é um *Game Day* planejado, com condições de abortar."
- "O que aprendemos aqui alimenta o **plano de DR** e as metas de RTO/RPO."

## 1.7 Fechamento do Lab 1 (5 min)

**Falar / perguntar:** "O que mudaria na arquitetura depois destes testes?" Respostas esperadas: mais células, autoscaling/auto-healing, alertas melhores, runbooks. Gancho: "E se as células compartilhassem um banco? O raio real seria 100%." (Extensão possível.)

---

# LAB 2 – CloudWatch investigations (55 min)

## 2.1 Abertura (5 min)

**Falar:**
- "Módulo 4: observabilidade é poder *inferir o estado interno* a partir das saídas — logs, métricas, traces."
- "Hoje vamos investigar um incidente **duas vezes**: primeiro como humanos, depois com IA. A pergunta é: onde a IA ajuda e onde ainda precisamos de julgamento humano?"
- "Lembrem: 'automação é multiplicador de força, não panaceia' (Módulo 5)."

## 2.2 Apresentar o ambiente (5 min)

**Mostrar:** diagrama do `lab2-.../README.md`; no console, a função Lambda, a tabela DynamoDB e o alarme `sre-lab-orders-lambda-errors`.

**Falar:** "API de pedidos simples. O alarme é o nosso SLI de **erros**. Funciona normal."

**Comandos:**
```bash
cd lab2-cloudwatch-investigations
./scripts/load.sh 30        # tudo 201
```

## 2.3 Injetar a falha (sem revelar!) (5 min)

**Comandos:**
```bash
./scripts/inject-fault.sh bad-config
./scripts/load.sh 120       # agora aparecem 500
```

**Falar:** "Um incidente começou. O alarme vai disparar em 1–2 minutos. Vocês são o time de plantão."
(Não diga que foi uma mudança de configuração.)

## 2.4 Parte 1 – Investigação humana (10 min)

Alunos preenchem a Parte 1 do `ROTEIRO_ALUNO.md` usando Metrics, Logs Insights, X-Ray e CloudTrail.

**Falar enquanto circulam:** "Primeira pergunta de todo incidente: **o que mudou?** Olhem o CloudTrail." Anote no quadro quem chegou à causa e em quanto tempo.

## 2.5 Parte 2 – Investigação com IA (15 min)

**Mostrar:** Console → CloudWatch → alarme → **Investigate / Start investigation**. Acompanhe o feed.

**Falar:**
- "A IA varre métricas, logs, traces e eventos de mudança e propõe **hipóteses** com evidências."
- "Eu **aceito ou descarto** cada achado — a IA sugere, o SRE decide."
- Compare: "A IA achou a mudança de configuração? Em quanto tempo? Trouxe hipóteses irrelevantes?" (Use o gabarito em `NOTAS_INSTRUTOR.md`.)

**Se a investigação demorar:** use os prints do ensaio e volte a ela ao final.

## 2.6 Repetir com a 2ª falha (10 min)

```bash
./scripts/restore.sh
./scripts/inject-fault.sh iam-deny
./scripts/load.sh 120
```
Desta vez só **POST falha** e o erro é `AccessDenied`. Peça aos alunos que apostem a causa *antes* de abrir a investigação.

## 2.7 Discussão blameless (5 min)

**Falar:**
- "Alguém executou um comando que quebrou o serviço. Quem culpamos? Ninguém: perguntamos **por que o processo permitiu** (Módulo 7)."
- Ações preventivas: IaC com revisão, validação de config, deploy canário, política de IAM controlada, alarme mais cedo.
- Peça 3 itens de ação de post-mortem (Parte 3 do roteiro).

---

# Fechamento (10 min)

Ligue os dois labs: "No Lab 1 **provocamos** a falha e medimos o raio; no Lab 2 **investigamos** a falha e medimos a rapidez do diagnóstico. Ambos reduzem MTTD/MTTR."

## Limpeza (obrigatória)

```bash
cd lab2-cloudwatch-investigations && ./scripts/restore.sh && ./scripts/destroy.sh
cd ../lab1-gremlin-blast-radius && ./scripts/destroy.sh
```
Verifique no console que as stacks `sre-lab1-gremlin` e `sre-lab2-investigations` sumiram.

---

## Troubleshooting rápido

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| `aws aiops` não existe | AWS CLI antiga | Atualize a CLI v2 ou faça o setup pelo console |
| Setup do investigation group falha | Permissão/role ainda propagando | Rode `./scripts/setup-investigation-group.sh` novamente ou crie pelo console |
| Agente Gremlin offline | Credenciais erradas / sem internet | `docker logs gremlin-agent` na instância (`aws ssm start-session ...`) |
| Dashboard sem dados | Bootstrap ainda rodando | Aguarde 3–5 min; `tail -f /var/log/lab-setup.log` |
| 502 persistente após ataque | nginx com IP antigo da célula | `docker compose restart router` |
| `destroy` do Lab 2 falha ao apagar a role | Policy `chaos-deny-ddb` sobrou | `./scripts/restore.sh` e rode `destroy.sh` de novo |
| Investigação não encontra a causa | Poucos dados / pouco tempo | Gere mais carga (`load.sh`), espere alguns minutos, use os prints |
