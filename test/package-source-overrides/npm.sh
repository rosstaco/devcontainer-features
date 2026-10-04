#!/bin/bash

# Scenario 'npm': only npmRegistry set (scope defaults to 'both', strictSsl true).

set -e

source dev-container-features-test-lib

REG="https://proxy.internal/artifactory/api/npm/npm-remote/"
REG_NOSLASH="${REG%/}"

check "system /etc/npmrc has registry" grep -qF "registry=${REG}" /etc/npmrc

check "root ~/.npmrc has registry" sudo grep -qF "registry=${REG}" /root/.npmrc

check "remote user ~/.npmrc has registry" grep -qF "registry=${REG}" /home/vscode/.npmrc

check "remote user ~/.npmrc owned by vscode" bash -c '[ "$(stat -c %U /home/vscode/.npmrc)" = "vscode" ]'

check "managed marker present" grep -qF "package-source-overrides" /etc/npmrc

check "strict-ssl not disabled when secure" bash -c '! grep -q "strict-ssl=false" /etc/npmrc'

check "remote user ~/.yarnrc.yml sets npmRegistryServer (no trailing slash)" grep -qxF "npmRegistryServer: \"${REG_NOSLASH}\"" /home/vscode/.yarnrc.yml

check "root ~/.yarnrc.yml sets npmRegistryServer" sudo grep -qxF "npmRegistryServer: \"${REG_NOSLASH}\"" /root/.yarnrc.yml

check "remote user ~/.yarnrc.yml owned by vscode" bash -c '[ "$(stat -c %U /home/vscode/.yarnrc.yml)" = "vscode" ]'

check "Yarn strict SSL untouched when secure" bash -c '! grep -q "enableStrictSsl" /home/vscode/.yarnrc.yml'

check "Corepack registry exported to login shells" bash -c "[ \"\$(env -i HOME=/home/vscode PATH=\"\$PATH\" bash -lc 'echo \$COREPACK_NPM_REGISTRY' | tail -1)\" = '${REG_NOSLASH}' ]"

check "BASH_ENV hook not created when disabled" bash -c '[ ! -e /etc/package-source-overrides/bash_env ]'

reportResults
