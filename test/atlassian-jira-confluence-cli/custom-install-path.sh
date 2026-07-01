#!/bin/bash

# This test verifies that acli can be installed to a custom directory

set -e

source dev-container-features-test-lib

check "acli binary in custom install path" test -x /usr/bin/acli

check "acli is on PATH" command -v acli

check "acli version command works" bash -c "acli --version 2>&1 | grep -q '[0-9]\+\.[0-9]\+\.[0-9]\+'"

reportResults
