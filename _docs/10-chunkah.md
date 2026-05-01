---
title: Splitting layers with chunkah
order: 10
description: A deeper layer-management tool that complements zstd:chunked. Walk through splitting a base image, isolating application code via xattrs, and combining chunkah with zstd:chunked.
duration: 30 minutes
---

`chunkah` is a tool for splitting container image layers along
file-system boundaries you choose, rather than along the
boundaries the build process happens to produce. Where
`zstd:chunked` is about *how* layers are compressed,
`chunkah` is about *what goes into which layer*.

The two work well together: `chunkah` decides how content is
partitioned across layers, and `zstd:chunked` makes the
resulting layers efficient to pull incrementally.

## Why split layers manually

When you build a Hummingbird-based image, the layers come out
of the build process in a fixed order — base image, your `COPY`
instructions, and so on. If your application code is in the same
layer as your application's third-party dependencies, every
application change invalidates the dependency layer, even though
the dependencies didn't change.

`chunkah` lets you re-partition the image's content so that:

- Stable parts (OS libraries, language runtime) live in their
  own layer.
- Slow-changing parts (third-party deps) live in another layer.
- Fast-changing parts (your application code) live in a small
  top layer.

Combined with `zstd:chunked` push, this means an application
update only re-uploads (and clients only re-download) the small
top layer — not the dependency layer below it.

{% include excalidraw.html
   file="10-chunkah-layer-split"
   alt="Diagram showing an image with one combined layer being split by chunkah into three layers: base/runtime, dependencies, and application code"
   caption="Figure 10.1 — chunkah re-partitioning a Hummingbird-based image into three independently cacheable layers" %}

## Setup — what you need

`chunkah` is distributed as a small CLI. As of this writing it
is not in the Fedora default repos and not in Homebrew, so it's
installed from a release artifact:

```bash
# This URL pattern matches the project's release artifacts. Check
# the upstream project for the latest tag.
CHUNKAH_VERSION=$(curl -sSL https://api.github.com/repos/containers/chunkah/releases/latest 2>/dev/null \
  | jq -r '.tag_name // empty')
echo "chunkah version: ${CHUNKAH_VERSION:-not-detected}"
```

> **Reconciliation note.** `chunkah` is referenced in the source
> material but its exact upstream location, current release tag,
> and CLI flags need confirmation against the canonical project
> URL before this section can be declared accurate. The patterns
> below are correct in spirit; the precise commands will need
> validation.

## Example 1 — Split a Hummingbird base image and inspect

The simplest possible invocation: take a Hummingbird image and
re-emit it with the layers split along defined boundaries.

```bash
# Pull the source image.
podman pull "$HB_REGISTRY/nginx:1"

# Hypothetical chunkah invocation that splits the image along
# defined paths — substitute the actual tool flags after
# verification.
chunkah split \
  --source "$HB_REGISTRY/nginx:1" \
  --output containers-storage:hummingbird-nginx-split:latest \
  --boundary /usr/lib \
  --boundary /etc \
  --boundary /var

# Inspect the resulting layer count.
skopeo inspect --raw containers-storage:hummingbird-nginx-split:latest \
  | jq '.layers | length'
```

The boundary flags tell `chunkah` "any time the file tree crosses
this directory, start a new layer." The result is an image
that's logically equivalent to the original but partitioned into
more granular layers.

## Example 2 — App code on top, dependencies underneath

The most operationally useful pattern: keep your application
code in its own layer, separate from your dependencies.

```bash
# Build your image normally.
cd ~/hummingbird-tutorial/examples/node-example
podman build -t myapp:base .

# Re-emit with chunkah, putting /app/node_modules in one layer
# and /app (excluding node_modules) in another.
chunkah split \
  --source containers-storage:myapp:base \
  --output containers-storage:myapp:split \
  --layer name=deps,path=/app/node_modules \
  --layer name=app,path=/app,exclude=/app/node_modules
```

The point of this is what happens on the next build: when only
`server.js` changes, only the `app` layer changes. The `deps`
layer's digest stays identical. A registry pull on a node that
already has a previous version of the image only needs the
`app` layer.

## Example 3 — xattr-based isolation

A more advanced pattern: tag files with extended attributes
during the build, and have `chunkah` use those tags as the
split boundary. This is useful when your build produces a tree
where the right boundary isn't a directory but a logical
classification (e.g., "everything I authored" vs. "everything
the build pulled in").

```bash
# Hypothetical: set xattrs during the build, then split by xattr
# value. The exact flag syntax depends on the chunkah CLI.
chunkah split \
  --source containers-storage:myapp:base \
  --output containers-storage:myapp:xattr-split \
  --xattr-key user.layer
```

A `RUN setfattr -n user.layer -v app /app/server.js` during the
build would tag that file as belonging to the `app` layer.

## Example 4 — chunkah + zstd:chunked together

The combined effect is the maximum win on registry traffic.
`chunkah` decides what goes into each layer; `zstd:chunked`
makes each layer efficient to pull.

```bash
# Build the image with chunkah-driven splits, then push with
# zstd:chunked compression.
chunkah split \
  --source containers-storage:myapp:base \
  --output containers-storage:myapp:final \
  --layer name=deps,path=/app/node_modules \
  --layer name=app,path=/app,exclude=/app/node_modules

podman push \
  --compression-format zstd:chunked \
  containers-storage:myapp:final \
  "quay.io/${USER}/myapp:final"
```

An application update on this image now re-pushes:

- The small `app` layer, in `zstd:chunked` format.
- A fresh manifest pointing at the new `app` layer plus the
  unchanged `deps` and base layers.

A pulling node only fetches the new `app` layer — typically a
few hundred KB — instead of the entire image.

## When this matters and when it doesn't

`chunkah` is operationally useful when:

- The image is pulled by a large fleet (cluster, edge, or
  many CI runners).
- The image is rebuilt frequently with small changes.
- Bandwidth is non-trivial.

It's not worth the additional build complexity when:

- The image is pulled rarely.
- You're shipping a single static binary (already minimally
  layered).
- The build is deterministic enough that the natural layer
  boundaries are already optimal.

## Verify before moving on

You should be able to:

- explain the difference between `zstd:chunked` and `chunkah`,
- name at least two scenarios where the combined effect is
  most useful, and
- describe how an application code change propagates differently
  through a `chunkah`-split image vs. a single-layer image.

## Where to go next

[Real-world examples]({{ "/docs/11-real-world-examples/" | prepend: site.baseurl }})
walks through five end-to-end scenarios that pull together
everything from the previous ten sections.

> **Reconciliation note.** This section is the most speculative
> in the tutorial — the broad architectural idea behind `chunkah`
> is well-documented, but the exact CLI surface used here needs
> verification. See the
> [reconciliation plan]({{ "/plans/reconciliation-plan/" | prepend: site.baseurl }}).
