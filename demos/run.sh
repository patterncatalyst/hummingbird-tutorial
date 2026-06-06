#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — launcher for the Hummingbird command-line demos.
#
#   ./demos/run.sh             # interactive menu
#   ./demos/run.sh 3           # run demo 3 only
#   ./demos/run.sh all         # the full walkthrough, in order
#   ./demos/run.sh list        # list the demos
#   ./demos/run.sh check       # preflight: tools + registry settings
#
# Each demo is also runnable on its own, e.g.  ./demos/03-compare-nonminimal.sh
# Runs fine from a zsh prompt — the scripts use a bash shebang.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail
DEMOS="$(cd "$(dirname "$0")" && pwd)"
source "$DEMOS/lib/_demo.sh"

mapfile -t FILES < <(ls "$DEMOS"/[0-9][0-9]-*.sh 2>/dev/null | sort)

_label() {  # pull the "Demo N — …" summary from line 2 of a demo file
    sed -n '2s/^# //p' "$1"
}

list() {
    echo
    printf '%b\n' "${BOLD}Hummingbird command-line demos${NC}"
    echo
    local i f
    for i in "${!FILES[@]}"; do
        f="${FILES[$i]}"
        printf "  ${BOLD}%d${NC}  %s\n" "$((i+1))" "$(_label "$f")"
    done
    echo
}

check() {
    echo
    printf '%b\n' "${BOLD}Preflight${NC}"
    echo
    printf '%b\n' "  ${BOLD}Registry settings${NC} (override via env before launching):"
    printf "    HB_REGISTRY   = %s\n" "$HB_REGISTRY"
    printf "    RH_REGISTRY   = %s\n" "$RH_REGISTRY"
    printf "    RHHI_REGISTRY = %s\n" "$RHHI_REGISTRY"
    printf "    FAT_IMAGE     = %s\n" "$FAT_IMAGE"
    echo
    printf '%b\n' "  ${BOLD}Tools${NC}:"
    local t
    for t in podman skopeo jq syft grype cosign curl; do
        if command -v "$t" >/dev/null 2>&1; then
            printf "    ${GREEN}✓${NC} %-8s %s\n" "$t" "$(command -v "$t")"
        else
            printf "    ${RED}✗${NC} %-8s ${DIM}(missing — see _docs/01-prerequisites.md)${NC}\n" "$t"
        fi
    done
    echo
    say "Tip: pre-pull the images before a talk so nothing stalls on the room's \
wifi — e.g. podman pull $HB_REGISTRY/curl:latest $HB_REGISTRY/nginx:1 \
$HB_REGISTRY/python:3.13 $HB_REGISTRY/go:1.26 $HB_REGISTRY/postgresql:18 \
$RH_REGISTRY/ubi9/toolbox:latest $FAT_IMAGE"
    echo
    say "Also refresh the scanner DB ahead of time (Grype refuses a stale DB): \
grype db update. Notes: demo 5's offline signing needs cosign v3 flags \
(handled in-script); demo 7's Trusted Libraries index is gated and returns \
HTTP 401 unless you're enrolled in the Tech Preview and authenticated."
    echo
}

run_one() {  # $1 = 1-based index
    local idx=$(( $1 - 1 )) f
    if (( idx < 0 || idx >= ${#FILES[@]} )); then
        printf '%b\n' "${RED}No demo numbered $1.${NC} Try: ./demos/run.sh list"
        return 1
    fi
    f="${FILES[$idx]}"
    bash "$f"
}

walkthrough() {
    echo
    printf '%b\n' "${BOLD}${MAGENTA}Full walkthrough — ${#FILES[@]} demos, in order.${NC}"
    say "Each demo stops between steps and again before the next one begins. \
Press Enter to advance; Ctrl-C to bail out at any point."
    pause
    local n
    for n in $(seq 1 "${#FILES[@]}"); do
        run_one "$n"
    done
    echo
    printf '%b\n' "${BOLD}${GREEN}That's the set. Thanks for following along.${NC}"
    echo
}

menu() {
    while true; do
        list
        printf '%b' "  ${BOLD}Pick a number, ${NC}a${BOLD} for all, ${NC}c${BOLD} to check, ${NC}q${BOLD} to quit:${NC} "
        IFS= read -r choice </dev/tty 2>/dev/null || choice="q"
        case "$choice" in
            [1-9]|[1-9][0-9]) run_one "$choice" ;;
            a|A|all)          walkthrough ;;
            c|C|check)        check ;;
            q|Q|quit|exit|"") echo; break ;;
            *) printf '%b\n' "  ${YELLOW}Didn't catch that.${NC}" ;;
        esac
    done
}

case "${1:-menu}" in
    menu)            menu ;;
    list|ls)         list ;;
    check|preflight) check ;;
    all|a)           walkthrough ;;
    [0-9]*)          run_one "$1" ;;
    -h|--help|help)  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) printf '%b\n' "${RED}Unknown argument: $1${NC}"; sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
