cmake_minimum_required(VERSION 3.21)
project(lain_client VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml OpenGL Network QuickTest)
find_package(Qt6 6.5 QUIET COMPONENTS LinguistTools)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)
string(TIMESTAMP LAIN_BUILD_TS "%Y-%m-%d %H:%M:%S")

set_source_files_properties(qml/theme/Tokens.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# Keep the C++ core and the registered Lain QML module in one static library.
# The application and offscreen QML tests link the same implementation.
qt_add_library(lain_core STATIC)
qt_add_qml_module(lain_core
    URI Lain
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/theme/Tokens.qml
        qml/theme/Color.js
        qml/theme/Format.js
        qml/components/PageHeader.qml
        qml/components/NavRail.qml
        qml/components/MediaRow.qml
        qml/components/PosterCard.qml
        qml/components/LandscapeCard.qml
        qml/components/PersonCard.qml
        qml/components/PlayerButton.qml
        qml/components/SeekBar.qml
        qml/components/ConfirmDialog.qml
        qml/components/Hero.qml
        qml/views/HomeView.qml
        qml/views/LibraryView.qml
        qml/views/DetailView.qml
        qml/views/CollectionsView.qml
        qml/views/PlayerView.qml
        qml/views/SettingsView.qml
        qml/views/SearchOverlay.qml
        qml/views/LoginView.qml
        qml/views/SetupWizard.qml
)
target_sources(lain_core PRIVATE
    src/MpvItem.h src/MpvItem.cpp
    src/ServerClient.h src/ServerClient.cpp
    src/OmarchyTheme.h src/OmarchyTheme.cpp
    src/LocaleManager.h src/LocaleManager.cpp
    src/Provisioning.h src/Provisioning.cpp
)
target_link_libraries(lain_core PUBLIC
    Qt6::Quick Qt6::Qml Qt6::OpenGL Qt6::Network
    PkgConfig::MPV
)
target_include_directories(lain_core PUBLIC src)
target_compile_definitions(lain_core PUBLIC LAIN_BUILD_TS="${LAIN_BUILD_TS}")
target_compile_definitions(lain_core PUBLIC LAIN_VERSION="${PROJECT_VERSION}")

qt_add_executable(lain
    src/main.cpp
)
qt_add_resources(lain "lain_assets"
    PREFIX "/icons"
    BASE "packaging"
    FILES packaging/lain-desktop.png
)
target_link_libraries(lain PRIVATE lain_core lain_coreplugin)

if(Qt6LinguistTools_FOUND)
    qt_add_translations(lain
        TS_FILES translations/lain_pt_BR.ts
        RESOURCE_PREFIX "/i18n"
    )
endif()

install(PROGRAMS $<TARGET_FILE:lain>
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    DESTINATION ${CMAKE_INSTALL_BINDIR}
    RENAME lain-desktop
)
install(FILES packaging/lain-desktop.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)
install(FILES packaging/lain-desktop.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps
)

# Headless Qt Quick Test and QTest suites run through ctest.
enable_testing()
add_subdirectory(tests)
