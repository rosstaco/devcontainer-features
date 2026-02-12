#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'copilot-persistence' Feature with no options.
#
# Eg:
# {
#    "image": "<..some-base-image...>",
#    "features": {
#       "copilot-persistence": {}
#    }
# }
#
# Thus, the value of all options will fall back to the default value in the
# Feature's 'devcontainer-feature.json'.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Run the init script to fix volume permissions (normally runs via /etc/profile.d on login)
if [ -f /usr/local/share/copilot-persistence/init.sh ]; then
    . /usr/local/share/copilot-persistence/init.sh
fi

# Feature-specific tests

check "init script exists" test -f /usr/local/share/copilot-persistence/init.sh

check "profile.d script exists" test -f /etc/profile.d/copilot-persistence.sh

check "copilot-data directory exists" test -d /copilot-data

check "copilot-data directory is writable" test -w /copilot-data

check "COPILOT_DATA_DIR env var is set" test -n "$COPILOT_DATA_DIR"

check "COPILOT_DATA_DIR points to /copilot-data" test "$COPILOT_DATA_DIR" = "/copilot-data"

check "symlink exists at ~/.copilot" test -L ~/.copilot

check "symlink target is /copilot-data" test "$(readlink ~/.copilot)" = "/copilot-data"

# Report results
reportResults
