/*
 *
 * (C) 2013-22 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"


/* ******************************* */

Mutex::Mutex() {
  pthread_mutex_init(&the_mutex, NULL);
  locked = false;
#ifdef MUTEX_DEBUG
  num_locks = num_unlocks = 0;
  last_lock_file[0] = '\0', last_unlock_file[0] = '\0';
  last_lock_line = last_unlock_line = 0;
#endif
}

/* ******************************* */

bool Mutex::lock(const char *filename, const int line, bool trace_errors) {
  int rc;

  errno = 0;
  rc = pthread_mutex_lock(&the_mutex);
  //~ printf("LOCK %s:%d\n", filename, line);

  if(rc != 0) {
    if(trace_errors)
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "pthread_mutex_lock() returned %d [%s][errno=%d]",
				   rc, strerror(rc), errno);
  } else
    locked = true;

#ifdef MUTEX_DEBUG
  snprintf(last_lock_file, sizeof(last_lock_file), "%s", filename);
  last_lock_line = line, num_locks++;
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p)", __FUNCTION__, this);
#endif

  return(locked);
}

/* ******************************* */

#ifdef __APPLE__
/*
 *
 * https://www.mail-archive.com/dev@apr.apache.org/msg26846.html
 *
 * A pthread_mutex_timedlock() impl for OSX/macOS, which lacks the
 * real thing.
 * NOTE: Unlike the real McCoy, won't return EOWNERDEAD, EDEADLK
 *       or EOWNERDEAD
 */
static int pthread_mutex_timedlock(pthread_mutex_t *mutex, struct timespec *abs_timeout) {
  int rv;
  struct timespec remaining, slept, ts;

  remaining = *abs_timeout;

  while((rv = pthread_mutex_trylock(mutex)) == EBUSY) {
    ts.tv_sec = 0;
    ts.tv_nsec = (remaining.tv_sec > 0 ? 10000000 :
		  (remaining.tv_nsec < 10000000 ? remaining.tv_nsec :
		   10000000));
    nanosleep(&ts, &slept);
    ts.tv_nsec -= slept.tv_nsec;

    if(ts.tv_nsec <= remaining.tv_nsec) {
      remaining.tv_nsec -= ts.tv_nsec;
    } else {
      remaining.tv_sec--;
      remaining.tv_nsec = (1000000 - (ts.tv_nsec - remaining.tv_nsec));
    }

    if(remaining.tv_sec < 0
       || (!remaining.tv_sec && remaining.tv_nsec <= 0)) {
      return ETIMEDOUT;
    }
  }

  return rv;
}

#endif /* __APPLE__ */

/* ******************************* */

bool Mutex::lockTimeout(const char *filename, const int line, struct timespec *wait, bool trace_errors) {
  int rc;

  errno = 0;
  rc = pthread_mutex_timedlock(&the_mutex, wait);
  //~ printf("LOCK %s:%d\n", filename, line);

  if(rc != 0) {
    if(trace_errors)
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "pthread_mutex_timedlock() returned %d [%s][errno=%d]",
				   rc, strerror(rc), errno);
  } else
    locked = true;

#ifdef MUTEX_DEBUG
  snprintf(last_lock_file, sizeof(last_lock_file), "%s", filename);
  last_lock_line = line, num_locks++;
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p)", __FUNCTION__, this);
#endif

  return(locked);
}

/* ******************************* */

void Mutex::unlock(const char *filename, const int line, bool trace_errors) {
  int rc;

  errno = 0;
  //~ printf("UNLOCK %s:%d\n", filename, line);

  rc = pthread_mutex_unlock(&the_mutex);

  if(rc != 0) {
    if(trace_errors && (errno != 0))
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "pthread_mutex_unlock() returned %d [%s][errno=%d]",
				   rc, strerror(rc), errno);
  }
  locked = false; /* Always unlock */

#ifdef MUTEX_DEBUG
  snprintf(last_unlock_file, sizeof(last_unlock_file), "%s", filename);
  last_unlock_line = line, num_unlocks++;
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p)", __FUNCTION__, this);
#endif
}

/* ******************************* */
/*
#ifdef WIN32
static int pthread_mutex_lock(pthread_mutex_t *mutex) {
  return WaitForSingleObject(*mutex, INFINITE) == WAIT_OBJECT_0? 0 : -1;
}

static int pthread_mutex_unlock(pthread_mutex_t *mutex) {
  return ReleaseMutex(*mutex) == 0 ? -1 : 0;
}
#endif
*/
