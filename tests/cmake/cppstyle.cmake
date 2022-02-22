# Check violation on Google Style.
SET (COMMAND_LINTER ${CMAKE_SOURCE_DIR}/test/cpplint.py)
    add_custom_target(
            stylelint
            COMMAND ${COMMAND_LINTER}
            --quiet
            --error-exitcode=1
            --enable=warning,portability,performance,style
            --std=c++11
            -I ${CMAKE_SOURCE_DIR}/include
            ${CMAKE_SOURCE_DIR}/src
    )
endif ()