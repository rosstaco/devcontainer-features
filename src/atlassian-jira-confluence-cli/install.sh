#!/bin/bash
set -e

# Atlassian CLI (acli) installation script for devcontainer features
# https://developer.atlassian.com/cloud/acli/

CLI_VERSION="${VERSION:-latest}"
INSTALL_PATH="${INSTALLPATH:-/usr/local/bin}"
CONFIGURE_BROWSER="${CONFIGUREBROWSER:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script.${NC}"
    exit 1
fi

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

echo -e "${GREEN}Installing Atlassian CLI (acli)...${NC}"

check_packages curl ca-certificates tar
echo "Finished setting up dependencies"

# Detect architecture using dpkg (acli publishes amd64 and arm64 builds)
arch=$(dpkg --print-architecture)
if [ "${arch}" != "amd64" ] && [ "${arch}" != "arm64" ]; then
    echo -e "${RED}Unsupported architecture: ${arch}${NC}" >&2
    echo -e "${RED}Only amd64 and arm64 are supported.${NC}" >&2
    exit 1
fi
echo "Detected architecture: ${arch}"

# Build the download URL. 'latest' uses the rolling release path; a pinned
# version resolves to the versioned '<version>-stable' archive.
if [ "${CLI_VERSION}" = "latest" ]; then
    download_url="https://acli.atlassian.com/linux/latest/acli_linux_${arch}.tar.gz"
else
    # Normalize the version: drop any leading 'v' and ensure the '-stable' suffix
    release="${CLI_VERSION#v}"
    case "${release}" in
        *-stable) ;;
        *) release="${release}-stable" ;;
    esac
    download_url="https://acli.atlassian.com/linux/${release}/acli_${release}_linux_${arch}.tar.gz"
fi

echo "Downloading acli from ${download_url}..."

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "${tmp_dir}"; }
trap cleanup EXIT

if ! curl -fsSL "${download_url}" -o "${tmp_dir}/acli.tar.gz"; then
    echo -e "${RED}Failed to download acli from ${download_url}${NC}" >&2
    echo -e "${RED}Check that the requested version '${CLI_VERSION}' exists.${NC}" >&2
    exit 1
fi

# The archive contains a single '<name>/acli' entry; strip the top-level dir
tar -xzf "${tmp_dir}/acli.tar.gz" --strip-components=1 -C "${tmp_dir}"

if [ ! -f "${tmp_dir}/acli" ]; then
    echo -e "${RED}acli binary not found in downloaded archive${NC}" >&2
    exit 1
fi

mkdir -p "${INSTALL_PATH}"
install -m 0755 "${tmp_dir}/acli" "${INSTALL_PATH}/acli"

# Verify installation
if ! command -v acli &> /dev/null && [ ! -x "${INSTALL_PATH}/acli" ]; then
    echo -e "${RED}acli installation failed - binary not found${NC}" >&2
    exit 1
fi

INSTALLED_VERSION=$("${INSTALL_PATH}/acli" --version 2>&1 | head -n 1 || true)
echo -e "${GREEN}acli installed successfully to ${INSTALL_PATH}/acli: ${INSTALLED_VERSION}${NC}"

# acli's OAuth login shells out to 'xdg-open' rather than honoring $BROWSER,
# which fails (or pops an in-container browser) inside a dev container. Install a
# shim on the PATH that prefers $BROWSER (e.g. VS Code's browser helper) and
# falls back to the real xdg-open otherwise.
if [ "${CONFIGURE_BROWSER}" = "true" ]; then
    echo "Installing xdg-open shim that prefers \$BROWSER..."
    cat > /usr/local/bin/xdg-open <<'SHIM'
#!/bin/sh
[ -n "$BROWSER" ] && [ -x "$BROWSER" ] && exec "$BROWSER" "$@"
exec /usr/bin/xdg-open "$@"
SHIM
    chmod 0755 /usr/local/bin/xdg-open
fi

echo ""
echo "The 'acli' command is now available."
echo "Authenticate with 'acli auth login' to start working with Jira and Confluence."
echo "For more information: https://developer.atlassian.com/cloud/acli/"
