#!/usr/bin/env bash
# Cria no Datadog o dashboard da demo (SLOs, SLIs por célula, versão em produção e logs de erro).
# Requer os SLOs do M2 (m2-slo/create-slos.sh). O estado fica no SSM (/sre-demo/state/dashboard).
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
need aws curl jq sed
need_dd

existing="$(state_get dashboard)"
if [[ -n "$existing" ]]; then echo "Dashboard já criado:"; echo "$existing" | jq .; exit 0; fi

RUN="$(demo_run)"
slos="$(state_get slos)"
[[ -n "$slos" ]] || die "crie os SLOs antes: ação create-slos (m2-slo/create-slos.sh)"

body=$(sed -e "s/__RUN__/$RUN/g" \
  -e "s/__SLO_AVAIL__/$(echo "$slos" | jq -r .availability_slo)/g" \
  -e "s/__SLO_LAT__/$(echo "$slos" | jq -r .latency_slo)/g" "$(dirname "$0")/dashboard.json")

resp=$(dd_api POST /api/v1/dashboard "$body")
info="$(echo "$resp" | jq -c '{id, url}')"
state_put dashboard "$info"
echo "$info" | jq .
echo "Abra: $(dd_app_url)$(echo "$resp" | jq -r .url)"
