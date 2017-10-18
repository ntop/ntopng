/*
 *
 * (C) 2013-17 - ntop.org
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

ConditionalVariable::ConditionalVariable() {
  pthread_mutex_init(&mutex, NULL);
  pthread_cond_init(&condvar, NULL);
}

/* ************************************ */

ConditionalVariable::~ConditionalVariable() {
  pthread_mutex_destroy(&mutex);
  pthread_cond_destroy(&condvar);
}

/* ************************************ */

int ConditionalVariable::wait() {
  int rc;

  if((rc = pthread_mutex_lock(&mutex)) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "lock failed %d/%s", rc, strerror(rc));
    return rc;
  }
  
  pthread_cond_wait(&condvar, &mutex);
  return(pthread_mutex_unlock(&mutex));
}

/* ************************************ */

int ConditionalVariable::signal(bool broadcast) {
  int rc;

#ifdef DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%s)", __FUNCTION__, broadcast ? "broadcast" : "");
#endif
  
  if(broadcast)
    rc = pthread_cond_broadcast(&condvar);
  else
    rc = pthread_cond_signal(&condvar);

  return rc;
}

