
IF(UNIX)

FIND_PATH(JSONC_INCLUDE_DIR json.h
  "$ENV{LIB_DIR}/include"
  "$ENV{LIB_DIR}/include/json-c"
  "/usr/include/json-c"
  "/usr/local/include/json-c"
  "${CMAKE_SOURCE_DIR}/include"
  "${CMAKE_SOURCE_DIR}/include/json-c"
  NO_DEFAULT_PATH
  )

SET(CMAKE_FIND_LIBRARY_PREFIXES "" "lib")
SET(CMAKE_FIND_LIBRARY_SUFFIXES ".so" ".a" ".lib")
FIND_LIBRARY(JSONC_LIBRARY NAMES libjson-c PATHS
  $ENV{LIB}
  /usr/lib
  /usr/lib/x86_64-linux-gnu
  /usr/local/lib
  /usr/lib/json-c
  /usr/local/lib/json-c
  "$ENV{LIB_DIR}/lib"
  "${CMAKE_SOURCE_DIR}/lib"
  #mingw
  c:/msys/local/lib
  NO_DEFAULT_PATH
  )
ELSE()
FIND_PATH(JSONC_INCLUDE_DIR json.h
    "${PROJECT_ROOT}/include/json-c"
    "/usr/local/include/json-c"
    "/usr/include/json-c"
  )

FILE(GLOB JSONC_LIBRARY NAMES
    "${PROJECT_ROOT}/lib/json-c*.lib"
    "${PROJECT_ROOT}/lib/json-c*.a"
    )
ENDIF()


IF (JSONC_INCLUDE_DIR AND JSONC_LIBRARY)
  SET(JSONC_FOUND TRUE)
ENDIF (JSONC_INCLUDE_DIR AND JSONC_LIBRARY)

MESSAGE(STATUS "JSONC Include: ${JSONC_INCLUDE_DIR}")


IF (JSONC_FOUND)
MESSAGE(STATUS "Found JSONC: ${JSONC_LIBRARY}")
ELSE (JSONC_FOUND)
MESSAGE(FATAL_ERROR "JSON-C is missing")
ENDIF (JSONC_FOUND)