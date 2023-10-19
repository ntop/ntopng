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

#ifndef _ALERT_CHECK_LUA_ENGINE_H_
#define _ALERT_CHECK_LUA_ENGINE_H_

class AlertCheckLuaEngine : public LuaEngine {
 private:
  ScriptPeriodicity p;
  char script_path[MAX_PATH];
  u_int num_calls;
  bool script_ok;
  ticks total_ticks, tps /* Ticks per second */;
  virtual void lua_stats_detail(lua_State *vm) const {};

 protected:
  NetworkInterface *iface;

 public:
  AlertCheckLuaEngine(AlertEntity alert_entity, ScriptPeriodicity p, NetworkInterface *_iface, lua_State *vm);
  virtual ~AlertCheckLuaEngine();

  bool pcall(int num_args, int num_results);

  ScriptPeriodicity getPeriodicity() const;
  const char * getGranularity() const;

  void lua_stats(const char * key, lua_State *vm);
  virtual void reset_stats();
};

#endif
