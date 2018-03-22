/*
 *
 * (C) 2013-18 - ntop.org
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

#ifndef _HTTPBL_H_
#define _HTTPBL_H_

#include "ntop_includes.h"

class HTTPBL {
  u_int32_t num_httpblized_categorizations, num_httpblized_fails;
  char *api_key;

  pthread_t httpblThreadLoop;
  void queryHTTPBL(char *numeric_ip);

 public:
  HTTPBL(char *_api_key);
  ~HTTPBL();

  char* findCategory(char *name, char *buf, u_int buf_len, bool add_if_needed); 
  void startLoop();
  void* httpblLoop(void* ptr);
};

#endif /* _HTTPBL_H_ */
