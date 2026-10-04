#!/bin/bash
set -e

# package-source-overrides
# -------------------------
# Point npm/pnpm/Yarn/Corepack, pip/uv, and NuGet at internal "override" package
# sources instead of public feeds. This Feature only writes configuration files
# (no network, no apt, no assumption that the package managers are installed
# yet) so it can run before other Features and have them resolve packages
# through the same sources during their own install scripts.

NPM_REGISTRY="${NPMREGISTRY:-}"
PIP_INDEX_URL="${PIPINDEXURL:-}"
PYTHON_MIRROR="${UVPYTHONINSTALLMIRROR:-}"
NUGET_SOURCE="${NUGETSOURCE:-}"
NUGET_SOURCE_NAME="${NUGETSOURCENAME:-override}"
SCOPE="${SCOPE:-both}"
STRICT_SSL="${STRICTSSL:-true}"
BASH_ENV_HOOK="${BASHENVHOOK:-false}"

# Fixed paths; BASH_ENV_FILE is also referenced by containerEnv BASH_ENV.
STATE_DIR="/etc/package-source-overrides"
ENV_FILE="${STATE_DIR}/env.sh"
BASH_ENV_FILE="${STATE_DIR}/bash_env"
PROFILE_FILE="/etc/profile.d/package-source-overrides.sh"
# The BASH_ENV value from before this Feature's containerEnv replaced it.
PREV_BASH_ENV="${PACKAGE_SOURCE_OVERRIDES_PREV_BASH_ENV:-}"
DOC_URL="https://github.com/rosstaco/devcontainer-features/tree/main/src/package-source-overrides#install-order"

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

# --- Validation -------------------------------------------------------------
# URLs end up in INI, TOML, YAML, XML and shell files, so reject characters that
# would need format-specific quoting.
validate_url() {
    local name="$1" value="$2"
    [ -z "${value}" ] && return 0
    case "${value}" in
        http://?* | https://?*) ;;
        *) err "Option '${name}' must be an http:// or https:// URL (got '${value}')."; exit 1 ;;
    esac
    case "${value}" in
        *[[:space:]]* | *\"* | *\'* | *\\* | *\`* | *\$* | *\<* | *\>*)
            err "Option '${name}' contains an unsupported character (whitespace, quote, backslash, backtick, \$, < or >)."
            exit 1
            ;;
    esac
}

validate_url npmRegistry "${NPM_REGISTRY}"
validate_url pipIndexUrl "${PIP_INDEX_URL}"
validate_url uvPythonInstallMirror "${PYTHON_MIRROR}"
validate_url nugetSource "${NUGET_SOURCE}"

if [ -n "${NUGET_SOURCE}" ]; then
    case "${NUGET_SOURCE_NAME}" in
        "" | *\"* | *\'* | *\<* | *\>* | *\&*)
            err "Option 'nugetSourceName' must be non-empty and must not contain quotes, <, > or &."
            exit 1
            ;;
    esac
    if [ "$(printf '%s' "${NUGET_SOURCE_NAME}" | tr '[:upper:]' '[:lower:]')" = "nuget.org" ]; then
        err "Option 'nugetSourceName' must not be 'nuget.org' (that source is disabled to enforce the override)."
        exit 1
    fi
fi

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

# per_user <writer> <path-relative-to-home> <content> : run a writer for root
# (build-time installs run as root) and for the remote user (runtime).
per_user() {
    local writer="$1" rel="$2" content="$3"
    "${writer}" "/root/${rel}" "0:0" "${content}"
    if [ -n "${USER_HOME}" ]; then
        "${writer}" "${USER_HOME}/${rel}" "user" "${content}"
    fi
}

# url_host <url> : extract host[:port] from a URL
url_host() {
    printf '%s' "$1" | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#/.*$##; s#^[^@]*@##'
}

# url_hostname <url> : extract the host without any port
url_hostname() {
    local host
    host="$(url_host "$1")"
    printf '%s' "${host%%:*}"
}

# shell_quote <value> : single-quote a value for a sourced shell file
shell_quote() {
    printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

# xml_escape <value> : escape a value for an XML attribute
xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

# --- Late-install detection -------------------------------------------------
# Package managers that already exist may have been installed (and used against
# public feeds) by Features that ran before this one.
PREINSTALLED=""
detect_preinstalled() {
    local candidates="" tool
    if [ -n "${NPM_REGISTRY}" ]; then
        candidates="${candidates} npm pnpm yarn corepack"
    fi
    if [ -n "${PIP_INDEX_URL}" ]; then
        candidates="${candidates} pip pip3 pipx uv"
    elif [ -n "${PYTHON_MIRROR}" ]; then
        candidates="${candidates} uv"
    fi
    if [ -n "${NUGET_SOURCE}" ]; then
        candidates="${candidates} dotnet nuget"
    fi
    for tool in ${candidates}; do
        if command -v "${tool}" >/dev/null 2>&1; then
            PREINSTALLED="${PREINSTALLED:+${PREINSTALLED}, }${tool}"
        fi
    done
}

# --- npm / pnpm / Yarn Classic ----------------------------------------------
# All three read `.npmrc`; `registry=` replaces the default registry. npm also
# reads /etc/npmrc via containerEnv NPM_CONFIG_GLOBALCONFIG, but pnpm ignores
# that, so the per-user files are written regardless of scope.
configure_npm() {
    [ -z "${NPM_REGISTRY}" ] && return 0
    log "Configuring npm/pnpm/Yarn Classic registry -> ${NPM_REGISTRY}"
    local content="registry=${NPM_REGISTRY}"
    if [ "${INSECURE}" = "true" ]; then
        content="${content}
strict-ssl=false"
    fi
    if [ "${DO_SYSTEM}" = "true" ]; then
        write_block_file "/etc/npmrc" "" "${content}"
    fi
    per_user write_block_file ".npmrc" "${content}"
}

# --- Yarn Berry (v2+) -------------------------------------------------------
# Yarn Berry ignores .npmrc and has no system-wide config; it reads ~/.yarnrc.yml.
configure_yarn() {
    [ -z "${NPM_REGISTRY}" ] && return 0
    log "Configuring Yarn Berry npmRegistryServer -> ${NPM_REGISTRY%/}"
    local content="npmRegistryServer: \"${NPM_REGISTRY%/}\""
    if [ "${INSECURE}" = "true" ]; then
        content="${content}
enableStrictSsl: false"
    fi
    case "${NPM_REGISTRY}" in
        http://*)
            content="${content}
unsafeHttpWhitelist:
  - \"$(url_hostname "${NPM_REGISTRY}")\""
            ;;
    esac
    per_user write_yarnrc ".yarnrc.yml" "${content}"
}

# write_yarnrc <path> <owner> <content> : managed block in ~/.yarnrc.yml that
# never duplicates keys the file already sets outside our block. Invoked via per_user.
# shellcheck disable=SC2317
write_yarnrc() {
    local path="$1" owner="$2" content="$3"
    remove_block "${path}"
    if [ -f "${path}" ] && grep -qE '^(npmRegistryServer|enableStrictSsl|unsafeHttpWhitelist):' "${path}"; then
        warn "${path} already sets Yarn registry/SSL keys; leaving it unchanged"
        return 0
    fi
    write_block_file "${path}" "${owner}" "${content}"
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
        per_user write_full_file ".config/pip/pip.conf" "${content}"
    fi
}

# --- uv ---------------------------------------------------------------------
# uv ignores pip.conf and PIP_INDEX_URL; it reads /etc/uv/uv.toml (system) and
# ~/.config/uv/uv.toml (user). uv rejects unknown keys, so keep this minimal.
configure_uv() {
    [ -z "${PIP_INDEX_URL}${PYTHON_MIRROR}" ] && return 0
    local content="# Managed by the package-source-overrides dev container Feature"
    # Top-level keys must come before the [[index]] table.
    if [ -n "${PYTHON_MIRROR}" ]; then
        log "Configuring uv python-install-mirror -> ${PYTHON_MIRROR}"
        content="${content}
python-install-mirror = \"${PYTHON_MIRROR}\""
    fi
    if [ "${INSECURE}" = "true" ]; then
        content="${content}
allow-insecure-host = [$(uv_insecure_hosts)]"
    fi
    if [ -n "${PIP_INDEX_URL}" ]; then
        log "Configuring uv default index -> ${PIP_INDEX_URL}"
        content="${content}

[[index]]
url = \"${PIP_INDEX_URL}\"
default = true"
    fi
    if [ "${DO_SYSTEM}" = "true" ]; then
        write_full_file "/etc/uv/uv.toml" "" "${content}"
    fi
    if [ "${DO_USER}" = "true" ]; then
        per_user write_full_file ".config/uv/uv.toml" "${content}"
    fi
}

# uv_insecure_hosts : de-duplicated, quoted TOML list items for allow-insecure-host
uv_insecure_hosts() {
    local hosts="" item url
    for url in "${PIP_INDEX_URL}" "${PYTHON_MIRROR}"; do
        [ -z "${url}" ] && continue
        item="\"$(url_host "${url}")\""
        case ", ${hosts}, " in
            *", ${item}, "*) ;;
            *) hosts="${hosts:+${hosts}, }${item}" ;;
        esac
    done
    printf '%s' "${hosts}"
}

# --- NuGet / .NET -----------------------------------------------------------
# <clear /> drops inherited sources, and disabling nuget.org keeps it off even
# when a higher-priority NuGet.Config (e.g. the SDK's default user config)
# re-adds it.
configure_nuget() {
    [ -z "${NUGET_SOURCE}" ] && return 0
    log "Configuring NuGet source '${NUGET_SOURCE_NAME}' -> ${NUGET_SOURCE}"
    local insecure_attr="" key value content
    if [ "${INSECURE}" = "true" ]; then
        insecure_attr=" allowInsecureConnections=\"true\""
    fi
    key="$(xml_escape "${NUGET_SOURCE_NAME}")"
    value="$(xml_escape "${NUGET_SOURCE}")"
    content="<?xml version=\"1.0\" encoding=\"utf-8\"?>
<!-- Managed by the package-source-overrides dev container Feature -->
<configuration>
  <packageSources>
    <clear />
    <add key=\"${key}\" value=\"${value}\" protocolVersion=\"3\"${insecure_attr} />
  </packageSources>
  <disabledPackageSources>
    <add key=\"nuget.org\" value=\"true\" />
  </disabledPackageSources>
</configuration>"
    # Machine-wide NuGet config directory on Linux is /etc/opt/NuGet/Config
    if [ "${DO_SYSTEM}" = "true" ]; then
        write_full_file "/etc/opt/NuGet/Config/NuGet.Config" "" "${content}"
    fi
    if [ "${DO_USER}" = "true" ]; then
        per_user write_full_file ".nuget/NuGet/NuGet.Config" "${content}"
    fi
}

# --- Environment-variable-only overrides ------------------------------------
# Some tools can only be redirected by an environment variable whose value is
# the (option-dependent) URL, which static containerEnv cannot express. They are
# written to ENV_FILE and exported for login shells via /etc/profile.d (and,
# opt-in, for non-interactive bash via BASH_ENV; see configure_bash_env).
configure_env_overrides() {
    local exports=()
    if [ -n "${NPM_REGISTRY}" ]; then
        # Corepack ignores .npmrc and appends "/<package>" to this base URL.
        exports+=("export COREPACK_NPM_REGISTRY=$(shell_quote "${NPM_REGISTRY%/}")")
    fi
    [ "${#exports[@]}" -eq 0 ] && return 0
    write_full_file "${ENV_FILE}" "" "$(printf '%s\n' "# Managed by the package-source-overrides dev container Feature" "${exports[@]}")"
    write_full_file "${PROFILE_FILE}" "" "# Managed by the package-source-overrides dev container Feature
if [ -r ${ENV_FILE} ]; then . ${ENV_FILE}; fi"
}

# --- BASH_ENV hook ----------------------------------------------------------
# containerEnv always points BASH_ENV at BASH_ENV_FILE (containerEnv is static).
# bash silently ignores a missing BASH_ENV file, so the file is only created when
# the hook is enabled or a pre-existing BASH_ENV has to keep working (chained).
configure_bash_env() {
    local prev="" content
    if [ -n "${PREV_BASH_ENV}" ] && [ "${PREV_BASH_ENV}" != "${BASH_ENV_FILE}" ]; then
        prev="${PREV_BASH_ENV}"
    fi
    if [ "${BASH_ENV_HOOK}" != "true" ] && [ -z "${prev}" ]; then
        rm -f "${BASH_ENV_FILE}"
        return 0
    fi
    content="# Managed by the package-source-overrides dev container Feature (sourced via BASH_ENV)"
    if [ -n "${prev}" ]; then
        content="${content}
# Chain to the BASH_ENV that was set before this Feature
if [ -r $(shell_quote "${prev}") ]; then . $(shell_quote "${prev}"); fi"
    fi
    if [ "${BASH_ENV_HOOK}" = "true" ]; then
        log "Enabling BASH_ENV hook -> ${BASH_ENV_FILE}"
        content="${content}
if [ -r ${ENV_FILE} ]; then . ${ENV_FILE}; fi"
    fi
    write_full_file "${BASH_ENV_FILE}" "" "${content}"
}

# --- Main -------------------------------------------------------------------
detect_preinstalled
configure_npm
configure_yarn
configure_pip
configure_uv
configure_nuget
configure_env_overrides
configure_bash_env

if [ -z "${NPM_REGISTRY}${PIP_INDEX_URL}${PYTHON_MIRROR}${NUGET_SOURCE}" ]; then
    warn "No override sources provided (npmRegistry, pipIndexUrl, uvPythonInstallMirror, nugetSource all empty); nothing configured."
else
    log "Done. scope=${SCOPE} strictSsl=${STRICT_SSL} bashEnvHook=${BASH_ENV_HOOK} remoteUser=${REMOTE_USER}${USER_HOME:+ (${USER_HOME})}"
fi

if [ -n "${PREINSTALLED}" ]; then
    warn "Already installed before this Feature ran: ${PREINSTALLED}."
    warn "If an earlier Feature installed them, it may already have fetched packages from public feeds."
    warn "To make this Feature install first, see: ${DOC_URL}"
fi

exit 0
