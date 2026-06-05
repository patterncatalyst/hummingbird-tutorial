#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# _demo.sh — shared presentation engine for the Hummingbird command-line demos.
#
# Source this from each demos/NN-*.sh. It provides:
#   • the narrate → stop → run rhythm used throughout the presentation,
#   • colour/formatting helpers,
#   • registry shortcuts (HB_REGISTRY / RH_REGISTRY / RHHI_REGISTRY),
#   • tool-availability checks that SKIP gracefully instead of crashing, and
#   • automatic cleanup of containers / images / temp dirs on exit.
#
# Design goal: a live demo must never die on stage. Commands that touch the
# network or a registry are run "soft" — a failure prints an explanation and
# the show goes on. The only hard rule is: keep talking, keep moving.
#
# Not meant to be executed directly.
# ─────────────────────────────────────────────────────────────────────────────

# No `set -e`: expected-failure demos (the gotchas) return non-zero on purpose,
# and a flaky pull must not abort the talk. We manage exit codes by hand.
set -uo pipefail

# ── Colours (auto-disabled when stdout isn't a tty) ─────────────────────────
if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'; RED=$'\033[0;31m';  YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m';  BLUE=$'\033[0;34m'; MAGENTA=$'\033[0;35m'
    BOLD=$'\033[1m';     DIM=$'\033[2m';     NC=$'\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; CYAN=''; BLUE=''; MAGENTA=''
    BOLD=''; DIM=''; NC=''
fi

# ── Registry shortcuts ──────────────────────────────────────────────────────
# Same names the tutorial's prerequisites set, so an admin who has sourced
# their rc already has these. Override any of them before launching a demo,
# e.g.  HB_REGISTRY=quay.io/hummingbird-hatchling ./demos/run.sh 1
: "${HB_REGISTRY:=quay.io/hummingbird}"               # hardened images (no sub needed)
: "${RH_REGISTRY:=registry.access.redhat.com}"        # UBI, toolbox
: "${RHHI_REGISTRY:=registry.access.redhat.com/hi}"   # signed Red Hat path
: "${RH_COSIGN_KEY:=https://security.access.redhat.com/data/63405576.txt}"
: "${FAT_IMAGE:=docker.io/library/nginx:latest}"      # non-minimal comparison
export HB_REGISTRY RH_REGISTRY RHHI_REGISTRY RH_COSIGN_KEY FAT_IMAGE

# Set DEMO_NO_PAUSE=1 to auto-advance (handy for a dry run / recording).
: "${DEMO_NO_PAUSE:=}"

_WIDTH=74
_RULE_CHAR='─'

_rule() { local n="${1:-70}"; printf '%b' "${DIM}"; printf "${_RULE_CHAR}%.0s" $(seq 1 "$n"); printf '%b\n' "${NC}"; }

# ── Cleanup bookkeeping ─────────────────────────────────────────────────────
declare -a _DEMO_CONTAINERS=()
declare -a _DEMO_IMAGES=()
DEMO_TMPDIR=""

track()       { _DEMO_CONTAINERS+=("$1"); }       # a container to rm -f on exit
track_image() { _DEMO_IMAGES+=("$1"); }           # an image to rmi on exit

_demo_cleanup() {
    local c
    for c in "${_DEMO_CONTAINERS[@]:-}"; do
        [[ -n "$c" ]] && podman rm -f "$c" >/dev/null 2>&1 || true
    done
    for c in "${_DEMO_IMAGES[@]:-}"; do
        [[ -n "$c" ]] && podman rmi -f "$c" >/dev/null 2>&1 || true
    done
    [[ -n "$DEMO_TMPDIR" && -d "$DEMO_TMPDIR" ]] && rm -rf "$DEMO_TMPDIR" 2>/dev/null || true
}

# Make a scratch dir the demo can build Containerfiles in. Sets the global
# DEMO_TMPDIR (cleaned up on exit). Call it directly, NOT in a $() subshell —
# a subshell can't set the parent's global, which would defeat cleanup:
#     demo_tmpdir; TMP="$DEMO_TMPDIR"
demo_tmpdir() { DEMO_TMPDIR="$(mktemp -d /tmp/hbdemo.XXXXXX)"; printf '%s\n' "$DEMO_TMPDIR"; }

# ── Narration ───────────────────────────────────────────────────────────────

# Big banner that opens a demo. Installs the cleanup trap.
# Usage: demo_title 1 "Pull and inspect a hardened image"
demo_title() {
    local n="$1"; shift
    local title="$*"
    trap _demo_cleanup EXIT
    echo
    printf '%b\n' "${BOLD}${MAGENTA}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    printf '%b\n' "${BOLD}${MAGENTA}║${NC}  ${BOLD}DEMO ${n}${NC}  ·  ${BOLD}${title}${NC}"
    printf '%b\n' "${BOLD}${MAGENTA}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# A short overview paragraph shown right after the title.
demo_intro() { say "$@"; pause; }

# Step header.  Usage: section "Step 1 — Pull the image"
section() {
    echo
    printf '%b\n' "${BOLD}${CYAN}━━ $* ${NC}"
}

# Explanatory prose, soft-wrapped to a readable width.
say() {
    echo
    printf '%s\n' "$*" | fold -s -w "$_WIDTH" | sed 's/^/  /'
}

note()   { echo; printf '%b\n' "  ${YELLOW}▸ $*${NC}"; }
caution(){ echo; printf '%b\n' "  ${RED}⚠ $*${NC}"; }
watch()  { echo; printf '%b\n' "  ${BLUE}👀 Watch for:${NC} $*"; }
good()   { printf '%b\n' "  ${GREEN}✓ $*${NC}"; }

# An explicit stop. The audience reads what's on screen; presenter narrates;
# hit Enter to move on. Clearly delineated by a rule.
pause() {
    [[ -n "$DEMO_NO_PAUSE" ]] && { echo; return 0; }
    echo
    _rule 70
    printf '%b' "  ${DIM}▸ press ${NC}${BOLD}Enter${NC}${DIM} to continue${NC}  "
    IFS= read -r _ </dev/tty 2>/dev/null || true
    echo
}

# ── Running commands ────────────────────────────────────────────────────────
# Each runner shows the command first, STOPS (so you can talk over it), then
# executes. Output streams live. Nothing here aborts the script.

_show_cmd() { echo; printf '%b\n' "  ${BOLD}${GREEN}\$ $1${NC}"; }

_stop_then_run() {
    [[ -n "$DEMO_NO_PAUSE" ]] || {
        printf '%b' "  ${DIM}▸ ${NC}${BOLD}Enter${NC}${DIM} to run${NC}  "
        IFS= read -r _ </dev/tty 2>/dev/null || true
    }
    echo
}

# Normal step. Non-zero exit is reported but does not stop the demo.
run() {
    local cmd="$1"
    _show_cmd "$cmd"
    _stop_then_run
    eval "$cmd"
    local rc=$?
    [[ $rc -ne 0 ]] && printf '%b\n' "  ${DIM}(command exited ${rc})${NC}"
    return 0
}

# A command we EXPECT to fail (the no-shell / gotcha moments). A non-zero
# exit is the teaching point and is reported as success.
run_fail() {
    local cmd="$1"
    _show_cmd "$cmd"
    _stop_then_run
    eval "$cmd"
    local rc=$?
    echo
    if [[ $rc -ne 0 ]]; then
        good "…and it failed exactly as expected (exit ${rc}). That's the point."
    else
        note "Huh — that succeeded (exit 0). Worth a look; the catalog evolves."
    fi
    return 0
}

# Network/registry/verify step that may not be reachable from the room. A
# failure degrades to a friendly note and the talk continues.
run_soft() {
    local cmd="$1"
    _show_cmd "$cmd"
    _stop_then_run
    eval "$cmd"
    local rc=$?
    echo
    if [[ $rc -ne 0 ]]; then
        note "That step didn't complete (exit ${rc}) — often a network, registry-auth,"
        printf '%b\n' "    ${YELLOW}  or signing-infra hiccup. The explanation above is what matters here.${NC}"
    fi
    return 0
}

# ── Tool checks ─────────────────────────────────────────────────────────────
# Returns 0 if all present; otherwise prints what's missing and returns 1 so
# the caller can SKIP the demo (exit 0) rather than crash mid-presentation.
require_tools() {
    local missing=() t
    for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
    if (( ${#missing[@]} )); then
        caution "Skipping — these tools aren't on PATH: ${missing[*]}"
        say "Install them first (see _docs/01-prerequisites.md), then re-run this demo."
        return 1
    fi
    return 0
}

# ── Demo closer ─────────────────────────────────────────────────────────────
# Recap line(s) + the deliberate stop BEFORE the next demo.
demo_end() {
    echo
    printf '%b\n' "  ${BOLD}${MAGENTA}── end of demo ─────────────────────────────────────────────────────${NC}"
    [[ $# -gt 0 ]] && say "$@"
    pause
}
