---
title: Multi-stage builds
order: 4
description: Use Hummingbird builder images for the build stage and Hummingbird runtime images for the final stage. Examples in Java (Quarkus), Python, Go, with a Node.js appendix.
duration: 45 minutes
---

This is the canonical Hummingbird workflow. You build your
application in one stage using a *builder* image (a Hummingbird
language image with the compiler, package manager, and headers
present), and you run it in a second stage using a *runtime*
image (a Hummingbird language image stripped to just the runtime).
The final image inherits the small footprint and minimal attack
surface of Hummingbird, while the build still gets the full
toolchain it needs.

We'll work through three primary examples — Java (Quarkus, JVM
mode), Python (FastAPI with the wheel-build pattern), and Go (a
static binary on the Hummingbird Go runtime) — in roughly the
order most readers will care about them. A fourth example for
Node.js is in the appendix at the bottom of the section,
included as a reference for the same multi-stage pattern.

## The two-stage pattern in one diagram

{% include excalidraw.html
   file="04-multi-stage-builds-pattern"
   alt="Two-stage container build: a Hummingbird builder image compiles the application, then COPY --from copies the artifact into a Hummingbird runtime image"
   caption="Figure 4.1 — The two-stage build pattern with Hummingbird builder and runtime images" %}

A few rules apply to every example:

- **Builder image first.** When a Hummingbird builder image exists
  for your language, use it as the `FROM ... AS builder` stage.
  Fall back to a UBI builder only when no Hummingbird builder is
  available.
- **Runtime image last.** The final `FROM` is always a Hummingbird
  runtime image.
- **Pin tags.** Use a specific major-version tag (e.g. `nodejs:20`
  rather than `nodejs:latest`) so a major-version bump never silently
  enters your build.
- **`COPY` only in the runtime stage; never `RUN`.** Hummingbird
  runtime images are distroless — no `/bin/sh`, no package
  manager, nothing to interpret a `RUN` line. Buildah will fail
  with `executable file '/bin/sh' not found` if you try. Anything
  that needs to execute (`pip install`, `dnf install`, custom
  setup scripts) must run in the builder stage; the runtime
  receives only the resulting filesystem via `COPY --from`.
- **Set `HOME` in the builder.** UID 1001 doesn't have a home
  directory in the Hummingbird builder images, so tools that
  default to `~/.cache` or `~/.m2` (Go, Maven, pip, npm) will try
  to write to `/.cache` or `/.m2` and fail with permission
  denied. `ENV HOME=/build` near the top of the builder stage
  fixes this once for the whole stage.
- **Run as a non-root user.** Hummingbird images default to
  UID 1001. Use `--chown=1001:1001` on every `COPY`.

## Setting up a project directory

Each example below is self-contained. Pick a working directory
and we'll create a subdirectory per example as we go.

```bash
mkdir -p ~/hummingbird-tutorial/examples
cd ~/hummingbird-tutorial/examples
```

## Example A — Java (Quarkus, JVM mode)

Java is the example with the most subtleties. We'll start with
the straightforward JVM mode here. A native-image variant is in
section 11.

### A pitfall worth knowing about up front

If you are training a JDK 25 AOT cache (Project Leyden) inside
your build, the **training JVM and runtime JVM must be exactly
the same build**, not just the same major version. A Maven
container with Eclipse Temurin and a Hummingbird OpenJDK runtime
have different JVM build identifiers, and the AOT cache will
refuse to load at runtime with a confusing "unable to map shared
spaces" error.

The fix is a three-stage build (compile → train → run) where the
train stage and the run stage use the same JVM. We'll show the
classic two-stage pattern here; the three-stage AOT variant is
covered in section 11 with the full AOT discussion.

### Set up

This example assumes you have a Quarkus skeleton from
`mvn quarkus:create` or the Quarkus CLI. If you don't, the
short version:

```bash
cd ~/hummingbird-tutorial/examples
mkdir -p java-example && cd java-example

# A fully fleshed-out Quarkus app is too much for a tutorial step.
# See the examples/ directory in the repository for a complete
# reference; the snippet below is the structure of the Containerfile
# you'd use against any standard Quarkus build.
```

### Containerfile (JVM mode)

```bash
cat > Containerfile.jvm <<'EOF'
ARG HB_REGISTRY=quay.io/hummingbird
ARG RH_REGISTRY=registry.access.redhat.com

# ── Stage 1: Build with UBI OpenJDK 21 (Maven pre-installed) ────────────────
# Note that this builder image is UBI, not Hummingbird. The
# Hummingbird openjdk:21-builder ships the JDK and javac but does
# not pre-install Maven — Hummingbird keeps builder images minimal,
# only including tools every user actually wants. UBI's openjdk-21
# image is purpose-built for Java builds with Maven and Gradle
# pre-installed and on PATH.
#
# The CVE surface that ships in production is the runtime image,
# not the builder; the larger UBI builder never reaches the
# deployed artefact. The runtime stage below is back on
# Hummingbird's distroless OpenJDK JRE.
FROM ${RH_REGISTRY}/ubi9/openjdk-21:latest AS builder
USER root
WORKDIR /build

COPY pom.xml ./

# Cache dependencies as a separate layer. If pom.xml does not change,
# this layer is reused.
RUN mvn -B -ntp dependency:go-offline

COPY src ./src
RUN mvn -B -ntp package -DskipTests

# ── Stage 2: Runtime on the Hummingbird OpenJDK JRE ─────────────────────────
FROM ${HB_REGISTRY}/openjdk:21-runtime
WORKDIR /app

COPY --from=builder --chown=1001:1001 /build/target/quarkus-app/lib/      ./lib/
COPY --from=builder --chown=1001:1001 /build/target/quarkus-app/*.jar     ./
COPY --from=builder --chown=1001:1001 /build/target/quarkus-app/app/      ./app/
COPY --from=builder --chown=1001:1001 /build/target/quarkus-app/quarkus/  ./quarkus/

USER 1001
EXPOSE 8080
ENV JAVA_OPTS_APPEND="-Dquarkus.http.host=0.0.0.0"

ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
EOF
```

The build invocation is the same as the other examples:

```bash
podman build -f Containerfile.jvm -t hummingbird-quarkus-jvm:latest .
```

## Example B — Python

Python is the example where the multi-stage pattern earns its
keep most visibly. The build stage compiles wheels for any C
extensions; the runtime stage installs from those wheels and
never needs a compiler.

### Set up the project

```bash
cd ~/hummingbird-tutorial/examples
mkdir -p python-example && cd python-example

cat > app/main.py <<'EOF'
# Minimal FastAPI app with a single route.
from fastapi import FastAPI
import sys

app = FastAPI()

@app.get("/")
def root():
    return {"status": "ok", "runtime": "hummingbird-python", "python": sys.version}
EOF
mkdir -p app && mv app/main.py app/  2>/dev/null || true   # ensures app/ exists

# Pin major versions only; pip will resolve the latest patches.
cat > requirements.txt <<'EOF'
fastapi==0.115.*
uvicorn[standard]==0.32.*
EOF
```

### Write the Containerfile

```bash
cat > Containerfile <<'EOF'
ARG HB_REGISTRY=quay.io/hummingbird
ARG RH_REGISTRY=registry.access.redhat.com

# ── Stage 1: Build wheels and install them into a stage-local prefix ────────
# Hummingbird runtime images are distroless: there's no /bin/sh in
# stage 2, so we cannot RUN anything there. Everything that requires
# a shell — pip install in particular — happens here in the builder.
# We install into /install with --prefix to get a clean tree to copy.
FROM ${HB_REGISTRY}/python:3.13-builder AS builder
USER 1001
WORKDIR /build

# pip writes to ~/.cache by default. Set HOME explicitly so it points
# at /build, which UID 1001 owns.
ENV HOME=/build PIP_NO_CACHE_DIR=1

COPY --chown=1001:1001 requirements.txt .

# Compile wheels for everything in requirements.txt, then install into
# /install. This pulls in any C-extension build dependencies present
# in the builder image.
RUN pip wheel --wheel-dir /build/wheels -r requirements.txt && \
    pip install --no-index --find-links=/build/wheels --prefix=/build/install \
        /build/wheels/*.whl

COPY --chown=1001:1001 app/ /build/app/

# ── Stage 2: Runtime on Hummingbird Python (distroless, no shell) ───────────
# Only COPY here — RUN cannot work because the runtime has no shell.
FROM ${HB_REGISTRY}/python:3.13
WORKDIR /app

# /build/install/lib/python3.13/site-packages lands at
# /usr/local/lib/python3.13/site-packages, which Python finds by default.
COPY --from=builder /build/install /usr/local
COPY --from=builder --chown=1001:1001 /build/app /app/app

USER 1001
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "app.main:app", \
     "--host", "0.0.0.0", "--port", "8000"]
EOF
```

### Build and run

```bash
podman build -t hummingbird-py-example:latest .

podman run -d \
  --name hb-py \
  -p 8000:8000 \
  hummingbird-py-example:latest

curl -s http://localhost:8000 | jq

podman stop hb-py && podman rm hb-py
```

## Example C — Go

Go is the easy example. Compile to a static binary in the builder
stage, copy the binary into the Hummingbird Go runtime, done. The
runtime image is essentially just glibc and a non-root user — Go's
static binaries don't need a language runtime in the deploy stage.

### Set up

```bash
cd ~/hummingbird-tutorial/examples
mkdir -p go-example && cd go-example

cat > main.go <<'EOF'
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "runtime"
)

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(map[string]string{
            "status":  "ok",
            "runtime": "hummingbird-go",
            "go":      runtime.Version(),
        })
    })
    log.Printf("Listening on :%s", port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
EOF

cat > go.mod <<'EOF'
module hummingbird-go-example

go 1.22
EOF
```

### Containerfile

```bash
cat > Containerfile <<'EOF'
ARG HB_REGISTRY=quay.io/hummingbird
ARG RH_REGISTRY=registry.access.redhat.com

# ── Stage 1: Compile with the Hummingbird Go builder ────────────────────────
FROM ${HB_REGISTRY}/go:1.26-builder AS builder
USER 1001
WORKDIR /build

# Go writes to HOME/.cache/go-build by default. The Hummingbird builder
# image doesn't set HOME for UID 1001, so Go falls back to /.cache and
# fails with permission denied. Point GOCACHE at a writable directory.
ENV HOME=/build GOCACHE=/build/.cache/go-build

COPY --chown=1001:1001 go.mod ./
COPY --chown=1001:1001 main.go ./

# Static binary: no cgo, no dynamic linker needed.
# -trimpath strips local build paths from the binary for reproducible
# builds; -ldflags "-s -w" strips the symbol table and DWARF debug
# info to keep the binary small.
RUN CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" -o app .

# ── Stage 2: Hummingbird Go runtime ─────────────────────────────────────────
# The Hummingbird Go runtime is the smallest base for a Go binary
# in the Hummingbird catalog: glibc, a non-root UID 1001 user, ca
# certificates, and not much else. It does not contain the Go
# toolchain — that's what the builder is for.
FROM ${HB_REGISTRY}/go:1.26
WORKDIR /app

COPY --from=builder --chown=1001:1001 /build/app ./app

USER 1001
EXPOSE 8080
CMD ["./app"]
EOF
```

### Build and run

```bash
podman build -t hummingbird-go-example:latest .

podman images hummingbird-go-example
# Notice how small this is — typically under 30 MB total.

podman run -d \
  --name hb-go \
  -p 8080:8080 \
  hummingbird-go-example:latest

curl -s http://localhost:8080 | jq

podman stop hb-go && podman rm hb-go
```

The Go example is the one where the size win is most dramatic.
A static Go binary on the Hummingbird Go runtime typically lands
around 30 MB — orders of magnitude smaller than the equivalent
general-purpose image.

## Cross-cutting: build args for environment switching

All four examples above use the same `HB_REGISTRY` and `RH_REGISTRY`
build args. That's deliberate — it lets the same Containerfile
build against the public registries on a connected machine and
against an internal mirror on a disconnected one, without
modifying the Containerfile.

```bash
# Connected build (default values).
podman build -t myapp:latest .

# Build against an internal mirror.
podman build \
  --build-arg HB_REGISTRY=registry.internal.example.com/hummingbird \
  --build-arg RH_REGISTRY=registry.internal.example.com/redhat \
  -t myapp:latest .
```

If you set `HB_REGISTRY` and `RH_REGISTRY` in your shell (as
recommended in the [prerequisites]({{ "/docs/01-prerequisites/" | prepend: site.baseurl }})),
you can also let those environment variables drive the build:

```bash
podman build \
  --build-arg HB_REGISTRY="$HB_REGISTRY" \
  --build-arg RH_REGISTRY="$RH_REGISTRY" \
  -t myapp:latest .
```

## Language-specific considerations

The three primary examples follow the same two-stage pattern, but
each language has its own gotchas. These are the things that bit
people in the source material that this tutorial is built from.

### Java (Quarkus)

**Match the JDK exactly between builder and runtime.** Hummingbird
publishes `openjdk:21-builder` and `openjdk:21-runtime` as a
matched pair. Don't mix `openjdk:21-builder` with
`openjdk-17-runtime` — the JVM AOT cache and the bytecode-version
floor both depend on identical major versions. Mixing produces
either runtime errors at first method invocation or — worse —
silent slowdowns when the runtime falls back to interpreted mode.

**JVM mode by default; native-image only when you have a reason.**
GraalVM/Mandrel native compilation cuts cold-start time and
memory, but it adds 2–4× to build time and not every dependency
plays well with reflection-heavy native compilation. For most
production workloads, JVM mode is the right starting point. Move
to native when there's a measurable need — typically scale-to-zero
serverless or memory-constrained edge deployment.

**Use the `target/quarkus-app/` fast-jar layout, not a fat-jar.**
Quarkus 3.x produces a directory structure with the launcher jar
plus a flat `lib/` tree. Smaller and faster to copy than a fat-jar,
and the layers are more cacheable across builds.

**Tune the JVM for the container, not the host.** `-Xmx` should
reference the cgroup memory limit, not physical RAM. OpenJDK 21
does this automatically with `-XX:+UseContainerSupport` (default
on), but verify with `podman inspect` that the cgroup limit is
what you expect. Without the limit set, the JVM sees host memory
and over-allocates.

**Debugging needs JDWP exposed at runtime.** The Hummingbird
runtime image lacks `jdb` — that lives in the builder. The §8
in-image-builder pattern is the right approach: build with debug
info, mount the resulting `target/` into a builder container, run
`jdb -attach` against the JDWP port your production container
exposes. Don't bake `jdb` into the runtime.

### Python

**Wheel-build pattern, not pip-in-runtime.** Pre-build wheels in
the builder stage with `pip wheel --wheel-dir=/build/wheels -r
requirements.txt`. Then in the runtime, install offline:
`pip install --no-index --find-links=/tmp/wheels /tmp/wheels/*.whl`.
The runtime never reaches the network, never runs a compiler.

**Native dependencies need build tools in the builder.** Packages
like `numpy`, `cryptography`, `psycopg2`, and `pillow` ship native
code that pip compiles unless a pre-built wheel is available for
your platform. The Hummingbird `python:3.13-builder` image carries
the C toolchain. The runtime doesn't need to.

**Match Python versions exactly.** A wheel built against Python
3.11 won't load in a 3.12 runtime. Keep
`python:3.13-builder` paired with `python:3.13`. If you need a
different version, switch *both* together.

**TLS and time zones are not in the runtime by default.**
Hummingbird's Python runtime ships a minimal filesystem. If your
app makes outbound HTTPS calls or uses `zoneinfo.ZoneInfo`, you
need to add `ca-certificates` and `tzdata`. The §14 RPM-install
pattern covers exactly this case.

**Debugging — install `python3-debug` in the builder, not the
runtime.** The §8 in-image-builder pattern: mount your source into
a `python:3.13-builder` container, `dnf install python3-debug`, run
`python3-debug -m pdb your-app.py`. Set breakpoints, fix on the
host, restart. The runtime stays clean.

### Go

**Static binary by default; that's the win.** With
`CGO_ENABLED=0`, the resulting binary has no dynamic-linker
dependency. You can confirm with `ldd app` — output should be
"not a dynamic executable". This is what makes the runtime image
trivially small.

**The runtime image isn't really a runtime.** Unlike Python or
Java, a static Go binary doesn't need a language runtime.
Hummingbird's `go:1.26` runtime image is essentially a minimal
base — glibc, a non-root user, CA certificates. You're picking it
for the user/glibc/certs, not for any "Go runtime".

**`-trimpath` and `-ldflags="-s -w"` aren't optional.** `-trimpath`
strips local build paths from the binary for reproducible builds —
the same source committed at the same commit produces a
byte-identical binary regardless of who built it where.
`-ldflags="-s -w"` strips the symbol table and DWARF debug info.
Together they shave ~30% off the binary size and remove
build-host fingerprints.

**Non-root UID 1001 ships in the runtime.** If your code calls
anything that looks up the running user (`os/user.Current()`,
certain logging libraries), the runtime image needs `/etc/passwd`
to have UID 1001. The Hummingbird `go:1.26` runtime ships this by
default — no extra `COPY` needed.

**Debugging with delve — install in the builder, attach over
network.** `dlv` doesn't exist in the runtime image. The §8
in-image-builder pattern with `${HB_REGISTRY}/go:1.26-builder`,
mount your source, `go install
github.com/go-delve/delve/cmd/dlv@latest`, then `dlv exec ./app`
or `dlv attach <pid>` against a deployed binary. Expose the
delve port from the prod container only when actively debugging.

### What's the same across all three

- **Always run as UID 1001.** Hummingbird images default to it;
  use `--chown=1001:1001` on every `COPY` so the runtime user can
  read what you copied.
- **Always pin tags, ideally digests.** A `FROM
  ${HB_REGISTRY}/python:3.13` is fine for a tutorial; in
  production, pin to a specific tag or a SHA digest. §15 covers
  the tag strategies.
- **Always two stages.** Mixing build-time tools into the runtime
  is the most common Hummingbird mistake. If you find yourself
  reaching for `RUN apt-get` or `RUN dnf` in the runtime stage,
  stop and refactor — that work belongs in the builder.

## Appendix — Node.js

> The Node example is included as an appendix because the audience this tutorial is aimed at — JVM, Python, and Go backends — sees less Node in production. The two-stage pattern is identical, so if you do ship Node services, the same shape applies. Read it for the pattern; reach for the language-specific examples above for code you will actually copy.

A small Express-style app. Realistic enough that the `npm ci`
step actually does work, but small enough to read in one screen.

### Set up the project

```bash
mkdir -p node-example && cd node-example

# A trivial server that returns a JSON heartbeat.
cat > server.js <<'EOF'
const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    runtime: 'hummingbird-nodejs',
    nodeVersion: process.version
  }));
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Listening on ${port}`);
});
EOF

# Minimal package.json with no real deps so the build is fast.
cat > package.json <<'EOF'
{
  "name": "hummingbird-node-example",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
EOF

# A package-lock.json so npm ci has something to lock against.
echo '{}' > package-lock.json
```

### Write the Containerfile

```bash
cat > Containerfile <<'EOF'
# Build args make the same Containerfile work against the public
# registry or against an internal mirror. Override on the command
# line: --build-arg HB_REGISTRY=registry.internal.example.com/hb
ARG HB_REGISTRY=quay.io/hummingbird
ARG RH_REGISTRY=registry.access.redhat.com

# ── Stage 1: Build with the Hummingbird Node builder ────────────────────────
FROM ${HB_REGISTRY}/nodejs:20-builder AS builder
WORKDIR /build

# Cache deps separately from source. If package*.json don't change,
# the install layer is reused on the next build.
COPY --chown=1001:1001 package*.json ./
RUN npm ci --include=dev

# Copy source and build. There's nothing to compile in this trivial
# example, but real apps would run `npm run build` here.
COPY --chown=1001:1001 . .

# Drop dev deps before copying node_modules forward.
RUN npm prune --production

# ── Stage 2: Runtime on Hummingbird Node ────────────────────────────────────
FROM ${HB_REGISTRY}/nodejs:20
WORKDIR /app

# Copy only what the runtime needs.
COPY --from=builder --chown=1001:1001 /build/server.js ./
COPY --from=builder --chown=1001:1001 /build/node_modules ./node_modules
COPY --from=builder --chown=1001:1001 /build/package.json ./

USER 1001
ENV NODE_ENV=production
EXPOSE 3000

# Explicit entrypoint — no shell glob expansion to worry about.
CMD ["node", "server.js"]
EOF
```

> **Note on the builder image name.** This tutorial assumes the
> Hummingbird Node builder is published as `nodejs:20-builder`. If
> the image you have access to is named differently
> (`nodejs-20-devel`, `nodejs-20-build`, etc.), substitute that
> here. If no Hummingbird Node builder exists in your environment
> yet, replace the first `FROM` with `${RH_REGISTRY}/ubi9/nodejs-20:latest`
> as a fall-back.

### Build it

```bash
podman build -t hummingbird-node-example:latest .
```

If the build fails on the first `FROM` because the
`nodejs:20-builder` image is not yet available in your registry,
switch to the UBI fall-back:

```bash
podman build \
  --build-arg HB_REGISTRY="$HB_REGISTRY" \
  --build-arg RH_REGISTRY="$RH_REGISTRY" \
  -t hummingbird-node-example:latest .
```

### Run it

```bash
podman run -d \
  --name hb-node \
  -p 3000:3000 \
  hummingbird-node-example:latest

curl -s http://localhost:3000 | jq

podman stop hb-node && podman rm hb-node
```

You should see a JSON response from the app, then the cleanup
removes the container.

## Verify before moving on

You should now be able to:

- explain why the runtime stage uses `COPY --from=...` instead
  of `RUN`,
- write a two-stage Containerfile for any of the four languages
  above without copying from the tutorial, and
- swap registry hosts with build args without editing the
  Containerfile.

If you cleaned up after each example, your system has only the
three or four built images we tagged above. Leave them in place —
section 5 will sign and SBOM-attest them.

## Where to go next

[SBOMs and signing]({{ "/docs/05-sbom-and-signing/" | prepend: site.baseurl }})
takes one of the images you just built and walks through
generating an SBOM, signing the image, and attaching the SBOM
as an attestation that travels with the image.
