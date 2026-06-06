---
title: Hummingbird with Red Hat Trusted Libraries
order: 13
description: Extend the trust chain from base image to application dependencies. Use the Red Hat Trusted Libraries pip index as a drop-in replacement for pypi.org alongside Hummingbird's hardened base images.
duration: 30 minutes
---

Hummingbird gets you trust at the **container image layer**: a
near-zero-CVE base image with a signed SBOM, built reproducibly
in a hardened pipeline. But your Python application doesn't run on
the base image alone — it runs on the image *plus* whatever you
pulled from PyPI. And PyPI is, by design, a public unaudited index.

[Red Hat Trusted Libraries](https://packages.redhat.com/trusted-libraries)
is the natural complement: a pip-compatible package index of
curated Python libraries, **built from source** in Red Hat's
hardened build infrastructure, with **SLSA Level 3 provenance**
and signed attestations. It's a Tech Preview as of early 2026,
Python only, but the most-used libraries (NumPy, Pandas, Flask,
and the rest of that tier) are covered.

This section integrates Trusted Libraries into a Python
Containerfile alongside a Hummingbird base image. The end result:
every byte of your application — base layer, runtime layer,
language packages, and your own code — is built and signed by an
auditable pipeline.

> **The index is gated.** Because Trusted Libraries is a Tech
> Preview, the index at `packages.redhat.com/trusted-libraries`
> requires authentication — you enroll in the preview and
> configure pip/curl with your Red Hat credentials. An
> *unauthenticated* request returns **HTTP 401**. Read that as
> "not enrolled / not authenticated," **not** "package missing."
> The commands below assume you're authenticated; without
> credentials they will 401 rather than fail over to PyPI.

## What "trust at the dependency layer" actually means

A typical `pip install pandas` does the following:

1. Asks PyPI for the latest Pandas version.
2. Downloads a pre-built wheel from PyPI's CDN.
3. Verifies the SHA against a hash recorded by the package
   uploader (not against any independent attestation).
4. Unpacks into `site-packages`.

The wheel was built by whoever uploaded it. PyPI doesn't rebuild
or re-sign anything; it's a passthrough. If the upload pipeline
is compromised — supply-chain attack, stolen API key — the wheel
ships compromised, and PyPI has no way to know.

Trusted Libraries replaces step 2: the wheel comes from Red Hat's
build infrastructure, signed by Red Hat, with a SLSA L3
provenance attestation that records the source repo commit, the
build environment, and the build steps. You can verify any of
those before installing.

## Setting up a project to use Trusted Libraries

The integration point is `pip`. You can switch index URLs per
command, per project, or per user.

### Per-project (recommended)

Create `pip.conf` at the root of your project so it's checked
into source control:

```ini
# pip.conf
[global]
index-url = https://packages.redhat.com/trusted-libraries/simple/
extra-index-url = https://pypi.org/simple/
```

Two index URLs because Trusted Libraries doesn't yet cover all of
PyPI. Pip tries Trusted Libraries first; if a package isn't there
(your obscure data-processing dep, your private fork), it falls
back to pypi.org. Audit your dependency list to see which fall
into which bucket (this requires an authenticated session — see
the gated-index note above; without credentials every line returns
401 and prints `✗`, which means "couldn't check," not "not
covered"):

```bash
# Quick check: how many of your deps are in Trusted Libraries?
# Run this against an authenticated session; a 401 means you're
# not enrolled/authed, not that the package is absent.
while read pkg; do
  url="https://packages.redhat.com/trusted-libraries/simple/${pkg}/"
  code=$(curl -fsS --max-time 5 -o /dev/null -w '%{http_code}' "$url" || true)
  case "$code" in
    200) printf '✓ %s (trusted-libraries)\n' "$pkg" ;;
    401) printf '? %s (auth required — are you enrolled/logged in?)\n' "$pkg" ;;
    *)   printf '✗ %s (pypi.org only)\n' "$pkg" ;;
  esac
done < <(pip freeze | sed 's/==.*//')
```

### Per-command (for testing)

```bash
pip install \
  --index-url https://packages.redhat.com/trusted-libraries/simple/ \
  --extra-index-url https://pypi.org/simple/ \
  pandas==2.2.3
```

## Containerfile integration

Take §4's Python example and switch its pip index. The change is
two lines in the builder stage:

```dockerfile
ARG HB_REGISTRY=quay.io/hummingbird

FROM ${HB_REGISTRY}/python:3.13-builder AS builder
WORKDIR /build
USER 1001

# Trusted Libraries first, PyPI as fallback.
ENV PIP_INDEX_URL=https://packages.redhat.com/trusted-libraries/simple/
ENV PIP_EXTRA_INDEX_URL=https://pypi.org/simple/

COPY --chown=1001:1001 requirements.txt ./
RUN pip wheel --wheel-dir=/build/wheels -r requirements.txt

COPY --chown=1001:1001 src/ ./src/

FROM ${HB_REGISTRY}/python:3.13
WORKDIR /app
COPY --from=builder --chown=1001:1001 /build/wheels /tmp/wheels
COPY --from=builder --chown=1001:1001 /build/src /app/src

USER 1001
RUN pip install --no-index --find-links=/tmp/wheels /tmp/wheels/*.whl
ENV PYTHONPATH=/app/src
EXPOSE 8000
CMD ["python3", "-m", "src.main"]
```

The runtime stage doesn't reach the network — `--no-index
--find-links=/tmp/wheels` installs from the wheels the builder
already fetched. So the trust decision (which index, which
attestations to require) happens once in the builder.

## Verifying provenance for a Trusted Libraries package

Each package on the index ships with an in-toto attestation. Pull
and verify it before you install (these fetches use the same
authenticated index session as above — unauthenticated they 401):

```bash
# Get the package metadata, including the provenance URL.
curl -fsSL https://packages.redhat.com/trusted-libraries/simple/pandas/ \
  | grep -o 'provenance[^"]*'

# Pull the attestation (URL pattern documented in the
# packages.redhat.com docs).
curl -fsSL -o pandas-2.2.3.intoto.jsonl \
  "https://packages.redhat.com/trusted-libraries/attestations/pandas/2.2.3/provenance.intoto.jsonl"

# Verify with cosign — the public key is published by Red Hat.
cosign verify-blob-attestation \
  --certificate-identity-regexp '^https://github.com/redhat-' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  pandas-2.2.3.intoto.jsonl
```

If verify returns clean, the SLSA L3 chain holds: the Pandas
wheel you're about to install was built from a specific commit of
the upstream Pandas repo, in Red Hat's verified pipeline, and
hasn't been tampered with since.

In CI, fold this into the same pre-build step:

```bash
# In your build script, before pip install:
for pkg in $(awk -F'==' '{print $1}' requirements.txt); do
  if ! verify-trusted-libraries-attestation "$pkg"; then
    echo "✗ provenance verification failed for $pkg" >&2
    exit 1
  fi
done
```

(`verify-trusted-libraries-attestation` is a shell function you
write once around the cosign command above.)

## Where this integrates with §12

The custom SBOM you build in §12 already merges the source-side
SBOM with the image-side SBOM. When the source-side wheels come
from Trusted Libraries, they bring SLSA L3 attestations along.
`cyclonedx merge` preserves them. Your final attached SBOM
records:

- Hummingbird base image, signed by Red Hat → image trust
- Trusted Libraries wheels, signed by Red Hat → dependency trust
- Your application, signed by your CI key → first-party trust

Three signatures, one chain.

## Limitations as of early 2026

Things to know going in:

- **Python only.** No Java/Go/Node equivalents yet. The user-facing
  product page acknowledges Python-first; broader language coverage
  is on the roadmap.
- **Not every package is mirrored.** Long-tail packages won't be
  there. The fallback to pypi.org keeps builds working but means
  not every dependency in your tree carries a Red Hat attestation.
- **Tech Preview.** API surface, attestation format, and index URL
  may change before GA. Re-read the docs every couple of months.
- **Subscription gated for production support.** The index itself
  is public; production support and SLAs are part of the Red Hat
  Advanced Developer Suite subscription.

## Calunga — the upstream community version

The upstream/community version of Trusted Libraries is the
**Calunga project**. If you're building images outside the Red
Hat customer ecosystem, Calunga gives you the same architecture
(curated index, SLSA-attested rebuilds) without the subscription.
Hummingbird's documentation references it explicitly as the
upstream that Trusted Libraries productizes.

## Verify before moving on

You should be able to:

- explain what trust the base image gives you and what it
  doesn't,
- configure pip to use the Trusted Libraries index with PyPI as a
  fallback,
- modify a Hummingbird Python Containerfile to fetch wheels from
  Trusted Libraries in the builder stage and install them
  offline in the runtime stage,
- pull and verify a SLSA L3 provenance attestation for a single
  package,
- name the Python-only and Tech-Preview limitations.

## Where to go next

[Installing RPMs into the runtime image]({{ "/docs/14-installing-rpms/" | prepend: site.baseurl }})
takes the same trust-extension idea down a layer: how to add
specific OS-level packages to a Hummingbird runtime that has no
package manager.
