#!/usr/bin/env bash
# Local DevSecOps pipeline. Builds, scans, signs, and pushes a
# Hummingbird-based image, refusing to push if any high-severity
# CVE is found. See docs/11-real-world-examples.md scenario 4 for
# context.

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <image-name> <git-sha>" >&2
    echo "Example: $0 my-py-service \$(git rev-parse --short HEAD)" >&2
    exit 64
fi

IMAGE_NAME="$1"
GIT_SHA="$2"
REGISTRY="${REGISTRY:-quay.io/${USER}}"
IMAGE_REF="${REGISTRY}/${IMAGE_NAME}:${GIT_SHA}"
COSIGN_KEY="${COSIGN_KEY:-$HOME/.config/containers/signing/cosign.key}"
COSIGN_PUB="${COSIGN_KEY%.key}.pub"
SBOM_PATH="${SBOM_PATH:-/tmp/sbom-${IMAGE_NAME}-${GIT_SHA}.spdx.json}"

if [[ ! -f "$COSIGN_KEY" ]]; then
    echo "Cosign key not found at $COSIGN_KEY" >&2
    echo "Run 'cosign generate-key-pair' first (see §5 of the tutorial)." >&2
    exit 1
fi

echo "→ [1/5] Build $IMAGE_REF"
podman build -t "$IMAGE_REF" .

echo
echo "→ [2/5] CVE scan (fail on high)"
grype "$IMAGE_REF" --fail-on high -o table

echo
echo "→ [3/5] Generate SBOM ($SBOM_PATH)"
syft "$IMAGE_REF" -o "spdx-json=$SBOM_PATH"
echo "   Package count: $(jq '.packages | length' "$SBOM_PATH")"

echo
echo "→ [4/5] Push, sign, attest"
podman push "$IMAGE_REF"
cosign sign --yes --key "$COSIGN_KEY" "$IMAGE_REF"
cosign attest --yes \
    --key "$COSIGN_KEY" \
    --predicate "$SBOM_PATH" \
    --type spdxjson \
    "$IMAGE_REF"

echo
echo "→ [5/5] Verify"
cosign verify --key "$COSIGN_PUB" "$IMAGE_REF" >/dev/null
cosign verify-attestation \
    --key "$COSIGN_PUB" \
    --type spdxjson \
    "$IMAGE_REF" >/dev/null

echo
echo "✔ Built, scanned, signed, attested: $IMAGE_REF"
echo "  SBOM:       $SBOM_PATH"
echo "  Public key: $COSIGN_PUB"
