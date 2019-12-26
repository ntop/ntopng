/*
 *
 * (C) 2013-19 - ntop.org
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

#ifndef _LUA_H_
#define _LUA_H_

#include "ntop_includes.h"
/** @defgroup LuaEngine LuaEngine
 * Main ntopng lua group.
 */

/* ******************************* */

/** @class LuaEngine
 *  @brief Main class of lua.
 *
 *  @ingroup LuaEngine
 *
 */

class LuaEngine {
 protected:
  lua_State *L; /**< The LuaEngine state.*/
  
  void lua_register_classes(lua_State *L, bool http_mode);

 public:
  /**
  * @brief A Constructor
  * @details Creating a new lua state.
  *
  * @return A new instance of lua.
  */
  LuaEngine();
 
  /**
   * @brief A Destructor.
   *
   */
  virtual ~LuaEngine();

  /* Set Hosts and Networks into the Lua context */
  void setHost(Host* h);
  void setNetwork(NetworkStats* ns);
  void setFlow(Flow*f);

  inline Host* getHost()     { return(getLuaVMContext(L)->host); }
  inline NetworkInterface* getNetworkInterface() { return(getLuaVMContext(L)->iface); }
  NetworkStats* getNetwork() { return(getLuaVMContext(L)->network); }

  /**
   * @brief Run a Lua script.
   * @details Run a script from within ntopng. No HTTP GUI.
   * 
   * @param script_path Full path of lua script.
   * @param iface Select the specified interface (if not NULL)
   * @param load_only Load the Lua script but does not execute it
   *
   * @return 0 if the script has been executed successfully.
   */
  int run_script(char *script_path, NetworkInterface *iface, bool load_only = false, time_t deadline = 0, bool no_pcall = false);

  /**
   * @brief Handling of request info of script.
   * @details Read from the request the parameters and put the GET parameters and the _SESSION parameters into the environment. 
   * Once all parameters have been load we running the script.
   * 
   * @param conn This structure contains handle for the individual connection.
   * @param request_info This structure contains information about the HTTP request.
   * @param script_path Full path of lua script.
   * @return The result of the execution of the script.
   */
  int handle_script_request(struct mg_connection *conn,
			    const struct mg_request_info *request_info, 
			    char *script_path, bool *attack_attempt, const char *user, const char *group, bool localuser);

  bool setParamsTable(lua_State* vm,
		      const struct mg_request_info *request_info,
		      const char* table_name,
		      const char* query) const;

#ifdef NOT_USED /* Use Utils::purifyHTTPParam */
  static void purifyHTTPParameter(char *param);
#endif
  static void luaRegister(lua_State *L, const ntop_class_reg *reg);
  static void luaRegisterInternalRegs(lua_State *L);

  inline lua_State* getState() const { return(L); }
 
  bool switchInterface(struct lua_State *vm, const char *ifid, const char *user, const char *session);
  void setInterface(const char * user, char * const ifname, u_int16_t ifname_len, bool * const is_allowed) const;
};

/**
 * @brief Push string value to table entry specify the key.
 * 
 * @param L The lua state.
 * @param key The key of hash table.
 * @param value The value of hash table.
 */
extern void lua_push_str_table_entry(lua_State *L, const char * const key, const char * const value);

/**
 * @brief Push null value to table entry specify the key.
 * 
 * @param L The lua state.
 * @param key The key of hash table.
 */
extern void lua_push_nil_table_entry(lua_State *L, const char *key);

/**
 * @brief Push int value to table entry specify the key.
 * 
 * @param L The lua state.
 * @param key The key of hash table.
 * @param value The value of hash table.
 */
extern void lua_push_uint64_table_entry(lua_State *L, const char *key, u_int64_t value);

/**
 * @brief Push int32 value to table entry specify the key.
 * 
 * @param L The lua state.
 * @param key The key of hash table.
 * @param value The value of hash table.
 */
void lua_push_int32_table_entry(lua_State *L, const char *key, int32_t value);

/**
 * @brief Push bool value to table entry specify the key.
 * @details Using LUA_NUMBER (double: 64 bit) in place of LUA_INTEGER (ptrdiff_t: 32 or 64 bit
   * according to the platform) to handle big counters. (luaconf.h)
   * 
 * @param L The lua state.
 * @param key The key of hash table.
 * @param value The value of hash table.
 */
extern void lua_push_bool_table_entry(lua_State *L, const char *key, bool value);

/**
 * @brief Push float value to table entry specify the key.
 * 
 * @param L The lua state.
 * @param key The key of hash table.
 * @param value The value of hash table.
 */
extern void lua_push_float_table_entry(lua_State *L, const char *key, float value);

int ntop_lua_check(lua_State* vm, const char* func, int pos, int expected_type);

void get_host_vlan_info(char* lua_ip, char** host_ip, u_int16_t* vlan_id, char *buf, u_int buf_len);

#endif /* _LUA_H_ */
