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
provenance that ships on a hardened image (rock-solid), then look at \
extending the same idea to Python packages with Red Hat Trusted Libraries."

section "Step 1 — Verify the image's SLSA provenance (the reliable anchor)"
say "Every hardened image carries a signed SLSA provenance attestation. \
Verifying it tells you which build system produced the image and from what \
source — not just that the bytes are intact, but how they came to be."
run_soft "cosign verify-attestation --key \"$RH_COSIGN_KEY\" --insecure-ignore-tlog \
  --type slsaprovenance \"$SIGNED\" \
  | jq -r '.payload|@base64d|fromjson | {predicateType, builder:(.predicate.builder.id // .predicate.runDetails.builder.id // \"(see predicate)\")}'"

section "Step 2 — The dependency-layer problem"
say "'pip install pandas' downloads a wheel built by whoever uploaded it; \
PyPI is a passthrough and re-signs nothing. If that upload pipeline is \
compromised, the wheel ships compromised. Trusted Libraries replaces the \
source: wheels REBUILT from source in Red Hat's pipeline, signed, with SLSA \
Level 3 provenance. You point pip at it and keep PyPI as a fallback."
run "printf '%s\n' '[global]' \
  'index-url = $TL_INDEX/' \
  'extra-index-url = https://pypi.org/simple/' > \"$TMP/pip.conf\"; cat \"$TMP/pip.conf\""

section "Step 3 — Which of your deps are covered?"
say "Coverage is the most-used tier first (NumPy, Pandas, Flask, …); the \
long tail falls back to PyPI. A quick audit just HEADs the index per package."
run_soft "for pkg in numpy pandas flask requests some-obscure-internal-lib; do \
    if curl -fsSL --max-time 6 -o /dev/null \"$TL_INDEX/\${pkg}/\"; then \
      printf '  \\033[0;32m✓ %s\\033[0m (trusted-libraries)\\n' \"\$pkg\"; \
    else \
      printf '  \\033[1;33m✗ %s\\033[0m (pypi.org only)\\n' \"\$pkg\"; \
    fi; \
  done"

section "Step 4 — Verify a package's provenance"
say "Each package ships an in-toto SLSA attestation. The verification shape \
(exact URL/key come from the packages.redhat.com docs as this is Tech \
Preview) is a cosign blob-attestation check against Red Hat's signing \
identity. We'll fetch the index entry to show the attestation is published; \
the verify command is below it."
run_soft "curl -fsSL --max-time 8 \"$TL_INDEX/pandas/\" | grep -oiE 'provenance[^\"<> ]*' | head -3"
note "cosign verify-blob-attestation \\"
printf '%b\n' "       ${YELLOW}  --certificate-identity-regexp '^https://github.com/redhat-' \\\\${NC}"
printf '%b\n' "       ${YELLOW}  --certificate-oidc-issuer https://token.actions.githubusercontent.com \\\\${NC}"
printf '%b\n' "       ${YELLOW}  pandas-<ver>.intoto.jsonl${NC}"
say "A clean result means the wheel was built from a specific upstream commit \
in Red Hat's verified pipeline and hasn't been tampered with since."

section "Step 5 — Outside the subscription? Calunga."
say "Trusted Libraries is the productized form of the upstream community \
project 'Calunga' — same architecture (curated index, SLSA-attested \
rebuilds) without a subscription. Note the limits today: Python-only, Tech \
Preview, and not every package is mirrored."

demo_end "Image provenance verifies cleanly with one published key; the same \
SLSA idea extends to your Python dependencies via Trusted Libraries. Base \
image, language packages, and your own code can all carry signatures that \
chain. Last up: the sharp edges you'll actually hit — distroless gotchas."
