---
title: Outline
order: 0
description: How the tutorial is structured and how to read it.
duration: 5 minutes
---

This page is the map. Read it once before you start, and come back
whenever you lose your place. Every other section in the tutorial
links back here from the prev/next bar at the bottom of the page.

## How the tutorial is organised

The tutorial is divided into eleven core numbered sections plus
five optional follow-up sections, each of which lives in its own
document under `docs/`. The core sections are designed to
be **read and executed in order** — each one builds on the state your
machine is in when you finish the previous one. The follow-up
sections (12 through 16) can be read in any order after the core,
based on what you actually need. There is no separate
lab environment: your Fedora 44 workstation or macOS laptop is the
lab from start to finish.

Within a section, the structure is consistent:

1. **Why this section exists** — what you should be able to do after.
2. **What you'll learn** — a one-paragraph summary in plain language.
3. **The diagram** — an Excalidraw figure showing the moving parts.
4. **Step-by-step commands** — every command is meant to be copied
   and pasted. Where the command differs between Fedora 44 and
   macOS, both variants are shown side by side under collapsible
   headings.
5. **What to verify** — a short checklist so you can confirm the
   section worked before moving on.
6. **Where to go next** — a pointer to the next section, plus
   optional side trips.

## The eleven core sections

### 1. [Prerequisites]({{ "/docs/01-prerequisites/" | prepend: site.baseurl }})

Install the tooling you'll need on Fedora 44 or macOS: Podman 5.x,
Podman Compose, Podman Desktop, plus the supporting tools `cosign`,
`syft`, `grype`, `skopeo`, and `jq`. Configure rootless storage,
the Podman socket, and credentials for `registry.access.redhat.com`
and `quay.io`.

### 2. [What is Project Hummingbird]({{ "/docs/02-introduction/" | prepend: site.baseurl }})

The conceptual grounding. What makes Hummingbird different from a
general-purpose base image, where it fits in the Red Hat container
ecosystem alongside RHEL and UBI, and what "near zero CVE" actually
means in practice.

### 3. [Podman basics with Hummingbird]({{ "/docs/03-podman-basics/" | prepend: site.baseurl }})

Pull a Hummingbird image, inspect its manifest, run it, and
discover for yourself why exec'ing into it doesn't work. Learn the
ephemeral debug-sidecar pattern that replaces interactive shells.
This is the section where the rest of the tutorial starts to make
sense viscerally rather than abstractly.

### 4. [Multi-stage builds]({{ "/docs/04-multi-stage-builds/" | prepend: site.baseurl }})

The primary intended workflow: use a Hummingbird builder image as
your `FROM ... AS builder` stage and a Hummingbird runtime image
as the final stage. Walk through working examples in Quarkus,
Node.js, Python, and Go, with build-args so the same Containerfile
runs on a connected machine or against an internal mirror.

### 5. [SBOMs and signing]({{ "/docs/05-sbom-and-signing/" | prepend: site.baseurl }})

Generate an SBOM with Syft, attach it as a Sigstore attestation
with Cosign, and verify the SBOM that ships with a stock
Hummingbird image. Set up a local Cosign key pair and learn the
keyless-OIDC pattern used in CI.

### 6. [CVE scanning]({{ "/docs/06-cve-scanning/" | prepend: site.baseurl }})

Use Grype to scan a Hummingbird image, your own image built on
top of it, and confirm what "near zero CVE" looks like in practice.
Wire scanning into a pre-commit hook for local development.

### 7. [Multi-container apps with Podman Compose]({{ "/docs/07-podman-compose/" | prepend: site.baseurl }})

Stand up a small multi-service application — a web tier, a
database, and an OpenTelemetry collector — entirely with
Hummingbird base images. Cover the gotchas that come up on
Fedora's SELinux-enforcing storage and the healthcheck timing
that catches people coming from Docker.

### 8. [Debugging Hummingbird containers]({{ "/docs/08-debugging/" | prepend: site.baseurl }})

The four-layer debugging strategy: local Podman commands,
log-first diagnostics, ephemeral debug containers, and the full
developer workflow. This is where the "no shell" image design
stops feeling like a constraint and starts feeling like a habit.

### 9. [Layer optimisation with zstd:chunked]({{ "/docs/09-zstd-chunked/" | prepend: site.baseurl }})

Build images that pull faster on subsequent updates by using the
`zstd:chunked` compression format. Covers Fedora 44's specific
configuration, dual-format manifest pushes for compatibility,
and how to verify the partial-pull savings.

### 10. [Splitting layers with chunkah]({{ "/docs/10-chunkah/" | prepend: site.baseurl }})

A deeper layer-management tool that complements `zstd:chunked`.
Walk through the canonical examples: splitting a base image,
isolating application code via xattrs, and combining `chunkah`
with `zstd:chunked` for the maximum effect on registry traffic
and node disk usage.

### 11. [Real-world examples]({{ "/docs/11-real-world-examples/" | prepend: site.baseurl }})

Five end-to-end scenarios: a secure Python microservice, an ML
inference container, a secure edge-application stack, a
DevSecOps pipeline, and the trusted-application stack that ties
everything in the tutorial together.

## Optional follow-ups (sections 12–17)

These sections go deeper on specific topics and can be read in
any order after the core tutorial.

### 12. [Creating custom SBOMs]({{ "/docs/12-custom-sbom/" | prepend: site.baseurl }})

Build SBOMs that capture build context (commit, builder image,
SOURCE_DATE_EPOCH), merge image-derived and source-derived SBOMs,
and attach them as Cosign attestations. Goes beyond what §5 covers.

### 13. [Hummingbird with Red Hat Trusted Libraries]({{ "/docs/13-trusted-libraries/" | prepend: site.baseurl }})

Extend the trust chain from base image to application
dependencies. Configure pip to use the Trusted Libraries pip
index, verify SLSA L3 provenance, and integrate with Hummingbird
Python images. Python only as of early 2026.

### 14. [Installing RPMs into the runtime image]({{ "/docs/14-installing-rpms/" | prepend: site.baseurl }})

Three patterns for adding OS packages to a Hummingbird runtime
that has no `dnf`: staged install with `--installroot`,
`rpm2cpio` extraction, and selective file copy. Worked example
adding `tzdata` and `ca-certificates` to a Python runtime.

### 15. [Automated updates with Renovate]({{ "/docs/15-renovate/" | prepend: site.baseurl }})

Configure Renovate to watch `quay.io/hummingbird` tags, with a
custom regex manager for the tutorial's `${HB_REGISTRY}` build-arg
pattern. Three tag-pinning strategies and CI gating with `grype`.

### 16. [Pruning Podman images and build cache]({{ "/docs/16-pruning/" | prepend: site.baseurl }})

Reclaim laptop disk as Hummingbird base updates accumulate.
`podman image prune`, `podman system prune`, age-based filters,
and a scheduled-cleanup recipe via systemd or launchd.

### 17. [Distroless gotchas — lessons from the field]({{ "/docs/17-distroless-gotchas/" | prepend: site.baseurl }})

A debugging-and-prevention reference for the rough edges that
surface running real workloads on Hummingbird's distroless runtime.
Covers `RUN` failures from missing shells, `HOME`/cache
permission errors, the `lib`/`lib64` split that breaks PYTHONPATH,
the shared-library `COPY` pattern for adding `libstdc++`/`libgomp`
to support NumPy, IPv4/IPv6 binding caveats that surface as
"Connection reset by peer", and decision criteria for when
Hummingbird isn't the right runtime for your workload. Each
gotcha is documented as symptom → root cause → fix.

## What this tutorial deliberately does not cover

A few things are out of scope on purpose:

- **OpenShift deployment.** Hummingbird is just as useful in a plain
  Kubernetes cluster, on a single VM with `podman-compose`, or on a
  developer laptop. We stay on the laptop.
- **Tekton pipelines.** Tekton is a fine target for Hummingbird, but
  it's another full tutorial. References to Tekton in the source
  material were lifted out and are being collected separately.
- **Air-gapped registry mirroring as a first-class topic.** We
  parameterise registry hosts via environment variables so the
  examples are mirror-friendly, but a full Satellite / Quay-mirror
  walkthrough is its own document.
- **Comparisons to other vendors.** This tutorial is about how to
  use Hummingbird, not how it stacks up against alternatives.

The [reconciliation plan]({{ "/plans/reconciliation-plan/" | prepend: site.baseurl }})
records which of these may be added in future iterations and which
are firmly out of scope.

## Estimated time

If you read every section and run every command, expect:

- **2 to 3 hours** for sections 1 through 6 (the core path).
- **1 to 2 hours** for sections 7 and 8 (compose and debugging).
- **2 to 3 hours** for sections 9, 10, and 11 (advanced material).
- **1 to 2 hours** for sections 12 through 16 (optional follow-ups,
  read individually as needed).

Sections 1 through 6 are the recommended first pass. The rest can
wait until you have a real reason to reach for them.
