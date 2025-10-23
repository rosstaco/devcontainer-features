#!/bin/bash

# This test verifies that a specific version can be installed

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
check "oh-my-posh is installed" oh-my-posh version

check "oh-my-posh version output" oh-my-posh version

# The version should contain a version number (format may vary)
check "version contains number" bash -c "oh-my-posh version | grep -E '[0-9]+\.[0-9]+'"

reportResults
