---
title: Creating custom SBOMs
order: 12
description: Generate richer, application-specific SBOMs that capture build context, multi-source dependency graphs, and cosign-attached attestations beyond what stock images ship with.
duration: 25 minutes
---

§5 introduced SBOMs by generating one from your finished image with
Syft and attaching it as a Cosign attestation. That gets you a
working chain of custody for the *image*. This section is about
going further: building an SBOM that captures **what the
application is**, not only what files happen to be in the image —
including build-time information that scanning a finished image
can't recover.

## Why a richer SBOM is worth the effort

A stock `syft <image>` SBOM tells you the OS packages and the
language packages that Syft can identify by inspecting the
filesystem. That's a strong starting point. It misses:

- **Build provenance.** Which Git commit, which CI run, which
  builder image, which build flags?
- **Logical dependencies that aren't files.** Database schemas,
  external services your app calls, message-broker topics it
  depends on.
- **Pre-build dependencies.** The `pom.xml` declares Maven deps;
  the `requirements.txt` declares Python deps. After build, the
  dependency tree is in the image, but the *intent* is in the
  source — and the source is what you committed and signed.

A custom SBOM combines all of these into one signable artifact.

## Workflow at a glance

The flow we'll build:

1. **Generate** an SBOM from your finished image (Syft).
2. **Augment** it with build-time information your build script
   knows but the image doesn't (commit, builder, environment).
3. **Merge** in source-side SBOMs from your build manifest
   (`pom.xml`, `requirements.txt`, `go.mod`).
4. **Sign and attach** the merged SBOM as a Cosign attestation.
5. **Verify** the attestation against your image at deploy time.

## Step 1 — Generate the base image SBOM

This is the §5 starting point, with one extra flag for the
schema we'll standardize on:

```bash
IMAGE="quay.io/hummingbird/python:3.13"

# CycloneDX 1.5 — broadly supported, maps cleanly onto SPDX 2.3 if
# downstream tools want SPDX. Use --output cyclonedx-json so we get
# a JSON file (not XML).
syft "$IMAGE" \
  --output cyclonedx-json="$PWD/sbom-base.cdx.json"

# Quick sanity check.
jq '.metadata.component.name, .components | length' sbom-base.cdx.json
```

## Step 2 — Augment with build context

Your CI run knows things the finished image can't: the commit, the
build host, the builder image digest, the `SOURCE_DATE_EPOCH` for
reproducible builds, the build args. Inject those as `properties`
on the root component.

```bash
COMMIT=$(git rev-parse HEAD)
SHORT=$(git rev-parse --short HEAD)
BUILDER_IMG="quay.io/hummingbird/python@$(skopeo inspect \
  --format '{{.Digest}}' \
  docker://quay.io/hummingbird/python:3.13-builder)"
SDE=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}

jq --arg commit "$COMMIT" \
   --arg short "$SHORT" \
   --arg builder "$BUILDER_IMG" \
   --arg sde "$SDE" \
   --arg image "$IMAGE" \
'.metadata.properties += [
  {"name": "build:git.commit",        "value": $commit},
  {"name": "build:git.commit.short",  "value": $short},
  {"name": "build:builder.image",     "value": $builder},
  {"name": "build:source.date.epoch", "value": $sde},
  {"name": "build:image.target",      "value": $image}
]' sbom-base.cdx.json > sbom-augmented.cdx.json
```

CycloneDX `properties` are an open-by-design extension point;
Sigstore policy controllers can read them at admission time.

## Step 3 — Merge in source-declared dependencies

Syft against the finished image sees what was *installed*. The
source manifest tells you what was *requested*. They overlap, but
not perfectly — pinned versions, optional deps, dev-only deps,
and transitive resolution can diverge. Generate a second SBOM
straight from the source manifest:

```bash
# Python — directly from requirements.txt.
syft scan dir:. \
  --select-catalogers +python-installed-package-cataloger,+python-package-cataloger \
  --output cyclonedx-json=sbom-source.cdx.json

# Java — from the pom.xml. Syft reads the resolved tree if you've
# already run `mvn dependency:tree -DoutputFile=tree.txt`.
mvn -B dependency:tree -DoutputFile=deps.txt
syft scan dir:. --output cyclonedx-json=sbom-source.cdx.json

# Go — from go.mod.
syft scan dir:. --select-catalogers +go-mod-file-cataloger \
  --output cyclonedx-json=sbom-source.cdx.json
```

Then merge image-derived and source-derived SBOMs. The
[cyclonedx-cli](https://github.com/CycloneDX/cyclonedx-cli)
tool does this natively:

```bash
# Install once if you don't have it.
# go install github.com/CycloneDX/cyclonedx-cli/cmd/cyclonedx@latest

cyclonedx merge \
  --input-files sbom-augmented.cdx.json sbom-source.cdx.json \
  --output-file sbom-final.cdx.json \
  --hierarchical
```

The `--hierarchical` flag preserves the relationship: image
contains source-installed packages. A flat merge would lose that.

## Step 4 — Sign and attach to the image

Now make the SBOM a **signed attestation** on the image, so anyone
pulling the image can recover and verify it.

```bash
# Generate a key pair if you haven't already (§5 walked through this).
# cosign generate-key-pair

# Attach the merged SBOM as a CycloneDX attestation.
cosign attest \
  --key cosign.key \
  --type cyclonedx \
  --predicate sbom-final.cdx.json \
  "$IMAGE"
```

The image now has three things attached: the original signature
(from §5), the original SBOM attestation (from §5), and the new
custom SBOM attestation. They coexist; verifiers can pick which
predicate type they care about.

## Step 5 — Verify at deploy time

Whoever consumes the image can pull just the attestation and
check it without trusting the full image first:

```bash
cosign verify-attestation \
  --key cosign.pub \
  --type cyclonedx \
  "$IMAGE" \
  | jq -r '.payload' \
  | base64 -d \
  | jq '.predicate.metadata.properties[] | select(.name | startswith("build:"))'
```

If your build properties come back, the chain is intact: the
attestation was signed by your key, the image hasn't been
substituted, and your build context is recoverable.

## Putting it in CI

The whole flow fits in a shell script that the build pipeline
runs after `podman push`. Save this as `scripts/sign-and-attest.sh`
in your repo:

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?usage: sign-and-attest.sh <image-ref>}"
KEY="${COSIGN_KEY:-cosign.key}"

# 1. Image SBOM
syft "$IMAGE" --output cyclonedx-json=sbom-base.cdx.json

# 2. Augment
COMMIT=$(git rev-parse HEAD)
SDE=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}
jq --arg commit "$COMMIT" --arg sde "$SDE" --arg image "$IMAGE" \
'.metadata.properties += [
  {"name":"build:git.commit","value":$commit},
  {"name":"build:source.date.epoch","value":$sde},
  {"name":"build:image.target","value":$image}
]' sbom-base.cdx.json > sbom-augmented.cdx.json

# 3. Source SBOM
syft scan dir:. --output cyclonedx-json=sbom-source.cdx.json

# 4. Merge
cyclonedx merge \
  --input-files sbom-augmented.cdx.json sbom-source.cdx.json \
  --output-file sbom-final.cdx.json \
  --hierarchical

# 5. Sign image, attach SBOM
cosign sign --key "$KEY" "$IMAGE"
cosign attest --key "$KEY" --type cyclonedx \
  --predicate sbom-final.cdx.json "$IMAGE"

echo "✓ signed image and attached merged SBOM"
```

In your GitHub Actions or Tekton pipeline, run this after the
build-and-push step. The same script works locally for testing.

## Where Trusted Libraries fits in

If your build pulls Python dependencies from
[Red Hat Trusted Libraries](https://packages.redhat.com/trusted-libraries),
those packages already ship with SLSA Level 3 provenance and
their own SBOMs. The `cyclonedx-cli merge` step pulls them into
your aggregate SBOM automatically — Syft reads the metadata that
pip wrote to `site-packages/*.dist-info/METADATA`. The next
section walks that integration.

## Verify before moving on

You should be able to:

- generate an image SBOM with Syft and inspect it with `jq`,
- explain why source-declared and image-derived SBOMs differ,
- merge two CycloneDX documents with `cyclonedx merge`,
- sign and attach a custom predicate type with `cosign attest`,
- verify the attached attestation with `cosign verify-attestation`.

## Where to go next

[Hummingbird with Red Hat Trusted Libraries]({{ "/docs/13-trusted-libraries/" | prepend: site.baseurl }})
extends the trust chain from base image to application
dependencies — the natural next step once you're signing your
own SBOMs.
