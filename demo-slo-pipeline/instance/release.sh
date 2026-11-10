#!/usr/bin/env bash
# Roda NA EC2 (via SSM). Troca a versão de uma célula (ou de todas).
# Uso: release.sh <cell-a|cell-b|cell-c|all> <versao|previous> [chave-s3]
#   chave-s3: artefato gerado pelo pipeline (docker save | gzip) a carregar antes do deploy.
#   previous: volta para a versão que a célula tinha antes do último release (rollback).
set -euo pipefail
cd "$(dirname "$0")/.."
cell="${1:?cell}"; version="${2:?versao}"; key="${3:-}"

set -a; . ./.env; set +a

if [[ -n "$key" ]]; then
  echo "carregando artefato s3://$ARTIFACT_BUCKET/$key"
  aws s3 cp "s3://$ARTIFACT_BUCKET/$key" - --region "$AWS_REGION" | gunzip | docker load
fi

if [[ "$cell" == "all" ]]; then cells="cell-a cell-b cell-c"; else cells="$cell"; fi

for c in $cells; do
  letter="${c#cell-}"
  var="CELL_$(echo "$letter" | tr a-z A-Z)_VERSION"
  port=$((8000 + $(printf '%d' "'$letter") - 96))     # a->8001 b->8002 c->8003
  v="$version"
  if [[ "$v" == "previous" ]]; then v="$(cat ".state-prev-$c")"; fi
  docker image inspect "sre-demo/cell-app:$v" >/dev/null 2>&1 || { echo "imagem sre-demo/cell-app:$v nao existe" >&2; exit 1; }

  current="$(grep "^$var=" .env | cut -d= -f2)"
  [[ "$current" != "$v" ]] && echo "$current" > ".state-prev-$c"
  sed -i "s/^$var=.*/$var=$v/" .env
  echo "$c: $current -> $v"
  docker compose --env-file .env up -d --no-build --no-deps "$c"

  for i in $(seq 1 40); do
    if curl -fsS "http://127.0.0.1:$port/health" >/dev/null 2>&1; then echo "$c saudavel (v$v)"; break; fi
    [[ $i -eq 40 ]] && { echo "$c nao ficou saudavel" >&2; exit 1; }
    sleep 2
  done
done
