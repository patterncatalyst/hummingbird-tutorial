#!/usr/bin/env bash
# Runs all three remaining example tests end-to-end.
# Designed to be run from the repo root: `bash test-remaining.sh`
#
# Each test:
#   1. Builds the image
#   2. (For go and ml) runs the container, hits the endpoint, tears down
#   3. (For compose) brings up the stack, checks all three services, brings down
#
# Exits non-zero on first failure. Intended for one-shot copy-paste.

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${YELLOW}━━ $1${NC}"; }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# ── Test 1: Go ──────────────────────────────────────────────────────────────
info "TEST 1/3: Go example"
cd examples/go-example
podman build -t hb-test-go . || fail "Go build failed"
pass "Go build succeeded"

podman rm -f hb-test-go-run 2>/dev/null || true
podman run -d --name hb-test-go-run -p 18081:8080 hb-test-go
sleep 2
RESP=$(curl -fsSL http://localhost:18081/ || true)
podman stop hb-test-go-run >/dev/null
podman rm hb-test-go-run >/dev/null

[[ "$RESP" == *'"status":"ok"'* ]] && pass "Go runtime responds: $RESP" \
  || fail "Go runtime didn't return expected JSON. Got: $RESP"

cd "$REPO_ROOT"

# ── Test 2: ML ──────────────────────────────────────────────────────────────
info "TEST 2/3: ML example"
cd examples/ml-example
podman build -t hb-test-ml . || fail "ML build failed"
pass "ML build succeeded"

podman rm -f hb-test-ml-run 2>/dev/null || true
podman run -d --name hb-test-ml-run -p 18082:8000 hb-test-ml
sleep 4   # FastAPI startup is slower than a bare Go listener
RESP=$(curl -fsSL http://localhost:18082/ || true)
podman stop hb-test-ml-run >/dev/null
podman rm hb-test-ml-run >/dev/null

[[ "$RESP" == *'"status":"ok"'* ]] && pass "ML runtime responds: $RESP" \
  || fail "ML runtime didn't return expected JSON. Got: $RESP"

cd "$REPO_ROOT"

# ── Test 3: Compose stack ───────────────────────────────────────────────────
info "TEST 3/3: Compose stack"
cd examples/compose-stack

# Tear down any previous run before starting.
podman-compose down -v 2>/dev/null || true

podman-compose up -d --build || fail "compose up failed"
pass "compose up succeeded"

# Wait for web to be healthy (compose's own healthcheck handles db→web wait).
echo "Waiting up to 60s for web tier to start responding..."
for i in $(seq 1 30); do
  if curl -fsSL http://localhost:3000/ >/dev/null 2>&1; then break; fi
  sleep 2
done

RESP=$(curl -fsSL http://localhost:3000/ || true)
[[ "$RESP" == *'"status":"ok"'* ]] && pass "web tier responds: $RESP" \
  || { podman-compose logs --tail=50 web; fail "web didn't return expected JSON. Got: $RESP"; }

# Test db is queryable.
DB_CONTAINER=$(podman ps --format '{{.Names}}' | grep -E 'compose-stack[_-]db' | head -1)
if [[ -z "$DB_CONTAINER" ]]; then
  fail "couldn't find db container"
fi
DB_RESULT=$(podman exec "$DB_CONTAINER" psql -U app -d appdb -tAc 'select 42' 2>&1 || true)
[[ "$DB_RESULT" == *"42"* ]] && pass "db queryable: $DB_RESULT" \
  || fail "db query failed. Got: $DB_RESULT"

# Tear down.
podman-compose down -v
pass "compose stack torn down"

cd "$REPO_ROOT"

echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  All 3 remaining example tests passed.${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
