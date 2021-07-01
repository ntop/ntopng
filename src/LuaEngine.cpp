/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef _GETOPT_H
#define _GETOPT_H
#endif

#ifndef LIB_VERSION
#define LIB_VERSION "1.4.7"
#endif

struct keyval string_to_replace[MAX_NUM_HTTP_REPLACEMENTS] = { { NULL, NULL } }; /* TODO remove */

extern luaL_Reg *ntop_interface_reg;
extern luaL_Reg *ntop_reg;
extern luaL_Reg *ntop_network_reg;

/* ******************************* */

struct ntopngLuaContext* getUserdata(struct lua_State *vm) {
  if(vm) {
    struct ntopngLuaContext *userdata;

    lua_getglobal(vm, "userdata");
    userdata = (struct ntopngLuaContext*) lua_touserdata(vm, lua_gettop(vm));
    lua_pop(vm, 1); // undo the push done by lua_getglobal

    return(userdata);
  } else
    return(NULL);
}

/* ******************************* */

#ifdef DUMP_STACK
static void stackDump(lua_State *L) {
  int i;
  int top = lua_gettop(L);

  for(i = 1; i <= top; i++) {  /* repeat for each level */
    int t = lua_type(L, i);

    switch(t) {
    case LUA_TSTRING:  /* strings */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %s", i, lua_tostring(L, i));
      break;

    case LUA_TBOOLEAN:  /* booleans */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %s", i, lua_toboolean(L, i) ? "true" : "false");
      break;

    case LUA_TNUMBER:  /* numbers */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %g", i, lua_tonumber(L, i));
      break;

    default:  /* other values */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %s", i, lua_typename(L, t));
      break;
    }
  }
}
#endif

/* ******************************* */

LuaEngine::LuaEngine(lua_State *vm) {
  std::bad_alloc bax;
  void *ctx;

  loaded_script_path = NULL;

  L = luaL_newstate();

  if(!L) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create a new Lua state.");
    throw bax;
  }

  ctx = (void*)calloc(1, sizeof(struct ntopngLuaContext));

  if(!ctx) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to create a context for the new Lua state.");
    lua_close(L);
    throw bax;
  }

  lua_pushlightuserdata(L, ctx);
  lua_setglobal(L, "userdata");

  if(vm)
    setThreadedActivityData(vm);
}

/* ******************************* */

LuaEngine::~LuaEngine() {
  if(L) {
    struct ntopngLuaContext *ctx;

#ifdef DUMP_STACK
    stackDump(L);
#endif

    ctx = getLuaVMContext(L);

    if(ctx) {
#ifndef HAVE_NEDGE
      if(ctx->snmpBatch) delete ctx->snmpBatch;

      for(u_int8_t slot_id=0; slot_id<MAX_NUM_ASYNC_SNMP_ENGINES; slot_id++) {
	if(ctx->snmpAsyncEngine[slot_id] != NULL)
	  delete ctx->snmpAsyncEngine[slot_id];
      }
#endif

      if(ctx->pkt_capture.end_capture > 0) {
	ctx->pkt_capture.end_capture = 0; /* Force stop */
	pthread_join(ctx->pkt_capture.captureThreadLoop, NULL);
      }

      if((ctx->iface != NULL) && ctx->live_capture.pcaphdr_sent)
	ctx->iface->deregisterLiveCapture(ctx);

#ifdef __linux__
      /* Other platforms use the singleton inside the Ntop class */
      if(ctx->ping != NULL)
	delete ctx->ping;
#endif

      if(ctx->addr_tree != NULL)
        delete ctx->addr_tree;

      if(ctx->sqlite_hosts_filter)
	free(ctx->sqlite_hosts_filter);

      if(ctx->sqlite_flows_filter)
	free(ctx->sqlite_flows_filter);

      free(ctx);
    }

    lua_close(L);
  }

  if(loaded_script_path) free(loaded_script_path);
}

/* ****************************************** */

void LuaEngine::luaRegister(lua_State *L, const char *class_name, luaL_Reg *class_methods) {
  const luaL_Reg _meta[] = { { NULL, NULL } };
  int lib_id, meta_id;
  
  /* newclass = {} */
  lua_createtable(L, 0, 0);
  lib_id = lua_gettop(L);

  /* metatable = {} */
  luaL_newmetatable(L, class_name);
  meta_id = lua_gettop(L);
  luaL_setfuncs(L, _meta, 0);

  /* metatable.__index = class_methods */
  lua_newtable(L);
  luaL_setfuncs(L, class_methods, 0);
  lua_setfield(L, meta_id, "__index");

  /* class.__metatable = metatable */
  lua_setmetatable(L, lib_id);

  /* _G["Foo"] = newclass */
  lua_setglobal(L, class_name);
}

/* ****************************************** */

static int ntop_lua_http_print(lua_State* vm) {
  struct mg_connection *conn;
  char *printtype;
  int t;

  conn = getLuaVMUserdata(vm, conn);

  /* ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__); */

  /* Handle binary blob */
  if((lua_type(vm, 2) == LUA_TSTRING)
     && (printtype = (char*)lua_tostring(vm, 2)) != NULL)
    if(!strncmp(printtype, "blob", 4)) {
      char *str = NULL;

      if(ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) return(CONST_LUA_ERROR);
      if((str = (char*)lua_tostring(vm, 1)) != NULL) {
	int len = strlen(str);

	if(len <= 1)
	  mg_printf(conn, "%c", str[0]);
	else
	  return(CONST_LUA_PARAM_ERROR);
      }

      lua_pushnil(vm);
      return(CONST_LUA_OK);
    }

  switch(t = lua_type(vm, 1)) {
  case LUA_TNIL:
    mg_printf(conn, "%s", "nil");
    break;

  case LUA_TBOOLEAN:
  {
    int v = lua_toboolean(vm, 1);

    mg_printf(conn, "%s", v ? "true" : "false");
  }
  break;

  case LUA_TSTRING:
  {
    char *str = (char*)lua_tostring(vm, 1);

    if(str && (strlen(str) > 0))
      mg_printf(conn, "%s", str);
  }
  break;

  case LUA_TNUMBER:
  {
    char str[64];

    snprintf(str, sizeof(str), "%f", (float)lua_tonumber(vm, 1));
    mg_printf(conn, "%s", str);
  }
  break;

  case LUA_TTABLE:
    {
      lua_pushnil(vm);

      while(lua_next(vm, -2) != 0) {
	const char *key = lua_tostring(vm, -2);

	if(lua_isstring(vm, -1))
	  mg_printf(conn, "%s = %s", key, lua_tostring(vm, -1));
	else if(lua_isnumber(vm, -1))
	  mg_printf(conn, "%s = %d", key, (int)lua_tonumber(vm, -1));
	else if(lua_istable(vm, -1)) {
	  mg_printf(conn, "%s", key);
	  // PrintTable(vm);
	}
	lua_pop(vm, 1);
      }
    }
  break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(): Lua type %d is not handled",
				 __FUNCTION__, t);
    return(CONST_LUA_ERROR);
  }

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

int ntop_lua_cli_print(lua_State* vm) {
  int t;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s() called", __FUNCTION__);

  switch(t = lua_type(vm, 1)) {
  case LUA_TSTRING:
  {
    char *str = (char*)lua_tostring(vm, 1);

    if(str && (strlen(str) > 0))
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", str);
  }
  break;

  case LUA_TNUMBER:
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%f", (float)lua_tonumber(vm, 1));
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(): Lua type %d is not handled",
				 __FUNCTION__, t);
    return(CONST_LUA_ERROR);
  }

  lua_pushnil(vm);
  return(CONST_LUA_OK);
}

/* ****************************************** */

#if defined(NTOPNG_PRO) || defined(HAVE_NEDGE)

static int __ntop_lua_handlefile(lua_State* L, char *script_path, bool ex) {
  int rc;
  LuaHandler *lh = new LuaHandler(L, script_path);

  rc = lh->luaL_dofileM(ex);
  delete lh;
  return rc;
}

/* ****************************************** */

/* This function is called by Lua scripts when the call require(...) */
static int ntop_lua_require(lua_State* L) {
  char *script_name;

  if(lua_type(L, 1) != LUA_TSTRING ||
     (script_name = (char*)lua_tostring(L, 1)) == NULL)
    return 0;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%s(%s)", __FUNCTION__, script_name);

  lua_getglobal( L, "package" );
  lua_getfield( L, -1, "path" );

  string cur_path = lua_tostring( L, -1 ), parsed, script_path = "";
  stringstream input_stringstream(cur_path);
  while(getline(input_stringstream, parsed, ';')) {
    /* Example: package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path */
    unsigned found = parsed.find_last_of("?");
    if(found) {
      string s = parsed.substr(0, found) + script_name + ".lua";
      size_t first_dot = s.find("."), last_dot  = s.rfind(".");

      /*
	Lua transforms file names when directories are used.
	Example:  i18n/version.lua -> i18n.version.lua

	So we need to revert this logic back and the code
	below is doing exactly this
      */
      if((first_dot != string::npos)
	 && (last_dot != string::npos)
	 && (first_dot != last_dot))
	s.replace(first_dot, 1, "/");

      ntop->getTrace()->traceEvent(TRACE_DEBUG, "[%s] Searching %s", __FUNCTION__, s.c_str());

      if(Utils::file_exists(s.c_str())) {
	script_path = s;
	ntop->getTrace()->traceEvent(TRACE_DEBUG, "[%s] Found %s", __FUNCTION__, s.c_str());
	break;
      }
    }
  }

  if(script_path == "" ||
	  __ntop_lua_handlefile(L, (char *)script_path.c_str(),  false)) {
    if(lua_type(L, -1) == LUA_TSTRING) {
      const char *err = lua_tostring(L, -1);
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", script_path.c_str(), err ? err : "");
    }

    return 0;
  }

  return 1;
}

/* ****************************************** */

static int ntop_lua_xfile(lua_State* L, bool ex) {
  char *script_path;
  int ret;

  if(lua_type(L, 1) != LUA_TSTRING ||
     (script_path = (char*)lua_tostring(L, 1)) == NULL)
    return 0;

  ret = __ntop_lua_handlefile(L, script_path, ex);

  if(ret && (!lua_isnil(L, -1))) {
    const char *msg = lua_tostring(L, -1);
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure %s", msg);
  }

  return !ret;
}

/* ****************************************** */

static int ntop_lua_dofile(lua_State* L) {
  return ntop_lua_xfile(L, true);
}

/* ****************************************** */

static int ntop_lua_loadfile(lua_State* L) {
  return ntop_lua_xfile(L, false);
}

#endif

/* ****************************************** */

void LuaEngine::lua_register_classes(lua_State *L, bool http_mode) {
  if(!L) return;

  /* ntop add-ons */
  luaRegister(L, "interface", ntop_interface_reg);
  luaRegister(L, "ntop",      ntop_reg);
  luaRegister(L, "network",   ntop_network_reg);
  
  if(http_mode) {
    /* Overload the standard Lua print() with ntop_lua_http_print that dumps data on HTTP server */
    lua_register(L, "print", ntop_lua_http_print);
  } else
    lua_register(L, "print", ntop_lua_cli_print);

#if defined(NTOPNG_PRO) || defined(HAVE_NEDGE)
  if(ntop->getPro()->has_valid_license()) {
    lua_register(L, "ntopRequire", ntop_lua_require);
    /* Lua 5.2.x uses package.loaders   */
    luaL_dostring(L, "package.loaders = { ntopRequire }");
    /* Lua 5.3.x uses package.searchers */
    luaL_dostring(L, "package.searchers = { ntopRequire }");
    lua_register(L, "dofile", ntop_lua_dofile);
    lua_register(L, "loadfile", ntop_lua_loadfile);
  }
#endif
}

/* ****************************************** */

#if 0
/**
 * Iterator over key-value pairs where the value
 * maybe made available in increments and/or may
 * not be zero-terminated.  Used for processing
 * POST data.
 *
 * @param cls user-specified closure
 * @param kind type of the value
 * @param key 0-terminated key for the value
 * @param filename name of the uploaded file, NULL if not known
 * @param content_type mime-type of the data, NULL if not known
 * @param transfer_encoding encoding of the data, NULL if not known
 * @param data pointer to size bytes of data at the
 *              specified offset
 * @param off offset of data in the overall value
 * @param size number of bytes in data available
 * @return MHD_YES to continue iterating,
 *         MHD_NO to abort the iteration
 */
static int post_iterator(void *cls,
			 enum MHD_ValueKind kind,
			 const char *key,
			 const char *filename,
			 const char *content_type,
			 const char *transfer_encoding,
			 const char *data, uint64_t off, size_t size)
{
  struct Request *request = cls;
  char tmp[1024];
  u_int len = min(size, sizeof(tmp)-1);

  memcpy(tmp, &data[off], len);
  tmp[len] = '\0';

  fprintf(stdout, "[POST] [%s][%s]\n", key, tmp);
  return MHD_YES;
}
#endif

/* ****************************************** */

/* Loads a script into the engine from within ntopng (no HTTP GUI). */
int LuaEngine::load_script(char *script_path, NetworkInterface *iface) {
  int rc = 0;

  if(!L) return(-1);

  if(loaded_script_path)
    free(loaded_script_path);

  try {
    luaL_openlibs(L); /* Load base libraries */
    lua_register_classes(L, false); /* Load custom classes */

    if(iface) {
      /* Select the specified inteface */
      getLuaVMUservalue(L, iface) = iface;
    }

#ifdef NTOPNG_PRO
    if(ntop->getPro()->has_valid_license())
      rc = __ntop_lua_handlefile(L, script_path, false /* Do not execute */);
    else
#endif
      rc = luaL_loadfile(L, script_path);

    if(rc != 0) {
      const char *err = lua_tostring(L, -1);

      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", script_path, err ? err : "");
      rc = -1;
    }
  } catch(...) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s]", script_path);
    rc = -2;
  }

  loaded_script_path = strdup(script_path);

  return(rc);
}

/* ****************************************** */

/*
  Run a loaded Lua script (via LuaEngine::load_script) from within ntopng (no HTTP GUI).
  The script is invoked without any additional parameters. run_loaded_script can be called
  multiple times to run the same script again.
*/
int LuaEngine::run_loaded_script() {
  int top = lua_gettop(L);
  int rv = 0;

  if(!loaded_script_path)
    return(-1);

  /* Copy the lua_chunk to be able to possibly run it again next time */
  lua_pushvalue(L, -1);

  /* Perform the actual call */
  if(lua_pcall(L, 0, 0, 0) != 0) {
    if(lua_type(L, -1) == LUA_TSTRING) {
      const char *err = lua_tostring(L, -1);
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", loaded_script_path, err ? err : "");
    }

    rv = -2;
  }

  /* Reset the stack */
  lua_settop(L, top);

  return(rv);
}

/* ****************************************** */

/* http://www.geekhideout.com/downloads/urlcode.c */

#if 0
/* Converts an integer value to its hex character*/
static char to_hex(char code) {
  static char hex[] = "0123456789abcdef";
  return hex[code & 15];
}

/* ****************************************** */

/* Returns a url-encoded version of str */
/* IMPORTANT: be sure to free() the returned string after use */
static char* http_encode(char *str) {
  char *pstr = str, *buf = (char*)malloc(strlen(str) * 3 + 1), *pbuf = buf;
  while (*pstr) {
    if(isalnum(*pstr) || *pstr == '-' || *pstr == '_' || *pstr == '.' || *pstr == '~')
      *pbuf++ = *pstr;
    else if(*pstr == ' ')
      *pbuf++ = '+';
    else
      *pbuf++ = '%', *pbuf++ = to_hex(*pstr >> 4), *pbuf++ = to_hex(*pstr & 15);
    pstr++;
  }
  *pbuf = '\0';
  return buf;
}
#endif

/* ****************************************** */

#ifdef NOT_USED

void LuaEngine::purifyHTTPParameter(char *param) {
  char *ampersand;
  bool utf8_found = false;

  if((ampersand = strchr(param, '%')) != NULL) {
    /* We allow only a few chars, removing all the others */

    if((ampersand[1] != 0) && (ampersand[2] != 0)) {
      char c;
      char b = ampersand[3];

      ampersand[3] = '\0';
      c = (char)strtol(&ampersand[1], NULL, 16);
      ampersand[3] = b;

      switch(c) {
      case '/':
      case ':':
      case '(':
      case ')':
      case '{':
      case '}':
      case '[':
      case ']':
      case '?':
      case '!':
      case '$':
      case ',':
      case '^':
      case '*':
      case '_':
      case '&':
      case ' ':
      case '=':
      case '<':
      case '>':
      case '@':
      case '#':
	break;

      default:
        if(((u_char)c == 0xC3) && (ampersand[3] == '%')) {
          /* Latin-1 within UTF-8 */
          b = ampersand[6];
          ampersand[6] = '\0';
          c = (char)strtol(&ampersand[4], NULL, 16);
          ampersand[6] = b;

          /* Align to ASCII encoding */
          c |= 0x40;
          utf8_found = true;
        }

	if(!Utils::isPrintableChar(c)) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Discarded char '0x%02x' in URI [%s]", c, param);
	  ampersand[0] = '\0';
	  return;
	}
      }

      purifyHTTPParameter(utf8_found ? &ampersand[6] : &ampersand[3]);
    } else
      ampersand[0] = '\0';
  }
}
#endif

/* ****************************************** */

bool LuaEngine::switchInterface(struct lua_State *vm, const char *ifid,
				const char *user, const char *group,
				const char *session) {
  NetworkInterface *iface = NULL;
  char iface_key[64], ifname_key[64];
  char iface_id[16];

  iface = ntop->getNetworkInterface(ifid, vm);

  if(iface == NULL)
    return false;

  if(user != NULL) {
    if(!strlen(session) && strcmp(user, NTOP_NOLOGIN_USER))
      return false; 

    /* Non-admins cannot switch to the system interface */
    if(iface == ntop->getSystemInterface()
       && strcmp(user, NTOP_NOLOGIN_USER)
       && strncmp(group, CONST_USER_GROUP_ADMIN, strlen(CONST_USER_GROUP_ADMIN)))
      return false;

    snprintf(iface_key, sizeof(iface_key), NTOPNG_PREFS_PREFIX ".%s.iface", user);
    snprintf(ifname_key, sizeof(ifname_key), NTOPNG_PREFS_PREFIX ".%s.ifname", user);
  } else { // Login disabled
    snprintf(iface_key, sizeof(iface_key), NTOPNG_PREFS_PREFIX ".iface");
    snprintf(ifname_key, sizeof(ifname_key), NTOPNG_PREFS_PREFIX ".ifname");
  }

  snprintf(iface_id, sizeof(iface_id), "%d", iface->get_id());
  ntop->getRedis()->set(iface_key, iface_id, 0);
  ntop->getRedis()->set(ifname_key, iface->get_name(), 0);

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Switch interface requested via POST [Interface: %s][user: %s]",
			       iface->get_name(), user);

  getLuaVMUservalue(vm, iface) = iface;

  return true;
}

/* ****************************************** */

void LuaEngine::setInterface(const char * user, char * const ifname,
			     u_int16_t ifname_len, bool * const is_allowed) const {
  NetworkInterface *iface = NULL;
  char key[CONST_MAX_LEN_REDIS_KEY];
  u_int16_t observationPointId = 0;
  
  ifname[0] = '\0';

  if((user == NULL) || (user[0] == '\0'))
    user = NTOP_NOLOGIN_USER;

  if(is_allowed) *is_allowed = false;

  // check if the user is restricted to browse only a given interface
  if(snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, user)
     && ntop->getRedis()->get(key, ifname, ifname_len) == 0
     && ifname[0] != '\0') {
    /* If here is only one allowed interface for the user.
       The interface must exists otherwise we hould have prevented the login */
    if(is_allowed) *is_allowed = true;
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Allowed interface found. [Interface: %s][user: %s]",
				 ifname, user);
  } else if(snprintf(key, sizeof(key), NTOPNG_PREFS_PREFIX ".%s.ifname", user)
	    && (ntop->getRedis()->get(key, ifname, ifname_len) < 0
		|| (!ntop->isExistingInterface(ifname)))) {
    /* No allowed interface and no default (or not existing) set interface */
    snprintf(ifname, ifname_len, "%s",
	     ntop->getFirstInterface()->get_name());
    ntop->getRedis()->set(key, ifname, 3600 /* 1h */);
    ntop->getTrace()->traceEvent(TRACE_DEBUG,
				 "No interface interface found. Using default. [Interface: %s][user: %s]",
				 ifname, user);
  }

  if((iface = ntop->getNetworkInterface(ifname, NULL /* allowed user interface check already enforced */)) != NULL) {
    /* The specified interface still exists */
    lua_push_str_table_entry(L, "ifname", iface->get_name());
    snprintf(ifname, ifname_len, "%s", iface->get_name());

    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Interface found [Interface: %s][user: %s]", iface->get_name(), user);
  }

  if(iface && iface->haveObservationPointsDefined()) {
    char buf[16];
    
    snprintf(key, sizeof(key), NTOPNG_PREFS_PREFIX ".%s.observationPointId", user);
    
    if(ntop->getRedis()->get(key, buf, sizeof(buf)) != -1) {
      observationPointId = atoi(buf);

      if(!iface->hasObservationPointId(observationPointId))
	observationPointId = iface->getFirstObservationPointId(); /* Not existing */
    }
  }

  /* Set the observationPointId in the VM */
  getLuaVMUservalue(L, observationPointId) = observationPointId;

  // ntop->getTrace()->traceEvent(TRACE_WARNING, "observationPointId: %u", observationPointId);
  
  lua_push_uint32_table_entry(L, "observationPointId", observationPointId);
}

/* ****************************************** */

bool LuaEngine::setParamsTable(lua_State* vm,
			       const struct mg_request_info *request_info,
			       const char* table_name,
			       const char* query) const {
  char *where;
  char *tok;
  char *query_string = query ? strdup(query) : NULL;
  bool ret = false;

  lua_newtable(vm);

  if(query_string
     && strcmp(request_info->uri, CAPTIVE_PORTAL_INFO_URL) /* Ignore informative portal */
     ) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "[HTTP] %s", query_string);

    tok = strtok_r(query_string, "&", &where);

    while(tok != NULL) {
      char *_equal;

      if(strncmp(tok, "csrf", strlen("csrf")) != 0 /* Do not put csrf into the params table */
         && strncmp(tok, "switch_interface", strlen("switch_interface")) != 0
	 && (_equal = strchr(tok, '='))){
	char *decoded_buf;
        int len;

        _equal[0] = '\0';
        _equal = &_equal[1];
        len = strlen(_equal);

	// ntop->getTrace()->traceEvent(TRACE_WARNING, "%s = %s", tok, _equal);

        if((decoded_buf = (char*)malloc(len+1)) != NULL) {
	  bool rsp = false;

          Utils::urlDecode(_equal, decoded_buf, len + 1);

	  rsp = Utils::purifyHTTPparam(tok, true, false, false);
	  /* don't purify decoded_buf, it's purified in lua */

	  if(rsp) {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "[HTTP] Invalid '%s'", query);
	    ret = true;
	  }

	  /* Now make sure that decoded_buf is not a file path */
	  if(strchr(decoded_buf, CONST_PATH_SEP)
	     && Utils::file_exists(decoded_buf)
	     && !Utils::dir_exists(decoded_buf)
	     && strcmp(tok, "pid_name") /* This is the only exception */
	     )
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "Discarded '%s'='%s' as argument is a valid file path",
					 tok, decoded_buf);
	  else
	    lua_push_str_table_entry(vm, tok, decoded_buf);

          free(decoded_buf);
        } else
          ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      }

      tok = strtok_r(NULL, "&", &where);
    } /* while */
  }

  if(query_string) free(query_string);

  if(table_name)
    lua_setglobal(L, table_name);
  else
    lua_setglobal(L, (char*)"_GET"); /* Default */

  return(ret);
}

/* ****************************************** */

void build_redirect(const char *url, const char * query_string,
		    char *buf, size_t bufsize) {
  snprintf(buf, bufsize, "HTTP/1.1 302 Found\r\n"
	   "Server: ntopng %s (%s)\r\n"
	   "Location: %s%s%s\r\n\r\n"
	   "<html>\n"
	   "<head>\n"
	   "<title>Moved</title>\n"
	   "</head>\n"
	   "<body>\n"
	   "<h1>Moved</h1>\n"
	   "<p>This page has moved to <a href=\"%s\">%s</a>.</p>\n"
	   "</body>\n"
	   "</html>\n",
	   PACKAGE_VERSION, PACKAGE_MACHINE,
	   url,
	   query_string ? "?" : "",
	   query_string ? query_string : "",
	   url, url);
}

/* ****************************************** */

int LuaEngine::handle_script_request(struct mg_connection *conn,
				     const struct mg_request_info *request_info,
				     char *script_path, bool *attack_attempt,
				     const char *user,
				     const char *group,
				     const char *session_csrf,
				     bool localuser) {
  NetworkInterface *iface = NULL;
  char key[64], ifname[MAX_INTERFACE_NAME_LEN];
  bool is_interface_allowed;
  AddressTree ptree;
  int rc, post_data_len;
  const char * content_type;
  u_int8_t valid_csrf = 1;
  char *post_data = NULL;
  char csrf[64] = { '\0' };
  char switch_interface[2] = { '\0' };
  char addr_buf[64];
  char session_buf[64];
  char ifid_buf[32], session_key[32];
  const char* origin_header;
  bool send_redirect = false;
  IpAddress client_addr;

  *attack_attempt = false;

  if(!L) return(-1);

  luaL_openlibs(L); /* Load base libraries */
  lua_register_classes(L, true); /* Load custom classes */

  getLuaVMUservalue(L, conn) = conn;

  content_type = mg_get_header(conn, "Content-Type");
  Utils::make_session_key(session_key, sizeof(session_key));
  mg_get_cookie(conn, session_key, session_buf, sizeof(session_buf));

  /* Check for POST requests */
  if((strcmp(request_info->request_method, "POST") == 0) && (content_type != NULL)) {
    int content_len = mg_get_content_len(conn) + 1;

    if(content_len > HTTP_MAX_POST_DATA_LEN) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Too much data submitted with the form. [data len: %u][max len: %u]",
				   content_len, HTTP_MAX_POST_DATA_LEN);
      valid_csrf = 0;
    } else if((post_data = (char*)malloc(content_len * sizeof(char))) == NULL
              || (post_data_len = mg_read(conn, post_data, content_len)) == 0) {
      valid_csrf = 0;
    } else {
      post_data[post_data_len] = '\0';

      if(!strcmp(session_csrf, NTOP_CSRF_TOKEN_NO_SESSION)) {
	/* Authentication has taken place with direct username:password submission, without the use of a session,
	   hence, this request cannot be the result of a CSRF attack which, by construction, relies on a valid session. */
	valid_csrf = 1;
      } else {
	/* If here, authentication has taken place using a session, thus CSRF is mandatory in POST request and must
	   be checked for validity.
	   Note that session_csrf is trusted, that it it comes from ntopng, whereas csrf read from the POST is untrusted. */
	if(strstr(content_type, "application/json") == content_type) {
	  /*
	    post_data is JSON which is only allowed when using the REST API
	  */
	  if((strstr(request_info->uri, REST_API_PREFIX) ||
	      strstr(request_info->uri, REST_API_PRO_PREFIX)) &&
              strstr(request_info->uri, "/get/")) {
	    /*
	      REST API URI, GET, no CSRF required
	    */
	  } else {
	    /*
	      REST API URIs not containing /get/, e.g., /set/, /add/, /delete/, are assumed to
	      change the status of ntopng and thus CSRF checks MUST be enforced.
	      In this case, post_data is decoded as JSON to enforce the check.
	    */
	    json_object *o, *csrf_o;

	    if(!(o = json_tokener_parse(post_data))
	       || !json_object_object_get_ex(o, "csrf", &csrf_o)
	       || !strncpy(csrf, json_object_get_string(csrf_o), sizeof(csrf)-1)
	       || strncmp(session_csrf, csrf, NTOP_CSRF_TOKEN_LENGTH)) {
	      /*
		Either the CSRF token has not been submitted as part of the JSON, or
		the submitted token is invalid.
	      */
	      valid_csrf = 0;
            }
	  }
	} else {
	  /*
	    post_data is assumed to be application/x-www-form-urlencoded
	    CSRF token is searched and validated using mg_get_var
	   */
	  mg_get_var(post_data, post_data_len, "csrf", csrf, sizeof(csrf));

	  if(strncmp(session_csrf, csrf, NTOP_CSRF_TOKEN_LENGTH))
	    valid_csrf = 0;
	}
      }
    }

    /* Empty CSRF only allowed for nologin user. Such user has no associated
     * session so it has an empty CSRF. */
    if(valid_csrf) {
      if(strstr(content_type, "application/x-www-form-urlencoded") == content_type)
	*attack_attempt = setParamsTable(L, request_info, "_POST", post_data); /* CSRF is valid here, now fill the _POST table with POST parameters */
      else {
	/* application/json */

	lua_newtable(L);
	lua_push_str_table_entry(L, "payload", post_data); /* This payload is NOT parsed, checked or verified against attacks */
	lua_setglobal(L, "_POST");
      }

      /* Check for interface switch requests */
      mg_get_var(post_data, post_data_len, "switch_interface", switch_interface, sizeof(switch_interface));
      if(strlen(switch_interface) > 0 && request_info->query_string) {
        mg_get_var(request_info->query_string, strlen(request_info->query_string), "ifid", ifid_buf, sizeof(ifid_buf));
	
        if(strlen(ifid_buf) > 0) {
          switchInterface(L, ifid_buf, user, group, session_buf);

	  /* Sending a redirect is needed to prevent the current lua script
	   * from receiving the POST request, as it could exchange the request
	   * as a configuration save request. */
	  send_redirect = true;
	}
      }
    } else {
      *attack_attempt = setParamsTable(L, request_info, "_POST", NULL /* Empty */);
    }
    
    if(post_data)
      free(post_data);
  } else
    *attack_attempt = setParamsTable(L, request_info, "_POST", NULL /* Empty */);

  if(send_redirect) {
    char buf[512], uri[512];
    
    snprintf(uri, sizeof(uri), "%s%s", ntop->getPrefs()->get_http_prefix(), request_info->uri);
    build_redirect(uri, request_info->query_string, buf, sizeof(buf));

    /* Redirect the page and terminate this request */
    mg_printf(conn, "%s", buf);
    return(CONST_LUA_OK);
  }

  /* Put the GET params into the environment */
  if(request_info->query_string)
    *attack_attempt = setParamsTable(L, request_info, "_GET", request_info->query_string);
  else
    *attack_attempt = setParamsTable(L, request_info, "_GET", NULL /* Empty */);

  /* _SERVER */
  lua_newtable(L);
  lua_push_str_table_entry(L, "REQUEST_METHOD", (char*)request_info->request_method);
  lua_push_str_table_entry(L, "URI", (char*)request_info->uri ? (char*)request_info->uri : (char*)"");
  lua_push_str_table_entry(L, "REFERER", (char*)mg_get_header(conn, "Referer") ? (char*)mg_get_header(conn, "Referer") : (char*)"");

  const char *host = mg_get_header(conn, "Host");

  if(host) {
    lua_pushfstring(L, "%s://%s", (request_info->is_ssl) ? "https" : "http", host);
    lua_pushstring(L, "HTTP_HOST");
    lua_insert(L, -2);
    lua_settable(L, -3);
  }

  if(request_info->remote_user)  lua_push_str_table_entry(L, "REMOTE_USER", (char*)request_info->remote_user);
  if(request_info->query_string) lua_push_str_table_entry(L, "QUERY_STRING", (char*)request_info->query_string);

  /* Additional headers can be added eventually */
  origin_header = mg_get_header(conn, "Origin");
  if(origin_header) lua_push_str_table_entry(L, "Origin", origin_header);
  
  for(int i=0; ((request_info->http_headers[i].name != NULL)
		&& request_info->http_headers[i].name[0] != '\0'); i++)
    lua_push_str_table_entry(L,
			     request_info->http_headers[i].name,
			     (char*)request_info->http_headers[i].value);

  client_addr.set(mg_get_client_address(conn));
  lua_push_str_table_entry(L, "REMOTE_ADDR", (char*) client_addr.print(addr_buf, sizeof(addr_buf)));

  lua_setglobal(L, (char*)"_SERVER");

  /* NOTE: ntopng cannot rely on user provided cookies for security data (e.g. user or group),
   * use the session data instead! */
  char *_cookies;

  /* Cookies */
  lua_newtable(L);
  if((_cookies = (char*)mg_get_header(conn, "Cookie")) != NULL) {
    char *cookies = strdup(_cookies);
    char *tok, *where;

    // ntop->getTrace()->traceEvent(TRACE_WARNING, "=> '%s'", cookies);
    tok = strtok_r(cookies, "=", &where);
    while(tok != NULL) {
      char *val;

      while(tok[0] == ' ') tok++;

      if((val = strtok_r(NULL, ";", &where)) != NULL) {
	lua_push_str_table_entry(L, tok, val);
	// ntop->getTrace()->traceEvent(TRACE_WARNING, "'%s'='%s'", tok, val);
      } else
	break;

      tok = strtok_r(NULL, "=", &where);
    }

    free(cookies);
  }
  lua_setglobal(L, "_COOKIE"); /* Like in php */

  /*
    Read user capabilities
  */
  u_int64_t capabilities = 0;

  if(!strncmp(group, CONST_USER_GROUP_ADMIN, strlen(CONST_USER_GROUP_ADMIN)))
    /* Administrators have all the possible capabilitites */
    capabilities = (u_int64_t)-1;
  else {
    char val[32];

    /*
      Non-admins only have a subset of capabilities
    */
    snprintf(key, sizeof(key), CONST_STR_USER_CAPABILITIES, user);

    if((ntop->getRedis()->get(key, val, sizeof(val)) != -1)
       && (val[0] != '\0')) {
      capabilities = strtol(val, NULL, 10);
    }
  }

  /*
    Read user allowed networks
  */
  char allowed_nets[MAX_USER_NETS_VAL_LEN];

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, user);
  /* Set the default, if no allowed networks are found */
  if(ntop->getRedis()->get(key, allowed_nets, sizeof(allowed_nets)) == -1)
    snprintf(allowed_nets, sizeof(allowed_nets), CONST_DEFAULT_ALL_NETS);

  /*
    Give user the 'alerts' and 'historical_flows' capabilities if its allowed networks equal the 'all networks' constant
    NOTE: currently, this is only given for local-users. For non-local users (i.e., Radius, LDAP)
    this is left for future implementation.
  */
  if(localuser && !strncmp(allowed_nets, CONST_DEFAULT_ALL_NETS, sizeof(allowed_nets)))
    capabilities |= (1 << capability_alerts) | (1 << capability_historical_flows);

  /* Put the _SESSION params into the environment */
  lua_newtable(L);

  lua_push_str_table_entry(L, "session", session_buf);
  lua_push_str_table_entry(L, "user", (char*)user);
  lua_push_str_table_entry(L, "group", (char*)group);
  lua_push_bool_table_entry(L, "localuser", localuser);
  lua_push_uint64_table_entry(L, "capabilities", capabilities);  

  // now it's time to set the interface.
  setInterface(user, ifname, sizeof(ifname), &is_interface_allowed);

  if(!valid_csrf)
    lua_push_bool_table_entry(L, "INVALID_CSRF", true);

  lua_setglobal(L, "_SESSION"); /* Like in php */

  if(user[0] != '\0') {
    char val[16];
    getLuaVMUservalue(L, user) = (char*)user;

    /* Populate a patricia tree with the user allowed networks */
    ptree.addAddresses(allowed_nets);

    getLuaVMUservalue(L, allowedNets) = &ptree;
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "SET [p: %p][val: %s][user: %s]", &ptree, val, user);

    snprintf(key, sizeof(key), CONST_STR_USER_LANGUAGE, user);
    if((ntop->getRedis()->get(key, val, sizeof(val)) != -1)
       && (val[0] != '\0')) {
      lua_pushstring(L, val);
    } else
      lua_pushstring(L, NTOP_DEFAULT_USER_LANG);
    
    lua_setglobal(L, CONST_USER_LANGUAGE);
  }

  
  getLuaVMUservalue(L, group) = (char*)(group ? (group) : "");
  getLuaVMUservalue(L, localuser) = localuser;
  getLuaVMUservalue(L, csrf) = (char*)session_csrf;
  getLuaVMUservalue(L, capabilities) = capabilities;

  iface = ntop->getNetworkInterface(ifname); /* Can't be null */
  /* 'select' ther interface that has already been set into the _SESSION */
  getLuaVMUservalue(L,iface)  = iface;

  if(is_interface_allowed)
    getLuaVMUservalue(L, allowed_ifname) = iface->get_name();

#ifdef NTOPNG_PRO
  if(ntop->getPro()->has_valid_license())
    rc = __ntop_lua_handlefile(L, script_path, true);
  else
#endif
    rc = luaL_dofile(L, script_path);

  if(rc != 0) {
    const char *err = lua_tostring(L, -1);

    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s][%s]", script_path, err);
    return(redirect_to_error_page(conn, request_info, "internal_error", script_path, (char*)err));
  }

  return(CONST_LUA_OK);
}

/* ****************************************** */

void LuaEngine::setHost(Host* h) {
  struct ntopngLuaContext *c = getLuaVMContext(L);

  if(c) {
    c->host = h;

    if(h)
      c->iface = h->getInterface();
  }
}

/* ****************************************** */

void LuaEngine::setNetwork(NetworkStats* ns) {
  struct ntopngLuaContext *c = getLuaVMContext(L);

  if(c) {
    c->network = ns;
  }
}

/* ****************************************** */

void LuaEngine::setFlow(Flow* f) {
  struct ntopngLuaContext *c = getLuaVMContext(L);

  if(c) {
    c->flow = f;
    c->iface = f->getInterface();
  }
}

/* ****************************************** */

void LuaEngine::setThreadedActivityData(lua_State* from) {
  struct ntopngLuaContext *cur_ctx, *from_ctx;
  lua_State *cur_state = getState();

  if(from
     && (cur_ctx = getLuaVMContext(cur_state))
     && (from_ctx = getLuaVMContext(from))) {
    cur_ctx->deadline = from_ctx->deadline;
    cur_ctx->threaded_activity = from_ctx->threaded_activity;
    cur_ctx->threaded_activity_stats = from_ctx->threaded_activity_stats;
  }
}

/* ****************************************** */

void LuaEngine::setThreadedActivityData(const ThreadedActivity *ta, ThreadedActivityStats *tas, time_t deadline) {
  struct ntopngLuaContext *cur_ctx;
  lua_State *cur_state = getState();

  if((cur_ctx = getLuaVMContext(cur_state))) {
    cur_ctx->deadline = deadline;
    cur_ctx->threaded_activity = ta;
    cur_ctx->threaded_activity_stats = tas;
  }

}
