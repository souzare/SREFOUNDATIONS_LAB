#!/usr/bin/env bash
# Reseta o M5: a branch demo volta ao estado da main e as 3 células voltam à versão base.
# Só a branch 'demo' sofre force push. Roda no GitHub Actions (ação reset do workflow demo-ops),
# que tem o token com permissão de escrita; na CloudShell o push não tem credenciais.
set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"
need git jq
cd "$DEMO_ROOT/.."

git fetch origin main -q
commit="$(git -c user.name=demo-reset -c user.email=demo-reset@users.noreply.github.com \
  commit-tree 'FETCH_HEAD^{tree}' -p FETCH_HEAD -m 'reset demo')"
git push --force -q origin "$commit:refs/heads/demo"
echo "branch demo redefinida a partir da main"

[[ "${SKIP_REMOTE:-0}" == "1" ]] && exit 0
base="$(git show FETCH_HEAD:demo-slo-pipeline/app/config.json | jq -r .version)"
"$DEMO_ROOT/scripts/remote.sh" "cd /opt/lab/demo-slo-pipeline && instance/release.sh all $base"
echo "celulas na versao base $base"
