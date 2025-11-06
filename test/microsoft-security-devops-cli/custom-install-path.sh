#!/bin/bash

# This test verifies custom install path

set -e

source dev-container-features-test-lib

check "guardian installed in custom path" test -x /usr/bin/guardian/guardian

check "guardian is accessible" bash -c "guardian version 2>&1 | grep -q 'Microsoft.Guardian.Cli'"

check "guardian is in PATH" which guardian

reportResults
