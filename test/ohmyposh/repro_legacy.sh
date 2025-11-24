#!/bin/bash
set -e

# Mock environment
USER_HOME=$(pwd)
RC_FILE="$USER_HOME/.bashrc_repro"

# Create legacy file
cat > "$RC_FILE" << EOF
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

echo "--- Initial Content ---"
cat "$RC_FILE"
echo "-----------------------"

# Define the function exactly as in the file
move_to_end() {
    local rc_file="$1"
    local start_marker="# region Oh My Posh configuration"
    local end_marker="# endregion Oh My Posh configuration"
    
    if [ -f "$rc_file" ]; then
        # Check for the region markers
        if grep -q "$start_marker" "$rc_file"; then
            echo "Ensuring Oh My Posh configuration is at the end of $rc_file..."
            
            # Extract the block
            local block=$(sed -n "/$start_marker/,/$end_marker/p" "$rc_file")
            
            if [ -n "$block" ]; then
                # Create a temp file
                local temp_file=$(mktemp)
                
                # Write file content WITHOUT the block to temp file
                # We use awk to exclude the range
                awk -v start="$start_marker" -v end="$end_marker" '
                    $0 ~ start {skip=1}
                    !skip {print}
                    $0 ~ end {skip=0}
                ' "$rc_file" > "$temp_file"
                
                # Append the block to the end
                echo "" >> "$temp_file"
                echo "$block" >> "$temp_file"
                
                # Replace original file
                mv "$temp_file" "$rc_file"
                
                echo "Moved Oh My Posh configuration to the end of $rc_file"
            fi
        # Fallback: Check for old configuration without markers
        elif grep -q "oh-my-posh init" "$rc_file"; then
            echo "Found legacy Oh My Posh configuration in $rc_file. Moving to end and adding markers..."
            
            # Create a temp file
            local temp_file=$(mktemp)
            
            # Remove lines containing "oh-my-posh init" and surrounding if/else block if possible
            # This is harder to do reliably with regex, so we'll just comment out the old init line
            # and add a new block at the end.
            
            # Actually, let's just append the new block and assume the old one will be overridden or harmless
            # if it's not setting PROMPT_COMMAND in a conflicting way.
            # But the old one DOES set PROMPT_COMMAND via eval.
            
            # Let's try to remove the old block if it matches the standard pattern
            # Standard pattern:
            # # Oh My Posh configuration
            # if [ -s ~/.ohmyposh.json ]; then
            # ...
            # fi
            
            # We'll use a simpler approach: Remove any lines containing "oh-my-posh init" 
            # and the specific comment "# Oh My Posh configuration"
            
            # Use a temp file for grep output to avoid issues with reading/writing same file
            grep -v "oh-my-posh init" "$rc_file" | grep -v "# Oh My Posh configuration" > "$temp_file"
            
            # Replace original file with cleaned content
            mv "$temp_file" "$rc_file"

            # Append new block
            # Determine shell from filename
            local shell_name="bash"
            if [[ "$rc_file" == *".zshrc" ]]; then
                shell_name="zsh"
            fi

            # Use echo to append to avoid issues with cat and EOF in some environments or if file is empty
            echo "" >> "$rc_file"
            echo "$start_marker" >> "$rc_file"
            echo "if [ -s ~/.ohmyposh.json ]; then" >> "$rc_file"
            echo "    eval \"\$(oh-my-posh init $shell_name --config ~/.ohmyposh.json)\"" >> "$rc_file"
            echo "else" >> "$rc_file"
            echo "    eval \"\$(oh-my-posh init $shell_name --config jandedobbeleer)\"" >> "$rc_file"
            echo "fi" >> "$rc_file"
            echo "$end_marker" >> "$rc_file"
            
            echo "Updated legacy configuration in $rc_file"
        fi
    fi
}

# Run it
move_to_end "$RC_FILE"

echo "--- Final Content ---"
cat "$RC_FILE"
echo "---------------------"

# Check for markers
if grep -q "# region Oh My Posh configuration" "$RC_FILE"; then
    echo "✅ Markers found"
else
    echo "❌ Markers NOT found"
fi
