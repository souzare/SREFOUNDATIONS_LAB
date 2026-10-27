# Notas do instrutor (NÃO distribuir)

## Gabarito

### Falha `bad-config`
- **Causa raiz:** `UpdateFunctionConfiguration` alterou `TABLE_NAME` do Lambda para `<tabela>-v2`, que não existe.
- **Sintomas:** métrica `Errors` do Lambda sobe; API GW devolve 500; logs com `order_failed` e `ResourceNotFoundException`.
- **Evidência de mudança:** evento CloudTrail `UpdateFunctionConfiguration` poucos minutos antes do primeiro erro.
- **Correção:** reverter a variável de ambiente (`./scripts/restore.sh`).

### Falha `iam-deny`
- **Causa raiz:** `PutRolePolicy` (`chaos-deny-ddb`) negando `dynamodb:PutItem` à role do Lambda.
- **Sintomas:** `AccessDeniedException` nos logs; só POST falha (GET continua funcionando).
- **Evidência de mudança:** evento CloudTrail `PutRolePolicy`.
- **Correção:** remover a policy.

## O que observar na IA
- Ela encontrou a mudança de configuração/permissão no CloudTrail?
- Correlacionou o horário da mudança com o início dos erros?
- Citou os logs corretos? Sugeriu a remediação certa?
- Houve hipóteses irrelevantes? (ótimo ponto para discutir **validação humana**).

## Pontos de ensino (conectar ao curso)
- M4: observabilidade = poder inferir o estado interno a partir das saídas (logs, métricas, traces).
- M6: MTTD e MTTR; mudanças são a causa mais comum de incidentes.
- M7: investigação *blameless* — a mudança foi feita por um humano, mas o foco é o processo (por que a config errada chegou à produção sem validação?).
- IA como **multiplicador de força**, não panaceia (M5).

## Dicas práticas
- Rode `./scripts/load.sh 60` antes da aula para aquecer métricas/traces.
- Execute a injeção ~5 min antes de iniciar a investigação na frente da turma, ou faça ao vivo e use o tempo de espera para a Parte 1 (humanos).
- Plano B: salve prints de uma investigação anterior.
- Lembre de rodar `./scripts/destroy.sh` ao final.
