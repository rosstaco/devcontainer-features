#!/bin/bash

# This test verifies custom install path

set -e

source dev-container-features-test-lib

check "oh-my-posh installed in custom path" test -x /usr/bin/oh-my-posh

check "oh-my-posh is accessible" /usr/bin/oh-my-posh version

reportResults
