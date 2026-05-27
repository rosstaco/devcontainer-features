#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'copilot-metrics-lgtm' Feature with no options.
#
# Eg:
# {
#    "image": "<..some-base-image...>",
#    "features": {
#       "copilot-metrics-lgtm": {}
#    }
# }

set -e

source dev-container-features-test-lib

FEATURE_DIR="/usr/local/share/copilot-metrics-lgtm"

# Core runtime files
check "post-start.sh exists"           test -f "${FEATURE_DIR}/post-start.sh"
check "post-start.sh is executable"    test -x "${FEATURE_DIR}/post-start.sh"
check "docker-compose.yml exists"      test -f "${FEATURE_DIR}/docker-compose.yml"
check "dashboard JSON exists"          test -f "${FEATURE_DIR}/dashboards/github-copilot.json"

# Config file written by install.sh
check ".env exists"              test -f "${FEATURE_DIR}/.env"
check ".env has LGTM_IMAGE"     grep -q "^LGTM_IMAGE=" "${FEATURE_DIR}/.env"
check ".env has INSTALL_DASHBOARD" grep -q "^INSTALL_DASHBOARD=" "${FEATURE_DIR}/.env"
check ".env has DOCKER_MODE"     grep -q "^DOCKER_MODE=" "${FEATURE_DIR}/.env"
check ".env has GRAFANA_PORT"    grep -q "^GRAFANA_PORT=" "${FEATURE_DIR}/.env"
check ".env has CAPTURE_CONTENT"  grep -q "^CAPTURE_CONTENT=" "${FEATURE_DIR}/.env"
check "profile.d env var exists" test -f /etc/profile.d/copilot-metrics-lgtm.sh

# Syntax checks
check "post-start.sh valid bash" bash -n "${FEATURE_DIR}/post-start.sh"
check "dashboard is valid JSON"  jq empty "${FEATURE_DIR}/dashboards/github-copilot.json"

reportResults
