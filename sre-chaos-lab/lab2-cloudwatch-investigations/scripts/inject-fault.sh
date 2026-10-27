#!/usr/bin/env bash
# Uso: ./scripts/inject-fault.sh bad-config | iam-deny
# NAO revele o tipo de falha aos alunos antes da investigacao.
source "$(dirname "$0")/common.sh"

FUNC="$(cfout FunctionName)"
TABLE="$(cfout TableName)"
ROLE="$(cfout LambdaRoleName)"

case "${1:-}" in
  bad-config)
    # Mudanca de configuracao (deploy ruim): aponta o Lambda para uma tabela que nao existe
    aws lambda update-function-configuration --region "$REGION" --function-name "$FUNC" \
      --environment "Variables={TABLE_NAME=${TABLE}-v2}" >/dev/null
    aws lambda wait function-updated --region "$REGION" --function-name "$FUNC"
    echo "Falha injetada (bad-config). Gere carga: ./scripts/load.sh 120"
    ;;
  iam-deny)
    # Mudanca de permissao: nega dynamodb:PutItem para a role do Lambda
    aws iam put-role-policy --role-name "$ROLE" --policy-name chaos-deny-ddb \
      --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Deny","Action":"dynamodb:PutItem","Resource":"*"}]}'
    echo "Falha injetada (iam-deny). Gere carga: ./scripts/load.sh 120 (pode levar ~1 min para propagar)"
    ;;
  *)
    echo "Uso: $0 bad-config | iam-deny" >&2
    exit 1
    ;;
esac
