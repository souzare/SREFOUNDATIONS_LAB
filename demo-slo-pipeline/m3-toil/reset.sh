#!/usr/bin/env bash
# Reseta o M3: restaura o CSV de toil (se você editou os tempos) e o clone da EC2, que o release
# manual deixa com app/config.json alterado. As versões das células voltam no reset do M5.
# Com SKIP_REMOTE=1 não fala com a EC2.
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
cd "$DEMO_ROOT"
git checkout -- m3-toil/toil-steps.csv 2>/dev/null && echo "toil-steps.csv restaurado" || echo "toil-steps.csv sem alterações"
[[ "${SKIP_REMOTE:-0}" == "1" ]] && exit 0
"$DEMO_ROOT/scripts/remote.sh" "git -C /opt/lab checkout -- demo-slo-pipeline/app/config.json && echo 'clone da EC2 restaurado'"
