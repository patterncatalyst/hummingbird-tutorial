# go-example

Static Go HTTP server compiled with the Hummingbird Go builder and
deployed onto `ubi-micro`. Walked through in
[§4 — Multi-stage builds, Example C](../../docs/04-multi-stage-builds.md).

This is the smallest of the §4 examples — typically under 30 MB
total, almost all of which is the binary.

## Build and run

```bash
cd $(git rev-parse --show-toplevel)/examples/go-example

podman build -t hummingbird-go-example:latest .

podman run -d --name hb-go -p 8080:8080 hummingbird-go-example:latest

curl -s http://localhost:8080
# {"status":"ok","runtime":"hummingbird-go-on-ubi-micro"}

podman stop hb-go && podman rm hb-go
```

## Inspect the size

```bash
podman images hummingbird-go-example:latest \
  --format '{{.Repository}}:{{.Tag}}\t{{.Size}}'
```

If you already pulled a stock distro image earlier in the tutorial,
compare the sizes — the `ubi-micro`-based image typically lands at
roughly an order of magnitude smaller.

## Why `ubi-micro`

A static Go binary needs essentially nothing at runtime. `ubi-micro`
provides just glibc and a handful of system files. There's no shell,
no package manager, no busybox — which is exactly the point.

## What's in here

| File             | Why                                                |
| ---------------- | -------------------------------------------------- |
| `main.go`        | Single-file HTTP server                            |
| `go.mod`         | Module declaration; no external deps               |
| `Containerfile`  | Two-stage: Go builder → `ubi-micro` runtime        |

## Image-name caveat

Assumes `go-1.22-builder` and `ubi-micro` are both published in the
Hummingbird org. If `ubi-micro` is only available from
`registry.access.redhat.com/ubi9/ubi-micro`, change the second `FROM`
to `${RH_REGISTRY}/ubi9/ubi-micro:latest`. See the
[reconciliation plan](../../plans/reconciliation-plan.md) §A.
