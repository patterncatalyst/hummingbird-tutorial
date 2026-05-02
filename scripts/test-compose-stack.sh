#!/usr/bin/env bash
# Test the compose-stack end-to-end: bring up all three services
# (db, otel, web), confirm web responds, confirm db is queryable,
# tear down. Requires podman-compose.

set -euo pipefail
source "$(dirname "$0")/lib/_helpers.sh"

cd "$(repo_root)/examples/compose-stack"
trap "podman-compose down -v >/dev/null 2>&1 || true" EXIT

step "Bringing down any previous run"
podman-compose down -v >/dev/null 2>&1 || true

step "Building and starting compose stack"
podman-compose up -d --build >/dev/null 2>&1 \
    || fail "compose-stack: 'compose up' failed"
pass "compose stack started"

step "Waiting up to 60s for web tier to respond"
if ! wait_for_http "http://127.0.0.1:3000/" 60; then
    info "Web logs:"
    podman-compose logs --tail=30 web 2>&1 | sed 's/^/  /'
    info "DB logs:"
    podman-compose logs --tail=10 db 2>&1 | sed 's/^/  /'
    fail "compose-stack: web tier never responded"
fi

RESP=$(curl -fsS "http://127.0.0.1:3000/")
case "$RESP" in
    *'"status":"ok"'*) pass "web responds: $RESP" ;;
    *) fail "compose-stack: unexpected web response: $RESP" ;;
esac

step "Querying database"
DB_CONTAINER=$(podman ps --format '{{.Names}}' | grep -E 'compose[-_]stack[-_]db' | head -1)
if [[ -z "$DB_CONTAINER" ]]; then
    fail "compose-stack: couldn't find db container"
fi
DB_RESULT=$(podman exec "$DB_CONTAINER" psql -U app -d appdb -tAc 'select 42' 2>&1 || true)
case "$DB_RESULT" in
    *42*) pass "db queryable: $DB_RESULT" ;;
    *) fail "compose-stack: db query failed: $DB_RESULT" ;;
esac
