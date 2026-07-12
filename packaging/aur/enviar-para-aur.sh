#!/bin/bash
# Script para enviar/atualizar pacote no AUR
# Pré-requisitos:
#   - SSH configurado com chave para aur.archlinux.org
#   - .SRCINFO já gerado (rode prepare-for-aur.sh primeiro)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD="${SCRIPT_DIR}/PKGBUILD"
SRCINFO="${SCRIPT_DIR}/.SRCINFO"

# Extrair informações do PKGBUILD
PKGNAME=$(grep "^pkgname=" "$PKGBUILD" | cut -d= -f2 | tr -d '"' | tr -d "'")

echo "🚀 Enviando $PKGNAME para AUR..."

if [ ! -f "$SRCINFO" ]; then
    echo "❌ .SRCINFO não encontrado. Execute prepare-for-aur.sh primeiro:"
    echo "   ./prepare-for-aur.sh"
    exit 1
fi

# Verificar SSH
if ! ssh -T aur@aur.archlinux.org &>/dev/null; then
    echo "⚠️  Testando SSH..."
    if ssh -T aur@aur.archlinux.org 2>&1 | grep -q "git-receive-pack"; then
        echo "✅ SSH configurado corretamente"
    else
        echo "❌ SSH não configurado. Siga:"
        echo "   1. Gere chave SSH: ssh-keygen -t ed25519 -f ~/.ssh/aur_arch"
        echo "   2. Copie a chave pública para My Account → SSH Keys em aur.archlinux.org"
        echo "   3. Configure ~/.ssh/config conforme descrito em packaging/aur/README.txt"
        exit 1
    fi
fi

# Criar/clonar repositório AUR
AUR_REPO="/tmp/aur-${PKGNAME}"
if [ ! -d "$AUR_REPO" ]; then
    echo "📥 Clonando repositório AUR..."
    git clone "ssh://aur@aur.archlinux.org/${PKGNAME}.git" "$AUR_REPO" 2>/dev/null || {
        echo "ℹ️  Repositório não existe. Será criado na primeira submissão."
        mkdir -p "$AUR_REPO"
        cd "$AUR_REPO"
        git init
        git remote add origin "ssh://aur@aur.archlinux.org/${PKGNAME}.git"
    }
else
    echo "♻️  Atualizando repositório AUR local..."
    cd "$AUR_REPO"
    git fetch origin master 2>/dev/null || true
fi

cd "$AUR_REPO"

# Copiar ficheiros
echo "📋 Copiando ficheiros..."
cp "$PKGBUILD" .
cp "$SRCINFO" .

if [ -f "${SCRIPT_DIR}/${PKGNAME}.install" ]; then
    cp "${SCRIPT_DIR}/${PKGNAME}.install" .
fi

if [ -f "${SCRIPT_DIR}/LICENSE" ]; then
    cp "${SCRIPT_DIR}/LICENSE" .
fi

# Git add, commit e push
echo "💾 Fazendo commit..."
git add -A
git commit -m "Update to $(grep 'pkgver=' PKGBUILD | cut -d= -f2 | tr -d '\"' | tr -d "'" )" || {
    echo "ℹ️  Sem mudanças para commit"
}

echo "🔗 Enviando para AUR..."
if git push origin master; then
    echo "✅ Pacote enviado com sucesso!"
    echo ""
    echo "📦 Instalação:"
    echo "   paru -S $PKGNAME"
    echo "   # ou"
    echo "   yay -S $PKGNAME"
else
    echo "❌ Erro ao enviar. Verifique SSH e permissões."
    exit 1
fi

echo ""
echo "🎉 Concluído!"
