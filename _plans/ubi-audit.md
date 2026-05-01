---
title: UBI usage audit
description: Every UBI reference in the tutorial, categorized as keep, switch, or flagged for follow-up. Use this to keep the tutorial Hummingbird-first.
---

The tutorial's stated goal is to use Hummingbird wherever possible
and call out the exceptions clearly. This document is a one-page
audit of every UBI reference currently in `_docs/`, with a verdict
for each.

> **Important context.** There is no `${HB_REGISTRY}/ubi-micro`.
> Hummingbird and UBI are two separate Red Hat catalogs;
> Hummingbird does not republish UBI images under its org. Where
> the tutorial used to refer to a "Hummingbird `ubi-micro`
> runtime", that was wrong — there is no such thing. The Go
> example's runtime is now `${HB_REGISTRY}/go:1.26`. UBI's actual
> `ubi-micro` lives at `registry.access.redhat.com/ubi9/ubi-micro`
> and is a legitimate fall-back when a Hummingbird equivalent
> doesn't exist.

## Summary

| Verdict | Count | Meaning |
|---|---|---|
| **Keep — Hummingbird is wrong choice** | 4 | UBI is the right tool here; forcing Hummingbird would defeat the design |
| **Keep — fall-back instructions** | 3 | Explicit fall-back guidance for when a Hummingbird builder doesn't yet exist; valuable, leave in |
| **Keep — comparative content** | 5 | Hummingbird-vs-UBI explanations and ecosystem positioning; intentionally educational |
| **Switch when image name is confirmed** | 1 | Smoke test in §1 uses `ubi9/ubi9-micro` — switch to a Hummingbird image once one with public-pull access is identified |

## Per-reference detail

### docs/01-prerequisites.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 212 | Comment about Red Hat registry being needed for UBI fall-backs | Keep — fall-back | Honest about why both registries are configured |
| 382 | `podman run --rm "$RH_REGISTRY/ubi9/ubi9-micro:latest"` (smoke test) | **Switch** | Should pull from Hummingbird so step 1 already proves the Hummingbird registry works. Blocked on a stable Hummingbird image with public-pull access. Until then, keep UBI here so the smoke test always succeeds without auth |

### docs/02-introduction.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 78 | Diagram alt text mentioning UBI in ecosystem | Keep — comparative | Diagram explicitly compares ecosystem layers |
| 86 | "RHEL / UBI — Stable enterprise base images" | Keep — comparative | Comparison table |
| 90, 92 | "Hummingbird does not replace UBI" + "UBI is what you reach for when..." | Keep — comparative | Whole point of §2 is to position the two |

### docs/03-podman-basics.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 15 | "compared the layer count and size against a UBI image" | Keep — comparative | Pedagogical contrast |
| 168, 174, 178 | UBI toolbox sidecar pattern | Keep — Hummingbird wrong choice | Toolbox is a debug image. Hummingbird's whole design is to remove tools; using it as a debug sidecar would defeat the point |

### docs/04-multi-stage-builds.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 35 | "Fall back to a UBI builder only when no Hummingbird builder is available" | Keep — fall-back | Explicit instruction at the section level |
| Quarkus example builder | `${RH_REGISTRY}/ubi9/openjdk-21:latest` | Keep — Hummingbird wrong choice | Hummingbird `openjdk:21-builder` ships the JDK but not Maven; UBI is the right tool for Maven-driven Java builds. Verified 2026-05-01. Runtime stays on `${HB_REGISTRY}/openjdk:21-runtime` |
| 588, 599 | Node appendix UBI fall-back: `${RH_REGISTRY}/ubi9/nodejs-20` | Keep — fall-back | Honest fall-back if the Hummingbird Node-20 image doesn't exist yet |

### docs/08-debugging.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 140, 153, 192, 224 | UBI toolbox in sidecar pattern, SYS_PTRACE variant, kubectl debug | Keep — Hummingbird wrong choice | Toolbox is the right image for debug |

### docs/00-outline.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 49 | "ecosystem alongside RHEL and UBI" | Keep — comparative | Tutorial introduction |

## Action items

1. **Confirm `quay.io/hummingbird/go:1.26` exists.** This
   is the Go example's runtime image. If it doesn't exist, the
   Go example must fall back to
   `${RH_REGISTRY}/ubi9/ubi-micro:latest` (a UBI image), and §4's
   prose must be revised to acknowledge the runtime is a UBI
   fall-back rather than Hummingbird.

2. **Pick a Hummingbird smoke-test image for §1.** The rootless
   smoke test at line 382 should pull from `${HB_REGISTRY}/...`
   instead of UBI. Blocked on a stable image name with no auth.
   Candidates once confirmed: `${HB_REGISTRY}/python:latest`,
   `${HB_REGISTRY}/go:1.26`.

3. **Toolbox lock-in is intentional.** Don't try to replace the
   debug-toolbox references with a Hummingbird image. Hummingbird
   is minimalism; toolbox is the opposite. Keep the four toolbox
   references (3× in §8, 1× in §3).

4. **Leave the UBI fall-back instructions in §4 alone.** They're
   an honest accommodation of the early-access reality, not a
   tutorial flaw. If reconciliation §A confirms full Hummingbird
   coverage of the language examples, the fall-back blocks can be
   removed in a future commit.
