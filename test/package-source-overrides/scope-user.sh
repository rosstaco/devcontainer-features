#!/bin/bash

# Scenario 'scope-user': scope=user should write per-user config (root + remote
# user) but NOT the system-wide files.

set -e

source dev-container-features-test-lib

check "root ~/.npmrc present" sudo test -f /root/.npmrc

check "remote user ~/.npmrc present" test -f /home/vscode/.npmrc

check "remote user pip.conf present" test -f /home/vscode/.config/pip/pip.conf

check "system /etc/npmrc absent" bash -c '[ ! -e /etc/npmrc ]'

check "system /etc/pip.conf absent" bash -c '[ ! -e /etc/pip.conf ]'

reportResults
