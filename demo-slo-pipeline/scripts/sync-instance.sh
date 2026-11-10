#!/usr/bin/env bash
# Atualiza o código na EC2 (scripts de instance/, compose, router) com o que está na main do GitHub.
# Use depois de dar push de mudanças nesses arquivos. Mudanças no app passam pelo pipeline, não por aqui.
set -euo pipefail
"$(dirname "$0")/remote.sh" 'git -C /opt/lab pull --ff-only && git -C /opt/lab log --oneline -1'
