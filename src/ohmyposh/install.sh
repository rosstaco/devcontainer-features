#!/bin/bash
set -e

# Oh My Posh installation script for devcontainer features
# https://ohmyposh.dev

VERSION="${VERSION:-latest}"
THEME="${THEME:-jandedobbeleer}"
INSTALL_PATH="${INSTALLPATH:-/usr/local/bin}"
SHELLS="${SHELLS:-bash,zsh}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Oh My Posh...${NC}"

# Ensure curl is available
if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    export DEBIAN_FRONTEND=noninteractive
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y curl
    elif command -v apk &> /dev/null; then
        apk add --no-cache curl
    elif command -v yum &> /dev/null; then
        yum install -y curl
    else
        echo -e "${RED}Could not install curl. Please install it manually.${NC}"
        exit 1
    fi
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    armv7l|armv6l)
        ARCH="arm"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"

# Get the download URL
if [ "$VERSION" = "latest" ]; then
    echo "Fetching latest version..."
    DOWNLOAD_URL="https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-${ARCH}"
else
    echo "Using version: $VERSION"
    DOWNLOAD_URL="https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/${VERSION}/posh-linux-${ARCH}"
fi

echo "Downloading Oh My Posh from: $DOWNLOAD_URL"

# Download the binary
TEMP_FILE="/tmp/oh-my-posh-install"
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
    echo -e "${RED}Failed to download Oh My Posh${NC}"
    exit 1
fi

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_PATH"

# Install the binary
mv "$TEMP_FILE" "$INSTALL_PATH/oh-my-posh"
chmod +x "$INSTALL_PATH/oh-my-posh"

# Install the configure script
HELPER_SCRIPT="/usr/local/bin/oh-my-posh-configure-shell"
cp "$(dirname "$0")/configure-shell.sh" "$HELPER_SCRIPT"
chmod +x "$HELPER_SCRIPT"

echo -e "${GREEN}Oh My Posh binary installed to $INSTALL_PATH/oh-my-posh${NC}"

# Verify installation
if ! "$INSTALL_PATH/oh-my-posh" version; then
    echo -e "${RED}Oh My Posh installation verification failed${NC}"
    exit 1
fi

# Determine the user to configure
if [ -n "$_REMOTE_USER" ]; then
    USER_NAME="$_REMOTE_USER"
elif [ -n "$REMOTE_USER" ]; then
    USER_NAME="$REMOTE_USER"
else
    USER_NAME="${USERNAME:-vscode}"
fi

USER_HOME=$(eval echo "~$USER_NAME")

echo "Configuring for user: $USER_NAME (home: $USER_HOME)"

# Create the theme file placeholder
echo "Creating theme file at $USER_HOME/.ohmyposh.json"
touch "$USER_HOME/.ohmyposh.json"
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.ohmyposh.json" 2>/dev/null || true

# Parse shells and configure each one
IFS=',' read -ra SHELL_ARRAY <<< "$SHELLS"

for SHELL_NAME in "${SHELL_ARRAY[@]}"; do
    # Trim whitespace
    SHELL_NAME=$(echo "$SHELL_NAME" | xargs)
    
    case "$SHELL_NAME" in
        bash)
            echo "Configuring bash..."
            RC_FILE="$USER_HOME/.bashrc"
            SHELL_CMD="bash"
            ;;
        zsh)
            echo "Configuring zsh..."
            RC_FILE="$USER_HOME/.zshrc"
            SHELL_CMD="zsh"
            ;;
        fish)
            echo "Configuring fish..."
            RC_FILE="$USER_HOME/.config/fish/config.fish"
            SHELL_CMD="fish"
            mkdir -p "$USER_HOME/.config/fish"
            ;;
        *)
            echo -e "${YELLOW}Unknown shell: $SHELL_NAME, skipping...${NC}"
            continue
            ;;
    esac

    # Create RC file if it doesn't exist
    touch "$RC_FILE"

    # Check if already configured
    if grep -q "oh-my-posh init" "$RC_FILE" 2>/dev/null; then
        echo "Oh My Posh already configured in $RC_FILE"
        continue
    fi

    # Add Oh My Posh initialization
    cat >> "$RC_FILE" << EOF

# region Oh My Posh configuration
if [ -s ~/.ohmyposh.json ]; then
    # Use custom theme if mounted
    eval "\$(oh-my-posh init $SHELL_CMD --config ~/.ohmyposh.json)"
else
    # Use built-in theme
    eval "\$(oh-my-posh init $SHELL_CMD --config $THEME)"
fi
# endregion Oh My Posh configuration
EOF

    chown "$USER_NAME:$USER_NAME" "$RC_FILE" 2>/dev/null || true
    
    echo -e "${GREEN}Configured $SHELL_NAME${NC}"
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Oh My Posh installation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Theme: $THEME (built-in fallback)"
echo "Configured shells: $SHELLS"
echo ""
echo "To use a custom theme, add this to your devcontainer.json:"
echo ""
echo '  "mounts": ['
echo '    "source=${localEnv:HOME}/path/to/your/theme.json,target='$USER_HOME'/.ohmyposh.json,type=bind"'
echo '  ]'
echo ""
echo "For more information: https://ohmyposh.dev"
