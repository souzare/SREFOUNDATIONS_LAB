#!/usr/bin/env bash
# Reseta o M4: apaga o dashboard e remove qualquer falha injetada.
# Com SKIP_REMOTE=1 não fala com a EC2.
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
need aws curl jq
need_dd

info="$(state_get dashboard)"
if [[ -n "$info" ]]; then
  dd_api DELETE "/api/v1/dashboard/$(echo "$info" | jq -r .id)" >/dev/null || true
  state_del dashboard
  echo "dashboard removido"
else
  echo "nenhum dashboard para remover"
fi

[[ "${SKIP_REMOTE:-0}" == "1" ]] && exit 0
"$DEMO_ROOT/scripts/inject-fault.sh" all clear >/dev/null
echo "falhas limpas nas 3 celulas"
