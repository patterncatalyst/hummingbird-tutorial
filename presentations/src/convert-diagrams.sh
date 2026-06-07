#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
SVGDIR="../../assets/diagrams"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp "$SVGDIR"/*.svg "$TMP"/; ( cd "$TMP" && soffice --headless --convert-to pdf --outdir . ./*.svg >/dev/null 2>&1 )
mkdir -p png
for pdf in "$TMP"/*.pdf; do n="$(basename "${pdf%.pdf}")"; pdftoppm -png -r 200 "$pdf" "$TMP/p_${n}" >/dev/null 2>&1
  convert "$(ls "$TMP/p_${n}"*.png | head -1)" -background white -flatten -trim +repage -bordercolor white -border 24 "png/${n}.png"; done
