# Changelog

Todas as alterações notáveis deste projeto são documentadas neste ficheiro.

## [1.4.2] — 2026-08-03

### Adicionado / Melhorado
- **Melhorias de Arquitetura e Compilação Rigorosa**:
  - Adicionadas flags estritas C++ (`-Wall -Wextra`) e opção de sanitizers (`-DENABLE_SANITIZERS=ON`) no CMake.
  - Criação da biblioteca estática `agildodock_core` e isolamento dos builds em `build/` (Release nativo) e `build-asan/` (Debug com ASan).
- **Testes Unitários Automatizados**:
  - Suite de testes unitários C++ (`test_taskbackend`, `dock_browser_utils`, `agildodock_version`) com 100% de cobertura nos métodos core e execução headless em CTest.
- **Correção da Ancoragem LayerShellQt em Bordas**:
  - Mapeamento dinâmico correto para ancoragem do LayerShellQt em todas as 4 posições de tela (`Bottom`, `Top`, `Left`, `Right`) com invalidação automática da região de blur do KWin.
- **Otimização de Desempenho e Coalescimento no Hover**:
  - Coalescimento de eventos de movimento no `HoverHandler` via `Qt.callLater`, limitando a avaliação da física a no máximo 1 vez por frame em mouses de alto polling rate (1000Hz+).

## [1.4.1] — 2026-08-03

### Corrigido / Melhorado
- **Fixação de Aplicativos via Drag & Drop**:
  - Resolução robusta de URLs `applications:` e esquema `file://` do Kickoff/Wayland no C++ (`taskbackend.cpp`).
  - Correção de exceção de tipo (`TypeError`) ao tratar objetos `DropEvent` em QML, garantindo conversão explícita de `String` e retenção de atalhos arrastados na doca (`saveApps()`).
- **Animações de Reordenação e Adição de Ícones**:
  - Transições suaves de movimento (`move`) e surgimento (`add`) de ícones ao reordenar ou fixar atalhos na doca.
- **Encolhimento das Pontas Estilo macOS**:
  - Ajuste na curva `edgeContractFactor` para encolhimento acentuado de até 15% nas extremidades da barra ao aproximar o ponteiro dos ícones da ponta.

## [1.4.0] — 2026-07-25

### Adicionado / Melhorado
- **Física da Onda 100% macOS (`Dock.app`)**:
  - Resposta instantânea 1:1 de hardware ($0\text{ms}$ de atraso) e curva **Cosseno Quadrado ($\cos^2$)** idêntica ao macOS original.
  - Resolução subpixel contínua (`float`) eliminando qualquer imperfeição ou micro-degrau em telas de 60Hz, 120Hz e 144Hz.
- **Fundo Estável de Vidro no Hover**:
  - A barra de vidro da doca expande suavemente apenas na aproximação do rato (`waveAmplitude`: $0 \to 1$) e permanece **100% estática, firme e imóvel** durante a navegação entre ícones, eliminando qualquer oscilação ou tremor nas pontas.
- **Nativização do Menu de Aplicativos (`DockAppMenuWindow.qml`)**:
  - Suporte a desfoque KWin nativo em hardware (`enableWindowBlur`), layout responsivo compacto em PT-BR, barra de busca instantânea e atalhos de categoria.
- **Pulo Elástico de Ícones (*Bounce*)**:
  - Pulo discreto de 20px com subida elástica macia (`Easing.OutBack`) e queda senoidal (`Easing.InSine`).
- **Suporte Multidirecional Completo**:
  - Suporte perfeito a todas as 4 posições da doca (*Inferior*, *Superior*, *Esquerda*, *Direita*).

## [1.3.16] — 2026-07-23

### Adicionado / Melhorado
- **Docklet de Lixeira Inteligente**: Monitorização em tempo real via `QFileSystemWatcher` (`setupTrashWatcher`, `updateTrashStatus`), ícone dinâmico (`user-trash`/`user-trash-full`), badge com contagem de itens, ação de esvaziar no menu de contexto (`emptyTrash`) e suporte a *Drag & Drop* de ficheiros (`moveToTrash`).
- **Janela de Configurações Estilo Latte Dock**: Layout de 3 abas (*Comportamento*, *Aparência*, *Efeitos & Ajustes*) 100% traduzido para PT-BR, com chaveador *Avançado* dinâmico e retenção de todas as opções de personalização.
- **Menu de Contexto Flutuante Estilo Vidro/Latte**: Redesign visual com acentos dinâmicos do tema, cabeçalho de aplicação, suporte a submenus nativos de ficheiros recentes e comandos customizados.
- **Seletores de Ficheiros Nativos**: Integração de `FileDialog`s no nível raiz do `main.qml` para a adição estável de aplicativos e atalhos do sistema.
- **Componente ActionBtn Customizado**: Substituição de botões padrão do QtQuick por botões com estilo de vidro, eliminando avisos do tema Breeze no Plasma 6.

## [1.3.15] — 2026-07-22

### Alterado
- Auditoria e validação final da correção de data race em `knownApps` e alinhamento da documentação.

## [1.3.14] — 2026-07-22

### Corrigido
- **Data race** em `knownApps` (`taskbackend.cpp`): resolvido clonando o hash para o escopo local antes de passar por valor para `QtConcurrent::run` (em `launchApp`, `closeApp` e outros).
- **Data race** em `chromiumHistoryFailUntil` (`dock_browser_downloads.cpp`): hash estático protegido com `QMutex`.
- **Use-after-free** nos timers de kill do `kdotool` (`taskbackend.cpp`): ponteiros brutos substituídos por `QPointer<QProcess>`.
- Eliminado aviso do CMake sobre módulo privado do Qt (`QT_NO_PRIVATE_MODULE_WARNING`).

### Removido
- Código morto: `updateActiveWindowCoversWorkAreaHint()`, o wrapper redundante `TaskBackend::execBasenameFromCommand()` (a função original continua ativa), `combinedWmLower()`, `stackingWindowBelongsToCommand()`, `activeDownloadProgress()`.
- Propriedades QML obsoletas: `dockAppearanceModel`, rectângulo desativado no blur, `ajustarAlturaAoConteudo()`.
- Ficheiros desnecessários da raiz do projeto (`test9*`, `fix_*.py`, `.SRCINFO`).

### Alterado
- `.gitignore` atualizado para cobrir ficheiros de teste e scripts antigos.
- Documentação atualizada para v1.3.14 (`CHANGELOG`, `README`, `README_PT`).

## [1.3.13] — 2026-07-21

### Alterado
- Bump de versão para resolver conflitos de tag no Git/AUR.

## [1.3.12] — 2026-07-21

### Alterado
- Refactors Sonnet 5: melhorias de performance com `QtConcurrent` e limpeza de gestão de janelas.

## [1.3.11] — 2026-07-20

### Adicionado
- Animação de minimizar nativa no Wayland via `org_kde_plasma_window_management`.
- `KWinDBusHelper`: fallback D-Bus para gestão de janelas quando `kdotool` não está disponível.
- `X-KDE-Wayland-Interfaces=org_kde_plasma_window_management` no ficheiro `.desktop` para autorização KDE Plasma 6.

### Corrigido
- Headers e dependências faltantes do `kwin_dbus_helper`.

## [1.3.7–1.3.10] — 2026-07-18 a 2026-07-20

### Adicionado
- Melhorias incrementais na integração Wayland e estabilidade geral.

## [1.3.6] — 2026-07-18

### Corrigido
- Removida a borda duplicada do modo Vidro (3D) no fundo da dock.
- Corrigida a espessura anormal da borda superior ao desativar a `dockTopLine`, garantindo 1px exato em todos os estilos.


## [1.3.5] — 2026-05-30

### Adicionado
- `DockBlurBackground.qml` — blur e fundo extraídos de `main.qml`.
- `commandMatchesWmClass` em `dock_browser_utils` + teste unitário.
- Auto-ocultar: faixa de revelação nas quatro bordas da dock.
- Definições: tema claro/escuro conforme preset da dock; margem dinâmica por borda.

### Corrigido
- Watcher de download: prioriza browser com progresso activo, depois janela activa.
- Deteção de navegadores unificada (`DockBrowserUtils`) em kdotool e `/proc`.
- Default `borderGlow` alinhado (0.24); borda respeita o slider.
- Descrição acessível correcta para dock vertical/superior.

### Alterado
- README actualizado (v1.3.5, funcionalidades, atalhos Meta+D).
- Atalhos KGlobalAccel traduzíveis; `nameFilters` deduplicados no menu de contexto.

## [1.3.4] — 2026-05-30

### Adicionado
- Utilitário `dock_browser_utils` com deteção unificada de navegadores (Chromium, Brave, Opera, Vivaldi, Gecko).
- `DockBrowserDownloadWatcher` (renomeado) cobre Chromium, Firefox, Zen, `.crdownload` e pastas XDG.
- Progresso estilo macOS na pasta Transferências com ícone do arquivo em download.
- Indicador de stack por app (pontos estilo macOS) e flash da pasta ao concluir download.
- Botões de preset para widgets nas definições; perfis rápidos já existentes mantidos.
- Testes unitários para `dock_browser_utils`; `LICENSE` e `CHANGELOG` na raiz.
- Instalação opcional do plasmoid de pré-visualização.

### Corrigido
- Unity DBus: não regista `com.canonical.Unity` se outra dock (Latte) já o possui.
- Padrão e Vidro usam blur KWin; Padrão adiciona fill opaco por cima.
- Progresso `.crdownload` deixa de usar valor fixo 0.08 até o SQL responder.
- Steam removido da blacklist de `.desktop` — jogos podem aparecer na área dinâmica.
- Logs de falha do `kdotool` em pesquisas de janela.
- Cópia do History SQLite com backoff quando o ficheiro está bloqueado.

### Alterado
- `CMakeLists.txt` alinhado com versão 1.3.4; dependência `kglobalaccel` no PKGBUILD AUR.

## [1.3.3] — anterior

- Progresso de download com suporte Chromium History, debounce SQL e modos de exibição.
