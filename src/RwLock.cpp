/*
 *
 * (C) 2013-18 - ntop.org
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

RwLock::RwLock() {
  pthread_rwlock_init(&the_rwlock, NULL);
#ifdef RWLOCK_DEBUG
  num_locks = num_unlocks = 0;
  last_lock_file[0] = '\0', last_unlock_file[0] = '\0';
  last_lock_line = last_unlock_line = 0;
#endif
}

/* ******************************* */

void RwLock::lock(const char *filename, const int line, bool readonly) {
  int rc;

  errno = 0;

  if(readonly)
    rc = pthread_rwlock_rdlock(&the_rwlock);
  else
    rc = pthread_rwlock_wrlock(&the_rwlock);

  if(rc != 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, 
					"Unable to acquire lock. Return code %d [%s][errno=%d]", 
					rc, strerror(rc), errno);

#ifdef RWLOCK_DEBUG
  snprintf(last_lock_file, sizeof(last_lock_file), "%s", filename);
  last_lock_line = line, num_locks++;
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p)", __FUNCTION__, this);
#endif
}

/* ******************************* */

void RwLock::unlock(const char *filename, const int line) {
  int rc;

  errno = 0;  

  rc = pthread_rwlock_unlock(&the_rwlock);
  
  if(rc != 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, 
					"pthread_rwlock_unlock() returned %d [%s][errno=%d]",
					rc, strerror(rc), errno);

#ifdef RWLOCK_DEBUG
  snprintf(last_unlock_file, sizeof(last_unlock_file), "%s", filename);
  last_unlock_line = line, num_unlocks++;
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p)", __FUNCTION__, this);
#endif
}
