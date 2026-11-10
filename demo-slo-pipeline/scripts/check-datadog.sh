#!/usr/bin/env bash
# Valida as chaves do Datadog gravadas no stack: a API key, a Application key (acesso a SLOs) e o site.
# É o que o CloudFormation não consegue checar na criação do stack.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
need aws curl jq
need_dd

echo "Site: $DD_SITE"
if dd_api GET /api/v1/validate >/dev/null; then echo "DD_API_KEY: valida"; else die "DD_API_KEY invalida para o site $DD_SITE"; fi
if dd_api GET "/api/v1/slo?limit=1" >/dev/null; then echo "DD_APP_KEY: acesso a SLOs OK"; else die "DD_APP_KEY sem acesso a SLOs (permissao ou plano)"; fi
echo "demo_run atual: $(demo_run)"
