#!/bin/bash

# This test verifies that a specific version can be installed

set -e

source dev-container-features-test-lib

check "guardian is installed" bash -c "guardian version 2>&1 | grep -q 'Microsoft.Guardian.Cli'"

check "guardian is executable" which guardian

check "guardian version command works" bash -c "guardian version 2>&1 | grep -q '[0-9]\+\.[0-9]\+\.[0-9]\+'"

reportResults
