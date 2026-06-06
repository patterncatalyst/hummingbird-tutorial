#!/usr/bin/env bash
# Demo 7 — Provenance: image SLSA + Trusted Libraries for Python deps.
#          on a hardened image, then extend the same idea to application
#          packages via Red Hat Trusted Libraries (Tech Preview, Python-only).
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib/_demo.sh"

demo_title 7 "Provenance — from the image down to a trusted-libraries package"
require_tools cosign jq curl || exit 0

SIGNED="$RHHI_REGISTRY/curl:latest"
TL_INDEX="https://packages.redhat.com/trusted-libraries/simple"
demo_tmpdir >/dev/null; TMP="$DEMO_TMPDIR"

demo_intro "The base image gives you trust at the container layer. But your \
app also runs whatever you pulled from PyPI — a public, unaudited index. \
Provenance closes that gap: a SLSA attestation records WHERE and HOW an \
artifact was built, signed so you can verify it. We'll first verify the \
signed supply-chain metadata on a hardened image and what it attests to, \
then extend the same idea to Python packages with Trusted Libraries."

section "Step 1 — What supply-chain metadata is attached?"
say "Cosign can list everything hanging off an image's manifest — its \
signature plus any attestations (SBOM, provenance). Quickest way to SEE that \
a hardened image ships signed supply-chain metadata."
run_soft "cosign tree \"$SIGNED\""

section "Step 2 — Verify a signed attestation with the public Red Hat key"
say "On the Red Hat catalog path, the published key verifies the SBOM \
attestation — proof the bytes are vouched for, not merely present. (These \
images also ship signed SLSA provenance; we'll list what's attached next.)"
run_soft "cosign verify-attestation --key \"$RH_COSIGN_KEY\" --insecure-ignore-tlog \
  --type spdxjson \"$SIGNED\" \
  | jq -r '.payload|@base64d|fromjson | {predicateType, subject:(.subject[0].name // \"(see payload)\")}'"

section "Step 3 — What's in the signed attestations"
say "Ask the image what predicate types it actually carries (verified in \
step 2 against the public key). This enumerates them straight from the \
manifest rather than guessing a type that may not match."
run_soft "cosign download attestation \"$SIGNED\" 2>/dev/null \
  | jq -rs '.[] | (.payload|@base64d|fromjson|.predicateType)' | sort -u | sed 's/^/  predicate: /'"
say "Beyond the SBOM, every Hummingbird image is built with signed SLSA \
provenance and is reproducible bit-for-bit from it — the strongest supply- \
chain check there is. The exact verify-and-rebuild recipe (it evolves, so \
follow the source) is 'Verifying Reproducibility' at hummingbird-project.io \
and 'Reproducible builds in Project Hummingbird' on developers.redhat.com."

section "Step 4 — The dependency-layer problem"
say "'pip install pandas' downloads a wheel built by whoever uploaded it; \
PyPI is a passthrough and re-signs nothing. Trusted Libraries replaces the \
source: wheels REBUILT from source in Red Hat's Konflux pipeline, signed, \
with SLSA Level 3 provenance. You point pip at it and keep PyPI as a fallback."
run "printf '%s\n' '[global]' \
  'index-url = $TL_INDEX/' \
  'extra-index-url = https://pypi.org/simple/' > \"$TMP/pip.conf\"; cat \"$TMP/pip.conf\""

section "Step 5 — Trusted Libraries access requires authentication"
say "The index is gated: Trusted Libraries is Tech Preview, so you enroll and \
authenticate (pip configured with your Red Hat credentials). An unauthenticated \
request returns HTTP 401 — that means 'not enrolled / not authed', NOT 'package \
missing'. Don't read 401 as absence."
run_soft "curl -sS --max-time 8 -o /dev/null -w 'trusted-libraries index -> HTTP %{http_code}\n' \"$TL_INDEX/numpy/\""
say "Coverage starts with the most-used packages (NumPy, Pandas, Flask, …) and \
grows; the long tail falls back to PyPI via your extra-index."

section "Step 6 — Verify a package's provenance (the shape)"
say "Once authenticated, each wheel ships an in-toto SLSA attestation you \
verify against Red Hat's signing identity — the same idea as the image \
provenance above, one layer up the stack:"
note "cosign verify-blob-attestation \\"
printf '%b\n' "    ${YELLOW}  --certificate-identity-regexp '^https://github.com/redhat-' \\\\${NC}"
printf '%b\n' "    ${YELLOW}  --certificate-oidc-issuer https://token.actions.githubusercontent.com \\\\${NC}"
printf '%b\n' "    ${YELLOW}  --bundle pandas-<ver>.sigstore.json pandas-<ver>.whl${NC}"
say "The upstream community form of all this is the Calunga project — same \
architecture (curated index, SLSA-attested rebuilds). Limits today: \
Python-only and Tech Preview, with npm and Java planned."

demo_end "The image's signed metadata verifies with a public key, and the \
image is reproducible bit-for-bit from its signed provenance; the same idea \
extends to your Python dependencies via Trusted Libraries. Last up: the \
sharp edges you'll actually hit — distroless gotchas."
