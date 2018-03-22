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

#ifndef _MUTEX_H_
#define _MUTEX_H_

#include "ntop_includes.h"

/* #define MUTEX_DEBUG 1 */

/* ******************************* */

class Mutex {
 private:
  pthread_mutex_t the_mutex;
  bool locked;  
#ifdef MUTEX_DEBUG
  char last_lock_file[64], last_unlock_file[64];
  int  last_lock_line, last_unlock_line;
  u_int num_locks, num_unlocks;
#endif
  void initialize();

 public:
  Mutex();
  void lock(const char *filename, const int line);
  void unlock(const char *filename, const int line);  
  inline bool is_locked() { return(locked); };

  /* NOTE: this must be called while locked */
  inline int cond_wait(pthread_cond_t *condvar) { return pthread_cond_wait(condvar, &the_mutex); };
};


#endif /* _MUTEX_H_ */
