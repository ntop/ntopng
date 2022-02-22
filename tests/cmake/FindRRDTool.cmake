# - Try to find the RRDtool library
# Once done this will define:
#
#  RRDTOOL_FOUND - system has the RRDtool library
#  RRDTOOL_INCLUDE_DIR - the RRDtool include directory
#  RRDTOOL_LIBRARIES - The libraries needed to use RRDtool
#
# Copyright (c) 2008, Benjamin Reed <ranger@opennms.org>
#
# Redistribution and use is allowed according to the terms of the BSD license.

FIND_PATH(RRDTOOL_INCLUDE_DIR rrd.h)
FIND_LIBRARY(RRDTOOL_LIBRARY NAMES rrd_th rrd)

if(RRDTOOL_LIBRARY AND RRDTOOL_INCLUDE_DIR)
	set(RRDTOOL_FOUND true)
	set(RRDTOOL_LIBRARIES ${RRDTOOL_LIBRARY} CACHE STRING "The libraries needed to use RRDTOOL")
endif(RRDTOOL_LIBRARY AND RRDTOOL_INCLUDE_DIR)

if (NOT RRDTOOL_FOUND)
	if (Rrdtool_FIND_REQUIRED)
		message(FATAL_ERROR "Could NOT find rrdtool")
	endif (Rrdtool_FIND_REQUIRED)
endif (NOT RRDTOOL_FOUND)

MARK_AS_ADVANCED(RRDTOOL_INCLUDE_DIR RRDTOOL_LIBRARIES RRDTOOL_LIBRARY)