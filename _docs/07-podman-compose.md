---
title: Multi-container apps with Podman Compose
order: 7
description: Stand up a small multi-service stack with Hummingbird base images and Podman Compose; cover the Fedora-specific SELinux gotchas and healthcheck timing.
duration: 30 minutes
---

This section moves from single images to a multi-service stack:
a web tier, a database, and an OpenTelemetry collector — all
running on Hummingbird base images, all managed by Podman
Compose.

The example is deliberately small enough to fit on one page.
Real production stacks have more services and more configuration,
but the patterns here scale up cleanly.

## What you'll build

{% include excalidraw.html
   file="07-podman-compose-stack"
   alt="Architecture diagram: an Nginx-fronted web app talking to PostgreSQL, with an OpenTelemetry collector receiving traces from the web app"
   caption="Figure 7.1 — The compose stack we'll stand up in this section" %}

Three services:

1. **`web`** — a small Node.js application built on Hummingbird's
   Node runtime. It writes a row to PostgreSQL on each request
   and emits a span to the collector.
2. **`db`** — PostgreSQL on Hummingbird's PostgreSQL image.
3. **`otel`** — OpenTelemetry Collector, receiving OTLP traces
   from `web`.

## Step 1 — Project skeleton

```bash
mkdir -p ~/hummingbird-tutorial/examples/compose-stack
cd ~/hummingbird-tutorial/examples/compose-stack
mkdir -p web otel
```

## Step 2 — The web service

```bash
cat > web/server.js <<'EOF'
const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    note: 'real implementation would talk to db and otel here'
  }));
});

server.listen(port, '0.0.0.0', () => {
  console.log(`web listening on ${port}`);
});
EOF

cat > web/package.json <<'EOF'
{
  "name": "compose-web",
  "version": "1.0.0",
  "main": "server.js"
}
EOF

cat > web/Containerfile <<'EOF'
ARG HB_REGISTRY=quay.io/hummingbird

FROM ${HB_REGISTRY}/nodejs:20-builder AS builder
WORKDIR /build
COPY --chown=1001:1001 package*.json ./
RUN npm ci --omit=dev --no-audit
COPY --chown=1001:1001 server.js ./

FROM ${HB_REGISTRY}/nodejs:20
WORKDIR /app
COPY --from=builder --chown=1001:1001 /build /app
USER 1001
EXPOSE 3000
CMD ["node", "server.js"]
EOF
```

## Step 3 — The OpenTelemetry collector configuration

```bash
cat > otel/config.yaml <<'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch: {}

exporters:
  debug:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
EOF
```

## Step 4 — The `compose.yaml`

This is the file with the most platform-specific content. Pay
attention to the `:Z` suffix on the volume mounts — that's a
Fedora SELinux concern that becomes a no-op on macOS but is
required on Fedora.

```bash
cat > compose.yaml <<'EOF'
# Compose file for the Hummingbird tutorial section 7. Designed to
# work the same way under `podman-compose up` and `docker compose up`.
#
# IMPORTANT: every bind-mounted volume below ends with `:Z`. On
# Fedora's SELinux-enforcing storage this relabels the host directory
# so the container can read it. On macOS and other non-SELinux hosts,
# `:Z` is a harmless no-op. Leaving it in keeps the same compose file
# portable across both platforms.

services:
  db:
    image: ${HB_REGISTRY:-quay.io/hummingbird}/postgresql:18
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: appsecret
      POSTGRES_DB: appdb
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "app", "-d", "appdb"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 15s
    networks: [app]

  otel:
    image: docker.io/otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otelcol-contrib/config.yaml"]
    volumes:
      - ./otel/config.yaml:/etc/otelcol-contrib/config.yaml:Z
    ports:
      - "4317:4317"
      - "4318:4318"
    networks: [app]

  web:
    build:
      context: ./web
      args:
        HB_REGISTRY: ${HB_REGISTRY:-quay.io/hummingbird}
    depends_on:
      db:
        condition: service_healthy
      otel:
        condition: service_started
    environment:
      DATABASE_URL: postgres://app:appsecret@db:5432/appdb
      # Service names work as DNS inside the compose network. Do not
      # use localhost here — that would point at the web container
      # itself, not the otel container.
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otel:4318
    healthcheck:
      test: ["CMD", "/bin/test", "-f", "/proc/1/cmdline"]
      interval: 2s
      timeout: 2s
      retries: 30
      # Boot grace period — important for Java apps; harmless for Node.
      start_period: 30s
    ports:
      - "3000:3000"
    networks: [app]

networks:
  app:
    driver: bridge
EOF
```

The three things to notice in that file:

1. **`:Z` on every bind mount.** Required on Fedora; harmless on
   macOS. Forgetting it on Fedora gives "permission denied" errors
   that look like a wrong password but aren't.
2. **`OTEL_EXPORTER_OTLP_ENDPOINT: http://otel:4318`.** The
   service name `otel` resolves through Compose's internal DNS to
   the collector container. `localhost` would resolve to the web
   container itself.
3. **`start_period` on the web healthcheck.** Without this, the
   default healthcheck behaviour will mark the container unhealthy
   *while it's still booting normally*, breaking dependent service
   ordering for slower-booting frameworks. Thirty seconds is
   generous but cheap.

## Step 5 — Bring it up

```bash
# Use the env var from the prerequisites for the registry.
export HB_REGISTRY=${HB_REGISTRY:-quay.io/hummingbird}

# Build and start. The first run pulls the Hummingbird Postgres
# image, which can take a minute on a cold cache.
podman-compose up --build -d

# Watch the services come up.
podman-compose ps

# Tail logs as they start.
podman-compose logs -f
# (Ctrl-C to detach from the log stream — the stack keeps running.)
```

## Step 6 — Smoke-test the stack

```bash
# Hit the web service.
curl -s http://localhost:3000 | jq

# Confirm the OTel collector is listening.
ss -tlnp 2>/dev/null | grep -E "4317|4318" || \
  podman-compose exec otel sh -c "ss -tlnp 2>/dev/null"

# Confirm Postgres is healthy.
podman-compose exec db pg_isready -U app -d appdb
```

## Step 7 — Tear it down

```bash
podman-compose down
# Or, to also remove volumes:
podman-compose down --volumes
```

## Common gotchas

A summary of what bites people on this section:

| Symptom                                        | Likely cause                                     |
|------------------------------------------------|--------------------------------------------------|
| `permission denied` reading mounted config     | Missing `:Z` on a bind mount, on Fedora          |
| `connection refused` from web to otel          | `OTEL_EXPORTER_OTLP_ENDPOINT` set to localhost   |
| `web` reported unhealthy during normal boot    | Missing or too-short `start_period`              |
| `db` connection refused immediately            | `depends_on` without `condition: service_healthy`|
| `pull access denied` on `postgresql:18` | `HB_REGISTRY` not set, or wrong image name       |

## Verify before moving on

You should be able to bring the stack up and down cleanly with
`podman-compose up`/`down`, see all three services healthy in
`podman-compose ps`, and explain why the `:Z` flag is on the
volume mounts.

## Where to go next

[Debugging Hummingbird containers]({{ "/docs/08-debugging/" | prepend: site.baseurl }})
covers the four-layer debugging strategy, building on the
debug-sidecar pattern we introduced in section 3.
