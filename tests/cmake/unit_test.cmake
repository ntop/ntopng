# Create the unit testing executable.
# By using glob, any test source files that are added to test/ will automatically
# be added to the unit testing executable.
file(GLOB_RECURSE TEST_SOURCE_FILES ${CMAKE_SOURCE_DIR}/test/*.cc)

add_executable(unit_test ${SOURCE_FILES_NO_MAIN} ${TEST_SOURCE_FILES})
# Enable CMake `make test` support.
enable_testing()

if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  # using Clang
  target_compile_options(unit_test PRIVATE -Wall -Wextra -Werror -stdlib=libc++ -std=c++20 -g -O1 -fno-omit-frame-pointer)
  elseif (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  # using GCC
  target_compile_options(unit_test PRIVATE -Wall -Wextra -Werror -std=c++20 -fconcepts -g -O0 -fprofile-arcs -ftest-coverage)
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lgcov -coverage")
  execute_process(COMMAND
          ${CMAKE_CXX_COMPILER} -dumpversion
          OUTPUT_VARIABLE GCC_VERSION)
  string(STRIP ${GCC_VERSION} GCC_VERSION)
  MESSAGE(STATUS "gcc version: [" ${GCC_VERSION} "]")
  set(GCOV_TOOL "gcov-11")

  add_custom_target("coverage"
          COMMAND "lcov" --directory . --zerocounters
          COMMAND ctest
          COMMAND "lcov" --directory . --capture --output-file coverage.info --gcov-tool ${GCOV_TOOL}
          WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
          )
  add_custom_target("coverage-report"
          COMMAND "genhtml" -o coverage coverage.info
          WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
          DEPENDS "coverage"
          )
endif()

add_test(NAME UnitTests COMMAND unit_test)
