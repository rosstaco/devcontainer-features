#!/bin/bash

# Scenario 'nuget': nugetSource + nugetSourceName=corp (scope 'both').

set -e

source dev-container-features-test-lib

MACHINE="/etc/opt/NuGet/Config/NuGet.Config"
USERCFG="/home/vscode/.nuget/NuGet/NuGet.Config"
URL="https://proxy.internal/artifactory/api/nuget/v3/index.json"

check "machine-wide NuGet.Config exists" test -f "${MACHINE}"

check "NuGet config clears public sources" grep -qF "<clear />" "${MACHINE}"

check "NuGet config adds override source key" grep -qF 'key="corp"' "${MACHINE}"

check "NuGet config has override source url" grep -qF "${URL}" "${MACHINE}"

check "remote user NuGet.Config exists" test -f "${USERCFG}"

check "remote user NuGet.Config owned by vscode" bash -c '[ "$(stat -c %U '"${USERCFG}"')" = "vscode" ]'

reportResults
