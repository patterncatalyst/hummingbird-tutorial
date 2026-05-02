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

This section was the largest source of unverified claims in early
drafts of the tutorial. As of the catalog audit, all of the
section's claims have been **verified** against the live Quay.io
catalog. Status is `verified` unless otherwise noted.

| Status | What | Where | Notes / verification |
|---|---|---|---|
| **verified** | Org name `quay.io/hummingbird` is the canonical pull URL | All sections | Confirmed via `curl https://quay.io/v2/hummingbird/<name>/tags/list`. Pre-GA `hummingbird-hatchling` org is no longer the authoritative source for the images we reference |
| **verified** | Repository naming is **just the software name**: `go`, `python`, `openjdk`, `nodejs`, `postgresql`, `nginx` — version is in the **tag**, not the repo | All sections | Earlier tutorial drafts assumed `<name>-<ver>-builder` repos (the wrong shape). All Containerfiles have been rewritten to `<name>:<ver>-builder` and `<name>:<ver>` tag-based form |
| **verified** | Tags exist at major (`:3`), major-minor (`:3.13`), and patch (`:3.13.5`) granularities, plus floating `:latest` | All sections | Tutorial pins to major-version tags (`:3.13`, `:21`, `:1.26`, `:20`, `:18`, `:1`) for stability |
| **verified** | Both runtime and builder variants are published as tag suffixes: `:<ver>` is runtime, `:<ver>-builder` is builder | All sections | All §4 examples and the Quarkus example use this pattern |
| **verified** | OpenJDK has both full JDK (`:21`) and JRE-only (`:21-runtime`) deploy variants | §4 Quarkus example | `:21-runtime` is the smaller deploy image; the Quarkus example uses `:21-builder` → `:21-runtime` |
| **verified** | A `-fips` suffix exists on every variant (e.g. `python:3.13-fips-builder`) for FIPS-validated environments | §1 prerequisites callout | Mentioned but not used in the main tutorial flow |
| **verified** | An alternative canonical path exists at `registry.access.redhat.com/hi/<name>:<tag>` (Red Hat container catalog) | §8 (uses this path); §1 callout documents it as an alternative `HB_REGISTRY` value | Confirmed by working command: `registry.access.redhat.com/hi/python:latest-builder` resolves |
| **verified** | `nginx` is published as `quay.io/hummingbird/nginx`, current major-tag `:1` (1.28 is the latest minor) | §3, §5, §6 | Tutorial uses `nginx:1` after the catalog rewrite |
| **verified** | `postgresql` is published, current major-tag `:18` (18.3 is the latest minor) | §7 compose stack | Tutorial originally referenced `postgresql-16`, which doesn't exist; corrected to `postgresql:18` |
| **verified** | A Hummingbird Go runtime image exists at `${HB_REGISTRY}/go:1.26` separate from the `-builder` variant | §4 Go example | Confirmed via tag-list. The runtime is a minimal base for Go static binaries |
| **verified** 2026-05-01 | Hummingbird `openjdk:21-builder` ships the JDK and `javac` but **not Maven**. Build attempts that invoke `mvn` fail with `mvn: command not found` | §4 Quarkus example | Discovered during build testing. Hummingbird's design philosophy keeps builder images minimal — build tools that not every user needs (like Maven) aren't pre-installed. For a Maven-driven project, switch the build stage to `${RH_REGISTRY}/ubi9/openjdk-21:latest` (Maven pre-installed) and keep the Hummingbird runtime. The Quarkus example does this; logged as a "Keep — Hummingbird wrong choice" entry in the UBI audit |

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
| unverified | The Node example builds end-to-end with the `nodejs:20-builder` and `nodejs:20` runtime images | `podman build -t hb-node . && podman run hb-node` |
| unverified | The Python example's wheel-build pattern works against `python:3.13-builder` (i.e., gcc/headers are present in the builder image) | Build with a requirement that needs C-extension compilation (e.g. `psycopg2`) and confirm wheel build succeeds |
| unverified | The Go example produces a static binary that runs on the Hummingbird Go runtime without missing-library errors | `podman run hb-go && curl localhost:8080` |
| unverified | The Quarkus JVM example's `mvnw` invocation works with the JDK and Maven shipped in `openjdk:21-builder` | Quarkus `getting-started` skeleton + the §4 Containerfile |
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
| in flight | The stronger sidecar variant — `--cap-add=SYS_PTRACE`, `--security-opt label=disable`, `--user 0` — actually permits `strace -p 1` against the target container's PID 1 on rootless Podman | Run the variant from §8, install strace, attach. If `Operation not permitted` still surfaces, document the additional `userns` or rootful escape required |
| in flight | The in-image debug pattern (mount code into builder image, install debug tools via `dnf`) works against `registry.access.redhat.com/hi/python:latest-builder` end-to-end | Run the §8 worked example for Python with pdb on Fedora 43 and macOS |
| unverified | The Java equivalent (`hi/openjdk-21:latest-builder` + `jdb`) works; specifically, that `jdb` is in `$PATH` in the builder image | Run §8's Java worked example |
| unverified | The Go equivalent works — `go install` of delve, then `dlv debug` against mounted source | Run §8's Go worked example |
| unverified | `kubectl debug --image=... --target=...` against a Hummingbird-based pod actually shares the right namespaces with `--target` | Stand up a single-pod cluster (Kind/Minikube), apply `kubectl debug` from §8 |

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

## G. Testing matrix

End-to-end testing is its own track. None of the rows below mean
"the tutorial is broken if this doesn't pass" — they mean "we
haven't actually run the steps end-to-end on a clean machine and
recorded the result". As tests pass, the corresponding rows in
sections A through D can usually be flipped to `verified`.

Testing is split into three layers, cheapest to most expensive:

### G.1 — Catalog availability (cheap, scriptable)

One `skopeo inspect` per image used in the tutorial. Confirms the
image exists, the manifest is healthy, and the SBOM/signature
attestations are attached. Takes ~30 seconds total.

| Status | Image | Test command |
|---|---|---|
| not yet run | `quay.io/hummingbird/openjdk:21-builder` | `skopeo inspect docker://quay.io/hummingbird/openjdk:21-builder` |
| not yet run | `quay.io/hummingbird/openjdk:21-runtime` | `skopeo inspect docker://quay.io/hummingbird/openjdk:21-runtime` |
| not yet run | `quay.io/hummingbird/python:3.13-builder` | `skopeo inspect docker://quay.io/hummingbird/python:3.13-builder` |
| not yet run | `quay.io/hummingbird/python:3.13` | `skopeo inspect docker://quay.io/hummingbird/python:3.13` |
| not yet run | `quay.io/hummingbird/go:1.26-builder` | `skopeo inspect docker://quay.io/hummingbird/go:1.26-builder` |
| not yet run | `quay.io/hummingbird/go:1.26` | `skopeo inspect docker://quay.io/hummingbird/go:1.26` |
| not yet run | `quay.io/hummingbird/nodejs:20-builder` | `skopeo inspect docker://quay.io/hummingbird/nodejs:20-builder` |
| not yet run | `quay.io/hummingbird/nodejs:20` | `skopeo inspect docker://quay.io/hummingbird/nodejs:20` |
| not yet run | `quay.io/hummingbird/postgresql:18` | `skopeo inspect docker://quay.io/hummingbird/postgresql:18` |
| not yet run | `quay.io/hummingbird/nginx:1` | `skopeo inspect docker://quay.io/hummingbird/nginx:1` |

A loop that runs the lot:

```bash
for img in \
  openjdk:21-builder openjdk:21-runtime \
  python:3.13-builder python:3.13 \
  go:1.26-builder go:1.26 \
  nodejs:20-builder nodejs:20 \
  postgresql:18 nginx:1; do
  echo "=== ${img} ==="
  skopeo inspect "docker://quay.io/hummingbird/${img}" 2>&1 \
    | head -3
  echo
done
```

### G.2 — Build-and-run smoke tests (medium, ~15 min)

Build each example end-to-end and confirm it runs. Doesn't validate
the tutorial prose around it — just that the Containerfile produces
a working image.

| Status | What | Command |
|---|---|---|
| **verified** 2026-05-01 | `examples/quarkus-example` builds | First test failed: `mvn: command not found` — Hummingbird `openjdk:21-builder` ships the JDK but not Maven. Fixed by switching the build stage to UBI's `openjdk-21` (which pre-installs Maven) while keeping `${HB_REGISTRY}/openjdk:21-runtime` for the deploy stage. Now passes |
| **verified** 2026-05-01 | Quarkus app responds on :8080 | Returns `{"javaVersion":"21.0.11","runtime":"hummingbird-quarkus","status":"ok","javaVendor":"Red Hat, Inc."}` — confirms multi-stage handoff (UBI builder → Hummingbird JRE) works and the JVM in production is the Hummingbird one |
| **verified** 2026-05-01 | `examples/python-example` builds | First test failed: runtime stage `RUN pip install` errored with `/bin/sh not found` — Hummingbird runtime images are distroless, no shell. Fixed by moving install to the builder with `--prefix=/build/install` and copying the prefix across; required `python3` (not `python`) in CMD; required `PYTHONPATH` covering both `lib/` and `lib64/`. Now passes |
| **verified** 2026-05-01 | Python app responds | Build + run + curl confirmed end-to-end |
| **verified** 2026-05-01 | `examples/go-example` builds | First test failed: `mkdir /.cache: permission denied` — UID 1001 can't write to `/`. Fixed by setting `ENV HOME=/build GOCACHE=/build/.cache/go-build` in the builder stage. Now passes |
| **verified** 2026-05-01 | Go app responds | Build + run + curl confirmed end-to-end |
| **verified** 2026-05-01 | `examples/ml-example` builds | Required additional fixes beyond python-example: `COPY libstdc++.so.6*` and `libgcc_s.so.1*` for NumPy's compiled extensions; `libgomp.so.1*` for the OpenMP backend that's delay-loaded at compute time. Symptom of missing libgomp was a silent SIGSEGV in the worker manifesting as "Connection reset by peer" with no traceback |
| **verified** 2026-05-01 | ML app responds | Build + run + curl confirmed end-to-end. NumPy `np.eye(3).sum() = 3.0` returns over the wire |
| **FAIL → fixed** 2026-05-01 | `examples/node-example` builds | First test failed: `npm error code EACCES, syscall open, path /build/package-lock.json` — same root cause as the Go and Python builders (UID 1001 needs `HOME` set, plus npm's WORKDIR write needs the user to own it). Fixed by adding `USER 1001`, `ENV HOME=/build`, `ENV NPM_CONFIG_CACHE=/build/.npm` to the builder stage. Second test failed: runtime stage `COPY /build/node_modules` errored — the example had no dependencies, so `npm install` produced no `node_modules/` directory to copy. Fixed by adding `pino` (a real, small structured-logger dep) to package.json so the multi-stage example actually demonstrates dependency flow. Re-run needed |
| **verified** 2026-05-01 | `examples/compose-stack` brings up | First test failed: db exited with `Error: Database is uninitialized and superuser password is not specified` — Hummingbird's `postgresql:18` uses upstream Postgres env var names (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`), not sclorg names (`POSTGRESQL_USER`, etc.). Fixed by switching env var names in `compose.yaml`. Now passes |
| **verified** 2026-05-01 | Compose stack web tier reachable | `curl localhost:3000` returns expected JSON. End-to-end three-service stack: db (Hummingbird postgresql:18) → web (Hummingbird nodejs:20, depends_on db healthy) → otel (third-party docker.io/otel/opentelemetry-collector-contrib) |
| **verified** 2026-05-01 | Compose stack DB queryable | `psql -U app -d appdb -c 'select 42'` returns 42 from inside the db container |

### G.3 — Tutorial walkthroughs (expensive, ~5 hours)

Run the tutorial sections end-to-end on a clean machine, record any
prose that didn't match what happened. This is the gold-standard
test; the §1 walkthrough alone catches most issues.

| Status | What | Where to run |
|---|---|---|
| not yet run | §1 prerequisites — full install on fresh Fedora 43 VM | Clean VM |
| not yet run | §1 prerequisites — full install on fresh macOS | Clean macOS install or VM |
| not yet run | §3 podman basics — pull, run, sidecar pattern | Either platform after §1 passes |
| not yet run | §4 multi-stage — Quarkus example | Either platform |
| not yet run | §4 multi-stage — Python example | Either platform |
| not yet run | §4 multi-stage — Go example | Either platform |
| not yet run | §5 SBOM and signing — generate and verify | Either platform |
| not yet run | §6 CVE scanning — clean and dirty image | Either platform |
| not yet run | §7 compose stack — full bring-up | Fedora primarily (SELinux surface) |
| not yet run | §8 debugging — sidecar pattern, in-image-builder | Either platform |
| not yet run | §9 zstd:chunked — partial-pull verification | Fedora |
| not yet run | §10 chunkah — split, recombine | Fedora |
| not yet run | §11 real-world examples — at least one of the five | Either platform |
| not yet run | §12 custom SBOM — full augment-merge-sign cycle | Either platform |
| not yet run | §13 Trusted Libraries — pip install with provenance verify | Either platform; needs Red Hat account |
| not yet run | §14 RPM install — staged install + COPY rootfs | Either platform |
| not yet run | §15 Renovate — config validates against a real repo | Wherever |
| not yet run | §16 pruning — every command runs cleanly | Either platform |

### G.4 — How to record results

When a row passes, change `not yet run` to `verified <YYYY-MM-DD>`.
When a row fails, change to `FAIL <YYYY-MM-DD>` and add a footnote
with the error and a link to a fix-up issue. Don't delete failing
rows; the failure history is the record of what's been hit.

When a row passes on one platform but not the other, split it into
two rows (Fedora / macOS) so the partial verification is captured.

---

When everything in sections A through G has moved to `verified`
or `out of scope`, this tutorial is done.
