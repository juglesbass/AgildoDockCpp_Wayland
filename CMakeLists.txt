cmake_minimum_required(VERSION 3.16)
project(agildodock VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick WaylandClient Concurrent LinguistTools)
qt_policy(SET QTP0001 NEW)
find_package(KF6WindowSystem REQUIRED)
find_package(KF6Kirigami REQUIRED)
find_package(LayerShellQt REQUIRED)

add_executable(agildodock
    main.cpp
    taskbackend.cpp
    dock_window_management.cpp
)

qt6_add_qml_module(agildodock
    URI AgildoDock
    VERSION 1.0
    QML_FILES
        main.qml
        DockSettingsWindow.qml
        DockIconDelegate.qml
)

set(AGILDO_DOCK_QML_I18N_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/main.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockSettingsWindow.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/DockIconDelegate.qml"
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
    KF6::WindowSystem
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

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/data/metainfo/org.agildosoft.agildodock.metainfo.xml"
    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/metainfo")

include(CTest)
enable_testing()
add_test(NAME agildodock_version COMMAND $<TARGET_FILE:agildodock> --version)
set_tests_properties(agildodock_version PROPERTIES PASS_REGULAR_EXPRESSION "AgildoDock 1\\.0")
