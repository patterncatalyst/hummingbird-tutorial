#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"; export NODE_PATH="$(npm root -g)"; node deck.js
