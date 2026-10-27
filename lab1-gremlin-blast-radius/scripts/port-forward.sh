#!/usr/bin/env bash
# Uso: ./scripts/port-forward.sh [porta]   (padrao 8081 = dashboard; 8080 = app via router)
# Requer o plugin Session Manager da AWS CLI instalado.
set -euo pipefail
PORT="${1:-8081}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
STACK="${STACK_NAME:-sre-lab1-gremlin}"
IID=$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" --output text)
echo "Abrindo http://localhost:$PORT (Ctrl+C para encerrar)"
aws ssm start-session --region "$REGION" --target "$IID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"$PORT\"],\"localPortNumber\":[\"$PORT\"]}"
