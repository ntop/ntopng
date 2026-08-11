/*
 *
 * (C) 2024-26 - ntop.org
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

/* ******************************************************* */

CHTimeseriesExporter::CHTimeseriesExporter(NetworkInterface* _if)
    : TimeseriesExporter(_if) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  ts_queue = new (std::nothrow) CHTSPointFifoQueue(ntop->getPrefs()->get_ch_ts_queue_size());
}

/* ******************************************************* */

CHTimeseriesExporter::~CHTimeseriesExporter() { delete ts_queue; }

/* ******************************************************* */

/* Read a Lua table into a vector<pair<std::string,V>>, converting each value with to_val */
template <typename V>
static void lua_table_to_vector(lua_State* vm, int index,
                                std::vector<std::pair<std::string, V>>& out,
                                V (*to_val)(lua_State*, int)) {
  lua_pushnil(vm);

  while (lua_next(vm, index) != 0) {
    const char* k = lua_tostring(vm, -2);

    if (k) out.push_back(std::make_pair(std::string(k), to_val(vm, -1)));

    lua_pop(vm, 1);
  }
}

static std::string lua_val_to_string(lua_State* vm, int index) {
  const char* s = lua_tostring(vm, index);
  return s ? std::string(s) : std::string();
}

static double lua_val_to_double(lua_State* vm, int index) {
  return (double)lua_tonumber(vm, index);
}

/* ******************************************************* */

/* Builds a CHTSPoint from Lua */
bool CHTimeseriesExporter::enqueueData(lua_State* vm, bool do_lock) {
  /* schema */
  if (ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING) != CONST_LUA_OK) {
    qdrops++;
    return false;
  }

  /* timestamp */
  if (ntop_lua_check(vm, __FUNCTION__, 2, LUA_TNUMBER) != CONST_LUA_OK) {
    qdrops++;
    return false;
  }

  /* tags */
  if (ntop_lua_check(vm, __FUNCTION__, 3, LUA_TTABLE) != CONST_LUA_OK) {
    qdrops++;
    return false;
  }

  /* metrics */
  if (ntop_lua_check(vm, __FUNCTION__, 4, LUA_TTABLE) != CONST_LUA_OK) {
    qdrops++;
    return false;
  }

  /* ifid: passed separately from tags (every schema requires an 'ifid' tag,
   * see ts_schema.lua) so it can be stored directly on CHTSPoint without
   * scanning the tags vector for it on every point. */
  if (ntop_lua_check(vm, __FUNCTION__, 5, LUA_TNUMBER) != CONST_LUA_OK) {
    qdrops++;
    return false;
  }

  CHTSPoint* point = new (std::nothrow) CHTSPoint();
  if (!point) {
    qdrops++;
    return false;
  }

  point->schema_name = lua_tostring(vm, 1);
  point->tstamp = (time_t)lua_tonumber(vm, 2);
  lua_table_to_vector<std::string>(vm, 3, point->tags, lua_val_to_string);
  lua_table_to_vector<double>(vm, 4, point->metrics, lua_val_to_double);
  point->ifid = (int16_t)lua_tonumber(vm, 5);

  if (!ts_queue->enqueue(point)) {
    delete point;
    return false;
  }

  return true;
}

/* ******************************************************* */

/* Not used: exportBatch() is used with ClickHouse timeseries */
char* CHTimeseriesExporter::dequeueData() { return NULL; }

/* ******************************************************* */

u_int64_t CHTimeseriesExporter::queueLength() const {
  return ts_queue->getLength();
}

/* ******************************************************* */

void CHTimeseriesExporter::flush() {}

/* ******************************************************* */

u_int32_t CHTimeseriesExporter::exportBatch(u_int32_t max_rows,
                                            std::string& err) {
  std::vector<CHTSPoint*> points;
  u_int32_t num_exported = 0;

  ts_queue->dequeueBatch(max_rows, points);

  if (points.empty()) return 0;

  if (iface->getDB() &&
      iface->getDB()->insertTimeseriesBatch("timeseries", points, err))
    num_exported = (u_int32_t)points.size();

  for (std::vector<CHTSPoint*>::iterator it = points.begin();
       it != points.end(); ++it)
    delete *it;

  return num_exported;
}
