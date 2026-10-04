## About

In locked-down environments you often cannot reach public package feeds
(`registry.npmjs.org`, `pypi.org`, `api.nuget.org`, …) and must go through an
internal pull-through proxy / mirror such as **JFrog Artifactory**, **Sonatype
Nexus**, or **Azure Artifacts**.

This Feature points **npm**, **pnpm**, **Yarn**, **Corepack**, **pip**, **uv**,
and **NuGet** at those override sources by writing their configuration, so that
**Features installed after it, and your projects, resolve packages through the
proxy**.

It only writes configuration — no network calls, no `apt`, and no assumption that
the package managers are already installed. Providing no URLs makes the Feature a
safe no-op.

## How It Works

For each URL you provide, the Feature writes the standard config files for every
tool that consumes that feed. Per-user config is written for **root** (package
installs run by other Features at build time run as root) and for the **remote
user** (runtime).

| Option | Tool | System scope | User scope (root + remote user) |
|--------|------|--------------|---------------------------------|
| `npmRegistry` | npm | `/etc/npmrc` (via the `NPM_CONFIG_GLOBALCONFIG` env var this Feature sets) | `~/.npmrc` |
| `npmRegistry` | pnpm, Yarn Classic | — (no system-wide config) | `~/.npmrc` (always written) |
| `npmRegistry` | Yarn Berry (v2+) | — (no system-wide config) | `~/.yarnrc.yml` `npmRegistryServer` (always written) |
| `npmRegistry` | Corepack | `COREPACK_NPM_REGISTRY` env var (see below) | — |
| `pipIndexUrl` | pip, pipx | `/etc/pip.conf` | `~/.config/pip/pip.conf` |
| `pipIndexUrl` | uv | `/etc/uv/uv.toml` | `~/.config/uv/uv.toml` |
| `uvPythonInstallMirror` | uv-managed Python downloads | `/etc/uv/uv.toml` `python-install-mirror` | `~/.config/uv/uv.toml` |
| `nugetSource` | NuGet / dotnet | `/etc/opt/NuGet/Config/NuGet.Config` | `~/.nuget/NuGet/NuGet.Config` |

- `scope` (`system`, `user`, `both`; default `both`) selects the columns above.
  pnpm and Yarn Berry have no system-wide config location, so their per-user
  files are written for every scope.
- **npm / pnpm / Yarn Classic** — `registry=` replaces the default registry.
- **Yarn Berry** ignores `.npmrc`; it reads `npmRegistryServer` from `~/.yarnrc.yml`.
- **pip** — `index-url` replaces the default PyPI index.
- **uv** ignores `pip.conf` and `PIP_INDEX_URL`; it uses an `[[index]]` with
  `default = true`. uv rejects unknown keys in `uv.toml`, so the file is kept
  minimal.
- **uv-managed Python** (`uv python install`, automatic downloads) normally comes
  from GitHub. Set `uvPythonInstallMirror` to a mirror of the
  `python-build-standalone` release downloads.
- **NuGet** — `<clear />` removes inherited sources, and `nuget.org` is also
  listed under `<disabledPackageSources>` so it stays off even when a
  higher-priority config (such as the .NET SDK's default user config) re-adds it.

`.npmrc` and `.yarnrc.yml` are updated inside a managed marker block so unrelated
settings are preserved (an existing `~/.yarnrc.yml` that already sets the
registry is left unchanged). `pip.conf`, `uv.toml`, and `NuGet.Config` are fully
managed by this Feature. Project-level configuration (a repository's own
`.npmrc`, `.yarnrc.yml`, `uv.toml`, `NuGet.Config`, …) still takes precedence.

## Install order

Dev container Features install in rounds; within a round the spec sorts Features
**alphabetically by their full registry path**. Features from
`ghcr.io/devcontainers/…` therefore install *before*
`ghcr.io/rosstaco/…`, and any of them that download packages (for example the
Python Feature installing its default tools with pip) would hit the public feeds
first. Make this Feature install first in one of these ways:

### Per repository: `overrideFeatureInstallOrder`

```jsonc
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/package-source-overrides:1": {
      "npmRegistry": "https://artifactory.example.com/artifactory/api/npm/npm-remote/",
      "pipIndexUrl": "https://artifactory.example.com/artifactory/api/pypi/pypi-remote/simple",
      "nugetSource": "https://artifactory.example.com/artifactory/api/nuget/v3/index.json"
    },
    "ghcr.io/devcontainers/features/node:1": {},
    "ghcr.io/devcontainers/features/python:1": {}
  },
  // Configure the override sources before anything installs packages
  "overrideFeatureInstallOrder": [
    "ghcr.io/rosstaco/devcontainer-features/package-source-overrides"
  ]
}
```

### Machine-wide: VS Code `dev.containers.defaultFeatures`

Adding this Feature to the VS Code user setting `dev.containers.defaultFeatures`
applies it to every dev container you open locally, but there is no global
equivalent of `overrideFeatureInstallOrder`, so on its own it installs *after*
the official Features. Add `common-utils` to the default Features as well: the
official Features (node, python, dotnet, java, go, rust, ruby, conda, powershell,
docker-in-docker, azure-cli, github-cli, …) declare
`installsAfter: common-utils`, which moves them to a later round — after this
Feature, which deliberately declares no `installsAfter`.

```jsonc
// VS Code user settings.json
"dev.containers.defaultFeatures": {
  "ghcr.io/devcontainers/features/common-utils:2": {
    "installZsh": false,
    "installOhMyZsh": false,
    "upgradePackages": false,
    "username": "none"
  },
  "ghcr.io/rosstaco/devcontainer-features/package-source-overrides:1": {
    "npmRegistry": "https://artifactory.example.com/artifactory/api/npm/npm-remote/",
    "pipIndexUrl": "https://artifactory.example.com/artifactory/api/pypi/pypi-remote/simple",
    "nugetSource": "https://artifactory.example.com/artifactory/api/nuget/v3/index.json"
  }
}
```

Caveats: `common-utils` runs `apt-get`, so your apt sources must be reachable.
Features that don't declare `installsAfter: common-utils` can still sort ahead
of this one. `defaultFeatures` only applies to the local VS Code Dev Containers
extension — not to Codespaces, the `devcontainer` CLI in CI, or other tools.

### Most robust: your base image

Configuration baked into your organization's base image exists before any
Feature runs.

If `npm`, `pip`, `uv`, `dotnet`, … already exist when this Feature runs, it prints
a warning: an earlier Feature (or the base image) installed them and may already
have fetched packages from public feeds.

## Environment-variable-only tools

**Corepack** (used via `corepack enable` and the `packageManager` field in
`package.json`) ignores `.npmrc` and can only be redirected with the
`COREPACK_NPM_REGISTRY` environment variable. Because `containerEnv` cannot
contain option values, the Feature writes such variables to
`/etc/package-source-overrides/env.sh`, which is sourced:

- **at runtime** by login shells via `/etc/profile.d/package-source-overrides.sh`
  (this includes VS Code's environment probe, terminals, and lifecycle commands);
- **at build time**, only when `bashEnvHook` is `true`: `BASH_ENV` makes every
  non-interactive bash process (such as the install scripts of Features that run
  after this one) source it. `sh`/`dash` scripts don't honor `BASH_ENV`.

`BASH_ENV` is always set to `/etc/package-source-overrides/bash_env` (static
`containerEnv`); the file only exists when `bashEnvHook` is enabled or when the
base image already had a `BASH_ENV`, which is chained so it keeps working.

## Notes

- **No authentication** is configured — the override sources are expected to allow
  anonymous access. Do not put credentials in the URL options (they would be baked
  into image layers).
- **Replace policy:** public feeds are replaced, not augmented. Only the override
  sources are consulted.
- **Self-signed / HTTP proxies:** set `strictSsl` to `false` to emit
  `strict-ssl=false` (npm), `enableStrictSsl: false` (Yarn Berry), `trusted-host`
  (pip), `allow-insecure-host` (uv), and `allowInsecureConnections` (NuGet). An
  `http://` npm registry is also added to Yarn Berry's `unsafeHttpWhitelist`.
  Leave `strictSsl` `true` whenever your proxy presents a trusted certificate.
- URL options must be `http(s)://` URLs without whitespace, quotes, backslashes,
  backticks, `$`, `<`, or `>`.
- Leave a URL empty to skip configuring the tools that use it.
