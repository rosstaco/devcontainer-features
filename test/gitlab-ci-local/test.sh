#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'gitlab-ci-local' Feature with no options.
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
check "gitlab-ci-local is executable" command -v gitlab-ci-local

check "gitlab-ci-local binary exists" test -x /usr/local/bin/gitlab-ci-local

check "gitlab-ci-local version command works" bash -c "gitlab-ci-local --version 2>&1 | grep -q '[0-9]\+\.[0-9]\+\.[0-9]\+'"

# Report results
reportResults
