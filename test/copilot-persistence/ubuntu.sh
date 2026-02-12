#!/bin/bash

# Scenario test: Ubuntu base image
# Validates copilot-persistence works on Ubuntu

set -e

source dev-container-features-test-lib

check "copilot-data directory exists" test -d /copilot-data

check "COPILOT_DATA_DIR is set" test "$COPILOT_DATA_DIR" = "/copilot-data"

check "symlink exists at ~/.copilot" test -L ~/.copilot

check "can write to copilot-data" bash -c "touch /copilot-data/test-file && rm /copilot-data/test-file"

reportResults
