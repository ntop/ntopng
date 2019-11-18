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

#ifndef _FLOW_ALERT_CHECK_LUA_ENGINE_H_
#define _FLOW_ALERT_CHECK_LUA_ENGINE_H_

class FlowAlertCheckLuaEngine : public AlertCheckLuaEngine {
 private:
  u_int32_t num_skipped_proto_detected;
  u_int32_t num_skipped_periodic_update;
  u_int32_t num_skipped_idle;

  u_int32_t num_pending_proto_detected;
  u_int32_t num_pending_periodic_update;

  virtual void lua_stats_skipped(lua_State *vm) const;

 public:
  FlowAlertCheckLuaEngine(NetworkInterface *iface);
  virtual ~FlowAlertCheckLuaEngine();

  void incSkippedPcalls(FlowLuaCall flow_lua_call);
  void incPendingPcalls(FlowLuaCall flow_lua_call);
};

#endif
