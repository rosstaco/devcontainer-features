#!/bin/bash
set -e

echo "Setting up Copilot CLI persistence..."

# Determine the user (defaults to vscode if not set)
USERNAME="${_REMOTE_USER:-"${USERNAME:-"vscode"}"}"

# Resolve home directory properly (root uses /root, others use /home/<user>)
if [ "$USERNAME" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME="/home/${USERNAME}"
fi

# Create the persistent data directory in a neutral location
mkdir -p /copilot-data

# Get the user's UID and GID
USER_UID=$(id -u "${USERNAME}" 2>/dev/null || echo "1000")
USER_GID=$(id -g "${USERNAME}" 2>/dev/null || echo "1000")

# Fix ownership for the user
chown -R "${USER_UID}:${USER_GID}" /copilot-data
chmod 755 /copilot-data

# Create a symlink from the default location to our persistent volume
# This handles the case where Copilot doesn't use XDG_CONFIG_HOME correctly
mkdir -p "${USER_HOME}"
if [ ! -L "${USER_HOME}/.copilot" ]; then
    rm -rf "${USER_HOME}/.copilot" 2>/dev/null || true
    ln -sf /copilot-data "${USER_HOME}/.copilot"
    chown -h "${USER_UID}:${USER_GID}" "${USER_HOME}/.copilot"
fi

echo "Copilot CLI persistence configured successfully for user: ${USERNAME}"
echo "Data will be stored in /copilot-data (mounted volume)"
