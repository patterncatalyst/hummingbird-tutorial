# Examples

Each subdirectory here is the **runnable companion** to a numbered
section of the tutorial under `_docs/`. The Containerfiles, source
code, and compose files match what appears inline in the tutorial,
so you can either:

- **read the tutorial** and copy the snippets into a fresh
  directory of your own, or
- **clone this repository** and `cd` straight into the relevant
  example directory.

| Directory          | Tutorial section                                                      |
|--------------------|-----------------------------------------------------------------------|
| `node-example/`    | [§4 — Multi-stage builds](../_docs/04-multi-stage-builds.md), Node     |
| `python-example/`  | [§4 — Multi-stage builds](../_docs/04-multi-stage-builds.md), Python   |
| `go-example/`      | [§4 — Multi-stage builds](../_docs/04-multi-stage-builds.md), Go       |
| `compose-stack/`   | [§7 — Multi-container apps with Podman Compose](../_docs/07-podman-compose.md) |
| `ml-example/`      | [§11 — Real-world examples](../_docs/11-real-world-examples.md), Scenario 2 (ML inference) |

The Quarkus / Java example is described in section 4 but isn't
shipped here as a runnable skeleton — it requires a Maven project
of non-trivial size. See section 4 for the Containerfile pattern
to apply to your existing Quarkus project.

## Building any example

Every Containerfile in this directory accepts the same two build
args, so the same command builds them all:

```bash
podman build \
  --build-arg HB_REGISTRY="${HB_REGISTRY:-quay.io/hummingbird}" \
  --build-arg RH_REGISTRY="${RH_REGISTRY:-registry.access.redhat.com}" \
  -t my-image:latest \
  .
```

## Reconciliation

Image names and the existence of specific Hummingbird builder
images vary across the early-access and post-GA windows. If a
`podman build` here fails on `manifest unknown`, see the
[reconciliation plan](../plans/reconciliation-plan.md), section A
("Image catalog and naming") — that's the canonical list of
unverified image references in the tutorial.
