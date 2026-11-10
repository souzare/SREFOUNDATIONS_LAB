#!/usr/bin/env bash
# Sobe o ambiente: valida tudo e cria o stack CloudFormation lendo as chaves do .env local.
# Idempotente (rodar de novo atualiza o stack). Requer o AWS CLI com sessão ativa.
#   cp .env.example .env   # preencha DD_API_KEY, DD_APP_KEY e DD_SITE (o .env é ignorado pelo git)
#   ./scripts/deploy.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"
need aws curl jq git

ENV_FILE="$DEMO_ROOT/.env"
[[ -f "$ENV_FILE" ]] || die ".env nao encontrado: copie .env.example para .env e preencha"
git -C "$DEMO_ROOT" check-ignore -q "$ENV_FILE" || die ".env NAO esta no .gitignore: abortando para nao arriscar vazar as chaves"
chmod 600 "$ENV_FILE"
set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a
: "${DD_API_KEY:?preencha DD_API_KEY no .env}"
: "${DD_APP_KEY:?preencha DD_APP_KEY no .env}"
export DD_SITE="${DD_SITE:-datadoghq.com}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"

echo "[1/5] Validando credenciais..."
aws sts get-caller-identity --query Account --output text >/dev/null || die "AWS sem sessao ativa (aws login / aws sso login)"
dd_api GET /api/v1/validate >/dev/null || die "DD_API_KEY invalida para o site $DD_SITE"
dd_api GET "/api/v1/slo?limit=1" >/dev/null || die "DD_APP_KEY sem acesso a SLOs (permissao ou plano)"
echo "      AWS (regiao $AWS_REGION) e Datadog (site $DD_SITE) OK"

echo "[2/5] Conferindo o repositorio no GitHub..."
REPO_SLUG="${GITHUB_REPO:-}"
if [[ -z "$REPO_SLUG" ]]; then
  origin="$(git -C "$DEMO_ROOT" remote get-url origin)"
  REPO_SLUG="$(echo "$origin" | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')"
fi
[[ "$REPO_SLUG" == */* ]] || die "defina GITHUB_REPO=owner/repo no .env"
[[ "$(curl -fsS "https://api.github.com/repos/$REPO_SLUG" | jq -r .private)" == "false" ]] \
  || die "o repositorio $REPO_SLUG precisa ser publico (a EC2 clona por https)"
[[ -n "$(curl -fsS "https://api.github.com/repos/$REPO_SLUG/contents/demo-slo-pipeline/infra/demo.yaml?ref=main" | jq -r '.name // empty')" ]] \
  || die "demo-slo-pipeline/ nao esta na branch main de $REPO_SLUG: faca o push antes"
echo "      $REPO_SLUG (publico, demo presente na main)"

echo "[3/5] Detectando o provider OIDC do GitHub na conta..."
# O provider pode ser do PROPRIO stack (criado numa execucao anterior) ou de outra origem. Se for do stack,
# GitHubOidcProviderArn tem que ficar VAZIO: informar o ARN faria o CloudFormation apagar o provider.
OWN="$(aws cloudformation describe-stack-resource --stack-name "$STACK" --logical-resource-id GitHubOidcProvider \
  --query StackResourceDetail.ResourceStatus --output text 2>/dev/null || echo NONE)"
if [[ "$OWN" == "CREATE_COMPLETE" || "$OWN" == "UPDATE_COMPLETE" ]]; then
  PROVIDER=""
  echo "      gerenciado por este stack (parametro fica vazio)"
else
  PROVIDER="$(aws iam list-open-id-connect-providers \
    --query "OpenIDConnectProviderList[?ends_with(Arn,'token.actions.githubusercontent.com')].Arn | [0]" --output text)"
  [[ "$PROVIDER" == "None" ]] && PROVIDER=""
  echo "      ${PROVIDER:-nenhum (o stack vai criar)}"
fi

echo "[4/5] Criando o stack $STACK (8 a 12 min: so termina quando Docker, app e Datadog Agent estao no ar)..."
STATUS="$(aws cloudformation describe-stacks --stack-name "$STACK" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo NONE)"
if [[ "$STATUS" == "ROLLBACK_COMPLETE" || "$STATUS" == "CREATE_FAILED" ]]; then
  echo "      stack anterior em $STATUS: removendo antes de recriar"
  aws cloudformation delete-stack --stack-name "$STACK"
  aws cloudformation wait stack-delete-complete --stack-name "$STACK"
fi
aws cloudformation deploy --stack-name "$STACK" --template-file "$DEMO_ROOT/infra/demo.yaml" \
  --capabilities CAPABILITY_IAM --no-fail-on-empty-changeset \
  --parameter-overrides DatadogApiKey="$DD_API_KEY" DatadogAppKey="$DD_APP_KEY" DatadogSite="$DD_SITE" \
  GitHubRepo="$REPO_SLUG" GitHubOidcProviderArn="$PROVIDER" InstanceType="${INSTANCE_TYPE:-t3.micro}"

echo "[5/5] Configuracao no GitHub..."
ROLE_ARN="$(cfout GitHubRoleArn)"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh variable set AWS_ROLE_ARN --body "$ROLE_ARN" -R "$REPO_SLUG" >/dev/null
  echo "      variavel AWS_ROLE_ARN criada em $REPO_SLUG (via gh)"
else
  echo "      Crie a variavel (Settings > Secrets and variables > Actions > Variables):"
  echo "        https://github.com/$REPO_SLUG/settings/variables/actions"
  echo "        Nome:  AWS_ROLE_ARN"
  echo "        Valor: $ROLE_ARN"
fi
echo
echo "Ambiente no ar. Falta so o environment 'slo-override' com revisor (README, A4) e a verificacao (A5)."
