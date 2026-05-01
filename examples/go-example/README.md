# go-example

Static Go HTTP server compiled with the Hummingbird Go builder
and deployed onto the Hummingbird Go runtime. Walked through in
[§4 — Multi-stage builds, Example C](../../docs/04-multi-stage-builds.md).

This is the smallest of the §4 examples — typically around 30 MB
total, almost all of which is the binary itself.

## Build and run

```bash
cd $(git rev-parse --show-toplevel)/examples/go-example

podman build -t hummingbird-go-example:latest .

podman run -d --name hb-go -p 8080:8080 hummingbird-go-example:latest

curl -s http://localhost:8080
# {"status":"ok","runtime":"hummingbird-go"}

podman stop hb-go && podman rm hb-go
```

## Inspect the size

```bash
podman images hummingbird-go-example:latest \
  --format '{% raw %}{{.Repository}}:{{.Tag}}\t{{.Size}}{% endraw %}'
```

If you've pulled a stock distro Go image earlier (for comparison),
the Hummingbird image typically lands an order of magnitude smaller.

## Why the Hummingbird Go runtime

A static Go binary built with `CGO_ENABLED=0` is self-contained —
it doesn't need a Go toolchain at runtime. So the runtime image
just needs to provide:

- **glibc** — even a "static" Go binary still calls into glibc
  for some syscalls and DNS resolution.
- **A non-root user (UID 1001)** — Hummingbird images default to
  running as 1001; the runtime ships an `/etc/passwd` entry so
  any Go code that calls `os/user.Current()` works.
- **CA certificates** — for outbound HTTPS calls.

The Hummingbird `go-1.22` runtime image gives you exactly that
and not much else. It's the right default for any Go service.

## What's in here

| File             | Why                                                |
| ---------------- | -------------------------------------------------- |
| `main.go`        | Single-file HTTP server                            |
| `go.mod`         | Module declaration; no external deps               |
| `Containerfile`  | Two-stage: Hummingbird Go builder → Hummingbird Go runtime |

## Image-name caveat

This Containerfile assumes that `go-1.22-builder` and `go-1.22`
both exist in the Hummingbird catalog at `quay.io/hummingbird/`.
The builder is well-precedented (matches the Python and Java
patterns); the runtime is parallel to `python-311` and
`openjdk-21`. Verification status is tracked in the
[reconciliation plan](../../plans/reconciliation-plan.md) §A.
