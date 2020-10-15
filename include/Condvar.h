/*
 *
 * (C) 2014-20 - ntop.org
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


#ifndef _CONDVAR_H_
#define _CONDVAR_H_

#include "ntop_includes.h"

/* ******************************* */

class Condvar {
 private:
  pthread_mutex_t mutex;
  pthread_cond_t  condvar;
  bool predicate;

  int signal_waiters(bool signal_all);
  
 public:
  Condvar();
  ~Condvar();

  void init();
  int wait();
  int timedWait(struct timespec *expiration);

  inline int signal()    { return(signal_waiters(false)); };
  inline int signalAll() { return(signal_waiters(true));  };
};


#endif /* _CONDVAR_H_ */
