/**
 * RRDTool - src/rrd_daemon.c
 * Copyright (C) 2008,2009 Florian octo Forster
 * Copyright (C) 2008,2009 Kevin Brintnall
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; only version 2 of the License is applicable.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
 *
 * Authors:
 *   Florian octo Forster <octo at verplant.org>
 *   kevin brintnall <kbrint@rufus.net>
 **/

#if 0
/*
 * First tell the compiler to stick to the C99 and POSIX standards as close as
 * possible.
 */
#ifndef __STRICT_ANSI__ /* {{{ */
# define __STRICT_ANSI__
#endif

#ifndef _ISOC99_SOURCE
# define _ISOC99_SOURCE
#endif

#ifdef _POSIX_C_SOURCE
# undef _POSIX_C_SOURCE
#endif
#define _POSIX_C_SOURCE 200112L

/* Single UNIX needed for strdup. */
#ifdef _XOPEN_SOURCE
# undef _XOPEN_SOURCE
#endif
#define _XOPEN_SOURCE 500

#ifndef _REENTRANT
# define _REENTRANT
#endif

#ifndef _THREAD_SAFE
# define _THREAD_SAFE
#endif

#ifdef _GNU_SOURCE
# undef _GNU_SOURCE
#endif
/* }}} */
#endif /* 0 */

/*
 * Now for some includes..
 */
/* {{{ */
#include "rrd_tool.h"
#include "rrd_client.h"
#include "unused.h"

#include <stdlib.h>

#ifndef WIN32
#ifdef HAVE_STDINT_H
#  include <stdint.h>
#endif
#include <unistd.h>
#include <strings.h>
#include <inttypes.h>
#include <sys/socket.h>

#else

#endif
#include <stdio.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/un.h>
#include <netdb.h>
#include <poll.h>
#include <syslog.h>
#include <pthread.h>
#include <errno.h>
#include <assert.h>
#include <sys/time.h>
#include <time.h>
#include <libgen.h>
#include <grp.h>

#ifdef HAVE_LIBWRAP
#include <tcpd.h>
#endif /* HAVE_LIBWRAP */

#include <glib.h>
/* }}} */

#define RRDD_LOG(severity, ...) \
  do { \
    if (stay_foreground) { \
      fprintf(stderr, __VA_ARGS__); \
      fprintf(stderr, "\n"); } \
    syslog ((severity), __VA_ARGS__); \
  } while (0)

/*
 * Types
 */
typedef enum { RESP_ERR = -1, RESP_OK = 0 } response_code;

struct listen_socket_s
{
  int fd;
  char addr[PATH_MAX + 1];
  int family;

  /* state for BATCH processing */
  time_t batch_start;
  int batch_cmd;

  /* buffered IO */
  char *rbuf;
  off_t next_cmd;
  off_t next_read;

  char *wbuf;
  ssize_t wbuf_len;

  uint32_t permissions;

  gid_t  socket_group;
  mode_t socket_permissions;
};
typedef struct listen_socket_s listen_socket_t;

struct command_s;
typedef struct command_s command_t;
/* note: guard against "unused" warnings in the handlers */
#define DISPATCH_PROTO	listen_socket_t UNUSED(*sock),\
			time_t UNUSED(now),\
			char  UNUSED(*buffer),\
			size_t UNUSED(buffer_size)

#define HANDLER_PROTO	command_t UNUSED(*cmd),\
			DISPATCH_PROTO

struct command_s {
  char   *cmd;
  int (*handler)(HANDLER_PROTO);

  char  context;		/* where we expect to see it */
#define CMD_CONTEXT_CLIENT	(1<<0)
#define CMD_CONTEXT_BATCH	(1<<1)
#define CMD_CONTEXT_JOURNAL	(1<<2)
#define CMD_CONTEXT_ANY		(0x7f)

  char *syntax;
  char *help;
};

struct cache_item_s;
typedef struct cache_item_s cache_item_t;
struct cache_item_s
{
  char *file;
  char **values;
  size_t values_num;
  time_t last_flush_time;
  double last_update_stamp;
#define CI_FLAGS_IN_TREE  (1<<0)
#define CI_FLAGS_IN_QUEUE (1<<1)
  int flags;
  pthread_cond_t  flushed;
  cache_item_t *prev;
  cache_item_t *next;
};

struct callback_flush_data_s
{
  time_t now;
  time_t abs_timeout;
  char **keys;
  size_t keys_num;
};
typedef struct callback_flush_data_s callback_flush_data_t;

enum queue_side_e
{
  HEAD,
  TAIL
};
typedef enum queue_side_e queue_side_t;

/* describe a set of journal files */
typedef struct {
  char **files;
  size_t files_num;
} journal_set;

/* max length of socket command or response */
#define CMD_MAX 4096
#define RBUF_SIZE (CMD_MAX*2)

/*
 * Variables
 */
static int stay_foreground = 0;
static uid_t daemon_uid;

static listen_socket_t *listen_fds = NULL;
static size_t listen_fds_num = 0;

static listen_socket_t default_socket;

enum {
  RUNNING,		/* normal operation */
  FLUSHING,		/* flushing remaining values */
  SHUTDOWN		/* shutting down */
} state = RUNNING;

static pthread_t *queue_threads;
static pthread_cond_t queue_cond = PTHREAD_COND_INITIALIZER;
static int config_queue_threads = 4;

static pthread_t flush_thread;
static pthread_cond_t flush_cond = PTHREAD_COND_INITIALIZER;

static pthread_mutex_t connection_threads_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t  connection_threads_done = PTHREAD_COND_INITIALIZER;
static int connection_threads_num = 0;

/* Cache stuff */
static GTree          *cache_tree = NULL;
static cache_item_t   *cache_queue_head = NULL;
static cache_item_t   *cache_queue_tail = NULL;
static pthread_mutex_t cache_lock = PTHREAD_MUTEX_INITIALIZER;

static int config_write_interval = 300;
static int config_write_jitter   = 0;
static int config_flush_interval = 3600;
static int config_flush_at_shutdown = 0;
static char *config_pid_file = NULL;
static char *config_base_dir = NULL;
static size_t _config_base_dir_len = 0;
static int config_write_base_only = 0;

static listen_socket_t **config_listen_address_list = NULL;
static size_t config_listen_address_list_len = 0;

static uint64_t stats_queue_length = 0;
static uint64_t stats_updates_received = 0;
static uint64_t stats_flush_received = 0;
static uint64_t stats_updates_written = 0;
static uint64_t stats_data_sets_written = 0;
static uint64_t stats_journal_bytes = 0;
static uint64_t stats_journal_rotate = 0;
static pthread_mutex_t stats_lock = PTHREAD_MUTEX_INITIALIZER;

/* Journaled updates */
#define JOURNAL_REPLAY(s) ((s) == NULL)
#define JOURNAL_BASE "rrd.journal"
static journal_set *journal_cur = NULL;
static journal_set *journal_old = NULL;
static char *journal_dir = NULL;
static FILE *journal_fh = NULL;		/* current journal file handle */
static long  journal_size = 0;		/* current journal size */
#define JOURNAL_MAX (1 * 1024 * 1024 * 1024)
static pthread_mutex_t journal_lock = PTHREAD_MUTEX_INITIALIZER;
static int journal_write(char *cmd, char *args);
static void journal_done(void);
static void journal_rotate(void);

/* prototypes for forward refernces */
static int handle_request_help (HANDLER_PROTO);

/* 
 * Functions
 */
static void sig_common (const char *sig) /* {{{ */
{
  RRDD_LOG(LOG_NOTICE, "caught SIG%s", sig);
  if (state == RUNNING) {
      state = FLUSHING;
  }
  pthread_cond_broadcast(&flush_cond);
  pthread_cond_broadcast(&queue_cond);
} /* }}} void sig_common */

static void sig_int_handler (int UNUSED(s)) /* {{{ */
{
  sig_common("INT");
} /* }}} void sig_int_handler */

static void sig_term_handler (int UNUSED(s)) /* {{{ */
{
  sig_common("TERM");
} /* }}} void sig_term_handler */

static void sig_usr1_handler (int UNUSED(s)) /* {{{ */
{
  config_flush_at_shutdown = 1;
  sig_common("USR1");
} /* }}} void sig_usr1_handler */

static void sig_usr2_handler (int UNUSED(s)) /* {{{ */
{
  config_flush_at_shutdown = 0;
  sig_common("USR2");
} /* }}} void sig_usr2_handler */

static void install_signal_handlers(void) /* {{{ */
{
  /* These structures are static, because `sigaction' behaves weird if the are
   * overwritten.. */
  static struct sigaction sa_int;
  static struct sigaction sa_term;
  static struct sigaction sa_pipe;
  static struct sigaction sa_usr1;
  static struct sigaction sa_usr2;

  /* Install signal handlers */
  memset (&sa_int, 0, sizeof (sa_int));
  sa_int.sa_handler = sig_int_handler;
  sigaction (SIGINT, &sa_int, NULL);

  memset (&sa_term, 0, sizeof (sa_term));
  sa_term.sa_handler = sig_term_handler;
  sigaction (SIGTERM, &sa_term, NULL);

  memset (&sa_pipe, 0, sizeof (sa_pipe));
  sa_pipe.sa_handler = SIG_IGN;
  sigaction (SIGPIPE, &sa_pipe, NULL);

  memset (&sa_pipe, 0, sizeof (sa_usr1));
  sa_usr1.sa_handler = sig_usr1_handler;
  sigaction (SIGUSR1, &sa_usr1, NULL);

  memset (&sa_usr2, 0, sizeof (sa_usr2));
  sa_usr2.sa_handler = sig_usr2_handler;
  sigaction (SIGUSR2, &sa_usr2, NULL);

} /* }}} void install_signal_handlers */

static int open_pidfile(char *action, int oflag) /* {{{ */
{
  int fd;
  const char *file;
  char *file_copy, *dir;

  file = (config_pid_file != NULL)
    ? config_pid_file
    : LOCALSTATEDIR "/run/rrdcached.pid";

  /* dirname may modify its argument */
  file_copy = strdup(file);
  if (file_copy == NULL)
  {
    fprintf(stderr, "rrdcached: strdup(): %s\n",
        rrd_strerror(errno));
    return -1;
  }

  dir = dirname(file_copy);
  if (rrd_mkdir_p(dir, 0777) != 0)
  {
    fprintf(stderr, "Failed to create pidfile directory '%s': %s\n",
        dir, rrd_strerror(errno));
    return -1;
  }

  free(file_copy);

  fd = open(file, oflag, S_IWUSR|S_IRUSR|S_IRGRP|S_IROTH);
  if (fd < 0)
    fprintf(stderr, "rrdcached: can't %s pid file '%s' (%s)\n",
            action, file, rrd_strerror(errno));

  return(fd);
} /* }}} static int open_pidfile */

/* check existing pid file to see whether a daemon is running */
static int check_pidfile(void)
{
  int pid_fd;
  pid_t pid;
  char pid_str[16];

  pid_fd = open_pidfile("open", O_RDWR);
  if (pid_fd < 0)
    return pid_fd;

  if (read(pid_fd, pid_str, sizeof(pid_str)) <= 0)
    return -1;

  pid = atoi(pid_str);
  if (pid <= 0)
    return -1;

  /* another running process that we can signal COULD be
   * a competing rrdcached */
  if (pid != getpid() && kill(pid, 0) == 0)
  {
    fprintf(stderr,
            "FATAL: Another rrdcached daemon is running?? (pid %d)\n", pid);
    close(pid_fd);
    return -1;
  }

  lseek(pid_fd, 0, SEEK_SET);
  if (ftruncate(pid_fd, 0) == -1)
  {
    fprintf(stderr,
            "FATAL: Faild to truncate stale PID file. (pid %d)\n", pid);
    close(pid_fd);
    return -1;
  }

  fprintf(stderr,
          "rrdcached: removed stale PID file (no rrdcached on pid %d)\n"
          "rrdcached: starting normally.\n", pid);

  return pid_fd;
} /* }}} static int check_pidfile */

static int write_pidfile (int fd) /* {{{ */
{
  pid_t pid;
  FILE *fh;

  pid = getpid ();

  fh = fdopen (fd, "w");
  if (fh == NULL)
  {
    RRDD_LOG (LOG_ERR, "write_pidfile: fdopen() failed.");
    close(fd);
    return (-1);
  }

  fprintf (fh, "%i\n", (int) pid);
  fclose (fh);

  return (0);
} /* }}} int write_pidfile */

static int remove_pidfile (void) /* {{{ */
{
  char *file;
  int status;

  file = (config_pid_file != NULL)
    ? config_pid_file
    : LOCALSTATEDIR "/run/rrdcached.pid";

  status = unlink (file);
  if (status == 0)
    return (0);
  return (errno);
} /* }}} int remove_pidfile */

static char *next_cmd (listen_socket_t *sock, ssize_t *len) /* {{{ */
{
  char *eol;

  eol = memchr(sock->rbuf + sock->next_cmd, '\n',
               sock->next_read - sock->next_cmd);

  if (eol == NULL)
  {
    /* no commands left, move remainder back to front of rbuf */
    memmove(sock->rbuf, sock->rbuf + sock->next_cmd,
            sock->next_read - sock->next_cmd);
    sock->next_read -= sock->next_cmd;
    sock->next_cmd = 0;
    *len = 0;
    return NULL;
  }
  else
  {
    char *cmd = sock->rbuf + sock->next_cmd;
    *eol = '\0';

    sock->next_cmd = eol - sock->rbuf + 1;

    if (eol > sock->rbuf && *(eol-1) == '\r')
      *(--eol) = '\0'; /* handle "\r\n" EOL */

    *len = eol - cmd;

    return cmd;
  }

  /* NOTREACHED */
  assert(1==0);
} /* }}} char *next_cmd */

/* add the characters directly to the write buffer */
static int add_to_wbuf(listen_socket_t *sock, char *str, size_t len) /* {{{ */
{
  char *new_buf;

  assert(sock != NULL);

  new_buf = rrd_realloc(sock->wbuf, sock->wbuf_len + len + 1);
  if (new_buf == NULL)
  {
    RRDD_LOG(LOG_ERR, "add_to_wbuf: realloc failed");
    return -1;
  }

  strncpy(new_buf + sock->wbuf_len, str, len + 1);

  sock->wbuf = new_buf;
  sock->wbuf_len += len;

  return 0;
} /* }}} static int add_to_wbuf */

/* add the text to the "extra" info that's sent after the status line */
static int add_response_info(listen_socket_t *sock, char *fmt, ...) /* {{{ */
{
  va_list argp;
  char buffer[CMD_MAX];
  int len;

  if (JOURNAL_REPLAY(sock)) return 0;
  if (sock->batch_start) return 0; /* no extra info returned when in BATCH */

  va_start(argp, fmt);
#ifdef HAVE_VSNPRINTF
  len = vsnprintf(buffer, sizeof(buffer), fmt, argp);
#else
  len = vsprintf(buffer, fmt, argp);
#endif
  va_end(argp);
  if (len < 0)
  {
    RRDD_LOG(LOG_ERR, "add_response_info: vnsprintf failed");
    return -1;
  }

  return add_to_wbuf(sock, buffer, len);
} /* }}} static int add_response_info */

static int count_lines(char *str) /* {{{ */
{
  int lines = 0;

  if (str != NULL)
  {
    while ((str = strchr(str, '\n')) != NULL)
    {
      ++lines;
      ++str;
    }
  }

  return lines;
} /* }}} static int count_lines */

/* send the response back to the user.
 * returns 0 on success, -1 on error
 * write buffer is always zeroed after this call */
static int send_response (listen_socket_t *sock, response_code rc,
                          char *fmt, ...) /* {{{ */
{
  va_list argp;
  char buffer[CMD_MAX];
  int lines;
  ssize_t wrote;
  int rclen, len;

  if (JOURNAL_REPLAY(sock)) return rc;

  if (sock->batch_start)
  {
    if (rc == RESP_OK)
      return rc; /* no response on success during BATCH */
    lines = sock->batch_cmd;
  }
  else if (rc == RESP_OK)
    lines = count_lines(sock->wbuf);
  else
    lines = -1;

  rclen = sprintf(buffer, "%d ", lines);
  va_start(argp, fmt);
#ifdef HAVE_VSNPRINTF
  len = vsnprintf(buffer+rclen, sizeof(buffer)-rclen, fmt, argp);
#else
  len = vsprintf(buffer+rclen, fmt, argp);
#endif
  va_end(argp);
  if (len < 0)
    return -1;

  len += rclen;

  /* append the result to the wbuf, don't write to the user */
  if (sock->batch_start)
    return add_to_wbuf(sock, buffer, len);

  /* first write must be complete */
  if (len != write(sock->fd, buffer, len))
  {
    RRDD_LOG(LOG_INFO, "send_response: could not write status message");
    return -1;
  }

  if (sock->wbuf != NULL && rc == RESP_OK)
  {
    wrote = 0;
    while (wrote < sock->wbuf_len)
    {
      ssize_t wb = write(sock->fd, sock->wbuf + wrote, sock->wbuf_len - wrote);
      if (wb <= 0)
      {
        RRDD_LOG(LOG_INFO, "send_response: could not write results");
        return -1;
      }
      wrote += wb;
    }
  }

  free(sock->wbuf); sock->wbuf = NULL;
  sock->wbuf_len = 0;

  return 0;
} /* }}} */

static void wipe_ci_values(cache_item_t *ci, time_t when)
{
  ci->values = NULL;
  ci->values_num = 0;

  ci->last_flush_time = when;
  if (config_write_jitter > 0)
    ci->last_flush_time += (rrd_random() % config_write_jitter);
}

/* remove_from_queue
 * remove a "cache_item_t" item from the queue.
 * must hold 'cache_lock' when calling this
 */
static void remove_from_queue(cache_item_t *ci) /* {{{ */
{
  if (ci == NULL) return;
  if ((ci->flags & CI_FLAGS_IN_QUEUE) == 0) return; /* not queued */

  if (ci->prev == NULL)
    cache_queue_head = ci->next; /* reset head */
  else
    ci->prev->next = ci->next;

  if (ci->next == NULL)
    cache_queue_tail = ci->prev; /* reset the tail */
  else
    ci->next->prev = ci->prev;

  ci->next = ci->prev = NULL;
  ci->flags &= ~CI_FLAGS_IN_QUEUE;

  pthread_mutex_lock (&stats_lock);
  assert (stats_queue_length > 0);
  stats_queue_length--;
  pthread_mutex_unlock (&stats_lock);

} /* }}} static void remove_from_queue */

/* free the resources associated with the cache_item_t
 * must hold cache_lock when calling this function
 */
static void *free_cache_item(cache_item_t *ci) /* {{{ */
{
  if (ci == NULL) return NULL;

  remove_from_queue(ci);

  for (size_t i=0; i < ci->values_num; i++)
    free(ci->values[i]);

  free (ci->values);
  free (ci->file);

  /* in case anyone is waiting */
  pthread_cond_broadcast(&ci->flushed);
  pthread_cond_destroy(&ci->flushed);

  free (ci);

  return NULL;
} /* }}} static void *free_cache_item */

/*
 * enqueue_cache_item:
 * `cache_lock' must be acquired before calling this function!
 */
static int enqueue_cache_item (cache_item_t *ci, /* {{{ */
    queue_side_t side)
{
  if (ci == NULL)
    return (-1);

  if (ci->values_num == 0)
    return (0);

  if (side == HEAD)
  {
    if (cache_queue_head == ci)
      return 0;

    /* remove if further down in queue */
    remove_from_queue(ci);

    ci->prev = NULL;
    ci->next = cache_queue_head;
    if (ci->next != NULL)
      ci->next->prev = ci;
    cache_queue_head = ci;

    if (cache_queue_tail == NULL)
      cache_queue_tail = cache_queue_head;
  }
  else /* (side == TAIL) */
  {
    /* We don't move values back in the list.. */
    if (ci->flags & CI_FLAGS_IN_QUEUE)
      return (0);

    assert (ci->next == NULL);
    assert (ci->prev == NULL);

    ci->prev = cache_queue_tail;

    if (cache_queue_tail == NULL)
      cache_queue_head = ci;
    else
      cache_queue_tail->next = ci;

    cache_queue_tail = ci;
  }

  ci->flags |= CI_FLAGS_IN_QUEUE;

  pthread_cond_signal(&queue_cond);
  pthread_mutex_lock (&stats_lock);
  stats_queue_length++;
  pthread_mutex_unlock (&stats_lock);

  return (0);
} /* }}} int enqueue_cache_item */

/*
 * tree_callback_flush:
 * Called via `g_tree_foreach' in `flush_thread_main'. `cache_lock' is held
 * while this is in progress.
 */
static gboolean tree_callback_flush (gpointer key, gpointer value, /* {{{ */
    gpointer data)
{
  cache_item_t *ci;
  callback_flush_data_t *cfd;

  ci = (cache_item_t *) value;
  cfd = (callback_flush_data_t *) data;

  if (ci->flags & CI_FLAGS_IN_QUEUE)
    return FALSE;

  if (ci->values_num > 0
      && (ci->last_flush_time <= cfd->abs_timeout || state != RUNNING))
  {
    enqueue_cache_item (ci, TAIL);
  }
  else if (((cfd->now - ci->last_flush_time) >= config_flush_interval)
      && (ci->values_num <= 0))
  {
    assert ((char *) key == ci->file);
    if (!rrd_add_ptr((void ***)&cfd->keys, &cfd->keys_num, (void *)key))
    {
      RRDD_LOG (LOG_ERR, "tree_callback_flush: rrd_add_ptrs failed.");
      return (FALSE);
    }
  }

  return (FALSE);
} /* }}} gboolean tree_callback_flush */

static int flush_old_values (int max_age)
{
  callback_flush_data_t cfd;
  size_t k;

  memset (&cfd, 0, sizeof (cfd));
  /* Pass the current time as user data so that we don't need to call
   * `time' for each node. */
  cfd.now = time (NULL);
  cfd.keys = NULL;
  cfd.keys_num = 0;

  if (max_age > 0)
    cfd.abs_timeout = cfd.now - max_age;
  else
    cfd.abs_timeout = cfd.now + 2*config_write_jitter + 1;

  /* `tree_callback_flush' will return the keys of all values that haven't
   * been touched in the last `config_flush_interval' seconds in `cfd'.
   * The char*'s in this array point to the same memory as ci->file, so we
   * don't need to free them separately. */
  g_tree_foreach (cache_tree, tree_callback_flush, (gpointer) &cfd);

  for (k = 0; k < cfd.keys_num; k++)
  {
    gboolean status = g_tree_remove(cache_tree, cfd.keys[k]);
    /* should never fail, since we have held the cache_lock
     * the entire time */
    assert(status == TRUE);
  }

  if (cfd.keys != NULL)
  {
    free (cfd.keys);
    cfd.keys = NULL;
  }

  return (0);
} /* int flush_old_values */

static void *flush_thread_main (void UNUSED(*args)) /* {{{ */
{
  struct timeval now;
  struct timespec next_flush;
  int status;

  gettimeofday (&now, NULL);
  next_flush.tv_sec = now.tv_sec + config_flush_interval;
  next_flush.tv_nsec = 1000 * now.tv_usec;

  pthread_mutex_lock(&cache_lock);

  while (state == RUNNING)
  {
    gettimeofday (&now, NULL);
    if ((now.tv_sec > next_flush.tv_sec)
        || ((now.tv_sec == next_flush.tv_sec)
          && ((1000 * now.tv_usec) > next_flush.tv_nsec)))
    {
      RRDD_LOG(LOG_DEBUG, "flushing old values");

      /* Determine the time of the next cache flush. */
      next_flush.tv_sec = now.tv_sec + config_flush_interval;

      /* Flush all values that haven't been written in the last
       * `config_write_interval' seconds. */
      flush_old_values (config_write_interval);

      /* unlock the cache while we rotate so we don't block incoming
       * updates if the fsync() blocks on disk I/O */
      pthread_mutex_unlock(&cache_lock);
      journal_rotate();
      pthread_mutex_lock(&cache_lock);
    }

    status = pthread_cond_timedwait(&flush_cond, &cache_lock, &next_flush);
    if (status != 0 && status != ETIMEDOUT)
    {
      RRDD_LOG (LOG_ERR, "flush_thread_main: "
                "pthread_cond_timedwait returned %i.", status);
    }
  }

  if (config_flush_at_shutdown)
    flush_old_values (-1); /* flush everything */

  state = SHUTDOWN;

  pthread_mutex_unlock(&cache_lock);

  return NULL;
} /* void *flush_thread_main */

static void *queue_thread_main (void UNUSED(*args)) /* {{{ */
{
  pthread_mutex_lock (&cache_lock);

  while (state != SHUTDOWN
         || (cache_queue_head != NULL && config_flush_at_shutdown))
  {
    cache_item_t *ci;
    char *file;
    char **values;
    size_t values_num;
    int status;

    /* Now, check if there's something to store away. If not, wait until
     * something comes in. */
    if (cache_queue_head == NULL)
    {
      status = pthread_cond_wait (&queue_cond, &cache_lock);
      if ((status != 0) && (status != ETIMEDOUT))
      {
        RRDD_LOG (LOG_ERR, "queue_thread_main: "
            "pthread_cond_wait returned %i.", status);
      }
    }

    /* Check if a value has arrived. This may be NULL if we timed out or there
     * was an interrupt such as a signal. */
    if (cache_queue_head == NULL)
      continue;

    ci = cache_queue_head;

    /* copy the relevant parts */
    file = strdup (ci->file);
    if (file == NULL)
    {
      RRDD_LOG (LOG_ERR, "queue_thread_main: strdup failed.");
      continue;
    }

    assert(ci->values != NULL);
    assert(ci->values_num > 0);

    values = ci->values;
    values_num = ci->values_num;

    wipe_ci_values(ci, time(NULL));
    remove_from_queue(ci);

    pthread_mutex_unlock (&cache_lock);

    rrd_clear_error ();
    status = rrd_update_r (file, NULL, (int) values_num, (void *) values);
    if (status != 0)
    {
      RRDD_LOG (LOG_NOTICE, "queue_thread_main: "
          "rrd_update_r (%s) failed with status %i. (%s)",
          file, status, rrd_get_error());
    }

    journal_write("wrote", file);

    /* Search again in the tree.  It's possible someone issued a "FORGET"
     * while we were writing the update values. */
    pthread_mutex_lock(&cache_lock);
    ci = (cache_item_t *) g_tree_lookup(cache_tree, file);
    if (ci)
      pthread_cond_broadcast(&ci->flushed);
    pthread_mutex_unlock(&cache_lock);

    if (status == 0)
    {
      pthread_mutex_lock (&stats_lock);
      stats_updates_written++;
      stats_data_sets_written += values_num;
      pthread_mutex_unlock (&stats_lock);
    }

    rrd_free_ptrs((void ***) &values, &values_num);
    free(file);

    pthread_mutex_lock (&cache_lock);
  }
  pthread_mutex_unlock (&cache_lock);

  return (NULL);
} /* }}} void *queue_thread_main */

static int buffer_get_field (char **buffer_ret, /* {{{ */
    size_t *buffer_size_ret, char **field_ret)
{
  char *buffer;
  size_t buffer_pos;
  size_t buffer_size;
  char *field;
  size_t field_size;
  int status;

  buffer = *buffer_ret;
  buffer_pos = 0;
  buffer_size = *buffer_size_ret;
  field = *buffer_ret;
  field_size = 0;

  if (buffer_size <= 0)
    return (-1);

  /* This is ensured by `handle_request'. */
  assert (buffer[buffer_size - 1] == '\0');

  status = -1;
  while (buffer_pos < buffer_size)
  {
    /* Check for end-of-field or end-of-buffer */
    if (buffer[buffer_pos] == ' ' || buffer[buffer_pos] == '\0')
    {
      field[field_size] = 0;
      field_size++;
      buffer_pos++;
      status = 0;
      break;
    }
    /* Handle escaped characters. */
    else if (buffer[buffer_pos] == '\\')
    {
      if (buffer_pos >= (buffer_size - 1))
        break;
      buffer_pos++;
      field[field_size] = buffer[buffer_pos];
      field_size++;
      buffer_pos++;
    }
    /* Normal operation */ 
    else
    {
      field[field_size] = buffer[buffer_pos];
      field_size++;
      buffer_pos++;
    }
  } /* while (buffer_pos < buffer_size) */

  if (status != 0)
    return (status);

  *buffer_ret = buffer + buffer_pos;
  *buffer_size_ret = buffer_size - buffer_pos;
  *field_ret = field;

  return (0);
} /* }}} int buffer_get_field */

/* if we're restricting writes to the base directory,
 * check whether the file falls within the dir
 * returns 1 if OK, otherwise 0
 */
static int check_file_access (const char *file, listen_socket_t *sock) /* {{{ */
{
  assert(file != NULL);

  if (!config_write_base_only
      || JOURNAL_REPLAY(sock)
      || config_base_dir == NULL)
    return 1;

  if (strstr(file, "../") != NULL) goto err;

  /* relative paths without "../" are ok */
  if (*file != '/') return 1;

  /* file must be of the format base + "/" + <1+ char filename> */
  if (strlen(file) < _config_base_dir_len + 2) goto err;
  if (strncmp(file, config_base_dir, _config_base_dir_len) != 0) goto err;
  if (*(file + _config_base_dir_len) != '/') goto err;

  return 1;

err:
  if (sock != NULL && sock->fd >= 0)
    send_response(sock, RESP_ERR, "%s\n", rrd_strerror(EACCES));

  return 0;
} /* }}} static int check_file_access */

/* when using a base dir, convert relative paths to absolute paths.
 * if necessary, modifies the "filename" pointer to point
 * to the new path created in "tmp".  "tmp" is provided
 * by the caller and sizeof(tmp) must be >= PATH_MAX.
 *
 * this allows us to optimize for the expected case (absolute path)
 * with a no-op.
 */
static void get_abs_path(char **filename, char *tmp)
{
  assert(tmp != NULL);
  assert(filename != NULL && *filename != NULL);

  if (config_base_dir == NULL || **filename == '/')
    return;

  snprintf(tmp, PATH_MAX, "%s/%s", config_base_dir, *filename);
  *filename = tmp;
} /* }}} static int get_abs_path */

static int flush_file (const char *filename) /* {{{ */
{
  cache_item_t *ci;

  pthread_mutex_lock (&cache_lock);

  ci = (cache_item_t *) g_tree_lookup (cache_tree, filename);
  if (ci == NULL)
  {
    pthread_mutex_unlock (&cache_lock);
    return (ENOENT);
  }

  if (ci->values_num > 0)
  {
    /* Enqueue at head */
    enqueue_cache_item (ci, HEAD);
    pthread_cond_wait(&ci->flushed, &cache_lock);
  }

  /* DO NOT DO ANYTHING WITH ci HERE!!  The entry
   * may have been purged during our cond_wait() */

  pthread_mutex_unlock(&cache_lock);

  return (0);
} /* }}} int flush_file */

static int syntax_error(listen_socket_t *sock, command_t *cmd) /* {{{ */
{
  char *err = "Syntax error.\n";

  if (cmd && cmd->syntax)
    err = cmd->syntax;

  return send_response(sock, RESP_ERR, "Usage: %s", err);
} /* }}} static int syntax_error() */

static int handle_request_stats (HANDLER_PROTO) /* {{{ */
{
  uint64_t copy_queue_length;
  uint64_t copy_updates_received;
  uint64_t copy_flush_received;
  uint64_t copy_updates_written;
  uint64_t copy_data_sets_written;
  uint64_t copy_journal_bytes;
  uint64_t copy_journal_rotate;

  uint64_t tree_nodes_number;
  uint64_t tree_depth;

  pthread_mutex_lock (&stats_lock);
  copy_queue_length       = stats_queue_length;
  copy_updates_received   = stats_updates_received;
  copy_flush_received     = stats_flush_received;
  copy_updates_written    = stats_updates_written;
  copy_data_sets_written  = stats_data_sets_written;
  copy_journal_bytes      = stats_journal_bytes;
  copy_journal_rotate     = stats_journal_rotate;
  pthread_mutex_unlock (&stats_lock);

  pthread_mutex_lock (&cache_lock);
  tree_nodes_number = (uint64_t) g_tree_nnodes (cache_tree);
  tree_depth        = (uint64_t) g_tree_height (cache_tree);
  pthread_mutex_unlock (&cache_lock);

  add_response_info(sock,
                    "QueueLength: %"PRIu64"\n", copy_queue_length);
  add_response_info(sock,
                    "UpdatesReceived: %"PRIu64"\n", copy_updates_received);
  add_response_info(sock,
                    "FlushesReceived: %"PRIu64"\n", copy_flush_received);
  add_response_info(sock,
                    "UpdatesWritten: %"PRIu64"\n", copy_updates_written);
  add_response_info(sock,
                    "DataSetsWritten: %"PRIu64"\n", copy_data_sets_written);
  add_response_info(sock, "TreeNodesNumber: %"PRIu64"\n", tree_nodes_number);
  add_response_info(sock, "TreeDepth: %"PRIu64"\n", tree_depth);
  add_response_info(sock, "JournalBytes: %"PRIu64"\n", copy_journal_bytes);
  add_response_info(sock, "JournalRotate: %"PRIu64"\n", copy_journal_rotate);

  send_response(sock, RESP_OK, "Statistics follow\n");

  return (0);
} /* }}} int handle_request_stats */

static int handle_request_flush (HANDLER_PROTO) /* {{{ */
{
  char *file, file_tmp[PATH_MAX];
  int status;

  status = buffer_get_field (&buffer, &buffer_size, &file);
  if (status != 0)
  {
    return syntax_error(sock,cmd);
  }
  else
  {
    pthread_mutex_lock(&stats_lock);
    stats_flush_received++;
    pthread_mutex_unlock(&stats_lock);

    get_abs_path(&file, file_tmp);
    if (!check_file_access(file, sock)) return 0;

    status = flush_file (file);
    if (status == 0)
      return send_response(sock, RESP_OK, "Successfully flushed %s.\n", file);
    else if (status == ENOENT)
    {
      /* no file in our tree; see whether it exists at all */
      struct stat statbuf;

      memset(&statbuf, 0, sizeof(statbuf));
      if (stat(file, &statbuf) == 0 && S_ISREG(statbuf.st_mode))
        return send_response(sock, RESP_OK, "Nothing to flush: %s.\n", file);
      else
        return send_response(sock, RESP_ERR, "No such file: %s.\n", file);
    }
    else if (status < 0)
      return send_response(sock, RESP_ERR, "Internal error.\n");
    else
      return send_response(sock, RESP_ERR, "Failed with status %i.\n", status);
  }

  /* NOTREACHED */
  assert(1==0);
} /* }}} int handle_request_flush */

static int handle_request_flushall(HANDLER_PROTO) /* {{{ */
{
  RRDD_LOG(LOG_DEBUG, "Received FLUSHALL");

  pthread_mutex_lock(&cache_lock);
  flush_old_values(-1);
  pthread_mutex_unlock(&cache_lock);

  return send_response(sock, RESP_OK, "Started flush.\n");
} /* }}} static int handle_request_flushall */

static int handle_request_pending(HANDLER_PROTO) /* {{{ */
{
  int status;
  char *file, file_tmp[PATH_MAX];
  cache_item_t *ci;

  status = buffer_get_field(&buffer, &buffer_size, &file);
  if (status != 0)
    return syntax_error(sock,cmd);

  get_abs_path(&file, file_tmp);

  pthread_mutex_lock(&cache_lock);
  ci = g_tree_lookup(cache_tree, file);
  if (ci == NULL)
  {
    pthread_mutex_unlock(&cache_lock);
    return send_response(sock, RESP_ERR, "%s\n", rrd_strerror(ENOENT));
  }

  for (size_t i=0; i < ci->values_num; i++)
    add_response_info(sock, "%s\n", ci->values[i]);

  pthread_mutex_unlock(&cache_lock);
  return send_response(sock, RESP_OK, "updates pending\n");
} /* }}} static int handle_request_pending */

static int handle_request_forget(HANDLER_PROTO) /* {{{ */
{
  int status;
  gboolean found;
  char *file, file_tmp[PATH_MAX];

  status = buffer_get_field(&buffer, &buffer_size, &file);
  if (status != 0)
    return syntax_error(sock,cmd);

  get_abs_path(&file, file_tmp);
  if (!check_file_access(file, sock)) return 0;

  pthread_mutex_lock(&cache_lock);
  found = g_tree_remove(cache_tree, file);
  pthread_mutex_unlock(&cache_lock);

  if (found == TRUE)
  {
    if (!JOURNAL_REPLAY(sock))
      journal_write("forget", file);

    return send_response(sock, RESP_OK, "Gone!\n");
  }
  else
    return send_response(sock, RESP_ERR, "%s\n", rrd_strerror(ENOENT));

  /* NOTREACHED */
  assert(1==0);
} /* }}} static int handle_request_forget */

static int handle_request_queue (HANDLER_PROTO) /* {{{ */
{
  cache_item_t *ci;

  pthread_mutex_lock(&cache_lock);

  ci = cache_queue_head;
  while (ci != NULL)
  {
    add_response_info(sock, "%d %s\n", ci->values_num, ci->file);
    ci = ci->next;
  }

  pthread_mutex_unlock(&cache_lock);

  return send_response(sock, RESP_OK, "in queue.\n");
} /* }}} int handle_request_queue */

static int handle_request_update (HANDLER_PROTO) /* {{{ */
{
  char *file, file_tmp[PATH_MAX];
  int values_num = 0;
  int status;
  char orig_buf[CMD_MAX];

  cache_item_t *ci;

  /* save it for the journal later */
  if (!JOURNAL_REPLAY(sock))
    strncpy(orig_buf, buffer, min(CMD_MAX,buffer_size));

  status = buffer_get_field (&buffer, &buffer_size, &file);
  if (status != 0)
    return syntax_error(sock,cmd);

  pthread_mutex_lock(&stats_lock);
  stats_updates_received++;
  pthread_mutex_unlock(&stats_lock);

  get_abs_path(&file, file_tmp);
  if (!check_file_access(file, sock)) return 0;

  pthread_mutex_lock (&cache_lock);
  ci = g_tree_lookup (cache_tree, file);

  if (ci == NULL) /* {{{ */
  {
    struct stat statbuf;
    cache_item_t *tmp;

    /* don't hold the lock while we setup; stat(2) might block */
    pthread_mutex_unlock(&cache_lock);

    memset (&statbuf, 0, sizeof (statbuf));
    status = stat (file, &statbuf);
    if (status != 0)
    {
      RRDD_LOG (LOG_NOTICE, "handle_request_update: stat (%s) failed.", file);

      status = errno;
      if (status == ENOENT)
        return send_response(sock, RESP_ERR, "No such file: %s\n", file);
      else
        return send_response(sock, RESP_ERR,
                             "stat failed with error %i.\n", status);
    }
    if (!S_ISREG (statbuf.st_mode))
      return send_response(sock, RESP_ERR, "Not a regular file: %s\n", file);

    if (access(file, R_OK|W_OK) != 0)
      return send_response(sock, RESP_ERR, "Cannot read/write %s: %s\n",
                           file, rrd_strerror(errno));

    ci = (cache_item_t *) malloc (sizeof (cache_item_t));
    if (ci == NULL)
    {
      RRDD_LOG (LOG_ERR, "handle_request_update: malloc failed.");

      return send_response(sock, RESP_ERR, "malloc failed.\n");
    }
    memset (ci, 0, sizeof (cache_item_t));

    ci->file = strdup (file);
    if (ci->file == NULL)
    {
      free (ci);
      RRDD_LOG (LOG_ERR, "handle_request_update: strdup failed.");

      return send_response(sock, RESP_ERR, "strdup failed.\n");
    }

    wipe_ci_values(ci, now);
    ci->flags = CI_FLAGS_IN_TREE;
    pthread_cond_init(&ci->flushed, NULL);

    pthread_mutex_lock(&cache_lock);

    /* another UPDATE might have added this entry in the meantime */
    tmp = g_tree_lookup (cache_tree, file);
    if (tmp == NULL)
      g_tree_replace (cache_tree, (void *) ci->file, (void *) ci);
    else
    {
      free_cache_item (ci);
      ci = tmp;
    }

    /* state may have changed while we were unlocked */
    if (state == SHUTDOWN)
      return -1;
  } /* }}} */
  assert (ci != NULL);

  /* don't re-write updates in replay mode */
  if (!JOURNAL_REPLAY(sock))
    journal_write("update", orig_buf);

  while (buffer_size > 0)
  {
    char *value;
    double stamp;
    char *eostamp;

    status = buffer_get_field (&buffer, &buffer_size, &value);
    if (status != 0)
    {
      RRDD_LOG (LOG_INFO, "handle_request_update: Error reading field.");
      break;
    }

    /* make sure update time is always moving forward. We use double here since
       update does support subsecond precision for timestamps ... */
    stamp = strtod(value, &eostamp);
    if (eostamp == value || eostamp == NULL || *eostamp != ':')
    {
      pthread_mutex_unlock(&cache_lock);
      return send_response(sock, RESP_ERR,
                           "Cannot find timestamp in '%s'!\n", value);
    }
    else if (stamp <= ci->last_update_stamp)
    {
      pthread_mutex_unlock(&cache_lock);
      return send_response(sock, RESP_ERR,
                           "illegal attempt to update using time %lf when last"
                           " update time is %lf (minimum one second step)\n",
                           stamp, ci->last_update_stamp);
    }
    else
      ci->last_update_stamp = stamp;

    if (!rrd_add_strdup(&ci->values, &ci->values_num, value))
    {
      RRDD_LOG (LOG_ERR, "handle_request_update: rrd_add_strdup failed.");
      continue;
    }

    values_num++;
  }

  if (((now - ci->last_flush_time) >= config_write_interval)
      && ((ci->flags & CI_FLAGS_IN_QUEUE) == 0)
      && (ci->values_num > 0))
  {
    enqueue_cache_item (ci, TAIL);
  }

  pthread_mutex_unlock (&cache_lock);

  if (values_num < 1)
    return send_response(sock, RESP_ERR, "No values updated.\n");
  else
    return send_response(sock, RESP_OK,
                         "errors, enqueued %i value(s).\n", values_num);

  /* NOTREACHED */
  assert(1==0);

} /* }}} int handle_request_update */

/* we came across a "WROTE" entry during journal replay.
 * throw away any values that we have accumulated for this file
 */
static int handle_request_wrote (HANDLER_PROTO) /* {{{ */
{
  cache_item_t *ci;
  const char *file = buffer;

  pthread_mutex_lock(&cache_lock);

  ci = g_tree_lookup(cache_tree, file);
  if (ci == NULL)
  {
    pthread_mutex_unlock(&cache_lock);
    return (0);
  }

  if (ci->values)
    rrd_free_ptrs((void ***) &ci->values, &ci->values_num);

  wipe_ci_values(ci, now);
  remove_from_queue(ci);

  pthread_mutex_unlock(&cache_lock);
  return (0);
} /* }}} int handle_request_wrote */

/* start "BATCH" processing */
static int batch_start (HANDLER_PROTO) /* {{{ */
{
  int status;
  if (sock->batch_start)
    return send_response(sock, RESP_ERR, "Already in BATCH\n");

  status = send_response(sock, RESP_OK,
                         "Go ahead.  End with dot '.' on its own line.\n");
  sock->batch_start = time(NULL);
  sock->batch_cmd = 0;

  return status;
} /* }}} static int batch_start */

/* finish "BATCH" processing and return results to the client */
static int batch_done (HANDLER_PROTO) /* {{{ */
{
  assert(sock->batch_start);
  sock->batch_start = 0;
  sock->batch_cmd  = 0;
  return send_response(sock, RESP_OK, "errors\n");
} /* }}} static int batch_done */

static int handle_request_quit (HANDLER_PROTO) /* {{{ */
{
  return -1;
} /* }}} static int handle_request_quit */

static command_t list_of_commands[] = { /* {{{ */
  {
    "UPDATE",
    handle_request_update,
    CMD_CONTEXT_ANY,
    "UPDATE <filename> <values> [<values> ...]\n"
    ,
    "Adds the given file to the internal cache if it is not yet known and\n"
    "appends the given value(s) to the entry. See the rrdcached(1) manpage\n"
    "for details.\n"
    "\n"
    "Each <values> has the following form:\n"
    "  <values> = <time>:<value>[:<value>[...]]\n"
    "See the rrdupdate(1) manpage for details.\n"
  },
  {
    "WROTE",
    handle_request_wrote,
    CMD_CONTEXT_JOURNAL,
    NULL,
    NULL
  },
  {
    "FLUSH",
    handle_request_flush,
    CMD_CONTEXT_CLIENT | CMD_CONTEXT_BATCH,
    "FLUSH <filename>\n"
    ,
    "Adds the given filename to the head of the update queue and returns\n"
    "after it has been dequeued.\n"
  },
  {
    "FLUSHALL",
    handle_request_flushall,
    CMD_CONTEXT_CLIENT,
    "FLUSHALL\n"
    ,
    "Triggers writing of all pending updates.  Returns immediately.\n"
  },
  {
    "PENDING",
    handle_request_pending,
    CMD_CONTEXT_CLIENT,
    "PENDING <filename>\n"
    ,
    "Shows any 'pending' updates for a file, in order.\n"
    "The updates shown have not yet been written to the underlying RRD file.\n"
  },
  {
    "FORGET",
    handle_request_forget,
    CMD_CONTEXT_ANY,
    "FORGET <filename>\n"
    ,
    "Removes the file completely from the cache.\n"
    "Any pending updates for the file will be lost.\n"
  },
  {
    "QUEUE",
    handle_request_queue,
    CMD_CONTEXT_CLIENT,
    "QUEUE\n"
    ,
        "Shows all files in the output queue.\n"
    "The output is zero or more lines in the following format:\n"
    "(where <num_vals> is the number of values to be written)\n"
    "\n"
    "<num_vals> <filename>\n"
  },
  {
    "STATS",
    handle_request_stats,
    CMD_CONTEXT_CLIENT,
    "STATS\n"
    ,
    "Returns some performance counters, see the rrdcached(1) manpage for\n"
    "a description of the values.\n"
  },
  {
    "HELP",
    handle_request_help,
    CMD_CONTEXT_CLIENT,
    "HELP [<command>]\n",
    NULL, /* special! */
  },
  {
    "BATCH",
    batch_start,
    CMD_CONTEXT_CLIENT,
    "BATCH\n"
    ,
    "The 'BATCH' command permits the client to initiate a bulk load\n"
    "   of commands to rrdcached.\n"
    "\n"
    "Usage:\n"
    "\n"
    "    client: BATCH\n"
    "    server: 0 Go ahead.  End with dot '.' on its own line.\n"
    "    client: command #1\n"
    "    client: command #2\n"
    "    client: ... and so on\n"
    "    client: .\n"
    "    server: 2 errors\n"
    "    server: 7 message for command #7\n"
    "    server: 9 message for command #9\n"
    "\n"
    "For more information, consult the rrdcached(1) documentation.\n"
  },
  {
    ".",   /* BATCH terminator */
    batch_done,
    CMD_CONTEXT_BATCH,
    NULL,
    NULL
  },
  {
    "QUIT",
    handle_request_quit,
    CMD_CONTEXT_CLIENT | CMD_CONTEXT_BATCH,
    "QUIT\n"
    ,
    "Disconnect from rrdcached.\n"
  }
}; /* }}} command_t list_of_commands[] */
static size_t list_of_commands_len = sizeof (list_of_commands)
  / sizeof (list_of_commands[0]);

static command_t *find_command(char *cmd)
{
  size_t i;

  for (i = 0; i < list_of_commands_len; i++)
    if (strcasecmp(cmd, list_of_commands[i].cmd) == 0)
      return (&list_of_commands[i]);
  return NULL;
}

/* We currently use the index in the `list_of_commands' array as a bit position
 * in `listen_socket_t.permissions'. This member schould NEVER be accessed from
 * outside these functions so that switching to a more elegant storage method
 * is easily possible. */
static ssize_t find_command_index (const char *cmd) /* {{{ */
{
  size_t i;

  for (i = 0; i < list_of_commands_len; i++)
    if (strcasecmp(cmd, list_of_commands[i].cmd) == 0)
      return ((ssize_t) i);
  return (-1);
} /* }}} ssize_t find_command_index */

static int socket_permission_check (listen_socket_t *sock, /* {{{ */
    const char *cmd)
{
  ssize_t i;

  if (JOURNAL_REPLAY(sock))
    return (1);

  if (cmd == NULL)
    return (-1);

  if ((strcasecmp ("QUIT", cmd) == 0)
      || (strcasecmp ("HELP", cmd) == 0))
    return (1);
  else if (strcmp (".", cmd) == 0)
    cmd = "BATCH";

  i = find_command_index (cmd);
  if (i < 0)
    return (-1);
  assert (i < 32);

  if ((sock->permissions & (1 << i)) != 0)
    return (1);
  return (0);
} /* }}} int socket_permission_check */

static int socket_permission_add (listen_socket_t *sock, /* {{{ */
    const char *cmd)
{
  ssize_t i;

  i = find_command_index (cmd);
  if (i < 0)
    return (-1);
  assert (i < 32);

  sock->permissions |= (1 << i);
  return (0);
} /* }}} int socket_permission_add */

static void socket_permission_clear (listen_socket_t *sock) /* {{{ */
{
  sock->permissions = 0;
} /* }}} socket_permission_clear */

static void socket_permission_copy (listen_socket_t *dest, /* {{{ */
    listen_socket_t *src)
{
  dest->permissions = src->permissions;
} /* }}} socket_permission_copy */

static void socket_permission_set_all (listen_socket_t *sock) /* {{{ */
{
  size_t i;

  sock->permissions = 0;
  for (i = 0; i < list_of_commands_len; i++)
    sock->permissions |= (1 << i);
} /* }}} void socket_permission_set_all */

/* check whether commands are received in the expected context */
static int command_check_context(listen_socket_t *sock, command_t *cmd)
{
  if (JOURNAL_REPLAY(sock))
    return (cmd->context & CMD_CONTEXT_JOURNAL);
  else if (sock->batch_start)
    return (cmd->context & CMD_CONTEXT_BATCH);
  else
    return (cmd->context & CMD_CONTEXT_CLIENT);

  /* NOTREACHED */
  assert(1==0);
}

static int handle_request_help (HANDLER_PROTO) /* {{{ */
{
  int status;
  char *cmd_str;
  char *resp_txt;
  command_t *help = NULL;

  status = buffer_get_field (&buffer, &buffer_size, &cmd_str);
  if (status == 0)
    help = find_command(cmd_str);

  if (help && (help->syntax || help->help))
  {
    char tmp[CMD_MAX];

    snprintf(tmp, sizeof(tmp)-1, "Help for %s\n", help->cmd);
    resp_txt = tmp;

    if (help->syntax)
      add_response_info(sock, "Usage: %s\n", help->syntax);

    if (help->help)
      add_response_info(sock, "%s\n", help->help);
  }
  else
  {
    size_t i;

    resp_txt = "Command overview\n";

    for (i = 0; i < list_of_commands_len; i++)
    {
      if (list_of_commands[i].syntax == NULL)
        continue;
      add_response_info (sock, "%s", list_of_commands[i].syntax);
    }
  }

  return send_response(sock, RESP_OK, resp_txt);
} /* }}} int handle_request_help */

static int handle_request (DISPATCH_PROTO) /* {{{ */
{
  char *buffer_ptr = buffer;
  char *cmd_str = NULL;
  command_t *cmd = NULL;
  int status;

  assert (buffer[buffer_size - 1] == '\0');

  status = buffer_get_field (&buffer_ptr, &buffer_size, &cmd_str);
  if (status != 0)
  {
    RRDD_LOG (LOG_INFO, "handle_request: Unable parse command.");
    return (-1);
  }

  if (sock != NULL && sock->batch_start)
    sock->batch_cmd++;

  cmd = find_command(cmd_str);
  if (!cmd)
    return send_response(sock, RESP_ERR, "Unknown command: %s\n", cmd_str);

  if (!socket_permission_check (sock, cmd->cmd))
    return send_response(sock, RESP_ERR, "Permission denied.\n");

  if (!command_check_context(sock, cmd))
    return send_response(sock, RESP_ERR, "Can't use '%s' here.\n", cmd_str);

  return cmd->handler(cmd, sock, now, buffer_ptr, buffer_size);
} /* }}} int handle_request */

static void journal_set_free (journal_set *js) /* {{{ */
{
  if (js == NULL)
    return;

  rrd_free_ptrs((void ***) &js->files, &js->files_num);

  free(js);
} /* }}} journal_set_free */

static void journal_set_remove (journal_set *js) /* {{{ */
{
  if (js == NULL)
    return;

  for (uint i=0; i < js->files_num; i++)
  {
    RRDD_LOG(LOG_DEBUG, "removing old journal %s", js->files[i]);
    unlink(js->files[i]);
  }
} /* }}} journal_set_remove */

/* close current journal file handle.
 * MUST hold journal_lock before calling */
static void journal_close(void) /* {{{ */
{
  if (journal_fh != NULL)
  {
    if (fclose(journal_fh) != 0)
      RRDD_LOG(LOG_ERR, "cannot close journal: %s", rrd_strerror(errno));
  }

  journal_fh = NULL;
  journal_size = 0;
} /* }}} journal_close */

/* MUST hold journal_lock before calling */
static void journal_new_file(void) /* {{{ */
{
  struct timeval now;
  int  new_fd;
  char new_file[PATH_MAX + 1];

  assert(journal_dir != NULL);
  assert(journal_cur != NULL);

  journal_close();

  gettimeofday(&now, NULL);
  /* this format assures that the files sort in strcmp() order */
  snprintf(new_file, PATH_MAX, "%s/%s.%010d.%06d",
           journal_dir, JOURNAL_BASE, (int)now.tv_sec, (int)now.tv_usec);

  new_fd = open(new_file, O_WRONLY|O_CREAT|O_APPEND,
                S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH);
  if (new_fd < 0)
    goto error;

  journal_fh = fdopen(new_fd, "a");
  if (journal_fh == NULL)
    goto error;

  journal_size = ftell(journal_fh);
  RRDD_LOG(LOG_DEBUG, "started new journal %s", new_file);

  /* record the file in the journal set */
  rrd_add_strdup(&journal_cur->files, &journal_cur->files_num, new_file);

  return;

error:
  RRDD_LOG(LOG_CRIT,
           "JOURNALING DISABLED: Error while trying to create %s : %s",
           new_file, rrd_strerror(errno));
  RRDD_LOG(LOG_CRIT,
           "JOURNALING DISABLED: All values will be flushed at shutdown");

  close(new_fd);
  config_flush_at_shutdown = 1;

} /* }}} journal_new_file */

/* MUST NOT hold journal_lock before calling this */
static void journal_rotate(void) /* {{{ */
{
  journal_set *old_js = NULL;

  if (journal_dir == NULL)
    return;

  RRDD_LOG(LOG_DEBUG, "rotating journals");

  pthread_mutex_lock(&stats_lock);
  ++stats_journal_rotate;
  pthread_mutex_unlock(&stats_lock);

  pthread_mutex_lock(&journal_lock);

  journal_close();

  /* rotate the journal sets */
  old_js = journal_old;
  journal_old = journal_cur;
  journal_cur = calloc(1, sizeof(journal_set));

  if (journal_cur != NULL)
    journal_new_file();
  else
    RRDD_LOG(LOG_CRIT, "journal_rotate: malloc(journal_set) failed\n");

  pthread_mutex_unlock(&journal_lock);

  journal_set_remove(old_js);
  journal_set_free  (old_js);

} /* }}} static void journal_rotate */

/* MUST hold journal_lock when calling */
static void journal_done(void) /* {{{ */
{
  if (journal_cur == NULL)
    return;

  journal_close();

  if (config_flush_at_shutdown)
  {
    RRDD_LOG(LOG_INFO, "removing journals");
    journal_set_remove(journal_old);
    journal_set_remove(journal_cur);
  }
  else
  {
    RRDD_LOG(LOG_INFO, "expedited shutdown; "
             "journals will be used at next startup");
  }

  journal_set_free(journal_cur);
  journal_set_free(journal_old);
  free(journal_dir);

} /* }}} static void journal_done */

static int journal_write(char *cmd, char *args) /* {{{ */
{
  int chars;

  if (journal_fh == NULL)
    return 0;

  pthread_mutex_lock(&journal_lock);
  chars = fprintf(journal_fh, "%s %s\n", cmd, args);
  journal_size += chars;

  if (journal_size > JOURNAL_MAX)
    journal_new_file();

  pthread_mutex_unlock(&journal_lock);

  if (chars > 0)
  {
    pthread_mutex_lock(&stats_lock);
    stats_journal_bytes += chars;
    pthread_mutex_unlock(&stats_lock);
  }

  return chars;
} /* }}} static int journal_write */

static int journal_replay (const char *file) /* {{{ */
{
  FILE *fh;
  int entry_cnt = 0;
  int fail_cnt = 0;
  uint64_t line = 0;
  char entry[CMD_MAX];
  time_t now;

  if (file == NULL) return 0;

  {
    char *reason = "unknown error";
    int status = 0;
    struct stat statbuf;

    memset(&statbuf, 0, sizeof(statbuf));
    if (stat(file, &statbuf) != 0)
    {
      reason = "stat error";
      status = errno;
    }
    else if (!S_ISREG(statbuf.st_mode))
    {
      reason = "not a regular file";
      status = EPERM;
    }
    if (statbuf.st_uid != daemon_uid)
    {
      reason = "not owned by daemon user";
      status = EACCES;
    }
    if (statbuf.st_mode & (S_IWGRP|S_IWOTH))
    {
      reason = "must not be user/group writable";
      status = EACCES;
    }

    if (status != 0)
    {
      RRDD_LOG(LOG_ERR, "journal_replay: %s : %s (%s)",
               file, rrd_strerror(status), reason);
      return 0;
    }
  }

  fh = fopen(file, "r");
  if (fh == NULL)
  {
    if (errno != ENOENT)
      RRDD_LOG(LOG_ERR, "journal_replay: cannot open journal file: '%s' (%s)",
               file, rrd_strerror(errno));
    return 0;
  }
  else
    RRDD_LOG(LOG_NOTICE, "replaying from journal: %s", file);

  now = time(NULL);

  while(!feof(fh))
  {
    size_t entry_len;

    ++line;
    if (fgets(entry, sizeof(entry), fh) == NULL)
      break;
    entry_len = strlen(entry);

    /* check \n termination in case journal writing crashed mid-line */
    if (entry_len == 0)
      continue;
    else if (entry[entry_len - 1] != '\n')
    {
      RRDD_LOG(LOG_NOTICE, "Malformed journal entry at line %"PRIu64, line);
      ++fail_cnt;
      continue;
    }

    entry[entry_len - 1] = '\0';

    if (handle_request(NULL, now, entry, entry_len) == 0)
      ++entry_cnt;
    else
      ++fail_cnt;
  }

  fclose(fh);

  RRDD_LOG(LOG_INFO, "Replayed %d entries (%d failures)",
           entry_cnt, fail_cnt);

  return entry_cnt > 0 ? 1 : 0;
} /* }}} static int journal_replay */

static int journal_sort(const void *v1, const void *v2)
{
  char **jn1 = (char **) v1;
  char **jn2 = (char **) v2;

  return strcmp(*jn1,*jn2);
}

static void journal_init(void) /* {{{ */
{
  int had_journal = 0;
  DIR *dir;
  struct dirent *dent;
  char path[PATH_MAX+1];

  if (journal_dir == NULL) return;

  pthread_mutex_lock(&journal_lock);

  journal_cur = calloc(1, sizeof(journal_set));
  if (journal_cur == NULL)
  {
    RRDD_LOG(LOG_CRIT, "journal_rotate: malloc(journal_set) failed\n");
    return;
  }

  RRDD_LOG(LOG_INFO, "checking for journal files");

  /* Handle old journal files during transition.  This gives them the
   * correct sort order.  TODO: remove after first release
   */
  {
    char old_path[PATH_MAX+1];
    snprintf(old_path, PATH_MAX, "%s/%s", journal_dir, JOURNAL_BASE ".old" );
    snprintf(path,     PATH_MAX, "%s/%s", journal_dir, JOURNAL_BASE ".0000");
    rename(old_path, path);

    snprintf(old_path, PATH_MAX, "%s/%s", journal_dir, JOURNAL_BASE        );
    snprintf(path,     PATH_MAX, "%s/%s", journal_dir, JOURNAL_BASE ".0001");
    rename(old_path, path);
  }

  dir = opendir(journal_dir);
  if (!dir) {
    RRDD_LOG(LOG_CRIT, "journal_init: opendir(%s) failed\n", journal_dir);
    return;
  }
  while ((dent = readdir(dir)) != NULL)
  {
    /* looks like a journal file? */
    if (strncmp(dent->d_name, JOURNAL_BASE, strlen(JOURNAL_BASE)))
      continue;

    snprintf(path, PATH_MAX, "%s/%s", journal_dir, dent->d_name);

    if (!rrd_add_strdup(&journal_cur->files, &journal_cur->files_num, path))
    {
      RRDD_LOG(LOG_CRIT, "journal_init: cannot add journal file %s!",
               dent->d_name);
      break;
    }
  }
  closedir(dir);

  qsort(journal_cur->files, journal_cur->files_num,
        sizeof(journal_cur->files[0]), journal_sort);

  for (uint i=0; i < journal_cur->files_num; i++)
    had_journal += journal_replay(journal_cur->files[i]);

  journal_new_file();

  /* it must have been a crash.  start a flush */
  if (had_journal && config_flush_at_shutdown)
    flush_old_values(-1);

  pthread_mutex_unlock(&journal_lock);

  RRDD_LOG(LOG_INFO, "journal processing complete");

} /* }}} static void journal_init */

static void free_listen_socket(listen_socket_t *sock) /* {{{ */
{
  assert(sock != NULL);

  free(sock->rbuf);  sock->rbuf = NULL;
  free(sock->wbuf);  sock->wbuf = NULL;
  free(sock);
} /* }}} void free_listen_socket */

static void close_connection(listen_socket_t *sock) /* {{{ */
{
  if (sock->fd >= 0)
  {
    close(sock->fd);
    sock->fd = -1;
  }

  free_listen_socket(sock);

} /* }}} void close_connection */

static void *connection_thread_main (void *args) /* {{{ */
{
  listen_socket_t *sock;
  int fd;

  sock = (listen_socket_t *) args;
  fd = sock->fd;

  /* init read buffers */
  sock->next_read = sock->next_cmd = 0;
  sock->rbuf = malloc(RBUF_SIZE);
  if (sock->rbuf == NULL)
  {
    RRDD_LOG(LOG_ERR, "connection_thread_main: cannot malloc read buffer");
    close_connection(sock);
    return NULL;
  }

  pthread_mutex_lock (&connection_threads_lock);
#ifdef HAVE_LIBWRAP
  /* LIBWRAP does not support multiple threads! By putting this code
     inside pthread_mutex_lock we do not have to worry about request_info
     getting overwritten by another thread.
  */
  struct request_info req;
  request_init(&req, RQ_DAEMON, "rrdcached\0", RQ_FILE, fd, NULL );
  fromhost(&req);
  if(!hosts_access(&req)) {
    RRDD_LOG(LOG_INFO, "refused connection from %s", eval_client(&req));
    pthread_mutex_unlock (&connection_threads_lock);
    close_connection(sock);
    return NULL;
  }
#endif /* HAVE_LIBWRAP */
  connection_threads_num++;
  pthread_mutex_unlock (&connection_threads_lock);

  while (state == RUNNING)
  {
    char *cmd;
    ssize_t cmd_len;
    ssize_t rbytes;
    time_t now;

    struct pollfd pollfd;
    int status;

    pollfd.fd = fd;
    pollfd.events = POLLIN | POLLPRI;
    pollfd.revents = 0;

    status = poll (&pollfd, 1, /* timeout = */ 500);
    if (state != RUNNING)
      break;
    else if (status == 0) /* timeout */
      continue;
    else if (status < 0) /* error */
    {
      status = errno;
      if (status != EINTR)
        RRDD_LOG (LOG_ERR, "connection_thread_main: poll(2) failed.");
      continue;
    }

    if ((pollfd.revents & POLLHUP) != 0) /* normal shutdown */
      break;
    else if ((pollfd.revents & (POLLIN | POLLPRI)) == 0)
    {
      RRDD_LOG (LOG_WARNING, "connection_thread_main: "
          "poll(2) returned something unexpected: %#04hx",
          pollfd.revents);
      break;
    }

    rbytes = read(fd, sock->rbuf + sock->next_read,
                  RBUF_SIZE - sock->next_read);
    if (rbytes < 0)
    {
      RRDD_LOG(LOG_ERR, "connection_thread_main: read() failed.");
      break;
    }
    else if (rbytes == 0)
      break; /* eof */

    sock->next_read += rbytes;

    if (sock->batch_start)
      now = sock->batch_start;
    else
      now = time(NULL);

    while ((cmd = next_cmd(sock, &cmd_len)) != NULL)
    {
      status = handle_request (sock, now, cmd, cmd_len+1);
      if (status != 0)
        goto out_close;
    }
  }

out_close:
  close_connection(sock);

  /* Remove this thread from the connection threads list */
  pthread_mutex_lock (&connection_threads_lock);
  connection_threads_num--;
  if (connection_threads_num <= 0)
    pthread_cond_broadcast(&connection_threads_done);
  pthread_mutex_unlock (&connection_threads_lock);

  return (NULL);
} /* }}} void *connection_thread_main */

static int open_listen_socket_unix (const listen_socket_t *sock) /* {{{ */
{
  int fd;
  struct sockaddr_un sa;
  listen_socket_t *temp;
  int status;
  const char *path;
  char *path_copy, *dir;

  path = sock->addr;
  if (strncmp(path, "unix:", strlen("unix:")) == 0)
    path += strlen("unix:");

  /* dirname may modify its argument */
  path_copy = strdup(path);
  if (path_copy == NULL)
  {
    fprintf(stderr, "rrdcached: strdup(): %s\n",
        rrd_strerror(errno));
    return (-1);
  }

  dir = dirname(path_copy);
  if (rrd_mkdir_p(dir, 0777) != 0)
  {
    fprintf(stderr, "Failed to create socket directory '%s': %s\n",
        dir, rrd_strerror(errno));
    return (-1);
  }

  free(path_copy);

  temp = (listen_socket_t *) rrd_realloc (listen_fds,
      sizeof (listen_fds[0]) * (listen_fds_num + 1));
  if (temp == NULL)
  {
    fprintf (stderr, "rrdcached: open_listen_socket_unix: realloc failed.\n");
    return (-1);
  }
  listen_fds = temp;
  memcpy (listen_fds + listen_fds_num, sock, sizeof (listen_fds[0]));

  fd = socket (PF_UNIX, SOCK_STREAM, /* protocol = */ 0);
  if (fd < 0)
  {
    fprintf (stderr, "rrdcached: unix socket(2) failed: %s\n",
             rrd_strerror(errno));
    return (-1);
  }

  memset (&sa, 0, sizeof (sa));
  sa.sun_family = AF_UNIX;
  strncpy (sa.sun_path, path, sizeof (sa.sun_path) - 1);

  /* if we've gotten this far, we own the pid file.  any daemon started
   * with the same args must not be alive.  therefore, ensure that we can
   * create the socket...
   */
  unlink(path);

  status = bind (fd, (struct sockaddr *) &sa, sizeof (sa));
  if (status != 0)
  {
    fprintf (stderr, "rrdcached: bind(%s) failed: %s.\n",
             path, rrd_strerror(errno));
    close (fd);
    return (-1);
  }

  /* tweak the sockets group ownership */
  if (sock->socket_group != (gid_t)-1)
  {
    if ( (chown(path, getuid(), sock->socket_group) != 0) ||
	 (chmod(path, (S_IRUSR|S_IWUSR|S_IXUSR | S_IRGRP|S_IWGRP)) != 0) )
    {
      fprintf(stderr, "rrdcached: failed to set socket group permissions (%s)\n", strerror(errno));
    }
  }

  if (sock->socket_permissions != (mode_t)-1)
  {
    if (chmod(path, sock->socket_permissions) != 0)
      fprintf(stderr, "rrdcached: failed to set socket file permissions (%o): %s\n",
          (unsigned int)sock->socket_permissions, strerror(errno));
  }

  status = listen (fd, /* backlog = */ 10);
  if (status != 0)
  {
    fprintf (stderr, "rrdcached: listen(%s) failed: %s.\n",
             path, rrd_strerror(errno));
    close (fd);
    unlink (path);
    return (-1);
  }

  listen_fds[listen_fds_num].fd = fd;
  listen_fds[listen_fds_num].family = PF_UNIX;
  strncpy(listen_fds[listen_fds_num].addr, path,
          sizeof (listen_fds[listen_fds_num].addr) - 1);
  listen_fds_num++;

  return (0);
} /* }}} int open_listen_socket_unix */

static int open_listen_socket_network(const listen_socket_t *sock) /* {{{ */
{
  struct addrinfo ai_hints;
  struct addrinfo *ai_res;
  struct addrinfo *ai_ptr;
  char addr_copy[NI_MAXHOST];
  char *addr;
  char *port;
  int status;

  strncpy (addr_copy, sock->addr, sizeof(addr_copy)-1);
  addr_copy[sizeof (addr_copy) - 1] = 0;
  addr = addr_copy;

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
      fprintf (stderr, "rrdcached: Malformed address: %s\n", sock->addr);
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
      fprintf (stderr, "rrdcached: Garbage after address: %s\n", port);
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
    fprintf (stderr, "rrdcached: getaddrinfo(%s) failed: %s\n",
             addr, gai_strerror (status));
    return (-1);
  }

  for (ai_ptr = ai_res; ai_ptr != NULL; ai_ptr = ai_ptr->ai_next)
  {
    int fd;
    listen_socket_t *temp;
    int one = 1;

    temp = (listen_socket_t *) rrd_realloc (listen_fds,
        sizeof (listen_fds[0]) * (listen_fds_num + 1));
    if (temp == NULL)
    {
      fprintf (stderr,
               "rrdcached: open_listen_socket_network: realloc failed.\n");
      continue;
    }
    listen_fds = temp;
    memcpy (listen_fds + listen_fds_num, sock, sizeof (listen_fds[0]));

    fd = socket (ai_ptr->ai_family, ai_ptr->ai_socktype, ai_ptr->ai_protocol);
    if (fd < 0)
    {
      fprintf (stderr, "rrdcached: network socket(2) failed: %s.\n",
               rrd_strerror(errno));
      continue;
    }

    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));

    status = bind (fd, ai_ptr->ai_addr, ai_ptr->ai_addrlen);
    if (status != 0)
    {
      fprintf (stderr, "rrdcached: bind(%s) failed: %s.\n",
               sock->addr, rrd_strerror(errno));
      close (fd);
      continue;
    }

    status = listen (fd, /* backlog = */ 10);
    if (status != 0)
    {
      fprintf (stderr, "rrdcached: listen(%s) failed: %s\n.",
               sock->addr, rrd_strerror(errno));
      close (fd);
      freeaddrinfo(ai_res);
      return (-1);
    }

    listen_fds[listen_fds_num].fd = fd;
    listen_fds[listen_fds_num].family = ai_ptr->ai_family;
    listen_fds_num++;
  } /* for (ai_ptr) */

  freeaddrinfo(ai_res);
  return (0);
} /* }}} static int open_listen_socket_network */

static int open_listen_socket (const listen_socket_t *sock) /* {{{ */
{
  assert(sock != NULL);
  assert(sock->addr != NULL);

  if (strncmp ("unix:", sock->addr, strlen ("unix:")) == 0
      || sock->addr[0] == '/')
    return (open_listen_socket_unix(sock));
  else
    return (open_listen_socket_network(sock));
} /* }}} int open_listen_socket */

static int close_listen_sockets (void) /* {{{ */
{
  size_t i;

  for (i = 0; i < listen_fds_num; i++)
  {
    close (listen_fds[i].fd);

    if (listen_fds[i].family == PF_UNIX)
      unlink(listen_fds[i].addr);
  }

  free (listen_fds);
  listen_fds = NULL;
  listen_fds_num = 0;

  return (0);
} /* }}} int close_listen_sockets */

static void *listen_thread_main (void UNUSED(*args)) /* {{{ */
{
  struct pollfd *pollfds;
  int pollfds_num;
  int status;
  int i;

  if (listen_fds_num < 1)
  {
    RRDD_LOG(LOG_ERR, "listen_thread_main: no listen_fds !");
    return (NULL);
  }

  pollfds_num = listen_fds_num;
  pollfds = (struct pollfd *) malloc (sizeof (*pollfds) * pollfds_num);
  if (pollfds == NULL)
  {
    RRDD_LOG (LOG_ERR, "listen_thread_main: malloc failed.");
    return (NULL);
  }
  memset (pollfds, 0, sizeof (*pollfds) * pollfds_num);

  RRDD_LOG(LOG_INFO, "listening for connections");

  while (state == RUNNING)
  {
    for (i = 0; i < pollfds_num; i++)
    {
      pollfds[i].fd = listen_fds[i].fd;
      pollfds[i].events = POLLIN | POLLPRI;
      pollfds[i].revents = 0;
    }

    status = poll (pollfds, pollfds_num, /* timeout = */ 1000);
    if (state != RUNNING)
      break;
    else if (status == 0) /* timeout */
      continue;
    else if (status < 0) /* error */
    {
      status = errno;
      if (status != EINTR)
      {
        RRDD_LOG (LOG_ERR, "listen_thread_main: poll(2) failed.");
      }
      continue;
    }

    for (i = 0; i < pollfds_num; i++)
    {
      listen_socket_t *client_sock;
      struct sockaddr_storage client_sa;
      socklen_t client_sa_size;
      pthread_t tid;
      pthread_attr_t attr;

      if (pollfds[i].revents == 0)
        continue;

      if ((pollfds[i].revents & (POLLIN | POLLPRI)) == 0)
      {
        RRDD_LOG (LOG_ERR, "listen_thread_main: "
            "poll(2) returned something unexpected for listen FD #%i.",
            pollfds[i].fd);
        continue;
      }

      client_sock = (listen_socket_t *) malloc (sizeof (listen_socket_t));
      if (client_sock == NULL)
      {
        RRDD_LOG (LOG_ERR, "listen_thread_main: malloc failed.");
        continue;
      }
      memcpy(client_sock, &listen_fds[i], sizeof(listen_fds[0]));

      client_sa_size = sizeof (client_sa);
      client_sock->fd = accept (pollfds[i].fd,
          (struct sockaddr *) &client_sa, &client_sa_size);
      if (client_sock->fd < 0)
      {
        RRDD_LOG (LOG_ERR, "listen_thread_main: accept(2) failed.");
        free(client_sock);
        continue;
      }

      pthread_attr_init (&attr);
      pthread_attr_setdetachstate (&attr, PTHREAD_CREATE_DETACHED);

      status = pthread_create (&tid, &attr, connection_thread_main,
                               client_sock);
      if (status != 0)
      {
        RRDD_LOG (LOG_ERR, "listen_thread_main: pthread_create failed.");
        close_connection(client_sock);
        continue;
      }
    } /* for (pollfds_num) */
  } /* while (state == RUNNING) */

  RRDD_LOG(LOG_INFO, "starting shutdown");

  close_listen_sockets ();

  pthread_mutex_lock (&connection_threads_lock);
  while (connection_threads_num > 0)
    pthread_cond_wait(&connection_threads_done, &connection_threads_lock);
  pthread_mutex_unlock (&connection_threads_lock);

  free(pollfds);

  return (NULL);
} /* }}} void *listen_thread_main */

static int daemonize (void) /* {{{ */
{
  int pid_fd;
  char *base_dir;

  daemon_uid = geteuid();

  pid_fd = open_pidfile("create", O_CREAT|O_EXCL|O_WRONLY);
  if (pid_fd < 0)
    pid_fd = check_pidfile();
  if (pid_fd < 0)
    return pid_fd;

  /* open all the listen sockets */
  if (config_listen_address_list_len > 0)
  {
    for (size_t i = 0; i < config_listen_address_list_len; i++)
      open_listen_socket (config_listen_address_list[i]);

    rrd_free_ptrs((void ***) &config_listen_address_list,
                  &config_listen_address_list_len);
  }
  else
  {
    strncpy(default_socket.addr, RRDCACHED_DEFAULT_ADDRESS,
        sizeof(default_socket.addr) - 1);
    default_socket.addr[sizeof(default_socket.addr) - 1] = '\0';

    if (default_socket.permissions == 0)
      socket_permission_set_all (&default_socket);

    open_listen_socket (&default_socket);
  }

  if (listen_fds_num < 1)
  {
    fprintf (stderr, "rrdcached: FATAL: cannot open any listen sockets\n");
    goto error;
  }

  if (!stay_foreground)
  {
    pid_t child;

    child = fork ();
    if (child < 0)
    {
      fprintf (stderr, "daemonize: fork(2) failed.\n");
      goto error;
    }
    else if (child > 0)
      exit(0);

    /* Become session leader */
    setsid ();

    /* Open the first three file descriptors to /dev/null */
    close (2);
    close (1);
    close (0);

    open ("/dev/null", O_RDWR);
    if (dup(0) == -1 || dup(0) == -1){
        RRDD_LOG (LOG_ERR, "faild to run dup.\n");
    }
  } /* if (!stay_foreground) */

  /* Change into the /tmp directory. */
  base_dir = (config_base_dir != NULL)
    ? config_base_dir
    : "/tmp";

  if (chdir (base_dir) != 0)
  {
    fprintf (stderr, "daemonize: chdir (%s) failed.\n", base_dir);
    goto error;
  }

  install_signal_handlers();

  openlog ("rrdcached", LOG_PID, LOG_DAEMON);
  RRDD_LOG(LOG_INFO, "starting up");

  cache_tree = g_tree_new_full ((GCompareDataFunc) strcmp, NULL, NULL,
                                (GDestroyNotify) free_cache_item);
  if (cache_tree == NULL)
  {
    RRDD_LOG (LOG_ERR, "daemonize: g_tree_new failed.");
    goto error;
  }

  return write_pidfile (pid_fd);

error:
  remove_pidfile();
  return -1;
} /* }}} int daemonize */

static int cleanup (void) /* {{{ */
{
  pthread_cond_broadcast (&flush_cond);
  pthread_join (flush_thread, NULL);

  pthread_cond_broadcast (&queue_cond);
  for (int i = 0; i < config_queue_threads; i++)
    pthread_join (queue_threads[i], NULL);

  if (config_flush_at_shutdown)
  {
    assert(cache_queue_head == NULL);
    RRDD_LOG(LOG_INFO, "clean shutdown; all RRDs flushed");
  }

  free(queue_threads);
  free(config_base_dir);

  pthread_mutex_lock(&cache_lock);
  g_tree_destroy(cache_tree);

  pthread_mutex_lock(&journal_lock);
  journal_done();

  RRDD_LOG(LOG_INFO, "goodbye");
  closelog ();

  remove_pidfile ();
  free(config_pid_file);

  return (0);
} /* }}} int cleanup */

static int read_options (int argc, char **argv) /* {{{ */
{
  int option;
  int status = 0;

  socket_permission_clear (&default_socket);

  default_socket.socket_group = (gid_t)-1;
  default_socket.socket_permissions = (mode_t)-1;

  while ((option = getopt(argc, argv, "gl:s:m:P:f:w:z:t:Bb:p:Fj:h?")) != -1)
  {
    switch (option)
    {
      case 'g':
        stay_foreground=1;
        break;

      case 'l':
      {
        listen_socket_t *new;

        new = malloc(sizeof(listen_socket_t));
        if (new == NULL)
        {
          fprintf(stderr, "read_options: malloc failed.\n");
          return(2);
        }
        memset(new, 0, sizeof(listen_socket_t));

        strncpy(new->addr, optarg, sizeof(new->addr)-1);

        /* Add permissions to the socket {{{ */
        if (default_socket.permissions != 0)
        {
          socket_permission_copy (new, &default_socket);
        }
        else /* if (default_socket.permissions == 0) */
        {
          /* Add permission for ALL commands to the socket. */
          socket_permission_set_all (new);
        }
        /* }}} Done adding permissions. */

        new->socket_group = default_socket.socket_group;
        new->socket_permissions = default_socket.socket_permissions;

        if (!rrd_add_ptr((void ***)&config_listen_address_list,
                         &config_listen_address_list_len, new))
        {
          fprintf(stderr, "read_options: rrd_add_ptr failed.\n");
          return (2);
        }
      }
      break;

      /* set socket group permissions */
      case 's':
      {
	gid_t group_gid;
	struct group *grp;

	group_gid = strtoul(optarg, NULL, 10);
	if (errno != EINVAL && group_gid>0)
	{
	  /* we were passed a number */
	  grp = getgrgid(group_gid);
	}
	else
	{
	  grp = getgrnam(optarg);
	}

	if (grp)
	{
	  default_socket.socket_group = grp->gr_gid;
	}
	else
	{
	  /* no idea what the user wanted... */
	  fprintf (stderr, "read_options: couldn't map \"%s\" to a group, Sorry\n", optarg);
	  return (5);
	}
      }
      break;

      /* set socket file permissions */
      case 'm':
      {
        long  tmp;
        char *endptr = NULL;

        tmp = strtol (optarg, &endptr, 8);
        if ((endptr == optarg) || (! endptr) || (*endptr != '\0')
            || (tmp > 07777) || (tmp < 0)) {
          fprintf (stderr, "read_options: Invalid file mode \"%s\".\n",
              optarg);
          return (5);
        }

        default_socket.socket_permissions = (mode_t)tmp;
      }
      break;

      case 'P':
      {
        char *optcopy;
        char *saveptr;
        char *dummy;
        char *ptr;

        socket_permission_clear (&default_socket);

        optcopy = strdup (optarg);
        dummy = optcopy;
        saveptr = NULL;
        while ((ptr = strtok_r (dummy, ", ", &saveptr)) != NULL)
        {
          dummy = NULL;
          status = socket_permission_add (&default_socket, ptr);
          if (status != 0)
          {
            fprintf (stderr, "read_options: Adding permission \"%s\" to "
                "socket failed. Most likely, this permission doesn't "
                "exist. Check your command line.\n", ptr);
            status = 4;
          }
        }

        free (optcopy);
      }
      break;

      case 'f':
      {
        int temp;

        temp = atoi (optarg);
        if (temp > 0)
          config_flush_interval = temp;
        else
        {
          fprintf (stderr, "Invalid flush interval: %s\n", optarg);
          status = 3;
        }
      }
      break;

      case 'w':
      {
        int temp;

        temp = atoi (optarg);
        if (temp > 0)
          config_write_interval = temp;
        else
        {
          fprintf (stderr, "Invalid write interval: %s\n", optarg);
          status = 2;
        }
      }
      break;

      case 'z':
      {
        int temp;

        temp = atoi(optarg);
        if (temp > 0)
          config_write_jitter = temp;
        else
        {
          fprintf (stderr, "Invalid write jitter: -z %s\n", optarg);
          status = 2;
        }

        break;
      }

      case 't':
      {
        int threads;
        threads = atoi(optarg);
        if (threads >= 1)
          config_queue_threads = threads;
        else
        {
          fprintf (stderr, "Invalid thread count: -t %s\n", optarg);
          return 1;
        }
      }
      break;

      case 'B':
        config_write_base_only = 1;
        break;

      case 'b':
      {
        size_t len;
        char base_realpath[PATH_MAX];

        if (config_base_dir != NULL)
          free (config_base_dir);
        config_base_dir = strdup (optarg);
        if (config_base_dir == NULL)
        {
          fprintf (stderr, "read_options: strdup failed.\n");
          return (3);
        }

        if (rrd_mkdir_p (config_base_dir, 0777) != 0)
        {
          fprintf (stderr, "Failed to create base directory '%s': %s\n",
              config_base_dir, rrd_strerror (errno));
          return (3);
        }

        /* make sure that the base directory is not resolved via
         * symbolic links.  this makes some performance-enhancing
         * assumptions possible (we don't have to resolve paths
         * that start with a "/")
         */
        if (realpath(config_base_dir, base_realpath) == NULL)
        {
          fprintf (stderr, "Failed to canonicalize the base directory '%s': "
              "%s\n", config_base_dir, rrd_strerror(errno));
          return 5;
        }

        len = strlen (config_base_dir);
        while ((len > 0) && (config_base_dir[len - 1] == '/'))
        {
          config_base_dir[len - 1] = 0;
          len--;
        }

        if (len < 1)
        {
          fprintf (stderr, "Invalid base directory: %s\n", optarg);
          return (4);
        }

        _config_base_dir_len = len;

        len = strlen (base_realpath);
        while ((len > 0) && (base_realpath[len - 1] == '/'))
        {
          base_realpath[len - 1] = '\0';
          len--;
        }

        if (strncmp(config_base_dir,
                         base_realpath, sizeof(base_realpath)) != 0)
        {
          fprintf(stderr,
                  "Base directory (-b) resolved via file system links!\n"
                  "Please consult rrdcached '-b' documentation!\n"
                  "Consider specifying the real directory (%s)\n",
                  base_realpath);
          return 5;
        }
      }
      break;

      case 'p':
      {
        if (config_pid_file != NULL)
          free (config_pid_file);
        config_pid_file = strdup (optarg);
        if (config_pid_file == NULL)
        {
          fprintf (stderr, "read_options: strdup failed.\n");
          return (3);
        }
      }
      break;

      case 'F':
        config_flush_at_shutdown = 1;
        break;

      case 'j':
      {
        char journal_dir_actual[PATH_MAX];
        const char *dir;
        if (realpath((const char *)optarg, journal_dir_actual) == NULL)
        {
          fprintf(stderr, "Failed to canonicalize the journal directory '%s': %s\n",
              optarg, rrd_strerror(errno));
          return 7;
        }
        dir = journal_dir = strdup(journal_dir_actual);
        if (dir == NULL) {
          fprintf (stderr, "read_options: strdup failed.\n");
          return (3);
        }

        status = rrd_mkdir_p(dir, 0777);
        if (status != 0)
        {
          fprintf(stderr, "Failed to create journal directory '%s': %s\n",
              dir, rrd_strerror(errno));
          return 6;
        }

        if (access(dir, R_OK|W_OK|X_OK) != 0)
        {
          fprintf(stderr, "Must specify a writable directory with -j! (%s)\n",
                  errno ? rrd_strerror(errno) : "");
          return 6;
        }
      }
      break;

      case 'h':
      case '?':
        printf ("RRDCacheD %s\n"
            "Copyright (C) 2008,2009 Florian octo Forster and Kevin Brintnall\n"
            "\n"
            "Usage: rrdcached [options]\n"
            "\n"
            "Valid options are:\n"
            "  -l <address>  Socket address to listen to.\n"
            "                Default: "RRDCACHED_DEFAULT_ADDRESS"\n"
            "  -P <perms>    Sets the permissions to assign to all following "
                            "sockets\n"
            "  -w <seconds>  Interval in which to write data.\n"
            "  -z <delay>    Delay writes up to <delay> seconds to spread load\n"
            "  -t <threads>  Number of write threads.\n"
            "  -f <seconds>  Interval in which to flush dead data.\n"
            "  -p <file>     Location of the PID-file.\n"
            "  -b <dir>      Base directory to change to.\n"
            "  -B            Restrict file access to paths within -b <dir>\n"
            "  -g            Do not fork and run in the foreground.\n"
            "  -j <dir>      Directory in which to create the journal files.\n"
            "  -F            Always flush all updates at shutdown\n"
            "  -s <id|name>  Group owner of all following UNIX sockets\n"
            "                (the socket will also have read/write permissions "
                            "for that group)\n"
            "  -m <mode>     File permissions (octal) of all following UNIX "
                            "sockets\n"
            "\n"
            "For more information and a detailed description of all options "
            "please refer\n"
            "to the rrdcached(1) manual page.\n",
            VERSION);
        if (option == 'h')
          status = -1;
        else
          status = 1;
        break;
    } /* switch (option) */
  } /* while (getopt) */

  /* advise the user when values are not sane */
  if (config_flush_interval < 2 * config_write_interval)
    fprintf(stderr, "WARNING: flush interval (-f) should be at least"
            " 2x write interval (-w) !\n");
  if (config_write_jitter > config_write_interval)
    fprintf(stderr, "WARNING: write delay (-z) should NOT be larger than"
            " write interval (-w) !\n");

  if (config_write_base_only && config_base_dir == NULL)
    fprintf(stderr, "WARNING: -B does not make sense without -b!\n"
            "  Consult the rrdcached documentation\n");

  if (journal_dir == NULL)
    config_flush_at_shutdown = 1;

  return (status);
} /* }}} int read_options */

int main (int argc, char **argv)
{
  int status;

  status = read_options (argc, argv);
  if (status != 0)
  {
    if (status < 0)
      status = 0;
    return (status);
  }

  status = daemonize ();
  if (status != 0)
  {
    fprintf (stderr, "rrdcached: daemonize failed, exiting.\n");
    return (1);
  }

  journal_init();

  /* start the queue threads */
  queue_threads = calloc(config_queue_threads, sizeof(*queue_threads));
  if (queue_threads == NULL)
  {
    RRDD_LOG (LOG_ERR, "FATAL: cannot calloc queue threads");
    cleanup();
    return (1);
  }
  for (int i = 0; i < config_queue_threads; i++)
  {
    memset (&queue_threads[i], 0, sizeof (*queue_threads));
    status = pthread_create (&queue_threads[i], NULL, queue_thread_main, NULL);
    if (status != 0)
    {
      RRDD_LOG (LOG_ERR, "FATAL: cannot create queue thread");
      cleanup();
      return (1);
    }
  }

  /* start the flush thread */
  memset(&flush_thread, 0, sizeof(flush_thread));
  status = pthread_create (&flush_thread, NULL, flush_thread_main, NULL);
  if (status != 0)
  {
    RRDD_LOG (LOG_ERR, "FATAL: cannot create flush thread");
    cleanup();
    return (1);
  }

  listen_thread_main (NULL);
  cleanup ();

  return (0);
} /* int main */

/*
 * vim: set sw=2 sts=2 ts=8 et fdm=marker :
 */
