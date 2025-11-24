#!/bin/bash
set -e

# This script ensures Oh My Posh configuration is at the end of shell RC files
# to avoid being overwritten by other features (like shell-history).

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
            # grep -v "oh-my-posh init" "$rc_file" | grep -v "# Oh My Posh configuration" > "$temp_file"
            
            # Replace lines containing "oh-my-posh init" with ":" (no-op) to disable old config
            # while preserving syntax validity of surrounding if/else blocks.
            sed 's/.*oh-my-posh init.*/    :/' "$rc_file" > "$temp_file"
            
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

# Determine the user
if [ -n "$_REMOTE_USER" ]; then
    USER_NAME="$_REMOTE_USER"
elif [ -n "$REMOTE_USER" ]; then
    USER_NAME="$REMOTE_USER"
else
    USER_NAME="${USERNAME:-vscode}"
fi

USER_HOME=$(eval echo "~$USER_NAME")

# Check bash
move_to_end "$USER_HOME/.bashrc"

# Check zsh
move_to_end "$USER_HOME/.zshrc"

# Check fish
if [ -f "$USER_HOME/.config/fish/config.fish" ]; then
    # Fish syntax is different, so we handle it separately or adapt move_to_end
    # For now, let's just check if oh-my-posh init is present and move it to end
    # Fish doesn't use PROMPT_COMMAND conflict in the same way, but good to be consistent.
    # However, shell-history for fish uses a symlink or function override, so it might not conflict.
    # But let's be safe.
    
    FISH_CONFIG="$USER_HOME/.config/fish/config.fish"
    if grep -q "oh-my-posh init" "$FISH_CONFIG"; then
        echo "Ensuring Oh My Posh configuration is at the end of $FISH_CONFIG..."
        # Simple move to end for fish
        grep -v "oh-my-posh init" "$FISH_CONFIG" > "${FISH_CONFIG}.tmp"
        echo "" >> "${FISH_CONFIG}.tmp"
        echo "oh-my-posh init fish --config ~/.ohmyposh.json | source" >> "${FISH_CONFIG}.tmp" # Simplified for now, assuming standard init
        # Actually, let's preserve the original logic if possible or just leave fish alone if it's not broken.
        # The user issue was specifically about PROMPT_COMMAND which is Bash/Zsh.
        # Let's skip fish for now to avoid breaking it with incorrect syntax assumptions.
        echo "Skipping fish configuration adjustment."
    fi
fi
