/**
 * RRDTool - src/rrd_client.c
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
 *   Sebastian tokkee Harl <sh at tokkee.org>
 **/

#include "rrd.h"
#include "rrd_tool.h"
#include "rrd_client.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef WIN32
#include <strings.h>
#endif
#include <errno.h>
#include <assert.h>
#include <pthread.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netdb.h>
#include <limits.h>

#ifndef ENODATA
#define ENODATA ENOENT
#endif

struct rrdc_response_s
{
  int status;
  char *message;
  char **lines;
  size_t lines_num;
};
typedef struct rrdc_response_s rrdc_response_t;

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static int sd = -1;
static FILE *sh = NULL;
static char *sd_path = NULL; /* cache the path for sd */

/* get_path: Return a path name appropriate to be sent to the daemon.
 *
 * When talking to a local daemon (thru a UNIX socket), relative path names
 * are resolved to absolute path names to allow for transparent integration
 * into existing solutions (as requested by Tobi). Else, absolute path names
 * are not allowed, since path name translation is done by the server.
 *
 * One must hold `lock' when calling this function. */
static const char *get_path (const char *path, char *resolved_path) /* {{{ */
{
  const char *ret = path;
  int is_unix = 0;

  if ((path == NULL) || (resolved_path == NULL) || (sd_path == NULL))
    return (NULL);

  if ((*sd_path == '/')
      || (strncmp ("unix:", sd_path, strlen ("unix:")) == 0))
    is_unix = 1;

  if (is_unix)
  {
    ret = realpath(path, resolved_path);
    if (ret == NULL)
      rrd_set_error("realpath(%s): %s", path, rrd_strerror(errno));
    return ret;
  }
  else
  {
    if (*path == '/') /* not absolute path */
    {
      rrd_set_error ("absolute path names not allowed when talking "
          "to a remote daemon");
      return NULL;
    }
  }

  return path;
} /* }}} char *get_path */

/* One must hold `lock' when calling `close_connection'. */
static void close_connection (void) /* {{{ */
{
  if (sh != NULL)
  {
    fclose (sh);
    sh = NULL;
    sd = -1;
  }
  else if (sd >= 0)
  {
    close (sd);
    sd = -1;
  }

  if (sd_path != NULL)
    free (sd_path);
  sd_path = NULL;
} /* }}} void close_connection */

static int buffer_add_string (const char *str, /* {{{ */
    char **buffer_ret, size_t *buffer_size_ret)
{
  char *buffer;
  size_t buffer_size;
  size_t buffer_pos;
  size_t i;
  int status;

  buffer = *buffer_ret;
  buffer_size = *buffer_size_ret;
  buffer_pos = 0;

  i = 0;
  status = -1;
  while (buffer_pos < buffer_size)
  {
    if (str[i] == 0)
    {
      buffer[buffer_pos] = ' ';
      buffer_pos++;
      status = 0;
      break;
    }
    else if ((str[i] == ' ') || (str[i] == '\\'))
    {
      if (buffer_pos >= (buffer_size - 1))
        break;
      buffer[buffer_pos] = '\\';
      buffer_pos++;
      buffer[buffer_pos] = str[i];
      buffer_pos++;
    }
    else
    {
      buffer[buffer_pos] = str[i];
      buffer_pos++;
    }
    i++;
  } /* while (buffer_pos < buffer_size) */

  if (status != 0)
    return (-1);

  *buffer_ret = buffer + buffer_pos;
  *buffer_size_ret = buffer_size - buffer_pos;

  return (0);
} /* }}} int buffer_add_string */

static int buffer_add_value (const char *value, /* {{{ */
    char **buffer_ret, size_t *buffer_size_ret)
{
  char temp[4096];

  if (strncmp (value, "N:", 2) == 0)
    snprintf (temp, sizeof (temp), "%lu:%s",
        (unsigned long) time (NULL), value + 2);
  else
    strncpy (temp, value, sizeof (temp));
  temp[sizeof (temp) - 1] = 0;

  return (buffer_add_string (temp, buffer_ret, buffer_size_ret));
} /* }}} int buffer_add_value */

/* Remove trailing newline (NL) and carriage return (CR) characters. Similar to
 * the Perl function `chomp'. Returns the number of characters that have been
 * removed. */
static int chomp (char *str) /* {{{ */
{
  size_t len;
  int removed;

  if (str == NULL)
    return (-1);

  len = strlen (str);
  removed = 0;
  while ((len > 0) && ((str[len - 1] == '\n') || (str[len - 1] == '\r')))
  {
    str[len - 1] = 0;
    len--;
    removed++;
  }

  return (removed);
} /* }}} int chomp */

static void response_free (rrdc_response_t *res) /* {{{ */
{
  if (res == NULL)
    return;

  if (res->lines != NULL)
  {
    size_t i;

    for (i = 0; i < res->lines_num; i++)
      if (res->lines[i] != NULL)
        free (res->lines[i]);
    free (res->lines);
  }

  free (res);
} /* }}} void response_free */

static int response_read (rrdc_response_t **ret_response) /* {{{ */
{
  rrdc_response_t *ret = NULL;
  int status = 0;

  char buffer[4096];
  char *buffer_ptr;

  size_t i;

#define DIE(code) do { status = code; goto err_out; } while(0)

  if (sh == NULL)
    DIE(-1);

  ret = (rrdc_response_t *) malloc (sizeof (rrdc_response_t));
  if (ret == NULL)
    DIE(-2);
  memset (ret, 0, sizeof (*ret));
  ret->lines = NULL;
  ret->lines_num = 0;

  buffer_ptr = fgets (buffer, sizeof (buffer), sh);
  if (buffer_ptr == NULL)
    DIE(-3);

  chomp (buffer);

  ret->status = strtol (buffer, &ret->message, 0);
  if (buffer == ret->message)
    DIE(-4);

  /* Skip leading whitespace of the status message */
  ret->message += strspn (ret->message, " \t");

  if (ret->status <= 0)
  {
    if (ret->status < 0)
      rrd_set_error("rrdcached: %s", ret->message);
    goto out;
  }

  ret->lines = (char **) malloc (sizeof (char *) * ret->status);
  if (ret->lines == NULL)
    DIE(-5);

  memset (ret->lines, 0, sizeof (char *) * ret->status);
  ret->lines_num = (size_t) ret->status;

  for (i = 0; i < ret->lines_num; i++)
  {
    buffer_ptr = fgets (buffer, sizeof (buffer), sh);
    if (buffer_ptr == NULL)
      DIE(-6);

    chomp (buffer);

    ret->lines[i] = strdup (buffer);
    if (ret->lines[i] == NULL)
      DIE(-7);
  }

out:
  *ret_response = ret;
  fflush(sh);
  return (status);

err_out:
  response_free(ret);
  close_connection();
  return (status);

#undef DIE

} /* }}} rrdc_response_t *response_read */

static int request (const char *buffer, size_t buffer_size, /* {{{ */
    rrdc_response_t **ret_response)
{
  int status;
  rrdc_response_t *res;

  if (sh == NULL)
    return (ENOTCONN);

  status = (int) fwrite (buffer, buffer_size, /* nmemb = */ 1, sh);
  if (status != 1)
  {
    close_connection ();
    rrd_set_error("request: socket error (%d) while talking to rrdcached",
                  status);
    return (-1);
  }
  fflush (sh);

  res = NULL;
  status = response_read (&res);

  if (status != 0)
  {
    if (status < 0)
      rrd_set_error("request: internal error while talking to rrdcached");
    return (status);
  }

  *ret_response = res;
  return (0);
} /* }}} int request */

/* determine whether we are connected to the specified daemon_addr if
 * NULL, return whether we are connected at all
 */
int rrdc_is_connected(const char *daemon_addr) /* {{{ */
{
  if (sd < 0)
    return 0;
  else if (daemon_addr == NULL)
  {
    /* here we have to handle the case i.e.
     *   UPDATE --daemon ...; UPDATEV (no --daemon) ...
     * In other words: we have a cached connection,
     * but it is not specified in the current command.
     * Daemon is only implied in this case if set in ENV
     */
    char *addr = getenv(ENV_RRDCACHED_ADDRESS);
    if (addr != NULL && strcmp(addr,"") != 0)
      return 1;
    else
      return 0;
  }
  else if (strcmp(daemon_addr, sd_path) == 0)
    return 1;
  else
    return 0;

} /* }}} int rrdc_is_connected */

static int rrdc_connect_unix (const char *path) /* {{{ */
{
  struct sockaddr_un sa;
  int status;

  assert (path != NULL);
  assert (sd == -1);

  sd = socket (PF_UNIX, SOCK_STREAM, /* protocol = */ 0);
  if (sd < 0)
  {
    status = errno;
    return (status);
  }

  memset (&sa, 0, sizeof (sa));
  sa.sun_family = AF_UNIX;
  strncpy (sa.sun_path, path, sizeof (sa.sun_path) - 1);

  status = connect (sd, (struct sockaddr *) &sa, sizeof (sa));
  if (status != 0)
  {
    status = errno;
    close_connection ();
    return (status);
  }

  sh = fdopen (sd, "r+");
  if (sh == NULL)
  {
    status = errno;
    close_connection ();
    return (status);
  }

  return (0);
} /* }}} int rrdc_connect_unix */

static int rrdc_connect_network (const char *addr_orig) /* {{{ */
{
  struct addrinfo ai_hints;
  struct addrinfo *ai_res;
  struct addrinfo *ai_ptr;
  char addr_copy[NI_MAXHOST];
  char *addr;
  char *port;

  assert (addr_orig != NULL);
  assert (sd == -1);

  strncpy(addr_copy, addr_orig, sizeof(addr_copy));
  addr_copy[sizeof(addr_copy) - 1] = '\0';
  addr = addr_copy;

  int status;
  memset (&ai_hints, 0, sizeof (ai_hints));
  ai_hints.ai_flags = 0;
#ifdef AI_ADDRCONFIG
  ai_hints.ai_flags |= AI_ADDRCONFIG;
#endif
  ai_hints.ai_family = AF_UNSPEC;
  ai_hints.ai_socktype = SOCK_STREAM;

  port = NULL;
  if (*addr == '[') /* IPv6+port format */
  {
    /* `addr' is something like "[2001:780:104:2:211:24ff:feab:26f8]:12345" */
    addr++;

    port = strchr (addr, ']');
    if (port == NULL)
    {
      rrd_set_error("malformed address: %s", addr_orig);
      return (-1);
    }
    *port = 0;
    port++;

    if (*port == ':')
      port++;
    else if (*port == 0)
      port = NULL;
    else
    {
      rrd_set_error("garbage after address: %s", port);
      return (-1);
    }
  } /* if (*addr == '[') */
  else
  {
    port = rindex(addr, ':');
    if (port != NULL)
    {
      *port = 0;
      port++;
    }
  }

  ai_res = NULL;
  status = getaddrinfo (addr,
                        port == NULL ? RRDCACHED_DEFAULT_PORT : port,
                        &ai_hints, &ai_res);
  if (status != 0)
  {
    rrd_set_error ("failed to resolve address `%s' (port %s): %s",
        addr, port == NULL ? RRDCACHED_DEFAULT_PORT : port,
        gai_strerror (status));
    return (-1);
  }

  for (ai_ptr = ai_res; ai_ptr != NULL; ai_ptr = ai_ptr->ai_next)
  {
    sd = socket (ai_ptr->ai_family, ai_ptr->ai_socktype, ai_ptr->ai_protocol);
    if (sd < 0)
    {
      status = errno;
      sd = -1;
      continue;
    }

    status = connect (sd, ai_ptr->ai_addr, ai_ptr->ai_addrlen);
    if (status != 0)
    {
      status = errno;
      close_connection();
      continue;
    }

    sh = fdopen (sd, "r+");
    if (sh == NULL)
    {
      status = errno;
      close_connection ();
      continue;
    }

    assert (status == 0);
    break;
  } /* for (ai_ptr) */

  freeaddrinfo(ai_res);

  return (status);
} /* }}} int rrdc_connect_network */

int rrdc_connect (const char *addr) /* {{{ */
{
  int status = 0;

  if (addr == NULL) {
    addr = getenv (ENV_RRDCACHED_ADDRESS);
  }

  if (addr == NULL || strcmp(addr,"") == 0 ) {
    addr = NULL;
    return 0;   
  }

  pthread_mutex_lock(&lock);

  if (sd >= 0 && sd_path != NULL && strcmp(addr, sd_path) == 0)
  {
    /* connection to the same daemon; use cached connection */
    pthread_mutex_unlock (&lock);
    return (0);
  }
  else
  {
    close_connection();
  }

  rrd_clear_error ();
  if (strncmp ("unix:", addr, strlen ("unix:")) == 0)
    status = rrdc_connect_unix (addr + strlen ("unix:"));
  else if (addr[0] == '/')
    status = rrdc_connect_unix (addr);
  else
    status = rrdc_connect_network(addr);

  if (status == 0 && sd >= 0)
    sd_path = strdup(addr);
  else
  {
    char *err = rrd_test_error () ? rrd_get_error () : "Internal error";
    /* err points the string that gets written to by rrd_set_error(), thus we
     * cannot pass it to that function */
    err = strdup (err);
    rrd_set_error("Unable to connect to rrdcached: %s",
                  (status < 0)
                  ? (err ? err : "Internal error")
                  : rrd_strerror (status));
    if (err != NULL)
      free (err);
  }

  pthread_mutex_unlock (&lock);
  return (status);
} /* }}} int rrdc_connect */

int rrdc_disconnect (void) /* {{{ */
{
  pthread_mutex_lock (&lock);

  close_connection();

  pthread_mutex_unlock (&lock);

  return (0);
} /* }}} int rrdc_disconnect */

int rrdc_update (const char *filename, int values_num, /* {{{ */
		const char * const *values)
{
  char buffer[4096];
  char *buffer_ptr;
  size_t buffer_free;
  size_t buffer_size;
  rrdc_response_t *res;
  int status;
  int i;
  char file_path[PATH_MAX];

  memset (buffer, 0, sizeof (buffer));
  buffer_ptr = &buffer[0];
  buffer_free = sizeof (buffer);

  status = buffer_add_string ("update", &buffer_ptr, &buffer_free);
  if (status != 0)
    return (ENOBUFS);

  pthread_mutex_lock (&lock);
  filename = get_path (filename, file_path);
  if (filename == NULL)
  {
    pthread_mutex_unlock (&lock);
    return (-1);
  }

  status = buffer_add_string (filename, &buffer_ptr, &buffer_free);
  if (status != 0)
  {
    pthread_mutex_unlock (&lock);
    return (ENOBUFS);
  }

  for (i = 0; i < values_num; i++)
  {
    status = buffer_add_value (values[i], &buffer_ptr, &buffer_free);
    if (status != 0)
    {
      pthread_mutex_unlock (&lock);
      return (ENOBUFS);
    }
  }

  assert (buffer_free < sizeof (buffer));
  buffer_size = sizeof (buffer) - buffer_free;
  assert (buffer[buffer_size - 1] == ' ');
  buffer[buffer_size - 1] = '\n';

  res = NULL;
  status = request (buffer, buffer_size, &res);
  pthread_mutex_unlock (&lock);

  if (status != 0)
    return (status);

  status = res->status;
  response_free (res);

  return (status);
} /* }}} int rrdc_update */

int rrdc_flush (const char *filename) /* {{{ */
{
  char buffer[4096];
  char *buffer_ptr;
  size_t buffer_free;
  size_t buffer_size;
  rrdc_response_t *res;
  int status;
  char file_path[PATH_MAX];

  if (filename == NULL)
    return (-1);

  memset (buffer, 0, sizeof (buffer));
  buffer_ptr = &buffer[0];
  buffer_free = sizeof (buffer);

  status = buffer_add_string ("flush", &buffer_ptr, &buffer_free);
  if (status != 0)
    return (ENOBUFS);

  pthread_mutex_lock (&lock);
  filename = get_path (filename, file_path);
  if (filename == NULL)
  {
    pthread_mutex_unlock (&lock);
    return (-1);
  }

  status = buffer_add_string (filename, &buffer_ptr, &buffer_free);
  if (status != 0)
  {
    pthread_mutex_unlock (&lock);
    return (ENOBUFS);
  }

  assert (buffer_free < sizeof (buffer));
  buffer_size = sizeof (buffer) - buffer_free;
  assert (buffer[buffer_size - 1] == ' ');
  buffer[buffer_size - 1] = '\n';

  res = NULL;
  status = request (buffer, buffer_size, &res);
  pthread_mutex_unlock (&lock);

  if (status != 0)
    return (status);

  status = res->status;
  response_free (res);

  return (status);
} /* }}} int rrdc_flush */


/* convenience function; if there is a daemon specified, or if we can
 * detect one from the environment, then flush the file.  Otherwise, no-op
 */
int rrdc_flush_if_daemon (const char *opt_daemon, const char *filename) /* {{{ */
{
  int status = 0;

  rrdc_connect(opt_daemon);

  if (rrdc_is_connected(opt_daemon))
  {
    rrd_clear_error();
    status = rrdc_flush (filename);

    if (status != 0 && !rrd_test_error())
    {
      if (status > 0)
      {
        rrd_set_error("rrdc_flush (%s) failed: %s",
                      filename, rrd_strerror(status));
      }
      else if (status < 0)
      {
        rrd_set_error("rrdc_flush (%s) failed with status %i.",
                      filename, status);
      }
    }
  } /* if (rrdc_is_connected(..)) */

  return status;
} /* }}} int rrdc_flush_if_daemon */


int rrdc_stats_get (rrdc_stats_t **ret_stats) /* {{{ */
{
  rrdc_stats_t *head;
  rrdc_stats_t *tail;

  rrdc_response_t *res;

  int status;
  size_t i;

  /* Protocol example: {{{
   * ->  STATS
   * <-  5 Statistics follow
   * <-  QueueLength: 0
   * <-  UpdatesWritten: 0
   * <-  DataSetsWritten: 0
   * <-  TreeNodesNumber: 0
   * <-  TreeDepth: 0
   * }}} */

  res = NULL;
  pthread_mutex_lock (&lock);
  status = request ("STATS\n", strlen ("STATS\n"), &res);
  pthread_mutex_unlock (&lock);

  if (status != 0)
    return (status);

  if (res->status <= 0)
  {
    response_free (res);
    return (EIO);
  }

  head = NULL;
  tail = NULL;
  for (i = 0; i < res->lines_num; i++)
  {
    char *key;
    char *value;
    char *endptr;
    rrdc_stats_t *s;

    key = res->lines[i];
    value = strchr (key, ':');
    if (value == NULL)
      continue;
    *value = 0;
    value++;

    while ((value[0] == ' ') || (value[0] == '\t'))
      value++;

    s = (rrdc_stats_t *) malloc (sizeof (rrdc_stats_t));
    if (s == NULL)
      continue;
    memset (s, 0, sizeof (*s));

    s->name = strdup (key);

    endptr = NULL;
    if ((strcmp ("QueueLength", key) == 0)
        || (strcmp ("TreeDepth", key) == 0)
        || (strcmp ("TreeNodesNumber", key) == 0))
    {
      s->type = RRDC_STATS_TYPE_GAUGE;
      s->value.gauge = strtod (value, &endptr);
    }
    else if ((strcmp ("DataSetsWritten", key) == 0)
        || (strcmp ("FlushesReceived", key) == 0)
        || (strcmp ("JournalBytes", key) == 0)
        || (strcmp ("JournalRotate", key) == 0)
        || (strcmp ("UpdatesReceived", key) == 0)
        || (strcmp ("UpdatesWritten", key) == 0))
    {
      s->type = RRDC_STATS_TYPE_COUNTER;
      s->value.counter = (uint64_t) strtoll (value, &endptr, /* base = */ 0);
    }
    else
    {
      free (s);
      continue;
    }

    /* Conversion failed */
    if (endptr == value)
    {
      free (s);
      continue;
    }

    if (head == NULL)
    {
      head = s;
      tail = s;
      s->next = NULL;
    }
    else
    {
      tail->next = s;
      tail = s;
    }
  } /* for (i = 0; i < res->lines_num; i++) */

  response_free (res);

  if (head == NULL)
#ifdef EPROTO
    return (EPROTO);
#else
    return (EINVAL);
#endif

  *ret_stats = head;
  return (0);
} /* }}} int rrdc_stats_get */

void rrdc_stats_free (rrdc_stats_t *ret_stats) /* {{{ */
{
  rrdc_stats_t *this;

  this = ret_stats;
  while (this != NULL)
  {
    rrdc_stats_t *next;

    next = this->next;

    if (this->name != NULL)
    {
      free ((char *)this->name);
      this->name = NULL;
    }
    free (this);

    this = next;
  } /* while (this != NULL) */
} /* }}} void rrdc_stats_free */

/*
 * vim: set sw=2 sts=2 ts=8 et fdm=marker :
 */
