/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef _LUA_ENGINE_FUNCTIONS_H_
#define _LUA_ENGINE_FUNCTIONS_H_

extern NetworkInterface* getCurrentInterface(lua_State* vm);
extern int ntop_get_alerts(lua_State* vm, AlertableEntity *entity);
extern int ntop_store_triggered_alert(lua_State* vm, AlertableEntity *alertable, int idx = 1);
extern int ntop_release_triggered_alert(lua_State* vm, AlertableEntity *alertable, int idx = 1);
extern AddressTree* get_allowed_nets(lua_State* vm); /* LuaEngineInterface.cpp */
extern int ntop_get_alerts(lua_State* vm, AlertableEntity *entity);
extern NetworkInterface* getCurrentInterface(lua_State* vm);
extern void build_redirect(const char *url, const char * query_string,
			   char *buf, size_t bufsize);
extern bool matches_allowed_ifname(char *allowed_ifname, char *iface);

extern struct keyval string_to_replace[];

#endif /* _LUA_ENGINE_FUNCTIONS_H_ */
