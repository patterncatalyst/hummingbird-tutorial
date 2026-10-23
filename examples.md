---
title: "Examples"
layout: plan
permalink: /examples/
description: "Every runnable example in this repo, mapped to the tutorial section it supports."
---

Each subdirectory under
[`examples/`](https://github.com/{{ site.github_username }}/hummingbird-tutorial/tree/main/examples)
is the runnable companion to a numbered section of the tutorial. The
Containerfiles, source, and compose files match what appears inline in the
chapters, so you can read a chapter and copy its snippets into a fresh
directory, or clone the repo and work straight from the example.

| Example | What it shows | Tutorial section |
|---|---|---|
| [`node-example`](https://github.com/{{ site.github_username }}/hummingbird-tutorial/tree/main/examples/node-example) | Multi-stage build on a hardened base, Node | [Ch4]({{ '/docs/04-multi-stage-builds/' | relative_url }}) |
| [`python-example`](https://github.com/{{ site.github_username }}/hummingbird-tutorial/tree/main/examples/python-example) | Multi-stage build on a hardened base, Python | [Ch4]({{ '/docs/04-multi-stage-builds/' | relative_url }}) |
| [`go-example`](https://github.com/{{ site.github_username }}/hummingbird-tutorial/tree/main/examples/go-example) | Multi-stage build on a hardened base, Go | [Ch4]({{ '/docs/04-multi-stage-builds/' | relative_url }}) |
| [`quarkus-example`](https://github.com/{{ site.github_username }}/hummingbird-tutorial/tree/main/examples/quarkus-example) | A Quarkus service on a hardened base | [Ch4]({{ '/docs/04-multi-stage-builds/' | relative_url }}) |
| [`compose-stack`](https://github.com/{{ site.github_username }}/hummingbird-tutorial/tree/main/examples/compose-stack) | A multi-container app wired with Podman Compose | [Ch7]({{ '/docs/07-podman-compose/' | relative_url }}) |
| [`ml-example`](https://github.com/{{ site.github_username }}/hummingbird-tutorial/tree/main/examples/ml-example) | A real-world scenario: ML inference on a hardened image | [Ch11]({{ '/docs/11-real-world-examples/' | relative_url }}) |

## Running an example

Each directory is self-contained: a `Containerfile` (or a `compose.yaml` for the
compose stack) and a `README.md` with the build and run steps. The build and run
commands use Podman; see
[Prerequisites]({{ '/docs/01-prerequisites/' | relative_url }}) for the full
toolchain (Podman, podman-compose, cosign, syft, grype).
