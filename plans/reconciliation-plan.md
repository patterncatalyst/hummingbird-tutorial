---
title: Reconciliation plan
description: What in this tutorial is verified, what is in flight, and what needs validation against a live Fedora 43 or macOS environment.
---

This document tracks the **gap between what the tutorial claims and
what we have actually verified end-to-end**. It is the single
authoritative list of things to check, fix, or expand before the
tutorial is declared production-ready. Every section that contains
unverified content has a "Reconciliation note" callout linking
back here.

The plan has four columns:

- **Status** — `verified`, `in flight`, `unverified`, `out of scope`.
- **What** — the claim or example that needs checking.
- **Where** — the section it appears in.
- **How to verify** — the concrete check that closes the item.

## Conventions

- A `verified` row has been run end-to-end on **both** Fedora 43
  and macOS by at least one contributor, with the exact commands
  shown in the tutorial.
- An `in flight` row is being actively worked on; the assigned
  contributor is named where known.
- An `unverified` row is a claim taken from source material that
  has not been re-validated against a current environment.
- An `out of scope` row is something we deliberately decided not
  to verify in this iteration; the reason is given.

A row moves from `unverified` to `verified` only after both
platforms have been exercised. If something works on Fedora but
not macOS (or vice versa), it stays `in flight` with a note about
which platform passed.

## A. Image catalog and naming

The single biggest source of unverified claims in the tutorial is
the **exact set of Hummingbird images that exist** and **how they
are named**. The user-supplied registry pointer is
`https://quay.io/organization/hummingbird`; the source material
referenced both `quay.io/hummingbird` (post-GA) and
`quay.io/hummingbird-hatchling` (early-access). Until the image
catalog is confirmed, every Containerfile in the tutorial relies
on an environment variable (`HB_REGISTRY`) and image-name
pattern that may need adjustment.

| Status | What | Where | How to verify |
|---|---|---|---|
| unverified | Org name `quay.io/hummingbird` is the canonical post-GA pull URL | All sections | Browse `https://quay.io/organization/hummingbird` and confirm; if the early-access org is still authoritative, switch the default to `quay.io/hummingbird-hatchling` and update the prerequisites |
| unverified | Builder images named `<lang>-<ver>-builder` (e.g. `nodejs-20-builder`, `python-311-builder`, `openjdk-21-builder`, `go-1.22-builder`) | §4, §7, §11 | Confirm against the live catalog; update names in all four examples in §4 if the convention is different |
| unverified | Runtime images named `<lang>-<ver>` for Node and Python, `<lang>-<ver>-runtime` for OpenJDK | §3, §4, §7, §11 | Confirm — the asymmetry between Node/Python and Java naming may need to be normalised |
| unverified | `ubi-micro` exists in the Hummingbird catalog under that name | §4 (Go example), §10 | Confirm; if it is only available from `registry.access.redhat.com/ubi9/ubi-micro`, update the Go example to fall back there |
| unverified | A Hummingbird `nginx` image is published under the org | §3, §6 | Confirm; this is the demonstration image used throughout §3 |
| unverified | A Hummingbird `postgresql-16` image is published | §7 | Confirm; the compose stack depends on it. If only `postgresql-15` or a different naming exists, update §7 |

**Recommended fix path.** Once the catalog is confirmed, replace
any `unverified` row above with the actual image name and bump
its status. If a name in the tutorial differs, do a global
find-and-replace across `docs/` and update §4 example
Containerfiles to match.

## B. Tool versions

The tutorial assumes specific tool families and versions. These
are likely to drift but should be re-checked at major release
cadences.

| Status | What | Where | How to verify |
|---|---|---|---|
| verified | Podman 5.x is available in Fedora 43 default repos | §1 | `dnf info podman` on a fresh Fedora 43 VM |
| unverified | Podman Compose available as `podman-compose` in Fedora 43 repos at the version §7 needs | §1, §7 | Run §7's compose stack end-to-end on a fresh Fedora 43 |
| unverified | `brew install --cask podman-desktop` brings the Podman CLI alongside it on macOS | §1 | Fresh macOS install; confirm `podman --version` works after the cask completes |
| unverified | Podman Desktop tarball install path on Fedora produces a working desktop entry on Fedora 43's default desktop (GNOME) | §1 | Click-through test on Fedora 43 GNOME |
| unverified | The Grype install script writes to `~/.local/bin` cleanly under both Fedora 43 and macOS | §1 | Confirm `grype --version` works after install on both |

## C. Section-specific items

### §3 — Podman basics

| Status | What | How to verify |
|---|---|---|
| unverified | Hummingbird Nginx listens on port 8080 by default (not 80) | Pull the image, run, `curl localhost:8080` |
| unverified | The "no shell" error message text matches what the tutorial shows ("no such file") | Run `podman exec ... /bin/sh` against the image |
| unverified | `ubi9/toolbox:latest` is still the right diagnostic image to recommend | Confirm Red Hat has not deprecated it in favour of a different name |

### §4 — Multi-stage builds

| Status | What | How to verify |
|---|---|---|
| unverified | The Node example builds end-to-end with the `nodejs-20-builder` and `nodejs-20` runtime images | `podman build -t hb-node . && podman run hb-node` |
| unverified | The Python example's wheel-build pattern works against `python-311-builder` (i.e., gcc/headers are present in the builder image) | Build with a requirement that needs C-extension compilation (e.g. `psycopg2`) and confirm wheel build succeeds |
| unverified | The Go example produces a static binary that runs on `ubi-micro` without missing-library errors | `podman run hb-go && curl localhost:8080` |
| unverified | The Quarkus JVM example's `mvnw` invocation works with the JDK and Maven shipped in `openjdk-21-builder` | Quarkus `getting-started` skeleton + the §4 Containerfile |
| in flight | The 3-stage AOT-cache Containerfile (compile / train / run) referenced in §11 needs to be written out | Adapt FINDINGS.md §1.4 into a working multi-stage Containerfile |

### §5 — SBOMs and signing

| Status | What | How to verify |
|---|---|---|
| unverified | `cosign verify-attestation --type spdxjson` against a stock Hummingbird image works without supplying a custom key | Try the §5 invocation against a live Hummingbird image and document any extra flags needed |
| unverified | The example `policy.json` snippet in §5 is correct for current Podman 5.x behaviour | Run a `podman pull` against an image with a mismatched signature and confirm it is rejected |

### §6 — CVE scanning

| Status | What | How to verify |
|---|---|---|
| unverified | A freshly-rebuilt Hummingbird Nginx image scans clean with current Grype DB | `grype` after `grype db update` on a current day |
| unverified | The pre-commit hook in §6 actually fires on `git commit` and aborts on high-severity matches | Stage a change, commit, observe |

### §7 — Podman Compose

| Status | What | How to verify |
|---|---|---|
| unverified | The `:Z` flag on compose volume mounts behaves as a no-op on macOS (does not error) | Run §7's compose stack on macOS as written |
| unverified | The Hummingbird Postgres image accepts the `POSTGRESQL_USER`/`POSTGRESQL_PASSWORD`/`POSTGRESQL_DATABASE` env vars (UBI/RHEL convention) rather than the upstream `POSTGRES_*` convention | Confirm against the published image |
| unverified | Service-name DNS (`http://otel:4318`) resolves correctly under `podman-compose` and not just `docker compose` | Confirm with `podman-compose up` and an exec into the web container |

### §8 — Debugging

| Status | What | How to verify |
|---|---|---|
| verified | The `--pid=container:` and `--network=container:` flags work for the sidecar pattern under rootless Podman 5.x | Demonstrated on Fedora 43 |
| unverified | `--volumes-from` works rootless without surprises on a Hummingbird container | Try against §3's Nginx with a mounted volume |

### §9 — zstd:chunked

This whole section is the most speculative in the tutorial. The
broad mechanics are stable; the precise flag set should be
validated.

| Status | What | How to verify |
|---|---|---|
| unverified | `--compression-format zstd:chunked` is the correct flag spelling on Podman 5.x build and push | `podman build --help` and `podman push --help` on a current build |
| unverified | The resulting layer media type is `application/vnd.oci.image.layer.v1.tar+zstd` exactly as the tutorial claims | `skopeo inspect --raw` and read |
| unverified | Quay.io accepts the chunked format | Push an image and observe |
| unverified | The "byte-savings on second pull" demo is reproducible enough to ship in a tutorial | Run the demo, measure, decide whether it's a reliable demonstration or whether to soften the claim |

### §10 — chunkah

The most speculative section. Before this section can be moved
to `verified`, the following all need confirmation.

| Status | What | How to verify |
|---|---|---|
| unverified | The tool `chunkah` is currently distributed with that name | Find the canonical upstream project URL |
| unverified | The CLI surface used in the tutorial (`chunkah split --source ... --output ... --layer ... --boundary ... --xattr-key ...`) matches the actual tool | Install the tool and run `chunkah --help` |
| unverified | The "split a Hummingbird image into 3 cacheable layers" example in §10 produces a working image | End-to-end build and pull test |
| in flight | If the tool's CLI surface is materially different from what the tutorial assumes, rewrite §10 against the real surface | Same as above |

### §11 — Real-world examples

| Status | What | How to verify |
|---|---|---|
| unverified | The Python ML example's wheel-build for `numpy` succeeds against the Hummingbird Python builder image | Try the example with `numpy` uncommented in `requirements.txt` |
| unverified | The `secure-build.sh` end-to-end pipeline runs cleanly with no manual intervention | Run with a real image name and confirm all five steps pass |
| out of scope | OpenShift / Konflux deployment of the trusted-stack image | Future tutorial — not this one |

## D. Cross-cutting items

| Status | What | Where | How to verify |
|---|---|---|---|
| unverified | All env-var-based registry overrides (`HB_REGISTRY`, `RH_REGISTRY`) propagate cleanly into `podman build --build-arg` invocations | All sections | Build §4's Node example with a non-default `HB_REGISTRY` and confirm |
| unverified | The Excalidraw embed include renders correctly on GitHub Pages with the configured `baseurl` | `_includes/excalidraw.html` | Deploy a copy of the site to GitHub Pages and click each diagram |
| in flight | The 10 Excalidraw diagrams are placeholder SVGs hand-drawn for shape; they need re-creation in actual Excalidraw with the editable `.excalidraw` files in sync | `assets/diagrams/` | Open each `.excalidraw` file on excalidraw.com, polish the diagram, re-export the SVG, commit both files |
| verified | The `examples/` directory contains runnable skeletons for `node-example`, `python-example`, `go-example`, `compose-stack`, and `ml-example`, each mirroring the inline content of its referencing tutorial section | `examples/` | `find examples -type f` and confirm every Containerfile matches the corresponding `cat > Containerfile <<EOF` block in the docs. The Quarkus example is intentionally omitted as a skeleton — it needs a real Maven project to be useful |

## E. Decisions taken (not for reconciliation, just on record)

These are conscious choices, not gaps. Listed here so reviewers
don't accidentally "fix" them.

| Decision | Rationale |
|---|---|
| No comparison to Docker, Chainguard, Kubernetes alternatives | Tutorial is about how to use Hummingbird, not how it stacks up |
| No Antora/Asciidoc; plain Jekyll markdown | Owner directive |
| No Tekton or GitHub Actions content in the main tutorial | Belongs in a separate pipelines tutorial |
| Air-gapped Satellite mirroring is parameterised but not walked through | Scope; the build args make it possible without making it the focus |
| Hummingbird-vs-UBI comparison is kept | Within the Red Hat ecosystem; this is positioning, not competition |
| `:Z` on every bind mount, even though it's a no-op on macOS | Single source for both platforms is worth more than per-platform purity |
| UID 1001 throughout | Matches Hummingbird default |
| `BUILDAH_FORMAT=oci` set in the prerequisites | Cosign signs OCI; Docker-format would silently break signing later |

## F. Working list of follow-ups

A short list of "next things to do" once the items above start
landing. Roughly priority-ordered.

1. **Verify the image catalog (Section A above).** This unblocks
   nearly everything else — without it, no Containerfile in the
   tutorial is testable.
2. **Run §1 end-to-end on a fresh Fedora 43 VM.** The prerequisite
   doc has the largest blast radius on its own.
3. **Run §1 end-to-end on a fresh macOS install.** Same reason.
4. **Run §3 and §4 end-to-end.** These are the sections most
   readers will actually do; they need to be bulletproof.
5. **Re-create the 10 Excalidraw diagrams.** The current SVGs
   are functional sketches.
6. **Stand up the §7 compose stack on both platforms.** Lots of
   Fedora-vs-macOS surface area.
7. **Validate §9 (zstd:chunked) and §10 (chunkah)** against
   current upstream tooling. If anything has changed materially,
   rewrite.
8. **Build out the `examples/` directory** so each Containerfile
   in the tutorial has a corresponding runnable project.

---

When everything in sections A through D has moved to `verified`
or `out of scope`, this tutorial is done.
