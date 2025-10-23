#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'ohmyposh' Feature with no options.
#
# Eg:
# {
#    "image": "<..some-base-image...>",
#    "features": {
#       "ohmyposh": {}
#    }
# }
#
# Thus, the value of all options will fall back to the default value in the
# Feature's 'devcontainer-feature.json'.
#
# These scripts are run as 'root' by default. Although that can be changed
# with the '--remote-user' flag.
# 
# For more information, see: https://github.com/devcontainers/cli/blob/main/docs/features/test.md

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.

check "oh-my-posh is installed" oh-my-posh version

check "oh-my-posh is executable" which oh-my-posh

check "oh-my-posh binary in correct location" test -x /usr/local/bin/oh-my-posh

check "theme placeholder file exists" test -f ~/.ohmyposh.json

check "bash is configured" grep -q "oh-my-posh init bash" ~/.bashrc

check "zsh is configured" grep -q "oh-my-posh init zsh" ~/.zshrc

check "oh-my-posh can init bash" oh-my-posh init bash --config jandedobbeleer

check "oh-my-posh can init zsh" oh-my-posh init zsh --config jandedobbeleer

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
