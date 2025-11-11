
# Microsoft Security DevOps CLI (microsoft-security-devops-cli)

Installs Microsoft Security DevOps CLI (guardian) for running security analysis tools

## Example Usage

```json
"features": {
    "ghcr.io/rosstaco/devcontainer-features/microsoft-security-devops-cli:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of Microsoft Security DevOps CLI to install. Use 'latest' or a specific version like '0.215.0' | string | latest |
| installPath | Directory where the guardian binaries will be installed | string | /usr/local/bin/guardian |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/rosstaco/devcontainer-features/blob/main/src/microsoft-security-devops-cli/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
