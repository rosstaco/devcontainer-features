#!/bin/bash
set -e

# package-source-overrides
# -------------------------
# Point npm/pnpm, pip, and NuGet at internal "override" package sources instead
# of public feeds. This Feature only writes configuration files (no network, no
# apt, no assumption that the package managers are installed yet) so it can run
# as early as possible and have other Features resolve packages through the same
# sources during their own install scripts.

NPM_REGISTRY="${NPMREGISTRY:-}"
PIP_INDEX_URL="${PIPINDEXURL:-}"
NUGET_SOURCE="${NUGETSOURCE:-}"
NUGET_SOURCE_NAME="${NUGETSOURCENAME:-override}"
SCOPE="${SCOPE:-both}"
STRICT_SSL="${STRICTSSL:-true}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[package-source-overrides]${NC} $*"; }
warn() { echo -e "${YELLOW}[package-source-overrides]${NC} $*" >&2; }
err()  { echo -e "${RED}[package-source-overrides]${NC} $*" >&2; }

if [ "$(id -u)" -ne 0 ]; then
    err "Script must be run as root. Add \"USER root\" before running, or use sudo."
    exit 1
fi

# --- Resolve scope ----------------------------------------------------------
DO_SYSTEM=false
DO_USER=false
case "${SCOPE}" in
    system) DO_SYSTEM=true ;;
    user)   DO_USER=true ;;
    both)   DO_SYSTEM=true; DO_USER=true ;;
    *) err "Invalid scope '${SCOPE}' (expected system|user|both)"; exit 1 ;;
esac

# --- Insecure/self-signed proxy handling ------------------------------------
INSECURE=false
if [ "${STRICT_SSL}" = "false" ]; then
    INSECURE=true
fi

# --- Resolve remote (non-root) user + home ----------------------------------
REMOTE_USER="${_REMOTE_USER:-"${USERNAME:-vscode}"}"
USER_HOME=""
USER_UID=""
USER_GID=""
if [ "${REMOTE_USER}" != "root" ] && [ "${REMOTE_USER}" != "none" ] && id -u "${REMOTE_USER}" >/dev/null 2>&1; then
    USER_HOME="${_REMOTE_USER_HOME:-"$(getent passwd "${REMOTE_USER}" 2>/dev/null | cut -d: -f6)"}"
    USER_UID="$(id -u "${REMOTE_USER}" 2>/dev/null || true)"
    USER_GID="$(id -g "${REMOTE_USER}" 2>/dev/null || true)"
fi

BEGIN_MARK="# >>> package-source-overrides >>>"
END_MARK="# <<< package-source-overrides <<<"

# --- Helpers ----------------------------------------------------------------

# make_dir <dir> <owner: ''|0:0|user>
# Creates the directory; when owner is 'user', chowns each created level up to
# (but not including) the user's home so the remote user can read the config.
make_dir() {
    local dir="$1" owner="$2"
    mkdir -p "${dir}"
    if [ "${owner}" = "user" ] && [ -n "${USER_HOME}" ] && [ -n "${USER_UID}" ]; then
        local cur="${dir}"
        while [ "${cur}" != "${USER_HOME}" ] && [ "${cur}" != "/" ] && [ "${cur}" != "." ]; do
            chown "${USER_UID}:${USER_GID}" "${cur}" 2>/dev/null || true
            cur="$(dirname "${cur}")"
        done
    fi
}

# apply_owner <path> <owner: ''|0:0|user>
apply_owner() {
    local path="$1" owner="$2"
    case "${owner}" in
        user)
            if [ -n "${USER_UID}" ]; then
                chown "${USER_UID}:${USER_GID}" "${path}" 2>/dev/null || true
            fi
            ;;
        "")   : ;;
        *)    chown "${owner}" "${path}" 2>/dev/null || true ;;
    esac
}

# remove_block <path> : strip a previously managed marker block (idempotency)
remove_block() {
    local path="$1"
    [ -f "${path}" ] || return 0
    awk -v b="${BEGIN_MARK}" -v e="${END_MARK}" '
        $0==b {skip=1; next}
        skip==1 && $0==e {skip=0; next}
        skip==1 {next}
        {print}
    ' "${path}" > "${path}.pso.tmp" && mv "${path}.pso.tmp" "${path}"
}

# write_full_file <path> <owner> <content> : fully managed file (overwritten)
write_full_file() {
    local path="$1" owner="$2" content="$3"
    make_dir "$(dirname "${path}")" "${owner}"
    printf '%s\n' "${content}" > "${path}"
    chmod 0644 "${path}"
    apply_owner "${path}" "${owner}"
    log "wrote ${path}"
}

# write_block_file <path> <owner> <content> : managed marker block, preserving
# any unrelated lines already in the file. Our block is appended last so its
# keys win for last-wins parsers such as npm.
write_block_file() {
    local path="$1" owner="$2" content="$3"
    make_dir "$(dirname "${path}")" "${owner}"
    remove_block "${path}"
    {
        printf '%s\n' "${BEGIN_MARK}"
        printf '%s\n' "${content}"
        printf '%s\n' "${END_MARK}"
    } >> "${path}"
    chmod 0644 "${path}"
    apply_owner "${path}" "${owner}"
    log "updated ${path}"
}

# url_host <url> : extract host[:port] from a URL (for pip trusted-host)
url_host() {
    printf '%s' "$1" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#/.*$##; s#^[^@]*@##'
}

# --- npm / pnpm -------------------------------------------------------------
# npm and pnpm both read `.npmrc`; `registry=` replaces the default registry.
configure_npm() {
    [ -z "${NPM_REGISTRY}" ] && return 0
    log "Configuring npm/pnpm registry -> ${NPM_REGISTRY}"
    local content="registry=${NPM_REGISTRY}"
    if [ "${INSECURE}" = "true" ]; then
        content="${content}
strict-ssl=false"
    fi
    # System file is picked up via containerEnv NPM_CONFIG_GLOBALCONFIG=/etc/npmrc
    if [ "${DO_SYSTEM}" = "true" ]; then
        write_block_file "/etc/npmrc" "" "${content}"
    fi
    if [ "${DO_USER}" = "true" ]; then
        write_block_file "/root/.npmrc" "0:0" "${content}"
        if [ -n "${USER_HOME}" ]; then
            write_block_file "${USER_HOME}/.npmrc" "user" "${content}"
        fi
    fi
}

# --- pip / PyPI -------------------------------------------------------------
# `index-url` replaces the default PyPI index (public feed no longer consulted).
configure_pip() {
    [ -z "${PIP_INDEX_URL}" ] && return 0
    log "Configuring pip index-url -> ${PIP_INDEX_URL}"
    local content="# Managed by the package-source-overrides dev container Feature
[global]
index-url = ${PIP_INDEX_URL}"
    if [ "${INSECURE}" = "true" ]; then
        content="${content}
trusted-host = $(url_host "${PIP_INDEX_URL}")"
    fi
    if [ "${DO_SYSTEM}" = "true" ]; then
        write_full_file "/etc/pip.conf" "" "${content}"
    fi
    if [ "${DO_USER}" = "true" ]; then
        write_full_file "/root/.config/pip/pip.conf" "0:0" "${content}"
        if [ -n "${USER_HOME}" ]; then
            write_full_file "${USER_HOME}/.config/pip/pip.conf" "user" "${content}"
        fi
    fi
}

# --- NuGet / .NET -----------------------------------------------------------
# <clear /> drops nuget.org so only the override source remains (replace policy).
configure_nuget() {
    [ -z "${NUGET_SOURCE}" ] && return 0
    log "Configuring NuGet source '${NUGET_SOURCE_NAME}' -> ${NUGET_SOURCE}"
    local insecure_attr=""
    if [ "${INSECURE}" = "true" ]; then
        insecure_attr=" allowInsecureConnections=\"true\""
    fi
    local content="<?xml version=\"1.0\" encoding=\"utf-8\"?>
<!-- Managed by the package-source-overrides dev container Feature -->
<configuration>
  <packageSources>
    <clear />
    <add key=\"${NUGET_SOURCE_NAME}\" value=\"${NUGET_SOURCE}\" protocolVersion=\"3\"${insecure_attr} />
  </packageSources>
</configuration>"
    # Machine-wide NuGet config directory on Linux is /etc/opt/NuGet/Config
    if [ "${DO_SYSTEM}" = "true" ]; then
        write_full_file "/etc/opt/NuGet/Config/NuGet.Config" "" "${content}"
    fi
    if [ "${DO_USER}" = "true" ]; then
        write_full_file "/root/.nuget/NuGet/NuGet.Config" "0:0" "${content}"
        if [ -n "${USER_HOME}" ]; then
            write_full_file "${USER_HOME}/.nuget/NuGet/NuGet.Config" "user" "${content}"
        fi
    fi
}

# --- Main -------------------------------------------------------------------
configure_npm
configure_pip
configure_nuget

if [ -z "${NPM_REGISTRY}${PIP_INDEX_URL}${NUGET_SOURCE}" ]; then
    warn "No override sources provided (npmRegistry, pipIndexUrl, nugetSource all empty); nothing configured."
else
    log "Done. scope=${SCOPE} strictSsl=${STRICT_SSL} remoteUser=${REMOTE_USER}${USER_HOME:+ (${USER_HOME})}"
fi

exit 0
