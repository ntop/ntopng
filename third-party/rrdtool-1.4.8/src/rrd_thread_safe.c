/*****************************************************************************
 * RRDtool 1.4.8  Copyright by Tobi Oetiker, 1997-2013
 * This file:     Copyright 2003 Peter Stamfest <peter@stamfest.at> 
 *                             & Tobias Oetiker
 * Distributed under the GPL
 *****************************************************************************
 * rrd_thread_safe.c   Contains routines used when thread safety is required
 *****************************************************************************
 * $Id$
 *************************************************************************** */

#include <pthread.h>
#include <string.h>
/* #include <error.h> */
#include "rrd.h"
#include "rrd_tool.h"

/* Key for the thread-specific rrd_context */
static pthread_key_t context_key;

/* Once-only initialisation of the key */
static pthread_once_t context_key_once = PTHREAD_ONCE_INIT;

/* Free the thread-specific rrd_context - we might actually use
   rrd_free_context instead...
 */
static void context_destroy_context(
    void *ctx_)
{
    rrd_context_t *ctx = ctx_;

    if (ctx)
        rrd_free_context(ctx);
}

/* Allocate the key */
static void context_get_key(
    void)
{
    pthread_key_create(&context_key, context_destroy_context);
}

rrd_context_t *rrd_get_context(
    void)
{
    rrd_context_t *ctx;

    pthread_once(&context_key_once, context_get_key);
    ctx = pthread_getspecific(context_key);
    if (!ctx) {
        ctx = rrd_new_context();
        pthread_setspecific(context_key, ctx);
    }
    return ctx;
}

#ifdef HAVE_STRERROR_R
const char *rrd_strerror(
    int err)
{
    rrd_context_t *ctx = rrd_get_context();
    char *ret = "unknown error";

    *ctx->lib_errstr = '\0';

    /* Even though POSIX/XSI requires "strerror_r" to return an "int", some
     * systems (e.g. the GNU libc) return a "char *" _and_ ignore the second
     * argument ... -tokkee */
#ifdef STRERROR_R_CHAR_P
    ret = strerror_r(err, ctx->lib_errstr, sizeof(ctx->lib_errstr));
    if ((! ret) || (*ret == '\0')) {
        if (*ctx->lib_errstr != '\0')
            ret = ctx->lib_errstr;
        else {
            /* according to the manpage this should not happen -
               let's handle it somehow sanely anyway */
            snprintf(ctx->lib_errstr, sizeof(ctx->lib_errstr),
                    "unknown error %i - strerror_r did not return anything",
                    err);
            ctx->lib_errstr[sizeof(ctx->lib_errstr) - 1] = '\0';
            ret = ctx->lib_errstr;
        }
    }
#else /* ! STRERROR_R_CHAR_P */
    if (strerror_r(err, ctx->lib_errstr, sizeof(ctx->lib_errstr))) {
        snprintf(ctx->lib_errstr, sizeof(ctx->lib_errstr),
                "unknown error %i - strerror_r returned with errno = %i",
                err, errno);
        ctx->lib_errstr[sizeof(ctx->lib_errstr) - 1] = '\0';
    }
    ret = ctx->lib_errstr;
#endif
    return ret;
}
#else
#undef strerror
const char *rrd_strerror(
    int err)
{
    static pthread_mutex_t mtx = PTHREAD_MUTEX_INITIALIZER;
    rrd_context_t *ctx;

    ctx = rrd_get_context();
    pthread_mutex_lock(&mtx);
    strncpy(ctx->lib_errstr, strerror(err), sizeof(ctx->lib_errstr));
    ctx->lib_errstr[sizeof(ctx->lib_errstr) - 1] = '\0';
    pthread_mutex_unlock(&mtx);
    return ctx->lib_errstr;
}
#endif
