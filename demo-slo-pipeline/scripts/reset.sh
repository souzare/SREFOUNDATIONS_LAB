#!/usr/bin/env bash
# Reseta a demo inteira para a próxima rodada: chama o reset.sh de cada módulo, do M5 para o M2.
# O QUE FAZ (pede confirmação): redefine a branch 'demo' do GitHub (force push só nela), volta as
# células à versão base, remove dashboard, SLOs e monitores do Datadog e inicia um novo run de métricas.
# Uso: scripts/reset.sh [-y|--yes]      (-h mostra esta ajuda)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-}" in
  -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
  -y|--yes) ;;
  *)
    sed -n '3,5p' "$0"
    read -r -p "Continuar? [s/N] " answer
    [[ "$answer" == "s" || "$answer" == "S" ]] || { echo "cancelado"; exit 1; }
    ;;
esac

status=0
for mod in m5-pipeline-slo-gate m4-observabilidade m3-toil m2-slo; do
  if [[ -x "$ROOT/$mod/reset.sh" ]]; then
    echo "==> reset $mod"
    "$ROOT/$mod/reset.sh" || { echo "!! falhou: $mod" >&2; status=1; }
  else
    echo "==> $mod: sem reset"
  fi
done
[[ $status -eq 0 ]] && echo "Demo resetada." || echo "Reset terminou com erros." >&2
exit $status
