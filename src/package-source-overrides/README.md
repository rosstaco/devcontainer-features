
# Package Source Overrides (package-source-overrides)

Configure npm, pnpm, pip, and NuGet to use internal override package sources instead of public feeds, early in the container lifecycle so other Features resolve packages through them too

## Example Usage

```json
"features": {
    "ghcr.io/rosstaco/devcontainer-features/package-source-overrides:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| npmRegistry | Registry URL for npm and pnpm (they share .npmrc). Leave empty to skip npm/pnpm. Example: https://artifactory.example.com/artifactory/api/npm/npm-remote/ | string | - |
| pipIndexUrl | pip / PyPI index URL that replaces the default index. Leave empty to skip pip. Example: https://artifactory.example.com/artifactory/api/pypi/pypi-remote/simple | string | - |
| nugetSource | NuGet v3 package source URL that replaces nuget.org. Leave empty to skip NuGet. Example: https://artifactory.example.com/artifactory/api/nuget/v3/nuget-remote/index.json | string | - |
| nugetSourceName | Friendly key/name for the configured NuGet package source | string | override |
| scope | Where configuration is written: 'system' (system-wide files), 'user' (root + remote user home), or 'both' | string | both |
| strictSsl | When false, allow self-signed/insecure internal proxies (npm strict-ssl=false, pip trusted-host, NuGet allowInsecureConnections) | boolean | true |

## About

In locked-down environments you often cannot reach public package feeds
(`registry.npmjs.org`, `pypi.org`, `api.nuget.org`, …) and must go through an
internal pull-through proxy / mirror such as **JFrog Artifactory**, **Sonatype
Nexus**, or **Azure Artifacts**.

This Feature points **npm**, **pnpm**, **pip**, and **NuGet** at those override
sources by writing their configuration files as early as possible in the
container lifecycle, so that **other Features installed afterward also resolve
their packages through the proxy** during their own install scripts.

It only writes configuration — no network calls, no `apt`, and no assumption that
the package managers are already installed. Providing no URLs makes the Feature a
safe no-op.

## How It Works

For each ecosystem you give a URL, the Feature writes standard config files at
both **system** and **per-user** scope (`scope` option, default `both`). Per-user
config is written for **root** (so package installs run by other Features at build
time use the proxy) and for the **remote user** (so it also applies at runtime).

| Ecosystem | System scope | User scope (root + remote user) |
|-----------|--------------|---------------------------------|
| npm / pnpm | `/etc/npmrc` (read via the `NPM_CONFIG_GLOBALCONFIG` env var this Feature sets) | `~/.npmrc` |
| pip / PyPI | `/etc/pip.conf` | `~/.config/pip/pip.conf` |
| NuGet | `/etc/opt/NuGet/Config/NuGet.Config` | `~/.nuget/NuGet/NuGet.Config` |

- **npm / pnpm** share the same `npmRegistry` (pnpm reads `.npmrc`). The
  `registry=` key replaces the default registry.
- **pip** sets `index-url`, which replaces the default PyPI index.
- **NuGet** writes `<clear />` before the override source, so `nuget.org` is
  removed and only your source remains.

The `.npmrc` files are updated inside a managed marker block so any unrelated npm
settings you already have are preserved; `pip.conf` and `NuGet.Config` are fully
managed by this Feature.

## Getting It First in the Lifecycle

A Feature cannot *force* itself to install before arbitrary third-party Features.
To maximize how early this runs, it declares **no `installsAfter` dependencies**,
so it sorts as early as the resolver allows, and it writes config to root-readable
default locations that later Features' package managers pick up automatically.

For a **hard guarantee** that it runs before Features that download packages, list
it first in `overrideFeatureInstallOrder`:

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
  // Ensure the override sources are configured before anything installs packages
  "overrideFeatureInstallOrder": [
    "ghcr.io/rosstaco/devcontainer-features/package-source-overrides"
  ]
}
```

## Notes

- **No authentication** is configured — the override sources are expected to allow
  anonymous access. Do not put credentials in the URL options (they would be baked
  into image layers).
- **Replace policy:** public feeds are replaced, not augmented. Only the override
  sources are consulted.
- **Self-signed / HTTP proxies:** set `strictSsl` to `false` to emit
  `strict-ssl=false` (npm), `trusted-host` (pip), and `allowInsecureConnections`
  (NuGet). Leave it `true` whenever your proxy presents a trusted certificate.
- Leave an ecosystem's URL empty to skip configuring it.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/rosstaco/devcontainer-features/blob/main/src/package-source-overrides/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
