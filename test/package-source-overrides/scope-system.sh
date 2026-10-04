#!/bin/bash

# Scenario 'scope-system': system-wide files only, except pnpm and Yarn Berry,
# which have no system-wide config and always get per-user files.

set -e

source dev-container-features-test-lib

check "system /etc/npmrc present" test -f /etc/npmrc

check "per-user ~/.npmrc still written for pnpm" test -f /home/vscode/.npmrc

check "per-user ~/.yarnrc.yml still written for Yarn Berry" test -f /home/vscode/.yarnrc.yml

check "system /etc/pip.conf present" test -f /etc/pip.conf

check "no per-user pip.conf" bash -c '[ ! -e /home/vscode/.config/pip/pip.conf ]'

check "system /etc/uv/uv.toml present" test -f /etc/uv/uv.toml

check "no per-user uv.toml" bash -c '[ ! -e /home/vscode/.config/uv/uv.toml ]'

check "machine-wide NuGet.Config disables nuget.org" grep -qF '<add key="nuget.org" value="true" />' /etc/opt/NuGet/Config/NuGet.Config

check "no per-user NuGet.Config" bash -c '[ ! -e /home/vscode/.nuget/NuGet/NuGet.Config ]'

reportResults
