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

#ifndef _GROUPER_H_
#define _GROUPER_H_

#include "ntop_includes.h"

class GrouperEntry;
class Host;

enum grouper_dimension_t {ASN, OS, MAC, COUNTRY, INVALID};

//template <class T>
class Grouper {
 private:
  grouper_dimension_t dimension;
  //  map<T,    GrouperEntry*> grouper;
  map<int,    GrouperEntry*> number_grouper;
  map<string, GrouperEntry*> string_grouper;

  void incStats(const char* group_key);
  void incStats(int   group_key);
  GrouperEntry *getGrouperEntryAt(const char *group_key, const char *label);
  GrouperEntry *getGrouperEntryAt(int group_key, const char *label);
 public:
  Grouper(const char *dimension);
  ~Grouper();

  void group(Host *h);

  u_int32_t numEntries(){return number_grouper.size() + string_grouper.size();};
  void lua(lua_State* vm);
  void print();
};

#endif /* _GROUPER_H_ */
