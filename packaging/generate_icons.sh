#!/usr/bin/env bash
# Gera PNGs a partir do SVG (menu KDE/Plasma costuma precisar de tamanhos fixos em hicolor).
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="${RAIZ}/data/icons/hicolor/scalable/apps/org.agildosoft.agildodock.svg"
command -v rsvg-convert >/dev/null || { echo 'Instala librsvg (rsvg-convert).'; exit 1; }
for s in 16 22 24 32 48 64 128 256; do
  d="${RAIZ}/data/icons/hicolor/${s}x${s}/apps"
  mkdir -p "$d"
  rsvg-convert -w "$s" -h "$s" -o "$d/org.agildosoft.agildodock.png" "$SVG"
done
echo 'PNGs gerados em data/icons/hicolor/*/apps/'
