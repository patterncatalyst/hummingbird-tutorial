#!/usr/bin/env bash
# Shared helpers for the example-test scripts. Source this from each
# scripts/test-*.sh — handles colors, repo-root resolution, container
# cleanup. Not intended to be executed directly.

# ── Colors (auto-disabled when stdout isn't a tty) ──────────────────────────
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

step()  { echo -e "${CYAN}━━ $*${NC}"; }
pass()  { echo -e "${GREEN}✓ $*${NC}"; }
fail()  { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }
info()  { echo -e "${YELLOW}  $*${NC}"; }

# ── Repo-root resolution ────────────────────────────────────────────────────
# Falls back to the script's grandparent dir if we're outside a git checkout.
repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # scripts/lib/_helpers.sh -> scripts/ -> repo
        cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
    fi
}

# ── Container cleanup ───────────────────────────────────────────────────────
# Idempotent: removes a container if it exists, silent if not.
cleanup_container() {
    local name="$1"
    podman rm -f "$name" >/dev/null 2>&1 || true
}

# Wait up to N seconds for an HTTP endpoint to start responding.
# Returns 0 if it does, 1 if it doesn't. Use 127.0.0.1 (not localhost)
# to avoid IPv4/IPv6 dual-stack mismatch issues.
wait_for_http() {
    local url="$1"
    local timeout="${2:-30}"
    local i
    for ((i = 0; i < timeout; i++)); do
        if curl -fsS "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    return 1
}
