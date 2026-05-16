#!/usr/bin/env bash
# Gera ../agildodock-VERSION.tar.gz com o estrutura exigido pelo PKGBUILD (pastas agildodock-VERSION/…).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VER="${1:-1.0}"
STAGE_PARENT="/tmp/agildodock-dist-$VER"
STAGED="$STAGE_PARENT/agildodock-$VER"
OUT="$ROOT/agildodock-$VER.tar.gz"

rm -rf "$STAGE_PARENT"
mkdir -p "$STAGED"

rsync -a \
  --exclude='/build' \
  --exclude='/.git' \
  --exclude='/.cursor' \
  --exclude='/agildodock-*.tar.gz' \
  "$ROOT/" "$STAGED/"

tar -C "$STAGE_PARENT" -czvf "$OUT" "agildodock-$VER"
echo "Pacote criado em: $OUT"
echo "Para empaquetar: cd packaging && cp '$OUT' . && makepkg -f"
