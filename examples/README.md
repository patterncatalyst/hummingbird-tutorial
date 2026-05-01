# Examples

Each subdirectory here is the **runnable companion** to a numbered
section of the tutorial under `docs/`. The Containerfiles, source
code, and compose files match what appears inline in the tutorial,
so you can either:

- **read the tutorial** and copy the snippets into a fresh
  directory of your own, or
- **clone this repository** and `cd` straight into the relevant
  example directory.

## Primary examples

For the audience this tutorial is aimed at — JVM, Python, and Go
backends — these three are the focus. They're listed in roughly the
order a typical reader will care about them.

| Directory                                  | Tutorial section                                                                | What it shows                                                              |
| ------------------------------------------ | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| [`quarkus-example/`](./quarkus-example)    | [§4 — Multi-stage builds](../docs/04-multi-stage-builds.md), Example D          | Quarkus 3.15 LTS, JVM mode, two-stage `openjdk-21-builder` → runtime build |
| [`python-example/`](./python-example)      | [§4 — Multi-stage builds](../docs/04-multi-stage-builds.md), Example B          | FastAPI, wheel-build pattern (compile in builder, install in runtime)      |
| [`go-example/`](./go-example)              | [§4 — Multi-stage builds](../docs/04-multi-stage-builds.md), Example C          | Static Go binary on `ubi-micro` — the smallest of the four examples        |
| [`ml-example/`](./ml-example)              | [§11 — Real-world examples](../docs/11-real-world-examples.md), Scenario 2     | FastAPI + NumPy variant of the Python example with native-code wheels      |
| [`compose-stack/`](./compose-stack)        | [§7 — Multi-container apps](../docs/07-podman-compose.md)                       | Three-service stack: Node web, PostgreSQL, OpenTelemetry collector         |

## Secondary example

| Directory                              | Tutorial section                                                          | What it shows                                                  |
| -------------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------- |
| [`node-example/`](./node-example)      | [§4 — Multi-stage builds](../docs/04-multi-stage-builds.md), Example A    | Node.js, two-stage `nodejs-20-builder` → `nodejs-20` build     |

The Node example exists because the multi-stage pattern in §4 is
explained against it first as a stripped-down reference. If you're not
shipping Node services, skim it for the pattern and skip to the
language you actually use.

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

## What's deliberately not here

- **A native-image Quarkus skeleton.** The JVM-mode example covers
  the realistic default. Native-image builds need a Mandrel/GraalVM
  builder image whose Hummingbird name isn't yet confirmed; see the
  reconciliation plan §A and the note at the bottom of the
  `quarkus-example/` README.
- **A `secure-build.sh` end-to-end pipeline script.** Referenced from
  §11 scenario 4; tracked in the reconciliation plan.

## Reconciliation

Image names and the existence of specific Hummingbird builder
images vary across the early-access and post-GA windows. If a
`podman build` here fails on `manifest unknown`, see the
[reconciliation plan](../plans/reconciliation-plan.md), section A
("Image catalog and naming") — that's the canonical list of
unverified image references in the tutorial.
