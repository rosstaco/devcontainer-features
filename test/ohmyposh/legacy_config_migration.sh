#!/bin/bash

set -e

source dev-container-features-test-lib

# 1. Verify the helper script is installed
check "helper script installed" test -x /usr/local/bin/oh-my-posh-configure-shell

# 2. Simulate legacy configuration (no markers)
cat > ~/.bashrc << EOF
# Some initial content
export PATH=\$PATH:/something

# Oh My Posh configuration
if [ -s ~/.ohmyposh.json ]; then
    # Use custom theme if mounted
    eval "\$(oh-my-posh init bash --config ~/.ohmyposh.json)"
else
    # Use built-in theme
    eval "\$(oh-my-posh init bash --config jandedobbeleer)"
fi

# Some other content that should be preserved
export FOO=bar
EOF

# 3. Run the helper script
# We need to set USERNAME to root because the test runs as root
# and the helper script defaults to 'vscode' if not set.
export USERNAME=root
/usr/local/bin/oh-my-posh-configure-shell

# 4. Verify the result
# Read the last few lines of .bashrc
LAST_LINES=$(tail -n 10 ~/.bashrc)
echo "Last lines of .bashrc:"
echo "$LAST_LINES"

# Check if "oh-my-posh init" is in the last lines
check "oh-my-posh is at the end" bash -c "tail -n 10 ~/.bashrc | grep -q 'oh-my-posh init'"

# Check if markers are present
check "markers are present" grep -q "# region Oh My Posh configuration" ~/.bashrc

# Check if old config is gone (or at least the comment)
# We removed lines with "oh-my-posh init" and "# Oh My Posh configuration"
# But we added them back at the end.
# So we check if there is only ONE occurrence of the block (or markers)
COUNT=$(grep -c "# region Oh My Posh configuration" ~/.bashrc)
if [ "$COUNT" -eq 1 ]; then
    echo "✅ Only one configuration block found"
else
    echo "❌ Found $COUNT configuration blocks"
    exit 1
fi

# Check if FOO=bar is preserved and BEFORE the new block
POS_FOO=$(grep -n "export FOO=bar" ~/.bashrc | cut -d: -f1)
POS_OMP=$(grep -n "# region Oh My Posh configuration" ~/.bashrc | cut -d: -f1)

echo "FOO position: $POS_FOO"
echo "OMP position: $POS_OMP"

if [ "$POS_OMP" -gt "$POS_FOO" ]; then
    echo "✅ Oh My Posh config is after existing content"
else
    echo "❌ Oh My Posh config is NOT after existing content"
    exit 1
fi

reportResults
