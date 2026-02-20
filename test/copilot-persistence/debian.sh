#!/bin/bash

# Scenario test: Debian base image
# Validates copilot-persistence works on Debian

set -e

source dev-container-features-test-lib

# Verify profile script was created and source it to fix volume permissions
check "copilot-persistence profile script exists" test -f /etc/profile.d/copilot-persistence.sh
. /etc/profile.d/copilot-persistence.sh

check "copilot-data directory exists" test -d /copilot-data

check "COPILOT_DATA_DIR is set" test "$COPILOT_DATA_DIR" = "/copilot-data"

check "symlink exists at ~/.copilot" test -L ~/.copilot

check "can write to copilot-data" bash -c "touch /copilot-data/test-file && rm /copilot-data/test-file"

check "copilot-data has restricted permissions" bash -c 'test "$(stat -c %a /copilot-data)" = "700"'

reportResults
