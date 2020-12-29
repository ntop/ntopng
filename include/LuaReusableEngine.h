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

#ifndef _LUA_REUSABLE_ENGINE_H_
#define _LUA_REUSABLE_ENGINE_H_

#include "ntop_includes.h"

class LuaReusableEngine {
 private:
  LuaEngine *vm;
  NetworkInterface *iface;
  char *script_path;
  int reload_interval;
  time_t next_reload;

  void reloadVm(time_t now);

 public:
  LuaReusableEngine(const char *_script_path, NetworkInterface *_iface, int _reload_interval);
  ~LuaReusableEngine();

  void setNextVmReload(time_t t);
  LuaEngine* getVm(time_t now);
};

#endif
