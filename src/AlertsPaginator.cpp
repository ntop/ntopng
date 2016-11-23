/*
 *
 * (C) 2013-16 - ntop.org
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

/* **************************************************** */

AlertsPaginator::AlertsPaginator() : Paginator() {
  /* char* */
  sort_column = strdup("column_date");
  a2z_sort_order = false;
  alert_severity_set = alert_type_set = alert_entity_set = false;
  alert_entity_value = NULL;
};

/* **************************************************** */

AlertsPaginator::~AlertsPaginator() {
  if(alert_entity_value) free(alert_entity_value);
}

/* **************************************************** */

void AlertsPaginator::readOptions(lua_State *L, int index) {
  Paginator::readOptions(L, index);

  lua_pushnil(L);

  while(lua_next(L, index) != 0) {
    const char *key = lua_tostring(L, -2);
    int t = lua_type(L, -1);

    switch(t) {
    case LUA_TSTRING:
      if(!strcmp(key, "entityValueFilter")) {
	if(alert_entity_value) free(alert_entity_value);
	alert_entity_value = strdup(lua_tostring(L, -1));
      }
      //ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid string type (%s) for option %s", lua_tostring(L, -1), key);
      break;

    case LUA_TNUMBER:
      if(!strcmp(key, "severityFilter")) {
	alert_severity_set = true;
	alert_severity = (AlertLevel)lua_tointeger(L, -1);
      }
      else if(!strcmp(key, "typeFilter")) {
	alert_type_set = true;
	alert_type = (AlertType)lua_tointeger(L, -1);
      }
      else if(!strcmp(key, "entityFilter")) {
	alert_entity_set = true;
	alert_entity = (AlertEntity)lua_tointeger(L, -1);
      }
      break;
    }

    lua_pop(L, 1);
  }
}
