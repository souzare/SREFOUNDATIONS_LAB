#!/usr/bin/env bash
# Funções comuns da demo. Uso: source "$(dirname "$0")/<...>/scripts/lib.sh"
# Compatível com bash 3.2 (macOS).

# shellcheck disable=SC2034  # usada pelos scripts que fazem source desta biblioteca
DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
export AWS_DEFAULT_REGION="$AWS_REGION"
STACK="${STACK_NAME:-sre-demo}"

die() { echo "ERRO: $*" >&2; exit 1; }

need() {
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || die "comando ausente: $c"; done
}

# Estado e configuração vivem no SSM Parameter Store, nunca no disco: os scripts rodam em CloudShell,
# no GitHub Actions ou na EC2, onde o disco é descartável.
ssm_get() { aws ssm get-parameter --name "$1" --with-decryption --query Parameter.Value --output text 2>/dev/null || true; }
ssm_put() { aws ssm put-parameter --name "$1" --type "${3:-String}" --value "$2" --overwrite >/dev/null; }
ssm_del() { aws ssm delete-parameter --name "$1" >/dev/null 2>&1 || true; }
state_get() { ssm_get "/sre-demo/state/$1"; }
state_put() { ssm_put "/sre-demo/state/$1" "$2"; }
state_del() { ssm_del "/sre-demo/state/$1"; }
demo_run() { ssm_get /sre-demo/demo_run; }

# Chaves do Datadog: variáveis de ambiente se existirem, senão o SSM (onde o stack do CloudFormation as grava).
need_dd() {
  DD_SITE="${DD_SITE:-$(ssm_get /sre-demo/dd_site)}"
  DD_API_KEY="${DD_API_KEY:-$(ssm_get /sre-demo/dd_api_key)}"
  DD_APP_KEY="${DD_APP_KEY:-$(ssm_get /sre-demo/dd_app_key)}"
  [[ -n "$DD_SITE" && -n "$DD_API_KEY" && -n "$DD_APP_KEY" ]] \
    || die "chaves do Datadog ausentes em /sre-demo/* (o stack do CloudFormation as grava)"
  export DD_SITE DD_API_KEY DD_APP_KEY
}

# URL da interface web do Datadog para o site configurado (datadoghq.com -> app.datadoghq.com)
dd_app_url() {
  case "$DD_SITE" in
    datadoghq.com|datadoghq.eu|ddog-gov.com) echo "https://app.$DD_SITE" ;;
    *) echo "https://$DD_SITE" ;;
  esac
}

cfout() {
  aws cloudformation describe-stacks --stack-name "$STACK" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

# dd_api METHOD PATH [JSON_BODY] -> imprime o corpo; erro (com o corpo) se HTTP >= 400
dd_api() {
  local method="$1" path="$2" body="${3:-}" out code
  if [[ -n "$body" ]]; then
    out=$(curl -sS -w '\n%{http_code}' -X "$method" "https://api.${DD_SITE}${path}" \
      -H "DD-API-KEY: $DD_API_KEY" -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
      -H 'Content-Type: application/json' -d "$body") || return 1
  else
    out=$(curl -sS -w '\n%{http_code}' -X "$method" "https://api.${DD_SITE}${path}" \
      -H "DD-API-KEY: $DD_API_KEY" -H "DD-APPLICATION-KEY: $DD_APP_KEY" \
      -H 'Content-Type: application/json') || return 1
  fi
  code="${out##*$'\n'}"
  out="${out%$'\n'*}"
  if [[ "$code" -ge 400 ]]; then
    echo "Datadog API $method $path -> HTTP $code: $out" >&2
    return 1
  fi
  printf '%s' "$out"
}
