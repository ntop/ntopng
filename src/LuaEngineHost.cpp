/*
 *
 * (C) 2013-22 - ntop.org
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

/*
  This file implements the host.**** class
*/

/* **************************************************************** */

static int ntop_host_get_ip(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    char buf[64];

    lua_pushstring(vm, h->printMask(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_name(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    char buf[64];

    lua_pushstring(vm, h->get_visual_name(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_host_get_vlan_id(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h)
    lua_pushinteger(vm, h->get_vlan_id());
  else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_trigger_host_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Host *h = c ? c->host : NULL;

  if(h) {
    u_int32_t value;
    char *msg;

    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    value = (u_int32_t) lua_tointeger(vm, 1);

    if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    msg = (char*)lua_tostring(vm, 2);

    h->triggerCustomHostAlert(value, msg);
  } else
    lua_pushnil(vm);

  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static luaL_Reg _ntop_host_reg[] = {
  { "ip",         ntop_host_get_ip                     },
  { "name",       ntop_host_get_name                   },
  { "vlan",       ntop_host_get_vlan_id                },

  { "triggerAlert",     ntop_trigger_host_alert        },

  { NULL,               NULL                           }
};

luaL_Reg *ntop_host_reg = _ntop_host_reg;
