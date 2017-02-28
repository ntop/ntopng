/*
 *
 * (C) 2013-17 - ntop.org
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

Paginator::Paginator() {
  /* char* */
  sort_column = strdup("column_thpt");
  country_filter = NULL;
  host_filter = NULL;

  /* bool */
  a2z_sort_order = true;
  detailed_results = false;

  /* int */
  max_hits = CONST_MAX_NUM_HITS;
  to_skip = 0;
  l7proto_filter = NDPI_PROTOCOL_UNKNOWN;
  port_filter = 0;
  local_network_filter = 0;
  client_mode = location_all;
  server_mode = location_all;

  /*
    TODO MISSING

    osFilter
    vlanFilter
    asnFilter
  */
};

/* **************************************************** */

Paginator::~Paginator() {
  if(sort_column)    free(sort_column);
  if(country_filter) free(country_filter);
  if(host_filter)    free(host_filter);
}

/* **************************************************** */

void Paginator::readOptions(lua_State *L, int index) {
  /*
    See https://www.lua.org/ftp/refman-5.0.pdf for a detailed description
    of lua traversal of tables
  */
  lua_pushnil(L);

  while(lua_next(L, index) != 0) {
    if(lua_type(L, -1) == LUA_TTABLE) {
      /* removes 'value'; keeps 'key' for next iteration */
      Paginator::readOptions(L, index);
    } else {
      const char *key = lua_tostring(L, -2);
      int t = lua_type(L, -1);

      switch(t) {
      case LUA_TSTRING:
	if(!strcmp(key, "sortColumn")) {
	  if(sort_column) free(sort_column);
	  sort_column = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "countryFilter")) {
	  if(country_filter) free(country_filter);
	  country_filter = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "hostFilter")) {
	  if(host_filter) free(host_filter);
	  host_filter = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "clientMode")) {
	  const char* value = lua_tostring(L, -1);
	  if (!strcmp(value, "local"))
	    client_mode = location_local_only;
	  else if (!strcmp(value, "remote"))
	    client_mode = location_remote_only;
	  else
	    client_mode = location_all;
	} else if(!strcmp(key, "serverMode")) {
	  const char* value = lua_tostring(L, -1);
	  if (!strcmp(value, "local"))
	    server_mode = location_local_only;
	  else if (!strcmp(value, "remote"))
	    server_mode = location_remote_only;
	  else
	    server_mode = location_all;
	} //else
	  //ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid string type (%s) for option %s", lua_tostring(L, -1), key);
	break;

      case LUA_TNUMBER:
	if(!strcmp(key, "maxHits"))
	  max_hits = lua_tointeger(L, -1);
	else if(!strcmp(key, "toSkip"))
	  to_skip = lua_tointeger(L, -1);
	else if(!strcmp(key, "l7protoFilter"))
	  l7proto_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "portFilter"))
	  port_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "LocalNetworkFilter"))
	  local_network_filter = lua_tointeger(L, -1);
	//else
	  //ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid int type (%d) for option %s", lua_tointeger(L, -1), key);
	break;

      case LUA_TBOOLEAN:
	if(!strcmp(key, "a2zSortOrder"))
	  a2z_sort_order = lua_toboolean(L, -1) ? true : false;
	else if(!strcmp(key, "detailedResults"))
	  detailed_results = lua_toboolean(L, -1) ? true : false;
	//else
	  //ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid bool type for option %s", key);
	break;

      default:
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error: type %d not handled", t);
	break;
      }
    }

    lua_pop(L, 1);
  }
}
