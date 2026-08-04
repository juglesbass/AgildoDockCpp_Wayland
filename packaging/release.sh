#!/usr/bin/env bash
set -euo pipefail

# Script de automação de release para o AgildoDock
# Uso: ./packaging/release.sh <versao> (ex.: ./packaging/release.sh 1.4.2)

if [ $# -ne 1 ]; then
    echo "Uso: $0 <nova_versao>"
    echo "Exemplo: $0 1.4.2"
    exit 1
fi

NEW_VER="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

# 0. Impede tag duplicada (já rolou com a v1.4.0)
if git rev-parse -q --verify "refs/tags/v${NEW_VER}" >/dev/null; then
    echo "ERRO: a tag v${NEW_VER} já existe. Escolha outra versão ou apague a tag antiga primeiro:"
    echo "  git tag -d v${NEW_VER}"
    exit 1
fi

echo "==> Atualizando versão para ${NEW_VER}..."

# 1. Atualiza CMakeLists.txt
sed -i -E "s/project\(agildodock VERSION [0-9]+\.[0-9]+\.[0-9]+/project\(agildodock VERSION ${NEW_VER}/" CMakeLists.txt

# 2. Atualiza PKGBUILD
sed -i -E "s/pkgver=[0-9]+\.[0-9]+\.[0-9]+/pkgver=${NEW_VER}/" packaging/aur/PKGBUILD
sed -i -E "s/pkgrel=[0-9]+/pkgrel=1/" packaging/aur/PKGBUILD

# 3. Build + testes ANTES de mexer em checksums (não faz sentido gerar
#    hash de um tarball se o código nem builda)
echo "==> Compilando e rodando testes unitários com Sanitizers..."
cmake -S . -B build-asan -DCMAKE_BUILD_TYPE=Debug -DENABLE_SANITIZERS=ON
cmake --build build-asan -j"$(nproc)"
QT_QPA_PLATFORM=offscreen ctest --test-dir build-asan --output-on-failure

# 4. Cria a tag local (sem push — o push fica manual, de propósito)
echo "==> Criando tag v${NEW_VER}..."
git add -A
git commit -m "release: v${NEW_VER}"
git tag -a "v${NEW_VER}" -m "v${NEW_VER}"

# 5. Sincroniza o sha256sum do tarball GitHub com o PKGBUILD/.SRCINFO
#    (precisa da tag já criada e empurrada, porque o hash é do tarball
#    publicado no GitHub, não do teu diretório local)
echo ""
echo "==> Próximos passos MANUAIS (precisam da tag no GitHub primeiro):"
echo "    git push origin main --tags"
echo "    cd packaging/aur && updpkgsums && makepkg --printsrcinfo > .SRCINFO"
echo "    (isso troca o 'sha256sums = SKIP' atual do .SRCINFO por um hash real —"
echo "     hoje ele está dessincronizado do PKGBUILD, que já tem hash fixo)"
echo ""
echo "==> Versão ${NEW_VER} pronta localmente."
