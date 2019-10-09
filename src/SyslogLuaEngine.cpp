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

SyslogLuaEngine::SyslogLuaEngine(const char *script_name,  NetworkInterface *iface) : LuaEngine() {
  initialized = false;

  snprintf(script_path, sizeof(script_path), "%s/%s/%s.lua",
	   ntop->getPrefs()->get_scripts_dir(), SYSLOG_SCRIPTS_PATH, script_name);

  ntop->fixPath(script_path);

  if (run_script(script_path, iface, true /* Load only */) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Failure loading %s", script_path);
    return;
  }

  initialized = true;

  /* Calling setup() */
  lua_getglobal(L, "setup");      /* Called function   */
  lua_pushstring(L, script_name); /* push 1st argument */
  pcall(1 /* 1 argument */, 0);
}

/* ****************************************** */

SyslogLuaEngine::~SyslogLuaEngine() {
  if (!initialized)
    return;

  /* Calling teardown() */
  lua_getglobal(L, "teardown"); /* Called function */
  if (lua_isfunction(L, -1))
    pcall(0 /* 1 argument */, 0);
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
