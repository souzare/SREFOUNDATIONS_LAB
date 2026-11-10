#!/usr/bin/env bash
# Roda NA EC2 (via SSM). Injeta ou limpa falhas no app em execução.
# Uso: fault.sh <cell-a|cell-b|cell-c|all> <error|latency|clear> [valor]
#   error   N   -> N% das requisições da célula retornam 500
#   latency N   -> N ms de latência no span db.query
#   clear       -> zera as duas falhas
set -euo pipefail
cell="${1:?cell}"; mode="${2:?error|latency|clear}"; value="${3:-0}"

case "$mode" in
  error)   body="{\"error_rate\": $value}" ;;
  latency) body="{\"db_latency_ms\": $value}" ;;
  clear)   body='{"error_rate": 0, "db_latency_ms": 0}' ;;
  *) echo "modo invalido: $mode" >&2; exit 2 ;;
esac

if [[ "$cell" == "all" ]]; then cells="a b c"; else cells="${cell#cell-}"; fi
for letter in $cells; do
  port=$((8000 + $(printf '%d' "'$letter") - 96))
  printf 'cell-%s: ' "$letter"
  resp="$(curl -sS -w '\n%{http_code}' -X POST "http://127.0.0.1:$port/admin/fault" \
    -H 'Content-Type: application/json' -d "$body")"
  code="${resp##*$'\n'}"
  echo "${resp%$'\n'*}"
  if [[ "$code" != 2* ]]; then
    echo "cell-$letter: HTTP $code (a imagem da celula pode estar desatualizada: rode a acao rebuild-base)" >&2
    exit 1
  fi
done
