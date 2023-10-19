/*
 *
 * (C) 2013-23 - ntop.org
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

/* ************************************ */

Condvar::Condvar() { init(); }

/* ************************************ */

void Condvar::init() {
  pthread_mutex_init(&mutex, NULL);
  pthread_cond_init(&condvar, NULL);
  predicate = false;
}

/* ************************************ */

Condvar::~Condvar() {
  pthread_mutex_destroy(&mutex);
  pthread_cond_destroy(&condvar);
}

/* ************************************ */

int Condvar::wait() {
  int rc;

  if ((rc = pthread_mutex_lock(&mutex)) != 0) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Condvar::wait() lock failed %d/%s", rc, strerror(rc));
    return rc;
  }

  while (predicate == false) rc = pthread_cond_wait(&condvar, &mutex);

  predicate = false;

  rc = pthread_mutex_unlock(&mutex);

  return rc;
}

/* ************************************ */

int Condvar::timedWait(struct timespec *expiration) {
  int rc;

  if ((rc = pthread_mutex_lock(&mutex)) != 0) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Condvar::wait() lock failed %d/%s", rc, strerror(rc));
    return rc;
  }

#if 1
  while (predicate == false) {
    rc = pthread_cond_timedwait(&condvar, &mutex, expiration);

    if (rc == ETIMEDOUT) {
      pthread_mutex_unlock(&mutex);
      return rc;
    }
  }
#endif

  predicate = false;

  return (pthread_mutex_unlock(&mutex));
}

/* ************************************ */

int Condvar::signal_waiters(bool signal_all) {
  int rc;

  rc = pthread_mutex_lock(&mutex);

  predicate = true;

  rc = pthread_mutex_unlock(&mutex);

  if (signal_all)
    rc = pthread_cond_broadcast(&condvar);
  else
    rc = pthread_cond_signal(&condvar);

  return rc;
}
