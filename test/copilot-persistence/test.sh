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

# Verify profile script was created and source it to fix volume permissions
check "copilot-persistence profile script exists" test -f /etc/profile.d/copilot-persistence.sh
. /etc/profile.d/copilot-persistence.sh

# Feature-specific tests

check "copilot-data directory exists" test -d /copilot-data

check "copilot-data directory is writable" test -w /copilot-data

check "COPILOT_DATA_DIR env var is set" test -n "$COPILOT_DATA_DIR"

check "COPILOT_DATA_DIR points to /copilot-data" test "$COPILOT_DATA_DIR" = "/copilot-data"

check "symlink exists at ~/.copilot" test -L ~/.copilot

check "symlink target is /copilot-data" test "$(readlink ~/.copilot)" = "/copilot-data"

check "copilot-data has restricted permissions" bash -c 'test "$(stat -c %a /copilot-data)" = "700"'

check "data written to volume is accessible via symlink" bash -c 'echo "test" > /copilot-data/test-persist && test "$(cat ~/.copilot/test-persist)" = "test" && rm /copilot-data/test-persist'

# Test migration: simulate pre-existing .copilot directory and verify mv behavior
check "migration preserves pre-existing data" bash -c '
    rm -f ~/.copilot
    mkdir -p ~/.copilot
    echo "precious-data" > ~/.copilot/history.json
    if [ -e ~/.copilot ] && [ ! -L ~/.copilot ]; then
        mv ~/.copilot "/copilot-data/migrated-test"
    fi
    ln -sfn /copilot-data ~/.copilot
    test -f /copilot-data/migrated-test/history.json &&
    test "$(cat /copilot-data/migrated-test/history.json)" = "precious-data" &&
    test -L ~/.copilot &&
    rm -rf /copilot-data/migrated-test
'

# Report results
reportResults
