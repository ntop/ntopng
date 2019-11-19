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

FlowAlertCheckLuaEngine::FlowAlertCheckLuaEngine(NetworkInterface *iface) : AlertCheckLuaEngine(alert_entity_flow, minute_script /* doesn't matter */, iface) {
  num_skipped_idle = num_skipped_periodic_update = num_skipped_proto_detected = 0;
  num_pending_proto_detected = num_pending_periodic_update = 0;
}

/* ****************************************** */

FlowAlertCheckLuaEngine::~FlowAlertCheckLuaEngine() {
}

/* ****************************************** */

void FlowAlertCheckLuaEngine::incSkippedPcalls(FlowLuaCall flow_lua_call) {
  switch(flow_lua_call) {
  case flow_lua_call_protocol_detected:
    num_skipped_proto_detected++;
    break;
  case flow_lua_call_periodic_update:
    num_skipped_periodic_update++;
    break;
  case flow_lua_call_idle:
    num_skipped_idle++;
    break;
  default:
    break;
  }

  iface->incNumDroppedFlowScriptsCalls();
}

/* ****************************************** */

void FlowAlertCheckLuaEngine::incPendingPcalls(FlowLuaCall flow_lua_call) {
  switch(flow_lua_call) {
  case flow_lua_call_protocol_detected:
    num_pending_proto_detected++;
    break;
  case flow_lua_call_periodic_update:
    num_pending_periodic_update++;
    break;
  default:
    break;
  }
}

/* ****************************************** */

void FlowAlertCheckLuaEngine::lua_stats_skipped(lua_State *vm) const {
  lua_push_uint64_table_entry(vm, "num_skipped_idle", num_skipped_idle);
  lua_push_uint64_table_entry(vm, "num_skipped_periodic_update", num_skipped_periodic_update);
  lua_push_uint64_table_entry(vm, "num_skipped_proto_detected", num_skipped_proto_detected);

  lua_push_uint64_table_entry(vm, "num_pending_proto_detected", num_pending_proto_detected);
  lua_push_uint64_table_entry(vm, "num_pending_periodic_update", num_pending_periodic_update);
}
