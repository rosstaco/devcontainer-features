## How It Works

Inspired by the [shell-history pattern](https://github.com/stuartleeks/dev-container-features/tree/main/src/shell-history), this feature:

1. **Mounts a named volume** (scoped per dev container via `${devcontainerId}`) to `/copilot-data`
2. **Creates a symlink** from `~/.copilot` → `/copilot-data`
3. **Sets ownership** to the container user during installation (auto-detects from `$_REMOTE_USER`)

> **Note:** If `~/.copilot` already exists as a directory during installation, it is moved into the volume at `/copilot-data/migrated-<timestamp>/` before the symlink is created.

## What Persists

- ✅ Chat history and sessions
- ✅ CLI configuration (model preferences, settings)
- ✅ Command history
- ✅ Trusted folders

## Troubleshooting

View the volume data:
```bash
ls -la /copilot-data
```

Check the symlink:
```bash
ls -la ~/.copilot
```
