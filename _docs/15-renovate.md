---
title: Automated updates with Renovate
order: 15
description: Configure Renovate to watch Hummingbird base image tags on quay.io and open PRs when new versions land. Covers regex managers for FROM lines, tag pinning strategies, and digest pinning.
duration: 20 minutes
---

The whole point of Hummingbird is a base image that ships free of
known CVEs. The only way to *stay* free of known CVEs as new ones
are disclosed is to consume new builds — promptly, reliably, and
without pulling 47 unrelated changes along with the bump.

[Renovate](https://docs.renovatebot.com) is the right tool for
this. It watches your Containerfiles for `FROM` lines, checks the
upstream registry on a schedule, and opens a PR when a newer tag
is available. Combined with your CI's existing test suite, this
gives you continuous, low-risk base-image updates.

This section configures Renovate against `quay.io/hummingbird`
and walks through three tag-pinning strategies — choose the one
that matches how often you want to ship.

## Why this matters more for Hummingbird than for stock images

A stock `python:3.11` image on a typical public registry gets new
builds when the maintainers feel like it — sometimes weekly,
sometimes quarterly. Hummingbird rebuilds on every upstream RHEL CVE
patch. That cadence makes the difference between zero CVEs and zero
CVEs *for now* — and also means the base image you used last
week may already have a successor.

## Setting up Renovate

If your repo is on GitHub, the easiest path is the
[hosted Renovate GitHub App](https://github.com/marketplace/renovate).
Install it on your repo; it'll auto-create a config PR on first run.

For self-hosted, the same `renovate.json` works against the CLI:

```bash
npx --yes renovate \
  --token "$GITHUB_TOKEN" \
  --platform=github \
  patterncatalyst/hummingbird-tutorial
```

## Regex manager for FROM lines

Renovate's built-in `dockerfile` manager handles `FROM
quay.io/hummingbird/python:3.13.5` directly. But the tutorial's
Containerfiles use build args:

```dockerfile
ARG HB_REGISTRY=quay.io/hummingbird
FROM ${HB_REGISTRY}/python:3.13-builder AS builder
```

Renovate's plain dockerfile manager doesn't dereference `${...}`
expansions. Use a `customManagers` regex rule that matches the
form you actually write:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": ["(^|/)Containerfile$", "(^|/)Dockerfile$"],
      "matchStrings": [
        "FROM\\s+\\$\\{HB_REGISTRY[^}]*\\}/(?<depName>[^:\\s]+):(?<currentValue>[^\\s]+)"
      ],
      "datasourceTemplate": "docker",
      "registryUrlTemplate": "https://quay.io",
      "packageNameTemplate": "quay.io/hummingbird/{{depName}}"
    },
    {
      "customType": "regex",
      "fileMatch": ["(^|/)Containerfile$", "(^|/)Dockerfile$"],
      "matchStrings": [
        "ARG\\s+HB_REGISTRY=quay\\.io/hummingbird\\s*\\n.*FROM\\s+\\$\\{HB_REGISTRY\\}/(?<depName>[^:\\s]+):(?<currentValue>[^\\s]+)"
      ],
      "datasourceTemplate": "docker",
      "packageNameTemplate": "quay.io/hummingbird/{{depName}}"
    }
  ]
}
```

The regex says: when you see `FROM ${HB_REGISTRY}/<name>:<tag>`,
treat `<name>` as a Docker package and `<tag>` as the current
version. Renovate then queries quay.io for newer tags of
`quay.io/hummingbird/<name>` and opens a PR when one is found.

## Tag pinning strategies

Pick one of three. They trade off update cadence against
stability.

### Strategy A — Floating major tag, frequent rebuilds

Use a major-version tag like `:1` or `:latest-1.x`. Renovate
flags new minor/patch releases. CI rebuilds on every PR merge.
Fast, low-risk for patch-level CVE catches; risky if the
upstream introduces a breaking change in a minor release.

```dockerfile
FROM ${HB_REGISTRY}/python:3.13-builder
```

```json
{
  "packageRules": [
    {
      "matchPackagePatterns": ["^quay\\.io/hummingbird/"],
      "matchUpdateTypes": ["minor", "patch"],
      "automerge": true
    }
  ]
}
```

`automerge: true` means CI alone gates the bump; if your tests
pass, it lands. Combined with a strong test suite, this is the
fastest CVE response.

### Strategy B — Pinned exact tag, manual review

Use a fully-qualified tag like `:1.2.3-20260201`. Renovate
flags every change. Each PR requires human review. Slow but
explicit; appropriate for tightly regulated environments.

```dockerfile
FROM ${HB_REGISTRY}/python:3.13.5-builder-20260201
```

No `automerge` rule — the PR sits until a human approves.

### Strategy C — Digest pinning, audit-grade

Pin by SHA-256 digest. The most precise; impossible to
silently substitute. Renovate keeps the digest current as new
images are pushed.

```dockerfile
FROM ${HB_REGISTRY}/python@sha256:abcdef0123...
```

```json
{
  "packageRules": [
    {
      "matchPackagePatterns": ["^quay\\.io/hummingbird/"],
      "pinDigests": true
    }
  ]
}
```

This is the strongest binding. Combine it with cosign signature
verification at deploy time and you have a fully-traceable
chain.

## Combining strategies across stages

You can pin the builder differently from the runtime. A common
choice: digest-pinned runtime (audit), floating-major builder
(speed):

```dockerfile
ARG HB_REGISTRY=quay.io/hummingbird

# Builder: floating major. We don't ship the builder, so it just
# needs to compile.
FROM ${HB_REGISTRY}/python:3.13-builder AS builder
# ...

# Runtime: digest-pinned. This is the layer that goes to prod.
FROM ${HB_REGISTRY}/python@sha256:abcdef... AS runtime
# ...
```

## Tagging your own images

Renovate solves the inbound side. The outbound side — what tag
you push for your *application* — is just as important. A few
conventions worth adopting:

- **Calendar versioning for apps that don't have semantic
  releases:** `2026.05.01-1` (date plus daily sequence).
- **Always also push a digest:** `myapp:2026.05.01-1` and
  `myapp@sha256:...`. Downstream consumers can pin either.
- **Multi-tag the same digest:** push `:latest`, `:1`, `:1.2`,
  and `:1.2.3` for the same image. Lets consumers pick a
  pinning strategy that matches their risk tolerance.

```bash
# Push a multi-tagged image cleanly.
DIGEST=$(podman push --quiet --digestfile /dev/stdout \
           ghcr.io/me/myapp:1.2.3)

# Tag-only operations after the initial push:
skopeo copy "docker://ghcr.io/me/myapp@$DIGEST" \
            "docker://ghcr.io/me/myapp:1.2"
skopeo copy "docker://ghcr.io/me/myapp@$DIGEST" \
            "docker://ghcr.io/me/myapp:1"
skopeo copy "docker://ghcr.io/me/myapp@$DIGEST" \
            "docker://ghcr.io/me/myapp:latest"
```

`skopeo copy` between tags on the same registry is metadata-only;
it doesn't move bytes.

## Making Renovate test before merging

The whole flow only works if your CI actually exercises the new
base image. Add a workflow that runs on every Renovate PR:

```yaml
# .github/workflows/renovate-base-update.yml
name: Test base image bump
on:
  pull_request:
    paths:
      - 'Containerfile'
      - 'Dockerfile'

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build with new base
        run: podman build -t test-image .
      - name: Run smoke test
        run: |
          podman run -d --name app test-image
          sleep 5
          # Whatever your minimal smoke test is.
          curl -fsSL http://localhost:8080/healthz
      - name: CVE scan
        run: grype test-image --fail-on high
```

If `grype --fail-on high` finds a high CVE, the PR fails — even
if the build succeeds. That's the safety net that catches a bad
upstream release. The PR sits open until a clean newer tag
appears (which it usually does within hours).

## A complete `renovate.json` for this tutorial's repo

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    ":timezone(America/New_York)",
    ":maintainLockFilesWeekly"
  ],
  "schedule": ["after 8pm every weekday", "every weekend"],
  "labels": ["dependencies", "renovate"],
  "customManagers": [
    {
      "customType": "regex",
      "fileMatch": ["(^|/)Containerfile$", "(^|/)Dockerfile$"],
      "matchStrings": [
        "FROM\\s+\\$\\{HB_REGISTRY[^}]*\\}/(?<depName>[^:\\s]+):(?<currentValue>[^\\s]+)"
      ],
      "datasourceTemplate": "docker",
      "packageNameTemplate": "quay.io/hummingbird/{{depName}}"
    }
  ],
  "packageRules": [
    {
      "matchPackagePatterns": ["^quay\\.io/hummingbird/"],
      "groupName": "Hummingbird base images",
      "matchUpdateTypes": ["minor", "patch", "digest"],
      "automerge": true,
      "automergeType": "pr",
      "platformAutomerge": true
    },
    {
      "matchPackagePatterns": ["^quay\\.io/hummingbird/"],
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["dependencies", "renovate", "major-bump"]
    }
  ]
}
```

What this does: groups all Hummingbird base-image bumps into one
PR per cycle, auto-merges minor/patch/digest changes (CI gated),
and holds major version bumps for human review. Runs after 8pm
weekdays so PRs land overnight without churning the main branch
during work hours.

## Verify before moving on

You should be able to:

- explain why automated base-image updates matter more for
  Hummingbird than for typical base images,
- write a Renovate `customManagers` regex that matches the
  tutorial's `${HB_REGISTRY}` Containerfile pattern,
- choose between floating-tag, exact-tag, and digest-pinning
  strategies based on a stated risk profile,
- combine Renovate auto-merge with a CI-gated grype scan so bad
  bumps don't reach main.

## Where to go next

[Pruning Podman images and build cache]({{ "/docs/16-pruning/" | prepend: site.baseurl }})
covers the local-laptop side of staying current: as Renovate
updates your bases and CI pulls new tags, your `podman images`
output grows without bound. That section closes the loop.
