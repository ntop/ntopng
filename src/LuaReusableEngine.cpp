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

/* ******************************* */

LuaReusableEngine::LuaReusableEngine(const char *_script_path, NetworkInterface *_iface, int _reload_interval) {
  script_path = strdup(_script_path);
  reload_interval = _reload_interval;
  iface = _iface;
  vm = NULL;
  next_reload = 0;
}

/* ******************************* */

LuaReusableEngine::~LuaReusableEngine() {
  if(script_path) free(script_path);
  if(vm) delete vm;
}

/* ******************************* */

void LuaReusableEngine::reloadVm(time_t now) {
  if(vm) {
    delete vm;
    vm = NULL;
  }

  try {
    vm = new LuaEngine();
  } catch(std::bad_alloc& ba) {
    static bool oom_warning_sent = false;

    if(!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "[ThreadedActivity] Unable to start a Lua interpreter.");
      oom_warning_sent = true;
    }

    return;
  }

  vm->run_script(script_path, iface, true /* load only */, 0, true /* no_pcall */);
  next_reload = now + reload_interval;
}

/* ******************************* */

bool LuaReusableEngine::pcall(time_t deadline) {
  time_t now = time(NULL);
  int top;

  if((vm == NULL) || (now >= next_reload))
    reloadVm(now);

  if(vm == NULL)
    return(false);

  if(deadline) {
    lua_pushinteger(vm->getState(), deadline);
    lua_setglobal(vm->getState(), "deadline");
  }

  top = lua_gettop(vm->getState());

  /* Copy the lua_chunk to be able to run it again next time */
  lua_pushvalue(vm->getState(), -1);

  /* Perform the actual call */
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%p: pcall(%s, %s)", this, script_path, iface->get_name());
  lua_pcall(vm->getState(), 0, 0, 0);

  /* Reset the stack */
  lua_settop(vm->getState(), top);

  return(true);
}
