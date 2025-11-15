#!/bin/bash
set -e

# Prompty Dumpty installation script for devcontainer features
# https://pypi.org/project/prompty-dumpty/

VERSION="${VERSION:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing prompty-dumpty...${NC}"

# Ensure pip is available
if ! command -v pip3 &> /dev/null; then
    echo "Installing python3-pip..."
    export DEBIAN_FRONTEND=noninteractive
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y --no-install-recommends python3-pip
    elif command -v apk &> /dev/null; then
        apk add --no-cache py3-pip
    elif command -v yum &> /dev/null; then
        yum install -y python3-pip
    else
        echo -e "${RED}Could not install python3-pip. Please install it manually.${NC}"
        exit 1
    fi
fi

# Build pip install command
if [ "$VERSION" = "latest" ]; then
    echo "Installing latest version..."
    PIP_PACKAGE="prompty-dumpty"
else
    echo "Installing version: $VERSION"
    PIP_PACKAGE="prompty-dumpty==$VERSION"
fi

# Check if pip supports --break-system-packages flag (pip >= 23.0)
if pip3 install --help 2>&1 | grep -q "break-system-packages"; then
    PIP_SUPPORTS_BREAK_SYSTEM="yes"
else
    PIP_SUPPORTS_BREAK_SYSTEM="no"
fi

# Install prompty-dumpty with appropriate flags
if [ "$PIP_SUPPORTS_BREAK_SYSTEM" = "yes" ]; then
    echo "Running: pip3 install $PIP_PACKAGE --break-system-packages"
    if ! pip3 install "$PIP_PACKAGE" --break-system-packages; then
        echo -e "${RED}Failed to install prompty-dumpty${NC}"
        exit 1
    fi
else
    echo "Running: pip3 install $PIP_PACKAGE"
    if ! pip3 install "$PIP_PACKAGE"; then
        echo -e "${RED}Failed to install prompty-dumpty${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}prompty-dumpty installed successfully${NC}"

# Verify installation
if ! command -v dumpty &> /dev/null; then
    echo -e "${YELLOW}Warning: dumpty command not found in PATH${NC}"
    echo -e "${YELLOW}You may need to restart your shell or source your shell configuration${NC}"
else
    echo -e "${GREEN}dumpty installation verified successfully${NC}"
    
    # Try to get version info
    if INSTALLED_VERSION=$(dumpty --version 2>&1); then
        echo "Installed version: $INSTALLED_VERSION"
    else
        echo "Installed version: version check failed"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "The 'dumpty' command is now available."
echo ""
echo "For more information: https://pypi.org/project/prompty-dumpty/"
