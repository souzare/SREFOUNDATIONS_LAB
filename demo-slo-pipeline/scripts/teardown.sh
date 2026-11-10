#!/usr/bin/env bash
# Derruba tudo: remove SLOs/monitores/dashboard do Datadog e apaga o stack (a Lambda do stack
# esvazia o bucket e remove os parametros do SSM). Use ao terminar o curso para nao deixar custo.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
need aws curl jq

ENV_FILE="$DEMO_ROOT/.env"
# shellcheck source=/dev/null
if [[ -f "$ENV_FILE" ]]; then set -a; . "$ENV_FILE"; set +a; fi
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"

read -r -p "Apagar SLOs, dashboard e o stack '$STACK' na regiao $AWS_REGION? [s/N] " answer
[[ "$answer" == "s" || "$answer" == "S" ]] || { echo "cancelado"; exit 1; }

echo "Removendo SLOs, monitores e dashboard do Datadog..."
for mod in m4-observabilidade m2-slo; do
  SKIP_REMOTE=1 "$DEMO_ROOT/$mod/reset.sh" || echo "  (aviso: $mod/reset.sh falhou; confira o Datadog manualmente)"
done

echo "Removendo o stack $STACK..."
aws cloudformation delete-stack --stack-name "$STACK"
aws cloudformation wait stack-delete-complete --stack-name "$STACK"
echo "Demo removida. (A branch 'demo' e a variavel AWS_ROLE_ARN do GitHub permanecem; apague-as se quiser.)"
