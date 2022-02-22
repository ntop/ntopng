
IF(UNIX)

FIND_PATH(NDPI_INCLUDE_DIR ndpi_api.h
  "$ENV{LIB_DIR}/include"
  "$ENV{LIB_DIR}/include/ndpi"
  "/usr/local/include/ndpi"
  "${CMAKE_SOURCE_DIR}/include"
  "${CMAKE_SOURCE_DIR}/include/ndpi"
  NO_DEFAULT_PATH
  )

SET(CMAKE_FIND_LIBRARY_PREFIXES "" "lib")
SET(CMAKE_FIND_LIBRARY_SUFFIXES ".so" ".a" ".lib")
FIND_LIBRARY(NDPI_LIBRARY NAMES libndpi PATHS
  $ENV{LIB}
  /usr/lib
  /usr/lib/x86_64-linux-gnu
  /usr/local/lib
  /usr/local/lib/ndpi
  "$ENV{LIB_DIR}/lib"
  "${CMAKE_SOURCE_DIR}/lib"
  #mingw
  c:/msys/local/lib
  NO_DEFAULT_PATH
  )
ELSE()
FIND_PATH(NDPI_INCLUDE_DIR ndpi_api.h
    "${PROJECT_ROOT}/include/ndpi"
    "/usr/local/include/ndpi"
    "/usr/include/ndpi"
  )

FILE(GLOB NDPI_LIBRARY NAMES
    "${PROJECT_ROOT}/lib/ndpi*.lib"
    "${PROJECT_ROOT}/lib/ndpi*.a"
    )
ENDIF()


IF (NDPI_INCLUDE_DIR AND NDPI_LIBRARY)
  SET(NDPI_FOUND TRUE)
ENDIF (NDPI_INCLUDE_DIR AND NDPI_LIBRARY)

MESSAGE(STATUS "NDPI Include: ${NDPI_INCLUDE_DIR}")


IF (NDPI_FOUND)
MESSAGE(STATUS "Found NDPI: ${NDPI_LIBRARY}")
ELSE (NDPI_FOUND)
MESSAGE(FATAL_ERROR "Ntop NDPI is missing. Please see https://github.com/ntop/nDPI")
ENDIF (NDPI_FOUND)