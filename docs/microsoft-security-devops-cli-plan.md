---
description: Implementation plan for adding Microsoft Security DevOps CLI (guardian) feature to devcontainer-features project
---

# Microsoft Security DevOps CLI Feature Implementation Plan

## Overview

Add a new devcontainer feature to install Microsoft Security DevOps CLI (`guardian` command) by downloading the architecture-specific nuget package, extracting binaries to a common location, and adding to PATH.

## Verified Information

- **Nuget API behavior**: `https://www.nuget.org/api/v2/package/Microsoft.Security.DevOps.Cli.linux-x64` without version parameter redirects to latest version (0.215.0 as of test)
- **Available architectures**: Only `linux-x64` and `linux-arm64` (no musl, arm, or other variants)
- **Command name**: `guardian` (Microsoft.Guardian.Cli binary name)
- **All binaries in tools/**: The nuget package contains all binaries in the `tools/` directory
- **Init command**: `guardian init --force` requires a git repository, so cannot be run during feature installation

## Implementation Steps

### 1. Create Feature Structure

Create `src/microsoft-security-devops-cli/` directory with:

#### `devcontainer-feature.json`
```json
{
  "id": "microsoft-security-devops-cli",
  "version": "1.0.0",
  "name": "Microsoft Security DevOps CLI",
  "description": "Installs Microsoft Security DevOps CLI (guardian) for running security analysis tools",
  "documentationURL": "https://github.com/rosstaco/devcontainer-features/tree/main/src/microsoft-security-devops-cli",
  "options": {
    "version": {
      "type": "string",
      "default": "latest",
      "description": "Version of Microsoft Security DevOps CLI to install. Use 'latest' or a specific version like '0.215.0'"
    },
    "installPath": {
      "type": "string",
      "default": "/usr/local/bin/guardian",
      "description": "Directory where the guardian binaries will be installed"
    }
  },
  "installsAfter": [
    "ghcr.io/devcontainers/features/common-utils"
  ]
}
```

#### `install.sh`
Key requirements:
- Use `set -e` for error handling
- Detect architecture: `x86_64` → `linux-x64`, `aarch64|arm64` → `linux-arm64`, else error
- Read options: `VERSION="${VERSION:-latest}"`, `INSTALL_PATH="${INSTALLPATH:-/usr/local/bin/guardian}"`
- Build download URL:
  - For "latest": `https://www.nuget.org/api/v2/package/Microsoft.Security.DevOps.Cli.${ARCH}`
  - For specific version: `https://www.nuget.org/api/v2/package/Microsoft.Security.DevOps.Cli.${ARCH}/${VERSION}`
- Download to temp file (e.g., `/tmp/guardian-cli.nupkg`)
- Unzip to temp directory (e.g., `/tmp/guardian-extract`)
- Copy all files from `tools/*` to `$INSTALL_PATH`
- Set executable permissions: `chmod +x $INSTALL_PATH/*` or individually for binaries
- Verify installation: `guardian --version`
- Output completion message with hint about `guardian init --force` command
- Use colored output (GREEN, RED, YELLOW, NC) like ohmyposh pattern

### 2. Create Test Structure

Create `test/microsoft-security-devops-cli/` directory with:

#### `scenarios.json`
```json
{
    "version": {
        "image": "ubuntu:latest",
        "features": {
            "microsoft-security-devops-cli": {
                "version": "0.215.0"
            }
        }
    },
    "custom-install-path": {
        "image": "ubuntu:latest",
        "features": {
            "microsoft-security-devops-cli": {
                "installPath": "/usr/bin"
            }
        }
    }
}
```

#### `test.sh`
Tests to implement:
```bash
#!/bin/bash
set -e
source dev-container-features-test-lib

check "guardian is installed" guardian --version
check "guardian is executable" which guardian
check "guardian binary in correct location" test -x /usr/local/bin/guardian/guardian
check "guardian can show help" guardian --help

reportResults
```

#### Additional test files (optional):
- `version.sh` - Test specific version installation
- `custom-install-path.sh` - Test custom installation path

### 3. Update Project Documentation

Update `README.md` to add new feature section after Oh My Posh:

```markdown
### Microsoft Security DevOps CLI

Installs [Microsoft Security DevOps CLI](https://aka.ms/msdodocs) (`guardian` command) for running security analysis tools without requiring .NET installation.

**Usage:**

```json
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/microsoft-security-devops-cli:1": {
      "version": "latest",
      "installPath": "/usr/local/bin"
    }
  }
}
```

**Options:**
- `version` - Version to install (default: "latest"). Use "latest" or a specific version like "0.215.0"
- `installPath` - Installation directory (default: "/usr/local/bin")

**Supported Architectures:**
- linux-x64 (x86_64)
- linux-arm64 (aarch64)

**Running Guardian:**

After installation, the `guardian` command is available in your PATH. To initialize guardian in your repository:

```bash
guardian init --force
```

Note: `guardian init` requires a git repository, so it must be run manually after the container starts (not during feature installation).
```

### 4. Update Justfile (Optional)

Add build command for new feature:

```justfile
# Build Microsoft Security DevOps CLI feature
build-microsoft-security-devops-cli:
    just build-feature microsoft-security-devops-cli

# Build all features
build-all:
    just build-ohmyposh
    just build-microsoft-security-devops-cli
```

## Key Design Decisions

1. **No curl/unzip checks**: Rely on `common-utils` feature via `installsAfter` to ensure dependencies are available
2. **Simple version handling**: "latest" uses API without version parameter (auto-redirects), specific versions use full URL path
3. **Copy entire tools/ directory**: Install all binaries from nuget package's tools folder to support any dependencies
4. **No auto-init**: Don't run `guardian init --force` automatically as it requires a git repository
5. **Minimal options**: Only version and installPath, keeping it simple like the user requested
6. **Error on unsupported arch**: Clear error messages for architectures that don't have nuget packages

## Installation Flow

```
1. Feature detects architecture (x86_64 or aarch64)
2. Maps to nuget package variant (linux-x64 or linux-arm64)
3. Downloads .nupkg file from nuget.org API
4. Extracts to temporary directory
5. Copies tools/* binaries to install path
6. Sets executable permissions
7. Verifies guardian --version works
8. Outputs completion message with init instructions
```

## Testing Strategy

1. **Default test**: Install latest version to /usr/local/bin on ubuntu:latest
2. **Version test**: Install specific version (0.215.0)
3. **Custom path test**: Install to /usr/bin instead of default
4. **Verification**: Each test confirms binary exists, is executable, in PATH, and runs successfully

## Future Enhancements (Not in Initial Implementation)

- Support for macOS architectures (osx-x64, osx-arm64) if needed
- Automatic guardian init if git repo detected
- Configuration file support
- Tool-specific version pinning
