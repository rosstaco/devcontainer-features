# Copilot Metrics (LGTM)

Captures OpenTelemetry traces emitted by **GitHub Copilot** (VS Code Copilot
Chat _and_ the Copilot CLI) and visualizes them in a local **Grafana LGTM
stack** (Loki / Grafana / Tempo / Mimir, via the `grafana/otel-lgtm` image).

## Usage

Add this Feature to your `devcontainer.json`:

```json
{
  "features": {
    "ghcr.io/rosstaco/devcontainer-features/copilot-metrics-lgtm:1": {}
  },
  "forwardPorts": [3000]
}
```

Open Grafana at **http://localhost:3000** after the container starts.

## Prerequisites

This Feature requires a Docker daemon inside the devcontainer. Add **one** of
the following to your `features` block:

| Feature | When to use |
|---------|-------------|
| `ghcr.io/devcontainers/features/docker-in-docker` | Default / recommended. Simplest. |
| `ghcr.io/devcontainers/features/docker-outside-of-docker` | When `privileged: true` is not allowed (restricted Codespaces, corporate policy). |

> **⚠️ `forwardPorts` required** — Features cannot contribute `forwardPorts`.
> Add `"forwardPorts": [3000]` to your `devcontainer.json` to access Grafana
> in your browser. VS Code's auto port forwarding usually catches it, but the
> explicit declaration ensures it.

## Options

| Option             | Type    | Default                    | Description                               |
|--------------------|---------|----------------------------|-------------------------------------------|
| `lgtmImage`        | string  | `grafana/otel-lgtm:latest` | LGTM image tag to use.                    |
| `installDashboard` | boolean | `true`                     | POST the bundled dashboard on first start.|
| `dockerMode`       | string  | `auto`                     | `auto`, `dind`, or `dood`.                |
| `grafanaPort`      | string  | `3000`                     | Grafana web UI port (change if 3000 conflicts).|
| `captureContent`   | boolean | `true`                     | Capture full prompt/response content in traces. |

## Data flow

```
VS Code Copilot Chat ─┐                          ┌─ Tempo (traces)  ─┐
                      ├─ OTLP/HTTP :4318 ──► LGTM ┤                   ├─► Grafana :3000
Copilot CLI         ─┘                           └─ Prometheus etc. ─┘
```

Both exporters target `http://localhost:4318` inside the devcontainer.

## Privacy notice

> **This Feature captures full prompt and response content locally when
> `captureContent` is `true` (the default).**

- **VS Code Copilot Chat** sends `gen_ai.input.messages` and
  `gen_ai.output.messages` to the local Tempo instance when
  `github.copilot.chat.otel.captureContent` is `true` (the default).
- **Copilot CLI** captures `gen_ai.input.messages` when
  `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` is `true`.

Both are controlled by the `captureContent` option. Set to `false` to capture
only span metadata (timing, token counts) without message bodies.

All data stays local (inside the devcontainer's LGTM stack). To wipe all
stored data:

```bash
docker volume rm copilot-lgtm-data
```

## Docker modes

### Docker-in-Docker (default)

LGTM runs in the devcontainer's inner Docker daemon. `localhost:4318` works
transparently. Requires `privileged: true` (provided by the DinD feature).

### Docker-outside-of-Docker

For environments that can't use DinD, the Feature supports DooD. LGTM runs
on the host daemon but joins the devcontainer's network namespace
(`--network=container:$HOSTNAME`), so `localhost:4318` still works.

Set `"dockerMode": "dood"` explicitly, or leave `"auto"` to detect
automatically.

## First start

The first `docker compose up` pulls **~600 MB** (`grafana/otel-lgtm`).
Subsequent starts are fast thanks to the `copilot-lgtm-data` named volume
that persists data across container rebuilds.

## State reset

```bash
docker volume ls | grep copilot-lgtm-data
# Then: docker volume rm <volume-name>
```

The volume name is `${devcontainerId}-copilot-lgtm-data` — check `docker volume ls`
to find the exact name. This removes all Grafana dashboards (including manual
UI edits), traces, metrics, and logs.
