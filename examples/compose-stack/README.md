# compose-stack

Three-service multi-container example: a Node web app, a PostgreSQL
database, and an OpenTelemetry collector — all on Hummingbird base
images, orchestrated with Podman Compose. Walked through in detail
in [§7 — Multi-container apps](../../docs/07-podman-compose.md).

## Bring it up

```bash
cd $(git rev-parse --show-toplevel)/examples/compose-stack

# The compose file reads HB_REGISTRY from the environment; the
# prerequisites doc (§1) sets it.
export HB_REGISTRY=${HB_REGISTRY:-quay.io/hummingbird}

podman-compose up --build -d

# Wait for the web container to become healthy.
podman ps

curl -s http://localhost:3000 | jq

# Watch the otel collector log to confirm traces flow through.
podman-compose logs -f otel
```

Press Ctrl-C to stop following logs, then:

```bash
podman-compose down
```

## What's running

| Service | Image                                                    | Port(s)         |
| ------- | -------------------------------------------------------- | --------------- |
| `web`   | Built locally from `web/Containerfile`                   | 3000            |
| `db`    | `${HB_REGISTRY}/postgresql:18`                    | (compose net)   |
| `otel`  | `docker.io/otel/opentelemetry-collector-contrib:latest`  | 4317, 4318      |

## Things to notice

1. **`:Z` on every bind mount.** Required on Fedora's SELinux storage,
   harmless on macOS. One compose file, both platforms.
2. **`OTEL_EXPORTER_OTLP_ENDPOINT: http://otel:4318`.** Service-name
   DNS, not `localhost`. Localhost would point at the web container
   itself.
3. **`start_period` on the web healthcheck.** Without it, the
   healthcheck would mark the container unhealthy *during* normal
   boot, breaking the dependency chain.

These three things are documented in §7 and reflect the findings
from the infrastructure environment notes (`FINDINGS.md`).

## Layout

```
compose-stack/
├── compose.yaml       # the orchestration
├── otel/
│   └── config.yaml    # OTLP receivers + debug exporter
└── web/
    ├── Containerfile  # Hummingbird Node multi-stage
    ├── package.json
    └── server.js
```

## Image-name caveat

Assumes `nodejs:20-builder`, `nodejs:20`, and `postgresql:18` are all
published in the Hummingbird org. See the
[reconciliation plan](../../plans/reconciliation-plan.md) §A.
