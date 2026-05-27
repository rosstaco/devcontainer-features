#!/usr/bin/env bash
# Installs the copilot-metrics-lgtm Feature: stages runtime files into
# /usr/local/share/copilot-metrics-lgtm/ and writes a .env with resolved options.
set -euo pipefail

FEATURE_DIR="/usr/local/share/copilot-metrics-lgtm"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "${FEATURE_DIR}/dashboards"

# Copy runtime files
cp "${SCRIPT_DIR}/docker-compose.yml"              "${FEATURE_DIR}/"
cp "${SCRIPT_DIR}/post-start.sh"                   "${FEATURE_DIR}/"
cp "${SCRIPT_DIR}/dashboards/github-copilot.json"  "${FEATURE_DIR}/dashboards/"

# Resolve options (env vars set by devcontainer CLI per Feature spec)
LGTM_IMAGE="${LGTMIMAGE:-grafana/otel-lgtm:latest}"
INSTALL_DASHBOARD="${INSTALLDASHBOARD:-true}"
DOCKER_MODE="${DOCKERMODE:-auto}"
CAPTURE_CONTENT="${CAPTURECONTENT:-true}"

# Validate grafanaPort
GRAFANA_PORT="${GRAFANAPORT:-3000}"
if [[ ! "${GRAFANA_PORT}" =~ ^[0-9]+$ ]]; then
  echo "WARNING: grafanaPort '${GRAFANA_PORT}' is not a number; using 3000" >&2
  GRAFANA_PORT="3000"
fi

# Basic validation of lgtmImage
if [[ ! "${LGTM_IMAGE}" =~ ^[a-zA-Z0-9._/:@-]+$ ]]; then
  echo "WARNING: lgtmImage '${LGTM_IMAGE}' looks invalid; using default" >&2
  LGTM_IMAGE="grafana/otel-lgtm:latest"
fi

# Write config for post-start.sh and docker-compose variable substitution.
# Values are read back with grep/cut, not sourced, to avoid injection.
cat > "${FEATURE_DIR}/.env" <<EOF
LGTM_IMAGE=${LGTM_IMAGE}
INSTALL_DASHBOARD=${INSTALL_DASHBOARD}
DOCKER_MODE=${DOCKER_MODE}
GRAFANA_PORT=${GRAFANA_PORT}
CAPTURE_CONTENT=${CAPTURE_CONTENT}
EOF

# Set CLI env var via profile.d so it's available in all terminal sessions
mkdir -p /etc/profile.d
cat > /etc/profile.d/copilot-metrics-lgtm.sh <<EOF
export OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT="${CAPTURE_CONTENT}"
EOF

chmod +x "${FEATURE_DIR}/post-start.sh"
echo "copilot-metrics-lgtm: installed to ${FEATURE_DIR}"
