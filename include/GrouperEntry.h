/*
 *
 * (C) 2015-16 - ntop.org
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

#ifndef _GROUPER_ENTRY_H_
#define _GROUPER_ENTRY_H_

#include "ntop_includes.h"

class GrouperEntry {
 private:
  char *name;
  u_int32_t num_hosts;

 public:
  GrouperEntry(const char *label);
  ~GrouperEntry();

  inline void incStats() {num_hosts++;};

  void lua(lua_State* vm);
  void print();
};

#endif /* _GROUPER_ENTRY_H_ */
