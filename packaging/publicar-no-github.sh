#!/usr/bin/env bash
# Envia este projecto ao GitHub (juglesbass/AgildoDockCpp_Wayland) e publica a etiqueta v1.0.
# Corres este script no teu terminal (pode pedir login); o ambiente Cursor costuma não ter credenciais.
#
# PRÉ‑PASSO (escolhe um):
#
# A) Pelo browser
#    1) https://github.com/new → nome: AgildoDockCpp_Wayland → público
#       NÃO marques README / .gitignore / license no assistente.
#    2) Corre de novo: ./packaging/publicar-no-github.sh
#
# B) Com GitHub CLI (se instalares: pacman -S github-cli)
#    gh auth login
#    gh repo create juglesbass/AgildoDockCpp_Wayland --public --source=. --remote=origin --push
#    git push origin v1.0
#
# Se já criaste «origin», este script apenas faz push + tag.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

OWNER="juglesbass"
NOME_REPO="AgildoDockCpp_Wayland"

REPO_URL_HTTPS="https://github.com/${OWNER}/${NOME_REPO}.git"
URL_WEB="https://github.com/${OWNER}/${NOME_REPO}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo 'Erro: esta pasta não é um repositório git.' >&2
  exit 1
fi

if ! git rev-parse -q --verify refs/tags/v1.0 >/dev/null 2>&1; then
  git tag -a v1.0 -m 'Release v1.0 (fonte tarball AUR)'
fi

tem_origin=false
if git remote get-url origin >/dev/null 2>&1; then
  tem_origin=true
else
  echo "A registar remote origin → ${REPO_URL_HTTPS}"
  git remote add origin "${REPO_URL_HTTPS}"
fi

echo 'A enviar branch main… (pode pedir utilizador/token do GitHub em HTTPS)'
git push -u origin main

echo 'A enviar etiqueta v1.0…'
git push origin v1.0

echo ''
echo 'Feito. Verifica: '"${URL_WEB}"'/releases/tag/v1.0'
echo 'Depois: cd packaging/aur && ./prepare-for-aur.sh'
