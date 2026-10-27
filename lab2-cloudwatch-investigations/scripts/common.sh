#!/usr/bin/env bash
# Funcoes comuns (usar com: source "$(dirname "$0")/common.sh")
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
STACK="${STACK_NAME:-sre-lab2-investigations}"
# Le um output da stack CloudFormation: cfout ApiUrl
cfout() {
  aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
