#!/usr/bin/env bash
# Primeiro envio (ou atualização) ao repositório Git da AUR: ramo obrigatório «master».
# Pré‑requisito: conta em aur.archlinux.org + chave SSH pública lá colada (~/.ssh configurado para Host aur.archlinux.org).
set -euo pipefail

# Pasta onde está este script (PKGBUILD, .SRCINFO, *.install e LICENSE devem estar aqui)
FONTES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$(grep -m1 '^pkgname=' "${FONTES}/PKGBUILD" | cut -d= -f2 | tr -d ' \"')"
readonly PKG

if grep -qE 'sha256sums=\([^)]*SKIP[^)]*\)' "${FONTES}/PKGBUILD"; then
  echo 'Corrige primeiro: ./prepare-for-aur.sh (não pode haver SKIP no PKGBUILD).'
  exit 1
fi

echo 'A regenerar .SRCINFO…'
(cd "${FONTES}" && makepkg --printsrcinfo >.SRCINFO)

echo 'Teste rápido de SSH ao servidor da AUR (se falhar, configura ~/.ssh antes de continuares):'
set +e
ssh -o BatchMode=yes -T aur@aur.archlinux.org 2>&1
ssh_ok=$?
set -e

echo ""
if [[ "${ssh_ok}" -ne 0 ]]; then
  echo 'NOTA: o comando ssh acima costuma dar código ≠0 mesmo quando a conta está bem; desde que apareça algo como permissão/recusa de shell interactivo está OK.'
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/aur-${PKG}-XXXXXX")"

cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

echo ""
echo 'A clonar repositório vazio/hosteado na AUR (git, ramo master)…'

git -c init.defaultBranch=master clone ssh://aur@aur.archlinux.org/"${PKG}.git" "${WORKDIR}/repo"

cd "${WORKDIR}/repo"

git config user.email 'agomesdasilva99@gmail.com'
git config user.name 'Agildo Gomes da Silva'

# Garantimos ramo «master»: a AUR só aceita push para master.
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo master)"
if [[ "${CURRENT_BRANCH}" != master ]]; then
  git branch -m master || true
fi

cp "${FONTES}/PKGBUILD" .
cp "${FONTES}/.SRCINFO" .
cp "${FONTES}/agildodock.install" .

if [[ ! -f "${FONTES}/LICENSE" ]]; then
  echo 'Falta o ficheiro LICENSE ao lado do PKGBUILD (licença 0BSD dos ficheiros AUR).' >&2
  exit 1
fi

cp "${FONTES}/LICENSE" .

git add PKGBUILD .SRCINFO agildodock.install LICENSE

pkgver="$(grep ^pkgver= PKGBUILD | head -1 | cut -d= -f2)"
pkgrel="$(grep ^pkgrel= PKGBUILD | head -1 | cut -d= -f2)"

if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
  git commit -m "Atualizar para ${pkgver}-${pkgrel}"
else
  git commit -m "Publicação inicial: ${pkgver}-${pkgrel}"
fi

git push origin master

echo ''
echo 'Concluído. Em alguns minutos procura:'
echo "  https://aur.archlinux.org/packages/${PKG}"
echo 'Depois: paru -Sy '"${PKG}"'   # primeira vez faz -Sy para actualizar lista da AUR'
