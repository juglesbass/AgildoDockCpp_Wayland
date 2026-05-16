# Pacote agildodock — Arch User Repository (AUR)

Depois de publicado, instalas com:

    paru -S agildodock

O paru compila/instala como qualquer pacote da AUR e integra com o pacman.

──────────────────────────────────────────────────────────────────────────────
Pré-requisitos
──────────────────────────────────────────────────────────────────────────────

• Conta em https://aur.archlinux.org e chave SSH pública no perfil (git push).
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
3) Primeira submissão
──────────────────────────────────────────────────────────────────────────────

Se o nome «agildodock» ainda não existir na AUR, usa o formulário «Submit Package»
no site da AUR e envia PKGBUILD + .SRCINFO (+ agildodock.install conforme pedido).

Após aprovação, actualizações normais:

    git clone ssh://aur@aur.archlinux.org/agildodock.git
    cd agildodock
    (copiar PKGBUILD, .SRCINFO, agildodock.install já preparados)
    git add PKGBUILD .SRCINFO agildodock.install
    git commit -m "Upstream release v…"
    git push

No repositório da AUR não se versionam tarballs — só estes metadados.

──────────────────────────────────────────────────────────────────────────────
4) paru
──────────────────────────────────────────────────────────────────────────────

    paru -S agildodock
    paru -Syu agildodock    # actualizar

Se o pkgname estiver ocupado, escolhe outro nome coerente com o upstream e renomeia
os ficheiros .install/README conforme necessário.

──────────────────────────────────────────────────────────────────────────────
Variante «-git»
──────────────────────────────────────────────────────────────────────────────

Para empacotar o último commit em vez de tags estáveis: ver Wiki AUR sobre função
pkgver() em PKGBUILD com fonte git+https (pacote à parte, ex.: agildodock-git).

