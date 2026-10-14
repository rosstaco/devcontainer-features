#!/bin/bash

# Scenario 'opt-outs': enableTelemetry=true, persistAuth=false, configureBrowser=false.

set -e

source dev-container-features-test-lib

check "twg is on PATH" command -v twg

check "no telemetry env file" bash -c '[ ! -e /etc/atlassian-teamwork-graph-cli/env.sh ]'

check "no BASH_ENV hook file" bash -c '[ ! -e /etc/atlassian-teamwork-graph-cli/bash_env ]'

check "login shells do not get DO_NOT_TRACK" bash -c '[ -z "$(bash -lc "echo \$DO_NOT_TRACK")" ]'

check "~/.config/twg is not symlinked to the volume" bash -c '[ ! -L /home/vscode/.config/twg ]'

check "xdg-open shim not installed" bash -c '[ ! -e /usr/local/bin/xdg-open ]'

reportResults
