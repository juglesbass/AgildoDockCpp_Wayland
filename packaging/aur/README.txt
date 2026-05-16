# Pacote agildodock — Arch User Repository (AUR)

Depois de publicado, instalas com:

    paru -S agildodock

O paru compila/instala como qualquer pacote da AUR e integra com o pacman.

──────────────────────────────────────────────────────────────────────────────
Pré-requisitos
──────────────────────────────────────────────────────────────────────────────

• Registo/login em https://aur.archlinux.org .
• Chave SSH pública colada na AUR (My Account → SSH Keys — necessário para enviar‑para‑aur.sh).
• Repositório Git público (ex.: GitHub) com etiqueta Git «vVERSÃO» igual ao pkgver
  (ex.: v1.0 para pkgver=1.0). O PKGBUILD descarrega o tarball dessa etiqueta.
• Ficheiro LICENSE/COPYING no código ou alinhar license=() com a licença real (SPDX).

──────────────────────────────────────────────────────────────────────────────
1) Editar PKGBUILD
──────────────────────────────────────────────────────────────────────────────

  • # Maintainer: Nome <email@domínio>
  • _githubuser=   (utilizador ou org no GitHub)
  • _repo=         (nome exacto do repo; pasta extraída = ${_repo}-${pkgver})
  • license=(...)  (SPDX)
  • pkgver/pkgrel  alinhados com a etiqueta no GitHub

──────────────────────────────────────────────────────────────────────────────
2) Checksums e .SRCINFO (obrigatório)
──────────────────────────────────────────────────────────────────────────────

Na pasta packaging/aur:

    chmod +x prepare-for-aur.sh
    ./prepare-for-aur.sh

Isto valida o URL do tarball, corre updpkgsums e gera .SRCINFO.
NÃO envies ao AUR com sha256sums=("SKIP").

Alternativa manual:

    updpkgsums
    makepkg -fci
    makepkg --printsrcinfo > .SRCINFO

──────────────────────────────────────────────────────────────────────────────
3) SSH (uma vez) — obrigatório para «git push» na AUR
──────────────────────────────────────────────────────────────────────────────

Na máquina:

    ssh-keygen -t ed25519 -f ~/.ssh/aur_arch -N "" -C "agomesdasilva99@gmail.com"

Mostra a chave pública e copia-a:

    cat ~/.ssh/aur_arch.pub

Na AUR: login → «My Account» → «SSH Keys» → colar → guardar.

Ficheiro ~/.ssh/config (cria ou acrescenta):

    Host aur.archlinux.org
      IdentityFile ~/.ssh/aur_arch
      User aur

Teste (mensagem estranha ou fecho logo = normal):

    ssh -T aur@aur.archlinux.org

──────────────────────────────────────────────────────────────────────────────
4) Enviar o pacote (script automático)
──────────────────────────────────────────────────────────────────────────────

    cd packaging/aur
    ./prepare-for-aur.sh               # garante checksums + .SRCINFO
    chmod +x enviar-para-aur.sh
    ./enviar-para-aur.sh

Este script faz fetch no git da AUR, copia PKGBUILD, .SRCINFO, agildodock.install
e LICENSE, commit em «master» e push. Guia oficial:
https://wiki.archlinux.org/title/AUR_submission_guidelines

──────────────────────────────────────────────────────────────────────────────
5) paru
──────────────────────────────────────────────────────────────────────────────

    paru -S agildodock
    paru -Syu agildodock    # actualizar

Se o pkgname estiver ocupado, escolhe outro nome coerente com o upstream e renomeia
os ficheiros .install/README conforme necessário.

──────────────────────────────────────────────────────────────────────────────
6) Variante «-git»
──────────────────────────────────────────────────────────────────────────────

Para empacotar o último commit em vez de tags estáveis: ver Wiki AUR sobre função
pkgver() em PKGBUILD com fonte git+https (pacote à parte, ex.: agildodock-git).

