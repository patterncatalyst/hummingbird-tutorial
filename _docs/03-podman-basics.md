---
title: Podman basics with Hummingbird
order: 3
description: Pull, inspect, and run your first Hummingbird image; learn the ephemeral debug-sidecar pattern.
duration: 25 minutes
---

This is the section where the design ideas from the introduction
become tangible. By the end, you'll have:

- pulled a Hummingbird image and inspected its manifest,
- watched `podman exec ... /bin/sh` fail by design,
- attached a debug sidecar that shares the running container's
  PID and network namespaces, and
- compared the layer count and size against a UBI image so the
  "minimal runtime" claim has numbers behind it.

If you have not finished the prerequisites, do that first — every
command below assumes the environment variables `HB_REGISTRY` and
`RH_REGISTRY` are set.

## Diagram: what `podman pull` does for a Hummingbird image

{% include excalidraw.html
   file="03-podman-basics-pull-flow"
   alt="Sequence diagram of podman pull resolving image layers from quay.io and storing them in local containers-storage"
   caption="Figure 3.1 — How podman pull resolves a Hummingbird image into local storage" %}

## Step 1 — Pull a Hummingbird image

We'll start with Nginx because it is the easiest Hummingbird image
to demonstrate the "minimal runtime" idea against — Nginx is a
widely understood reference point and the difference vs. a stock
Nginx image shows up immediately.

```bash
# Use the registry shortcut from the prerequisites.
podman pull "$HB_REGISTRY/nginx:1"
```

While that is running, take a look at what is happening:

- Each layer is downloaded from `quay.io` and stored locally in
  `~/.local/share/containers/storage` (Fedora) or inside the
  Podman machine (macOS).
- The manifest file is written to local storage and indexed by
  digest.
- The image is tagged in your local image list.

After the pull finishes:

```bash
# Confirm the image is present and note the size.
podman images "$HB_REGISTRY/nginx"
```

Make a mental note of the size column. You'll compare it against a
non-minimal image in step 5.

## Step 2 — Inspect the manifest

Skopeo can inspect an image without pulling, but since we just
pulled, let's use both forms so the syntax is familiar.

```bash
# Inspect the manifest of the local copy.
podman inspect "$HB_REGISTRY/nginx:1" \
  | jq '{
      digest: .[0].Digest,
      created: .[0].Created,
      architecture: .[0].Architecture,
      os: .[0].Os,
      labels: .[0].Labels,
      layers: (.[0].RootFS.Layers | length)
    }'
```

The same data via Skopeo, without ever needing the image local:

```bash
skopeo inspect "docker://$HB_REGISTRY/nginx:1" \
  | jq '{
      digest: .Digest,
      created: .Created,
      os: .Os,
      arch: .Architecture,
      layers: (.Layers | length),
      labels: .Labels
    }'
```

Two things to look at in the output:

1. **The layer count.** A Hummingbird Nginx image typically has a
   handful of layers. A standard Nginx image has many more.
2. **The labels.** The `org.opencontainers.image.source` label
   should point back to the Hummingbird build pipeline, and
   `org.opencontainers.image.vendor` will identify Red Hat.

## Step 3 — Run it

```bash
# Run the image in the background and bind it to a host port.
# Hummingbird Nginx listens on 8080 in the container by default
# because non-privileged binds are required for non-root containers.
podman run -d \
  --name hummingbird-nginx \
  -p 8080:8080 \
  "$HB_REGISTRY/nginx:1"

# Confirm it is running.
podman ps --filter name=hummingbird-nginx

# Hit it with curl from your host.
curl -sI http://localhost:8080
```

You should see an HTTP 200 (or 403 — Hummingbird's default
configuration may not include a default `index.html`). Either is
fine; we just need to know it's serving.

## Step 4 — Watch the no-shell behaviour

This is the moment that surprises people coming from general-purpose
base images. Try to exec a shell:

```bash
# This will fail.
podman exec -it hummingbird-nginx /bin/sh
```

Expected output is something like:

```
Error: OCI runtime attempted to invoke a command that was not found
```

or

```
exec: "/bin/sh": stat /bin/sh: no such file or directory
```

There is no shell to exec into. The image does not contain `sh`,
`bash`, or any of the usual diagnostic tools. This is by design —
the entire premise of the minimal runtime is that the post-build
filesystem contains only the application runtime and its direct
dependencies.

> **If you are coming from a Docker-driven workflow and your
> muscle memory is "exec into the container to look around":**
> that habit will not work here. The next step shows the pattern
> that replaces it.

## Step 5 — The ephemeral debug-sidecar pattern

When you need to look at what's happening inside a Hummingbird
container — file system, processes, network state — you do it by
running a *separate* container that shares the relevant
namespaces. The Hummingbird container itself stays unchanged.

{% include excalidraw.html
   file="03-podman-basics-debug-sidecar"
   alt="Diagram showing a debug sidecar container sharing the PID and network namespace of a Hummingbird container"
   caption="Figure 3.2 — The debug-sidecar pattern: a second container shares the namespaces of the first" %}

```bash
# Attach a UBI toolbox container that shares the Hummingbird
# container's PID, network, and mount namespaces. The toolbox
# image has bash, ps, ss, curl, and the usual diagnostic tools.
podman run -it --rm \
  --pid=container:hummingbird-nginx \
  --network=container:hummingbird-nginx \
  "$RH_REGISTRY/ubi9/toolbox:latest" \
  bash
```

You're now in a shell inside the UBI toolbox container, but
`ps`, `ss`, and friends see the *Hummingbird* container's
processes and network state. Try a few commands:

```bash
# Inside the toolbox container:

# See the nginx worker processes from the other container.
ps -ef | grep nginx

# Check what's listening on port 8080 — you'll see nginx itself.
ss -tlnp

# Hit nginx via localhost — works because we share its network namespace.
curl -sI http://localhost:8080

# Exit when done.
exit
```

The key insight: the Hummingbird container's namespaces are
visible from the toolbox, but the Hummingbird container's own
filesystem is *not* mounted into the toolbox unless you explicitly
add `--volumes-from hummingbird-nginx`. That separation is what
makes this pattern safe to use without contaminating the
production runtime.

## Step 6 — Compare against a non-minimal image

To anchor the "minimal" claim with numbers, pull a stock Nginx
from a non-Hummingbird source and compare side by side.

```bash
# Pull a comparison image. Any general-purpose Nginx will do.
podman pull docker.io/library/nginx:latest

# Compare sizes.
podman images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.Created}}" \
  | grep -E "nginx"

# Compare layer counts.
echo "Hummingbird nginx layers:"
skopeo inspect "docker://$HB_REGISTRY/nginx:1" \
  | jq '.Layers | length'

echo "Stock nginx layers:"
skopeo inspect "docker://docker.io/library/nginx:latest" \
  | jq '.Layers | length'
```

The exact numbers will drift over time, but the ratio is the
durable result: the Hummingbird image is several times smaller and
carries a fraction of the layers.

## Step 7 — Clean up

```bash
# Stop and remove the running Hummingbird container.
podman stop hummingbird-nginx
podman rm hummingbird-nginx

# (Optional) remove the comparison nginx image to free space.
podman rmi docker.io/library/nginx:latest
```

Leave the Hummingbird Nginx image in place — section 4 will use
it again as the runtime stage of a multi-stage build.

## Verify before moving on

Before you move on to multi-stage builds, confirm:

- `podman images "$HB_REGISTRY/nginx"` lists the Hummingbird
  Nginx image.
- The exec-into-no-shell error in step 4 felt expected, not
  surprising.
- The debug-sidecar in step 5 successfully showed you the Nginx
  process from inside the toolbox container.

If any of those are not yet true, scroll back up — the next
section assumes all three.

## Where to go next

[Multi-stage builds]({{ "/docs/04-multi-stage-builds/" | prepend: site.baseurl }})
is where Hummingbird stops being a thing you pull and starts being
a thing you build on top of.
