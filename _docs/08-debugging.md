---
title: Debugging Hummingbird containers
order: 8
description: A four-layer debugging strategy for images that have no shell, no curl, and no diagnostic tools.
duration: 25 minutes
---

This section is the "no shell" promise turned into a habit. The
moment you build something on Hummingbird and it doesn't behave
the way you expect, you'll need a debugging workflow that doesn't
rely on `podman exec ... /bin/bash`. We'll work through four
layers of that workflow, from cheapest to most invasive.

The four layers, from least intrusive to most:

1. **Local Podman commands.** `inspect`, `logs`, `top`, `port`,
   `events` — everything you can do without putting any code into
   the container.
2. **Log-first diagnostics.** Make the application emit enough
   structured information that you rarely need to reach for a
   shell.
3. **Ephemeral debug containers.** The sidecar pattern from
   section 3, scaled up to the whole toolkit a Linux engineer
   normally has — including a stronger variant with
   `SYS_PTRACE` for `strace`/`gdb`/`perf` work.
4. **Kubernetes ephemeral debug containers.** When the deployment
   target is a cluster, `kubectl debug` does the same thing the
   sidecar pattern does, but with the cluster as the orchestrator.

Plus a complementary fifth technique: **in-image debug with a
builder image** — for when you're developing the app and want a
shell with `dnf`, debug-symbol packages, and your code mounted
in. This pattern works alongside the four layers, not instead of
them.

{% include excalidraw.html
   file="08-debugging-layers"
   alt="Diagram showing the four debugging layers from cheap (logs) to invasive (ephemeral debug container) with appropriate use cases"
   caption="Figure 8.1 — The four debugging layers and when each one earns its keep" %}

## Layer 1 — Local Podman commands

Before reaching for any new tooling, exhaust what `podman` itself
will tell you.

```bash
# Pick a running container to debug. Replace with a real container
# you have running.
CTR=hb-node

# Container metadata: image, mounts, environment, network.
podman inspect "$CTR" | jq '.[0] | {
  state: .State.Status,
  pid: .State.Pid,
  startedAt: .State.StartedAt,
  exitCode: .State.ExitCode,
  ports: .NetworkSettings.Ports,
  networks: .NetworkSettings.Networks,
  envCount: (.Config.Env | length)
}'

# Recent logs (last 100 lines, follow=false).
podman logs --tail 100 "$CTR"

# Live processes inside the container, from the host's view.
podman top "$CTR"

# Resource usage (one-shot snapshot).
podman stats --no-stream "$CTR"

# Per-container event history. Useful when "what happened?" is
# the actual question.
podman events --filter container="$CTR" --since 30m --until now
```

If those five commands tell you what's wrong, you don't need
layer 2. Quite often they do.

## Layer 2 — Log-first diagnostics

The Hummingbird design pushes you toward applications that emit
useful structured logs by default, because the alternative
("ssh in and look at the file") doesn't exist. A few practices
that pay off:

- **Log to stdout/stderr only.** Container runtimes are good at
  capturing those. Files inside the container are inaccessible
  unless you've mounted a volume.
- **Log structured (JSON).** Makes `podman logs ... | jq ...` a
  one-liner instead of a regex hunt.
- **Include trace IDs.** If you're using OpenTelemetry, the
  trace ID is the join key between logs, metrics, and traces.
- **Make readiness explicit.** A line like
  `app=web event=ready port=3000` is worth its weight in
  guesswork.

A small Node example with structured logging:

```javascript
// Replace plain console.log with this in any of the section 4
// examples to see structured logs in action.
function log(level, msg, fields = {}) {
  console.log(JSON.stringify({
    ts: new Date().toISOString(),
    level,
    msg,
    ...fields
  }));
}

log('info', 'starting', { port, runtime: process.version });
```

Then on the host:

```bash
podman logs hb-node | jq -r 'select(.level == "error")'
```

## Layer 3 — Ephemeral debug containers

When logs aren't enough — the container is up but not responding,
or there's network weirdness, or you need to look at file system
state — attach a sidecar that shares the right namespaces.

The shell function below codifies the pattern. Add it to your
`~/.bashrc` or `~/.zshrc`:

```bash
# Ephemeral debug sidecar. Usage: hb-debug <container-name>
hb-debug() {
  if [[ -z "$1" ]]; then
    echo "Usage: hb-debug <container-name>" >&2
    return 1
  fi
  podman run -it --rm \
    --pid="container:$1" \
    --network="container:$1" \
    --volumes-from "$1" \
    "${RH_REGISTRY:-registry.access.redhat.com}/ubi9/toolbox:latest" \
    bash
}
```

What each flag does:

- `--pid=container:$1` — see the target container's processes.
- `--network=container:$1` — see its network state and reach its
  ports via `localhost`.
- `--volumes-from $1` — see its volume mounts. Be careful with
  this in production debugging — it gives you write access to
  the volumes.
- The toolbox image — a UBI image with bash, curl, ss, ps,
  strace, tcpdump, and the rest of a working diagnostic
  toolkit.

Once inside:

```bash
# Inside the toolbox container:

# What process is the container running?
ps -ef

# What's listening?
ss -tlnp

# Is the application reachable from inside its own network?
curl -v http://localhost:3000

# Look at the app's open files.
ls -la /proc/1/fd
```

### When you need stronger introspection

The sidecar above is enough for poking at network state, file
descriptors, and process listings. When you need `strace`, `gdb`,
`perf`, or anything that uses `ptrace(2)`, the basic flags aren't
sufficient — you need to grant the debug container the
`SYS_PTRACE` capability and (on SELinux-enforcing hosts) relax
the security label so the debug container can actually attach to
the target.

```bash
podman run --rm -it \
  --cap-add=SYS_PTRACE \
  --security-opt label=disable \
  --pid="container:$CTR" \
  --network="container:$CTR" \
  --user 0 \
  registry.access.redhat.com/ubi9/toolbox:latest \
  bash

# Now inside the toolbox:
dnf install -y strace gdb
strace -p 1                    # attach to the target's PID 1
```

Three flags to understand:

- **`--cap-add=SYS_PTRACE`** — without this, `strace -p` and `gdb
  attach` return *Operation not permitted*.
- **`--security-opt label=disable`** — bypasses SELinux's
  `container_t` isolation for this debug container only. The
  target container's labels are unchanged. On macOS this is a
  no-op; on Fedora it's required to attach.
- **`--user 0`** — root inside the debug container, so `dnf install`
  works.

Use this variant only when you actually need ptrace. The basic
sidecar covers the majority of debugging cases without lifting any
security constraints.

## Layer 4 — Kubernetes ephemeral debug containers

When you're past the laptop and into a cluster, `kubectl debug`
does the equivalent of the sidecar pattern, but with the
cluster as the orchestrator:

```bash
# Attach a debug container to a running pod, sharing namespaces.
kubectl debug -it <pod-name> \
  --image=registry.access.redhat.com/ubi9/toolbox:latest \
  --target=<container-name>
```

The `--target` flag is the cluster equivalent of
`--pid=container:...`. Without it, the debug container shares
only the pod's network and volumes, not the target container's
PID namespace.

This is out of scope for the laptop-focused tutorial, but worth
mentioning for completeness — the mental model is the same as
layer 3.

## Newer technique — in-image debug with a builder image

The four layers above all assume you have a *running* container
that needs poking at. There's a complementary pattern for the
case where you're *developing* an application and want to run it
in a richer environment than the runtime image affords: bring up
a Hummingbird **builder** image interactively, mount your code
into it, and use the builder's package manager to install
debug-variant tools.

Why this works: Hummingbird builder images carry `dnf` and the
language toolchain. The runtime images don't — that's the whole
point. So the builder is the right place for `dnf install
python3-debug`, `gdb`, `strace`, and friends, even though you'd
never ship those into production.

### The pattern

```bash
podman run -it --rm \
  --user 0 \
  -v ./app:/app:Z \
  registry.access.redhat.com/hi/<lang>:<tag>-builder \
  bash
```

Three things to notice:

1. **`--user 0`** — root inside the container. Required so `dnf
   install` has permission. The container is ephemeral; this is
   only a risk in the sense that whatever you `dnf install` could
   come from a compromised mirror — same risk as on any build
   host.
2. **`-v ./app:/app:Z`** — your local working directory is mounted
   into the container. Edits on the host are visible to the
   running process; the `:Z` suffix relabels for SELinux on
   Fedora and is a no-op on macOS.
3. **`registry.access.redhat.com/hi/...`** — this is the Red Hat
   container catalog path for Hummingbird images. The build
   sections of this tutorial use the `quay.io/hummingbird` mirror;
   both should resolve to the same content. If your environment
   is configured for one, use it; otherwise the `hi/` namespace
   at `registry.access.redhat.com` is the canonical Red Hat
   customer path.

### Worked example — Python with pdb

```bash
# Drop into a Python builder shell with your code mounted.
podman run -it --rm --user 0 \
  -v ./app:/app:Z \
  registry.access.redhat.com/hi/python:latest-builder bash

# Now inside the container.
dnf install -y python3-debug
python3-debug -m pdb /app/main.py
```

You're now in `pdb` running against a Python with debug symbols,
on the same Python version as the runtime image. Set
breakpoints, step through, and when you've identified the issue,
fix the host file (the mount makes that a normal edit) and exit
the container.

### Worked example — Java with jdb

```bash
# Build with debug info first (host or in-container).
mvn -DskipTests package

podman run -it --rm --user 0 \
  -v ./target:/app:Z \
  registry.access.redhat.com/hi/openjdk-21:latest-builder bash

# Inside:
jdb -classpath /app/classes com.example.Main
```

For attaching to an already-running JVM in JDWP mode, expose the
JDWP port from the original container and use `jdb -attach
host:port` from this one.

### Worked example — Go with delve

```bash
podman run -it --rm --user 0 \
  -v .:/src:Z -w /src \
  registry.access.redhat.com/hi/go:latest-builder bash

# Inside:
go install github.com/go-delve/delve/cmd/dlv@latest
dlv debug ./...
```

### When to use this vs the sidecar pattern

The four-layer sidecar approach is for debugging a container
that's *already running*, in something close to its production
shape. The in-image builder approach is for debugging during
*development*, when you control how the process is launched.

| Scenario                                                    | Pattern                              |
|-------------------------------------------------------------|--------------------------------------|
| Local development, need a debugger or profiler              | In-image builder (this section)      |
| Reproducing a bug from a running production-shape image     | Layer 3 — basic sidecar              |
| App crashes on first request, can't catch it under pdb      | Layer 3 — sidecar with `SYS_PTRACE`  |
| Inspecting dependencies that aren't in the runtime image    | In-image builder                     |
| Profiling a hot path under realistic load                   | Layer 3 — sidecar with `SYS_PTRACE`  |

## When to reach for which layer

| Situation                                      | Start with |
|------------------------------------------------|------------|
| App is crashing on startup                     | Layer 1: `podman logs` |
| App is up but returning 500s                   | Layer 2: structured logs |
| App is up but unreachable from another service | Layer 3: sidecar, `curl localhost:port` |
| Network looks broken in some other way         | Layer 3: sidecar, `ss`, `tcpdump` |
| Need `strace`, `gdb`, or `perf`                | Layer 3: sidecar with `SYS_PTRACE` |
| Disk pressure or unexpected file growth        | Layer 3: sidecar with `--volumes-from` |
| Local development, want a real debugger (pdb, jdb, delve) | In-image builder |
| Same problem in a real cluster                 | Layer 4: `kubectl debug` |

The implicit principle: don't reach for a heavier tool than the
problem requires. Logs are cheaper than sidecars are cheaper than
clusters.

## Verify before moving on

You should be able to:

- list four layers of debugging without checking notes,
- pull up the logs and processes of a running container with
  three Podman commands,
- attach a debug sidecar to a running Hummingbird container and
  reach its ports via `localhost`,
- explain when `--cap-add=SYS_PTRACE` and
  `--security-opt label=disable` matter on the sidecar,
- run an interactive Python or Go debugger by mounting your code
  into a Hummingbird builder image, and
- explain why `--volumes-from` is a powerful flag to use with
  care in production debugging.

## Where to go next

The remaining sections cover advanced image-management topics:
[zstd:chunked]({{ "/docs/09-zstd-chunked/" | prepend: site.baseurl }}),
[chunkah]({{ "/docs/10-chunkah/" | prepend: site.baseurl }}),
and [real-world examples]({{ "/docs/11-real-world-examples/" | prepend: site.baseurl }}).
These are useful when you're optimising registry traffic, node
disk usage, or assembling end-to-end secure pipelines, and can
be skipped on a first pass through the tutorial.
