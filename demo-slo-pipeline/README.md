# Demo SLO + Pipeline (Módulos 2 a 5)

Uma **demo única, conduzida pelo instrutor**: o mesmo app sobe uma vez e cada módulo acrescenta uma camada.
No fim, um deploy é **bloqueado pelo pipeline** porque o SLO estourou o orçamento de erro, e o único caminho
é uma exceção explícita e aprovada.

> **Tudo roda na nuvem.** O ambiente inteiro sobe com **um stack do CloudFormation**: pelo console, ou por um script que
> lê as suas chaves de um `.env` local (ignorado pelo git). Durante a aula você usa só o navegador (AWS Console, GitHub e Datadog). Os alunos só assistem. Este README é o roteiro: **Parte A** sobe o ambiente (véspera),
> **Parte B** é a aula, **Parte C** reseta para repetir.

## Onde cada coisa roda

| O quê | Onde | Como você aciona |
|---|---|---|
| Subir e derrubar o ambiente | **CloudFormation** (um único stack) | `./scripts/deploy.sh` com `.env` local, ou Console AWS → CloudFormation |
| Ações da aula: criar SLOs, dashboard, injetar falha, ver orçamento, resetar | **GitHub Actions** (workflow `demo-ops`) | Actions → demo-ops → *Run workflow* |
| Pipeline de entrega (build, gate de SLO, canário, promoção) | **GitHub Actions** (workflow `demo-slo-pipeline`) | Actions → demo-slo-pipeline → *Run workflow* |
| O app (3 células), router, gerador de carga e Datadog Agent | **EC2 t3.micro** (Docker) | Já está no ar; shell pelo Session Manager |
| Observabilidade (SLOs, monitores, dashboard, APM, logs) | **Datadog** | Navegador |
| Estado e configuração (chaves, ids de SLO, run atual) | **AWS SSM Parameter Store** | Automático |

```
 GitHub Actions ──OIDC (sem chaves)──► AWS ──► SSM SendCommand ──► EC2 (Docker)
   demo-ops (botões da aula)                                         ├─ cell-a / cell-b / cell-c  (Flask + ddtrace)
   demo-slo-pipeline:                                                ├─ router (nginx)
   release → lint/test → build → gate de SLO                         ├─ loadgen (30 clientes; SLIs via DogStatsD)
   → canário (cell-a) → verifica SLI → promove                       └─ datadog-agent ──► Datadog (SLOs, APM, logs)
```

| Módulo | Camada | Pasta |
|---|---|---|
| M2 | SLO como código + política de error budget | [m2-slo/](m2-slo/) |
| M3 | Release manual cronometrado e análise de toil | [m3-toil/](m3-toil/) |
| M4 | Dashboard, APM e logs; investigação de falha "desconhecida" | [m4-observabilidade/](m4-observabilidade/) |
| M5 | Pipeline com canário, rollback e gate de SLO | [m5-pipeline-slo-gate/](m5-pipeline-slo-gate/) |

**Custo:** 1 EC2 t3.micro (free tier em conta nova), S3 com expiração de 14 dias, SSM e a role OIDC. Sem ALB, NAT ou
ECR. GitHub Actions é gratuito em repositório público. Se a t3.micro ficar lenta (Datadog Agent + 3 apps + carga em 1 GB),
rode o setup com `INSTANCE_TYPE=t3.small` (centavos por hora).

---

# Parte A – Subir o ambiente (véspera da aula)

Faça uma vez; depois use o reset. Tempo total: ~20 min (a maior parte é o bootstrap da EC2).

## A1. Contas e chaves

| Item | Detalhe |
|---|---|
| AWS | Conta de laboratório; seu usuário precisa criar IAM, EC2, S3, SSM e CloudFormation (administrador) |
| GitHub | Repositório **público** com este código |
| Datadog | Site da conta (`datadoghq.com`, `datadoghq.eu`, `us5.datadoghq.com`...), uma **API key** e uma **Application key** (*Organization Settings → API Keys / Application Keys*; a de aplicação precisa criar SLOs, monitores e dashboards) |

## A2. O código precisa estar na main do GitHub

A EC2 e o pipeline buscam o código no GitHub. Publique a pasta `demo-slo-pipeline/` **e** a pasta `.github/`
(workflows e a ação `demo-env`) na branch `main` do seu repositório, pelo fluxo de git que você já usa.
Confira no navegador: `https://github.com/<owner>/<repo>/tree/main/demo-slo-pipeline` e `.../tree/main/.github`.

## A3. Subir o ambiente: um stack do CloudFormation

O template [infra/demo.yaml](infra/demo.yaml) cria **tudo**: VPC, EC2 (Docker, app, carga e Datadog Agent), bucket de artefatos,
role OIDC do pipeline e os parâmetros do SSM com as suas chaves do Datadog.

### Opção A – script com `.env` local (as chaves não passam pelo console)

Requer o AWS CLI com sessão ativa (`aws sts get-caller-identity`) e o código já na `main` do GitHub (A2).

```bash
cd demo-slo-pipeline
cp .env.example .env        # o .env está no .gitignore; o script se recusa a rodar se não estiver
# edite o .env: DD_API_KEY, DD_APP_KEY e DD_SITE (opcionais: GITHUB_REPO, INSTANCE_TYPE, AWS_REGION)
./scripts/deploy.sh
```

O script faz **5 fases** e para na primeira que falhar, dizendo o motivo:

| Fase | O que acontece | Como conferir sozinho |
|---|---|---|
| 1 | Valida a sessão AWS e as duas chaves do Datadog (incluindo permissão de SLO) | mensagem "AWS e Datadog OK" |
| 2 | Confere que o repositório é público e que `demo-slo-pipeline/` está na `main` | abrir `github.com/<owner>/<repo>/tree/main/demo-slo-pipeline` |
| 3 | Detecta se a conta já tem o provider OIDC do GitHub (só pode haver um) | `aws iam list-open-id-connect-providers` |
| 4 | Cria o stack `sre-demo`. Só termina quando Docker, app e Datadog Agent estão no ar (8 a 12 min) | `aws cloudformation describe-stacks --stack-name sre-demo --query 'Stacks[0].StackStatus'` |
| 5 | Cria a variável `AWS_ROLE_ARN` no GitHub (se o `gh` estiver instalado e logado) ou imprime o valor para você criar no A4 | `GitHubRoleArn` na aba Outputs do stack |

Com isso, os passos 1 a 6 da Opção B abaixo não são necessários. Siga para o **A4**.

### Opção B – pelo console da AWS

1. Console AWS (região **us-east-1**, ou outra, mas use sempre a mesma) → **CloudFormation → Create stack → With new resources**.
2. **Upload a template file** → escolha `demo-slo-pipeline/infra/demo.yaml` (do seu clone, ou baixe-o pelo botão *Raw → Download* no GitHub) → **Next**.
3. **Stack name:** `sre-demo`. Parâmetros:

| Parâmetro | Valor |
|---|---|
| `DatadogApiKey` / `DatadogAppKey` | As chaves do A1 (o console não as exibe depois: são `NoEcho`) |
| `DatadogSite` | O site da sua conta (`datadoghq.com`, `datadoghq.eu`, `us5.datadoghq.com`...) |
| `GitHubRepo` | `owner/repo` do repositório público (ex. `souzare/SREFOUNDATIONS_LAB`) |
| `InstanceType` | `t3.micro` (free tier); se ficar lenta, `t3.small` |
| `GitHubOidcProviderArn` | **Deixe vazio.** Só preencha se a criação falhar com "EntityAlreadyExists": a conta já tem o provider do GitHub (IAM → Identity providers → `token.actions.githubusercontent.com`); cole o ARN dele. **Em atualizações do stack, mantenha vazio**: preencher o ARN do provider que o próprio stack criou faz o CloudFormation **apagá-lo** (e o pipeline passa a falhar com "web identity token could not be validated") |
| `RepoBranch` | `main` |

4. **Next → Next**, marque *"I acknowledge that AWS CloudFormation might create IAM resources"* → **Submit**.
5. Aguarde ~8 a 12 min até **CREATE_COMPLETE**. A instância só conclui quando o Docker, o app e o Datadog Agent estão no ar
   (ela sinaliza o CloudFormation ao final do bootstrap), então `CREATE_COMPLETE` já significa "ambiente pronto".
6. Aba **Outputs:** copie o valor de `GitHubRoleArn` (usado no A4).

> Se o stack falhar e der rollback, abra **Events** e veja o recurso com erro. Para inspecionar o log do bootstrap, recrie o stack
> escolhendo *Stack failure options → Preserve successfully provisioned resources* e, no Session Manager, `tail -50 /var/log/demo-setup.log`.

**Alternativa sem console de upload (CloudShell, uma linha):** ícone `>_` do Console, clone o repositório e rode
`aws cloudformation deploy --stack-name sre-demo --template-file demo-slo-pipeline/infra/demo.yaml --capabilities CAPABILITY_IAM --parameter-overrides DatadogApiKey=... DatadogAppKey=... DatadogSite=datadoghq.com GitHubRepo=<owner>/<repo>`.

## A4. Configurar o GitHub (pela interface web, uma vez)

1. **Variável da role:** *Settings → Secrets and variables → Actions → Variables → New repository variable*
   com o nome `AWS_ROLE_ARN` e o valor de `GitHubRoleArn` (Outputs do stack). **Se o `deploy.sh` encontrou o `gh` logado, esta variável já foi criada.** (Se usou outra região, crie também `AWS_REGION`.)
   Não há secrets: as chaves do Datadog ficam no SSM e o pipeline as lê pela role.
2. **Aprovação de exceção:** *Settings → Environments → New environment* → nome exato `slo-override` →
   marque **Required reviewers** e adicione quem aprova (você, no ensaio; outra pessoa, na aula).
3. Se o repositório for de uma organização que restringe o token: *Settings → Actions → General → Workflow permissions →
   Read and write permissions*.

## A5. Primeira execução e verificação

Em **Actions → demo-ops → Run workflow**, rode as ações abaixo (o resultado aparece no *Summary* da execução):

| Ordem | action | O que você deve ver |
|---|---|---|
| 1 | `check-datadog` | `DD_API_KEY: valida` e `DD_APP_KEY: acesso a SLOs OK` (o CloudFormation não consegue validar as chaves; esta ação confirma que digitou certo) |
| 2 | `status` | 6 containers `Up` (`cell-a`, `cell-b`, `cell-c`, `router`, `loadgen`, `datadog-agent`), as três células em `1.0.0`, o `DEMO_RUN` e ~30 requisições por janela com `success_pct` perto de 100 |
| 3 | `reset` | Cria a branch `demo` a partir da `main` (necessária ao pipeline) e inicia um `demo_run` limpo. Na primeira vez não há nada a apagar |

No Datadog, em **Metrics → Explorer**, busque `sre.requests.total` agrupado por `cell` (leva ~2 min depois do bootstrap).
Em **Infrastructure → Containers** devem aparecer os containers e, em **APM → Services**, o serviço `cell-app` (`env:demo`).

## A6. Ensaio

Rode a Parte B inteira uma vez sozinho e depois use o reset (Parte C). **Não pule o ensaio**: é nele que você valida,
na sua conta, o que não pude testar daqui (veja "Limites desta entrega" no fim).

---

# Parte B – Roteiro da aula

Formato: **Ações** → **Mostrar** → **Falar**. As ações são os botões do GitHub:
**Actions → demo-ops → Run workflow → escolha `action`** (para o pipeline: **Actions → demo-slo-pipeline → Run workflow**).
Abra a execução e o *Summary* para mostrar a saída na tela. Deixe o tráfego rodando entre as aulas: o SLO precisa de volume.

## Passo 1 – M2: criar o modelo de SLO

**Ações (demo-ops)**: `status` → `calc-error-budget` → `create-slos`. Depois leia a política em
[m2-slo/POLITICA_ERROR_BUDGET.md](m2-slo/POLITICA_ERROR_BUDGET.md).

**Mostrar**
1. `status`: três células idênticas, cada cliente fixo em uma célula, ~100% de sucesso. No Datadog (**Metrics → Explorer**):
   `sre.requests.good` e `sre.requests.total` por `cell`. São os SLIs: eventos bons / eventos totais.
2. `calc-error-budget`: 99,9% = 43 min/mês; 99% de 744.000 logins = 7.440 falhas permitidas; 75% de 1.000 tíquetes = 250 manuais.
3. `create-slos`: imprime os ids. Abra **Service Management → SLOs**: *Disponibilidade* (alvo 99%, janela 7d) e *Latência*
   (95% das respostas < 300 ms), ambos com o error budget perto de 100%. Em **Monitors** aparecem os dois alertas de
   error budget e burn rate.
4. A política: tabela de estados (verde/amarelo/laranja/vermelho) e a consequência no vermelho.

**Falar**
- "O SLO é uma meta de experiência do usuário, nunca 100%. Aqui: 99% das requisições devem dar certo."
- "O error budget é o que sobra: 1% das requisições pode falhar. É um orçamento para **gastar** em inovação."
- "Escrevi o SLO como código: repetível, versionável e revisável. A política é o que dá dentes ao SLO."
- Pergunte: "O que deve acontecer quando o orçamento acaba?" (é o gancho do Passo 4).

> O SLO leva 2 a 5 min para mostrar dados depois de criado: rode `create-slos` cedo e fale da calculadora enquanto isso.

## Passo 2 – M3: o custo do release manual

**Ações**
1. Leia [m3-toil/RELEASE_MANUAL.md](m3-toil/RELEASE_MANUAL.md) e **execute-o de verdade** em uma sessão do navegador:
   Console AWS → **Systems Manager → Session Manager → Start session** → instância `sre-demo`. Cronometre cada passo.
2. `demo-ops` → `toil-roi` (a análise, com os tempos típicos do CSV; para usar os seus, edite
   [m3-toil/toil-steps.csv](m3-toil/toil-steps.csv) pela interface do GitHub antes de rodar).

**Mostrar**
1. O roteiro manual: 8 etapas (sessão, `git pull`, editar versão, `docker build`, subir a `cell-a`, observar, repetir em `b` e `c`,
   avisar o time). Ele sobe a versão 1.1.0 manualmente, célula a célula.
2. A tabela do `toil-roi`: cada passo classificado pelas 6 características (manual, repetitivo, automatizável, tático,
   sem valor duradouro, escala linear). O code review **não** é toil. O resto é.
3. O resumo: ~70% do release é toil, ~5 h/mês com 8 releases, e a automação se paga em ~3 meses.

**Falar**
- "Toil é trabalho manual, repetitivo, automatizável e que cresce linearmente com o serviço. Reunião não é toil; coisa chata nem sempre é toil."
- "A regra do Google: abaixo de 50% do tempo em operação. Aqui passamos disso."
- "Reparem no passo 'decidir no olho se o SLO permite': esse é o que o gate do M5 vai automatizar."
- Feche: "Este backlog de automação é exatamente o pipeline do Passo 4."

> Ao terminar: as células estão em 1.1.0 manualmente. A ação `reset` (Parte C) devolve tudo a 1.0.0.

## Passo 3 – M4: observar o sistema

**Ações (demo-ops)**: `create-dashboard` → `inject-fault` (cell = `cell-b`, fault = `latency`, value = `800`; **não diga qual célula**)
→ ao final, `clear-faults`.

**Mostrar**
1. O dashboard (a URL aparece no log da ação): os dois SLOs, o sucesso por célula com a linha do SLO, o p95 por célula,
   as requisições por célula **e versão** (é aqui que o canário vai aparecer no M5) e o stream de logs de erro.
2. Cerca de 1 min depois da injeção: o p95 da `cell-b` sobe acima da linha de 300 ms e o SLO de **latência** começa a gastar budget,
   enquanto a **disponibilidade** continua intacta. O monitoramento diz *que* está lento, não *por quê*.
3. **APM → Services → cell-app → Traces**: filtre `@cell:cell-b` e ordene por duração. No *flame graph* o tempo está no span
   `db.query` (serviço `orders-db`). Use o botão de logs do trace para ver os logs da mesma requisição (correlação por `trace_id`).
4. Opcional, outro tipo de falha: `inject-fault` com `cell-c`, `error`, `20`; mostre os erros no stream de logs e nos traces com erro;
   depois `clear-faults`.

**Falar**
- "Monitoramento responde a perguntas que previmos (está lento?). Observabilidade responde às que não previmos (por que a `cell-b`?)."
- "Os SLIs são os números do dashboard; os SLOs, a meta; o trace e o log, o diagnóstico."
- "Instrumentamos tudo (traces, logs, métricas), mas só alertamos o que importa: o burn rate do SLO."

## Passo 4 – M5: pipeline com gate de SLO

**Preparação (antes de entrar na aula)** — tudo no `demo-ops`:
1. `reset` (orçamento novo e cheio, branch `demo` limpa, células em 1.0.0).
2. `create-slos`, depois `create-dashboard`.
3. **Espere ~15 min** de tráfego: o orçamento depende do volume.
4. Deixe abertas as abas: **Actions** (workflow `demo-slo-pipeline`) e o dashboard do Datadog.

**4.1 Release saudável passa por tudo**

Actions → **demo-slo-pipeline → Run workflow** → `release = good` (1.0.0 → 1.1.0), `override` desmarcado.

Mostrar: o job `prepare` publica o release na branch `demo`; depois os jobs em sequência (lint e testes → build e artefato
versionado no S3 → **gate de SLO** → canário → promoção). Abra o *Summary* do job `slo-gate`: tabela com SLI, alvo e orçamento
restante, decisão **OK**. No dashboard, a `cell-a` aparece com a versão `1.1.0` primeiro e depois as outras. A ação `status`
confirma as 3 células em 1.1.0.
Falar: "Cada passo do Passo 2 virou um job. O 'decidir no olho' virou o gate. Zero SSH, zero chave de longa duração."

**4.2 Release ruim: o canário reprova e o rollback é automático**

Run workflow → `release = bad` (1.1.0 → 1.2.0, com regressão de 5% de erros).

Mostrar: o canário sobe só na `cell-a` (1/3 dos clientes); o job `deploy-canary` espera ~2,5 min e mede o SLI da versão nova
(`canary_verify.py`): abaixo de 99% → **rollback automático** da `cell-a` e pipeline vermelho. No dashboard, as barras da
`1.2.0` somem e a `cell-a` volta à `1.1.0`. As células `b` e `c` nunca foram tocadas.
Falar: "O raio da explosão ficou em uma célula e por poucos minutos. E o erro consumiu um pedaço do orçamento: o custo da falha."

**4.3 Incidente real: o orçamento acaba e o pipeline bloqueia**

1. `demo-ops` → `inject-fault` com `cell-b`, `error`, `30` (incidente em produção).
2. Aguarde 2 a 4 min e rode `check-budget` até o orçamento ficar negativo (ou veja a página de SLOs do Datadog).
3. Run workflow do pipeline → `release = fix` (1.2.0 → 1.2.1, remove a regressão).

Mostrar: o monitor de burn rate dispara e o SLO fica vermelho. O pipeline para no job `slo-gate` (vermelho):
"Deploy bloqueado: o orçamento de erro acabou". Nenhum job de deploy roda. A tabela do *Summary* mostra o orçamento negativo.
Falar: "Essa é a consequência da política: sem orçamento, sem lançamento. Quem decide isso é o pipeline, não o humor do dia."

**4.4 A exceção: a correção é justamente o que precisamos publicar**

Run workflow do pipeline → `release = none`, **`override` marcado**, `reason = hotfix 1.2.1 remove regressao e corrige incidente na cell-b`.

Mostrar: o job `override-approval` fica **esperando aprovação** (na execução: *Review deployments*). Aprove com a segunda
pessoa. Depois o canário roda na `cell-a`, passa, e a promoção sobe `cell-b` e `cell-c`. O deploy reinicia a `cell-b` e **encerra
o incidente injetado**. Confirme com `status`: `success_pct` normal.
Falar: "A exceção existe, mas deixa rastro: motivo, aprovador e o log. Entra no post-mortem. Sem fingir que a regra não existe."

Ao final, `demo-ops` → `clear-faults` para garantir que não restou falha.

**Fechamento:** compare com o Passo 2: os 12 passos manuais viraram um pipeline; o SLO virou o critério de decisão.

> Variação sem o botão: edite `demo-slo-pipeline/app/config.json` na branch `demo` pela interface do GitHub e faça o commit;
> o workflow dispara sozinho por *push*.

---

# Parte C – Resetar e repetir

Actions → **demo-ops → Run workflow → `reset`**. Roda na nuvem, sem confirmação, na ordem M5 → M4 → M3 → M2:

| Módulo | Ação |
|---|---|
| M5 | Redefine a branch `demo` a partir da `main` (**force push só na `demo`**) e volta as 3 células à versão base |
| M4 | Apaga o dashboard e limpa qualquer falha injetada |
| M3 | Restaura `toil-steps.csv` e o clone da EC2 (que o release manual altera) |
| M2 | Apaga SLOs e monitores e **inicia um novo `demo_run`**: o loadgen passa a etiquetar as métricas com o novo run, então o orçamento volta a 100% |

Para recomeçar a aula, volte ao **Passo 1**: os SLOs e o dashboard são recriados ao vivo.

## Derrubar tudo ao final do curso

**Opção A (com `.env`):** `./scripts/teardown.sh` (pede confirmação). Remove do Datadog os SLOs, monitores e o dashboard
e apaga o stack.

**Opção B (console):**
1. Actions → **demo-ops → Run workflow → `reset`**: remove do Datadog os SLOs, monitores e o dashboard (o CloudFormation não os conhece).
2. Console AWS → **CloudFormation → `sre-demo` → Delete**.

Nos dois casos o próprio stack esvazia o bucket de artefatos e apaga os parâmetros do SSM (inclusive as suas chaves do Datadog).
**Faça isso ao terminar o curso** para não deixar custo. (A branch `demo` e a variável `AWS_ROLE_ARN` do GitHub permanecem; apague-as se quiser.)

---

# Problemas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `inject-fault`, `clear-faults` ou `reset` falham com `curl: (22) ... error: 500` (ou `HTTP 500` do `fault.sh`) | A imagem das células na EC2 é antiga: o código do app mudou na `main`, mas a EC2 só constrói a imagem base uma vez | Publique a correção na `main` e rode a ação **`rebuild-base`** do `demo-ops` (reconstrói a imagem e recria as 3 células); depois rode `reset` |
| `check-datadog` falha com HTTP 403 | A chave de aplicação não tem permissão de SLO, ou o plano não inclui SLOs | Gere a chave com um usuário administrador; confira o plano em *Plan & Usage*; corrija atualizando o stack com as chaves novas |
| Stack falha em `InitSecrets` | A Lambda não conseguiu gravar no SSM | Veja a mensagem em **Events** e o log da função no CloudWatch |
| Stack falha em `DemoInstance` (timeout/sinal) | O bootstrap da EC2 falhou (rede, GitHub ou memória) | Recrie com *Preserve successfully provisioned resources* e leia `/var/log/demo-setup.log` |
| Stack falha com `EntityAlreadyExists` no provider OIDC | A conta já tem o provider do GitHub | Preencha `GitHubOidcProviderArn` com o ARN existente |
| `Could not assume role with OIDC: The web identity token provided could not be validated` | O provider OIDC não existe mais na conta (uma atualização do stack com `GitHubOidcProviderArn` preenchido o apagou) | `aws iam list-open-id-connect-providers` deve listar `token.actions.githubusercontent.com`. Se vier vazio, atualize o stack com `GitHubOidcProviderArn` **vazio** (o `deploy.sh` atual já faz isso) |
| `Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity` com a role e o repositório certos | O GitHub emite o `sub` com IDs imutáveis (`repo:owner@ID/repo@ID:ref:...`) e a confiança da role esperava o formato sem IDs | Use o template atual (aceita os dois formatos) e atualize o stack. Para ver o `sub` real: CloudTrail → *Event history* → evento `AssumeRoleWithWebIdentity` → campo `userName` |
| Ação do `demo-ops` falha em "Credenciais" | A variável `AWS_ROLE_ARN` não existe ou a role não confia neste repositório | Confira o valor da variável (A4) e o parâmetro `GitHubRepo` do stack |
| `prepare` falha em `checkout ref: demo` | A branch `demo` não existe | Rode a ação `reset` do `demo-ops` (cria a branch) |
| Métricas não chegam ao Datadog | `DD_SITE` errado, ou Agent sem memória | Session Manager na EC2: `docker logs datadog-agent 2>&1 \| tail -30`; confira o site; use `t3.small` |
| O SLO fica "No Data" | Passaram menos de 2 min, ou o `demo_run` do SLO difere do da carga | Espere; compare a ação `status` (DEMO_RUN) com a tag `demo_run` em `sre.requests.total` |
| `deploy-canary` diz "imagem não existe" | O artefato não foi baixado do S3 | Veja o log do `build` (upload) e o conteúdo do bucket `artifacts/cell-app/` no console do S3 |
| Canário "amostras insuficientes" | Datadog atrasou as métricas | O script tenta 3 vezes; se persistir, aumente `CANARY_SECONDS` no workflow |
| O job `override-approval` não pede aprovação | O environment `slo-override` não tem revisor | Configure *Required reviewers* (A4) |

---

# Limites desta entrega (leia antes do ensaio)

O que foi **verificado** antes de entregar: sintaxe de todos os scripts (`bash -n` e `shellcheck`), 16 testes unitários
(gate de SLO, verificação do canário, app, calculadoras), `cfn-lint` do template, `docker compose config`, YAML dos workflows
e da ação composta, e a existência das versões fixadas dos pacotes.

O que **só o seu ensaio confirma** (não havia Docker rodando, sessão AWS ativa nem credenciais Datadog no ambiente em que isto foi escrito):

- Build das imagens e o bootstrap da EC2 (`ddtrace==2.14.4`, Docker Compose e buildx no Amazon Linux 2023).
- O `deploy.sh` e o `teardown.sh` (validados só com `shellcheck` e com o caso de `.env` ausente; nunca rodaram contra uma conta real).
- A criação do stack: a Lambda `InitFunction` (testada com `boto3` simulado, mas nunca com o CloudFormation real) e o sinal
  `cfn-signal` da instância (assume o pacote `aws-cfn-bootstrap` disponível no Amazon Linux 2023).
- Os payloads da API do Datadog em `create-slos.sh`, `create-dashboard.sh` e em `slo_gate.py` (campo `sli_value` do histórico
  e sintaxe das queries dos monitores `error_budget(...)` e `burn_rate(...)`). Se a API rejeitar algum campo, a mensagem de erro
  do Datadog aparece no log; o ajuste costuma ser de uma linha.
- A execução ponta a ponta do GitHub Actions: OIDC, SSM, o `push` do `prepare`/`reset` com o token do workflow
  e o environment `slo-override`.
- Se o seu plano do Datadog inclui SLOs e logs (a ação `check-datadog` testa o acesso a SLOs).
