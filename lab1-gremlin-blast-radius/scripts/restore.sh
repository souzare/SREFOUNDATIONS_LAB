#!/usr/bin/env bash
# Volta o Lab 1 ao normal: sobe de novo qualquer container parado (cells, router, loadgen, agente).
# Containers em execucao nao sao recriados. Funciona apos Shutdown/Kill de container ou reboot do host.
set -euo pipefail
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
STACK="${STACK_NAME:-sre-lab1-gremlin}"
IID=$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" --output text)

CID=$(aws ssm send-command --region "$REGION" --instance-ids "$IID" \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["cd /opt/lab/lab1-gremlin-blast-radius","docker compose --env-file .env -f docker-compose.yml -f docker-compose.gremlin.yml up -d 2>&1 | tail -15","docker ps -a --format \"{{.Names}}\t{{.Status}}\""]' \
  --query Command.CommandId --output text)

while true; do
  STATUS=$(aws ssm get-command-invocation --region "$REGION" --command-id "$CID" --instance-id "$IID" \
    --query Status --output text 2>/dev/null || echo Pending)
  [[ "$STATUS" == "InProgress" || "$STATUS" == "Pending" ]] || break
  sleep 3
done

aws ssm get-command-invocation --region "$REGION" --command-id "$CID" --instance-id "$IID" \
  --query StandardOutputContent --output text
[[ "$STATUS" == "Success" ]] || { echo "Falhou: $STATUS" >&2; exit 1; }
echo "Ambiente restaurado."
