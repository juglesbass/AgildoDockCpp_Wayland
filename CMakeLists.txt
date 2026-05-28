cmake_minimum_required(VERSION 3.16)
project(agildodock VERSION 1.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick WaylandClient Concurrent LinguistTools DBus)
qt_policy(SET QTP0001 NEW)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6Kirigami REQUIRED)
find_package(LayerShellQt REQUIRED)
find_package(KF6GlobalAccel QUIET COMPONENTS GlobalAccel)

option(ENABLE_KWIN_EFFECT "Instalar efeito KWin (sugar ao minimizar)" OFF)

add_executable(agildodock
    main.cpp
    taskbackend.cpp
    dock_window_management.cpp
    dock_bridge.cpp
    global_shortcuts.cpp
    kwin_integration.cpp
)

qt6_add_qml_module(agildodock
    URI AgildoDock
    VERSION 1.0
    QML_FILES
        main.qml
        DockSettingsWindow.qml
        DockIconDelegate.qml
        DockWarningBanner.qml
        DockGlobalTooltip.qml
        DockWidgetStrip.qml
        DockSwipeHideArea.qml
        DockIconContextMenu.qml
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
    "${CMAKE_CURRENT_SOURCE_DIR}/DockSettingsWindow.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockIconDelegate.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockWarningBanner.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockGlobalTooltip.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockWidgetStrip.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockSwipeHideArea.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockIconContextMenu.qml"
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

target_link_libraries(agildodock PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::WaylandClient
    Qt6::Concurrent
    Qt6::DBus
    KF6::WindowSystem
    KF6::Kirigami
    LayerShellQt::Interface
)

if(TARGET KF6::GlobalAccel)
    target_link_libraries(agildodock PRIVATE KF6::GlobalAccel)
    target_compile_definitions(agildodock PRIVATE AGILDO_HAVE_KGLOBALACCEL=1)
endif()

# --- Instalação (make install / pacotes) ---
include(GNUInstallDirs)
install(TARGETS agildodock
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/org.agildosoft.agildodock.desktop"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/scalable/apps/org.agildosoft.agildodock.svg"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps")

# PNG em vários tamanhos: o editor de menus do KDE/Plasma muitas vezes ignora só SVG em scalable/.
set(_agildo_icon_png_sizes 16 22 24 32 48 64 128 256)
foreach(_sz IN LISTS _agildo_icon_png_sizes)
    install(FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/${_sz}x${_sz}/apps/org.agildosoft.agildodock.png"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/${_sz}x${_sz}/apps")
endforeach()

# Fallback legado para menus que procuram pixmap (nome sem extensão no .desktop).
install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/48x48/apps/org.agildosoft.agildodock.png"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/pixmaps"
    RENAME org.agildosoft.agildodock.png)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/metainfo/org.agildosoft.agildodock.metainfo.xml"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/metainfo")

if(ENABLE_KWIN_EFFECT)
    # Efeito do KWin (JS). Instala em share/kwin/effects/<id>/...
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/kwin-effect-suck-minimize/"
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/kwin/effects/agildodock_suck_minimize")
endif()

include(CTest)
enable_testing()
add_test(NAME agildodock_version COMMAND $<TARGET_FILE:agildodock> --version)
set_tests_properties(agildodock_version PROPERTIES PASS_REGULAR_EXPRESSION "AgildoDock 1\\.2\\.0")

if(BUILD_TESTING)
    add_executable(test_dock_matching
        tests/test_dock_matching.cpp
        dock_window_management.cpp
    )
    target_link_libraries(test_dock_matching PRIVATE
        Qt6::Core
        Qt6::Gui
        KF6::WindowSystem
        LayerShellQt::Interface
    )
    target_include_directories(test_dock_matching PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
  set_target_properties(test_dock_matching PROPERTIES EXCLUDE_FROM_ALL TRUE)
    add_test(NAME dock_matching COMMAND test_dock_matching)
endif()
