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
                if ! awk -v start="$start_marker" -v end="$end_marker" '
                    $0 ~ start {skip=1; next}
                    $0 ~ end {skip=0; next}
                    !skip {print}
                ' "$rc_file" > "$temp_file"; then
                    echo "Error: Failed to process $rc_file"
                    rm -f "$temp_file"
                    return 1
                fi
                
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
            
            # Replace lines containing "oh-my-posh init" with ":" (no-op) to disable old config
            # while preserving syntax validity of surrounding if/else blocks.
            sed 's/^\([[:space:]]*\).*oh-my-posh init.*/\1:/' "$rc_file" > "$temp_file"
            
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

# Check bash
move_to_end "$HOME/.bashrc"

# Check zsh
move_to_end "$HOME/.zshrc"

