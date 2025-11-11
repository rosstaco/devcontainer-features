
# Oh My Posh (ohmyposh)

A prompt theme engine for any shell with customizable themes and segments

## Example Usage

```json
"features": {
    "ghcr.io/rosstaco/devcontainer-features/ohmyposh:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of Oh My Posh to install. Use 'latest' or a specific version like 'v19.0.0' | string | latest |
| theme | Built-in theme name to use as fallback (e.g., 'jandedobbeleer', 'powerlevel10k_rainbow', 'dracula', 'agnoster') | string | jandedobbeleer |
| installPath | Directory where the oh-my-posh binary will be installed | string | /usr/local/bin |
| shells | Comma-separated list of shells to configure (bash, zsh, fish) | string | bash,zsh |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/rosstaco/devcontainer-features/blob/main/src/ohmyposh/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
