#!/usr/bin/env bash
# Demo 5 — SBOMs & signing: generate an SBOM, verify Red Hat's, sign your own.
#          signature, and verifying the Red Hat-signed SBOM + your own.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib/_demo.sh"

demo_title 5 "SBOMs & signing — the artifacts attached to an image"
require_tools podman syft cosign jq || exit 0

IMG="$HB_REGISTRY/curl:latest"
SIGNED="$RHHI_REGISTRY/curl:latest"   # Red Hat path carries the signatures
FAT="$FAT_IMAGE"
demo_tmpdir >/dev/null; TMP="$DEMO_TMPDIR"

demo_intro "Three distinct things can hang off an image manifest, addressed \
by digest: (1) a signature — 'I vouch for these bytes'; (2) an SBOM \
attestation — a signed bill of materials; (3) a SLSA provenance attestation \
— how it was built. We'll generate an SBOM locally, see how small a hardened \
image's bill of materials is, verify Red Hat's signature and shipped SBOM, \
then sign and verify an artifact ourselves — all without a registry push."

section "Step 1 — Generate an SBOM with Syft"
say "SPDX-JSON is the right default — it's what cosign attaches and what \
downstream tools expect. The headline number is the package count."
run "syft \"$IMG\" -o spdx-json=\"$TMP/curl.spdx.json\" -q"
run "echo \"packages: \$(jq '.packages | length' \"$TMP/curl.spdx.json\")\""
run "jq -r '.packages[0:6][] | \"  - \\(.name) \\(.versionInfo // \"\")\"' \"$TMP/curl.spdx.json\""

section "Step 2 — Contrast with a non-minimal image's SBOM"
say "Smaller image, smaller bill of materials, fewer things to track."
run "syft \"$FAT\" -o spdx-json=\"$TMP/fat.spdx.json\" -q; \
     echo \"hardened curl : \$(jq '.packages|length' \"$TMP/curl.spdx.json\") packages\"; \
     echo \"stock nginx   : \$(jq '.packages|length' \"$TMP/fat.spdx.json\") packages\""

section "Step 3 — Verify Red Hat's signature on the shipped image"
say "Hummingbird images on the Red Hat path are signed with Red Hat's key. \
Verifying proves the bytes are untampered since Red Hat signed them. The key \
is published; --insecure-ignore-tlog skips the public transparency log."
run_soft "cosign verify --key \"$RH_COSIGN_KEY\" --insecure-ignore-tlog \"$SIGNED\" | jq '.[0].critical.image'"

section "Step 4 — Read the SBOM that SHIPS with the image"
say "The same verify machinery can extract the signed SBOM attestation that \
Red Hat attached — a bill of materials you didn't have to generate or trust \
on faith, because the signature backs it."
run_soft "cosign verify-attestation --key \"$RH_COSIGN_KEY\" --insecure-ignore-tlog \
  --type spdxjson \"$SIGNED\" \
  | jq -r '.payload|@base64d|fromjson|.predicate.packages[].name' | head -15"

section "Step 5 — Sign and verify something yourself (offline)"
say "Signing an image is the same flow against a registry ref. To keep this \
self-contained we'll sign a file: generate a key pair, sign, verify. \
COSIGN_PASSWORD is set empty so nothing prompts on stage; we keep it all \
local with no transparency-log upload."
run "cd \"$TMP\" && COSIGN_PASSWORD='' cosign generate-key-pair && ls cosign.*"
run "cd \"$TMP\" && echo 'hello hardened world' > artifact.txt && \
     COSIGN_PASSWORD='' cosign sign-blob --key cosign.key --tlog-upload=false --yes \
       --output-signature artifact.sig artifact.txt && echo signed"
run "cd \"$TMP\" && cosign verify-blob --key cosign.pub --insecure-ignore-tlog \
       --signature artifact.sig artifact.txt"
say "In a real pipeline you'd 'cosign sign --key cosign.key \$IMAGE' against a \
registry ref, then 'cosign attest --predicate sbom.json --type spdxjson' to \
attach your own SBOM. See _docs/05-sbom-and-signing.md for the push-based flow."

demo_end "A hardened image's SBOM is short enough to read; the signature and \
SBOM that ship with it are verifiable with one published key; and the same \
cosign you used to verify Red Hat's work signs your own. Next: turn that \
small SBOM into an actual CVE count."
