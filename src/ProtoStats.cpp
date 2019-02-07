/*
 *
 * (C) 2013-19 - ntop.org
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

/* *************************************** */

ProtoStats::ProtoStats() {
  reset();
}

/* *************************************** */

void ProtoStats::print(const char *prefix) {
  char bytes_buf[32], packets_buf[32];
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, 
			       "%s %s/%s Packets", prefix,
			       Utils::formatTraffic((float)numBytes, false, bytes_buf, sizeof(bytes_buf)),
			       Utils::formatPackets((float)numPkts, packets_buf, sizeof(packets_buf)));
}

/* *************************************** */

void ProtoStats::lua(lua_State *vm, const char *prefix) {
  char key_buf[32];

  snprintf(key_buf, sizeof(key_buf), "%sbytes", prefix);
  lua_push_uint64_table_entry(vm, key_buf, numBytes);

  snprintf(key_buf, sizeof(key_buf), "%spackets", prefix);
  lua_push_uint64_table_entry(vm, key_buf, numPkts);
}
