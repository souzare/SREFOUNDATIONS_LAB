#!/usr/bin/env bash
# Mostra o estado da demo na EC2: containers, versões por célula, run atual e estatísticas da carga.
set -euo pipefail
"$(dirname "$0")/remote.sh" 'cd /opt/lab/demo-slo-pipeline
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo
grep -E "^(DEMO_RUN|CELL_._VERSION)=" .env
echo
curl -s http://127.0.0.1:8081/api/stats
echo'
