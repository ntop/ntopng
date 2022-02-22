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

find_package(Threads REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(ZeroMQ REQUIRED)
find_package(PCAP REQUIRED)
find_package(Ndpi REQUIRED)
find_package(Lua REQUIRED)
find_package(JsonC REQUIRED)
find_package(SQLite3 REQUIRED)
find_package(Hiredis REQUIRED)
find_package(Mongoose REQUIRED)

set(LOCAL_INCLUDE ${CMAKE_SOURCE_DIR}/include ${CMAKE_SOURCE_DIR}/../include ${CMAKE_SOURCE_DIR}/../third-party/include)
include_directories(${LOCAL_INCLUDE} ${OPENSSL_INCLUDE_DIR} ${HIREDIS_INCLUDE_DIR} ${SQLite3_INCLUDE_DIRS} ${ZeroMQ_INCLUDE_DIRS} ${NDPI_INCLUDE_DIR} ${PCAP_INCLUDE_DIR} ${JSONC_INCLUDE_DIR} ${LUA_INCLUDE_DIR} ${MONGOOSE_INCLUDE_DIR})
  
include(CTest)
enable_testing()
add_definitions(-DUNIT_TEST)

add_executable(
  unit_tests
  ${CMAKE_SOURCE_DIR}/src/gtest.cpp
  ${CMAKE_SOURCE_DIR}/src/AddressResolutionTest.cpp
  ${CMAKE_SOURCE_DIR}/src/ScopedThreadPool.cpp
  ${CMAKE_SOURCE_DIR}/src/ThreadPoolTest.cpp  
)
target_link_libraries(
  unit_tests
  gtest_main
)
include(GoogleTest)
gtest_discover_tests(unit_tests)

set(CPACK_PROJECT_NAME ${PROJECT_NAME})
set(CPACK_PROJECT_VERSION ${PROJECT_VERSION})
include(CPack)
