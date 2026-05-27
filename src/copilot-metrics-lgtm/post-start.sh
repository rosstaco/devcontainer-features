#!/usr/bin/env bash
# Post-start lifecycle script for the copilot-metrics-lgtm Feature.
# Starts the LGTM stack and provisions the Grafana dashboard.
set -euo pipefail

FEATURE_DIR="/usr/local/share/copilot-metrics-lgtm"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Read a value from the .env config written by install.sh.
# Uses grep/cut instead of `source` to avoid shell-injection risk.
get_config() {
  local val
  val="$(grep "^${1}=" "${FEATURE_DIR}/.env" 2>/dev/null | head -1 | cut -d= -f2-)"
  echo "${val:-$2}"
}

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

if ! command -v docker &>/dev/null; then
  echo "copilot-metrics-lgtm: ERROR — 'docker' not found." >&2
  echo "  Install ghcr.io/devcontainers/features/docker-in-docker" >&2
  echo "  or ghcr.io/devcontainers/features/docker-outside-of-docker." >&2
  exit 1
fi

if ! docker compose version &>/dev/null; then
  echo "copilot-metrics-lgtm: ERROR — 'docker compose' not available." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Read options
# ---------------------------------------------------------------------------

DOCKER_MODE="$(get_config DOCKER_MODE auto)"
INSTALL_DASHBOARD="$(get_config INSTALL_DASHBOARD true)"
GRAFANA_PORT="$(get_config GRAFANA_PORT 3000)"

# ---------------------------------------------------------------------------
# Auto-detect Docker mode
# ---------------------------------------------------------------------------

if [[ "${DOCKER_MODE}" == "auto" ]]; then
  if docker inspect "$HOSTNAME" >/dev/null 2>&1; then
    DOCKER_MODE=dood
  else
    DOCKER_MODE=dind
  fi
  echo "copilot-metrics-lgtm: auto-detected docker mode: ${DOCKER_MODE}"
fi

# ---------------------------------------------------------------------------
# Prepare data volume mount point
# ---------------------------------------------------------------------------

$SUDO mkdir -p /lgtm-data
$SUDO chmod 0777 /lgtm-data

# ---------------------------------------------------------------------------
# Start LGTM stack
# ---------------------------------------------------------------------------

cd "${FEATURE_DIR}"

if [[ "${DOCKER_MODE}" == "dood" ]]; then
  export LGTM_NETWORK_MODE="container:${HOSTNAME}"
fi

docker compose up -d

# ---------------------------------------------------------------------------
# Wait for Grafana
# ---------------------------------------------------------------------------

GRAFANA_URL="http://localhost:${GRAFANA_PORT}"
echo "copilot-metrics-lgtm: waiting for Grafana..."
for i in $(seq 1 30); do
  if curl -fsS "${GRAFANA_URL}/api/health" >/dev/null 2>&1; then
    echo "copilot-metrics-lgtm: Grafana is ready"
    break
  fi
  sleep 2
done

# ---------------------------------------------------------------------------
# Provision dashboard
# ---------------------------------------------------------------------------

if [[ "${INSTALL_DASHBOARD}" == "true" ]]; then
  DASHBOARD_FILE="${FEATURE_DIR}/dashboards/github-copilot.json"
  DASHBOARD_UID="GitHubCopilot"
  if [[ -f "${DASHBOARD_FILE}" ]]; then
    if curl -fsS "${GRAFANA_URL}/api/dashboards/uid/${DASHBOARD_UID}" >/dev/null 2>&1; then
      echo "copilot-metrics-lgtm: dashboard ${DASHBOARD_UID} already present; leaving as-is."
    else
      echo "copilot-metrics-lgtm: provisioning dashboard..."
      curl -fsS -X POST -H "Content-Type: application/json" \
        --data @"${DASHBOARD_FILE}" \
        "${GRAFANA_URL}/api/dashboards/db" \
        >/dev/null && echo "copilot-metrics-lgtm: dashboard provisioned" \
        || echo "copilot-metrics-lgtm: dashboard provisioning failed (Grafana may still be starting)"
    fi
  fi
fi
