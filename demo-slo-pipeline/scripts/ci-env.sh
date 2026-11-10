#!/usr/bin/env bash
# Usado pela ação .github/actions/demo-env: carrega a configuração da demo do SSM para o ambiente do job.
# Uso: ci-env.sh <arquivo GITHUB_ENV>
set -euo pipefail
source "$(dirname "$0")/lib.sh"
need aws jq
out="${1:?uso: ci-env.sh <arquivo-de-env>}"
need_dd

echo "::add-mask::$DD_API_KEY"
echo "::add-mask::$DD_APP_KEY"
slos="$(state_get slos)"
{
  echo "DD_API_KEY=$DD_API_KEY"
  echo "DD_APP_KEY=$DD_APP_KEY"
  echo "DD_SITE=$DD_SITE"
  echo "DEMO_RUN=$(demo_run)"
  echo "INSTANCE_ID=$(ssm_get /sre-demo/instance_id)"
  echo "ARTIFACT_BUCKET=$(ssm_get /sre-demo/artifact_bucket)"
  if [[ -n "$slos" ]]; then
    echo "DD_SLO_IDS=$(echo "$slos" | jq -r '[.availability_slo, .latency_slo] | join(",")')"
  fi
} >> "$out"
