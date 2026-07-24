#!/bin/bash

# Scenario 'npm': only npmRegistry set (scope defaults to 'both', strictSsl true).

set -e

source dev-container-features-test-lib

REG="https://proxy.internal/artifactory/api/npm/npm-remote/"

check "system /etc/npmrc has registry" grep -qF "registry=${REG}" /etc/npmrc

check "root ~/.npmrc has registry" sudo grep -qF "registry=${REG}" /root/.npmrc

check "remote user ~/.npmrc has registry" grep -qF "registry=${REG}" /home/vscode/.npmrc

check "remote user ~/.npmrc owned by vscode" bash -c '[ "$(stat -c %U /home/vscode/.npmrc)" = "vscode" ]'

check "managed marker present" grep -qF "package-source-overrides" /etc/npmrc

check "strict-ssl not disabled when secure" bash -c '! grep -q "strict-ssl=false" /etc/npmrc'

reportResults
