#!/bin/bash

# Scenario 'all-insecure': every ecosystem with strictSsl=false and an http://
# npm registry. Asserts the insecure/self-signed settings for each package manager.

set -e

source dev-container-features-test-lib

check "npm strict-ssl disabled" grep -qF "strict-ssl=false" /etc/npmrc

check "pip trusted-host set to proxy host" grep -qF "trusted-host = proxy.internal" /etc/pip.conf

check "NuGet allowInsecureConnections enabled" grep -qF 'allowInsecureConnections="true"' /etc/opt/NuGet/Config/NuGet.Config

check "Yarn strict SSL disabled" grep -qxF "enableStrictSsl: false" /home/vscode/.yarnrc.yml

check "Yarn allows the http:// registry host (hostname only)" grep -qxF '  - "proxy.internal"' /home/vscode/.yarnrc.yml

check "uv allow-insecure-host lists the proxy host once" grep -qxF 'allow-insecure-host = ["proxy.internal"]' /etc/uv/uv.toml

reportResults
