#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

: "${GENT_ENVIRONMENT:?GENT_ENVIRONMENT must be set (TeamCity build configuration parameter)}"
: "${LAMBDA_REGION:?LAMBDA_REGION must be set (TeamCity build configuration parameter)}"

rendered_context="deploy/platform-context.rendered.yaml"
sed \
  -e "s#\${GENT_ENVIRONMENT}#${GENT_ENVIRONMENT}#g" \
  -e "s#\${LAMBDA_REGION}#${LAMBDA_REGION}#g" \
  deploy/platform/platform-context.yaml > "$rendered_context"

echo "==> Deploying hello-lambda to region '${LAMBDA_REGION}' (environment '${GENT_ENVIRONMENT}')"

gent platform deploy \
  --environment "$GENT_ENVIRONMENT" \
  --platform-context "$rendered_context"
