# Shared HTTP stub and test harness.
add_library(lain_test_support STATIC stubserver.cpp stubserver.h)
target_link_libraries(lain_test_support PUBLIC Qt6::Network Qt6::Core)
target_include_directories(lain_test_support PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# Exercise ServerClient against the gateway stub.
qt_add_executable(tst_serverclient tst_serverclient.cpp)
target_link_libraries(tst_serverclient PRIVATE
    lain_core lain_coreplugin lain_test_support Qt6::Test)

# Locale selection and PT-BR dictionary coverage.
qt_add_executable(tst_locale tst_locale.cpp)
target_link_libraries(tst_locale PRIVATE
    lain_core lain_coreplugin Qt6::Test)

# Provisioning detection and ownership (DD-022..DD-026).
qt_add_executable(tst_provisioning tst_provisioning.cpp)
target_link_libraries(tst_provisioning PRIVATE
    lain_core lain_coreplugin lain_test_support Qt6::Test)

# QML TestCase suites link the same static Lain module as the application.
qt_add_executable(tst_qml tst_qml.cpp)
target_link_libraries(tst_qml PRIVATE
    lain_core lain_coreplugin lain_test_support Qt6::QuickTest Qt6::Quick)
target_compile_definitions(tst_qml PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")

add_test(NAME serverclient COMMAND tst_serverclient)
set_tests_properties(serverclient PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_LOGGING_RULES=*.debug=false")

add_test(NAME locale COMMAND tst_locale)
set_tests_properties(locale PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_LOGGING_RULES=*.debug=false")

add_test(NAME provisioning COMMAND tst_provisioning)
set_tests_properties(provisioning PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_LOGGING_RULES=*.debug=false")

add_test(NAME qml COMMAND tst_qml)
set_tests_properties(qml PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_LOGGING_RULES=*.debug=false")
