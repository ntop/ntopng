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

#include "ntop_includes.h"

/* *************************************** */

GrouperEntry::GrouperEntry(const char *label) {
  if(label)
    name = strdup(label);
  else
    name = NULL;
  num_hosts = 0;
}

/* *************************************** */
GrouperEntry::~GrouperEntry(){
  if(name){
    free(name);
    name = NULL;
  }
}

/* *************************************** */

void GrouperEntry::lua(lua_State* vm) {
  lua_newtable(vm);
  lua_push_int_table_entry(vm, "num_hosts", num_hosts);
  lua_pushstring(vm, name ? name : (char*)"");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void GrouperEntry::print() {
  char *l = name ? name : (char*)"";
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s\tnum_hosts: %i", l, num_hosts);
}
