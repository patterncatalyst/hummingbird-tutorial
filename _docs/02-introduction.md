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
release time. The official product name is **Red Hat Hardened
Images (RHHI)**; "Project Hummingbird" is the project name the
community and this tutorial use, and the two refer to the same
catalog.

Announced in November 2025, it ships through Red Hat's trusted
build pipeline and inherits the same provenance, signing, and SBOM
infrastructure that backs the rest of the Red Hat container
ecosystem. The catalog is **available at no cost** with support
included for users running Red Hat Enterprise Linux or OpenShift
Container Platform.

The catalog covers three broad categories:

- **Languages and runtimes** — .NET, Go, Java (multiple JDK lines),
  Node.js, Python, and others.
- **Databases** — MariaDB, PostgreSQL.
- **Web servers and proxies** — Nginx, Caddy.

These are the components most commonly requested by Red Hat
customers, packaged as OCI images that are very small, contain
only what is needed to run the application, and are continuously
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

- A shell. `podman exec ... /bin/sh` will fail in most cases —
  see the variant note below for the exceptions.
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

## Image variants: default, builder, FIPS

Each Hummingbird image is published in three variants, identified
by tag suffix:

| Variant     | Tag suffix         | What it adds over default                        | When to use it                                   |
|-------------|--------------------|--------------------------------------------------|--------------------------------------------------|
| **Default** | `:<version>`       | (the distroless baseline)                        | Production runtime — final stage of every build  |
| **Builder** | `:<version>-builder` | Package manager and shell                       | Builder stage of multi-stage builds              |
| **FIPS**    | `:<version>-fips`, `:<version>-fips-builder` | FIPS-validated cryptographic modules; FIPS algorithms enforced by default | Environments requiring FIPS-validated cryptography |

**A note on shells in default images.** Most default images
genuinely have no shell — that's the distroless guarantee. A few
specific images do include one because the runtime ecosystem
expects it: **Golang, Core Runtime, and the full OpenJDK** ship
with a shell in their default variants. The JRE-only OpenJDK
variant (`openjdk:21-runtime`) and most others do not. If your
build pattern depends on shell-free runtime, pin to a specific
variant rather than assuming distroless across the board.

**FIPS variants exist for every image.** If your environment
requires FIPS-validated cryptography (US federal workloads,
some regulated industries), add `-fips` to the tag and the same
example works. The tutorial doesn't use FIPS by default so the
examples stay readable, but every command is FIPS-compatible
with the suffix added.

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

## What "hardened" means concretely

{% include excalidraw.html
   file="02-introduction-hardening-stack"
   alt="Four-layer pyramid showing the hardening stack: Source (SLSA 3 provenance, continuous upstream tracking, CVE monitoring), Packages (PIE/RELRO, stack canaries, dependency minimization), Images (distroless, non-root, reproducible), Benchmarks & scanning (CIS, STIG, OpenSCAP profiles)"
   caption="Figure 2.2 — The Hummingbird hardening stack" %}

Hardening is applied at four layers, each building on the one
below. None of the layers individually is novel; the value is in
applying all four to every image in the catalog by default.

### Source — ever-fresh remediations

Every component is tracked against its upstream source, with
continuous CVE monitoring and remediation. The build environment
was originally designed to **SLSA level 4** requirements — when
that level was retired from the SLSA framework, the project moved
to claiming **SLSA 3**, which is now the highest level the
framework defines. This is the layer that turns "we say we did the
right thing" into "we have a signed attestation that we did the
right thing."

### Packages — hardened compiler options

Components are compiled with the full RHEL hardening flag set:
**Position-Independent Executables (PIE)** and **RELRO** for
load-time and link-time hardening, **stack protectors** for
canaries against stack-smashing, **`FORTIFY_SOURCE=3`** for
compatibility checks on C and C++ string and memory operations.
Binary checks via `annobin` and `annocheck` confirm the flags
are actually present in the resulting ELF binaries — not just
documented in the build configuration.

Dependency minimization is applied at the package layer too:
`install_weak_deps=False` is set for every package install, so
recommended-but-not-required dependencies don't get pulled in
silently. The catalog ships the dependencies that are actually
used, not the ones that happened to be packaged together.

### Images — distroless, non-root, reproducible

The image-assembly layer applies the patterns described in this
section: distroless userspace, non-root default user (UID 1001),
hermetically built, signed manifests, attached SBOMs,
reproducible across rebuilds with the same inputs. This is where
the security of the lower layers becomes a property of the
artifact you actually pull from a registry.

### Benchmarks and scanning — CIS, STIG, OpenSCAP

Each image is verified against published security benchmarks —
**CIS** baselines, **STIG** profiles for federal workloads,
**OpenSCAP** scans against multiple compliance profiles. These
checks are part of the release gate, not a one-off audit. An
image that fails its benchmark scan doesn't ship.

The compounding effect of the four layers is what makes "near
zero CVE" defensible at release time, not just a marketing claim.

## How Hummingbird compares with UBI

UBI (Universal Base Image) and Hummingbird are both Red Hat
container image bases, with overlapping audiences and quite
different shapes. They're worth comparing directly because most
real platforms end up using both.

| Feature           | UBI                                      | Hummingbird (RHHI)                                    |
|-------------------|------------------------------------------|-------------------------------------------------------|
| Primary focus     | Flexible base with full RHEL userspace   | Purpose-built minimal attack surface                  |
| Use case          | Apps that need RHEL life cycle and breadth | Hardened components; reduce CVE management toil      |
| Update cadence    | Standard RHEL errata and life cycle      | Continuous and rolling                                |
| Image size        | Standard RPM install                     | Distroless build from a minimal base                  |
| Life cycle        | Predictable 10-year                      | Upstream releases and life cycle                      |
| Support           | Full when run on RHEL or OpenShift       | Full, included with RHEL or OpenShift                 |
| Redistribution    | Allowed                                  | Allowed                                               |
| Cost              | Free                                     | Free                                                  |

The two complement rather than compete. UBI is the right choice
when you need a familiar RHEL userspace, broad package
availability, or `dnf install` at runtime. Hummingbird is the
right choice when you want the smallest, hardest-to-attack
runtime — typically the deploy stage of a multi-stage build.
Section 17 of this tutorial expands on the decision criteria with
specific failure modes; the
[reconciliation plan]({{ "/plans/reconciliation-plan/" | prepend: site.baseurl }})
records every place in the tutorial where one or the other is
the deliberate choice.

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
