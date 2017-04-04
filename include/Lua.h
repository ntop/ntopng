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

#ifndef _LUA_H_
#define _LUA_H_

#include "ntop_includes.h"
/** @defgroup Lua Lua
 * Main ntopng lua group.
 */

enum lua_print_mode {
  LUA_PRINT_MODE_HTTP,
  LUA_PRINT_MODE_WEBSOCKET,
  LUA_PRINT_MODE_CONSOLE
};

/* ******************************* */

/** @class Lua
 *  @brief Main class of lua.
 *
 *  @ingroup Lua
 *
 */
class Lua {
 private:
  lua_State *L; /**< The Lua state.*/
  
  void lua_register_classes(lua_State *L, lua_print_mode print_mode);
  int prepare_script_request(struct mg_connection *conn,
             const struct mg_request_info *request_info,
             char *script_path,
             AddressTree *allowed_nets,
             lua_print_mode print_mode);

 public:
  /**
  * @brief A Constructor
  * @details Creating a new lua state.
  *
  * @return A new instance of lua.
  */
  Lua();
 
  /**
   * @brief A Destructor.
   *
   */
  ~Lua();

  /**
   * @brief Run a Lua script.
   * @details Run a script from within ntopng. No HTTP GUI.
   * 
   * @param script_path Full path of lua script.
   * @return 0 if the script has been executed successfully.
   */
  int run_script(char *script_path);

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
			    char *script_path);

  int handle_websocket_init(struct mg_connection *conn,
          const struct mg_request_info *request_info,
          const char *script_path, AddressTree *allowed_nets);
  void handle_websocket_ready(const char *script_path);
  int handle_websocket_message(const char * data, const char *script_path);

  void setParamsTable(lua_State* vm,
		      const char* table_name,
		      const char* query) const;
  static void purifyHTTPParameter(char *param);
  void setInterface(const char *user);
};

/**
 * @brief Push string value to table entry specify the key.
 * 
 * @param L The lua state.
 * @param key The key of hash table.
 * @param value The value of hash table.
 */
extern void lua_push_str_table_entry(lua_State *L, const char *key, char *value);
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
extern void lua_push_int_table_entry(lua_State *L, const char *key, u_int64_t value);


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



#endif /* _LUA_H_ */
