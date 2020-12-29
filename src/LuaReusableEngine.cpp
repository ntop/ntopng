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

void LuaReusableEngine::setNextVmReload(time_t t) {
  /*
    Set the next_reload
   */
  next_reload = t;

  /*
    Also put the next_reload into the vm state,
    so that it can be read from Lua scripts as well.
   */
  lua_State *cur_state;
  ntopngLuaContext *cur_ctx;
  if(vm
     && (cur_state = vm->getState())
     && (cur_ctx = getLuaVMContext(cur_state)))
    cur_ctx->next_reload = next_reload;
}

/* ******************************* */

void LuaReusableEngine::reloadVm(time_t now) {
  if(vm) {
    delete vm;
    vm = NULL;
  }

  try {
    vm = new LuaEngine(NULL);
  } catch(std::bad_alloc& ba) {
    static bool oom_warning_sent = false;

    if(!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "[ThreadedActivity] Unable to start a Lua interpreter.");
      oom_warning_sent = true;
    }

    return;
  }

  if(vm->load_script(script_path, iface) == 0) {
    setNextVmReload(now + reload_interval);
  } else {
    /* Retry next time */
    delete vm;
    vm = NULL;
  }
}

/* ******************************* */

LuaEngine* LuaReusableEngine::getVm(time_t now) {
  if((vm == NULL) || (now >= next_reload))
    reloadVm(now);

  return(vm);
}
