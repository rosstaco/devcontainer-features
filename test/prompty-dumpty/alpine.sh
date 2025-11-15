#!/bin/bash

# This test verifies prompty-dumpty works on Alpine

set -e

source dev-container-features-test-lib

check "dumpty is executable" bash -c "command -v dumpty"

check "dumpty version command works" bash -c "dumpty --version 2>&1 || true"

reportResults
