# Dev Container Features

Custom [dev container Features](https://containers.dev/implementors/features/) for enhancing development containers, hosted on GitHub Container Registry. This repository follows the [dev container Feature distribution specification](https://containers.dev/implementors/features-distribution/).

## Available Features

### Oh My Posh

Installs [Oh My Posh](https://ohmyposh.dev/), a prompt theme engine for customizing your shell prompt across bash, zsh, and fish.

**Usage:**

```json
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/ohmyposh:1": {
      "version": "latest",
      "theme": "jandedobbeleer",
      "installPath": "/usr/local/bin",
      "shells": "bash,zsh"
    }
  }
}
```

**Options:**
- `version` - Oh My Posh version to install (default: "latest")
- `theme` - Built-in theme name to use (default: "jandedobbeleer")
- `installPath` - Installation directory (default: "/usr/local/bin")
- `shells` - Comma-separated list of shells to configure: bash, zsh, fish (default: "bash,zsh")

**Custom Themes:**

To use a custom theme file from your host machine, add a mount in your `devcontainer.json`:

```json
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/ohmyposh:1": {}
  },
  "mounts": [
    "source=${localEnv:HOME}/path/to/theme.json,target=/home/vscode/.ohmyposh.json,type=bind"
  ]
}
```

The feature creates a placeholder file at `~/.ohmyposh.json` during installation. If you mount a custom theme to this location, it will be used automatically. Otherwise, the built-in theme specified in the options will be used.

### Microsoft Security DevOps CLI

Installs [Microsoft Security DevOps CLI](https://aka.ms/msdodocs) (`guardian` command) for running security analysis tools without requiring .NET installation.

**Usage:**

```json
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/microsoft-security-devops-cli:1": {
      "version": "latest"
    }
  }
}
```

**Options:**
- `version` - Version to install (default: "latest"). Use "latest" or a specific version like "0.215.0"
- `installPath` - Installation directory (default: "/usr/local/bin/guardian")

**Supported Architectures:**
- linux-x64 (x86_64)
- linux-arm64 (aarch64)

**Running Guardian:**

After installation, the `guardian` command is available in your PATH. To initialize guardian in your repository:

```bash
guardian init --force
```

Note: `guardian init` requires a git repository, so it must be run manually after the container starts (not during feature installation).

### Copilot CLI Persistence

Persists GitHub Copilot CLI settings and chat history across container rebuilds using a named Docker volume.

**Usage:**

```json
{
  "features": {
    "ghcr.io/devcontainers/features/copilot-cli:1": {},
    "ghcr.io/rosstaco/devcontainer-features/copilot-persistence:1": {}
  }
}
```

**How It Works:**
- Mounts a named volume (scoped per dev container) to `/copilot-data`
- Creates a symlink from `~/.copilot` → `/copilot-data`
- Sets the `COPILOT_DATA_DIR` environment variable to `/copilot-data`

**What Persists:**
- Chat history and sessions
- CLI configuration (model preferences, settings)
- Command history
- Trusted folders

### Atlassian CLI for Jira & Confluence

Installs the [Atlassian CLI](https://developer.atlassian.com/cloud/acli/) (`acli`) for working with Jira and Confluence Cloud from the command line.

**Usage:**

```json
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/atlassian-jira-confluence-cli:1": {
      "version": "latest"
    }
  }
}
```

**Options:**
- `version` - Version of acli to install (default: "latest"). Use "latest" or a specific version like "1.3.21"
- `installPath` - Directory where the acli binary will be installed (default: "/usr/local/bin")
- `configureBrowser` - Install an `xdg-open` shim that prefers `$BROWSER` so `acli auth login` opens on your host (default: `true`)

**Supported Architectures:**
- amd64 (x86_64)
- arm64 (aarch64)

**Getting Started:**

After the container starts, authenticate once and then use the Jira and Confluence commands:

```bash
acli auth login
acli jira project list
```

**Browser Login:**

`acli auth login` opens an OAuth page via `xdg-open`, which doesn't honor `$BROWSER` inside a dev container. With `configureBrowser` enabled (the default), the feature installs a small `xdg-open` shim at `/usr/local/bin/xdg-open` that prefers `$BROWSER` (such as the VS Code browser helper) so the login page opens on your host machine. Set `configureBrowser` to `false` to skip it.

## Publishing

This repository uses a **GitHub Action** [workflow](.github/workflows/release.yaml) that publishes each Feature to GHCR (GitHub Container Registry).

Features in this repository are referenced with:

```
ghcr.io/rosstaco/devcontainer-features/<feature>:1
```

### Marking Feature Public

By default, GHCR packages are marked as `private`. To make them publicly accessible, navigate to the Feature's package settings page in GHCR and set the visibility to `public`:

```
https://github.com/users/rosstaco/packages/container/devcontainer-features%2F<featureName>/settings
```

### Adding Features to the Index

To add Features to the [public index](https://containers.dev/features):

* Go to [github.com/devcontainers/devcontainers.github.io](https://github.com/devcontainers/devcontainers.github.io)
* Open a PR to modify the [collection-index.yml](https://github.com/devcontainers/devcontainers.github.io/blob/gh-pages/_data/collection-index.yml) file

This allows tools like VS Code Dev Containers and GitHub Codespaces to surface your Features in their creation UI.
