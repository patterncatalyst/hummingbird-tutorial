#!/usr/bin/env bash
# Demo 8 — Distroless gotchas: the sharp edges, shown failing then fixed.
#          failing and then explained. Sourced from _docs/17-distroless-gotchas.md.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib/_demo.sh"

demo_title 8 "Distroless gotchas — the sharp edges, and how to round them off"
require_tools podman || exit 0

demo_intro "Minimalism is the feature, and it's also where every implicit \
assumption baked into the wider container ecosystem comes to surface. None \
of these are bugs — they're the absence of things you didn't know you were \
relying on. We'll trip each wire on purpose, then show the fix."

# ── Gotcha A: RUN in a distroless runtime stage ─────────────────────────────
section "Gotcha A — 'RUN' in a runtime stage: /bin/sh not found"
say "Buildah's RUN defaults to '/bin/sh -c …'. A distroless runtime has no \
shell, so the FIRST RUN in a runtime stage fails. Here's the trap:"
demo_tmpdir >/dev/null; TMP="$DEMO_TMPDIR"
run "printf 'FROM %s/curl:latest\nRUN echo hi\n' \"$HB_REGISTRY\" > \"$TMP/Containerfile.bad\"; cat \"$TMP/Containerfile.bad\""
run_fail "podman build -t hbdemo-bad -f \"$TMP/Containerfile.bad\" \"$TMP\""
say "Fix: do the work in a '-builder' stage and COPY the result into the \
runtime stage, which only ever takes COPY. (You saw a real multi-stage build \
do exactly this in demo 4.)"

# ── Gotcha B: not every distroless image is shell-free ──────────────────────
section "Gotcha B — the myth that ALL hardened images lack a shell"
say "It's the safe assumption, not a universal rule. curl is shell-free; a \
few images (Go, Core Runtime, full OpenJDK) DO keep a shell. Treating the \
rule as universal keeps your Containerfiles portable — but know the truth:"
run_fail "podman run --rm \"$HB_REGISTRY/curl:latest\" /bin/sh -c 'echo unreachable'"
run "podman run --rm \"$HB_REGISTRY/go:1.26\" sh -c 'echo \"the Go runtime image HAS a shell\"'"

# ── Gotcha C: python vs python3 ─────────────────────────────────────────────
section "Gotcha C — 'python: command not found'"
say "Distroless images drop convenience aliases full distros add for \
backwards compatibility. The bare 'python' symlink isn't there:"
run_fail "podman run --rm \"$HB_REGISTRY/python:3.13\" python --version"
say "Use the canonical name in CMD/ENTRYPOINT — 'python3', not 'python':"
run "podman run --rm \"$HB_REGISTRY/python:3.13\" python3 --version"

# ── Gotcha D: Postgres env var names ────────────────────────────────────────
section "Gotcha D — Postgres exits at startup with no password"
say "Hummingbird's postgresql follows UPSTREAM Postgres entrypoint \
conventions, not Red Hat's older sclorg ones. With no password it bails \
immediately:"
run_fail "podman run --rm \"$HB_REGISTRY/postgresql:18\""
say "If you've internalized POSTGRESQL_USER / POSTGRESQL_PASSWORD / \
POSTGRESQL_DATABASE (sclorg), switch to the upstream names: \
POSTGRES_USER / POSTGRES_PASSWORD / POSTGRES_DB. e.g."
note "podman run --rm -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=appdb $HB_REGISTRY/postgresql:18"

# ── Gotcha E: the IPv6 localhost reset (explain) ────────────────────────────
section "Gotcha E — 'Connection reset by peer' against a healthy container"
say "Your app logs a clean start, the container is 'running', yet 'curl \
http://localhost:PORT' resets. Modern resolvers try ::1 (IPv6) first; if \
your app bound 0.0.0.0 (IPv4 only), the forwarder accepts on ::1 and has \
nowhere to deliver. The container is fine — the test hit the wrong address \
family. Fix at the test layer: use 127.0.0.1 explicitly (that's why every \
demo here curls 127.0.0.1). Fix at the app layer: bind '::' for dual-stack."

# ── Gotcha F: when Hummingbird isn't the right runtime (explain) ────────────
section "Gotcha F — when a hardened runtime is the WRONG tool"
say "Native-extension stacks (heavy NumPy/SciPy/pandas, ML inference) need \
shared libraries the distroless runtime omits, so you start COPYing \
libstdc++, libgomp, libgfortran… one by one. Past ~5 of those you've \
hand-rebuilt a third of UBI's userland with no CVE tracking — undermining \
the very reason you reached for a hardened image. The honest call: use the \
hardened runtime for Go static binaries, JVM apps, and light Python; reach \
for UBI when the accommodation list gets long. Mixing per-stage is normal — \
the Quarkus example builds on UBI (for Maven) and deploys on a hardened JRE."

demo_end "Every gotcha here is an assumption made visible, not a defect. Know \
the handful — RUN needs a shell, aliases are gone, env-var dialects differ, \
localhost is dual-stack, and match the runtime to the workload — and \
hardened images stay boring in production, which is the whole point. \
Full catalogue of symptoms/causes/fixes lives in _docs/17-distroless-gotchas.md."
