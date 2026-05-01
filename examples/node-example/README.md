# node-example

Trivial Node.js HTTP server demonstrating the two-stage build pattern
on Hummingbird base images. Walked through in detail in
[§4 — Multi-stage builds, Example A](../../docs/04-multi-stage-builds.md).

Also referenced from §6 (CVE scanning), §9 (zstd:chunked), and §10
(chunkah) — those sections reuse this same project rather than
introducing a new one each time.

## Build and run

```bash
cd $(git rev-parse --show-toplevel)/examples/node-example

podman build -t hummingbird-node-example:latest .

podman run -d --name hb-node -p 3000:3000 hummingbird-node-example:latest

curl -s http://localhost:3000 | jq
# {"status":"ok","runtime":"hummingbird-nodejs","nodeVersion":"v20.x.x"}

podman stop hb-node && podman rm hb-node
```

## Override the registry

If you're pulling from an internal mirror or the Hummingbird
early-access org:

```bash
podman build \
  --build-arg HB_REGISTRY=quay.io/hummingbird-hatchling \
  -t hummingbird-node-example:latest .
```

## What's in here

| File                  | Why                                                  |
| --------------------- | ---------------------------------------------------- |
| `server.js`           | Single-file HTTP server, returns a JSON heartbeat    |
| `package.json`        | No real deps; small enough to read in one screen     |
| `package-lock.json`   | Empty lockfile so `npm ci` has something to lock     |
| `Containerfile`       | Two-stage: Hummingbird Node builder → Node runtime   |

## Image-name caveat

This Containerfile assumes `nodejs:20-builder` and `nodejs:20`. If the
images you have access to are named differently, edit the two `FROM`
lines or supply `--build-arg HB_REGISTRY=…`. See the
[reconciliation plan](../../plans/reconciliation-plan.md) §A for
the live status of these names.
