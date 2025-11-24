#!/bin/bash
set -e

cat > test.sh << EOF
# Oh My Posh configuration
if [ -s ~/.ohmyposh.json ]; then
    # Use custom theme if mounted
    eval "\$(oh-my-posh init bash --config ~/.ohmyposh.json)"
else
    # Use built-in theme
    eval "\$(oh-my-posh init bash --config jandedobbeleer)"
fi
EOF

sed 's/.*oh-my-posh init.*/    :/' test.sh > test.sh.tmp
mv test.sh.tmp test.sh

cat test.sh

# Check syntax
if bash -n test.sh; then
    echo "Syntax OK"
else
    echo "Syntax Error"
fi
