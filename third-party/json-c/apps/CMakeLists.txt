
cmake_minimum_required(VERSION 2.8)  # see ../CMakeLists.txt for why 2.8

if(POLICY CMP0075)
    cmake_policy(SET CMP0075 NEW)
endif()

include(CheckSymbolExists)
include(CheckIncludeFile)
include(CMakePackageConfigHelpers)

# First, sort out whether we're running inside a json-c build,
#  or standalone, such as part of a benchmark build.

if ("${PROJECT_NAME}" STREQUAL "json-c")
# Part of an overall json-c build
set(APPS_LINK_LIBS "${PROJECT_NAME}")

# We know we have this in our current sources:
set(HAVE_JSON_TOKENER_GET_PARSE_END)

else()

# Standalone mode, using an already installed json-c library, somewhere.
# The path to the json-c install must be specified with -DCMAKE_PREFIX_PATH=...

project(apps)
find_package(PkgConfig)

# PkgConfig is supposed to include CMAKE_PREFIX_PATH in the PKG_CONFIG_PATH
#  that's used when running pkg-config, but it just doesn't work :(
# https://gitlab.kitware.com/cmake/cmake/issues/18150
#set(PKG_CONFIG_USE_CMAKE_PREFIX_PATH True)

# Instead, we handle it explicitly here and update PKG_CONFIG_PATH ourselves.
if (NOT CMAKE_PREFIX_PATH)
	message(FATAL_ERROR "Please specify -DCMAKE_PREFIX_PATH=... when running cmake.")
endif()

# Note: find_file isn't recursive :(
find_file(PC_FILE_PATH "json-c.pc"
	PATHS "${CMAKE_PREFIX_PATH}/lib64" "${CMAKE_PREFIX_PATH}/lib"
	PATH_SUFFIXES "pkgconfig"
	NO_DEFAULT_PATH)
get_filename_component(PC_DIR_PATH "${PC_FILE_PATH}" DIRECTORY)
set(ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:${PC_DIR_PATH}")
message(STATUS "PC_FILE_PATH=${PC_FILE_PATH}")
message(STATUS "PC_DIR_PATH=${PC_DIR_PATH}")

pkg_check_modules(PC_JSONC json-c)
if (PC_JSONC_FOUND)
	message(STATUS "Found json-c using pkg-config: ${PC_JSONC_PREFIX}")
	message(STATUS " PC_JSONC_INCLUDE_DIRS=${PC_JSONC_INCLUDE_DIRS}")
	message(STATUS " PC_JSONC_LIBRARIES=${PC_JSONC_LIBRARIES}")
	message(STATUS " PC_JSONC_LIBRARY_DIRS=${PC_JSONC_LIBRARY_DIRS}")
	link_directories(${PC_JSONC_LIBRARY_DIRS})
	include_directories(${PC_JSONC_INCLUDE_DIRS})
	# for target_link_libraries(...)
	set(APPS_INCLUDE_DIRS ${PC_JSONC_INCLUDE_DIRS})
	set(APPS_LINK_DIRS ${PC_JSONC_LIBRARY_DIRS})
	set(APPS_LINK_LIBS ${PC_JSONC_LIBRARIES})
else()
	message(STATUS "Using find_package to locate json-c")

	# Note: find_package needs CMAKE_PREFIX_PATH set appropriately.
	# XXX json-c's installed cmake files don't actually set up what's
	#  needed to use find_package() by itself, so we're just using it
	#  to confirm the top of the install location.
	find_package(json-c CONFIG)  # sets json-c_DIR

	# Assume json-c-config.cmake is in lib64/cmake/json-c/
	get_filename_component(json-c_TOP "${json-c_DIR}/../../.." ABSOLUTE)
	get_filename_component(json-c_LIBDIR "${json-c_DIR}/../.." ABSOLUTE)

	message(STATUS " json-c_TOP=${json-c_TOP}")
	message(STATUS " json-c_DIR=${json-c_DIR}")
	message(STATUS " json-c_LIBDIR=${json-c_LIBDIR}")

	link_directories(${json-c_LIBDIR})
	include_directories(${json-c_TOP}/include)
	include_directories(${json-c_TOP}/include/json-c)
	set(APPS_LINK_DIRS "${json-c_LIBDIR}")
	set(APPS_INCLUDE_DIRS "${json-c_TOP}/include;${json-c_TOP}/include/json-c")

	set(APPS_LINK_LIBS json-c)
endif()

set(CMAKE_REQUIRED_LINK_OPTIONS "-L${APPS_LINK_DIRS}")
set(CMAKE_REQUIRED_LIBRARIES ${APPS_LINK_LIBS})
set(CMAKE_REQUIRED_INCLUDES ${APPS_INCLUDE_DIRS})
check_symbol_exists(json_tokener_get_parse_end "json_tokener.h" HAVE_JSON_TOKENER_GET_PARSE_END)

endif() # end "standalone mode" block

# ---------------------------------

check_include_file(sys/resource.h   HAVE_SYS_RESOURCE_H) # for getrusage
if (HAVE_SYS_RESOURCE_H)
    check_symbol_exists(getrusage   "sys/resource.h" HAVE_GETRUSAGE)
endif()

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cmake/apps_config.h.in
               ${PROJECT_BINARY_DIR}/apps_config.h)
message(STATUS "Wrote ${PROJECT_BINARY_DIR}/apps_config.h")

# ---------------------------------

include_directories(PUBLIC ${CMAKE_SOURCE_DIR})
include_directories(${PROJECT_SOURCE_DIR})
include_directories(${PROJECT_BINARY_DIR})

# ---------------------------------

# Now, finally, the actual executables we're building:

add_executable(json_parse json_parse.c)
target_link_libraries(json_parse PRIVATE ${APPS_LINK_LIBS})

# Note: it is intentional that there are no install instructions here yet.
# When/if the interface of the app(s) listed here settles down enough to
# publish as part of a regular build that will be added.

