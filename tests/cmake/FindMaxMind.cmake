
IF(UNIX)

FIND_PATH(MAXMINDDB_INCLUDE_DIR maxminddb.h
  "$ENV{LIB_DIR}/include"
  "$ENV{LIB_DIR}/include/maxmindb"
  "/usr/local/include/maxmindb"
  "${CMAKE_SOURCE_DIR}/include"
  "${CMAKE_SOURCE_DIR}/include/maxmindb"
  NO_DEFAULT_PATH
  )

SET(CMAKE_FIND_LIBRARY_PREFIXES "" "lib")
SET(CMAKE_FIND_LIBRARY_SUFFIXES ".so" ".a" ".lib")
FIND_LIBRARY(MAXMINDDB_LIBRARY NAMES libmaxminddb PATHS
  $ENV{LIB}
  /usr/lib
  /usr/lib/x86_64-linux-gnu
  /usr/local/lib
  /usr/local/lib/maxminddb
  "$ENV{LIB_DIR}/lib"
  "${CMAKE_SOURCE_DIR}/lib"
  #mingw
  c:/msys/local/lib
  NO_DEFAULT_PATH
  )
ELSE()
FIND_PATH(MAXMINDDB_INCLUDE_DIR maxminddb.h
    "${PROJECT_ROOT}/include/maxmind"
    "/usr/local/include/maxmind"
    "/usr/include/maxmind"
    "/usr/include"
    "/usr/local/include"
  )

FILE(GLOB MAXMINDDB_LIBRARY NAMES
    "${PROJECT_ROOT}/lib/maxmind*.lib"
    "${PROJECT_ROOT}/lib/maxmind*.a"
    )
ENDIF()


IF (MAXMINDDB_INCLUDE_DIR AND MAXMINDDB_LIBRARY)
  SET(MAXMINDDB_FOUND TRUE)
  add_definitions(-DHAVE_MAXMIND_DB)
ENDIF (MAXMINDDB_INCLUDE_DIR AND MAXMINDDB_LIBRARY)

MESSAGE(STATUS "MaxMind Include: ${MAXMINDDB_INCLUDE_DIR}")


IF (MAXMINDDB_FOUND)
MESSAGE(STATUS "Found MaxMind: ${MAXMINDDB_LIBRARY}")
ELSE (MAXMINDDB_FOUND)
MESSAGE(FATAL_ERROR "MaxMind is missing. Please see https://github.com/maxmind/libmaxminddb")
ENDIF (MAXMINDDB_FOUND)