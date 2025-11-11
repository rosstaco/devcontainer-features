#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'microsoft-security-devops-cli' Feature with no options.
#
# Thus, the value of all options will fall back to the default value in the
# Feature's 'devcontainer-feature.json'.
#
# These scripts are run as 'root' by default. Although that can be changed
# with the '--remote-user' flag.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
check "guardian is installed" bash -c "guardian version 2>&1 | grep -q 'Microsoft.Guardian.Cli' || true"

check "guardian is executable" which guardian

check "guardian binary in correct location" test -x /usr/local/bin/guardian/guardian

check "guardian can show version" bash -c "guardian version 2>&1 | grep -q '[0-9]\+\.[0-9]\+\.[0-9]\+' || true"

# Report results
reportResults
