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

<table class="bib bib--books">
  <colgroup><col style="width:62%"><col style="width:24%"><col style="width:14%"></colgroup>
  <thead><tr><th>Title</th><th>Author(s)</th><th>Year</th></tr></thead>
  <tbody>
    <tr><td><a href="https://www.oreilly.com/library/view/container-security-2nd/9781098168988/" rel="noopener"><em>Container Security</em>, 2nd ed.</a><br><small>O'Reilly. Container isolation, image supply chain, and runtime security</small></td><td>Liz Rice</td><td>2025</td></tr>
  </tbody>
</table>

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
