# Hummingbird command-line demos

A set of eight terminal demos for presenting Red Hat Hardened Images
(Project Hummingbird) to an audience of admins. Each demo narrates what
it's about to do, **stops** so you can talk over the command on screen,
runs it live, and stops again before moving on. Run them one at a time or
back-to-back as a guided walkthrough.

Everything here is built on the tutorial's own conventions and images, so
the demos line up with `_docs/` and `examples/`.

## Running

```bash
./demos/run.sh           # interactive menu
./demos/run.sh all       # the full walkthrough, in order
./demos/run.sh 3         # just demo 3
./demos/run.sh check     # preflight: tools + registry settings
./demos/run.sh list      # list the demos
```

Each demo is also runnable on its own:

```bash
./demos/01-pull-and-inspect.sh
```

The scripts use a `bash` shebang and run fine from a `zsh` prompt. The
**narrate → stop → run** rhythm is the whole interaction: read what's on
screen, press **Enter** to run it, press **Enter** again to advance. To
rehearse without stopping, set `DEMO_NO_PAUSE=1`.

## The eight demos

| # | Demo | What it shows |
|---|------|---------------|
| 1 | Pull & inspect | `podman` + `skopeo` manifest, layer count, OCI labels, the no-shell moment |
| 2 | Debug sidecar | An ephemeral UBI toolbox sharing a shell-less container's PID/network namespaces |
| 3 | Minimal vs not | Size, layer count, and contents against a stock general-purpose image |
| 4 | Multi-stage build | Builder image compiles, runtime image ships only the binary (uses `examples/go-example`) |
| 5 | SBOMs & signing | `syft` SBOM, verifying Red Hat's signature + shipped SBOM, signing your own (offline) |
| 6 | CVE scanning | `grype` numbers for a hardened image vs a stock one vs your derived image; CI gating |
| 7 | Provenance | SLSA provenance on an image, then Trusted Libraries for Python deps (Tech Preview) |
| 8 | Distroless gotchas | RUN-needs-a-shell, `python` vs `python3`, Postgres env names, the shelled exceptions, and more |

## Prerequisites

The same tools the tutorial uses: `podman`, `skopeo`, `jq`, `syft`,
`grype`, `cosign`, and `curl`. Run `./demos/run.sh check` to see what's on
your `PATH` and what's missing — see `_docs/01-prerequisites.md` for
install notes (including the cosign-on-Fedora-44 caveat).

**Before a talk, pre-pull the images** so nothing stalls on conference
wifi. `run.sh check` prints a ready-made `podman pull` line for the images
the demos use.

## Registry overrides

The demos honor the tutorial's registry shortcuts and add one for the
signed Red Hat path. Override any of them before launching:

```bash
HB_REGISTRY=quay.io/hummingbird            # hardened images (no subscription needed)
RH_REGISTRY=registry.access.redhat.com     # UBI + toolbox
RHHI_REGISTRY=registry.access.redhat.com/hi  # signed Red Hat path (signatures/provenance live here)
FAT_IMAGE=docker.io/library/nginx:latest   # the non-minimal comparison image
```

For example, against the early-access org:

```bash
HB_REGISTRY=quay.io/hummingbird-hatchling ./demos/run.sh all
```

## Notes for presenters

- **Nothing aborts on stage.** A failed pull, an unreachable registry, or a
  signing-infra hiccup degrades to a short explanation and the demo keeps
  going. Steps that touch the network are deliberately allowed to fail soft.
- **Self-cleaning.** Each demo removes the containers, images, and temp
  files it created when it exits, so re-runs are idempotent and your machine
  stays tidy.
- **Refresh the scanner DB first.** Grype refuses to scan against a stale DB
  (default max age 5 days). Run `grype db update` in your preflight; demo 6
  also runs it automatically if the DB is invalid.
- **Layer count is not a size signal.** Hardened images have *more* layers
  than the stock image — that's chunkah (content-based splitting for cheap
  re-pulls), not bloat. Demo 3 says this; size, contents, package count
  (demo 5), and CVE count (demo 6) are the real signals.
- **Signature vs provenance verification differ.** On the Red Hat catalog
  path (`registry.access.redhat.com/hi/`), the public key verifies the SBOM
  attestation. Full SLSA *provenance* on Hummingbird images is verified with
  the project's build key from the upstream GitLab repo
  (`gitlab.com/redhat/hummingbird/containers`, `ci/key.pub`) — see Red Hat's
  "Reproducible builds in Project Hummingbird" guide. Demo 7 shows both.
- **cosign v3.** Demo 5's offline self-signing uses the v3 flags
  (`--use-signing-config=false --tlog-upload=false` + `--bundle` on both
  sign and verify). On cosign v2, drop `--use-signing-config=false`.
- **Trusted Libraries is gated.** The index is Tech Preview and
  authenticated; an unauthenticated request returns HTTP 401 (that's
  "not enrolled/authed", not "package missing"). Demo 7 reflects this.

## Changelog

- **r01.1** — Fixes from a live dry run: demo 3 reframes layer count as
  chunkah (hardened has *more* layers, by design); demo 5's SBOM contrast is
  now apples-to-apples (hardened nginx vs stock nginx) and the offline
  cosign sign/verify uses the v3 `--bundle` flags; demo 6 refreshes a stale
  Grype DB and builds the Go example itself if demo 4's image isn't present;
  demo 7 verifies the SBOM attestation with the public key and SLSA
  provenance with the upstream project key, and treats the Trusted Libraries
  401 as auth-required rather than absence. Network curls gained timeouts.
- **r01.0** — Initial eight demos + runner.

## Verification status

**Partially verified.** Syntax-checked, and the command strings were
exercised through a dry run; the r01.1 changes came from a real run on
Fedora 44. Still confirm image names/tags and the signed paths against
`images.redhat.com` (and the upstream GitLab key for provenance) before an
audience — run `./demos/run.sh check`, pre-pull, `grype db update`, then a
full `./demos/run.sh all` rehearsal.

