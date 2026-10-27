#!/usr/bin/env bash
# Cria o investigation group (setup unico por regiao) do CloudWatch investigations.
# Requer AWS CLI v2 recente (comando `aws aiops`) e permissoes AIOpsConsoleAdminPolicy/Admin.
# Se falhar, faca o setup uma vez pelo console: CloudWatch > Investigations > configurar.
source "$(dirname "$0")/common.sh"

ROLE_ARN="$(cfout InvestigationsRoleArn)"

EXISTING="$(aws aiops list-investigation-groups --region "$REGION" \
  --query 'investigationGroups[0].arn' --output text 2>/dev/null || echo None)"

if [[ "$EXISTING" != "None" && -n "$EXISTING" ]]; then
  echo "Investigation group ja existe: $EXISTING"
  exit 0
fi

aws aiops create-investigation-group \
  --region "$REGION" \
  --name "sre-lab" \
  --role-arn "$ROLE_ARN" \
  --retention-in-days 30
echo "Investigation group criado."
