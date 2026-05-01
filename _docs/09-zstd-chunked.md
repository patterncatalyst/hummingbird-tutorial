---
title: Layer optimisation with zstd:chunked
order: 9
description: Build images that pull faster on subsequent updates by using the zstd:chunked compression format.
duration: 25 minutes
---

This section covers `zstd:chunked` — a compression format for
container image layers that lets clients pull only the *changed*
parts of a layer when an image is updated, rather than re-pulling
the entire layer. It pairs particularly well with Hummingbird
images, where the small dependency graph means a typical update
changes only a few packages.

The win is most visible when:

- You're updating an image with a small change (e.g. one
  patched library, or a new application binary).
- The same image is pulled by many nodes (a cluster, a fleet of
  edge devices).
- Bandwidth or registry egress costs are non-trivial.

## How it works at a glance

{% include excalidraw.html
   file="09-zstd-chunked-layer-format"
   alt="Diagram comparing a gzip-compressed layer (must be re-pulled in full when changed) with a zstd:chunked layer (only changed chunks need to be re-pulled)"
   caption="Figure 9.1 — Why zstd:chunked enables partial layer pulls" %}

In the standard gzip layer format, a layer is a single
gzip-compressed tar archive. If a single byte changes, the
entire compressed blob changes — the client has to re-pull the
whole layer.

In `zstd:chunked`, the layer is divided into chunks aligned to
file boundaries inside the tar archive. Each chunk has its own
checksum, recorded in a manifest at the end of the layer. When
an update changes one chunk, the rest are byte-identical to the
previous version — and the client can fetch only the changed
chunks from the registry.

## Step 1 — Confirm your Podman version supports zstd:chunked

`zstd:chunked` is supported by Podman 4.5 and newer. Section 1's
prerequisites already cover Podman 5.x, so this should be a
non-issue, but confirm:

```bash
podman --version
# Expected: podman version 5.x.x or later
```

## Step 2 — Enable zstd:chunked at build time

There are two places `zstd:chunked` shows up: when *building*
an image, and when *pushing* it to a registry. We'll cover both.

```bash
# Build a Hummingbird-based image with zstd:chunked compression on
# the layers Podman creates.
cd ~/hummingbird-tutorial/examples/node-example

podman build \
  --layers \
  --compression-format zstd:chunked \
  --compression-level 3 \
  -t hb-node-zstd:latest \
  .
```

The flags:

- `--layers` — keep intermediate build stages cached as
  separate layers, which is what you want here. Without it,
  Podman may collapse stages.
- `--compression-format zstd:chunked` — the headline flag.
- `--compression-level 3` — a reasonable default. Higher
  values (up to 22) give smaller layers at the cost of build
  time; lower values are faster.

Verify the layer compression on the resulting image:

```bash
skopeo inspect --raw containers-storage:hb-node-zstd:latest \
  | jq '.layers[] | {mediaType, size, digest}'
```

The `mediaType` field should include
`application/vnd.oci.image.layer.v1.tar+zstd` — that's the
indicator that the layer is `zstd`-compressed (chunked or not).

## Step 3 — Push with zstd:chunked

```bash
TARGET="quay.io/${USER}/hb-node-zstd:latest"
podman tag hb-node-zstd:latest "$TARGET"

podman push \
  --compression-format zstd:chunked \
  --compression-level 3 \
  "$TARGET"
```

If the registry doesn't support OCI artifacts with
`tar+zstd` media types yet, you'll get an error. Quay supports
it; some self-hosted registries may not. Falling back to gzip
is just a matter of dropping the flag — the image still pushes.

## Step 4 — Dual-format push for compatibility

In a heterogeneous environment where some nodes have a Podman
that supports `zstd:chunked` and some don't, push the image in
both formats so each node pulls what it can decode:

```bash
# Push the same image in both formats, side by side. Two pushes,
# two manifests; clients negotiate which one to pull.
podman push \
  --compression-format zstd:chunked \
  "$TARGET"

podman push \
  --compression-format gzip \
  "${TARGET%:*}:latest-gzip"
```

A more sophisticated approach uses an OCI image index that
references both formats under the same tag, so clients
auto-select. That's covered in the Podman documentation for
`podman manifest` and is beyond the scope of this tutorial.

## Step 5 — Verify partial-pull savings

To see the benefit, build a second version of the image with a
small change and watch what happens on a fresh node when it
pulls the update.

```bash
# Make a tiny change to the source.
cd ~/hummingbird-tutorial/examples/node-example
sed -i.bak "s/runtime: 'hummingbird-nodejs'/runtime: 'hummingbird-nodejs-v2'/" server.js

# Rebuild and push.
podman build \
  --layers \
  --compression-format zstd:chunked \
  -t hb-node-zstd:v2 \
  .

podman tag hb-node-zstd:v2 "quay.io/${USER}/hb-node-zstd:v2"
podman push --compression-format zstd:chunked "quay.io/${USER}/hb-node-zstd:v2"

# Restore the original.
mv server.js.bak server.js
```

On a different node (or after `podman rmi -a` clears local
storage), pull both versions and watch the byte counts:

```bash
podman pull --quiet "quay.io/${USER}/hb-node-zstd:latest"
echo "First pull complete."

# The second pull should transfer dramatically fewer bytes,
# because only the changed chunk needs to come down.
time podman pull "quay.io/${USER}/hb-node-zstd:v2"
```

The clearest "is this working?" signal is the time difference
between a cold first pull and a warm second pull on a related
image. The byte counts are visible in `podman pull`'s verbose
output if you run with `--log-level=debug`.

## Where this fits with Hummingbird specifically

`zstd:chunked` is most valuable for images that are updated
frequently with small changes. Hummingbird's "rebuild on
upstream fix" cadence produces exactly that pattern — a typical
update changes one or two packages out of a small total. The
chunked format means a fleet of nodes can pull those updates
incrementally rather than re-pulling the whole image.

## Verify before moving on

You should be able to:

- build an image with `--compression-format zstd:chunked`,
- recognize the `tar+zstd` media type on the resulting layers,
- push the image to a registry that accepts the format, and
- explain why `zstd:chunked` and Hummingbird's rebuild cadence
  reinforce each other.

## Where to go next

[Splitting layers with chunkah]({{ "/docs/10-chunkah/" | prepend: site.baseurl }})
is the natural follow-on — `chunkah` is a tool for *deciding*
how to split image content into layers in the first place, which
multiplies the benefit `zstd:chunked` provides.

> **Reconciliation note.** This section needs verification
> against current Hummingbird image availability and current
> Podman default behaviour. The mechanics described here are
> stable, but the exact flags and media-type strings should be
> confirmed against a live build before this tutorial is
> declared complete. See the
> [reconciliation plan]({{ "/plans/reconciliation-plan/" | prepend: site.baseurl }})
> for the working list.
