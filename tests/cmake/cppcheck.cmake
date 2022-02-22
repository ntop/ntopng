# If Cppcheck is installed, create a target to run it on the project source files.
find_program(CPPCHECK cppcheck)
if (CPPCHECK)
    add_custom_target(
            cppcheck
            COMMAND ${CPPCHECK}
            --quiet
            --error-exitcode=1
            --enable=warning,portability,performance,style
            --std=c++11
            -I ${CMAKE_SOURCE_DIR}/include
            ${CMAKE_SOURCE_DIR}/src
    )
endif ()