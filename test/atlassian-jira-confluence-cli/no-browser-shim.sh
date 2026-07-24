#!/bin/bash

# This test verifies that the xdg-open shim is NOT installed when
# configureBrowser is set to false.

set -e

source dev-container-features-test-lib

check "acli is installed" command -v acli

check "xdg-open shim not installed" bash -c "! test -e /usr/local/bin/xdg-open"

reportResults
