#!/usr/bin/env bash
# Mostra o orçamento de erro atual (a mesma checagem do gate do pipeline, mas só informativa).
set -euo pipefail
source "$(dirname "$0")/lib.sh"
need aws jq python3
need_dd

slos="$(state_get slos)"
[[ -n "$slos" ]] || die "SLOs ainda nao criados (acao create-slos)"
ids="$(echo "$slos" | jq -r '[.availability_slo, .latency_slo] | join(",")')"
# código 2 = bloqueado: para esta checagem informativa isso não é erro
DD_SLO_IDS="$ids" python3 "$DEMO_ROOT/m5-pipeline-slo-gate/slo_gate.py" || [ $? -eq 2 ]
