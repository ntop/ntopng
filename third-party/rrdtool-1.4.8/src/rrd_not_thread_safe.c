/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 * This file:     Copyright 2003 Peter Stamfest <peter@stamfest.at> 
 *                             & Tobias Oetiker
 * Distributed under the GPL
 *****************************************************************************
 * rrd_not_thread_safe.c   Contains routines used when thread safety is not
 *                         an issue
 *****************************************************************************
 * $Id$
 *************************************************************************** */
#include "rrd.h"
#include "rrd_tool.h"
#define MAXLEN 4096
#define ERRBUFLEN 256

/* The global context is very useful in the transition period to even
   more thread-safe stuff, it can be used whereever we need a context
   and do not need to worry about concurrency. */
static rrd_context_t global_ctx = {
    "",
    ""
};

/* #include <stdarg.h> */

rrd_context_t *rrd_get_context(
    void)
{
    return &global_ctx;
}

/* how ugly that is!!! - make sure strerror is what it should be. It
   might be redefined to help in keeping other modules thread safe by
   silently turning misplaced strerror into rrd_strerror, but here
   this turns recursive! */
#undef strerror
const char *rrd_strerror(
    int err)
{
    return strerror(err);
}
