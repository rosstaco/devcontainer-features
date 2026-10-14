#!/bin/bash

# Scenario 'version': pinned version, installed for the non-root remote user.

set -e

source dev-container-features-test-lib

check "pinned twg version installed" bash -c "twg -v 2>&1 | grep -q '^1\.3\.5'"

check "binary installed in the remote user's ~/.local/bin" test -x /home/vscode/.local/bin/twg

check "binary owned by the remote user" bash -c '[ "$(stat -c %U /home/vscode/.local/bin/twg)" = vscode ]'

check "~/.local/bin owned by the remote user" bash -c '[ "$(stat -c %U /home/vscode/.local/bin)" = vscode ]'

check "/usr/local/bin/twg symlinks to the user binary" bash -c '[ "$(readlink /usr/local/bin/twg)" = /home/vscode/.local/bin/twg ]'

check "twg config volume owned by the remote user" bash -c '[ "$(stat -c %U /twg-config)" = vscode ]'

reportResults
