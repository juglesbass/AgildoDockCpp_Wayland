# AgildoDock

Doca de aplicações para **Plasma (KDE) em Wayland**, com Layer Shell, efeito de onda e integração com janelas.

**Versão actual:** 1.2.0

## Requisitos

- Qt 6, KF6 (KWindowSystem, Kirigami), LayerShellQt  
- **kdotool** no `PATH` — recomendado no Plasma/Wayland para focar, minimizar e fechar janelas  
- **kglobalaccel** (opcional) — atalhos globais `Ctrl+,` e `Meta+Alt+D`  
- No Plasma 6, **org.kde.KWin** via D-Bus acelera o foco da janela activa (sem substituir o `kdotool` para todas as operações)

## Funcionalidades (1.2)

- Apps fixadas, área dinâmica, menu Plasma, itens de sistema configuráveis  
- Tema escuro / claro / sistema, auto-ocultar, desviar janelas maximizadas  
- Múltiplas janelas: badge, roda do rato, menu «Janelas abertas»  
- Regras para ocultar apps da área dinâmica (JSON nas configurações)  
- Separadores na lista fixada, exportar/importar `~/agildodock-apps.json`  
- Relógio e nome da actividade Plasma (opcional)  
- Ecrã primário ou índice de ecrã  
- Aviso na doca se `kdotool` não estiver instalado  
- Autostart Plasma (`X-KDE-Autostart`)

## Atalhos

- **Ctrl+,** — preferências (global com kglobalaccel)  
- **Meta+Alt+D** — mostrar/ocultar doca (com kglobalaccel)  
- Clique direito na barra — configurações  

## Instalação

### Arch / CachyOS (AUR)

```bash
paru -S agildodock
```

Publicar actualização (mantenedor):

1. Etiqueta `v1.2.0` no GitHub  
2. `cd packaging/aur && ./prepare-for-aur.sh && ./enviar-para-aur.sh`  
3. `paru -Syu agildodock`

### Compilar localmente

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
sudo cmake --install build
```

## Testes

```bash
ctest --test-dir build --output-on-failure
```

Inclui verificação de versão e testes de correspondência de janelas (`test_dock_matching`).

## Traduções

```bash
cmake --build build --target agildodock_lupdate
# Editar i18n/agildodock_pt_BR.ts (e outros), depois recompilar
```

## Limitações conhecidas

- Posição lateral/superior da doca: não disponível (só margem inferior)  
- Pré-visualização gráfica de janelas (miniaturas KWin): não implementada; usa lista de títulos no menu  
- Gestos multi-toque (pinch): não implementados  

## Efeito KWin: “sugar” ao minimizar (opcional)

Para ter uma animação tipo macOS (a janela “vai” até o ícone na doca), é necessário um **efeito do KWin**.
No Wayland, a doca não consegue animar janelas de terceiros sozinha.

### Compilar e instalar com o efeito

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_KWIN_EFFECT=ON
cmake --build build
sudo cmake --install build
```

### Activar no Plasma

1. Abrir **Configurações do Sistema → Área de Trabalho → Efeitos da Área de Trabalho**  
2. Desactivar outros efeitos de **minimizar** (ex.: *Squash*, *Lâmpada mágica*) — só um pode estar activo por vez  
3. Procurar por **“AgildoDock: Sugar ao minimizar”** e activar  
4. Reiniciar o KWin (`kwin_wayland --replace` ou terminar sessão) e minimizar uma janela

### Como funciona

- O efeito do KWin consulta via D-Bus a posição do ícone na doca (`org.agildosoft.AgildoDock` → `GetIconRect`).  
- A doca publica o retângulo global do ícone enquanto estiver visível.  
- Se não houver ícone correspondente, o efeito não anima (fallback padrão do KWin).

## Licença

Ver `packaging/aur/LICENSE` e campo `license` no PKGBUILD (GPL-3.0-or-later).
