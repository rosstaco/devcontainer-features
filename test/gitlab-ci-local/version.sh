#!/bin/bash

# This test verifies that a specific version can be installed

set -e

source dev-container-features-test-lib

check "gitlab-ci-local is executable" command -v gitlab-ci-local

check "gitlab-ci-local version command works" bash -c "gitlab-ci-local --version 2>&1 | grep -q '[0-9]\+\.[0-9]\+\.[0-9]\+'"

reportResults
