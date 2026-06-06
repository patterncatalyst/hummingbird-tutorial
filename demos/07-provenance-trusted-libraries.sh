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
signed supply-chain metadata on a hardened image, see how SLSA provenance \
is verified, then extend the same idea to Python packages with Trusted Libraries."

section "Step 1 — What supply-chain metadata is attached?"
say "Cosign can list everything hanging off an image's manifest — its \
signature plus any attestations (SBOM, provenance). Quickest way to SEE that \
a hardened image ships signed supply-chain metadata."
run_soft "cosign tree \"$SIGNED\""

section "Step 2 — Verify a signed attestation with the public Red Hat key"
say "On the Red Hat catalog path, the published key verifies the SBOM \
attestation — proof the bytes are vouched for, not merely present. (Provenance \
on these images is verified a little differently; that's the next step.)"
run_soft "cosign verify-attestation --key \"$RH_COSIGN_KEY\" --insecure-ignore-tlog \
  --type spdxjson \"$SIGNED\" \
  | jq -r '.payload|@base64d|fromjson | {predicateType, subject:(.subject[0].name // \"(see payload)\")}'"

section "Step 3 — Full SLSA provenance: the documented upstream path"
say "The SLSA *provenance* attestation on Hummingbird images is verified with \
the project's build key, per Red Hat's 'Reproducible builds in Project \
Hummingbird' guide. That key currently lives in the upstream GitLab project, \
so this is the honest way to verify provenance today — it records WHERE and \
HOW the image was built."
run_soft "cd \"$TMP\" && curl -fsSL --max-time 10 -o hb-ci-key.pub \
  https://gitlab.com/redhat/hummingbird/containers/-/raw/fc5c29670347ea2666ec2910a28880f76f5cdc4e/ci/key.pub && \
  cosign verify-attestation --key hb-ci-key.pub --insecure-ignore-tlog \
    --type slsaprovenance quay.io/hummingbird-hatchling/jq:latest \
  | jq -r '.payload|@base64d|fromjson | {predicateType, builder:(.predicate.builder.id // .predicate.runDetails.builder.id // \"(see predicate)\")}'"
note "Per developers.redhat.com 'Reproducible builds in Project Hummingbird' —"
printf '%b\n' "    ${YELLOW}  provenance key: gitlab.com/redhat/hummingbird/containers (ci/key.pub).${NC}"

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

demo_end "The image's signed metadata verifies with a public key; full SLSA \
provenance verifies with the project build key (documented upstream); and the \
same idea extends to your Python dependencies via Trusted Libraries. Last up: \
the sharp edges you'll actually hit — distroless gotchas."
