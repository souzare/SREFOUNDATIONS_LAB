#!/usr/bin/env bash
# Sobe a EC2 do Lab 1 via CloudFormation.
# Uso:
#   export GREMLIN_TEAM_ID=... GREMLIN_TEAM_SECRET=... REPO_URL=https://github.com/SEU_USUARIO/sre-chaos-lab.git
#   ./scripts/deploy.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
STACK="${STACK_NAME:-sre-lab1-gremlin}"

: "${GREMLIN_TEAM_ID:?defina GREMLIN_TEAM_ID}"
: "${GREMLIN_TEAM_SECRET:?defina GREMLIN_TEAM_SECRET}"
: "${REPO_URL:?defina REPO_URL (repositorio publico com este lab)}"
BRANCH="${REPO_BRANCH:-main}"

# CloudFormation nao cria SecureString: criamos antes, a instancia le no boot.
aws ssm put-parameter --region "$REGION" --overwrite --type SecureString \
  --name /sre-lab/gremlin/team_id --value "$GREMLIN_TEAM_ID" >/dev/null
aws ssm put-parameter --region "$REGION" --overwrite --type SecureString \
  --name /sre-lab/gremlin/team_secret --value "$GREMLIN_TEAM_SECRET" >/dev/null

# Stack que falhou antes fica em ROLLBACK_COMPLETE e nao pode ser atualizada: remove e recria.
STATUS=$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
  --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo NONE)
if [[ "$STATUS" == "ROLLBACK_COMPLETE" || "$STATUS" == "CREATE_FAILED" ]]; then
  echo "Stack anterior em $STATUS: removendo antes de recriar..."
  aws cloudformation delete-stack --region "$REGION" --stack-name "$STACK"
  aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$STACK"
fi

aws cloudformation deploy --region "$REGION" --stack-name "$STACK" \
  --template-file "$ROOT/cloudformation/lab1.yaml" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides RepoUrl="$REPO_URL" RepoBranch="$BRANCH"

IID=$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue" --output text)
echo
echo "Instancia: $IID"
echo "O bootstrap leva ~3-5 min. Acompanhe: aws ssm start-session --region $REGION --target $IID  (tail -f /var/log/lab-setup.log)"
echo "Dashboard: ./scripts/port-forward.sh 8081  ->  http://localhost:8081"
