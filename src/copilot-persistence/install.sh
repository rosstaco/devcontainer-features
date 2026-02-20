#!/bin/bash
set -e

USERNAME="${_REMOTE_USER:-"${USERNAME:-"vscode"}"}"
USER_HOME="${_REMOTE_USER_HOME:-"$(getent passwd "${USERNAME}" 2>/dev/null | cut -d: -f6)"}"
if [ -z "${USER_HOME}" ]; then
    echo "ERROR: Could not determine home directory for user '${USERNAME}'" >&2
    exit 1
fi
USER_UID=$(id -u "${USERNAME}" 2>/dev/null || echo "1000")
USER_GID=$(id -g "${USERNAME}" 2>/dev/null || echo "1000")

# Prepare the persistent data directory (permissions carry into named volume on first use)
mkdir -p /copilot-data
chown "${USER_UID}:${USER_GID}" /copilot-data
chmod 700 /copilot-data

# Fix volume permissions at login (build-time ownership may not carry into mounted volumes)
cat > /etc/profile.d/copilot-persistence.sh << EOF
[ -d /copilot-data ] && [ ! -w /copilot-data ] && sudo -n chown -R "${USER_UID}:${USER_GID}" /copilot-data 2>/dev/null || true
EOF

# Migrate any pre-existing Copilot data into the volume, then symlink
mkdir -p "${USER_HOME}"
if [ -e "${USER_HOME}/.copilot" ] && [ ! -L "${USER_HOME}/.copilot" ]; then
    mv "${USER_HOME}/.copilot" "/copilot-data/migrated-$(date +%s)"
fi
ln -sfn /copilot-data "${USER_HOME}/.copilot"
chown -h "${USER_UID}:${USER_GID}" "${USER_HOME}/.copilot"

echo "Copilot persistence: ~/.copilot → /copilot-data"
