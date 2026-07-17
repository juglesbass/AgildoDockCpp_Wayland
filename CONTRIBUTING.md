# Contribuindo para AgildoDock

Obrigado por considerar contribuir para o AgildoDock! 🎉

## 📋 Código de Conduta

Por favor, leia e siga nosso código de conduta (implícito: ser respeitoso e construtivo).

## 🐛 Reportar Bugs

Antes de criar um relatório de bug, verifique a lista de issues — você pode descobrir que o bug já foi reportado.

**Ao reportar um bug, inclua:**

- **Versão do AgildoDock** — `agildodock --version`
- **Sistema Operacional** — Plasma versão, Wayland/X11, distro
- **Passos para reproduzir** — Instrções claras
- **Comportamento esperado** — O que deveria acontecer
- **Comportamento atual** — O que realmente acontece
- **Logs de debug** — `AGILDO_DOCK_DEBUG=1 agildodock 2>&1 | head -50`

## 💡 Sugerir Melhorias

Sugestões são bem-vindas! Abra uma issue descrevendo:

- **Caso de uso** — Por que você precisa disso?
- **Solução proposta** — Como você implementaria?
- **Alternativas consideradas** — Outras formas de resolver?

## 🔧 Pull Requests

### Preparação

1. **Fork** o repositório
2. **Clone** localmente:
   ```bash
   git clone https://github.com/seu-usuario/AgildoDockCpp_Wayland.git
   cd AgildoDockCpp_Wayland
   ```
3. **Crie uma branch** para sua feature:
   ```bash
   git checkout -b feature/descricao-breve
   ```

### Desenvolvimento

1. **Siga o estilo de código** — Use `clang-format`:
   ```bash
   clang-format -i seu-arquivo.cpp
   ```

2. **Escreva testes** para novas funcionalidades
3. **Atualize documentação** conforme necessário
4. **Teste localmente**:
   ```bash
   mkdir build && cd build
   cmake -S .. -B . -DCMAKE_BUILD_TYPE=Debug
   cmake --build .
   ctest --output-on-failure
   ```

### Submissão

1. **Commit com mensagens claras**:
   ```bash
   git commit -m "feat: descrição breve da mudança"
   ```
   
   Prefixos recomendados:
   - `feat:` — Nova funcionalidade
   - `fix:` — Correção de bug
   - `docs:` — Documentação
   - `refactor:` — Refatoração sem mudança funcional
   - `perf:` — Melhorias de performance
   - `test:` — Testes

2. **Push para sua fork**:
   ```bash
   git push origin feature/descricao-breve
   ```

3. **Abra um Pull Request** no repositório original:
   - Descreva claramente as mudanças
   - Referencie issue relacionada (ex: `Fixes #123`)
   - Inclua screenshots se for UI

4. **Responda aos feedbacks** dos revisores

## 📐 Padrões de Código

### C++

```cpp
// Inclua headers necessários
#include <QObject>

// Nomes em camelCase para variáveis/funções
void processWindow(const QString &windowId)
{
    QString result = getWindowName(windowId);
    // ...
}

// Classes em PascalCase
class DockManager : public QObject
{
    Q_OBJECT
public:
    explicit DockManager(QObject *parent = nullptr);
    
private:
    void updateState();
};
```

### QML

```qml
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Item {
    id: root
    width: 400
    height: 300
    
    // Propriedades em camelCase
    property string windowTitle: ""
    
    // Sinais
    signal windowActivated(string windowId)
    
    // Funções com escopo
    function updateWindow() {
        // ...
    }
}
```

### CMake

```cmake
cmake_minimum_required(VERSION 3.16)
project(myproject VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

# Variáveis em UPPER_CASE
find_package(Qt6 REQUIRED COMPONENTS Core Gui)

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE Qt6::Core)
```

## 🧪 Testes

Toda nova funcionalidade deve incluir testes:

```cpp
// tests/test_my_feature.cpp
#include <QtTest>
#include "my_feature.h"

class TestMyFeature : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase() { }
    void testBasicFunctionality() 
    { 
        QCOMPARE(myFunction(5), 10);
    }
    void cleanupTestCase() { }
};

QTEST_MAIN(TestMyFeature)
#include "test_my_feature.moc"
```

Rode testes com:
```bash
ctest --test-dir build --output-on-failure
```

## 📚 Documentação

- Mantenha README.md atualizado
- Documente funções públicas com comentários
- Atualize CHANGELOG.md sob seção "Unreleased"

## 🚀 Processo de Release

1. Atualize versão em `CMakeLists.txt`
2. Atualize `CHANGELOG.md`
3. Crie commit: `git commit -m "chore: Bump version to 1.4.0"`
4. Crie tag: `git tag v1.4.0`
5. Push: `git push origin main --tags`
6. GitHub Actions automaticamente cria Release

## 📦 Atualizar AUR

Após release no GitHub:

```bash
cd packaging/aur
./prepare-for-aur.sh
./enviar-para-aur.sh
```

## ❓ Perguntas?

- Abra uma **Discussion** no GitHub
- Comente em uma **Issue** existente
- Revise a [documentação](README_PT.md)

---

**Obrigado por contribuir!** 🙏
