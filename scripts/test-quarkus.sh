#!/usr/bin/env bash
# Test the Quarkus example end-to-end: build → run → curl → teardown.
# Returns 0 on success, non-zero on any failure. Tears down the test
# container even if curl fails. Safe to re-run.

set -euo pipefail
source "$(dirname "$0")/lib/_helpers.sh"

EXAMPLE="quarkus-example"
IMAGE="hb-test-quarkus"
CONTAINER="hb-test-quarkus-run"
HOST_PORT=18080
CONTAINER_PORT=8080

cd "$(repo_root)/examples/$EXAMPLE"
trap "cleanup_container $CONTAINER" EXIT

step "Building $EXAMPLE"
podman build -t "$IMAGE" . >/dev/null || fail "$EXAMPLE: build failed"
pass "$EXAMPLE built"

step "Running $EXAMPLE on :$HOST_PORT"
cleanup_container "$CONTAINER"
podman run -d --name "$CONTAINER" -p "$HOST_PORT:$CONTAINER_PORT" "$IMAGE" >/dev/null

step "Waiting for HTTP response (Quarkus needs ~5s to boot)"
if ! wait_for_http "http://127.0.0.1:$HOST_PORT/" 30; then
    info "Container logs:"
    podman logs "$CONTAINER" 2>&1 | tail -20 | sed 's/^/  /'
    fail "$EXAMPLE: never started responding on :$HOST_PORT"
fi

RESP=$(curl -fsS "http://127.0.0.1:$HOST_PORT/")
case "$RESP" in
    *'"status":"ok"'*) pass "$EXAMPLE responds: $RESP" ;;
    *) fail "$EXAMPLE: unexpected response: $RESP" ;;
esac
