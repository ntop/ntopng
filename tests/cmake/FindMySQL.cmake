# -*- indent-tabs-mode:nil; -*-
# vim: set expandtab:
#
# Copyright (c) 2011, 2020, Oracle and/or its affiliates. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2.0, as
# published by the Free Software Foundation.
#
# This program is also distributed with certain software (including
# but not limited to OpenSSL) that is licensed under separate terms,
# as designated in a particular file or component or in included license
# documentation. The authors of MySQL hereby grant you an
# additional permission to link the program and your derivative works
# with the separately licensed software that they have included with
# MySQL.
#
# Without limiting anything contained in the foregoing, this file,
# which is part of MySQL Connector/ODBC, is also subject to the
# Universal FOSS Exception, version 1.0, a copy of which can be found at
# http://oss.oracle.com/licenses/universal-foss-exception.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License, version 2.0, for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

##########################################################################

##########################################################################
#
# Configuration variables, all optional, are
#
#   MYSQL_DIR         - Set in environment or as parameter to "cmake",
#                       this is the top directory of the MySQL Server or
#                       Connector/C install
#   MYSQL_INCLUDE_DIR - Set in environment or as parameter to "cmake",
#                       this is the include directory where to find
#                       the client library
#   MYSQL_LIB_DIR     - Set in environment or as parameter to "cmake",
#                       this is the library directory where to find
#                       the client library
#   MYSQLCLIENT_STATIC_LINKING
#                     - Specify that you want static linking, dynamic
#                       linking is the default
#   MYSQLCLIENT_NO_THREADS
#                     - Specify to link against the single threaded
#                       library, "libmysqlclient". Note that in 5.5
#                       and up "libmysqlclient" is multithreaded and
#                       "libmysqlclient_r" just a soft link to it
#   MYSQL_CONFIG_EXECUTABLE
#                     - "mysql_config" executable to use
#   MYSQL_CXX_LINKAGE - Specify that client library needs C++ linking
#   MYSQL_EXTRA_LIBRARIES
#                     - Libraries to add to the linkage
#   MYSQL_CFLAGS      - C compiler flags
#   MYSQL_CXXFLAGS    - C++ compiler flags
#   MYSQL_LINK_FLAGS  - User defined extra linkage flags
#   FINDMYSQL_DEBUG   - Set if want debug output from this script
#
# Note that most variables above, if not set by the user they will be
# set by this include file.
#
# In addition, the below CMake variables are set by this include file
#
#   MYSQL_VERSION     - Three position numeric version, like 5.6.41
#   MYSQL_VERSION_ID  - Numeric padded version, 5.13.4 => 51304
#   MYSQL_NUM_VERSION - Same as MYSQL_VERSION_ID, for compatibility
#   MYSQL_LIB         - Path to the client library
#   MYSQL_LIBRARIES   - Library name, might be "-lmysqlclient" while
#                       MYSQL_LIB is the path to the library
#   MYSQL_CLIENT_LIBS - Same as MYSQL_LIBRARIES, for compatibility
#
# (1) If MYSQL_INCLUDE_DIR or MYSQL_LIB_DIR are given, these are
#     used and an error is reported if can't be used
# (2) If MYSQL_CONFIG_EXECUTABLE is given, it is used to get
#     headers and libraries
# (3) If MYSQL_DIR is given and "${MYSQL_DIR}/bin/mysql_config" is
#     found, then same as (2)
# (4) If MYSQL_DIR is given and no "${MYSQL_DIR}/bin/mysql_config",
#     search MYSQL_DIR
#
# FIXME if we get a "mysql_config" on Windows, things needs to change
# FIXME rename the VERSION variables above
# FIXME let MYSQL_VERSION include "-beta" etc?
# FIXME can mysql_config --version be C/C verson?
# FIXME if no mysql_config, find version from include/mysql_version.h?
#       #define MYSQL_SERVER_VERSION       "5.7.5-m15"
#       #define MYSQL_VERSION_ID            50705
#       #define LIBMYSQL_VERSION           "6.1.5"
#       #define LIBMYSQL_VERSION_ID         60105
# FIXME can MYSQL_LIB_DIR be a list of paths?
# FIXME is MYSQLCLIENT_LIBS a better name?
# FIXME cache variables, makes them command line args?
# FIXME really do include_directories() and link_directories()? Likely
# FIXME add check that if not static, not picked up .a or mysqlclient.lib
# FIXME MYSQL_VERSION_ID need to take into account Cluster versions
#       and Connector/C versions
# FIXME handle MYSQL_VERSION_ID, LIBMYSQL_VERSION and LIBMYSQL_VERSION_ID?
#
##########################################################################


##########################################################################
#
# Check the input data
#
##########################################################################

# If using both MYSQL_DIR as a cmake argument and set in environment,
# and not empty strings, they better be the same. Else stop and complain

set(ENV_OR_OPT_VARS
  MYSQL_DIR
  MYSQL_INCLUDE_DIR
  MYSQL_LIB_DIR
  MYSQL_LIB_DIR_LIST
  MYSQL_PLUGIN_DIR
  MYSQL_CFLAGS
  MYSQL_CXXFLAGS
  MYSQL_CONFIG_EXECUTABLE
  MYSQLCLIENT_STATIC_LINKING
  MYSQLCLIENT_NO_THREADS
  MYSQL_CXX_LINKAGE
  MYSQL_EXTRA_LIBRARIES
  MYSQL_LINK_FLAGS
)

# Mark the variable names that have values that are paths
set(ENV_OR_OPT_PATH_VARS
  MYSQL_DIR
  MYSQL_INCLUDE_DIR
  MYSQL_LIB_DIR
  MYSQL_PLUGIN_DIR
)

foreach(_xvar ${ENV_OR_OPT_VARS})

  if((DEFINED ${_xvar}) AND
     (DEFINED ENV{${_xvar}}) AND
     (NOT "${${_xvar}}" STREQUAL "") AND
     (NOT "$ENV{${_xvar}}" STREQUAL "") AND
     (NOT "$ENV{${_xvar}}" STREQUAL "${${_xvar}}"))
    message(FATAL_ERROR "Please pass -D${_xvar}=... as an argument or "
                        "set ${_xvar} in the environment, but not both")
  endif()

  # Now we know both are not set, set the CMake variable if needed
  if((DEFINED ENV{${_xvar}}) AND (NOT "$ENV{${_xvar}}" STREQUAL ""))
    set(${_xvar} $ENV{${_xvar}})
  endif()

  # Notmalize the path if the variable is set and is a path
  if(${_xvar})
    list(FIND ENV_OR_OPT_PATH_VARS ${_xvar} _index)
    if (${_index} GREATER -1)
      file(TO_CMAKE_PATH "${${_xvar}}" ${_xvar})
    endif()
  endif()

endforeach()


# Bail out if both MYSQL_DIR/MYSQL_CONFIG_EXECUTABLE and MYSQL_INCLUDE/LIB_DIR
# were given

if(MYSQL_DIR AND (MYSQL_INCLUDE_DIR OR MYSQL_LIB_DIR OR MYSQL_PLUGIN_DIR))
  message(FATAL_ERROR
    "Both MYSQL_DIR and MYSQL_INCLUDE_DIR/MYSQL_LIB_DIR/MYSQL_PLUGIN_DIR were specified,"
    " use either one or the other way of pointing at MySQL location."
  )
endif()


if (MYSQL_CONFIG_EXECUTABLE AND (MYSQL_INCLUDE_DIR OR MYSQL_LIB_DIR OR MYSQL_PLUGIN_DIR))
  message(FATAL_ERROR
    "Both MYSQL_CONFIG_EXECUTABLE and MYSQL_INCLUDE_DIR/MYSQL_LIB_DIR/MYSQL_PLUGIN_DIR were specified,"
    " mixing settings detected with mysql_config and manually set by variables"
    " is not supported and would confuse our build logic."
  )
endif()


if(MYSQL_CONFIG_EXECUTABLE)
  set(_mysql_config_set_by_user 1)
else()
  # If MYSQL_DIR is set, set MYSQL_CONFIG_EXECUTABLE
  if((NOT WIN32) AND
     (DEFINED MYSQL_DIR) AND
     (EXISTS "${MYSQL_DIR}/bin/mysql_config"))
    set(MYSQL_CONFIG_EXECUTABLE "${MYSQL_DIR}/bin/mysql_config")
    set(_mysql_config_in_mysql_dir 1)
  endif()
endif()



##########################################################################
#
# Data and basic settings
#
##########################################################################

# Set sub directory to search in
# dist = for mysql binary distributions
# build = for custom built tree

if(CMAKE_BUILD_TYPE STREQUAL Debug)
  set(_lib_suffix_dist debug)
  set(_lib_suffix_build Debug)
else()
  set(_lib_suffix_dist opt)
  set(_lib_suffix_build Release)
  add_definitions(-DNDEBUG)   # FIXME what?!
endif()

set(_exe_fallback_path
    /usr/bin
    /usr/local/bin
    /opt/mysql/mysql/bin
    /usr/local/mysql/bin
)

set(_include_fallback_path
    /usr/include/mysql
    /usr/local/include/mysql
    /opt/mysql/mysql/include
    /opt/mysql/mysql/include/mysql
    /usr/local/mysql/include
    /usr/local/mysql/include/mysql
    $ENV{ProgramFiles}/MySQL/*/include
    $ENV{SystemDrive}/MySQL/*/include
)

set(_lib_fallback_path
    /usr/lib/mysql
    /usr/local/lib/mysql
    /usr/local/mysql/lib
    /usr/local/mysql/lib/mysql
    /opt/mysql/mysql/lib
    /opt/mysql/mysql/lib/mysql
    $ENV{ProgramFiles}/MySQL/*/lib/${_lib_suffix_dist}
    $ENV{ProgramFiles}/MySQL/*/lib
    $ENV{SystemDrive}/MySQL/*/lib/${_lib_suffix_dist}
    $ENV{SystemDrive}/MySQL/*/lib
)

set(_lib_subdirs
    # Paths in build tree, really being too nice
    libmysql/${_lib_suffix_build}
    client/${_lib_suffix_build}
    libmysql_r/.libs
    libmysql/.libs
    libmysql
    # Install sub directories
    lib/mysql
    lib/${_lib_suffix_dist}   # Need to be before "lib"
    lib
)

set(_static_subdirs
    mysql
    ${_lib_suffix_dist}
)

if(MSVC90)
  set(_vs_subdir vs9)
elseif(MSVC10)
  set(_vs_subdir vs10)
elseif(MSVC11)
  set(_vs_subdir vs11)
elseif(MSVC12)
  set(_vs_subdir vs12)
elseif(MSVC13)
  set(_vs_subdir vs13)
elseif(MSVC14)
  set(_vs_subdir vs14)
elseif(MSVC15)
  set(_vs_subdir vs15)
endif()

if(_vs_subdir)
  if("${_lib_suffix_dist}" STREQUAL "debug")
    set(_vs_subdir "${_vs_subdir}/debug")
  endif()
  list(INSERT _lib_subdirs 0 "lib/${_vs_subdir}")
endif()

# For Windows, the client library name differs, so easy to
# make sure find_library() picks the right one. For Unix, it
# is the file extension that differs. In the static library
# case we know it is ".a", so we add it to the library name
# we search for to make sure it is picked in the static case.
if(WIN32)
  set(_dynamic_libs   "libmysql")
  set(_static_libs    "mysqlclient")
  set(_static_lib_ext ".lib")   # Careful, can be import library for DLL
elseif(MYSQLCLIENT_NO_THREADS)
  # In 5.1 and below there is a single threaded library
  set(_dynamic_libs   "mysqlclient")
  set(_static_libs    "libmysqlclient.a")
  set(_static_lib_ext ".a")
else()
  # We try the multithreaded "libmysqlclient_r" first and if not
  # there, pick "libmysqlclient" that in 5.5 and up is multithreaded
  # anyway (soft link "libmysqlclient_r" is not installed MySQL Server
  # 5.6 and Debian/Ubuntu and might go in 5.7 for all installs)
  set(_dynamic_libs   "mysqlclient_r"      "mysqlclient")
  set(_static_libs    "libmysqlclient_r.a" "libmysqlclient.a")
  set(_static_lib_ext ".a")
endif()

if(MYSQLCLIENT_STATIC_LINKING)
  set(_link_type   "static")
  set(_search_libs ${_static_libs})
else()
  set(_link_type   "dynamic")
  set(_search_libs ${_dynamic_libs})
endif()

# Just to pretty print in error messages
string(REPLACE ";" " " _pp_search_libs           "${_search_libs}")
string(REPLACE ";" " " _pp_lib_subdirs           "${_lib_subdirs}")
string(REPLACE ";" " " _pp_lib_fallback_path     "${_lib_fallback_path}")
string(REPLACE ";" " " _pp_include_fallback_path "${_include_fallback_path}")

message(STATUS "You will link ${_link_type}ally to the MySQL client"
               " library (set with -DMYSQLCLIENT_STATIC_LINKING=<bool>)")
message(STATUS "Searching for ${_link_type} libraries with the base name(s) \"${_pp_search_libs}\"")

##########################################################################
#
# Macros
#
##########################################################################

# ----------------------------------------------------------------------
#
# Macro that runs "mysql_config ${_opt}" and return the line after
# trimming away ending space/newline.
#
# _mysql_conf(
#   _var    - output variable name, will contain a ';' separated list
#   _opt    - the flag to give to mysql_config
#
# ----------------------------------------------------------------------

macro(_mysql_conf _var _opt)
  execute_process(
    COMMAND ${MYSQL_CONFIG_EXECUTABLE} ${_opt}
    OUTPUT_VARIABLE ${_var}
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
endmacro()

# ----------------------------------------------------------------------
#
# Macro that runs "mysql_config ${_opt}", selects output args using a
# regex, and clean it up a bit removing space/tab/newline before
# setting it to a variable.
#
# _mysql_config(
#   _var    - output variable name, will contain a ';' separated list
#   _regex  - regular expression matching the prefix of args to select
#   _opt    - the flag to give to mysql_config
#
# ----------------------------------------------------------------------

macro(_mysql_config _var _regex _opt)
  _mysql_conf(_mysql_config_output ${_opt})
  string(REGEX MATCHALL "${_regex}([^ ]+)" _mysql_config_output "${_mysql_config_output}")
  string(REGEX REPLACE "^[ \t]+" "" _mysql_config_output "${_mysql_config_output}")
  IF(CMAKE_SYSTEM_NAME MATCHES "SunOS")
    string(REGEX REPLACE " -latomic" "" _mysql_config_output "${_mysql_config_output}")
  ENDIF()
    string(REGEX REPLACE "${_regex}" "" _mysql_config_output "${_mysql_config_output}")
  separate_arguments(_mysql_config_output)
  set(${_var} ${_mysql_config_output})
endmacro()

# ----------------------------------------------------------------------
#
# Macro that runs "mysql_config ${_opt}" and selects output using a
# prefix regex. Cleans it up a bit removing space/tab/newline. Then
# removes the prefix on all in the list, and finally replace what
# matches another regular expression with a replacement string.
#
# _mysql_config_replace(
#   _var     - output variable name, will contain a ';' separated list
#   _regex1  - regular expression to match out arguments
#   _replace - what to replace match _regex1 with
#   _regex2  - regular expression matching the prefix of args to select
#   _opt     - the flag to give to mysql_config
#
# ----------------------------------------------------------------------

macro(_mysql_config_replace _var _regex1 _replace _regex2 _opt)
  _mysql_conf(_mysql_config_output ${_opt})
  string(REGEX MATCHALL "${_regex2}([^ ]+)" _mysql_config_output "${_mysql_config_output}")
  string(REGEX REPLACE "^[ \t]+" "" _mysql_config_output "${_mysql_config_output}")
  IF(CMAKE_SYSTEM_NAME MATCHES "SunOS")
    string(REGEX REPLACE " -latomic" "" _mysql_config_output "${_mysql_config_output}")
  ENDIF()
  string(REGEX REPLACE "${_regex2}" "" _mysql_config_output "${_mysql_config_output}")
  string(REGEX REPLACE "${_regex1}" "${_replace}" _mysql_config_output "${_mysql_config_output}")
  separate_arguments(_mysql_config_output)
  set(${_var} ${_mysql_config_output})
endmacro()

# ----------------------------------------------------------------------
#
# Macro to check that we found a library and that we got the right type
#
# ----------------------------------------------------------------------

macro(_check_lib_search_error _lib_dir_var _lib_var _exta_err_string)

  set(_lib     "${${_lib_var}}")
  set(_lib_dir "${${_lib_dir_var}}")

  if(FINDMYSQL_DEBUG)
    message("_lib         \"${_lib}\"")
    message("_lib_dir     \"${_lib_dir}\"")
    message("_lib_var     \"${_lib_var}\"")
    message("_lib_dir_var \"${_lib_dir_var}\"")
  endif()

  set(_err_string "Could not find ${_link_type} "
                  "\"${_pp_search_libs}\" in ${_lib_dir_var} "
                  "\"${_lib_dir}\" ${_exta_err_string}")

  if(NOT ${_lib_var})
    message(FATAL_ERROR ${_err_string})
  endif()

  # find_library() try find a shared library first, then a static
  # one. For Windows the library has a different name, but for
  # Unix only the extension differs. So we check here that we
  # got the library kind we expected.
  if(NOT WIN32)
    if(NOT MYSQLCLIENT_STATIC_LINKING)
      get_filename_component(_ext ${_lib} EXT)
      if(${_ext} STREQUAL ${_static_lib_ext})
        message(FATAL_ERROR ${_err_string})
      endif()
    endif()
  endif()
endmacro()


##########################################################################
#
# Try find MYSQL_CONFIG_EXECUTABLE if not set, and find version
#
##########################################################################

if(NOT WIN32)

  if(NOT MYSQL_CONFIG_EXECUTABLE)
    find_program(MYSQL_CONFIG_EXECUTABLE
      NAMES
        mysql_config
      DOC
        "full path of mysql_config"
      PATHS
        ${_exe_fallback_path}
    )
  endif()

  if(MYSQL_CONFIG_EXECUTABLE)
    message(STATUS "mysql_config was found ${MYSQL_CONFIG_EXECUTABLE}")

    _mysql_conf(MYSQL_VERSION "--version")
  endif()

endif()

##########################################################################
#
# Find MYSQL_INCLUDE_DIR
#
##########################################################################

if(FINDMYSQL_DEBUG AND MYSQL_INCLUDE_DIR)
  message("DBG: User gave MYSQL_INCLUDE_DIR = \"${MYSQL_INCLUDE_DIR}\"")
endif()

if(FINDMYSQL_DEBUG AND MYSQL_DIR)
  message("DBG: User gave MYSQL_DIR = \"${MYSQL_DIR}\"")
endif()

if(MYSQL_INCLUDE_DIR)

  if(FINDMYSQL_DEBUG)
    message("DBG: Using MYSQL_INCLUDE_DIR to find \"mysql.h\"")
  endif()

  if(NOT EXISTS "${MYSQL_INCLUDE_DIR}/mysql.h")
    message(FATAL_ERROR "MYSQL_INCLUDE_DIR given, but no \"mysql.h\" "
                        "in \"${MYSQL_INCLUDE_DIR}\"")
  endif()

elseif(MYSQL_DIR AND
       (NOT _mysql_config_in_mysql_dir) AND
       (NOT _mysql_config_set_by_user))

  if(FINDMYSQL_DEBUG)
    message("DBG: Using MYSQL_DIR without \"mysql_config\" to find \"mysql.h\"")
  endif()

  set(MYSQL_INCLUDE_DIR "${MYSQL_DIR}/include")
  if(NOT EXISTS "${MYSQL_INCLUDE_DIR}/mysql.h")
    message(FATAL_ERROR "MYSQL_DIR given, but no \"mysql.h\" "
                        "in \"${MYSQL_INCLUDE_DIR}\"")
  endif()

elseif(MYSQL_CONFIG_EXECUTABLE)

  if(FINDMYSQL_DEBUG)
    message("DBG: Using \"mysql_config\" to find \"mysql.h\"")
  endif()

  # This code assumes there is just one "-I...." and that
  # no space between "-I" and the path
  _mysql_config(MYSQL_INCLUDE_DIR "(^| )-I" "--include")
  if(NOT MYSQL_INCLUDE_DIR)
    message(FATAL_ERROR "Could not find the include dir from running "
                        "\"${MYSQL_CONFIG_EXECUTABLE}\"")
  endif()

  if(NOT EXISTS "${MYSQL_INCLUDE_DIR}/mysql.h")
    message(FATAL_ERROR "Could not find \"mysql.h\" in \"${MYSQL_INCLUDE_DIR}\" "
                        "found from running \"${MYSQL_CONFIG_EXECUTABLE}\"")
  endif()

else()

  if(FINDMYSQL_DEBUG)
    message("DBG: Using find_path() searching "
            "\"${_pp_include_fallback_path}\" to find \"mysql.h\"")
  endif()

  # No specific paths, try some common install paths
  find_path(MYSQL_INCLUDE_DIR mysql.h ${_include_fallback_path})

  if(NOT MYSQL_INCLUDE_DIR)
    message(FATAL_ERROR "Could not find \"mysql.h\" from searching "
                        "\"${_pp_include_fallback_path}\"")
  endif()

endif()

if(FINDMYSQL_DEBUG)
  message("DBG: MYSQL_INCLUDE_DIR = \"${MYSQL_INCLUDE_DIR}\"")
endif()

##########################################################################
#
# Find MYSQL_LIB_DIR, MYSQL_LIB, MYSQL_PLUGIN_DIR and MYSQL_LIBRARIES
#
##########################################################################

if(FINDMYSQL_DEBUG AND MYSQL_LIB_DIR)
  message("DBG: User gave MYSQL_LIB_DIR = \"${MYSQL_LIB_DIR}\"")
endif()

if(MYSQL_LIB_DIR)

  if(FINDMYSQL_DEBUG)
    message("DBG: Using find_library() searching MYSQL_LIB_DIR")
  endif()

  find_library(MYSQL_LIB
    NAMES
      ${_search_libs}
    PATHS
      "${MYSQL_LIB_DIR}"
    NO_DEFAULT_PATH
  )
  _check_lib_search_error(MYSQL_LIB_DIR MYSQL_LIB "")
  set(MYSQL_LIBRARIES ${MYSQL_LIB})

  if(NOT DEFINED MYSQL_PLUGIN_DIR)
    set(MYSQL_PLUGIN_DIR "${MYSQL_LIB_DIR}/plugin")
  endif()

elseif(MYSQL_DIR AND
       (NOT _mysql_config_in_mysql_dir) AND
       (NOT _mysql_config_set_by_user))

  if(FINDMYSQL_DEBUG)
    message("DBG: Using find_library() searching "
            "MYSQL_DIR and \"${_pp_lib_subdirs}\"")
  endif()

  find_library(MYSQL_LIB
    NAMES
      ${_search_libs}
    PATHS
      "${MYSQL_DIR}"
    PATH_SUFFIXES
      ${_lib_subdirs}
    NO_DEFAULT_PATH
  )
  _check_lib_search_error(MYSQL_DIR MYSQL_LIB "in \"${_pp_lib_subdirs}\"")
  get_filename_component(MYSQL_LIB_DIR "${MYSQL_LIB}" PATH)
  set(MYSQL_LIBRARIES "${MYSQL_LIB}")

  if(NOT DEFINED MYSQL_PLUGIN_DIR AND MYSQL_LIB_DIR)
    set(MYSQL_PLUGIN_DIR "${MYSQL_LIB_DIR}/plugin")
  endif()

elseif(MYSQL_CONFIG_EXECUTABLE)

  if(FINDMYSQL_DEBUG)
    message("DBG: Using \"mysql_config\" to find the libraries")
  endif()

  # This code assumes there is just one "-L...." and that
  # no space between "-L" and the path
  _mysql_config(MYSQL_LIB_DIR "(^| )-L" "--libs")
  _mysql_conf(MYSQL_PLUGIN_DIR  "--variable=plugindir")

  IF(CMAKE_SYSTEM_NAME MATCHES "SunOS")
    # This is needed to make Solaris binaries using the default runtime lib path
    _mysql_config(DEV_STUDIO_RUNTIME_DIR "(^| )-R" "--libs")
  ENDIF()


  LIST(LENGTH MYSQL_LIB_DIR dir_cnt)
  MESSAGE(STATUS "Libraries paths found: ${n}")
  IF(${dir_cnt} GREATER 1)
    SET(MYSQL_LIB_DIR_LIST ${MYSQL_LIB_DIR})
    MESSAGE(STATUS "MYSQL_LIB_DIR_LIST = ${MYSQL_LIB_DIR_LIST}")

    FOREACH(_path_to_check IN LISTS MYSQL_LIB_DIR)
      FIND_LIBRARY(_mysql_client_lib_var
        NAMES ${_search_libs}
        PATHS ${_path_to_check}
        NO_DEFAULT_PATH
      )
      IF(_mysql_client_lib_var)
        MESSAGE(STATUS "CLIENT LIB VAR: ${_mysql_client_lib_var}")
        unset(_mysql_client_lib_var CACHE)
        set(MYSQL_LIB_DIR ${_path_to_check})
      ENDIF()
    ENDFOREACH(_path_to_check)
  ENDIF()

  if(NOT MYSQL_LIB_DIR)
    message(FATAL_ERROR "Could not find the library dir from running "
                        "\"${MYSQL_CONFIG_EXECUTABLE}\"")
  endif()

  if(NOT EXISTS "${MYSQL_LIB_DIR}")
    message(FATAL_ERROR "Could not find the directory \"${MYSQL_LIB_DIR}\" "
                        "found from running \"${MYSQL_CONFIG_EXECUTABLE}\"")
  endif()

  # We have the assumed MYSQL_LIB_DIR. The output from "mysql_config"
  # might not be correct for static libraries, so we might need to
  # adjust MYSQL_LIB_DIR later on.

  if(MYSQLCLIENT_STATIC_LINKING)

    # Find the static library, might be one level down
    find_library(MYSQL_LIB
      NAMES
        ${_search_libs}
      PATHS
        ${MYSQL_LIB_DIR}
      PATH_SUFFIXES
        ${_static_subdirs}
      NO_DEFAULT_PATH
    )
    _check_lib_search_error(MYSQL_LIB_DIR MYSQL_LIB "in \"${_static_subdirs}\"")

    # Adjust MYSQL_LIB_DIR in case it changes
    get_filename_component(MYSQL_LIB_DIR "${MYSQL_LIB}" PATH)

    # Replace the current library references with the full path
    # to the library, i.e. the -L will be ignored
    _mysql_config_replace(MYSQL_LIBRARIES
           "(mysqlclient|mysqlclient_r)" "${MYSQL_LIB}" "(^| )-l" "--libs")

  else()

    _mysql_config(MYSQL_LIBRARIES "(^| )-l" "--libs")
    FOREACH(__lib IN LISTS MYSQL_LIBRARIES)
      string(REGEX MATCH "mysqlclient([^ ]*)" _matched_lib __lib)
      IF(_matched_lib)
        set(_search_libs ${matched_lib})
      ENDIF()
    ENDFOREACH()
    # First library is assumed to be the client library
    # list(GET MYSQL_LIBRARIES 0 _search_libs)
    find_library(MYSQL_LIB
      NAMES
        ${_search_libs}
      PATHS
        ${MYSQL_LIB_DIR}
      NO_DEFAULT_PATH
    )
    _check_lib_search_error(MYSQL_LIB_DIR MYSQL_LIB "")

  endif()

else()

  if(FINDMYSQL_DEBUG)
    message("DBG: Using find_library() searching "
            "\"${_pp_lib_fallback_path}\" to find the client library")
  endif()

  # Search standard places
  find_library(MYSQL_LIB
    NAMES
      ${_search_libs}
    PATHS
      ${_lib_fallback_path}
  )
  if(NOT MYSQL_LIB)
    message(FATAL_ERROR "Could not find \"${_pp_search_libs}\" from searching "
                        "\"${_pp_lib_fallback_path}\"")
  endif()

  get_filename_component(MYSQL_LIB_DIR "${MYSQL_LIB}" PATH)

endif()

##########################################################################
#
# Add more libraries to MYSQL_LIBRARIES
#
##########################################################################

# FIXME needed?!
if(MYSQLCLIENT_STATIC_LINKING AND
   NOT WIN32 AND
   NOT ${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
  list(APPEND MYSQL_LIBRARIES "rt")
endif()

# For dynamic linking use the built-in sys and strings
if(NOT MYSQLCLIENT_STATIC_LINKING)
   list(APPEND SYS_LIBRARIES "mysql_sys")
   list(APPEND SYS_LIBRARIES "mysql_strings")
   list(APPEND SYS_LIBRARIES ${MYSQL_LIBRARIES})
   SET(MYSQL_LIBRARIES ${SYS_LIBRARIES})

#if(NOT MYSQLCLIENT_STATIC_LINKING AND ${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
#  list(REVERSE MYSQL_LIBRARIES)
#endif()

endif()

if(MYSQL_EXTRA_LIBRARIES)
  separate_arguments(MYSQL_EXTRA_LIBRARIES)
  list(APPEND MYSQL_LIBRARIES ${MYSQL_EXTRA_LIBRARIES})
endif()

list(LENGTH MYSQL_LIBRARIES len)
if (MYSQL_STATIC_LINKING AND (len LESS 2))
  message(WARNING
    "Statically linking MySQL client library normally requires linking"
    " additional libraries that the client library depends on. It seems"
    " no extra libraries have been specified. Provide the list of required"
    " dependencies through MYSQL_EXTRA_LIBRARIES."
  )
endif()

# For compatibility
SET(MYSQL_CLIENT_LIBS ${MYSQL_LIBRARIES})

##########################################################################
#
# If not found MySQL Serverv version, compile a small client app
# and let it write a small cmake file with the settings
#
##########################################################################

if(MYSQL_INCLUDE_DIR AND NOT MYSQL_VERSION)

  # Write the C source file that will include the MySQL headers
  set(GETMYSQLVERSION_SOURCEFILE "${CMAKE_CURRENT_BINARY_DIR}/getmysqlversion.c")
  file(WRITE "${GETMYSQLVERSION_SOURCEFILE}"
       "#include <mysql.h>\n"
       "#include <stdio.h>\n"
       "int main() {\n"
       "  printf(\"%s\", MYSQL_SERVER_VERSION);\n"
       "}\n"
  )

  # Compile and run the created executable, store output in MYSQL_VERSION
  try_run(_run_result _compile_result
    "${CMAKE_BINARY_DIR}"
    "${GETMYSQLVERSION_SOURCEFILE}"
    CMAKE_FLAGS "-DINCLUDE_DIRECTORIES:STRING=${MYSQL_INCLUDE_DIR}"
    RUN_OUTPUT_VARIABLE MYSQL_VERSION
  )

  if(FINDMYSQL_DEBUG)
    if(NOT _compile_result)
      message("DBG: Could not compile \"getmysqlversion.c\"")
    endif()
    if(_run_result)
      message("DBG: Running \"getmysqlversion\" returned ${_run_result}")
    endif()
  endif()

endif()

##########################################################################
#
# Clean up MYSQL_VERSION and create MYSQL_VERSION_ID/MYSQL_NUM_VERSION
#
##########################################################################

if(NOT MYSQL_VERSION)
  message(FATAL_ERROR "Could not determine the MySQL Server version")
endif()

# Clean up so only numeric, in case of "-alpha" or similar
string(REGEX MATCHALL "([0-9]+.[0-9]+.[0-9]+)" MYSQL_VERSION "${MYSQL_VERSION}")
# To create a fully numeric version, first normalize so N.NN.NN
string(REGEX REPLACE "[.]([0-9])[.]" ".0\\1." MYSQL_VERSION_ID "${MYSQL_VERSION}")
string(REGEX REPLACE "[.]([0-9])$"   ".0\\1"  MYSQL_VERSION_ID "${MYSQL_VERSION_ID}")
# Finally remove the dot
string(REGEX REPLACE "[.]" "" MYSQL_VERSION_ID "${MYSQL_VERSION_ID}")
set(MYSQL_NUM_VERSION ${MYSQL_VERSION_ID})

##########################################################################
#
# Try determine if to use C++ linkage, and also find C++ flags
#
##########################################################################

if(NOT WIN32)

  if(MYSQL_CONFIG_EXECUTABLE)

    if(NOT MYSQL_CFLAGS)
      _mysql_conf(MYSQL_CFLAGS "--cflags")
    endif()

    if(NOT MYSQL_CXXFLAGS)
      if(MYSQL_CXX_LINKAGE OR MYSQL_VERSION_ID GREATER 50603)
        _mysql_conf(MYSQL_CXXFLAGS "--cxxflags")
        set(MYSQL_CXX_LINKAGE 1)
      else()
        set(MYSQL_CXXFLAGS "${MYSQL_CFLAGS}")
      endif()
    endif()

# FIXME this should not be needed, caller of this module should set
#       it's own flags and just use the library on it's on terms
#       (change the infe message if enabling this code)
#   if(NOT MYSQL_LINK_FLAGS)
#     # Find -mcpu -march -mt -m32 -m64 and other flags starting with "-m"
#     string(REGEX MATCHALL "(^| )-m([^\r\n ]+)" MYSQL_LINK_FLAGS "${MYSQL_CXXFLAGS}")
#     string(REGEX REPLACE "^ " ""  MYSQL_LINK_FLAGS "${MYSQL_LINK_FLAGS}")
#     string(REGEX REPLACE "; " ";" MYSQL_LINK_FLAGS "${MYSQL_LINK_FLAGS}")
#   endif()

  endif()

endif()

##########################################################################
#
# Inform CMake where to look for headers and libraries
#
##########################################################################

# string(TOUPPER "${CMAKE_BUILD_TYPE}" CMAKEBT)
# set(CMAKE_CXX_FLAGS                "${CMAKE_CXX_FLAGS} ${MYSQL_CXXFLAGS}")
# set(CMAKE_CXX_FLAGS_${CMAKEBT}     "${CMAKE_CXX_FLAGS_${CMAKEBT}} ${MYSQL_CXXFLAGS}")

include_directories("${MYSQL_INCLUDE_DIR}")

link_directories("${MYSQL_LIB_DIR}")

MESSAGE(STATUS "MYSQL_LIB_DIR_LIST = ${MYSQL_LIB_DIR_LIST}")
IF(MYSQL_LIB_DIR_LIST)
  FOREACH(__libpath IN LISTS MYSQL_LIB_DIR_LIST)
    link_directories("${__libpath}")
  ENDFOREACH()
ENDIF()



##########################################################################
#
# Report
#
##########################################################################

message(STATUS "MySQL client environment/cmake variables set that the user can override")

message(STATUS "  MYSQL_DIR                   : ${MYSQL_DIR}")
message(STATUS "  MYSQL_INCLUDE_DIR           : ${MYSQL_INCLUDE_DIR}")
message(STATUS "  MYSQL_LIB_DIR               : ${MYSQL_LIB_DIR}")
message(STATUS "  MYSQL_PLUGIN_DIR            : ${MYSQL_PLUGIN_DIR}")
message(STATUS "  MYSQL_CONFIG_EXECUTABLE     : ${MYSQL_CONFIG_EXECUTABLE}")
message(STATUS "  MYSQL_CXX_LINKAGE           : ${MYSQL_CXX_LINKAGE}")
message(STATUS "  MYSQL_CFLAGS                : ${MYSQL_CFLAGS}")
message(STATUS "  MYSQL_CXXFLAGS              : ${MYSQL_CXXFLAGS}")
message(STATUS "  MYSQLCLIENT_STATIC_LINKING  : ${MYSQLCLIENT_STATIC_LINKING}")
message(STATUS "  MYSQLCLIENT_NO_THREADS      : ${MYSQLCLIENT_NO_THREADS}")

message(STATUS "MySQL client optional environment/cmake variables set by the user")

message(STATUS "  MYSQL_EXTRA_LIBRARIES       : ${MYSQL_EXTRA_LIBRARIES}")
message(STATUS "  MYSQL_LINK_FLAGS            : ${MYSQL_LINK_FLAGS}")

message(STATUS "MySQL client settings that the user can't override")

message(STATUS "  MYSQL_VERSION               : ${MYSQL_VERSION}")
message(STATUS "  MYSQL_VERSION_ID            : ${MYSQL_VERSION_ID}")
message(STATUS "  MYSQL_LIB                   : ${MYSQL_LIB}")
message(STATUS "  MYSQL_LIBRARIES             : ${MYSQL_LIBRARIES}")
