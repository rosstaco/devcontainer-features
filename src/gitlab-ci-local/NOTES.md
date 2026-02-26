## About

Tired of pushing to test your `.gitlab-ci.yml`? `gitlab-ci-local` lets you run GitLab CI/CD pipelines locally as a shell executor or docker executor.

For more information, see: https://github.com/firecow/gitlab-ci-local

## How It Works

1. **Downloads the binary** from [firecow/gitlab-ci-local](https://github.com/firecow/gitlab-ci-local) GitHub releases
2. **Installs to** `/usr/local/bin/gitlab-ci-local`
3. **Supports** both `amd64` and `arm64` architectures

## Usage

Run a pipeline locally from a project with a `.gitlab-ci.yml`:

```bash
gitlab-ci-local
```

Run a specific job:

```bash
gitlab-ci-local --job <job-name>
```
