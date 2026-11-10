#!/usr/bin/env bash
# Executa um comando NA EC2 via SSM e imprime a saída. Sai com erro se o comando falhar.
# Uso: scripts/remote.sh '<comando>'
# Usa INSTANCE_ID do ambiente (GitHub Actions) ou lê /sre-demo/instance_id no SSM.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
need aws jq

cmd="${1:?uso: remote.sh '<comando>'}"
iid="${INSTANCE_ID:-$(ssm_get /sre-demo/instance_id)}"
[[ -n "$iid" && "$iid" != "None" ]] || die "instancia nao encontrada em /sre-demo/instance_id (o stack existe?)"

cid=$(aws ssm send-command --instance-ids "$iid" --document-name AWS-RunShellScript \
  --timeout-seconds 900 --parameters "$(jq -n --arg c "$cmd" '{commands: [$c]}')" \
  --query Command.CommandId --output text)

status=Pending
while [[ "$status" == "Pending" || "$status" == "InProgress" || "$status" == "Delayed" ]]; do
  sleep 3
  status=$(aws ssm get-command-invocation --command-id "$cid" --instance-id "$iid" \
    --query Status --output text 2>/dev/null || echo Pending)
done

aws ssm get-command-invocation --command-id "$cid" --instance-id "$iid" \
  --query StandardOutputContent --output text
if [[ "$status" != "Success" ]]; then
  echo "--- stderr ---" >&2
  aws ssm get-command-invocation --command-id "$cid" --instance-id "$iid" \
    --query StandardErrorContent --output text >&2
  die "comando remoto terminou com status $status"
fi
