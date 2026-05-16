#!/usr/bin/env bash
# Gera checksums reais e o ficheiro .SRCINFO exigidos pelo AUR.
# Comentários em pt-BR: lê primeiro packaging/aur/README.txt

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

fatal() {
  printf 'Erro: %s\n' "$*" >&2
  exit 1
}

[[ -f PKGBUILD ]] || fatal "Execute este script na pasta packaging/aur."

if grep -Fq "_githubuser=SUBSTITUIR_UTILIZADOR" PKGBUILD; then
  fatal "Defina _githubuser no PKGBUILD (utilizador GitHub onde está o código e a tag v\${pkgver})."
fi

if grep -Fq "NOME COMPLETO" PKGBUILD; then
  fatal "Substitua a linha «Maintainer» no PKGBUILD pelo teu nome e e-mail válidos."
fi

GITHUB_USER="$(grep '^_githubuser=' PKGBUILD | head -1 | cut -d= -f2- | awk '{print $1}' | tr -d ' \"')"
REPO="$(grep '^_repo=' PKGBUILD | head -1 | cut -d= -f2- | awk '{print $1}')"
pkgver="$(grep '^pkgver=' PKGBUILD | head -1 | cut -d= -f2- | awk '{print $1}')"
URL="https://github.com/${GITHUB_USER}/${REPO}/archive/refs/tags/v${pkgver}.tar.gz"

printf 'A verificar se o tarball existe: %s\n' "$URL"
if command -v curl >/dev/null 2>&1; then
  code="$(curl -sS -o /dev/null -w '%{http_code}' -L "$URL" || true)"
  [[ "$code" == "200" ]] || fatal "HTTP $code ao aceder ao tarball. Publica no GitHub a etiqueta Git «v${pkgver}» antes de continuares."
elif command -v wget >/dev/null 2>&1; then
  wget -q --spider "$URL" || fatal "Não consegui confirmar o tarball. Publica a etiqueta Git «v${pkgver}» no GitHub."
else
  printf 'Aviso: instala curl ou wget para validar o URL antes de updpkgsums.\n'
fi

printf 'A atualizar checksums (updpkgsums)…\n'
updpkgsums

if grep -Fq 'sha256sums=("SKIP")' PKGBUILD; then
  fatal "Os checksums continuam SKIP — confirma conectividade ou o nome do repositório/etiqueta."
fi

printf 'A gerar .SRCINFO…\n'
makepkg --printsrcinfo >.SRCINFO

printf '\nFeito.\nRevê PKGBUILD, .SRCINFO e agildodock.install; depois segue README.txt para o primeiro envio ao AUR ou git push.\n'
