#!/bin/bash
set -e

# Microsoft Security DevOps CLI installation script for devcontainer features
# https://aka.ms/msdodocs

VERSION="${VERSION:-latest}"
INSTALL_PATH="${INSTALLPATH:-/usr/local/bin/guardian}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Microsoft Security DevOps CLI...${NC}"

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="linux-x64"
        ;;
    aarch64|arm64)
        ARCH="linux-arm64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        echo -e "${RED}Only x86_64 (linux-x64) and aarch64 (linux-arm64) are supported.${NC}"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"

# Build download URL
if [ "$VERSION" = "latest" ]; then
    echo "Fetching latest version..."
    DOWNLOAD_URL="https://www.nuget.org/api/v2/package/Microsoft.Security.DevOps.Cli.${ARCH}"
else
    echo "Using version: $VERSION"
    DOWNLOAD_URL="https://www.nuget.org/api/v2/package/Microsoft.Security.DevOps.Cli.${ARCH}/${VERSION}"
fi

echo "Downloading from: $DOWNLOAD_URL"

# Download the package
TEMP_FILE="/tmp/guardian-cli.nupkg"
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
    echo -e "${RED}Failed to download Microsoft Security DevOps CLI${NC}"
    exit 1
fi

# Extract the package
TEMP_DIR="/tmp/guardian-extract"
mkdir -p "$TEMP_DIR"
if ! unzip -q -o "$TEMP_FILE" -d "$TEMP_DIR"; then
    echo -e "${RED}Failed to extract package${NC}"
    rm -rf "$TEMP_DIR" "$TEMP_FILE"
    exit 1
fi

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_PATH"

# Copy all binaries from tools directory
if [ -d "$TEMP_DIR/tools" ]; then
    echo "Installing binaries to $INSTALL_PATH..."
    
    # Copy entire tools directory to preserve .NET runtime structure
    cp -r "$TEMP_DIR/tools/"* "$INSTALL_PATH/"
    
    # Set executable permissions recursively
    find "$INSTALL_PATH" -type f -exec chmod +x {} \; 2>/dev/null || true
else
    echo -e "${RED}tools directory not found in package${NC}"
    rm -rf "$TEMP_DIR" "$TEMP_FILE"
    exit 1
fi

# Add install path to PATH if not already present
if [[ ":$PATH:" != *":$INSTALL_PATH:"* ]]; then
    echo "Adding $INSTALL_PATH to PATH..."
    
    # Add to /etc/environment for system-wide PATH
    if [ -f /etc/environment ]; then
        # Check if PATH exists in /etc/environment
        if grep -q "^PATH=" /etc/environment; then
            # Append to existing PATH
            sed -i "s|^PATH=\"\(.*\)\"|PATH=\"\1:$INSTALL_PATH\"|" /etc/environment
        else
            # Add new PATH entry
            echo "PATH=\"$PATH:$INSTALL_PATH\"" >> /etc/environment
        fi
    fi
    
    # Add to common shell rc files
    for rc_file in /etc/bash.bashrc /etc/zsh/zshrc; do
        if [ -f "$rc_file" ]; then
            if ! grep -q "$INSTALL_PATH" "$rc_file"; then
                echo "export PATH=\"\$PATH:$INSTALL_PATH\"" >> "$rc_file"
            fi
        fi
    done
    
    # Update current session PATH
    export PATH="$PATH:$INSTALL_PATH"
fi

# Cleanup
rm -rf "$TEMP_DIR" "$TEMP_FILE"

echo -e "${GREEN}Microsoft Security DevOps CLI installed to $INSTALL_PATH${NC}"

# Verify installation
if ! command -v guardian &> /dev/null; then
    echo -e "${YELLOW}Warning: guardian command not found in PATH${NC}"
    echo -e "${YELLOW}You may need to restart your shell or source your shell configuration${NC}"
else
    echo -e "${GREEN}Guardian installation verified successfully${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "The 'guardian' command is now available."
echo ""
echo "To initialize guardian in your repository, run:"
echo ""
echo "  guardian init --force"
echo ""
echo "Note: guardian init requires a git repository."
echo ""
echo "For more information: https://aka.ms/msdodocs"
