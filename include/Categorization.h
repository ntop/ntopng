/*
 *
 * (C) 2013-16 - ntop.org
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

#ifndef _CATEGORIZATION_H_
#define _CATEGORIZATION_H_

#include "ntop_includes.h"

typedef struct {
  u_int8_t major, minor;
} HostCategory;

class Categorization {
  u_int32_t num_categorized_categorizationes, num_categorized_fails;
  char *api_key;

  pthread_t categorizeThreadLoop;

  void googleCategorizeHostName(char *sym_ip, char *buf, u_int buf_len);
  void httpCategorizeHostName(char *sym_ip, char *buf, u_int buf_len);

  static const int default_expire_time = 3600;

 public:
  Categorization(char *_api_key);
  ~Categorization();

  void startCategorizeCategorizationLoop();
  char* findCategory(char *url, char *buf, u_int buf_len, bool add_if_needed);
  void* categorizeLoop();
};

#endif /* _CATEGORIZATION_H_ */
