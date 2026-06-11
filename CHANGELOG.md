# Changelog

Todas as alterações notáveis deste projeto são documentadas neste ficheiro.

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
- Blur KWin desligado explicitamente no estilo plano (`liveBg3dStyle === 0`).
- Progresso `.crdownload` deixa de usar valor fixo 0.08 até o SQL responder.
- Steam removido da blacklist de `.desktop` — jogos podem aparecer na área dinâmica.
- Logs de falha do `kdotool` em pesquisas de janela.
- Cópia do History SQLite com backoff quando o ficheiro está bloqueado.

### Alterado
- `CMakeLists.txt` alinhado com versão 1.3.4; dependência `kglobalaccel` no PKGBUILD AUR.

## [1.3.3] — anterior

- Progresso de download com suporte Chromium History, debounce SQL e modos de exibição.
