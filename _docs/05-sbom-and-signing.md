---
title: SBOMs and signing
order: 5
description: Generate SBOMs with Syft, sign images with Cosign, and verify the artifacts that ship with stock Hummingbird images.
duration: 30 minutes
---

This section is about the artifacts that travel alongside an image
without being part of its filesystem: software bills of materials
(SBOMs), build provenance attestations, and Sigstore-style
signatures. By the end, you'll have:

- generated an SBOM for one of the images you built in section 4,
- signed that image with a local Cosign key pair,
- attached the SBOM as a Cosign attestation,
- verified your own signature, and
- verified the SBOM that ships with a stock Hummingbird image.

## What's actually attached to an image

Three distinct artifacts can be attached to an OCI image manifest:

1. **The signature.** A short attestation that says "I, the signer,
   vouch for the bytes of this image." Verifying a signature tells
   you the image hasn't been tampered with since the signer signed
   it; it does *not* tell you anything about the contents.
2. **The SBOM attestation.** A signed envelope wrapping a software
   bill of materials (SPDX or CycloneDX). The signature on this
   attestation is what makes the SBOM trustworthy.
3. **The provenance attestation (SLSA).** A signed envelope
   describing how the image was built — what source it came from,
   what build system produced it, when, and with what inputs.

All three are stored in the registry as separate artifacts on the
same manifest, addressable by the image digest.

{% include excalidraw.html
   file="05-sbom-and-signing-artifacts"
   alt="Diagram showing an OCI image manifest with three attached artifacts: signature, SBOM attestation, and provenance attestation"
   caption="Figure 5.1 — The three artifacts attached to a signed image" %}

## Step 1 — Generate a Cosign key pair

Cosign supports both keyless OIDC signing (used in CI, where the
identity comes from a GitHub Actions or GitLab token) and
key-based signing (used in local development). We'll use the
key-based path here because it works without any external
identity provider.

```bash
mkdir -p ~/.config/containers/signing
cd ~/.config/containers/signing

# Cosign will prompt for a passphrase. Use something memorable —
# you'll type it every time you sign during this section.
cosign generate-key-pair
```

You now have:

- `cosign.key` — the encrypted private key (do not commit).
- `cosign.pub` — the public key (safe to share; goes into your
  policy.json, distributed to verifiers, etc.).

## Step 2 — Sign one of your built images

Pick whichever of the section 4 images you have handy. The
Node example is the smallest and fastest to push around:

```bash
# Tag the image into a registry namespace you can push to. Replace
# 'quay.io/your-username' with your own Quay namespace, or use a
# local registry if you prefer not to publish.
TARGET="quay.io/${USER}/hummingbird-node-example:latest"
podman tag hummingbird-node-example:latest "$TARGET"
podman push "$TARGET"

# Sign the published image. The --key flag tells Cosign to use the
# local key pair instead of OIDC.
cosign sign \
  --key ~/.config/containers/signing/cosign.key \
  --yes \
  "$TARGET"
```

The `--yes` flag accepts the consent prompt about uploading the
signature to the public Sigstore transparency log. If you're
working on something that should not appear in the public log, see
the Cosign docs on private TUF roots — that's beyond the scope
of this tutorial.

## Step 3 — Verify your signature

```bash
cosign verify \
  --key ~/.config/containers/signing/cosign.pub \
  "$TARGET" \
  | jq
```

Expected: a JSON object describing the signature, the certificate
(if any), and the transparency-log entry. If `cosign verify`
exits non-zero, the image and signature are out of sync —
re-sign and try again.

## Step 4 — Generate an SBOM with Syft

Syft can produce SBOMs in several formats. SPDX-JSON is the
right default — it's the format Cosign expects when attaching
an SBOM as an SPDX attestation, and it's the format most
downstream tools prefer.

```bash
# Generate the SBOM. The output file is whatever path you want;
# we'll point Cosign at it in the next step.
syft "$TARGET" -o spdx-json="/tmp/sbom-node.spdx.json"

# Look at what's in there. The package count is the headline
# number — for a Hummingbird-based image it should be very small.
echo "SBOM package count:"
jq '.packages | length' /tmp/sbom-node.spdx.json

echo
echo "First few packages:"
jq '.packages[0:5] | .[] | {name, versionInfo, supplier}' \
  /tmp/sbom-node.spdx.json
```

## Step 5 — Attach the SBOM as a Cosign attestation

```bash
cosign attest \
  --key ~/.config/containers/signing/cosign.key \
  --predicate /tmp/sbom-node.spdx.json \
  --type spdxjson \
  --yes \
  "$TARGET"
```

Now there are *two* artifacts attached to the manifest: the
signature you created in step 2 and this SBOM attestation. You
can verify both:

```bash
cosign verify-attestation \
  --key ~/.config/containers/signing/cosign.pub \
  --type spdxjson \
  "$TARGET" \
  | jq '.payload | @base64d | fromjson | .predicate.packages | length'
```

The output should match the package count from step 4 — proof
that the SBOM you generated is the SBOM attached to the image.

## Step 6 — Verify the SBOM that ships with a Hummingbird image

Hummingbird images ship with a Red Hat-signed SBOM by default.
The verification flow is the same as above, but the key/identity
used by the verifier is Red Hat's, not yours. The flow below
uses `cosign verify-attestation` with the Sigstore public-key
flow to extract the SBOM that came pre-attached.

```bash
# Pick any Hummingbird image — Nginx will do.
HUMMINGBIRD_IMG="$HB_REGISTRY/nginx:latest"

# This will list the package names in the SBOM that shipped with
# the image. Output is one package name per line.
cosign verify-attestation \
  --type spdxjson \
  "$HUMMINGBIRD_IMG" \
  | jq -r '.payload | @base64d | fromjson | .predicate.packages[].name' \
  | head -20
```

> **If `cosign verify-attestation` errors with a verification
> failure**, your verifier needs the Red Hat root key or the
> appropriate certificate identity. See the Hummingbird
> documentation for the canonical verification command — it
> changes as the project's signing infrastructure evolves and
> we don't want to encode a stale invocation here.

## Step 7 — A `policy.json` that enforces signatures

Once you've practiced signing and verifying manually, you can
make Podman / Buildah enforce the same checks automatically by
configuring `~/.config/containers/policy.json`. This is the
file Podman consults before pulling or running any image.

A starter policy that requires Sigstore signatures for the
Hummingbird namespace, while leaving everything else permissive:

```bash
cat > ~/.config/containers/policy.json <<EOF
{
  "default": [
    { "type": "insecureAcceptAnything" }
  ],
  "transports": {
    "docker": {
      "${HB_REGISTRY}": [
        {
          "type": "sigstoreSigned",
          "keyPath": "$HOME/.config/containers/signing/cosign.pub",
          "signedIdentity": { "type": "matchRepository" }
        }
      ]
    }
  }
}
EOF
```

The `keyPath` here is your local public key — useful only for
images you yourself signed. To verify Red Hat-signed Hummingbird
images, use the Red Hat public key instead. **Test thoroughly**
before deploying a strict policy: an image that fails the policy
check is unpullable until either the policy is relaxed or the
signature appears.

## Verify before moving on

You should now have:

- a Cosign key pair under `~/.config/containers/signing`,
- a signed image you pushed and signed yourself, and a working
  `cosign verify` invocation against it,
- an SBOM attestation attached to that image, and
- the ability to inspect the SBOM that ships with a stock
  Hummingbird image.

## Where to go next

[CVE scanning]({{ "/docs/06-cve-scanning/" | prepend: site.baseurl }})
takes the same image and scans it with Grype, comparing the
result against a non-Hummingbird base image so the "near zero
CVE" claim has empirical numbers behind it.
