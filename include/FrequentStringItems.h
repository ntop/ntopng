/*
 *
 * (C) 2017-23 - ntop.org
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

#ifndef _FREQUENT_STRING_ITEMS_H_
#define _FREQUENT_STRING_ITEMS_H_

#include "ntop_includes.h"

/* https://resources.sei.cmu.edu/asset_files/Presentation/2010_017_001_49763.pdf
 */

/* *************************************** */

class FrequentStringItems {
 private:
  u_int32_t max_items, max_items_threshold;
  std::map<std::string, u_int32_t> q;
  Mutex m;
  bool thread_safe;

  void prune();

 public:
  FrequentStringItems(u_int32_t _max_items, bool _thread_safe = true) {
    max_items = _max_items, max_items_threshold = 2 * _max_items,
    thread_safe = _thread_safe;
  }

  inline u_int32_t getSize() { return q.size(); };
  void add(char* key, u_int32_t value);
  char* json(u_int32_t max_num_items = (u_int32_t)-1);
  inline void clear() { q.clear(); }
};

#endif /* _FREQUENT_STRING_ITEMS_H_ */
