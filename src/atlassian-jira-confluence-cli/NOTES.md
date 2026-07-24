## About

The [Atlassian CLI](https://developer.atlassian.com/cloud/acli/) (`acli`) is Atlassian's official command line tool for working with **Jira** and **Confluence** Cloud (plus Atlassian Guard and Rovo Dev) directly from your terminal.

For more information, see: https://developer.atlassian.com/cloud/acli/

## How It Works

1. **Downloads the official binary** from `acli.atlassian.com` (the same rolling `latest` and versioned `-stable` archives Atlassian publishes)
2. **Installs to** `/usr/local/bin/acli` by default (configurable via `installPath`)
3. **Supports** both `amd64` and `arm64` architectures
4. **Installs an `xdg-open` shim** (when `configureBrowser` is `true`, the default) so the OAuth login opens in your host browser — see below

## Browser Login in a Dev Container

`acli auth login` opens an OAuth page by shelling out to `xdg-open`, which doesn't
honor `$BROWSER` and fails (or tries to launch a browser inside the container).
With `configureBrowser` enabled, this feature installs a small `xdg-open` shim at
`/usr/local/bin/xdg-open` that prefers `$BROWSER` (for example the VS Code browser
helper) and falls back to the real `xdg-open` otherwise, so the login page opens on
your host. Set `configureBrowser` to `false` to skip installing the shim.

## Usage

Authenticate once (interactive OAuth login):

```bash
acli auth login
```

Then work with Jira and Confluence, for example:

```bash
# List your Jira projects
acli jira project list

# View a Jira work item
acli jira workitem view --key PROJ-123

# Confluence commands
acli confluence --help
```
