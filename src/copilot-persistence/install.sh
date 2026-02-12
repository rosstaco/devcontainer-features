#!/bin/bash
set -e

echo "Setting up Copilot CLI persistence..."

# Determine the user (defaults to vscode if not set)
USERNAME="${_REMOTE_USER:-"${USERNAME:-"vscode"}"}"

# Resolve home directory via the passwd database or shell expansion
USER_HOME=""
if command -v getent >/dev/null 2>&1; then
    USER_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
fi
if [ -z "${USER_HOME}" ]; then
    USER_HOME="$(eval echo "~${USERNAME}" 2>/dev/null || true)"
fi
if [ -z "${USER_HOME}" ]; then
    echo "Error: Unable to determine home directory for user '${USERNAME}'" >&2
    exit 1
fi

# Create the persistent data directory in a neutral location
mkdir -p /copilot-data

# Get the user's UID and GID
USER_UID=$(id -u "${USERNAME}" 2>/dev/null || echo "1000")
USER_GID=$(id -g "${USERNAME}" 2>/dev/null || echo "1000")

# Fix ownership for the user (build-time, may be overridden by volume mount)
chown -R "${USER_UID}:${USER_GID}" /copilot-data
chmod 700 /copilot-data

# Create an init script that fixes volume permissions at container start.
# When a named volume is mounted, build-time permissions may not carry over,
# so we fix ownership on every shell login.
mkdir -p /usr/local/share/copilot-persistence
cat > /usr/local/share/copilot-persistence/init.sh << 'INIT'
#!/bin/bash
# Fix /copilot-data ownership if it exists and is not writable by current user
if [ -d /copilot-data ] && [ ! -w /copilot-data ]; then
    sudo chown -R "$(id -u):$(id -g)" /copilot-data 2>/dev/null || true
fi
INIT
chmod 755 /usr/local/share/copilot-persistence/init.sh

# Source the init script from profile so it runs on container start
cat > /etc/profile.d/copilot-persistence.sh << 'PROFILE'
# Fix copilot-data volume permissions on login
if [ -f /usr/local/share/copilot-persistence/init.sh ]; then
    . /usr/local/share/copilot-persistence/init.sh
fi
PROFILE

# Create a symlink from the default location to our persistent volume
# This handles the case where Copilot doesn't use XDG_CONFIG_HOME correctly
mkdir -p "${USER_HOME}"
if [ ! -L "${USER_HOME}/.copilot" ] || [ "$(readlink "${USER_HOME}/.copilot")" != "/copilot-data" ]; then
    rm -rf "${USER_HOME}/.copilot" 2>/dev/null || true
    ln -sf /copilot-data "${USER_HOME}/.copilot"
    chown -h "${USER_UID}:${USER_GID}" "${USER_HOME}/.copilot"
fi

echo "Copilot CLI persistence configured successfully for user: ${USERNAME}"
echo "Data will be stored in /copilot-data (mounted volume)"
