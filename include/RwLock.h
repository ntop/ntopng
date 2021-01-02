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

#ifndef _RWLOCK_H_
#define _RWLOCK_H_

#include "ntop_includes.h"

/* ******************************* */

class RwLock {
 private:
#ifndef HAVE_RW_LOCK
  Mutex m;
#else
  pthread_rwlock_t the_rwlock;
#endif
  void lock(const char *filename, int line, bool readonly);
  bool trylock(const char *filename, int line, bool readonly);

 public:
  RwLock();
  ~RwLock();

  void rdlock(const char *filename, int line);
  void wrlock(const char *filename, int line);
  bool trywrlock(const char *filename, int line);
  void unlock(const char *filename, int line);
};


#endif /* _RWLOCK_H_ */
