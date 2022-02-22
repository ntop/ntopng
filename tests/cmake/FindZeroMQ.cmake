set(PKG_CONFIG_USE_CMAKE_PREFIX_PATH ON)
find_package(PkgConfig)
pkg_check_modules(PC_LIBZMQ QUIET libzmq)

set(ZeroMQ_VERSION ${PC_LIBZMQ_VERSION})

find_path(ZeroMQ_INCLUDE_DIR zmq.h
        PATHS ${ZeroMQ_DIR}/include
        ${PC_LIBZMQ_INCLUDE_DIRS})

find_library(ZeroMQ_LIBRARY
        NAMES zmq
        PATHS ${ZeroMQ_DIR}/lib
        ${PC_LIBZMQ_LIBDIR}
        ${PC_LIBZMQ_LIBRARY_DIRS})

if(ZeroMQ_LIBRARY)
    set(ZeroMQ_FOUND ON)
endif()

set ( ZeroMQ_LIBRARIES ${ZeroMQ_LIBRARY} )
set ( ZeroMQ_INCLUDE_DIRS ${ZeroMQ_INCLUDE_DIR} )

if(NOT TARGET libzmq)
    add_library(libzmq UNKNOWN IMPORTED)
    set_target_properties(libzmq PROPERTIES
            IMPORTED_LOCATION ${ZeroMQ_LIBRARIES}
            INTERFACE_INCLUDE_DIRECTORIES ${ZeroMQ_INCLUDE_DIRS})
endif()

include ( FindPackageHandleStandardArgs )
# handle the QUIETLY and REQUIRED arguments and set ZMQ_FOUND to TRUE
# if all listed variables are TRUE
find_package_handle_standard_args ( ZeroMQ DEFAULT_MSG ZeroMQ_LIBRARIES ZeroMQ_INCLUDE_DIRS )
