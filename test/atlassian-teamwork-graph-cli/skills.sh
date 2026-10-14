#!/bin/bash

# Scenario 'skills': installSkills=true installs TWG agent skills for the remote user.

set -e

source dev-container-features-test-lib

check "canonical twg skill installed" test -f /home/vscode/.agents/skills/twg/SKILL.md

check "claude twg skill installed" test -f /home/vscode/.claude/skills/twg/SKILL.md

check "skills owned by the remote user" bash -c '[ "$(stat -c %U /home/vscode/.agents/skills/twg/SKILL.md)" = vscode ]'

reportResults
