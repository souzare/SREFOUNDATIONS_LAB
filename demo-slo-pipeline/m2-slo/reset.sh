#!/usr/bin/env bash
# Reseta o M2: apaga SLOs e monitores e começa um NOVO run (tag demo_run) para o orçamento voltar a 100%.
# Com SKIP_REMOTE=1 só apaga os objetos do Datadog.
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
need aws curl jq
need_dd

state="$(state_get slos)"
if [[ -n "$state" ]]; then
  for id in $(echo "$state" | jq -r '.monitors[]'); do dd_api DELETE "/api/v1/monitor/$id" >/dev/null || true; done
  for id in $(echo "$state" | jq -r '.availability_slo, .latency_slo'); do dd_api DELETE "/api/v1/slo/$id" >/dev/null || true; done
  state_del slos
  echo "SLOs e monitores removidos"
else
  echo "nenhum SLO para remover"
fi

[[ "${SKIP_REMOTE:-0}" == "1" ]] && exit 0

RUN="run-$(date +%d%H%M%S)"
ssm_put /sre-demo/demo_run "$RUN"
"$DEMO_ROOT/scripts/remote.sh" "cd /opt/lab/demo-slo-pipeline && sed -i 's/^DEMO_RUN=.*/DEMO_RUN=$RUN/' .env && docker compose --env-file .env up -d --no-build --force-recreate loadgen" >/dev/null
echo "novo run: $RUN (a carga passa a ser medida do zero)"
