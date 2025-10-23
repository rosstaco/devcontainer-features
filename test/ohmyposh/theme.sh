#!/bin/bash

# This test verifies custom theme configuration

set -e

source dev-container-features-test-lib

# Check that dracula theme is configured in shell rc files
check "bash configured with dracula theme" grep -q "jandedobbeleer\|dracula" ~/.bashrc

check "theme can be used" oh-my-posh init bash --config dracula

reportResults
