#!/usr/bin/env bash
# Injeta ou limpa falhas no app em execução (usado no M4 e no M5).
# Uso: scripts/inject-fault.sh <cell-a|cell-b|cell-c|all> <error|latency|clear> [valor]
#   error 30      -> 30% das requisições da célula retornam 500
#   latency 800   -> 800 ms no span db.query
#   clear         -> remove as falhas
set -euo pipefail
[[ $# -ge 2 ]] || { sed -n '2,7p' "$0"; exit 2; }
"$(dirname "$0")/remote.sh" "cd /opt/lab/demo-slo-pipeline && instance/fault.sh $*"
