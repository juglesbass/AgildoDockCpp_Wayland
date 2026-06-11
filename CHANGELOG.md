# Changelog

Todas as alterações notáveis deste projeto são documentadas neste ficheiro.

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
