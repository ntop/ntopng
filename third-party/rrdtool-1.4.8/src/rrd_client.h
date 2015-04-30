/**
 * RRDTool - src/rrd_client.h
 * Copyright (C) 2008 Florian octo Forster
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 *
 * Authors:
 *   Florian octo Forster <octo at verplant.org>
 **/

#ifndef __RRD_CLIENT_H
#define __RRD_CLIENT_H 1

#ifndef WIN32
# ifdef HAVE_STDINT_H
#  include <stdint.h>
# else
#   ifdef HAVE_INTTYPES_H
#      include <inttypes.h>
#   else
#      error "you should have stdint.h or inttypes.h to compile this"
#   endif
# endif
#else
#	include <stdlib.h>
	typedef signed char 	int8_t;
	typedef unsigned char 	uint8_t;
	typedef signed int 	int16_t;
	typedef unsigned int 	uint16_t;
	typedef signed long int 	int32_t;
	typedef unsigned long int 	uint32_t;
	typedef signed long long int 	int64_t;
	typedef unsigned long long int 	uint64_t;
#endif


#ifndef RRDCACHED_DEFAULT_ADDRESS
# define RRDCACHED_DEFAULT_ADDRESS "unix:/tmp/rrdcached.sock"
#endif

#define RRDCACHED_DEFAULT_PORT "42217"
#define ENV_RRDCACHED_ADDRESS "RRDCACHED_ADDRESS"


// Windows version has no daemon/client support

#ifndef WIN32
int rrdc_connect (const char *addr);
int rrdc_is_connected(const char *daemon_addr);
int rrdc_disconnect (void);

int rrdc_update (const char *filename, int values_num,
        const char * const *values);

int rrdc_flush (const char *filename);
int rrdc_flush_if_daemon (const char *opt_daemon, const char *filename);

#else
#	define rrdc_flush_if_daemon(a,b) 0
#	define rrdc_connect(a) 0
#	define rrdc_is_connected(a) 0
#	define rrdc_flush(a) 0
#	define rrdc_update(a,b,c) 0
#endif

struct rrdc_stats_s
{
  const char *name;
  uint16_t type;
#define RRDC_STATS_TYPE_GAUGE   0x0001
#define RRDC_STATS_TYPE_COUNTER 0x0002
  uint16_t flags;
  union
  {
    uint64_t counter;
    double   gauge;
  } value;
  struct rrdc_stats_s *next;
};
typedef struct rrdc_stats_s rrdc_stats_t;

int rrdc_stats_get (rrdc_stats_t **ret_stats);
void rrdc_stats_free (rrdc_stats_t *ret_stats);

#endif /* __RRD_CLIENT_H */
/*
 * vim: set sw=2 sts=2 ts=8 et fdm=marker :
 */
