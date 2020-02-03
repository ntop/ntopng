/*
 *
 * (C) 2020 - ntop.org
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

void Bin::lua(lua_State* vm, const char *bin_label) const {
    u_int32_t total, i;

    lua_newtable(vm);

    for(i=0, total=0; i<MAX_NUM_BINS; i++)
      total += bins[i];

    if(total == 0) total = 1;

    for(i=0; i<MAX_NUM_BINS; i++) {
      const char *label;

      switch(i) {
      case 0:
	label = "<= 1";
	break;

      case 1:
	label = "<= 3";
	break;

      case 2:
	label = "<= 5";
	break;

      case 3:
	label = "<= 10";
	break;

      case 4:
	label = "<= 30";
	break;

      case 5:
	label = "<= 60";
	break;

      case 6:
	label = "<= 300";
	break;

      case 7:
	label = "> 300";
	break;
      }

      lua_push_float_table_entry(vm, label, (float)bins[i]/(float)total);
    }

    lua_pushstring(vm, bin_label);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
