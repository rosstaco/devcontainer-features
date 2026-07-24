#!/bin/bash

# This test verifies that a specific version can be installed

set -e

source dev-container-features-test-lib

check "acli is installed" command -v acli

check "acli binary exists" test -x /usr/local/bin/acli

check "acli reports pinned version 1.3.21" bash -c "acli --version 2>&1 | grep -q '1\.3\.21'"

reportResults
