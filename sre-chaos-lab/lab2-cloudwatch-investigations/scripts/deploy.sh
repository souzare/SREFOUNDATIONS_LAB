#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"

aws cloudformation deploy --region "$REGION" --stack-name "$STACK" \
  --template-file "$ROOT/cloudformation/lab2.yaml" \
  --capabilities CAPABILITY_NAMED_IAM

echo "Aguardando propagacao da role IAM..."
sleep 15
"$ROOT/scripts/setup-investigation-group.sh"

echo
echo "Pronto! API: $(cfout ApiUrl)"
echo "Proximo passo: ./scripts/load.sh 60   (baseline)"
