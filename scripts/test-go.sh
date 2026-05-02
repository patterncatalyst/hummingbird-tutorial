#!/usr/bin/env bash
# Test the Go example end-to-end: build → run → curl → teardown.

set -euo pipefail
source "$(dirname "$0")/lib/_helpers.sh"

EXAMPLE="go-example"
IMAGE="hb-test-go"
CONTAINER="hb-test-go-run"
HOST_PORT=18082
CONTAINER_PORT=8080

cd "$(repo_root)/examples/$EXAMPLE"
trap "cleanup_container $CONTAINER" EXIT

step "Building $EXAMPLE"
podman build -t "$IMAGE" . >/dev/null || fail "$EXAMPLE: build failed"
pass "$EXAMPLE built"

step "Running $EXAMPLE on :$HOST_PORT"
cleanup_container "$CONTAINER"
podman run -d --name "$CONTAINER" -p "$HOST_PORT:$CONTAINER_PORT" "$IMAGE" >/dev/null

step "Waiting for HTTP response"
if ! wait_for_http "http://127.0.0.1:$HOST_PORT/" 15; then
    info "Container logs:"
    podman logs "$CONTAINER" 2>&1 | tail -20 | sed 's/^/  /'
    fail "$EXAMPLE: never started responding on :$HOST_PORT"
fi

RESP=$(curl -fsS "http://127.0.0.1:$HOST_PORT/")
case "$RESP" in
    *'"status":"ok"'*) pass "$EXAMPLE responds: $RESP" ;;
    *) fail "$EXAMPLE: unexpected response: $RESP" ;;
esac
