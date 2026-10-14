#!/bin/bash
set -e

# atlassian-teamwork-graph-cli
# ----------------------------
# Installs the Atlassian Teamwork Graph CLI (twg) for the remote user.
# https://developer.atlassian.com/platform/teamwork-graph/twg-cli/
#
# The official installer (https://teamwork-graph.atlassian.com/cli/install) also
# runs 'twg setup finalize', which records consent, installs skills and starts an
# interactive OAuth login on /dev/tty. That can't happen at image build time, so
# this downloads the binary directly from the same CDN and verifies it against
# the published SHA256SUMS. Consent and login are left to the user ('twg login').

TWG_VERSION="${VERSION:-latest}"
INSTALL_SKILLS="${INSTALLSKILLS:-false}"
ENABLE_TELEMETRY="${ENABLETELEMETRY:-false}"
PERSIST_AUTH="${PERSISTAUTH:-true}"
CONFIGURE_BROWSER="${CONFIGUREBROWSER:-true}"

CDN_BASE_URL="https://teamwork-graph.atlassian.com/cli"
# Fixed paths; BASH_ENV_FILE and CONFIG_VOLUME are also referenced by
# devcontainer-feature.json (containerEnv BASH_ENV and mounts).
STATE_DIR="/etc/atlassian-teamwork-graph-cli"
ENV_FILE="${STATE_DIR}/env.sh"
BASH_ENV_FILE="${STATE_DIR}/bash_env"
PROFILE_FILE="/etc/profile.d/atlassian-teamwork-graph-cli.sh"
CONFIG_VOLUME="/twg-config"
SYMLINK_PATH="/usr/local/bin/twg"
# The BASH_ENV value from before this Feature's containerEnv replaced it.
PREV_BASH_ENV="${ATLASSIAN_TEAMWORK_GRAPH_CLI_PREV_BASH_ENV:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[atlassian-teamwork-graph-cli]${NC} $*"; }
warn() { echo -e "${YELLOW}[atlassian-teamwork-graph-cli]${NC} $*" >&2; }
err()  { echo -e "${RED}[atlassian-teamwork-graph-cli]${NC} $*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    err "Script must be run as root. Add \"USER root\" before running, or use sudo."
    exit 1
fi

# --- Resolve remote user + home ---------------------------------------------
REMOTE_USER="${_REMOTE_USER:-"${USERNAME:-vscode}"}"
if [ "${REMOTE_USER}" = "none" ] || ! id -u "${REMOTE_USER}" >/dev/null 2>&1; then
    REMOTE_USER="root"
fi
if [ "${REMOTE_USER}" = "${_REMOTE_USER:-}" ] && [ -n "${_REMOTE_USER_HOME:-}" ]; then
    USER_HOME="${_REMOTE_USER_HOME}"
else
    USER_HOME="$(getent passwd "${REMOTE_USER}" 2>/dev/null | cut -d: -f6)"
fi
if [ -z "${USER_HOME}" ]; then
    err "Could not determine home directory for user '${REMOTE_USER}'"
    exit 1
fi
USER_UID="$(id -u "${REMOTE_USER}")"
USER_GID="$(id -g "${REMOTE_USER}")"
TWG_BIN="${USER_HOME}/.local/bin/twg"

# Create a directory owned by the remote user, leaving existing ones untouched.
ensure_user_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        chown "${USER_UID}:${USER_GID}" "$1"
    fi
}


# --- Dependencies -----------------------------------------------------------
apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

# --- Telemetry environment --------------------------------------------------
# The variables depend on an option, which static containerEnv cannot express.
# They are written to ENV_FILE and exported for login shells via /etc/profile.d
# and for non-interactive bash via BASH_ENV (chained to any previous BASH_ENV).
configure_env() {
    mkdir -p "${STATE_DIR}"
    if [ "${ENABLE_TELEMETRY}" = "true" ]; then
        rm -f "${ENV_FILE}"
        return 0
    fi
    log "Disabling twg telemetry (DO_NOT_TRACK=1, TWG_DISABLE_3P_DATA_TELEMETRY=1)"
    cat > "${ENV_FILE}" <<'EOF'
# Managed by the atlassian-teamwork-graph-cli dev container Feature
export DO_NOT_TRACK=1
export TWG_DISABLE_3P_DATA_TELEMETRY=1
EOF
    # Also applies to the twg commands run later in this script.
    . "${ENV_FILE}"
}

configure_bash_env() {
    local prev="" content
    if [ -n "${PREV_BASH_ENV}" ] && [ "${PREV_BASH_ENV}" != "${BASH_ENV_FILE}" ]; then
        prev="${PREV_BASH_ENV}"
    fi
    if [ ! -f "${ENV_FILE}" ] && [ -z "${prev}" ]; then
        rm -f "${BASH_ENV_FILE}"
        return 0
    fi
    content="# Managed by the atlassian-teamwork-graph-cli dev container Feature (sourced via BASH_ENV)"
    if [ -n "${prev}" ]; then
        content="${content}
# Chain to the BASH_ENV that was set before this Feature
if [ -r '${prev}' ]; then . '${prev}'; fi"
    fi
    if [ -f "${ENV_FILE}" ]; then
        content="${content}
if [ -r ${ENV_FILE} ]; then . ${ENV_FILE}; fi"
    fi
    printf '%s\n' "${content}" > "${BASH_ENV_FILE}"
}

# --- Persistent auth --------------------------------------------------------
# ~/.config/twg holds auth.conf (credentials/site) and settings. Pointing it at
# the named volume declared in devcontainer-feature.json keeps 'twg login'
# across rebuilds. The volume is always mounted (mounts can't be conditional);
# persistAuth only controls the symlink.
configure_persist_auth() {
    mkdir -p "${CONFIG_VOLUME}"
    chown "${USER_UID}:${USER_GID}" "${CONFIG_VOLUME}"
    chmod 700 "${CONFIG_VOLUME}"
    if [ "${PERSIST_AUTH}" != "true" ]; then
        return 0
    fi
    log "Persisting ${USER_HOME}/.config/twg -> ${CONFIG_VOLUME}"
    ensure_user_dir "${USER_HOME}/.config"
    if [ -e "${USER_HOME}/.config/twg" ] && [ ! -L "${USER_HOME}/.config/twg" ]; then
        mv "${USER_HOME}/.config/twg" "${CONFIG_VOLUME}/migrated-$(date +%s%N)-$$"
    fi
    ln -sfn "${CONFIG_VOLUME}" "${USER_HOME}/.config/twg"
    chown -h "${USER_UID}:${USER_GID}" "${USER_HOME}/.config/twg"
}

write_profile() {
    local content=""
    if [ -f "${ENV_FILE}" ]; then
        content="${content}
if [ -r ${ENV_FILE} ]; then . ${ENV_FILE}; fi"
    fi
    if [ "${PERSIST_AUTH}" = "true" ]; then
        # Build-time ownership may not carry into a mounted volume.
        content="${content}
[ -d ${CONFIG_VOLUME} ] && [ ! -w ${CONFIG_VOLUME} ] && sudo -n chown -R \"\$(id -u):\$(id -g)\" ${CONFIG_VOLUME} 2>/dev/null || true"
    fi
    if [ -z "${content}" ]; then
        rm -f "${PROFILE_FILE}"
        return 0
    fi
    printf '%s\n' "# Managed by the atlassian-teamwork-graph-cli dev container Feature${content}" > "${PROFILE_FILE}"
}

# --- Install binary ---------------------------------------------------------
install_twg() {
    local arch version tmp_dir binary_name expected_sha actual_sha

    case "$(uname -m)" in
        x86_64|amd64)  arch="x64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            err "Unsupported architecture: $(uname -m). Only x86_64 and arm64 are supported."
            exit 1
            ;;
    esac

    if [ "${TWG_VERSION}" = "latest" ]; then
        log "Resolving latest stable twg version from ${CDN_BASE_URL}/manifest.json"
        version="$(curl -fsSL --retry 2 "${CDN_BASE_URL}/manifest.json" \
            | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
            | sed 's/.*"\([^"]*\)"$/\1/')"
        if [ -z "${version}" ]; then
            err "Could not determine the latest twg version from ${CDN_BASE_URL}/manifest.json"
            exit 1
        fi
    else
        version="${TWG_VERSION#v}"
    fi
    if ! printf '%s' "${version}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.+-][0-9A-Za-z.-]+)?$'; then
        err "Invalid twg version '${version}'. Use 'latest' or a version like '1.3.5'."
        exit 1
    fi

    binary_name="twg-linux-${arch}-v${version}"
    tmp_dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${tmp_dir}'" EXIT

    log "Downloading ${CDN_BASE_URL}/${binary_name}"
    if ! curl -fsSL --retry 2 -o "${tmp_dir}/twg" "${CDN_BASE_URL}/${binary_name}"; then
        err "Failed to download twg ${version}. Check that the version exists."
        exit 1
    fi
    curl -fsSL --retry 2 -o "${tmp_dir}/SHA256SUMS" "${CDN_BASE_URL}/SHA256SUMS-v${version}"

    expected_sha="$(awk -v file="${binary_name}" '{ name = $2; sub(/^\*/, "", name); sub(/\r$/, "", name); if (name == file) { print $1; exit } }' "${tmp_dir}/SHA256SUMS")"
    actual_sha="$(sha256sum "${tmp_dir}/twg" | awk '{print $1}')"
    if [ -z "${expected_sha}" ] || [ "${expected_sha}" != "${actual_sha}" ]; then
        err "Checksum verification failed for ${binary_name} (expected '${expected_sha}', got '${actual_sha}')"
        exit 1
    fi

    # Installed user-owned in ~/.local/bin (twg's default launcher path) so
    # 'twg upgrade' can replace it without sudo; symlinked onto the system PATH.
    ensure_user_dir "${USER_HOME}/.local"
    ensure_user_dir "${USER_HOME}/.local/bin"
    install -m 0755 -o "${USER_UID}" -g "${USER_GID}" "${tmp_dir}/twg" "${TWG_BIN}"
    ln -sfn "${TWG_BIN}" "${SYMLINK_PATH}"

    INSTALLED_VERSION="$("${TWG_BIN}" -v 2>/dev/null | head -n 1 || true)"
    if [ -z "${INSTALLED_VERSION}" ]; then
        err "twg was installed to ${TWG_BIN} but failed to run"
        exit 1
    fi
    log "twg ${INSTALLED_VERSION} installed to ${TWG_BIN} (symlinked from ${SYMLINK_PATH})"
}

install_skills() {
    if [ "${INSTALL_SKILLS}" != "true" ]; then
        return 0
    fi
    log "Installing TWG agent skills for ${REMOTE_USER}"
    # su (without -l) keeps the telemetry variables and sets HOME for the user.
    if [ "${REMOTE_USER}" = "root" ]; then
        HOME="${USER_HOME}" "${TWG_BIN}" skills install --yes
    else
        su "${REMOTE_USER}" -s /bin/sh -c "'${TWG_BIN}' skills install --yes"
    fi
}

# twg login opens the OAuth page via xdg-open, which doesn't honor $BROWSER
# inside a dev container. The shim prefers $BROWSER (e.g. VS Code's helper).
configure_browser() {
    if [ "${CONFIGURE_BROWSER}" != "true" ]; then
        return 0
    fi
    log "Installing xdg-open shim that prefers \$BROWSER"
    cat > /usr/local/bin/xdg-open <<'SHIM'
#!/bin/sh
[ -n "$BROWSER" ] && [ -x "$BROWSER" ] && exec "$BROWSER" "$@"
exec /usr/bin/xdg-open "$@"
SHIM
    chmod 0755 /usr/local/bin/xdg-open
}

# --- Main -------------------------------------------------------------------
check_packages curl ca-certificates coreutils
configure_env
configure_bash_env
configure_persist_auth
write_profile
install_twg
install_skills
configure_browser

log "Done. remoteUser=${REMOTE_USER} (${USER_HOME}) telemetry=${ENABLE_TELEMETRY} persistAuth=${PERSIST_AUTH} skills=${INSTALL_SKILLS}"
echo ""
echo "Run 'twg login' to authenticate (or set TWG_TOKEN/TWG_USER/TWG_SITE), then 'twg doctor'."
echo "For more information: https://developer.atlassian.com/platform/teamwork-graph/twg-cli/"
