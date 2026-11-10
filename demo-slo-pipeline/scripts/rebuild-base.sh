#!/usr/bin/env bash
# Reconstrói na EC2 a imagem base (a versão do app/config.json da main) e recria as 3 células com ela.
# Necessário quando o código do app muda na main: o bootstrap só constrói a imagem base uma vez.
# Depois, use a ação reset para voltar todo o resto ao estado inicial.
set -euo pipefail
"$(dirname "$0")/remote.sh" 'set -e
cd /opt/lab
git checkout -- demo-slo-pipeline/app/config.json 2>/dev/null || true   # o release manual do M3 altera este arquivo
git pull --ff-only -q
cd demo-slo-pipeline
v="$(jq -r .version app/config.json)"
echo "reconstruindo sre-demo/cell-app:$v a partir de $(git -C /opt/lab log --oneline -1)"
docker build -q -t "sre-demo/cell-app:$v" app/ >/dev/null
for c in cell-a cell-b cell-c; do
  docker compose --env-file .env up -d --no-build --no-deps --force-recreate "$c"
done
sleep 5
curl -fsS http://127.0.0.1:8001/admin/fault && echo "  <- /admin/fault responde 200 na cell-a"'
