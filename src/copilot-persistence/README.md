# Copilot CLI Persistence Feature

This devcontainer feature persists GitHub Copilot CLI settings and chat history across container rebuilds.

## How It Works

Inspired by the [shell-history pattern](https://github.com/stuartleeks/dev-container-features/tree/main/src/shell-history), this feature:

1. **Mounts a named volume** (scoped per dev container via `${devcontainerId}`) to `/copilot-data`
2. **Creates a symlink** from `~/.copilot` → `/copilot-data`
3. **Sets ownership** to the container user during installation (auto-detects from `$_REMOTE_USER`)


## What Persists

- ✅ Chat history and sessions
- ✅ CLI configuration (model preferences, settings)
- ✅ Command history
- ✅ Trusted folders

## Usage

```json
{
  "features": {
    "ghcr.io/devcontainers/features/copilot-cli:1": {},
    "ghcr.io/rosstaco/devcontainer-features/copilot-persistence:1": {}
  }
}
```

## Benefits Over Direct Mount

- No permission conflicts (volume created in neutral location)
- Works even if Copilot CLI has XDG_CONFIG_HOME bugs
- Clean lifecycle management during feature install
- Easy to share across projects

## Troubleshooting

View the volume data:
```bash
ls -la /copilot-data
```

Check the symlink:
```bash
ls -la ~/.copilot
```
