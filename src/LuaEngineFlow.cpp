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
  This file implements the flow.**** class
*/

/* ****************************************** */

static int ntop_flow_get_bytes(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f)
    lua_pushinteger(vm, f->get_bytes());
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_flow_get_cli2srv_bytes(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f)
    lua_pushinteger(vm, f->get_bytes_cli2srv());
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* ****************************************** */

static int ntop_flow_get_srv2cli_bytes(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f)
    lua_pushinteger(vm, f->get_bytes_srv2cli());
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_flow_get_client(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f && f->get_cli_ip_addr()) {
    char buf[64];
    
    lua_pushstring(vm, f->get_cli_ip_addr()->print(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_flow_get_client_port(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f) 
    lua_pushinteger(vm, f->get_cli_port());
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_flow_get_server(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f && f->get_srv_ip_addr()) {
    char buf[64];
    
    lua_pushstring(vm, f->get_srv_ip_addr()->print(buf, sizeof(buf)));
  } else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_flow_get_server_port(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f) 
    lua_pushinteger(vm, f->get_srv_port());
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_flow_get_protocol(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f) 
    lua_pushinteger(vm, f->get_protocol());
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_flow_get_vlan_id(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f) 
    lua_pushinteger(vm, f->get_vlan_id());
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_flow_get_l7_master_proto(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f) 
    lua_pushinteger(vm, f->get_detected_protocol().master_protocol);
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_flow_get_l7_proto(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f) 
    lua_pushinteger(vm, f->get_detected_protocol().app_protocol);
  else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static int ntop_trigger_flow_alert(lua_State* vm) {
  struct ntopngLuaContext *c = getLuaVMContext(vm);
  Flow *f = c ? c->flow : NULL;

  if(f) {
    u_int32_t value;
    char *msg;
     
    if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TNUMBER) != CONST_LUA_OK) return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    value = (u_int32_t) lua_tointeger(vm, 1);
    
    if(ntop_lua_check(vm, __FUNCTION__, 2, LUA_TSTRING) != CONST_LUA_OK) return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_ERROR));
    msg = (char*)lua_tostring(vm, 2);

    f->triggerCustomFlowAlert(value, msg);
  } else
    lua_pushnil(vm);
  
  return(ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK));
}

/* **************************************************************** */

static luaL_Reg _ntop_flow_reg[] = {
  { "cli",              ntop_flow_get_client           },
  { "cli_port",         ntop_flow_get_client_port      },
  { "srv",              ntop_flow_get_server           },
  { "srv_port",         ntop_flow_get_server_port      },
  { "protocol",         ntop_flow_get_protocol         },
  { "vlan_id",          ntop_flow_get_vlan_id          },

  { "cli2srv_bytes",    ntop_flow_get_cli2srv_bytes    },
  { "srv2cli_bytes",    ntop_flow_get_srv2cli_bytes    },
  { "bytes",            ntop_flow_get_bytes            },

  { "l7_master_proto",  ntop_flow_get_l7_master_proto  },
  { "l7_proto",         ntop_flow_get_l7_proto         },

  { "triggerAlert",     ntop_trigger_flow_alert        },
  
  { NULL,               NULL                           }
};

luaL_Reg *ntop_flow_reg = _ntop_flow_reg;
