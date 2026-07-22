# AgildoDock 🎯

[![Build & Test](https://github.com/juglesbass/AgildoDockCpp_Wayland/actions/workflows/build.yml/badge.svg)](https://github.com/juglesbass/AgildoDockCpp_Wayland/actions)
[![Code Quality](https://github.com/juglesbass/AgildoDockCpp_Wayland/actions/workflows/lint.yml/badge.svg)](https://github.com/juglesbass/AgildoDockCpp_Wayland/actions)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.3.14-green.svg)](#)

Doca de aplicações para **Plasma (KDE) em Wayland**, com Layer Shell, blur KWin, efeito de onda magnética e integração completa com janelas.

## 📋 Características Principais

- 🎨 **Quatro Bordas** — Inferior, superior, esquerda ou direita via Layer Shell
- ✨ **Efeitos Visuais** — Onda magnética nos ícones, blur KWin e temas customizáveis
- 🎯 **Inteligente** — Auto-ocultar, desviar janelas maximizadas, progresso de downloads
- 🌐 **i18n Completo** — Português (PT/BR), Inglês (US)
- ⚙️ **Configurável** — Presets, perfis, regras JSON, widgets personalizados
- 🔐 **Temas Agendados** — Dia/noite automático conforme a hora
- 📱 **Acessibilidade** — Papéis ARIA, contraste reforçado

## 🚀 Quick Start

### Requisitos

- **Qt 6** (Quick, Sql)
- **KF6** (KWindowSystem, Kirigami, KGlobalAccel)
- **LayerShellQt**
- **kdotool** (recomendado para Plasma/Wayland)
- Testado em **Plasma 6 + Wayland**

### Instalação Rápida (Arch/CachyOS)

```bash
git clone https://github.com/juglesbass/AgildoDockCpp_Wayland.git
cd AgildoDockCpp_Wayland

# Build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build

# Limpar cache de ícones
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
```

### Instalação via AUR

```bash
# Com paru
paru -S agildodock

# Ou com yay
yay -S agildodock

# Ou manual
git clone https://aur.archlinux.org/agildodock.git
cd agildodock
makepkg -sic
```

## 🛠️ Build Detalhado

### 1. Instalar Dependências

**Arch Linux:**
```bash
sudo pacman -S --needed \
  base-devel cmake ninja extra-cmake-modules \
  kglobalaccel kirigami kwindowsystem layer-shell-qt \
  qt6-base qt6-declarative qt6-shadertools qt6-wayland kdotool
```

**Fedora/RHEL:**
```bash
sudo dnf install gcc-c++ cmake ninja-build \
  kf6-kglobalshortcuts kf6-ki18n kf6-kwindowsystem \
  kf6-kirigami kirigami-devel layer-shell-qt-devel \
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel
```

**Debian/Ubuntu:**
```bash
sudo apt install build-essential cmake ninja-build \
  libkf6globalaccel-dev libkf6kirigami-dev libkf6windowsystem-dev \
  liblayershellqt-dev qt6-base-dev qt6-declarative-dev qt6-wayland-dev
```

### 2. Compilar

```bash
mkdir -p build && cd build
cmake -S .. -B . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build . --parallel $(nproc)
```

### 3. Testar

```bash
ctest --test-dir . --output-on-failure
```

### 4. Instalar

```bash
sudo cmake --install .
```

## ⚙️ Configuração

### Atalhos Globais

| Atalho | Ação | Personalizável |
|--------|------|---|
| **Meta+D** | Abrir Preferências | ✅ Sim |
| **Ctrl+Alt+D** | Mostrar/Ocultar Dock | ✅ Sim |
| **Ctrl+,** | Abrir Configurações | Local |

### Variáveis de Ambiente

```bash
# Força idioma específico
export AGILDO_DOCK_LOCALE=pt_BR

# Ativa logs de debug
export AGILDO_DOCK_DEBUG=1

# Filtra categorias de debug
export AGILDO_DOCK_DEBUG_CATS=ui,window
```

## 📖 Documentação Avançada

### Regras de Apps (JSON)

Customize o comportamento de aplicações específicas em `~/.config/agildodock/app_rules.json`:

```json
{
  "firefox": {
    "leftClickAction": 0,
    "badgeText": "2"
  },
  "telegram": {
    "middleClickAction": 3
  }
}
```

### Presets de Temas

Disponíveis:
- **Dark Glass** — Vidro escuro com blur
- **Light Glass** — Vidro claro e minimalista
- **Neon** — Tema blue neon (monocromático)
- **Minimal** — Padrão flat sem efeitos

### Plasmoid Preview (Plasma 6)

```bash
kpackagetool6 -t Plasma/Applet -i plasmoid/agildodock-preview
kpackagetool6 -t Plasma/Applet -u plasmoid/agildodock-preview   # Atualizar
kpackagetool6 -t Plasma/Applet -r org.agildosoft.agildodock.preview
```

## 🔄 Atualizações e Versionamento

### Versão Atual

**1.3.14** — Ver [CHANGELOG.md](CHANGELOG.md) para detalhes completos.

### Atualizar do GitHub

```bash
cd ~/.local/share/agildodock  # ou aonde clonou
git pull origin main
cmake --build build
sudo cmake --install build
```

### Restaurar Versão Anterior

```bash
git checkout backup/pre-melhorias-2026-05-30
```

## 🐛 Troubleshooting

### A dock não aparece

```bash
# Verificar se kdotool está disponível
which kdotool
echo $?  # Deve ser 0

# Forçar modo debug
AGILDO_DOCK_DEBUG=1 agildodock
```

### Blur não funciona

- Certifique-se de usar **Wayland** (não X11)
- Verifique se KWin está com blur habilitado
- Reinicie a sessão do Plasma

### Performance baixa

1. Desabilite "Auto-Ocultar" se não usar
2. Reduza "Intensidade da Onda" nas preferências
3. Mude para tema "Minimal" (sem efeitos)

## 📦 Publicar no AUR

### Pré-requisitos

1. Conta registada em https://aur.archlinux.org
2. Chave SSH configurada ([guia](packaging/aur/README.txt))
3. Tag Git criada: `git tag v1.3.14`

### Publicar

```bash
cd packaging/aur

# 1. Atualizar PKGBUILD com nova versão
# 2. Gerar checksums
./prepare-for-aur.sh

# 3. Enviar ao AUR
./enviar-para-aur.sh
```

## 📝 Traduções

### Atualizar strings para tradução

```bash
cmake --build build --target agildodock_lupdate
# Edite os ficheiros .ts em i18n/
cmake --build build
```

### Adicionar novo idioma

1. Copie `i18n/agildodock_en_US.ts` para `i18n/agildodock_xx_YY.ts`
2. Traduza as strings
3. Adicione em `CMakeLists.txt`:
   ```cmake
   "${CMAKE_CURRENT_SOURCE_DIR}/i18n/agildodock_xx_YY.ts"
   ```
4. Rebuild

## 🤝 Contribuições

Contribuições são bem-vindas! Por favor:

1. Faça fork do repositório
2. Crie uma branch (`git checkout -b feature/minha-feature`)
3. Commit suas mudanças (`git commit -m 'Add feature'`)
4. Push para a branch (`git push origin feature/minha-feature`)
5. Abra um Pull Request

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para mais detalhes.

## 📄 Licença

**GPL-3.0-or-later** — Ver [LICENSE](LICENSE)

## 👤 Autor

**Agildo Gomes da Silva** — [@juglesbass](https://github.com/juglesbass)

## 🔗 Links Úteis

- [KDE Plasma Documentation](https://docs.kde.org/stable/)
- [Qt 6 Documentation](https://doc.qt.io/qt-6/)
- [Layer Shell Protocol](https://github.com/emersion/wlr-layer-shell)
- [Arch Linux AUR](https://aur.archlinux.org/)

---

**Aproveita a dock!** Se encontrar bugs ou tiver sugestões, abre uma [issue](https://github.com/juglesbass/AgildoDockCpp_Wayland/issues) 🎉
