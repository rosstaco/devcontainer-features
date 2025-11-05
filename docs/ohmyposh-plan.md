# Oh My Posh devcontainer feature - Implementation Plan

## Overview

Create a devcontainer feature to install Oh My Posh with comprehensive configuration options. The installation will use GitHub releases API to download pre-compiled binaries directly for reliability and version control.

## Feature Structure

```
src/ohmyposh/
├── devcontainer-feature.json
└── install.sh
```

## Configuration Options

Define in `devcontainer-feature.json`:

- **`version`** (string, default: "latest")
  - Oh My Posh version to install
  - Supports: "latest" or specific version like "v19.0.0"

- **`theme`** (string, default: "jandedobbeleer")
  - Built-in theme name to use as fallback
  - Examples: "powerlevel10k_rainbow", "dracula", "agnoster", "pure"

- **`installPath`** (string, default: "/usr/local/bin")
  - Binary installation location

- **`shells`** (string, default: "bash,zsh")
  - Comma-separated list of shells to configure
  - Options: "bash", "zsh", "fish"

## Installation Process (`install.sh`)

1. **Fetch binary from GitHub releases**
   - Use GitHub API to get latest/specific release
   - Detect architecture: amd64, arm64, arm
   - Download appropriate binary for Linux

2. **Install binary**
   - Move to specified `installPath`
   - Set execute permissions
   - Verify installation

3. **Create theme file placeholder**
   ```bash
   touch /home/vscode/.ohmyposh.json
   chown vscode:vscode /home/vscode/.ohmyposh.json
   ```

4. **Configure shells**
   - Parse `shells` option
   - Add init commands to respective rc files based on selected shells

## Shell Integration Logic

Add to shell rc files (`.bashrc`, `.zshrc`, `.config/fish/config.fish`):

```bash
# Check if user mounted a custom theme
if [ -s ~/.ohmyposh.json ]; then
  # File has content, use custom theme
  eval "$(oh-my-posh init <shell> --config ~/.ohmyposh.json)"
else
  # Empty or invalid, use built-in theme from feature option
  eval "$(oh-my-posh init <shell> --config <THEME>)"
fi
```

Where:
- `-s` checks if file exists and has content
- `<shell>` is replaced with actual shell (bash/zsh/fish)
- `<THEME>` is replaced with the theme option value

## Custom Theme Usage

### For Users

To use a custom Oh My Posh theme, add a mount to your `devcontainer.json`:

```jsonc
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/ohmyposh:1": {
      "theme": "jandedobbeleer",
      "shells": "bash,zsh"
    }
  },
  "mounts": [
    "source=${localEnv:HOME}/path/to/your/theme.json,target=/home/vscode/.ohmyposh.json,type=bind"
  ]
}
```

### How It Works

1. Feature creates `~/.ohmyposh.json` during installation (empty file)
2. Mount target always exists, so mount operation succeeds
3. If user doesn't mount: file remains empty → feature uses built-in theme
4. If user mounts their theme: file has content → feature uses custom theme
5. User has full control over source path (can be anywhere on host)

## Key Design Decisions

### 1. Single Theme File Location
- **Path**: `~/.ohmyposh.json`
- **Rationale**: Simple, predictable, always exists
- **Benefit**: No mount failures, clear documentation

### 2. Graceful Fallback
- Empty file = use built-in theme from feature option
- Invalid JSON = use built-in theme
- Missing file = impossible (feature creates it)

### 3. User Flexibility
- Mount source path is user's choice
- Can point to anywhere on host system
- Not restricted to `.config` or specific locations

### 4. No `initializeCommand` Required
- Feature creates target file during build
- Mount succeeds even if source doesn't exist on host
- Simpler user setup

## Implementation Steps

1. Create `src/ohmyposh/devcontainer-feature.json` with options schema
2. Create `src/ohmyposh/install.sh` with:
   - GitHub releases API integration
   - Architecture detection
   - Binary download and installation
   - Theme file creation
   - Shell configuration
3. Add error handling for:
   - Network failures
   - Architecture not supported
   - Invalid version specified
4. Test on multiple base images (debian, ubuntu, alpine if supported)
5. Document in auto-generated README

## Testing Scenarios

1. **Default installation** - no options, uses latest + jandedobbeleer theme
2. **Specific version** - `"version": "v19.0.0"`
3. **Different theme** - `"theme": "dracula"`
4. **Custom shells** - `"shells": "zsh"` or `"shells": "bash,fish"`
5. **With custom theme mount** - user provides own theme file
6. **Without custom theme mount** - falls back to built-in

## Documentation Notes

Include in generated README:

- List of popular built-in themes
- Link to Oh My Posh themes gallery
- Example of mounting custom theme
- Note about Nerd Fonts requirement for most themes
- Shell configuration details
- Troubleshooting common issues

## Future Enhancements (Optional)

- Add `autoUpgrade` option for automatic updates
- Support for theme URLs (remote themes)
- Cache directory configuration
- Multiple theme files support
- Theme validation during build
