#!/bin/bash

# Scenario 'all-insecure': all three ecosystems with strictSsl=false. Asserts the
# insecure/self-signed settings are emitted for each package manager.

set -e

source dev-container-features-test-lib

check "npm strict-ssl disabled" grep -qF "strict-ssl=false" /etc/npmrc

check "pip trusted-host set to proxy host" grep -qF "trusted-host = proxy.internal" /etc/pip.conf

check "NuGet allowInsecureConnections enabled" grep -qF 'allowInsecureConnections="true"' /etc/opt/NuGet/Config/NuGet.Config

reportResults
