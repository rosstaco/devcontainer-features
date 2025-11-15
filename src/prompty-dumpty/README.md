
# Prompty Dumpty (prompty-dumpty)

Installs prompty-dumpty CLI tool for managing prompty files

## Example Usage

```json
"features": {
    "ghcr.io/rosstaco/devcontainer-features/prompty-dumpty:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of prompty-dumpty to install. Use 'latest' or a specific version like '0.6.2' | string | latest |

## Usage

After installation, the `dumpty` command will be available:

```bash
dumpty --help
dumpty --version
```

## Notes

This feature installs prompty-dumpty system-wide using pip3 with the `--break-system-packages` flag, which is appropriate for containerized development environments. Python 3 is assumed to be present in the base image.

For more information about prompty-dumpty, visit: https://pypi.org/project/prompty-dumpty/

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/rosstaco/devcontainer-features/blob/main/src/prompty-dumpty/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
