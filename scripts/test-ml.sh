#!/usr/bin/env bash
# Test the ML example end-to-end: build → run → curl → teardown.
# Slower than the others — NumPy wheels can take a minute to install.

set -euo pipefail
source "$(dirname "$0")/lib/_helpers.sh"

EXAMPLE="ml-example"
IMAGE="hb-test-ml"
CONTAINER="hb-test-ml-run"
HOST_PORT=18084
CONTAINER_PORT=8000

cd "$(repo_root)/examples/$EXAMPLE"
trap "cleanup_container $CONTAINER" EXIT

step "Building $EXAMPLE (slow first time — NumPy wheel)"
podman build -t "$IMAGE" . >/dev/null || fail "$EXAMPLE: build failed"
pass "$EXAMPLE built"

step "Running $EXAMPLE on :$HOST_PORT"
cleanup_container "$CONTAINER"
podman run -d --name "$CONTAINER" -p "$HOST_PORT:$CONTAINER_PORT" "$IMAGE" >/dev/null

step "Waiting for FastAPI + NumPy to start"
if ! wait_for_http "http://127.0.0.1:$HOST_PORT/" 30; then
    info "Container logs:"
    podman logs "$CONTAINER" 2>&1 | tail -20 | sed 's/^/  /'
    fail "$EXAMPLE: never started responding on :$HOST_PORT"
fi

RESP=$(curl -fsS "http://127.0.0.1:$HOST_PORT/")
case "$RESP" in
    *'"status":"ok"'*'"matrix_sum":3.0'*) pass "$EXAMPLE responds: $RESP" ;;
    *) fail "$EXAMPLE: unexpected response: $RESP" ;;
esac
