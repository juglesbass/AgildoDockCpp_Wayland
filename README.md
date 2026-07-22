# AgildoDock

Doca de aplicações para **Plasma (KDE) em Wayland**, com Layer Shell, blur KWin, efeito de onda e integração com janelas: **preferencialmente «kdotool»** no Plasma/Wayland, ou **KX11Extras/KWindowInfo** quando a sessão Qt corre em **X11**.

Versão actual: **1.3.14** (ver `CHANGELOG.md`).

## Requisitos

- Qt 6 (Quick, Sql), KF6 (KWindowSystem, Kirigami, KGlobalAccel), LayerShellQt  
- **kdotool** no `PATH` — habitual no Plasma/Wayland para focar, minimizar, fechar e medir geometria  
- Testado em **Plasma 6 + Wayland**; outros compositores podem diferir em blur, região de input e layer-shell  

## Funcionalidades principais

- Dock em **quatro bordas** (inferior, superior, esquerda, direita) via Layer Shell  
- Estilos **Padrão** (fill opaco + blur) e **Vidro** (gradiente translúcido + blur)  
- Onda magnética nos ícones, auto-ocultar, desviar janelas maximizadas  
- Progresso de download (navegador, pasta Transferências ou ícone do ficheiro)  
- Badges SNI, Unity DBus (quando disponível), stacks de janelas  
- Perfis/presets, regras JSON, widgets leves, tema agendado dia/noite  
- i18n: **en_US**, **pt_PT**, **pt_BR**  

## Comportamento de processos

O estado «em execução» usa leitura periódica de **`/proc/*/cmdline`** (thread de trabalho). A janela activa (classe WM, título, geometria) vem de **KX11Extras** ou **kdotool**. O sinal `windowsUpdated` dispara após cada varredura.

## Atalhos

- **Meta+D** (global, KGlobalAccel): abre preferências — configurável nas definições  
- **Ctrl+Alt+D** (global): mostrar/ocultar dock  
- **Ctrl+,** ou **Preferências** (StandardKey): abre definições quando a doca tem foco  

## Linha de comandos

```bash
agildodock --version   # ou -v
```

Variáveis úteis: **`AGILDO_DOCK_LOCALE`** (ex. `pt_BR`), **`AGILDO_DOCK_DEBUG`**, **`AGILDO_DOCK_DEBUG_CATS`**.

## Instalação no sistema

Instala **`agildodock`**, `.desktop`, ícones hicolor, metainfo AppStream e plasmoid de preview opcional.

### CMake (manual)

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
```

### Pacote Arch / CachyOS

```bash
./packaging/make_dist.sh 1.3.14
cd packaging
mv ../agildodock-1.3.14.tar.gz .
updpkgsums
makepkg -sic
```

Ver **`packaging/aur/README.txt`** para AUR.

## Testes (CTest)

```bash
cmake -S . -B build && cmake --build build && ctest --test-dir build
```

Inclui smoke `--version` e **`test_dock_browser_utils`**.

## Plasmoid preview (Plasma 6)

```bash
kpackagetool6 -t Plasma/Applet -i plasmoid/agildodock-preview
kpackagetool6 -t Plasma/Applet -u plasmoid/agildodock-preview   # actualizar
kpackagetool6 -t Plasma/Applet -r org.agildosoft.agildodock.preview  # remover
```

## Traduções (i18n)

```bash
cmake --build build --target agildodock_lupdate   # actualizar .ts
cmake --build build                                # gera .qm
```

## Restaurar versão anterior (git)

Se actualizaste a partir do repositório local:

```bash
git checkout backup/pre-melhorias-2026-05-30
```

## Acessibilidade

Papéis **Accessible** em `dockContainer` e ícones. Tooltip com contraste reforçado. Recomenda-se **≥ 44 px** para toque; o slider mínimo mantém 30 px por compatibilidade.

## Limitações conhecidas

- **X11**: `setMask` no ponteiro não é aplicado (evita recorte visual)  
- Atalhos globais dependem do Plasma/KGlobalAccel  
- Workaround de arranque (`close` + `show`) pode variar noutros compositores  

## Licença

**GPL-3.0-or-later** — ver `LICENSE`.
