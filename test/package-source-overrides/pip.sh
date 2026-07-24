#!/bin/bash

# Scenario 'pip': only pipIndexUrl set (scope defaults to 'both', strictSsl true).

set -e

source dev-container-features-test-lib

URL="https://proxy.internal/artifactory/api/pypi/pypi-remote/simple"

check "system /etc/pip.conf has index-url" grep -qF "index-url = ${URL}" /etc/pip.conf

check "remote user pip.conf has index-url" grep -qF "index-url = ${URL}" /home/vscode/.config/pip/pip.conf

check "remote user pip.conf owned by vscode" bash -c '[ "$(stat -c %U /home/vscode/.config/pip/pip.conf)" = "vscode" ]'

check "no trusted-host when secure" bash -c '! grep -q "trusted-host" /etc/pip.conf'

reportResults
