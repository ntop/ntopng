cmake_minimum_required(VERSION 3.0.0)
project(ntoptest VERSION 0.1.0)


set(CMAKE_CXX_STANDARD 98)

include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/609281088cfefc76f9d0ce82e1ff6c30cc3591e5.zip
)
# For Windows: Prevent overriding the parent project's compiler/linker settings
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_SOURCE_DIR}/cmake)
set(CURL_LIBRARY "-lcurl") 

option(MAX_MIND_DB "MaxMind Database" OFF)

find_package(Threads REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(ZeroMQ REQUIRED)
find_package(PCAP REQUIRED)
find_package(Ndpi REQUIRED)
find_package(CURL REQUIRED) 
find_package(Lua REQUIRED)
find_package(JsonC REQUIRED)
find_package(SQLite3 REQUIRED)
find_package(Hiredis REQUIRED)
find_package(Mongoose REQUIRED)
find_package(MySQL REQUIRED)
find_package(ZLIB REQUIRED)
find_package(EXPAT REQUIRED)
find_package(RRDTool REQUIRED)
if(MAX_MIND_DB) 
  find_package(MaxMindDB REQUIRED)
endif(MAX_MIND_DB)

set(LOCAL_INCLUDE ${CMAKE_SOURCE_DIR}/include ${CMAKE_SOURCE_DIR}/../third-party/include)
set(DEFAULT_DATA_DIR "/usr/local")
include_directories(${LOCAL_INCLUDE} ${ZLIB_INCLUDE_DIRS} ${CMAKE_SOURCE_DIR}/../include ${MYSQL_INCLUDE_DIR} ${OPENSSL_INCLUDE_DIR} ${HIREDIS_INCLUDE_DIR} ${SQLite3_INCLUDE_DIRS} ${ZeroMQ_INCLUDE_DIRS} ${NDPI_INCLUDE_DIR} ${PCAP_INCLUDE_DIR} ${JSONC_INCLUDE_DIR} ${LUA_INCLUDE_DIR} ${MONGOOSE_INCLUDE_DIR})
include_directories(${CURL_INCLUDE_DIR} ${RRDTOOL_INCLUDE_DIR} ${EXPAT_INCLUDE_DIRS})

file(GLOB_RECURSE INCLUDE_FILES ${CMAKE_SOURCE_DIR}/include/*.h)
file(GLOB_RECURSE SOURCE_FILES_NO_MAIN ${CMAKE_SOURCE_DIR}/src/*.cpp ${CMAKE_SOURCE_DIR}/../src/*.cpp)
list(FILTER SOURCE_FILES_NO_MAIN EXCLUDE REGEX ".*main.cpp$")

 
include(CTest)
enable_testing()
add_definitions(-DUNIT_TEST)
add_definitions(-DDATA_DIR=${DEFAULT_DATA_DIR})

# add coverage stuffs
if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --coverage")
  add_custom_target("coverage"
  COMMAND ctest
  COMMAND "ls *.gcda" --directory . --zerocounters
  COMMAND "llvm-cov gcov -f -b unit_tests.gcda" --directory .
  COMMAND "lcov" --directory . --capture --output-file coverage.info --gcov-tool ${GCOV_TOOL}
  WORKING_DIRECTORY ${CMAKE_BINARY_DIR}

  )

  # using Clang
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  # using GCC
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -lgcov -coverage")
  execute_process(COMMAND
          ${CMAKE_CXX_COMPILER} -dumpversion
          OUTPUT_VARIABLE GCC_VERSION)
  string(STRIP ${GCC_VERSION} GCC_VERSION)
  MESSAGE(STATUS "gcc version: [" ${GCC_VERSION} "]")
  set(GCOV_TOOL "llvm-gcov.sh")
  add_custom_target("coverage"
          COMMAND "lcov" --directory . --zerocounters
          COMMAND ctest
          COMMAND "lcov" --directory . --capture --output-file coverage.info --gcov-tool ${GCOV_TOOL}
          WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
          )
  add_custom_target("coverage-report"
          COMMAND "genhtml" -o coverage coverage.info
          WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
          DEPENDS "coverage")
endif()

add_executable(
  unit_tests
  ${SOURCE_FILES_NO_MAIN}
  ${CMAKE_SOURCE_DIR}/src/gtest.cpp
  ${CMAKE_SOURCE_DIR}/src/AddressResolutionTest.cpp
  ${CMAKE_SOURCE_DIR}/src/ScopedThreadPool.cpp
  ${CMAKE_SOURCE_DIR}/src/ThreadPoolTest.cpp

)
target_link_libraries( unit_tests gtest_main  ${RRDTOOL_LIBRARIES} ${CURL_LIBRARIES} ${MYSQL_LIB} ${OPENSSL_LIBRARIES} ${ZeroMQ_LIBRARIES}  ${NDPI_LIBRARY} ${PCAP_LIBRARY} ${NDPI_LIBRARY} ${LUA_LIBRARIES}  ${JSONC_LIBRARY} ${SQLite3_LIBRARIES} ${HIREDIS_LIBRARIES} ${ZLIB_LIBRARIES} ${EXPAT_LIBRARIES} Threads::Threads)


include(GoogleTest)
gtest_discover_tests(unit_tests)

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)

