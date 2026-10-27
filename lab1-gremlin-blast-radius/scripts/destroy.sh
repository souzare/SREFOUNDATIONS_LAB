#!/usr/bin/env bash
set -euo pipefail
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
STACK="${STACK_NAME:-sre-lab1-gremlin}"
aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK"
aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$STACK"
aws ssm delete-parameter --region "$REGION" --name /sre-lab/gremlin/team_id 2>/dev/null || true
aws ssm delete-parameter --region "$REGION" --name /sre-lab/gremlin/team_secret 2>/dev/null || true
echo "Lab 1 removido."
