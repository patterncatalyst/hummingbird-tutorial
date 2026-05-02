---
title: What is Project Hummingbird
order: 2
description: The conceptual grounding before we start running commands.
duration: 15 minutes
---

This is the only section of the tutorial without commands. Read it
once, then move on. The point is to understand **what** you are
about to use and **why**, so the commands in section 3 land
contextually rather than as magic.

## What Project Hummingbird is

Project Hummingbird is Red Hat's catalog of **minimal, hardened
container images** with a goal of zero known vulnerabilities at
release time. Announced in November 2025, it ships through Red Hat's
trusted build pipeline and inherits the same provenance, signing,
and SBOM infrastructure that backs the rest of the Red Hat container
ecosystem.

The catalog covers three broad categories:

- **Languages and runtimes** — .NET, Go, Java (multiple JDK lines),
  Node.js, Python, and others.
- **Databases** — MariaDB, PostgreSQL.
- **Web servers and proxies** — Nginx, Caddy.

These are the components most commonly requested by Red Hat
customers, packaged as OCI images that are very small, contain only
what is needed to run the application, and are continuously
rebuilt as upstream fixes appear.

## The core idea: rebuild, don't patch

Traditional base images carry hundreds of packages and a long
history of patches applied over time. When a new CVE is reported
against any of those packages, the platform team's job is to
backport a fix and rebuild — sometimes weeks after the upstream
fix exists.

Hummingbird inverts that loop. Hummingbird is its own distroless
distribution — a minimal userspace assembled from components that
flow through the Red Hat trust chain, but published as a distinct
image base rather than as a stripped variant of RHEL or UBI. The
project originated from the Fedora → RHEL pipeline that supplies
its components, and has matured into a separate Hummingbird image
base with its own build, release, and rebuild cadence.

When an upstream fix lands, the image is rebuilt clean from the
new components instead of being patched in place. Combined with
the small dependency graph, this means:

- Rebuilds are fast, so fixes propagate quickly.
- The rebuilt image carries no historical CVE legacy.
- The SBOM is small enough that you can actually read it.

## What "near zero CVE" really means

The marketing phrase is "zero CVE". The honest engineering phrase
is "near zero CVE". The reason is straightforward: with hundreds
of new vulnerabilities reported every day across the open-source
ecosystem, an image that scans clean at 9 a.m. can have a newly
disclosed vulnerability against one of its components by 5 p.m.
Holding a literal zero indefinitely is not achievable.

What Hummingbird *does* hold is:

- **Zero CVE at the moment of publication** — every published
  image is rebuilt and re-scanned.
- **Continuous rebuild on upstream fixes** — the catalog stays
  close to the moving zero line rather than drifting away from it.
- **Functionality testing as part of the rebuild** — fixes do not
  silently break the image.

Section 6 of this tutorial walks through scanning a Hummingbird
image yourself with Grype so you can see this in practice rather
than take it on faith.

## Where Hummingbird fits in the Red Hat container ecosystem

{% include excalidraw.html
   file="02-introduction-ecosystem"
   alt="Diagram showing the Red Hat container ecosystem: Fedora as upstream, RHEL/UBI as the stable base, Hummingbird as the minimal runtime catalog, and OpenShift as the platform layer"
   caption="Figure 2.1 — Hummingbird's place in the Red Hat container ecosystem" %}

Hummingbird and UBI are **sibling image distributions**, not stacked
layers. Both inherit components from the same Red Hat package pipeline,
but they assemble those components into different shapes for different
deployment needs:

| Layer / image base       | Role                                                                  |
|--------------------------|-----------------------------------------------------------------------|
| Fedora                   | Upstream component source, fast-moving                                |
| Red Hat package pipeline | Components stabilized, signed, made available to image builds         |
| RHEL / UBI               | Full enterprise base — broad package set, RPM tooling, shell, dnf    |
| Project Hummingbird      | Distroless image base — minimal userspace, near-zero CVE              |
| OpenShift / Kubernetes   | Platform layer that runs images of either kind                        |

The first two rows describe the **shared component pipeline** that
both image bases pull from. The next two rows are the image bases
themselves — distinct distributions that happen to share a trust
chain.

Hummingbird does not replace UBI. The two are complementary:

- **UBI** is what you reach for when you need a familiar RPM-based
  environment with broad package availability — typical for builder
  stages, anything that runs RPM-managed middleware, or workloads
  that need to install packages at runtime.
- **Hummingbird** is what you reach for when you want the
  smallest, hardest-to-attack runtime — typical for the final
  stage of a multi-stage build that ships a compiled binary, a JAR,
  or a Node bundle.

## What's in a Hummingbird image (and what isn't)

The deliberate omissions matter as much as the inclusions.

**A Hummingbird image typically contains:**

- The application runtime (a JVM, Node, Python, or a shared
  library set for compiled languages).
- The minimal set of OS libraries that runtime depends on.
- A non-root default user (commonly UID 1001).
- An OCI-compliant manifest with full SBOM metadata and build
  provenance attestations.

**A Hummingbird image typically does not contain:**

- A shell. Yes, really — `podman exec ... /bin/sh` will fail.
- A package manager (`dnf`, `microdnf`, `apt`, `apk`).
- Common diagnostic tools (`curl`, `ps`, `top`, `netstat`).
- A compiler or build toolchain.

This is the design. The set of things an attacker can use post-
compromise is dramatically smaller, and the set of things that
needs to be patched is a much smaller fraction of what a
general-purpose base image carries.

The cost is that **debugging changes shape**. We cover that in
detail in [section 8]({{ "/docs/08-debugging/" | prepend: site.baseurl }}),
but the short version is: instead of `exec`-ing into the
container with a shell, you attach a debug sidecar with the same
PID and network namespace.

## Build lineage and trust chain

Every Hummingbird image inherits the same trust chain as the rest
of the Red Hat container ecosystem, while remaining its own
distribution rather than a derivative of any other image:

1. Components originate in the Fedora ecosystem.
2. They are stabilised through the Red Hat package pipeline — the
   same pipeline that supplies the packages used by RHEL and UBI.
3. The Hummingbird image-build pipeline draws components from that
   pipeline and assembles them into Hummingbird's own minimal
   image base, with build provenance recorded as an attestation.
   The resulting image is a distroless Hummingbird OS — not a
   trimmed-down RHEL or UBI image.
4. Each image is signed using Sigstore-compatible signatures,
   verifiable with Cosign.
5. SBOMs are attached as OCI artifacts on the same manifest.

The shared trust chain means that if your platform already has a
signature-verification policy for `registry.access.redhat.com`,
extending it to `quay.io/hummingbird` is straightforward.
Section 5 of the tutorial walks through verifying a Hummingbird
image's signature and inspecting its SBOM.

## Three concepts that make the trust chain meaningful

Hummingbird's claims about provenance, signing, and SBOMs are
backed by three concrete things worth naming so you can find more
about them on your own.

### Distroless

**Distroless** is the design philosophy: an image that contains
the application's runtime and *only* what that runtime depends on
— no shell, no package manager, no diagnostic tools, no compiler.
The term comes from the broader OCI ecosystem; what Hummingbird
calls "near-zero CVE" is in large part a consequence of being
distroless.

Distroless is not the same as "small." Plenty of small images ship
a busybox shell or apk; those are minimalist but not distroless.
A distroless image is one where the attack surface has been
deliberately reduced to the language runtime and its libraries —
nothing else.

Distroless changes how you operate the image. You cannot `exec`
into a Hummingbird container to look around; you attach a debug
sidecar in a separate image that has those tools. Section 8 of
this tutorial covers that pattern in detail.

### Hermetic builds

A **hermetic build** is one that runs with no network access and
only the inputs that have been explicitly declared and signed in
advance. No `curl | sh` from the internet during compilation. No
"latest" pulls of build dependencies. Every byte that goes into
the resulting image comes from a known, attested source.

Hermetic builds are what make an SBOM meaningful. An SBOM
generated against a non-hermetic build can only describe what
*claims* to be in the image; an SBOM generated against a hermetic
build describes what's *provably* in the image, traceable back to
signed sources. Hummingbird's images are built hermetically, which
is why their SBOMs are trustworthy enough to be the foundation of
section 5's signing and verification flow.

### Konflux

**Konflux** is the open-source secure software supply chain
platform that produces Hummingbird images. It runs the hermetic
builds, generates the SBOMs, attaches the provenance attestations,
and signs the artifacts. From the consumer side — anyone pulling
a Hummingbird image — Konflux is invisible: you see a signed OCI
image with attached SBOM and attestation manifests. From the
producer side, Konflux is the machinery that gives those manifests
their trustworthiness.

You don't need to interact with Konflux directly to use
Hummingbird. The reason it's worth naming is that **the same
platform is available for your own builds**. If you want the same
provenance and SBOM properties for your application images that
Hummingbird has for its base images, building on Konflux is the
way to get there. That's a follow-on topic outside this tutorial's
scope, but it's the natural next step after section 5.

## Why this tutorial focuses on Podman

Podman, Buildah, and Skopeo were designed around the same OCI
specifications that Hummingbird images are built against. They have
no daemon, no privileged process to run, and a clean rootless story
that aligns with Hummingbird's "ship the smallest possible runtime"
philosophy.

Podman Compose adds the multi-container experience for local
development. Podman Desktop adds a GUI for the moments where a
graphical inspector is genuinely faster than a CLI command — image
size comparison, manifest inspection, vulnerability scanning
results.

Together they give you the full Hummingbird toolchain on a laptop
without needing to provision a cluster. The same commands work
unchanged on Fedora 43 and macOS once Podman Desktop is set up.

## Where to go next

Time to put a Hummingbird image on your machine.
[Podman basics with Hummingbird]({{ "/docs/03-podman-basics/" | prepend: site.baseurl }})
walks through pulling, inspecting, and running your first one,
and is where the design philosophy described above starts to feel
real.
