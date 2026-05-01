# Hummingbird Tutorial

A follow-along, cut-and-paste tutorial for Project Hummingbird — Red Hat's
catalog of minimal, hardened, near-zero-CVE container images — using
Podman, Podman Compose, and Podman Desktop.

The tutorial is published as a Jekyll site under `docs/` and is intended
to be read in order, top to bottom. Every command shown is meant to be
copied directly into a terminal on a Fedora 43 workstation or a macOS
machine with iTerm2 / Terminal. There is no separate "lab environment"
to provision — your laptop is the lab.

## Who this is for

- Developers who want to use Hummingbird base images for their applications.
- Platform engineers who need to wire Hummingbird into build pipelines.
- Security and compliance engineers who want hands-on familiarity with
  SBOMs, signing, and CVE scanning for Hummingbird images.

## What you'll need

The full prerequisite list — packages, tools, registry accounts, and
configuration — lives in [`docs/01-prerequisites.md`](docs/01-prerequisites.md).
At a glance:

- Fedora 43 (bash or zsh) **or** macOS (Terminal or iTerm2)
- Podman 5.x, Podman Compose, Podman Desktop
- An account on `registry.access.redhat.com` and `quay.io`
- A few supporting tools: `cosign`, `syft`, `grype`, `skopeo`, `jq`

## How to read it

Start at [`docs/00-outline.md`](docs/00-outline.md) for the table of
contents and a sense of how the sections fit together. Then work
through each numbered section in order. Each section is self-contained
enough that you can stop at the end of any chapter and come back later
without losing state on your machine.

## How to build the site locally

```bash
bundle install
bundle exec jekyll serve
```

The site will be available at `http://localhost:4000/hummingbird-tutorial/`.

## Status and reconciliation

This repository is under active development. The
[reconciliation plan](plans/reconciliation-plan.md) tracks what is
written, what is in flight, and what remains to be verified against
running Fedora 43 and macOS environments. If you find a command that
doesn't behave as documented, please open an issue and reference the
relevant section number.

## License

Tutorial content (under `docs/`, `plans/`, and `assets/diagrams/`) is
licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
Sample code (under `examples/` and `scripts/`) is licensed under the
[Apache License 2.0](LICENSE).
