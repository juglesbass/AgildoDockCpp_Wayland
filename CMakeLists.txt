cmake_minimum_required(VERSION 3.16)
project(agildodock VERSION 1.3 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick WaylandClient Concurrent DBus LinguistTools)
qt_policy(SET QTP0001 NEW)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6GlobalAccel REQUIRED)
find_package(KF6Kirigami REQUIRED)
find_package(LayerShellQt REQUIRED)

add_executable(agildodock
    main.cpp
    taskbackend.cpp
    dock_window_management.cpp
    dock_global_shortcuts.cpp
)

qt6_add_qml_module(agildodock
    URI AgildoDock
    VERSION 1.0
    QML_FILES
        main.qml
        DockSettingsWindow.qml
        DockIconDelegate.qml
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
    KF6::GlobalAccel
    KF6::Kirigami
    LayerShellQt::Interface
)

# --- Instalação (make install / pacotes) ---
include(GNUInstallDirs)
install(TARGETS agildodock
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/org.agildosoft.agildodock.desktop"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/scalable/apps/org.agildosoft.agildodock.svg"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps")

# PNG em vários tamanhos: o editor de menus do KDE/Plasma muitas vezes ignora só SVG em scalable/.
# Se rsvg-convert estiver disponível, os PNGs são gerados automaticamente no configure; caso
# contrário, espera-se que já existam (gerados por packaging/generate_icons.sh).
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

# Fallback legado para menus que procuram pixmap (nome sem extensão no .desktop).
install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/data/icons/hicolor/48x48/apps/org.agildosoft.agildodock.png"
    DESTINATION "${CMAKE_INSTALL_DATADIR}/pixmaps"
    RENAME org.agildosoft.agildodock.png)

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/metainfo/org.agildosoft.agildodock.metainfo.xml"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/metainfo")

include(CTest)
enable_testing()
add_test(NAME agildodock_version COMMAND $<TARGET_FILE:agildodock> --version)
set_tests_properties(agildodock_version PROPERTIES PASS_REGULAR_EXPRESSION "AgildoDock 1\\.0")
