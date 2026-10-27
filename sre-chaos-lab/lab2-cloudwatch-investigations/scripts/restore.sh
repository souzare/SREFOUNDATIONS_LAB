#!/usr/bin/env bash
# Desfaz qualquer falha injetada.
source "$(dirname "$0")/common.sh"

FUNC="$(cfout FunctionName)"
TABLE="$(cfout TableName)"
ROLE="$(cfout LambdaRoleName)"

aws lambda update-function-configuration --region "$REGION" --function-name "$FUNC" \
  --environment "Variables={TABLE_NAME=${TABLE}}" >/dev/null
aws lambda wait function-updated --region "$REGION" --function-name "$FUNC"
aws iam delete-role-policy --role-name "$ROLE" --policy-name chaos-deny-ddb 2>/dev/null || true
echo "Ambiente restaurado."
