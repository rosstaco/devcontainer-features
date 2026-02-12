#!/bin/bash

# Scenario test: Debian base image
# Validates copilot-persistence works on Debian

set -e

source dev-container-features-test-lib

# Run the init script to fix volume permissions (normally runs via /etc/profile.d on login)
if [ -f /usr/local/share/copilot-persistence/init.sh ]; then
    . /usr/local/share/copilot-persistence/init.sh
fi

check "copilot-data directory exists" test -d /copilot-data

check "COPILOT_DATA_DIR is set" test "$COPILOT_DATA_DIR" = "/copilot-data"

check "symlink exists at ~/.copilot" test -L ~/.copilot

check "can write to copilot-data" bash -c "touch /copilot-data/test-file && rm /copilot-data/test-file"

reportResults
