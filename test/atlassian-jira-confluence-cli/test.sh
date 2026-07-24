#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'acli' Feature with no options.
#
# Thus, the value of all options will fall back to the default value in the
# Feature's 'devcontainer-feature.json'.
#
# These scripts are run as 'root' by default. Although that can be changed
# with the '--remote-user' flag.

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
check "acli is executable" command -v acli

check "acli binary exists" test -x /usr/local/bin/acli

check "acli version command works" bash -c "acli --version 2>&1 | grep -q '[0-9]\+\.[0-9]\+\.[0-9]\+'"

check "acli reports itself as acli" bash -c "acli --version 2>&1 | grep -q 'acli'"

check "acli jira command available" bash -c "acli jira --help 2>&1 | grep -q 'Jira'"

check "acli confluence command available" bash -c "acli confluence --help 2>&1 | grep -q 'Confluence'"

# The feature installs an xdg-open shim (configureBrowser defaults to true) so
# 'acli auth login' opens the OAuth page via $BROWSER instead of in-container.
check "xdg-open shim installed" test -x /usr/local/bin/xdg-open

check "xdg-open shim prefers \$BROWSER" bash -c '
  marker="$(mktemp)"
  fake="$(mktemp)"
  printf "#!/bin/sh\necho \"\$1\" > \"%s\"\n" "$marker" > "$fake"
  chmod +x "$fake"
  BROWSER="$fake" /usr/local/bin/xdg-open "https://example.com/oauth" >/dev/null 2>&1
  grep -q "https://example.com/oauth" "$marker"
'

# Report results
reportResults
