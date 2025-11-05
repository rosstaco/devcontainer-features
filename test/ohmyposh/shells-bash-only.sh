#!/bin/bash

# This test verifies shell configuration options

set -e

source dev-container-features-test-lib

check "oh-my-posh is installed" oh-my-posh version

# Only bash should be configured when shells="bash"
check "bash is configured" grep -q "oh-my-posh init bash" ~/.bashrc || echo "Warning: bash not configured"

# zsh should NOT be configured
check "zsh is not configured" bash -c "! grep -q 'oh-my-posh init zsh' ~/.zshrc 2>/dev/null || ! test -f ~/.zshrc"

reportResults
