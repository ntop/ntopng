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

/* ******************************************* */

DB::DB(NetworkInterface *_iface) {
  running = false;
  iface = _iface;

  lastUpdateTime.tv_sec = 0, lastUpdateTime.tv_usec = 0;
  droppedFlows = queueDroppedFlows = exportedFlows = lastExportedFlows = 0;
  checkpointDroppedFlows = checkpointQueueDroppedFlows = checkpointExportedFlows = 0;
  exportRate = 0;
}

/* ******************************************* */

void DB::shutdown() {
  running = false;
}

/* ******************************************* */

void DB::lua(lua_State *vm, bool since_last_checkpoint) const {
  lua_push_uint64_table_entry(vm, "flow_export_count",
			   exportedFlows - (since_last_checkpoint ? checkpointExportedFlows : 0));
  lua_push_int32_table_entry(vm, "flow_export_drops",
			   getNumDroppedFlows() - (since_last_checkpoint ? (checkpointDroppedFlows + checkpointQueueDroppedFlows) : 0));
  lua_push_float_table_entry(vm, "flow_export_rate",
			   exportRate >= 0 ? exportRate : 0);
}

/* ******************************************* */

void DB::checkPointCounters(bool drops_only) {
  if(!drops_only)
    checkpointExportedFlows = exportedFlows;

  checkpointDroppedFlows = droppedFlows;
  checkpointQueueDroppedFlows = queueDroppedFlows;
};

/* ******************************************* */

void DB::updateStats(const struct timeval *tv) {
  if(tv == NULL) return;

  if(lastUpdateTime.tv_sec > 0) {
    float tdiffMsec = Utils::msTimevalDiff(tv, &lastUpdateTime);
    if(tdiffMsec >= 1000) { /* al least one second */
      u_int64_t diffFlows = exportedFlows - lastExportedFlows;
      lastExportedFlows = exportedFlows;

      exportRate = ((float)(diffFlows * 1000)) / tdiffMsec;
      if (exportRate < 0) exportRate = 0;
    }
  }

  memcpy(&lastUpdateTime, tv, sizeof(struct timeval));
}
