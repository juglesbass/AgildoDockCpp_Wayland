#!/bin/bash
# Script para preparar o pacote para submissão no AUR
# Executa: updpkgsums e makepkg --printsrcinfo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD="${SCRIPT_DIR}/PKGBUILD"

if [ ! -f "$PKGBUILD" ]; then
    echo "❌ PKGBUILD não encontrado em $SCRIPT_DIR"
    exit 1
fi

echo "📦 Preparando pacote para AUR..."

cd "$SCRIPT_DIR"

# 1. Atualizar checksums
echo "🔄 Atualizando checksums..."
if ! command -v updpkgsums &> /dev/null; then
    echo "❌ updpkgsums não encontrado. Instale pacman-contrib:"
    echo "   sudo pacman -S pacman-contrib"
    exit 1
fi

updpkgsums

# 2. Gerar .SRCINFO
echo "📋 Gerando .SRCINFO..."
if ! command -v makepkg &> /dev/null; then
    echo "❌ makepkg não encontrado. Instale base-devel:"
    echo "   sudo pacman -S base-devel"
    exit 1
fi

makepkg --printsrcinfo > .SRCINFO

echo "✅ Pacote preparado com sucesso!"
echo ""
echo "📝 Próximos passos:"
echo "   1. Revise PKGBUILD e .SRCINFO"
echo "   2. Execute: ./enviar-para-aur.sh"
echo ""
