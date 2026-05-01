# python-example

Trivial FastAPI app demonstrating the wheel-build multi-stage pattern.
Walked through in detail in [§4 — Multi-stage builds, Example B](../../docs/04-multi-stage-builds.md)
and reused in [§11 — Real-world examples (Scenario 1)](../../docs/11-real-world-examples.md).

## Build and run

```bash
cd $(git rev-parse --show-toplevel)/examples/python-example

podman build -t hummingbird-py-example:latest .

podman run -d --name hb-py -p 8000:8000 hummingbird-py-example:latest

# uvicorn takes a moment to boot — give it a couple of seconds.
sleep 2
curl -s http://localhost:8000 | jq
# {"status":"ok","runtime":"hummingbird-python","python":"3.11..."}

podman stop hb-py && podman rm hb-py
```

## Why two stages

The build stage installs `gcc`/headers/etc. and compiles wheels. The
runtime stage installs from those pre-built wheels and never sees a
compiler. Net effect: a runtime image that's smaller, has fewer CVEs
attached, and doesn't ship a build toolchain into production.

You won't see the size win on this trivial example because there are
no C-extension dependencies. Add `psycopg2`, `numpy`, `cryptography`,
or any package that compiles native code, and the difference becomes
obvious.

## Override the registry

```bash
podman build \
  --build-arg HB_REGISTRY=registry.internal.example.com/hb \
  -t hummingbird-py-example:latest .
```

## What's in here

| File                  | Why                                                  |
| --------------------- | ---------------------------------------------------- |
| `app/main.py`         | Single-route FastAPI app                             |
| `requirements.txt`    | Major-version pins for FastAPI and Uvicorn          |
| `Containerfile`       | Two-stage: Python builder (wheels) → Python runtime |

## Image-name caveat

Assumes `python-311-builder` and `python-311`. See the
[reconciliation plan](../../plans/reconciliation-plan.md) §A.
