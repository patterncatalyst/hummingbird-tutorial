#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
SVGDIR="../../assets/diagrams"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp "$SVGDIR"/*.svg "$TMP"/
( cd "$TMP" && soffice --headless --convert-to pdf --outdir . ./*.svg >/dev/null 2>&1 )
mkdir -p png
for pdf in "$TMP"/*.pdf; do
  name="$(basename "${pdf%.pdf}")"
  pdftoppm -png -r 200 "$pdf" "$TMP/p_${name}" >/dev/null 2>&1
  src="$(ls "$TMP/p_${name}"*.png | head -1)"
  convert "$src" -background white -flatten -trim +repage -bordercolor white -border 24 "png/${name}.png"
  echo "  png/${name}.png"
done
