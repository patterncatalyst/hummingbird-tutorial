---
title: Distroless gotchas — lessons from the field
order: 17
description: A debugging-and-prevention reference for the rough edges that surface when running real workloads on Hummingbird's distroless runtime images. Documents symptoms, root causes, and fixes for the issues that came up during tutorial development and testing.
duration: 30 minutes
---

This section exists because Hummingbird's
[distroless]({{ "/docs/02-introduction/#distroless" | prepend: site.baseurl }}) minimalism — the
property that makes it a great runtime for security-conscious workloads —
also magnifies every implicit assumption baked into the wider container
ecosystem. A tool that "just works" on UBI or Alpine because some package
is incidentally present can fail in surprising ways on a runtime that
ships only what's strictly needed.

This page collects the issues that came up while writing and testing
this tutorial against real Hummingbird images, in roughly the order
you're likely to hit them. Each entry has the symptom you'll see, the
root cause, and the fix.

If you're hitting an unfamiliar problem with a Hummingbird build, the
fastest path is usually: skim this list for the symptom, apply the fix,
move on. Many of the symptoms (`mvn: command not found`,
`Connection reset by peer`, `cannot open shared object file`) are
genuinely cryptic on first encounter and quick to diagnose once you've
seen them once.

## Build-time gotchas

These surface during `podman build` itself.

### "executable file '/bin/sh' not found" in a runtime stage

**Symptom:**

```
error running container: from /usr/bin/crun creating container for [/bin/sh -c ...]:
executable file `/bin/sh` not found: No such file or directory
```

**Root cause:** Hummingbird runtime images are distroless. There is no
`/bin/sh`, no shell of any kind. Buildah's `RUN` instruction defaults to
`/bin/sh -c <command>`, which fails the moment you try to use `RUN` in a
runtime stage.

**Fix:** Move everything that needs a shell into the builder stage. The
runtime stage takes only `COPY` instructions. Any setup (installing
packages, running scripts, modifying files) must happen in the builder,
with the result `COPY`-ed across.

```dockerfile
# Wrong — fails because /bin/sh doesn't exist in runtime
FROM ${HB_REGISTRY}/python:3.13
RUN pip install some-package      # NO

# Right — install in builder, copy result to runtime
FROM ${HB_REGISTRY}/python:3.13-builder AS builder
RUN pip install --prefix=/build/install some-package

FROM ${HB_REGISTRY}/python:3.13
COPY --from=builder /build/install /usr/local
```

### "Permission denied" on `/.cache`, `/.npm`, `/.m2`

**Symptom:** A build tool fails with permission denied on a path at the
filesystem root:

```
failed to initialize build cache at /.cache/go-build: mkdir /.cache: permission denied
EACCES: permission denied, mkdir '/.npm'
[ERROR] Could not create local repository at /.m2/repository
```

**Root cause:** Hummingbird builder images run as UID 1001 by default,
but they don't set `HOME` for that user. Many build tools default to
`$HOME/.cache`, `$HOME/.npm`, or `$HOME/.m2` for their working state.
With `HOME` unset, those paths resolve to `/.cache`, `/.npm`, and `/.m2`
at the filesystem root, where UID 1001 has no write permission.

**Fix:** Set `HOME` to a directory the build user owns. `/build` is the
conventional choice (used as `WORKDIR` in this tutorial's examples):

```dockerfile
FROM ${HB_REGISTRY}/python:3.13-builder AS builder
USER 1001
WORKDIR /build
ENV HOME=/build
```

For tools that don't read `$HOME` but read their own environment
variable, set both:

```dockerfile
ENV HOME=/build
ENV GOCACHE=/build/.cache/go-build      # Go
ENV NPM_CONFIG_CACHE=/build/.npm        # npm
ENV PIP_NO_CACHE_DIR=1                  # pip — sidesteps the issue
```

### "Permission denied" on `/install` with `pip install --prefix`

**Symptom:**

```
ERROR: Could not install packages due to an OSError:
[Errno 13] Permission denied: '/install'
```

**Root cause:** `pip install --prefix=/install` tries to create
`/install/` at the filesystem root. UID 1001 can't create directories
at `/`.

**Fix:** Use a prefix path inside the builder's working directory:

```dockerfile
RUN pip install --prefix=/build/install some-package
```

Then in the runtime stage, copy the prefix into `/usr/local`:

```dockerfile
COPY --from=builder /build/install /usr/local
```

The `/build/install/lib/python3.13/site-packages/` directory lands at
`/usr/local/lib/python3.13/site-packages/`, which is on Python's default
search path. Same for `bin/` scripts.

### "mvn: command not found" in `openjdk:21-builder`

**Symptom:**

```
/bin/sh: line 1: mvn: command not found
```

**Root cause:** The Hummingbird `openjdk:21-builder` image ships the JDK
and `javac` but does not pre-install Maven. Hummingbird keeps builder
images minimal — build tools that not every user needs (Maven, Gradle,
Ant) aren't included. For a `javac`-driven Java project, the Hummingbird
builder is sufficient. For a Maven- or Gradle-driven project, it isn't.

**Fix:** Use UBI's `openjdk-21` for the builder stage. UBI's image is
purpose-built for Java builds with Maven and Gradle pre-installed. The
runtime stage stays on `${HB_REGISTRY}/openjdk:21-runtime`.

```dockerfile
# Build with UBI — has Maven
FROM ${RH_REGISTRY}/ubi9/openjdk-21:latest AS builder
USER root
WORKDIR /build
COPY pom.xml ./
RUN mvn -B -ntp dependency:go-offline
COPY src ./src
RUN mvn -B -ntp package -DskipTests

# Deploy on Hummingbird — distroless JRE
FROM ${HB_REGISTRY}/openjdk:21-runtime
WORKDIR /app
COPY --from=builder --chown=1001:1001 /build/target/quarkus-app/*.jar ./
COPY --from=builder --chown=1001:1001 /build/target/quarkus-app/lib/  ./lib/
USER 1001
CMD ["java", "-jar", "quarkus-run.jar"]
```

The CVE surface that ships in production is the runtime image, not the
builder — the larger UBI builder doesn't reach the deployed artifact.

## Runtime gotchas

These surface when the image runs.

### "python: command not found"

**Symptom:**

```
crun: executable file `python` not found in $PATH:
No such file or directory: OCI runtime attempted to invoke a command that was not found
```

**Root cause:** The Hummingbird `python:3.13` runtime ships `python3` but
not the bare `python` symlink. Distroless images skip convenience aliases
that full distros provide for backwards compatibility.

**Fix:** Use the canonical name in `CMD` and `ENTRYPOINT`:

```dockerfile
# Wrong
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0"]

# Right
CMD ["python3", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0"]
```

### "ModuleNotFoundError" for a package you definitely installed

**Symptom:** A package that pip installed successfully isn't found at
runtime:

```
ModuleNotFoundError: No module named 'fastapi'
```

**Root cause:** RHEL-based distributions split Python's `site-packages`
across two directories — pure-Python code lands in
`/usr/local/lib/python3.13/site-packages/`, compiled C-extension code
lands in `/usr/local/lib64/python3.13/site-packages/`. The runtime
image's default `sys.path` may not include the `lib64` variant. Packages
installed in one directory are invisible to a Python that doesn't search
the other.

**Fix:** Set `PYTHONPATH` to cover both directories explicitly:

```dockerfile
ENV PYTHONPATH=/usr/local/lib/python3.13/site-packages:/usr/local/lib64/python3.13/site-packages
```

This is harmless if a directory doesn't exist (Python silently skips
missing paths) and ensures the runtime finds packages regardless of
which directory pip chose for them.

### "cannot open shared object file: libstdc++.so.6"

**Symptom:** Importing a NumPy/SciPy/pandas package fails with a missing
shared library:

```
ImportError: libstdc++.so.6: cannot open shared object file: No such file or directory
```

**Root cause:** Hummingbird's distroless `python:3.13` runtime ships
only what bare CPython needs — the C++ standard library isn't included
because vanilla Python doesn't use it. NumPy's compiled extensions are
written in C++ and need `libstdc++` at runtime; same for many other
scientific-Python packages.

**Fix:** `COPY` the C++ runtime libraries from the builder (which has
them for compiling C-extensions during install). This is the
selectively-copy-shared-libraries pattern, and it's the standard tool
for adapting distroless runtimes to native-extension workloads:

```dockerfile
COPY --from=builder /usr/lib64/libstdc++.so.6* /usr/lib64/
COPY --from=builder /usr/lib64/libgcc_s.so.1*  /usr/lib64/
COPY --from=builder /usr/lib64/libgomp.so.1*   /usr/lib64/
```

The three above cover most of the NumPy stack:

- `libstdc++` — C++ symbols required at import time.
- `libgcc_s` — GCC support runtime, required for stack unwinding.
- `libgomp` — OpenMP runtime, used by NumPy's bundled OpenBLAS for
  parallel matrix operations. Often delay-loaded: the import succeeds
  without it, but the first actual compute (`np.eye(3).sum()`) triggers
  a load that fails. Failure manifests as a silent SIGSEGV killing the
  worker; the request returns "Connection reset by peer" with no
  traceback.

When a package fails at import with another `libfoo.so.X: cannot open
shared object file`, **or** when a request crashes the worker silently,
the cure is the same: add another `COPY` line.

Common candidates for additions:

| Package | Likely missing library |
|---|---|
| scipy | `libgfortran.so.5`, `libquadmath.so.0` |
| pandas with PyArrow | `libffi.so.7`, possibly `libstdc++` already covered |
| lxml | `libxml2.so.2`, `libxslt.so.1` |
| Pillow | `libjpeg.so.62`, `libpng16.so.16` |
| psycopg2-binary | `libpq.so.5` (or use psycopg2 wheel that bundles it) |
| cryptography | normally fine — wheel is statically linked |

If your COPY list is starting to look like a hand-rolled mini-distro,
that's the signal to consider switching the runtime to UBI Python.
See "When Hummingbird isn't the right runtime" below.

## Network gotchas

These surface only when you're testing your container — fine in
production, confusing in development.

### "Connection reset by peer" against a working container

**Symptom:** Your application's logs show a clean startup. The container
is in `Status=running`. But `curl http://localhost:8080/` resets:

```
curl: (56) Recv failure: Connection reset by peer
```

**Root cause:** Modern resolvers prefer IPv6. `curl http://localhost`
resolves `localhost` to `::1` first and connects there. If your
application binds with Python's `socket.bind(("0.0.0.0", port))`, that's
IPv4-only — your listener isn't on `::1`. Podman's port forwarder
accepts the connection on the IPv6 side, can't deliver it to a listener
that doesn't exist, and resets back to curl. The container is fine; the
test harness is hitting the wrong address family.

This is not Hummingbird-specific — it would behave identically against
any distro — but it surfaces more often in distroless environments
because they tend to have leaner network configurations and less
ambient dual-stack helper machinery.

**Fix at the test layer:** Use `127.0.0.1` (IPv4 explicit), not
`localhost`:

```bash
# Wrong if your container binds 0.0.0.0 only
curl http://localhost:8080/

# Right
curl http://127.0.0.1:8080/
```

**Fix at the application layer (if you want dual-stack):** bind
explicitly to both:

```python
# uvicorn — bind both stacks
uvicorn.run(app, host="::", port=8000)
```

Languages where the standard library binds dual-stack by default:

- Go (`http.ListenAndServe(":8080", ...)` — both stacks)
- Java (most servers — both stacks)

Languages where you have to opt in:

- Python (single stack, default; bind to `::` for dual-stack)
- Node.js (single stack, default)

## Configuration gotchas

These come up in compose files and orchestration, not the Containerfile
itself.

### Postgres exits at startup with "POSTGRES_PASSWORD is not specified"

**Symptom:** The Hummingbird `postgresql:18` container exits seconds
after `compose up`. Logs show:

```
Error: Database is uninitialized and superuser password is not specified.
       You must specify POSTGRES_PASSWORD to a non-empty value for the
       superuser. For example, "-e POSTGRES_PASSWORD=password" on "docker run".
```

**Root cause:** Hummingbird's `postgresql:18` is built on the **upstream
Postgres** entrypoint conventions, not Red Hat's sclorg conventions.
The two ecosystems use different environment variable names for the
same thing:

| Variable purpose | Upstream Postgres (Hummingbird uses these) | sclorg (rhscl, what Red Hat traditionally used) |
|---|---|---|
| Initial superuser | `POSTGRES_USER` | `POSTGRESQL_USER` |
| Password | `POSTGRES_PASSWORD` | `POSTGRESQL_PASSWORD` |
| Database name | `POSTGRES_DB` | `POSTGRESQL_DATABASE` |

If you're coming from `registry.redhat.io/rhscl/postgresql-*` or
`registry.access.redhat.com/rhscl/postgresql-*`, you've internalized
the `POSTGRESQL_*` names. Hummingbird went the other direction.

**Fix:** Use the upstream names in compose.yaml or `podman run -e`:

```yaml
services:
  db:
    image: ${HB_REGISTRY:-quay.io/hummingbird}/postgresql:18
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: appsecret
      POSTGRES_DB: appdb
```

Once the data directory has been initialized, the env vars are only
consulted by the entrypoint to create roles and databases on first
boot — subsequent boots ignore them. So if you swap names on a
container that already initialized with the old names, you'll get
"database does not exist" errors instead. Easiest recovery is to
delete the volume (`podman-compose down -v`) and start fresh.

### Healthcheck commands that don't exist

**Symptom:** `podman-compose up` reports a service stuck in `unhealthy`,
or healthchecks never succeed even though the service is reachable.

**Root cause:** Healthcheck commands assume utilities that aren't in
distroless runtimes:

```yaml
# Wrong — /bin/test doesn't exist in distroless
healthcheck:
  test: ["CMD", "/bin/test", "-f", "/proc/1/cmdline"]
```

**Fix:** Use a tool that's actually in the image. For Node.js
runtimes, `node` itself is reliably present:

```yaml
healthcheck:
  test: ["CMD", "node", "-e",
    "require('http').get('http://localhost:3000', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]
  interval: 5s
  timeout: 5s
  retries: 30
  start_period: 30s
```

Same idea for other runtimes — use the language interpreter that's
guaranteed to be in the image, not a coreutils binary.

For databases, the database's own client is usually there. PostgreSQL
ships `pg_isready` in most distributions including (presumably)
Hummingbird's `postgresql:18` — that's worth verifying as part of your
testing matrix rather than assuming.

## When Hummingbird isn't the right runtime

The patterns above will get you a long way — most workloads can run on
Hummingbird with a small accommodation list. But there's a point where
the accommodation list itself becomes the problem.

The failure mode looks like this. You're shipping a SciPy-heavy data
science service. Your Containerfile starts to look like:

```dockerfile
FROM ${HB_REGISTRY}/python:3.13
COPY --from=builder /usr/lib64/libstdc++.so.6* /usr/lib64/
COPY --from=builder /usr/lib64/libgcc_s.so.1*  /usr/lib64/
COPY --from=builder /usr/lib64/libgomp.so.1*   /usr/lib64/
COPY --from=builder /usr/lib64/libgfortran.so.5* /usr/lib64/
COPY --from=builder /usr/lib64/libquadmath.so.0* /usr/lib64/
COPY --from=builder /usr/lib64/libffi.so.7*    /usr/lib64/
COPY --from=builder /usr/lib64/libxml2.so.2*   /usr/lib64/
COPY --from=builder /usr/lib64/libxslt.so.1*   /usr/lib64/
COPY --from=builder /usr/lib64/libssh2.so.1*   /usr/lib64/
COPY --from=builder /usr/lib64/libpsl.so.5*    /usr/lib64/
# ... and so on
```

At this point you've recreated about a third of UBI's userspace, by
hand, with the maintenance burden of tracking which libraries are
needed as you add packages. The CVE-surface argument for using
Hummingbird is undermined: you're shipping all those libraries; they
have CVEs; nothing's auditing the set you assembled. UBI ships the
same set with version coordination and CVE tracking from Red Hat.

The honest engineering answer is to match the runtime to the workload:

- **Use Hummingbird** when your image is Python with a few dependencies,
  or a Go static binary, or a Java JVM app. The CVE-minimization
  benefit is real and the accommodation list is short.
- **Consider UBI** when the accommodation list passes ~5 shared
  libraries, or when you're including a domain that brings significant
  native dependencies (heavy NumPy/SciPy/pandas, ML inference,
  bioinformatics, image processing). At that point UBI's
  out-of-the-box completeness is worth more than the CVE delta.
- **Mix freely.** The Quarkus example in this tutorial uses UBI's
  `openjdk-21` for the builder (because Hummingbird's builder doesn't
  ship Maven) and Hummingbird's `openjdk:21-runtime` for the deploy
  image (because that's what reaches production and CVE surface
  matters there). That pattern — UBI where breadth helps, Hummingbird
  where minimalism helps — is the most common shape in practice.

There's no shame in the call to use UBI for an ML workload. Hummingbird
isn't a moral position; it's a tool that's exceptional for some
workloads and a poor fit for others. Knowing the line is more
valuable than picking a side.

## A complete reference Containerfile

This is the Containerfile from the [ML example](https://github.com/patterncatalyst/hummingbird-tutorial/blob/main/examples/ml-example/Containerfile),
annotated with which gotcha each line addresses. It's a useful
cheat-sheet for assembling new Python-on-Hummingbird projects.

```dockerfile
ARG HB_REGISTRY=quay.io/hummingbird

# ── Stage 1 ─────────────────────────────────────────────────────────────────
FROM ${HB_REGISTRY}/python:3.13-builder AS builder

USER 1001
WORKDIR /build

# Sets HOME so pip's ~/.cache resolves to a writable path.
ENV HOME=/build PIP_NO_CACHE_DIR=1

COPY --chown=1001:1001 requirements.txt .

# --prefix=/build/install instead of /install — UID 1001 owns /build.
RUN pip wheel --wheel-dir /build/wheels -r requirements.txt && \
    pip install --no-index --find-links=/build/wheels --prefix=/build/install \
        /build/wheels/*.whl

COPY --chown=1001:1001 app/ /build/app/

# ── Stage 2 ─────────────────────────────────────────────────────────────────
# Distroless. No /bin/sh — only COPY past this point.
FROM ${HB_REGISTRY}/python:3.13
WORKDIR /app

# /build/install copies into /usr/local. Python finds packages here.
COPY --from=builder /build/install /usr/local
COPY --from=builder --chown=1001:1001 /build/app /app/app

# C++ runtime. Required for any package with C++-compiled extensions.
COPY --from=builder /usr/lib64/libstdc++.so.6* /usr/lib64/
COPY --from=builder /usr/lib64/libgcc_s.so.1*  /usr/lib64/
# OpenMP runtime. Needed by NumPy's BLAS for parallel ops.
COPY --from=builder /usr/lib64/libgomp.so.1*   /usr/lib64/

# Cover both lib and lib64 — RHEL splits pure-Python and C-extension
# packages across them, and the runtime's default sys.path may miss one.
ENV PYTHONPATH=/usr/local/lib/python3.13/site-packages:/usr/local/lib64/python3.13/site-packages

USER 1001
EXPOSE 8000

# python3, not python — distroless drops the alias.
CMD ["python3", "-m", "uvicorn", "app.main:app", \
     "--host", "0.0.0.0", "--port", "8000"]
```

## Where to go next

If you're hitting an issue not on this list, the
[reconciliation plan](../../plans/reconciliation-plan/) tracks every
verified fact and outstanding question about the tutorial's contents.
The plan's testing matrix in §G is also a record of what's been built
and run end-to-end versus what's still on faith.

Each gotcha here is also annotated in the relevant Containerfile
inline, so future readers can find the explanation at the point of
need rather than having to come back to this page.

If you have an additional gotcha worth adding, the format is intended
to be straightforward — symptom, root cause, fix — and the source for
this page is in [`_docs/17-distroless-gotchas.md`](https://github.com/patterncatalyst/hummingbird-tutorial/blob/main/_docs/17-distroless-gotchas.md).
