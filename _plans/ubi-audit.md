---
title: UBI usage audit
description: Every UBI reference in the tutorial, categorized as keep, switch, or flagged for follow-up. Use this to keep the tutorial Hummingbird-first.
---

The tutorial's stated goal is to use Hummingbird wherever possible and
call out the exceptions. This document is a one-page audit of every
UBI reference currently in `docs/`, with a verdict for each.

## Summary

| Verdict | Count | Meaning |
|---|---|---|
| **Keep — Hummingbird wrong choice** | 4 | UBI is the right tool here; the tutorial would suffer from forcing Hummingbird |
| **Keep — already Hummingbird** | 3 | The reference says "ubi-micro" but the image is `${HB_REGISTRY}/ubi-micro` (Hummingbird's catalog) — naming is inherited from RHEL |
| **Keep — fall-back instructions** | 4 | Explicit fall-back guidance for when a Hummingbird builder doesn't yet exist; valuable, leave in |
| **Keep — comparative content** | 5 | Hummingbird-vs-UBI explanations, comparison tables, ecosystem diagrams; intentionally educational |
| **Switch when image name is confirmed** | 1 | Smoke test in §1 uses `ubi9/ubi9-micro` — should switch to a Hummingbird image once a confirmed pull URL is known |
| **Track in reconciliation** | 5 | UBI references where the question is "does Hummingbird have an equivalent and what's its name" |

## Per-reference detail

### docs/01-prerequisites.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 212 | `# Red Hat registry — needed for any UBI builder images we fall back to` | Keep — fall-back | Comment is honest about why both registries are configured |
| 382 | `podman run --rm "$RH_REGISTRY/ubi9/ubi9-micro:latest" echo "..."` | **Switch** | The smoke test should use a Hummingbird image so step 1 already proves the Hummingbird registry works. Blocked on confirming a stable Hummingbird image name with no auth requirements. Until confirmed, leave UBI here so the smoke test always succeeds. |

### docs/02-introduction.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 78 | Diagram alt text mentioning UBI in the ecosystem | Keep — comparative | The diagram explicitly compares ecosystem layers |
| 86 | "RHEL / UBI — Stable enterprise base images" | Keep — comparative | Comparison table |
| 90, 92 | "Hummingbird does not replace UBI" + "UBI is what you reach for when..." | Keep — comparative | Whole point of §2 is to position the two |

### docs/03-podman-basics.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 15 | "compared the layer count and size against a UBI image" | Keep — comparative | Pedagogical contrast |
| 168 | `# Attach a UBI toolbox container that shares the Hummingbird` | Keep — Hummingbird wrong choice | Toolbox is a debug image. Hummingbird's whole design is to remove tools; using it as a debug sidecar would defeat the point |
| 174 | `"$RH_REGISTRY/ubi9/toolbox:latest"` | Keep — Hummingbird wrong choice | Same |
| 178 | Description of the toolbox shell session | Keep — Hummingbird wrong choice | Same |

### docs/04-multi-stage-builds.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 33 | "Fall back to a UBI builder only when no Hummingbird builder is available" | Keep — fall-back | Explicit instruction |
| 149 | `> ${RH_REGISTRY}/ubi9/nodejs-20:latest` (fall-back snippet) | Keep — fall-back | Same |
| 160 | "switch to the UBI fall-back" | Keep — fall-back | Same |
| 275, 339-340 | `${HB_REGISTRY}/ubi-micro:latest` (Go example runtime) | **Track in reconciliation** | This points at Hummingbird's catalog (`HB_REGISTRY` prefix). The image *name* is `ubi-micro`, inherited from RHEL's image lineage. **Verify** that `ubi-micro` is actually published under `quay.io/hummingbird/`. If it isn't, this falls back to `${RH_REGISTRY}/ubi9/ubi-micro`, which is UBI not Hummingbird |
| 370 | "A static binary plus `ubi-micro` is typically under 30 MB" | Keep — already Hummingbird | Same as above; just descriptive prose |

### docs/08-debugging.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 140 | `${RH_REGISTRY}/ubi9/toolbox:latest` (sidecar pattern) | Keep — Hummingbird wrong choice | Toolbox is right for debug |
| 153 | "The toolbox image — a UBI image with bash, curl, ss..." | Keep — Hummingbird wrong choice | Same |
| 192 | `registry.access.redhat.com/ubi9/toolbox:latest` (SYS_PTRACE variant) | Keep — Hummingbird wrong choice | Same |
| 224 | `--image=registry.access.redhat.com/ubi9/toolbox:latest` (kubectl debug example) | Keep — Hummingbird wrong choice | Same |

### docs/00-outline.md

| Line | Reference | Verdict | Notes |
|---|---|---|---|
| 49 | "ecosystem alongside RHEL and UBI" | Keep — comparative | Tutorial introduction |

## Action items

1. **Confirm `quay.io/hummingbird/ubi-micro` exists.** If yes, update the
   reconciliation plan §A row from `unverified` to `verified` and the
   `ubi-micro` references in §4 keep working as-is. If no, the Go
   example needs to fall back to `${RH_REGISTRY}/ubi9/ubi-micro`,
   and the prose around it should be honest that this is a UBI
   fallback (Hummingbird doesn't yet provide an `ubi-micro` equivalent).

2. **Pick a Hummingbird smoke-test image.** §1's rootless smoke test
   should pull from `${HB_REGISTRY}/...` instead of UBI. Blocked on a
   stable image name with no auth. Candidates once confirmed:
   `${HB_REGISTRY}/python:latest`, `${HB_REGISTRY}/go:latest`.

3. **Toolbox lock-in is intentional.** Don't try to replace the
   debug-toolbox references with a Hummingbird image. Hummingbird is
   minimalism; toolbox is the opposite. Keep the four toolbox
   references (3× in §8, 1× in §3).

4. **Leave the UBI fall-back instructions in §4 alone.** They're a
   honest accommodation of the early-access reality, not a tutorial
   flaw. If the reconciliation plan §A confirms full Hummingbird
   coverage of all four language examples, then the fall-back blocks
   can be removed in a future commit.
