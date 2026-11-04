/*
 *
 * (C) 2013-24 - ntop.org
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

#ifndef _CUSTOM_FLOW_LUA_SCRIPT_H_
#define _CUSTOM_FLOW_LUA_SCRIPT_H_

#include "ntop_includes.h"

/* Hooks of a custom flow script (bitmap) */
#define CUSTOM_FLOW_SCRIPT_HOOK_DETECTED 0x01
#define CUSTOM_FLOW_SCRIPT_HOOK_PERIODIC 0x02
#define CUSTOM_FLOW_SCRIPT_HOOK_END 0x04
#define CUSTOM_FLOW_SCRIPT_HOOK_ALL 0x07

/* Flow filter of a custom script: fields in AND, values of a field in OR,
   an empty field matches any flow */
class CustomFlowScriptFilter {
 private:
  AddressTree *cli_ip, *srv_ip, *ip; /* ip: client or server */
  std::set<u_int16_t> cli_port, srv_port, port; /* port: client or server */
  std::set<u_int8_t> l4_proto;
  std::set<u_int16_t> l7_proto; /* nDPI app or master protocol */
  bool empty;

  bool parseIPs(lua_State* L, const char* field, AddressTree** tree, std::string* err);
  bool parsePorts(lua_State* L, const char* field, std::set<u_int16_t>* ports, std::string* err);
  bool parseL4(lua_State* L, std::string* err);
  bool parseL7(lua_State* L, NetworkInterface* iface, std::string* err);

 public:
  CustomFlowScriptFilter();
  ~CustomFlowScriptFilter();

  /* Reads the filter table on top of the stack */
  bool parse(lua_State* L, NetworkInterface* iface, std::string* err);
  bool match(Flow* f);
  inline bool isEmpty() const { return (empty); }
};

/* ********************************************** */

/* A user script: its own VM, filter, hooks and the alert it triggers */
class CustomFlowScript {
 private:
  LuaEngine* lua;
  Mutex m;
  int check_ref;      /* Registry reference of the check function */
  std::string name, title;
  u_int8_t score, hooks;
  CustomFlowScriptFilter filter, exclude;
  bool error_reported;

  bool parseDefinition(NetworkInterface* iface);

 public:
  CustomFlowScript();
  ~CustomFlowScript();

  bool load(const char* path, NetworkInterface* iface);
  inline bool hasHook(u_int8_t hook) const { return ((hooks & hook) != 0); }
  inline const std::string& getName() const { return (name); }
  inline const std::string& getTitle() const { return (title); }
  inline u_int8_t getScore() const { return (score); }

  /* Runs the script on the flow if it matches the filters: true when the script triggered an alert */
  bool run(Flow* f);
};

/* ********************************************** */

/* The scripts of an interface (one VM per script) */
class CustomFlowScripts {
 private:
  std::vector<CustomFlowScript*> scripts;

 public:
  CustomFlowScripts(NetworkInterface* iface);
  ~CustomFlowScripts();

  inline const std::vector<CustomFlowScript*>& get() const { return (scripts); }
};

/* ********************************************** */

class CustomFlowLuaScript : public FlowCheck {
 private:
  void runScripts(Flow* f, u_int8_t hook);

 public:
  CustomFlowLuaScript();
  ~CustomFlowLuaScript();

  bool loadConfiguration(json_object* config);

  /* Flow callbacks */
  void protocolDetected(Flow* f);
  void periodicUpdate(Flow* f);
  void flowEnd(Flow* f);

  std::string getName() const { return (std::string("custom_lua_script")); }
};

#endif /* _CUSTOM_FLOW_LUA_SCRIPT_H_ */
