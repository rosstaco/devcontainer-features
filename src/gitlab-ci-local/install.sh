#!/bin/bash
set -e

# GitLab CI Local installation script for devcontainer features
# https://github.com/firecow/gitlab-ci-local

CLI_VERSION="${VERSION:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

download_from_github() {
    local release_url=$1
    echo "Downloading gitlab-ci-local from ${release_url}..."

    mkdir -p /tmp/gitlab-ci-local
    pushd /tmp/gitlab-ci-local
    wget --show-progress --progress=dot:giga "${release_url}"
    tar -xzf /tmp/gitlab-ci-local/"${cli_filename}"
    mv gitlab-ci-local /usr/local/bin/gitlab-ci-local
    popd
    rm -rf /tmp/gitlab-ci-local
}

install_using_github() {
    check_packages wget tar ca-certificates git
    echo "Finished setting up dependencies"

    arch=$(dpkg --print-architecture)
    if [ "${arch}" != "amd64" ] && [ "${arch}" != "arm64" ]; then
        echo -e "${RED}Unsupported architecture: ${arch}${NC}" >&2
        echo -e "${RED}Only amd64 and arm64 are supported.${NC}" >&2
        exit 1
    fi

    cli_filename="gitlab-ci-local-linux-${arch}.tar.gz"
    echo "Installing gitlab-ci-local for ${arch} architecture: ${cli_filename}"

    if [ "${CLI_VERSION}" = "latest" ]; then
        download_from_github "https://github.com/firecow/gitlab-ci-local/releases/latest/download/${cli_filename}"
    else
        # Add leading v to version if it doesn't start with a digit (versions are plain numbers like 4.67.0)
        download_from_github "https://github.com/firecow/gitlab-ci-local/releases/download/${CLI_VERSION}/${cli_filename}"
    fi
}

echo -e "${GREEN}Installing gitlab-ci-local...${NC}"

install_using_github

# Set executable permission
chmod +x /usr/local/bin/gitlab-ci-local

# Verify installation
if ! command -v gitlab-ci-local &> /dev/null; then
    echo -e "${RED}gitlab-ci-local installation failed - command not found in PATH${NC}"
    exit 1
fi

INSTALLED_VERSION=$(gitlab-ci-local --version 2>&1 || true)
echo -e "${GREEN}gitlab-ci-local installed successfully: ${INSTALLED_VERSION}${NC}"
echo ""
echo "The 'gitlab-ci-local' command is now available."
echo "For more information: https://github.com/firecow/gitlab-ci-local"
