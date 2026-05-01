---
title: Installing RPMs into the runtime image
order: 14
description: Three patterns for adding OS packages to a Hummingbird runtime image that has no dnf — staged install with --installroot, rpm2cpio extraction, and selective file copy.
duration: 25 minutes
---

The Hummingbird design takes the package manager out of the
runtime image. That's the whole point: smaller attack surface, no
runtime upgrades, an image as fixed as your application is. But
sometimes you need an OS-level package the runtime doesn't ship
with — `tzdata` for time-zone handling, `ca-certificates` updates,
a specific shared library your app dlopen()s, a curl binary for
container-internal health checks.

You can't `dnf install` it at runtime. You can't `RUN apt-get` in
the runtime stage. There's no `/usr/bin/dnf` to call.

You can do it from the **builder** stage, where dnf does exist,
and copy the result into the runtime. There are three patterns,
each suited to a different situation.

## Pattern decision matrix

| Situation | Pattern |
|---|---|
| You want one or two specific files from a package | **rpm2cpio extract** |
| You want a whole package and all its dependencies | **--installroot staged install** |
| The package has scriptlets that must run | **--installroot, then COPY rootfs** |
| You're not sure | **--installroot** is the safe default |

## Pattern 1 — Staged install with `dnf --installroot`

`dnf install --installroot=/some/path` installs into a directory
as if that directory were `/`. You can then `COPY` that
directory's contents into your runtime stage. This is the
canonical pattern; it correctly handles dependency resolution and
runs scriptlets in the right order.

```dockerfile
ARG HB_REGISTRY=quay.io/hummingbird

FROM ${HB_REGISTRY}/python:3.13-builder AS builder
USER 0

# Install tzdata + ca-certificates into a staging root.
RUN mkdir -p /staged && \
    dnf install -y \
      --installroot=/staged \
      --releasever=9 \
      --setopt=install_weak_deps=False \
      --nodocs \
      tzdata ca-certificates && \
    dnf clean all --installroot=/staged

# Strip out the parts of the staged root we don't need: package
# manager metadata, locale archives, man pages, log files. This
# is the bulk-cut step.
RUN rm -rf /staged/var/cache/dnf \
           /staged/var/log/* \
           /staged/var/lib/dnf \
           /staged/var/lib/rpm \
           /staged/usr/share/man \
           /staged/usr/share/doc \
           /staged/usr/share/locale

FROM ${HB_REGISTRY}/python:3.13
WORKDIR /app

# Layer the staged content onto the runtime image. Order matters:
# /etc first so config files don't get clobbered by /usr.
COPY --from=builder /staged/etc/  /etc/
COPY --from=builder /staged/usr/  /usr/

USER 1001
COPY --chown=1001:1001 src/ ./src/
CMD ["python", "-m", "src.main"]
```

Three flags worth understanding:

- **`--setopt=install_weak_deps=False`** — skips "recommended"
  packages. Without it, you can pick up a hundred MB of indirect
  deps you didn't ask for.
- **`--nodocs`** — skips `/usr/share/doc` and friends. Saves
  several MB on a typical install.
- **`--releasever=9`** — pins the RPM repo metadata to RHEL/UBI 9.
  Without it, dnf may guess wrong inside the builder.

After the `rm -rf` cleanup, a `tzdata + ca-certificates` install
adds maybe 5–8 MB to the runtime image — which is the irreducible
content of the package, not packaging overhead.

## Pattern 2 — `rpm2cpio` extract

When you need exactly one file from one package — a single
shared library, a single binary — and you don't want
dependency resolution at all, extract the RPM directly without
using dnf:

```dockerfile
ARG HB_REGISTRY=quay.io/hummingbird
ARG RH_REGISTRY=registry.access.redhat.com

FROM ${HB_REGISTRY}/python:3.13-builder AS extractor
USER 0

# Download the RPM but don't install it.
RUN dnf install -y --downloadonly --downloaddir=/rpms \
      curl-minimal && \
    cd /rpms && \
    # Unpack the RPM into a working directory.
    mkdir -p /extracted && cd /extracted && \
    rpm2cpio /rpms/curl-minimal-*.rpm | cpio -idmv

FROM ${HB_REGISTRY}/python:3.13
WORKDIR /app

# Copy only the binary you actually want.
COPY --from=extractor /extracted/usr/bin/curl /usr/bin/curl

# Copy any libraries it dynamically links to. Find these
# beforehand with `ldd` against the extracted binary.
COPY --from=extractor /extracted/usr/lib64/libcurl.so.4* /usr/lib64/

USER 1001
CMD ["python", "-m", "src.main"]
```

Caveats:

- **You're responsible for finding shared-library deps yourself.**
  `dnf install` would have pulled them automatically. With
  `rpm2cpio`, you don't get that. Run `ldd` against the binary
  in the extractor stage and copy each `.so` it lists.
- **Scriptlets don't run.** If the package needs to register a
  user, create a directory, or update a database (most don't, a
  few do), `rpm2cpio` skips that. `--installroot` is safer when
  this matters.
- **Useful for curl-minimal, jq, ca-certificates** and similar
  "just give me the binary" packages.

## Pattern 3 — Download RPMs, install at runtime (avoid)

You'll see this in some legacy material: download `.rpm` files in
the builder, COPY them into the runtime, install them on first
boot. It looks tempting because it defers the install to runtime.
**Avoid it.** The runtime image won't have `rpm` or `dnf`, so
you'd have to ship those too — which defeats the entire reason
you chose Hummingbird.

If you find yourself reaching for this pattern, the underlying
need is usually "I want the package install to happen as part of
some configuration step, not at build time." That's worth
re-examining. Configuration belongs in the application, not the
package manager.

## A worked end-to-end example: TLS certificates and time zones

The canonical real-world case. Most apps need both, and neither
ships with a stock Hummingbird Python image:

```dockerfile
# Containerfile
ARG HB_REGISTRY=quay.io/hummingbird

FROM ${HB_REGISTRY}/python:3.13-builder AS deps
USER 0

# OS-level deps: tzdata for ZoneInfo, ca-certificates for HTTPS.
RUN mkdir -p /staged && \
    dnf install -y \
      --installroot=/staged \
      --releasever=9 \
      --setopt=install_weak_deps=False \
      --nodocs \
      tzdata ca-certificates && \
    rm -rf /staged/var/cache/dnf \
           /staged/var/lib/dnf \
           /staged/var/lib/rpm \
           /staged/usr/share/{man,doc,locale}

# Python deps in a separate builder stage (orthogonal to OS deps).
# Install into a /install prefix so we can COPY across — the runtime
# image has no /bin/sh and cannot RUN pip install itself.
FROM ${HB_REGISTRY}/python:3.13-builder AS pybuild
USER 1001
WORKDIR /build
ENV HOME=/build PIP_NO_CACHE_DIR=1
COPY --chown=1001:1001 requirements.txt ./
RUN pip wheel --wheel-dir=/build/wheels -r requirements.txt && \
    pip install --no-index --find-links=/build/wheels --prefix=/build/install \
        /build/wheels/*.whl

FROM ${HB_REGISTRY}/python:3.13
WORKDIR /app

# OS-level overlay first.
COPY --from=deps /staged/etc/ /etc/
COPY --from=deps /staged/usr/ /usr/

# Then app deps and source — no RUN, only COPY.
COPY --from=pybuild /build/install /usr/local
COPY --chown=1001:1001 src/ /app/src/

USER 1001
ENV PYTHONPATH=/app/src
ENV TZ=UTC
EXPOSE 8000
CMD ["python", "-m", "src.main"]
```

What this image now has that a stock `python:3.13` doesn't:

- `/etc/ssl/certs/ca-bundle.crt` — Python's `ssl` module finds it
  automatically; HTTPS requests to public URLs work.
- `/usr/share/zoneinfo/...` — `zoneinfo.ZoneInfo("Europe/London")`
  works without falling back to UTC.

What it still doesn't have (which is the point):

- `dnf`, `rpm`, `curl`, `bash`, `coreutils`. The runtime image is
  still hardened.

Build, scan, and confirm:

```bash
podman build -t hb-py-app:latest .

# CVE scan should still come back close to clean.
grype hb-py-app:latest

# Verify the new content landed.
podman run --rm --entrypoint sh hb-py-app:latest -c \
  'ls /etc/ssl/certs/ca-bundle.crt /usr/share/zoneinfo/UTC' \
  2>/dev/null || echo "expected: no shell in runtime; use a sidecar to inspect"
```

Last command will fail because the runtime has no `sh` — exactly
the design. Use the §8 sidecar pattern to inspect:

```bash
podman run -d --name hb-app hb-py-app:latest

podman run --rm -it \
  --pid=container:hb-app \
  --network=container:hb-app \
  --volumes-from hb-app \
  registry.access.redhat.com/ubi9/toolbox:latest \
  bash -c 'ls /proc/1/root/etc/ssl/certs/ca-bundle.crt && \
           ls /proc/1/root/usr/share/zoneinfo/UTC'
```

## Verify before moving on

You should be able to:

- explain why `dnf` is removed from Hummingbird runtime images,
- choose between `--installroot` and `rpm2cpio` for a given
  problem,
- write a multi-stage Containerfile that adds `tzdata` and
  `ca-certificates` to a Hummingbird Python runtime,
- list at least three directories that should be cleaned out of
  a `/staged` rootfs before copying it into the runtime.

## Where to go next

[Automated updates with Renovate]({{ "/docs/15-renovate/" | prepend: site.baseurl }})
covers the operational follow-up: once you've built a curated
runtime image, how do you keep its base layer current as
Hummingbird publishes new tags?
