#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'atlassian-teamwork-graph-cli' Feature with no options, so every
# option falls back to its default in 'devcontainer-feature.json'.

set -e

source dev-container-features-test-lib

USER_HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"

check "twg is on PATH" command -v twg

check "/usr/local/bin/twg symlinks to the user-local binary" bash -c '[ -L /usr/local/bin/twg ] && [ -x "$(readlink /usr/local/bin/twg)" ]'

check "twg version command works" bash -c "twg -v 2>&1 | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+'"

check "twg jira command available" bash -c "twg jira --help 2>&1 | grep -qi 'jira'"

check "twg doctor runs without login" bash -c "twg doctor 2>&1 | grep -q 'Version:'"

# enableTelemetry defaults to false
check "telemetry env file disables tracking" grep -q 'DO_NOT_TRACK=1' /etc/atlassian-teamwork-graph-cli/env.sh

check "login shells get DO_NOT_TRACK" bash -c '[ "$(bash -lc "echo \$DO_NOT_TRACK")" = "1" ]'

check "containerEnv BASH_ENV points at the hook" bash -c '[ "$BASH_ENV" = "/etc/atlassian-teamwork-graph-cli/bash_env" ]'

check "clean non-interactive bash gets telemetry vars via BASH_ENV" bash -c 'out=$(env -i PATH="$PATH" BASH_ENV=/etc/atlassian-teamwork-graph-cli/bash_env bash -c "echo \$DO_NOT_TRACK:\$TWG_DISABLE_3P_DATA_TELEMETRY"); [ "$out" = "1:1" ]'

# persistAuth defaults to true
check "~/.config/twg is symlinked to the volume" bash -c "[ \"\$(readlink '${USER_HOME}/.config/twg')\" = /twg-config ]"

check "twg config volume is writable" test -w /twg-config

# installSkills defaults to false
check "skills not installed by default" bash -c "[ ! -e '${USER_HOME}/.agents/skills/twg' ]"

check "xdg-open shim installed" test -x /usr/local/bin/xdg-open

check "xdg-open shim prefers \$BROWSER" bash -c '
  marker="$(mktemp)"
  fake="$(mktemp)"
  printf "#!/bin/sh\necho \"\$1\" > \"%s\"\n" "$marker" > "$fake"
  chmod +x "$fake"
  BROWSER="$fake" /usr/local/bin/xdg-open "https://example.com/oauth" >/dev/null 2>&1
  grep -q "https://example.com/oauth" "$marker"
'

reportResults
