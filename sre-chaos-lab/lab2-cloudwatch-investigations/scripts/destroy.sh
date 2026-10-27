#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

# Remove a policy de falha (criada fora do CloudFormation), senao o delete da role falha
aws iam delete-role-policy --role-name "$(cfout LambdaRoleName)" --policy-name chaos-deny-ddb 2>/dev/null || true

# Remove o investigation group (criado fora do CloudFormation)
for arn in $(aws aiops list-investigation-groups --region "$REGION" \
    --query 'investigationGroups[].arn' --output text 2>/dev/null || true); do
  echo "Removendo investigation group $arn"
  aws aiops delete-investigation-group --region "$REGION" --identifier "$arn" || true
done

aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK"
aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$STACK"
echo "Lab 2 removido."
