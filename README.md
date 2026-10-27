# SRE Foundation – Labs de Resiliência e Investigação

Dois laboratórios práticos que complementam o curso **SRE Foundation (DevOps Institute)**. Infraestrutura em **AWS CloudFormation**.

👉 **Instrutor: comece pelo [GUIA_DO_INSTRUTOR.md](GUIA_DO_INSTRUTOR.md)** (como rodar e o que falar em cada passo).

| Lab | Tema | Módulos do curso | Duração sugerida |
|-----|------|------------------|------------------|
| [Lab 1](lab1-gremlin-blast-radius/) | Chaos Engineering com **Gremlin** em containers: raio da explosão (*blast radius*) e testes célula a célula | M6 (Antifragilidade), M4 (Observabilidade/SLIs) | 60–90 min |
| [Lab 2](lab2-cloudwatch-investigations/) | Diagnóstico assistido por IA com **Amazon CloudWatch investigations** | M4 (Observabilidade), M7 (Resposta a incidentes / blameless) | 45–60 min |

## Estrutura

```
sre-chaos-lab/
├── GUIA_DO_INSTRUTOR.md              # roteiro de aula: comandos + falas
├── Makefile                          # atalhos (make help)
├── lab1-gremlin-blast-radius/
│   ├── app/                          # app da "célula" (Flask)
│   ├── router/nginx.conf             # roteia clientes -> células (hash consistente)
│   ├── loadgen/                      # gerador de carga + dashboard por célula (:8081)
│   ├── docker-compose.yml            # 3 células + router + loadgen
│   ├── docker-compose.gremlin.yml    # agente Gremlin (overlay)
│   ├── cloudformation/lab1.yaml      # EC2 free tier que sobe tudo sozinha (opcional)
│   ├── scripts/                      # deploy, port-forward, destroy
│   └── EXPERIMENTOS.md               # experimentos + folha de hipóteses
└── lab2-cloudwatch-investigations/
    ├── cloudformation/lab2.yaml      # API GW + Lambda + DynamoDB + alarme + role do Investigations
    ├── scripts/                      # deploy, load, inject-fault, restore, destroy
    ├── ROTEIRO_ALUNO.md
    └── NOTAS_INSTRUTOR.md            # gabarito (não distribuir aos alunos)
```

## Pré-requisitos

- Conta AWS de sandbox (free tier/créditos) com **VPC default** na região e AWS CLI v2 atualizado (`aws aiops help` deve existir)
- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) (Lab 1 na AWS)
- `curl`, `bash`; Docker + Compose v2 (Lab 1 local)
- Conta **Gremlin Free** – Team ID e Team Secret em *Company Settings → Teams → Configuration*

Região padrão dos scripts: `us-east-1` (mude com `export AWS_REGION=...`).

## Custos e limpeza

Dimensionado para free tier (EC2 t3.micro, Lambda, API Gateway HTTP, DynamoDB 5/5, 1 alarme, logs com retenção de 7 dias).
**Rode `make lab1-aws-destroy` e `make lab2-destroy` ao terminar** e confira preços/limites vigentes do CloudWatch investigations e do plano Gremlin.

## Segurança

- Nunca commite `.env`. Use conta de laboratório.
- As credenciais Gremlin ficam em SSM Parameter Store (SecureString), não no template.
