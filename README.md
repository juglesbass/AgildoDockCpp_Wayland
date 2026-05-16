# AgildoDock

Doca de aplicações para **Plasma (KDE) em Wayland**, com Layer Shell, efeito de onda e integração com janelas: **preferencialmente «kdotool»** quando estás em Plasma/Wayland, ou **KX11Extras/KWindowInfo** quando a própria doca corre numa sessão Qt **X11**.

## Requisitos

- Qt 6, KF6 (KWindowSystem, Kirigami), LayerShellQt  
- **kdotool** no `PATH` — caminho habitual no **Plasma/Wayland** para focar, minimizar, fechar e medir geometria («desviar»). Num **Plasma X11** com **`QT_QPA_PLATFORM=xcb`** podes ficar apenas com **KWinStack**.  
- Testado em fluxos **Plasma 6 + Wayland**; outros compositores podem ter diferenças em blur, região de input e layer-shell  

## Comportamento de processos

O estado **«em execução»** dos ícones usa leitura periódica de **`/proc/*/cmdline`** (em thread de trabalho, sem bloquear a UI). O **meta-informações da janela ativa** (classe WM, título, geometria) vêm primeiro de **KX11Extras** quando a sessão permite; caso contrário, do **kdotool** quando estiver instalado. O sinal `windowsUpdated` dispara após cada varredura de `/proc` e novo após esse refresco da janela em primeiro plano.

## Atalhos

- **Ctrl+,** ou **Preferências** (tecla de atalho do ambiente): abre a janela de configurações (se o compositor entregar teclas à superfície da doca).

## Linha de comandos

```bash
agildodock --version   # ou -v; não precisa de servidor gráfico
```

## Instalação no sistema

O projeto instala um binário **`agildodock`**, entrada **`.desktop`**, ícone tema **hicolor** e **metainfo** (Discover / lojas compatíveis com AppStream).

### Instalar com CMake (manual)

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
```

Com prefixo próprio (`/usr/local`): o mesmo comando com `-DCMAKE_INSTALL_PREFIX=/usr/local` (atenção aos `PATH` do `.desktop`; em ambiente Plasma costuma estar ok).

### Pacote Arch / CachyOS (makepkg)

1. Gera o tarball com a estrutura que o **`PKGBUILD`** espera (`agildodock-VERSION/…` no topo):

   ```bash
   ./packaging/make_dist.sh 1.0
   ```

2. Copia **`agildodock-1.0.tar.gz`** para **`packaging/`**, atualiza checksums e compila:

   ```bash
   cd packaging
   mv ../agildodock-1.0.tar.gz .
   updpkgsums
   makepkg -sic
   ```

3. **`license=`** em `packaging/PKGBUILD`: substitui por licença real do projeto (SPDX).

### Arch User Repository (AUR)

Ficheiros em **`packaging/aur/`** (`PKGBUILD`, `agildodock.install`, `prepare-for-aur.sh`, `README.txt`). Guia passo a passo: **`packaging/aur/README.txt`**.

Fluxo rápido: público no GitHub com etiqueta **`v1.0`** (ou igual ao `pkgver`), preenches `Maintainer` e **`_githubuser`** no `PKGBUILD`, `./prepare-for-aur.sh`, submissão na AUR, depois **`paru -S agildodock`**.

## Testes (CTest)

```bash
cmake -S . -B build && cmake --build build && ctest --test-dir build
```

## Traduções (i18n)

O CMake usa **`qt_add_translations`** (Qt **LinguistTools**): em cada compilação o **`lrelease`** gera `agildodock_en_US.qm` e `agildodock_pt_PT.qm` e inclui-os no recurso **`:/i18n/`**.

- **Ficheiros no repositório:** `i18n/agildodock_en_US.ts`, `i18n/agildodock_pt_PT.ts` e **`i18n/agildodock_pt_BR.ts`** (português do Brasil: «mouse», «tela», «Salvar», «Arquivos», «Lixeira», «Downloads», etc.).
- **Atualizar as cadeias** a partir do QML (corrige `<location>` e mensagens novas):

  ```bash
  cmake --build build --target agildodock_lupdate
  ```

  Depois edita os `.ts` (por exemplo com **Linguist**), volta a compilar para regenerar os `.qm`.

- **Arranque:** `main.cpp` escolhe o `.qm` por `QLocale`: **`pt_BR`** usa `agildodock_pt_BR.qm`; **`pt_PT`** usa `agildodock_pt_PT.qm`; outros `pt_*` tentam Brasil e depois Portugal. Variável **`AGILDO_DOCK_LOCALE`** (ex. `pt_BR`) força um catálogo.

- **Novo idioma:** copia um `.ts` existente, altera `language="…"`, traduz, acrescenta o ficheiro em **`qt_add_translations`** em `CMakeLists.txt` e recompila.

## Acessibilidade

- Papéis **Accessible** em **`Item`** válidos: área visual da doca (`dockContainer`), coluna das definições, e cada ícone (`DockIconDelegate`). Em **`Window`** o anexo `Accessible` não é suportado (aviso em runtime).
- Tooltip com maior contraste e texto ligeiramente maior  
- Sugestão de **≥ 44 px** para alvos de toque nas definições (recomendação; o mínimo do slider mantém-se em 30 px por compatibilidade com configurações antigas)

## Limitações conhecidas

- **X11**: a doca não aplica `setMask` no ponteiro (evita recorte visual); o restante comportamento não foi o foco principal do projeto  
- Atalhos globais dependem do compositor entregar eventos de teclado à janela da doca  
- Ícones «moles» em escalas altas podem vir do tema/SVG; a doca expõe opções de tamanho e `roundToIconSize: false` nos ícones Kirigami  
