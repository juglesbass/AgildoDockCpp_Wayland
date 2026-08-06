cmake_minimum_required(VERSION 3.16)
project(agildodock VERSION 1.5.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Oculta o aviso de ligação do módulo privado do Qt (necessário pelo Wayland/KWin)
set(QT_NO_PRIVATE_MODULE_WARNING ON)

# Flags rigorosas de aviso (compilador GCC / Clang)
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wall -Wextra -Wnon-virtual-dtor -Wshadow -Wcast-align -Wunused -Woverloaded-virtual -Wnull-dereference -Wformat=2)
endif()

# Suporte opcional a Sanitizers (-DENABLE_SANITIZERS=ON)
option(ENABLE_SANITIZERS "Habilita AddressSanitizer e UndefinedBehaviorSanitizer" OFF)
if(ENABLE_SANITIZERS)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        message(STATUS "Habilitando AddressSanitizer e UndefinedBehaviorSanitizer")
        add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
        add_link_options(-fsanitize=address,undefined)
    endif()
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui GuiPrivate Qml Quick WaylandClient Concurrent DBus Sql LinguistTools Test)
qt_policy(SET QTP0001 NEW)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6GlobalAccel REQUIRED)
find_package(KF6Kirigami REQUIRED)
find_package(LayerShellQt REQUIRED)
find_package(Wayland REQUIRED Client)
find_package(LibTaskManager REQUIRED)

set(WAYLAND_PROTOCOLS
    "/usr/share/plasma-wayland-protocols/plasma-window-management.xml"
)

add_library(agildodock_core STATIC
    taskbackend.cpp
    dock_config_manager.cpp
    dock_app_launcher.cpp
    dock_process_scanner.cpp
    taskbackend_launcher_progress.cpp
    dock_window_management.cpp
    dock_global_shortcuts.cpp
    dock_unity_launcher.cpp
    dock_browser_integration.cpp
    dock_browser_downloads.cpp
    dock_browser_utils.cpp
    kwin_dbus_helper.cpp
    plasma_wayland_manager.cpp
)

qt6_generate_wayland_protocol_client_sources(agildodock_core FILES ${WAYLAND_PROTOCOLS})
target_compile_definitions(agildodock_core PRIVATE AGILDO_DOCK_VERSION="${PROJECT_VERSION}")
target_link_libraries(agildodock_core PUBLIC
    Wayland::Client
    Qt6::Core
    Qt6::Gui
    Qt6::GuiPrivate
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Qt6::Concurrent
    Qt6::DBus
    Qt6::Sql
    KF6::WindowSystem
    KF6::GlobalAccel
    KF6::Kirigami
    LayerShellQt::Interface
    PW::LibTaskManager
)

add_executable(agildodock main.cpp)
target_link_libraries(agildodock PRIVATE agildodock_core)
target_compile_definitions(agildodock PRIVATE AGILDO_DOCK_VERSION="${PROJECT_VERSION}")

set_source_files_properties(DockConstants.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(DockTheme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt6_add_qml_module(agildodock
    URI AgildoDock
    VERSION 1.0
    QML_FILES
        main.qml
        DockConstants.qml
        DockTheme.qml
        DockAppRules.qml
        DockBlurBackground.qml
        DockSettingsWindow.qml
        LatteSliderRow.qml
        DockIconDelegate.qml
        DockIconContextMenu.qml
        DockAppMenuWindow.qml
        DockWidgetPickerWindow.qml
        DockWindowPreviewTooltip.qml
        DockOverlayLayer.qml
        DockModelsStore.qml
        DockPhysicsState.qml
    )

# Ícone embutido: fallback quando o tema do sistema ainda não indexou org.agildosoft.agildodock.
set(_agildo_icon_svg "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/scalable/apps/org.agildosoft.agildodock.svg")
set_source_files_properties("${_agildo_icon_svg}" PROPERTIES QT_RESOURCE_ALIAS "org.agildosoft.agildodock.svg")
qt_add_resources(agildodock "agildodock_app_icon"
    PREFIX "/icons"
    FILES "${_agildo_icon_svg}"
)

set(AGILDO_DOCK_QML_I18N_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/main.qml"
        DockWavePhysics.qml
        DockAutoHideController.qml
        DockModelController.qml
    "${CMAKE_CURRENT_SOURCE_DIR}/DockBlurBackground.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockSettingsWindow.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/LatteSliderRow.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockIconDelegate.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockIconContextMenu.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockAppMenuWindow.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockWidgetPickerWindow.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockWindowPreviewTooltip.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockOverlayLayer.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockModelsStore.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockPhysicsState.qml"
)

qt_add_translations(agildodock
    TS_FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/i18n/agildodock_en_US.ts"
        "${CMAKE_CURRENT_SOURCE_DIR}/i18n/agildodock_pt_PT.ts"
        "${CMAKE_CURRENT_SOURCE_DIR}/i18n/agildodock_pt_BR.ts"
    SOURCES ${AGILDO_DOCK_QML_I18N_SOURCES}
    RESOURCE_PREFIX "/i18n"
    LUPDATE_OPTIONS -locations relative
)

# --- Instalação (make install / pacotes) ---
include(GNUInstallDirs)
install(TARGETS agildodock
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/org.agildosoft.agildodock.desktop"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/scalable/apps/org.agildosoft.agildodock.svg"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps")

set(_agildo_icon_png_sizes 16 22 24 32 48 64 128 256)
find_program(_rsvg_convert rsvg-convert)
if(_rsvg_convert)
    set(_agildo_icon_svg_src "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/scalable/apps/org.agildosoft.agildodock.svg")
    set(_agildo_icon_png_outputs "")
    foreach(_sz IN LISTS _agildo_icon_png_sizes)
        set(_png_out "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/${_sz}x${_sz}/apps/org.agildosoft.agildodock.png")
        add_custom_command(
            OUTPUT "${_png_out}"
            COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/${_sz}x${_sz}/apps"
            COMMAND "${_rsvg_convert}" -w "${_sz}" -h "${_sz}" -o "${_png_out}" "${_agildo_icon_svg_src}"
            DEPENDS "${_agildo_icon_svg_src}"
            COMMENT "Gerando ícone PNG ${_sz}x${_sz}"
        )
        list(APPEND _agildo_icon_png_outputs "${_png_out}")
    endforeach()
    add_custom_target(agildodock_icons ALL DEPENDS ${_agildo_icon_png_outputs})
    add_dependencies(agildodock agildodock_icons)
endif()

foreach(_sz IN LISTS _agildo_icon_png_sizes)
    install(FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/${_sz}x${_sz}/apps/org.agildosoft.agildodock.png"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/${_sz}x${_sz}/apps")
endforeach()

install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/48x48/apps/org.agildosoft.agildodock.png"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/pixmaps"
    RENAME org.agildosoft.agildodock.png)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/metainfo/org.agildosoft.agildodock.metainfo.xml"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/metainfo")

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/licenses/${PROJECT_NAME}")

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/plasmoid/agildodock-preview/metadata.json")
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/plasmoid/agildodock-preview/"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/plasma/plasmoids/org.agildosoft.agildodock.preview")
endif()

include(CTest)
enable_testing()
add_test(NAME agildodock_version COMMAND $<TARGET_FILE:agildodock> --version)
set_tests_properties(agildodock_version PROPERTIES
    PASS_REGULAR_EXPRESSION "AgildoDock ${PROJECT_VERSION}")

add_executable(test_dock_browser_utils
    tests/test_dock_browser_utils.cpp
)
target_include_directories(test_dock_browser_utils PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(test_dock_browser_utils PRIVATE agildodock_core Qt6::Test)
add_test(NAME dock_browser_utils COMMAND test_dock_browser_utils)

add_executable(test_taskbackend
    tests/test_taskbackend.cpp
)
target_include_directories(test_taskbackend PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(test_taskbackend PRIVATE agildodock_core Qt6::Test)
add_test(NAME taskbackend COMMAND test_taskbackend)

set_tests_properties(dock_browser_utils taskbackend PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)
