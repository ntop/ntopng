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

Paginator::Paginator() {
  max_hits = to_skip = sort_column = a2z_sort_order = NULL;
  detailed_results = NULL;
  os_filter = vlan_filter = asn_filter = local_network_filter = NULL;
  country_filter = NULL;
  l7proto_filter = NULL, port_filter = NULL;
  const void *options[] = {
    "sortColumn",           &sort_column,
    "a2zSortOrder",         &a2z_sort_order,
    "maxHits",              &max_hits,
    "detailedResults",      &detailed_results,
    "toSkip",               &to_skip,
    "osFilter",             &os_filter,
    "countryFilter",        &country_filter,
    "vlanFilter",           &vlan_filter,
    "asnFilter",            &asn_filter,
    "LocalNetworkFilter",   &local_network_filter,
    "l7protoFilter",        &l7proto_filter,
    "portFilter",           &port_filter,
    NULL,                   NULL
  };
  memcpy(pagination_options, options, sizeof(options));
};

/* **************************************************** */

Paginator::~Paginator() {
  for (int i = 1; pagination_options[i] != NULL; i += 2) {
    if(*(char**)pagination_options[i]) free(*(char**)pagination_options[i]);
  }
}

/* **************************************************** */

void Paginator::readOptions(lua_State *L, int index) {
  /*
    See https://www.lua.org/ftp/refman-5.0.pdf for a detailed description
    of lua traversal of tables
  */
  lua_pushnil(L);

  while(lua_next(L, index) != 0) {
    if (lua_type(L, -1) == LUA_TTABLE) {
      /* removes 'value'; keeps 'key' for next iteration */
      readOptions(L, index);
    } else {
      for (int i = 0; pagination_options[i] != NULL; i += 2) {
	if (strcmp((char*)pagination_options[i], lua_tostring(L, -2)) == 0) {
	  if(lua_type(L, -1) == LUA_TSTRING) {
	    *((char**)pagination_options[i+1]) = strdup(lua_tostring(L, -1));
	    ntop->getTrace()->traceEvent(TRACE_DEBUG,
					 "string %s = %s",
					 lua_tostring(L, -2), lua_tostring(L, -1));
	    break;
	  } else if(lua_type(L, -1) == LUA_TNUMBER) {
	    char opt[32];
	    snprintf(opt, sizeof(opt), "%ld", lua_tointeger(L,-1));
	    *((char**)pagination_options[i+1]) = strdup(opt);
	    ntop->getTrace()->traceEvent(TRACE_DEBUG,
					 "number %s = %li",
					 lua_tostring(L, -2),
					 lua_tointeger(L, -1));
	    break;
	  } else if(lua_type(L, -1) == LUA_TBOOLEAN) {
	    *((char**)pagination_options[i+1]) = strdup(lua_toboolean(L, -1) ? "true" : "false");
	    ntop->getTrace()->traceEvent(TRACE_DEBUG,
					 "boolean %s = %s",
					 lua_tostring(L, -2),
					 lua_toboolean(L, -1) ? "true" : "false");
	    break;
	  }
	}
      }
    }

    lua_pop(L, 1);
  }
};
