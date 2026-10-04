#!/bin/bash

# Scenario 'pip': pipIndexUrl + uvPythonInstallMirror (scope 'both', strictSsl true).

set -e

source dev-container-features-test-lib

URL="https://proxy.internal/artifactory/api/pypi/pypi-remote/simple"
MIRROR="https://proxy.internal/github/python-build-standalone"

check "system /etc/pip.conf has index-url" grep -qF "index-url = ${URL}" /etc/pip.conf

check "remote user pip.conf has index-url" grep -qF "index-url = ${URL}" /home/vscode/.config/pip/pip.conf

check "remote user pip.conf owned by vscode" bash -c '[ "$(stat -c %U /home/vscode/.config/pip/pip.conf)" = "vscode" ]'

check "no trusted-host when secure" bash -c '! grep -q "trusted-host" /etc/pip.conf'

check "system uv.toml sets the index url" grep -qxF "url = \"${URL}\"" /etc/uv/uv.toml

check "system uv.toml marks the index as default" grep -qxF "default = true" /etc/uv/uv.toml

check "uv python-install-mirror set" grep -qxF "python-install-mirror = \"${MIRROR}\"" /etc/uv/uv.toml

check "python-install-mirror is a top-level key (before [[index]])" bash -c 'm=$(grep -n "^python-install-mirror" /etc/uv/uv.toml | cut -d: -f1); i=$(grep -n "^\[\[index\]\]" /etc/uv/uv.toml | cut -d: -f1); [ -n "$m" ] && [ -n "$i" ] && [ "$m" -lt "$i" ]'

check "remote user uv.toml owned by vscode" bash -c '[ "$(stat -c %U /home/vscode/.config/uv/uv.toml)" = "vscode" ]'

check "root uv.toml present" sudo test -f /root/.config/uv/uv.toml

check "no allow-insecure-host when secure" bash -c '! grep -q "allow-insecure-host" /etc/uv/uv.toml'

reportResults
