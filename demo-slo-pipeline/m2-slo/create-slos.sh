#!/usr/bin/env bash
# Cria os SLOs (como código) e os monitores de error budget / burn rate no Datadog.
# Idempotente: se já existem para o run atual, só mostra. O estado fica no SSM (/sre-demo/state/slos).
#
# SLOs (janela 7d), calculados sobre as métricas que o loadgen emite:
#   disponibilidade  = sre.requests.good / sre.requests.total   alvo 99%
#   latência         = sre.requests.fast / sre.requests.good    alvo 95% (resposta < 300 ms)
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
need aws curl jq
need_dd

RUN="$(demo_run)"
[[ -n "$RUN" ]] || die "sem /sre-demo/demo_run: o stack do CloudFormation o cria"
existing="$(state_get slos)"
if [[ -n "$existing" ]]; then echo "SLOs já criados para $RUN:"; echo "$existing" | jq .; exit 0; fi

create_slo() {  # nome descricao numerador denominador alvo aviso
  local body
  body=$(jq -n --arg name "$1" --arg desc "$2" --arg num "$3" --arg den "$4" \
    --argjson target "$5" --argjson warning "$6" '{
      name: $name, description: $desc, type: "metric", tags: ["demo:sre-foundation"],
      query: {numerator: $num, denominator: $den},
      thresholds: [{timeframe: "7d", target: $target, warning: $warning}]}')
  dd_api POST /api/v1/slo "$body" | jq -r '.data[0].id'
}

create_monitor() {  # nome query mensagem limite
  local body
  body=$(jq -n --arg name "$1" --arg query "$2" --arg msg "$3" --argjson crit "$4" '{
      name: $name, type: "slo alert", query: $query, message: $msg,
      tags: ["demo:sre-foundation"], options: {thresholds: {critical: $crit}}}')
  dd_api POST /api/v1/monitor "$body" | jq -r '.id'
}

echo "Criando SLO de disponibilidade (99% em 7d)..."
AVAIL=$(create_slo "SRE Demo - Disponibilidade ($RUN)" \
  "Requisicoes com resposta 200 / total de requisicoes" \
  "sum:sre.requests.good{demo_run:$RUN}.as_count()" \
  "sum:sre.requests.total{demo_run:$RUN}.as_count()" 99.0 99.5)

echo "Criando SLO de latência (95% abaixo de 300 ms em 7d)..."
LAT=$(create_slo "SRE Demo - Latencia ($RUN)" \
  "Respostas 200 abaixo de 300 ms / respostas 200" \
  "sum:sre.requests.fast{demo_run:$RUN}.as_count()" \
  "sum:sre.requests.good{demo_run:$RUN}.as_count()" 95.0 97.0)

echo "Criando monitores (política de error budget)..."
M1=$(create_monitor "SRE Demo - Error budget da disponibilidade acima de 75% ($RUN)" \
  "error_budget(\"$AVAIL\").over(\"7d\") > 75" \
  "Mais de 75% do error budget de disponibilidade foi consumido. Politica: so mudancas pequenas com canario." 75)
M2=$(create_monitor "SRE Demo - Burn rate da disponibilidade ($RUN)" \
  "burn_rate(\"$AVAIL\").over(\"7d\").long_window(\"1h\").short_window(\"5m\") > 14.4" \
  "O orcamento esta sendo consumido 14x mais rapido que o sustentavel. Politica: congelar deploys." 14.4)

state="$(jq -nc --arg run "$RUN" --arg a "$AVAIL" --arg l "$LAT" --arg m1 "$M1" --arg m2 "$M2" \
  '{run: $run, availability_slo: $a, latency_slo: $l, monitors: [$m1, $m2]}')"
state_put slos "$state"   # o gate do pipeline lê os ids daqui

echo
echo "$state" | jq .
echo "Veja no Datadog: $(dd_app_url)/slo/manage"
