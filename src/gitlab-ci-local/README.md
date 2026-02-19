
# GitLab CI Local (gitlab-ci-local)

Installs gitlab-ci-local CLI for running GitLab CI/CD pipelines locally

## Example Usage

```json
"features": {
    "ghcr.io/rosstaco/devcontainer-features/gitlab-ci-local:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of gitlab-ci-local to install. Use 'latest' or a specific version like '4.67.0' | string | latest |

## About

Tired of pushing to test your `.gitlab-ci.yml`? `gitlab-ci-local` lets you run GitLab CI/CD pipelines locally as a shell executor or docker executor.

For more information, see: https://github.com/firecow/gitlab-ci-local

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/rosstaco/devcontainer-features/blob/main/src/gitlab-ci-local/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
