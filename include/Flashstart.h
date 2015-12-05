/*
 *
 * (C) 2015 - ntop.org
 *
 *
 * This program is free software; you can addresstribute it and/or modify
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

#ifndef _FLASHSTART_H_
#define _FLASHSTART_H_

#include "ntop_includes.h"

class Flashstart {
  u_int32_t num_flashstart_categorizations, num_flashstart_fails;
  char *user, *pwd;

  pthread_t flashstartThreadLoop;
  void queryFlashstart(char *numeric_ip);

 public:
  Flashstart(char *_user, char *_pwd);
  ~Flashstart();

  char* findTrafficCategory(char *name, char *buf, u_int buf_len, bool add_if_needed); 
  void startLoop();
  void* flashstartLoop(void* ptr);
};

#endif /* _FLASHSTART_H_ */
