---
title: "Bibliography"
layout: plan
permalink: /bibliography/
description: "The reference book and primary documentation this tutorial draws on for container security and hardened images."
---

This tutorial's coverage of hardened container images, supply-chain integrity,
and distroless runtimes draws on one reference book and the primary
documentation for the tools it uses. These are reference works, not sources: no
text or code from any of them is reproduced here.

| Title | Author(s) | Publisher | Year | Focus |
|---|---|---|---|---|
| [*Container Security*, 2nd ed.](https://www.oreilly.com/library/view/container-security-2nd/9781098168988/) | Liz Rice | O'Reilly | 2025 | Container isolation, image supply chain, and runtime security |

## Primary references

The tutorial follows the current documentation for the tools and standards it
uses. These are the authoritative sources to check against:

- [Red Hat hardened images](https://www.redhat.com/en/products/trusted-software-supply-chain): the minimal, maintained base images this tutorial builds on.
- [Sigstore / cosign](https://docs.sigstore.dev/): signing and verifying image signatures and attestations.
- [Syft](https://github.com/anchore/syft) and [Grype](https://github.com/anchore/grype): generating SBOMs and scanning images for known vulnerabilities.
- [SLSA](https://slsa.dev/): the supply-chain integrity framework the provenance discussion follows.
- [Podman documentation](https://docs.podman.io/): the container engine and `podman-compose` used throughout the examples.
- [Kubernetes documentation](https://kubernetes.io/docs/): the runtime target for the deployed examples.

Nothing in these chapters or the runnable examples copies text or code from
these works.
