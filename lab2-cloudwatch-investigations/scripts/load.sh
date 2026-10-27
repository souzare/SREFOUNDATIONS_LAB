#!/usr/bin/env bash
# Uso: ./scripts/load.sh [segundos]   (padrao 60) - gera trafego (POST /orders) e mostra contagem por status HTTP
source "$(dirname "$0")/common.sh"
DURATION="${1:-60}"
API="$(cfout ApiUrl)"
codes=""   # compativel com bash 3.2 (macOS): sem arrays associativos
end=$((SECONDS + DURATION))
echo "Enviando carga para $API/orders por ${DURATION}s..."
while [ $SECONDS -lt $end ]; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/orders" \
    -H 'content-type: application/json' -d '{"item":"widget"}')
  codes="$codes$code"$'\n'
  line=$(printf '%s' "$codes" | sort | uniq -c | awk '{printf "%s=%s  ", $2, $1}')
  printf '\r%s' "$line"
  sleep 0.5
done
echo
