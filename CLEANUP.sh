#!/usr/bin/env bash
set -euo pipefail

# Remove the resurrected docs/ and plans/ directories that I incorrectly
# created. Files in _docs/ and _plans/ are the real ones.

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

if [ -d docs ]; then
  echo "Removing resurrected docs/ directory..."
  git rm -r docs 2>/dev/null || rm -rf docs
fi

if [ -d plans ]; then
  echo "Removing resurrected plans/ directory..."
  git rm -r plans 2>/dev/null || rm -rf plans
fi

echo ""
echo "=== verifying _docs/ contents ==="
ls _docs/ | wc -l
echo "=== verifying _plans/ contents ==="
ls _plans/

echo ""
echo "=== sanity: §8 has the SYS_PTRACE / in-image debug content ==="
grep -c "in-image debug" _docs/08-debugging.md

echo ""
echo "Done. Now: git add -A && git commit && git push"
