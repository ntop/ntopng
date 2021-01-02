/*
 *
 * (C) 2013-21 - ntop.org
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

//#define DEBUG_RW_LOCK

/* ******************************* */

RwLock::RwLock() {
#ifndef HAVE_RW_LOCK
  Mutex m;
#else
  pthread_rwlock_init(&the_rwlock, NULL);
#endif
}

/* ******************************* */

RwLock::~RwLock() {
#ifndef HAVE_RW_LOCK
  /* Mutex destructor called automatically */
#else
  pthread_rwlock_destroy(&the_rwlock);
#endif
}

/* ******************************* */

void RwLock::lock(const char *filename, int line, bool readonly) {
#ifndef HAVE_RW_LOCK
#ifdef DEBUG_RW_LOCK
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s:%d] lock(%p)", filename, line, &m);
#endif
  m.lock(filename, line);
#else
  int rc;

  if(readonly) {
#ifdef DEBUG_RW_LOCK
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s:%d] lock(RO, %p)", filename, line, &the_rwlock);
#endif
    rc = pthread_rwlock_rdlock(&the_rwlock);
  } else {
#ifdef DEBUG_RW_LOCK
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s:%d] lock(RW, %p)", filename, line, &the_rwlock);
#endif
    rc = pthread_rwlock_wrlock(&the_rwlock);
  }

  if(rc)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to acquire lock. Return code %d [%s]", rc, strerror(rc), errno);
#endif
}

/* ******************************* */

bool RwLock::trylock(const char *filename, int line, bool readonly) {
#ifndef HAVE_RW_LOCK
  m.lock(filename, line);
  return true; /* Pretend to be always successful - indeed, if here the lock is acquired even in a blocking fashion */
#else
  int rc;

  if(readonly)
    rc = pthread_rwlock_tryrdlock(&the_rwlock);
  else
    rc = pthread_rwlock_trywrlock(&the_rwlock);

  if(!rc)
    return true; /* Lock acquired successfully */

  if(rc == EBUSY)
    ;  /* Normal, lock is being held by someone else */
  else
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Unable to acquire lock. Return code %d [%s]",  rc, strerror(rc));

  return false; /* Lock not acquired, held by someone else or there was an error */
#endif
}

/* ******************************* */

void RwLock::rdlock(const char *filename, int line) {
  lock(filename, line, true /* readonly */);
}

/* ******************************* */

void RwLock::wrlock(const char *filename, int line) {
  lock(filename, line, false /* write */);
}

/* ******************************* */

bool RwLock::trywrlock(const char *filename, int line) {
  return trylock(filename, line, false /* write */);
}

/* ******************************* */

void RwLock::unlock(const char *filename, int line) {
#ifndef HAVE_RW_LOCK
#ifdef DEBUG_RW_LOCK
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s:%d] unlock(%p)", filename, line, &m);
#endif
  m.unlock(filename, line);
#else
  int rc;

#ifdef DEBUG_RW_LOCK
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s:%d] unlock(%p)", filename, line, &the_rwlock);
#endif
  rc = pthread_rwlock_unlock(&the_rwlock);

  if(rc)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "pthread_rwlock_unlock() returned %d [%s]", rc, strerror(rc), errno);
#endif
}
