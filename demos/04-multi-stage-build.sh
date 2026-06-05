#!/usr/bin/env bash
# Demo 4 — Multi-stage build: toolchain in the builder, binary on the runtime.
#          the artifact on a Hummingbird *runtime* image. Uses the repo's
#          examples/go-example so the audience sees real, verified code.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib/_demo.sh"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

demo_title 4 "Multi-stage builds — toolchain in the builder, binary on the runtime"
require_tools podman || exit 0

EX="$REPO_ROOT/examples/go-example"
IMG="hbdemo-go"
CTR="hbdemo-go-run"
PORT=18191
track "$CTR"; track_image "$IMG"

if [[ ! -f "$EX/Containerfile" ]]; then
    caution "Can't find $EX/Containerfile — run this from inside the repo."
    exit 0
fi

demo_intro "The canonical Hummingbird workflow has two stages. Stage 1 uses a \
'-builder' image — the language plus its compiler and package manager — to \
build your app. Stage 2 copies just the resulting artifact onto a minimal \
runtime image. Your production image inherits the small, hardened surface; \
the toolchain never ships. We'll build the repo's Go example end to end."

section "Step 1 — Read the Containerfile"
say "Two FROMs. Note the builder stage (go:…-builder) sets HOME/GOCACHE so \
UID 1001 has somewhere to write — a classic gotcha — and builds a static \
binary. The runtime stage is just COPY --from=builder; no RUN, no toolchain."
run "sed -n '1,60p' \"$EX/Containerfile\""

section "Step 2 — Build it"
say "We pass HB_REGISTRY through as a build-arg so it matches your environment."
run "podman build --build-arg HB_REGISTRY=\"$HB_REGISTRY\" -t $IMG \"$EX\""

section "Step 3 — Run the result and hit it"
run "podman run -d --name $CTR -p $PORT:8080 $IMG"
run "sleep 1; curl -s http://127.0.0.1:$PORT/ ; echo"

section "Step 4 — The toolchain did NOT come along"
say "The whole point: the Go compiler stayed in the builder. The runtime \
image has the binary and not much else. (The Go runtime image is one of the \
few in the catalog that DOES keep a shell — handy here to prove the \
toolchain is gone without bringing a sidecar.)"
run "podman run --rm $IMG sh -c 'echo \"go toolchain: \$(command -v go || echo ABSENT)\"; \
            echo \"the app:      \$(ls -1 /app/app 2>/dev/null || echo missing)\"'"

section "Step 5 — Builder vs runtime, by size"
say "The builder image is large — that's fine, it never reaches production. \
What ships is the runtime image plus your binary."
run "podman images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' \
      | grep -E \"go|$IMG\" | grep -Ev 'NONE'"

demo_end "Build-time gets the full toolchain; runtime gets only the binary on \
a hardened base. That separation is what keeps the deployed image's CVE \
surface tiny — which we'll prove with a scanner in demo 6. Next: the \
artifacts that travel WITH an image — SBOMs and signatures."
