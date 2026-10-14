
# Atlassian Teamwork Graph CLI (twg) (atlassian-teamwork-graph-cli)

Installs the Atlassian Teamwork Graph CLI (twg) for working with Jira, Confluence, Bitbucket, JSM, Loom, Trello and the Teamwork Graph from the command line and from AI coding agents

## Example Usage

```json
"features": {
    "ghcr.io/rosstaco/devcontainer-features/atlassian-teamwork-graph-cli:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of twg to install. Use 'latest' (current stable release) or a specific version like '1.3.5'. Atlassian blocks versions below a published minimum, so old pins may stop working | string | latest |
| installSkills | Run 'twg skills install --yes' for the remote user, installing TWG agent skills into ~/.agents/skills and ~/.claude/skills | boolean | false |
| enableTelemetry | Allow twg runtime telemetry. When false (the default), DO_NOT_TRACK=1 and TWG_DISABLE_3P_DATA_TELEMETRY=1 are exported for login shells (/etc/profile.d) and non-interactive bash (BASH_ENV) | boolean | false |
| persistAuth | Symlink ~/.config/twg (credentials, site, settings) to a per-dev-container named volume so 'twg login' survives container rebuilds | boolean | true |
| configureBrowser | Install an xdg-open shim in /usr/local/bin that prefers $BROWSER (e.g. the VS Code browser helper) so 'twg login' opens the OAuth page on your host instead of failing inside the container | boolean | true |

## About

The [Atlassian Teamwork Graph CLI](https://developer.atlassian.com/platform/teamwork-graph/twg-cli/) (`twg`) is Atlassian's CLI for the Teamwork Graph and Atlassian Cloud: Jira, Confluence, Jira Service Management, Bitbucket, Loom, Trello, Goals, Assets and more. It is designed to be driven by AI coding agents as well as people, and complements the [Atlassian CLI (`acli`)](https://github.com/rosstaco/devcontainer-features/tree/main/src/atlassian-jira-confluence-cli). Both Features can be used together.

## How It Works

Atlassian's official installer (`curl … /cli/install | bash`) also runs `twg setup`, which asks you to accept the Atlassian agreements, installs agent skills and starts an interactive OAuth login on the controlling terminal. None of that can happen while an image is being built, so this Feature:

1. **Downloads the official binary** from `teamwork-graph.atlassian.com/cli` (`latest` is resolved from the stable `manifest.json`) and **verifies its SHA-256** against the published `SHA256SUMS`
2. **Installs it for the remote user** at `~/.local/bin/twg` (twg's default location, user-owned so `twg upgrade` works without sudo) and symlinks `/usr/local/bin/twg` to it so it is on every `PATH`
3. **Disables telemetry** unless `enableTelemetry` is `true` (see below)
4. **Persists `~/.config/twg`** on a per-dev-container named volume when `persistAuth` is `true`, so you only log in once
5. **Optionally installs TWG agent skills** (`installSkills`)
6. **Installs an `xdg-open` shim** (when `configureBrowser` is `true`) so the OAuth login opens in your host browser

Supported architectures: `x86_64` and `arm64` (Linux, glibc).

## Getting Started

Authenticate once, then check the setup:

```bash
twg login     # OAuth device authorization: open the printed URL (or let $BROWSER open it) and approve
twg doctor
```

Then, for example:

```bash
twg jira --help
twg confluence --help
twg --output json jira ...
```

## Authenticating with Environment Variables

Instead of `twg login`, every `twg` command reads `TWG_TOKEN`, `TWG_USER` and `TWG_SITE` directly. A Feature can't safely set these (its `containerEnv` is baked into the image), so pass them from your host in your own `devcontainer.json` with `remoteEnv`:

```json
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/atlassian-teamwork-graph-cli:1": {}
  },
  "remoteEnv": {
    "TWG_TOKEN": "${localEnv:TWG_TOKEN}",
    "TWG_USER": "${localEnv:TWG_USER}",
    "TWG_SITE": "${localEnv:TWG_SITE}"
  }
}
```

`remoteEnv` values are applied to the processes VS Code (or the dev container CLI) starts and are not written to the image. Never commit a token to `devcontainer.json`.

## Telemetry

With `enableTelemetry` set to `false` (the default), the Feature writes `/etc/atlassian-teamwork-graph-cli/env.sh`:

```bash
export DO_NOT_TRACK=1
export TWG_DISABLE_3P_DATA_TELEMETRY=1
```

It is sourced by login shells via `/etc/profile.d/atlassian-teamwork-graph-cli.sh` and by non-interactive bash via `BASH_ENV` (`/etc/atlassian-teamwork-graph-cli/bash_env`, which chains to any `BASH_ENV` set before this Feature). `DO_NOT_TRACK` is the [Console Do Not Track](https://consoledonottrack.com/) convention, so other tools that honour it will also stop sending telemetry. Set `enableTelemetry` to `true` to skip this.

## Persisted Login

`twg` keeps its credentials and settings in `~/.config/twg`. The Feature always mounts a named volume at `/twg-config` (dev container mounts can't depend on options). With `persistAuth` set to `true` (the default), `~/.config/twg` is a symlink to that volume, so `twg login` survives rebuilds. Set `persistAuth` to `false` to keep the config in the container instead. To log out, run `twg logout`, or remove the `<devcontainerId>-twg-config` volume.

## Agent Skills

With `installSkills` set to `true`, the Feature runs `twg skills install --yes` as the remote user, installing the TWG skills into `~/.agents/skills` (used by Copilot, Codex, Cursor, Gemini and other `.agents/skills`-compatible agents) and `~/.claude/skills`. They are reinstalled on every rebuild. You can also run `twg skills install` yourself.

## Browser Login in a Dev Container

`twg login` tries to open the OAuth page with `xdg-open`, which doesn't honour `$BROWSER` inside a dev container. With `configureBrowser` enabled, this Feature installs a small `xdg-open` shim at `/usr/local/bin/xdg-open` that prefers `$BROWSER` (for example the VS Code browser helper) and falls back to the real `xdg-open` otherwise. `twg login` also prints the URL, so you can open it yourself. The shim is the same one the `atlassian-jira-confluence-cli` Feature installs.

## Versions and Upgrades

`latest` installs the current stable release at build time. Atlassian publishes a minimum supported version and blocks older builds, so a pinned `version` may stop working over time. `twg upgrade` works inside the container, but the image installs the configured version again on the next rebuild.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/rosstaco/devcontainer-features/blob/main/src/atlassian-teamwork-graph-cli/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
