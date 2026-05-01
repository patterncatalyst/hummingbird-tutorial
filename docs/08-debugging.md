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
   normally has.
4. **Kubernetes ephemeral debug containers.** When the deployment
   target is a cluster, `kubectl debug` does the same thing the
   sidecar pattern does, but with the cluster as the orchestrator.

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

## When to reach for which layer

| Situation                                      | Start with |
|------------------------------------------------|------------|
| App is crashing on startup                     | Layer 1: `podman logs` |
| App is up but returning 500s                   | Layer 2: structured logs |
| App is up but unreachable from another service | Layer 3: sidecar, `curl localhost:port` |
| Network looks broken in some other way         | Layer 3: sidecar, `ss`, `tcpdump` |
| Disk pressure or unexpected file growth        | Layer 3: sidecar with `--volumes-from` |
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
  reach its ports via `localhost`, and
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
