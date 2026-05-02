#!/usr/bin/env bash
# Run every example test in sequence. Reports per-test pass/fail and
# prints a final summary. Does NOT fail-fast — every test runs even if
# earlier ones fail, so you see all problems at once.

source "$(dirname "$0")/lib/_helpers.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Order: fastest to slowest, so failures surface quickly.
TESTS=(
    test-go.sh
    test-node.sh
    test-quarkus.sh
    test-python.sh
    test-ml.sh
    test-compose-stack.sh
)

declare -a PASSED FAILED
START=$(date +%s)

for t in "${TESTS[@]}"; do
    echo
    echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  $t${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
    if bash "$SCRIPT_DIR/$t"; then
        PASSED+=("$t")
    else
        FAILED+=("$t")
    fi
done

ELAPSED=$(( $(date +%s) - START ))

echo
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Summary${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════${NC}"
echo
for t in "${PASSED[@]}"; do echo -e "  ${GREEN}✓${NC} $t"; done
for t in "${FAILED[@]}"; do echo -e "  ${RED}✗${NC} $t"; done
echo
echo "  Passed: ${#PASSED[@]} / ${#TESTS[@]}     (elapsed: ${ELAPSED}s)"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "${RED}${BOLD}  ${#FAILED[@]} test(s) failed.${NC}"
    exit 1
fi

echo -e "${GREEN}${BOLD}  All tests passed.${NC}"
