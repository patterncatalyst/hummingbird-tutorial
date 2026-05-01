---
title: Real-world examples
order: 11
description: Five end-to-end scenarios that pull together everything from the previous ten sections.
duration: 45 minutes
---

This section is where everything from sections 1–10 lands in a
real shape. Each example is a small but realistic scenario you
can build on your laptop and walk away with a usable artifact.

The five scenarios:

1. A secure Python microservice.
2. An ML inference container.
3. A secure edge-application stack.
4. A DevSecOps pipeline (the local equivalent of the cloud build).
5. The trusted application stack — how all the previous sections
   fit together.

You don't need to do all five. Pick the one closest to what you
actually build and skim the others.

## Scenario 1 — Secure Python microservice

This is the most direct usage of Hummingbird: a Flask or FastAPI
app, on a Hummingbird Python runtime, with its dependencies
controlled and its image signed.

The architecture:

```
Application code
      │
      ▼
Application dependencies (from your requirements.txt)
      │
      ▼
Hummingbird Python runtime image
      │
      ▼
Signed container image with SBOM attestation
      │
      ▼
Local laptop / VM / cluster
```

You already have the building blocks for this from sections 4
and 5. Combine them:

```bash
cd ~/hummingbird-tutorial/examples/python-example

# Build using the multi-stage pattern from section 4.
podman build -t my-py-service:1.0 .

# Tag for your registry.
podman tag my-py-service:1.0 "quay.io/${USER}/my-py-service:1.0"
podman push "quay.io/${USER}/my-py-service:1.0"

# Sign with your Cosign key (from section 5).
cosign sign --yes \
  --key ~/.config/containers/signing/cosign.key \
  "quay.io/${USER}/my-py-service:1.0"

# Generate and attach the SBOM.
syft "quay.io/${USER}/my-py-service:1.0" \
  -o spdx-json=/tmp/sbom.spdx.json

cosign attest --yes \
  --key ~/.config/containers/signing/cosign.key \
  --predicate /tmp/sbom.spdx.json \
  --type spdxjson \
  "quay.io/${USER}/my-py-service:1.0"
```

The result is an image where:

- The runtime is a near-zero-CVE Hummingbird base.
- Dependencies are explicit in `requirements.txt` and were
  resolved with a known tool (pip).
- The image is signed and the signature is verifiable.
- The SBOM is attached to the image and cryptographically tied
  to it via the same signature mechanism.

## Scenario 2 — ML inference container

Same shape as scenario 1, with one twist: ML containers tend to
have heavy native dependencies (NumPy, PyTorch, transformers).
The multi-stage pattern is even more valuable here because the
build stage compiles wheels for the heavy dependencies once,
and the runtime stage installs from those wheels — no compiler
in the runtime image.

```bash
mkdir -p ~/hummingbird-tutorial/examples/ml-example
cd ~/hummingbird-tutorial/examples/ml-example
mkdir -p app

cat > requirements.txt <<'EOF'
fastapi==0.115.*
uvicorn[standard]==0.32.*
numpy==2.*
# transformers / torch are large; uncomment only if you want to
# wait through the wheel build.
# transformers==4.*
# torch==2.*
EOF

cat > app/main.py <<'EOF'
from fastapi import FastAPI
import numpy as np

app = FastAPI()

@app.get("/")
def root():
    # Trivial NumPy operation to confirm the dependency loaded.
    return {
        "status": "ok",
        "matrix_sum": float(np.eye(3).sum())
    }
EOF

cat > Containerfile <<'EOF'
ARG HB_REGISTRY=quay.io/hummingbird

FROM ${HB_REGISTRY}/python:3.13-builder AS builder
WORKDIR /build
USER 1001

COPY --chown=1001:1001 requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /tmp/wheels -r requirements.txt

FROM ${HB_REGISTRY}/python:3.13
WORKDIR /app

COPY --from=builder /tmp/wheels /tmp/wheels
RUN pip install --no-cache-dir --no-index --find-links=/tmp/wheels \
        /tmp/wheels/*.whl \
    && rm -rf /tmp/wheels

COPY --chown=1001:1001 app/ ./app/

USER 1001
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "app.main:app", \
     "--host", "0.0.0.0", "--port", "8000"]
EOF

podman build -t hb-ml-example:latest .
podman run -d --name hb-ml -p 8000:8000 hb-ml-example:latest
sleep 3
curl -s http://localhost:8000 | jq
podman stop hb-ml && podman rm hb-ml
```

The same signing and SBOM flow from scenario 1 applies here
unchanged. The only thing that changes is what's in the SBOM —
which now includes the ML library set, all attributable back to
specific versions.

## Scenario 3 — Secure edge application

Edge deployments are the case where Hummingbird's small image
size has the most operational impact. Bandwidth on edge networks
is expensive; storage on edge devices is constrained; updates
need to propagate to many devices reliably.

The architecture for an edge gateway:

```
Edge data collector (Python or Go)
        │
        ▼
Trusted dependency set (your requirements.txt)
        │
        ▼
Hummingbird container runtime (small enough to fetch over
constrained links)
        │
        ▼
MicroShift / Podman on RHEL Device Edge / Podman on Fedora IoT
```

The Containerfile follows the same multi-stage pattern as
section 4. The differences for edge are operational, not in the
image itself:

- **Pin everything.** Use digest references rather than `:latest`
  tags. Edge devices often can't reach the registry frequently
  enough to handle tag-resolution race conditions.
- **Use `zstd:chunked` from section 9.** Updates over constrained
  links benefit most from partial-pull behaviour.
- **Use `chunkah` from section 10** to keep the application code
  in its own small layer, separate from the slow-changing
  dependency layer.

A representative image-build command for an edge target:

```bash
podman build \
  --layers \
  --compression-format zstd:chunked \
  --compression-level 6 \
  -t my-edge-app:1.0 \
  .
```

Higher compression level (6 vs the default 3) trades some build
time for a smaller image, which is the right tradeoff when the
image is going to be downloaded by hundreds of edge devices.

## Scenario 4 — DevSecOps pipeline (locally)

In a real organisation, the build pipeline for a Hummingbird-based
image runs in CI — Tekton, GitHub Actions, GitLab CI, Konflux.
For a tutorial, the same flow can be modelled in a local shell
script. The point is the **sequence of steps**, not the
orchestrator.

```bash
cat > ~/hummingbird-tutorial/scripts/secure-build.sh <<'BASH'
#!/usr/bin/env bash
# Local DevSecOps pipeline. Builds, scans, signs, and pushes a
# Hummingbird-based image, refusing to push if any high-severity
# CVE is found.

set -euo pipefail

IMAGE_NAME="${1:?usage: $0 <image-name> <git-sha>}"
GIT_SHA="${2:?usage: $0 <image-name> <git-sha>}"
REGISTRY="${REGISTRY:-quay.io/${USER}}"
IMAGE_REF="${REGISTRY}/${IMAGE_NAME}:${GIT_SHA}"
COSIGN_KEY="${COSIGN_KEY:-$HOME/.config/containers/signing/cosign.key}"

echo "→ [1/5] Build"
podman build -t "$IMAGE_REF" .

echo "→ [2/5] CVE scan (fail on high)"
grype "$IMAGE_REF" --fail-on high -o table

echo "→ [3/5] SBOM"
syft "$IMAGE_REF" -o spdx-json="/tmp/sbom-${GIT_SHA}.spdx.json"

echo "→ [4/5] Sign and attest"
podman push "$IMAGE_REF"
cosign sign --yes --key "$COSIGN_KEY" "$IMAGE_REF"
cosign attest --yes \
  --key "$COSIGN_KEY" \
  --predicate "/tmp/sbom-${GIT_SHA}.spdx.json" \
  --type spdxjson \
  "$IMAGE_REF"

echo "→ [5/5] Verify"
cosign verify --key "${COSIGN_KEY%.key}.pub" "$IMAGE_REF" >/dev/null
cosign verify-attestation \
  --key "${COSIGN_KEY%.key}.pub" \
  --type spdxjson \
  "$IMAGE_REF" >/dev/null

echo
echo "✔ Built, scanned, signed, attested: $IMAGE_REF"
BASH

chmod +x ~/hummingbird-tutorial/scripts/secure-build.sh
```

Run it:

```bash
cd ~/hummingbird-tutorial/examples/python-example
~/hummingbird-tutorial/scripts/secure-build.sh \
  my-py-service \
  $(git rev-parse --short HEAD 2>/dev/null || echo "manual")
```

The five steps map onto what a Tekton pipeline or GitHub Actions
workflow would do in CI — same commands, same intermediate
artifacts. Moving from this script to a hosted CI is mostly a
matter of expressing the same five steps in the orchestrator's
configuration language.

## Scenario 5 — The trusted application stack

This is the picture-on-the-wall summary. When all of the
patterns from this tutorial are combined, you have an image that
can be reasoned about layer by layer:

| Layer                       | What it gives you                              |
|-----------------------------|------------------------------------------------|
| Application code            | Your business logic                            |
| Application dependencies    | Verified at install time, recorded in SBOM     |
| Hummingbird runtime image   | Minimal, near-zero-CVE, signed by Red Hat      |
| Multi-stage build           | No build tools in the runtime image            |
| Cosign signature            | Tamper detection                               |
| SBOM attestation            | Compositional transparency                     |
| zstd:chunked + chunkah      | Efficient propagation across many nodes        |
| Podman / Buildah            | Daemonless, rootless build and run             |

Each layer is independent — you can adopt one without adopting
all of them, and each one is useful on its own. The compounding
benefit shows up when they're combined. An image built with all
of them in place is one where:

- A new CVE in a dependency is detectable in seconds via the
  SBOM.
- A change to the application is a small layer update, not a
  full re-pull.
- The image's authenticity is verifiable without trusting the
  registry.
- The runtime cannot be exec'd into for arbitrary debugging,
  reducing the attack surface.

That set of properties is hard to compose from a general-purpose
base image. It's straightforward to compose from a Hummingbird
base, which is the point of the project.

## Verify

You finished the tutorial. You should be able to:

- pick the right scenario for the workload in front of you,
- build, scan, sign, and attest a Hummingbird-based image
  with one local script,
- explain to a colleague which layer of the trusted stack solves
  which problem.

## Where to go next

You've finished the **core tutorial**. Sections 12 through 16 are
optional follow-ups that go deeper on specific topics:

- [Creating custom SBOMs]({{ "/docs/12-custom-sbom/" | prepend: site.baseurl }}) — extend §5 with build-context-aware SBOMs and signed attestations.
- [Hummingbird with Red Hat Trusted Libraries]({{ "/docs/13-trusted-libraries/" | prepend: site.baseurl }}) — extend the trust chain from base image down to your application's Python dependencies.
- [Installing RPMs into the runtime image]({{ "/docs/14-installing-rpms/" | prepend: site.baseurl }}) — three patterns for adding OS packages to a runtime that has no `dnf`.
- [Automated updates with Renovate]({{ "/docs/15-renovate/" | prepend: site.baseurl }}) — keep your base images current as Hummingbird publishes new tags.
- [Pruning Podman images and build cache]({{ "/docs/16-pruning/" | prepend: site.baseurl }}) — reclaim disk on a laptop where bases accumulate.

The [reconciliation plan]({{ "/plans/reconciliation-plan/" | prepend: site.baseurl }})
tracks what needs to be verified or expanded. If you spotted
something in the tutorial that didn't match what your environment
does, that's the right place to start — open an issue and we'll
pick it up against the plan.
