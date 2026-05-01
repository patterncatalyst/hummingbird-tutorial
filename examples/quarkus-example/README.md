# quarkus-example

Trivial Quarkus app demonstrating the two-stage JVM-mode build pattern
on Hummingbird OpenJDK images. Walked through in
[§4 — Multi-stage builds, Example A](../../docs/04-multi-stage-builds.md).

JVM mode rather than native — building a native image needs a different
builder image and roughly doubles build time. JVM mode is what most
teams ship; native is conceptual ground covered in the tutorial body.

## Build and run

```bash
cd $(git rev-parse --show-toplevel)/examples/quarkus-example

podman build -t hummingbird-quarkus-example:latest .

podman run -d --name hb-q -p 8080:8080 hummingbird-quarkus-example:latest

# Quarkus boots in a few seconds — give it 3-5s on a cold image, less
# on subsequent runs.
sleep 5
curl -s http://localhost:8080 | jq
# {
#   "status": "ok",
#   "runtime": "hummingbird-quarkus",
#   "javaVersion": "21.0.x",
#   "javaVendor": "Red Hat, Inc."
# }

podman stop hb-q && podman rm hb-q
```

## Why JVM mode is the realistic default

The Quarkus marketing pitch is around native image builds — fast cold
start, low memory. Both real. But native builds:

- Need a separate Mandrel/GraalVM builder image.
- Take 2–4× longer than JVM builds.
- Don't always succeed without tuning, especially with reflection-heavy
  libraries.

For most production workloads JVM mode is the right starting point —
predictable, fast to build, well-understood. Move to native when you
have a measurable reason. This example deliberately shows the JVM
path so the build is fast enough to fit in a tutorial.

## Why `openjdk:21-runtime` instead of `openjdk:21`

Hummingbird publishes both a full JDK runtime (`openjdk:21`) and a
JRE-only runtime (`openjdk:21-runtime`). For an application that
only runs bytecode at runtime — no `javac`, no Maven invocations
inside the container — the JRE-only image is meaningfully smaller
and removes attack surface that wouldn't be exercised anyway.
That's what we use here.

If you needed to compile inside the container at runtime (rare —
think hot-reloading scripts, or a JShell-driven service), use
`openjdk:21` instead.

## What about the Maven wrapper?

A real `quarkus create app` generates `mvnw` / `mvnw.cmd` / `.mvn/`
files for a self-contained Maven setup. We omit them here because
they're large binary blobs and the Hummingbird OpenJDK builder
image ships Maven, so `mvn` works directly. If you want the wrapper
for use outside the container, run once:

```bash
mvn -N wrapper:wrapper -Dmaven=3.9.6
```

## Override the registry

```bash
podman build \
  --build-arg HB_REGISTRY=registry.internal.example.com/hb \
  -t hummingbird-quarkus-example:latest .
```

## What's in here

| File                                                | Why                                                     |
| --------------------------------------------------- | ------------------------------------------------------- |
| `pom.xml`                                           | Quarkus 3.33 LTS, REST + JSON-B; minimal dependency set |
| `src/main/java/com/example/HelloResource.java`      | Single-endpoint REST resource                           |
| `src/main/resources/application.properties`         | HTTP host/port + log format                             |
| `Containerfile`                                     | Two-stage: `openjdk:21-builder` → `openjdk:21-runtime`  |

## Why not native here

If you do want to try native, the conceptual change is one extra
build stage. The Mandrel builder image's exact name in the
Hummingbird catalog isn't yet verified — see the
[reconciliation plan](../../plans/reconciliation-plan.md) for the
in-flight question. Treat the snippet below as illustrative until
the catalog is checked:

```dockerfile
# Native build stage — adds 2-4 minutes to build time.
FROM ${HB_REGISTRY}/openjdk:21-mandrel-builder AS native
WORKDIR /build
COPY --from=builder /build /build
RUN mvn -B -Pnative package -DskipTests

# Native runtime — much smaller, no JVM needed.
FROM ${RH_REGISTRY}/ubi9/ubi-micro:latest
COPY --from=native /build/target/*-runner /app
CMD ["/app"]
```
