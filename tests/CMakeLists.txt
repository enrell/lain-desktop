# Stub HTTP + harness compartilhados pelos testes.
add_library(lain_test_support STATIC stubserver.cpp stubserver.h)
target_link_libraries(lain_test_support PUBLIC Qt6::Network Qt6::Core)
target_include_directories(lain_test_support PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

# Cliente HTTP (ServerClient) contra o stub do gateway.
qt_add_executable(tst_serverclient tst_serverclient.cpp)
target_link_libraries(tst_serverclient PRIVATE
    lain_core lain_coreplugin lain_test_support Qt6::Test)

# Testes de QML (TestCase) com o módulo "Lain" linkado estaticamente.
qt_add_executable(tst_qml tst_qml.cpp)
target_link_libraries(tst_qml PRIVATE
    lain_core lain_coreplugin lain_test_support Qt6::QuickTest Qt6::Quick)
target_compile_definitions(tst_qml PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")

add_test(NAME serverclient COMMAND tst_serverclient)
set_tests_properties(serverclient PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_LOGGING_RULES=*.debug=false")

add_test(NAME qml COMMAND tst_qml)
set_tests_properties(qml PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_LOGGING_RULES=*.debug=false")
