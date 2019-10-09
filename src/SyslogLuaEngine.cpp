/*
 *
 * (C) 2019 - ntop.org
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

/* ****************************************** */

SyslogLuaEngine::SyslogLuaEngine(NetworkInterface *iface) : LuaEngine() {
  initialized = false;

  snprintf(script_path, sizeof(script_path), "%s/%s",
	   ntop->getPrefs()->get_scripts_dir(), 
	   SYSLOG_SCRIPT_PATH);

  ntop->fixPath(script_path);

  if (run_script(script_path, iface, true /* Load only */) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failure loading %s", script_path);
    return;
  }

  initialized = true;

  /* Calling setup() */
  lua_getglobal(L, "setup");
  if (lua_isfunction(L, -1))
    pcall(0 /* no argument */, 0);
}

/* ****************************************** */

SyslogLuaEngine::~SyslogLuaEngine() {
  if (!initialized)
    return;

  /* Calling teardown() */
  lua_getglobal(L, "teardown");
  if (lua_isfunction(L, -1))
    pcall(0 /* no argument */, 0);
}

/* ****************************************** */

bool SyslogLuaEngine::pcall(int num_args, int num_results) {
  if (!initialized)
    return false;

  if (lua_pcall(L, num_args, num_results, 0)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Script failure [%s]", lua_tostring(L, -1));
    return false;
  }

  return true;
}

/* **************************************************** */

void SyslogLuaEngine::handleEvent(const char *application, const char *message) {
  lua_State *L = getState();
  lua_getglobal(L, SYSLOG_SCRIPT_CALLBACK_EVENT);
  lua_pushstring(L, application);
  lua_pushstring(L, message);
  pcall(2 /* num args */, 0);
}

