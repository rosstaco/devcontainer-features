#!/bin/bash

# Scenario 'bash-env-hook': bashEnvHook=true exports env-only overrides to every
# non-interactive bash process (e.g. install scripts of later Features).

set -e

source dev-container-features-test-lib

check "BASH_ENV hook file installed" test -f /etc/package-source-overrides/bash_env

check "containerEnv BASH_ENV points at the hook" bash -c '[ "$BASH_ENV" = "/etc/package-source-overrides/bash_env" ]'

check "clean non-interactive bash gets COREPACK_NPM_REGISTRY via BASH_ENV" bash -c 'out=$(env -i PATH="$PATH" BASH_ENV=/etc/package-source-overrides/bash_env bash -c "echo \$COREPACK_NPM_REGISTRY"); [ "$out" = "https://proxy.internal/npm" ]'

check "without BASH_ENV the variable is not set" bash -c 'out=$(env -i PATH="$PATH" bash -c "echo \$COREPACK_NPM_REGISTRY"); [ -z "$out" ]'

reportResults
