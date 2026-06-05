#!/usr/bin/env bash
# Rebuild the deck. Requires Node + pptxgenjs (npm i -g pptxgenjs if missing).
set -euo pipefail
cd "$(dirname "$0")"
export NODE_PATH="$(npm root -g)"
node deck.js
