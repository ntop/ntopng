/*
 *
 * (C) 2013-24 - ntop.org
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
#include <string>

/* *************************************** */

nDPIStats::nDPIStats(bool _enable_throughput_stats,
                     bool _enable_behavior_stats) {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  
#ifdef NTOPNG_PRO
  nextMinPeriodicUpdate = 0;
#endif
  enable_throughput_stats = _enable_throughput_stats,
  enable_behavior_stats = _enable_behavior_stats;
}

/* *************************************** */

nDPIStats::nDPIStats(nDPIStats &stats) {
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator it;

  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  
#ifdef NTOPNG_PRO
  nextMinPeriodicUpdate = 0;
#endif

  for (it = stats.counters.begin(); it != stats.counters.end(); ++it) {
    ProtoCounter *c = it->second;

    if (c != NULL) {
      std::unordered_map<u_int16_t, ProtoCounter *>::iterator cbr =
          counters.find(it->first);

      if (cbr == counters.end()) {
        ProtoCounter *pc =
            new (std::nothrow) ProtoCounter(it->first,
#ifdef NTOPNG_PRO
                                            enable_throughput_stats,
#else
                                            false,
#endif
                                            enable_behavior_stats);

        if (pc != NULL) {
          pc->set(c);
          counters[it->first] = pc;
        }
      } else
        (it->second)->set(c);
    }
  }
}

/* *************************************** */

nDPIStats::~nDPIStats() {
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator it;

  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
  
  for (it = counters.begin(); it != counters.end(); ++it) {
    ProtoCounter *c = it->second;

    delete c;
  }
}

/* *************************************** */

void nDPIStats::sum(nDPIStats *stats) {
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator it;
  std::unordered_map<u_int16_t, CategoryCounter>::iterator it1;

  for (it = stats->counters.begin(); it != stats->counters.end(); ++it) {
    u_int16_t proto_id = it->first;
    ProtoCounter *c = it->second;
    std::unordered_map<u_int16_t, ProtoCounter *>::iterator it1 =
        counters.find(proto_id);

    if (it1 != counters.end())
      it1->second->sum(c);
    else {
      ProtoCounter *pc = new (std::nothrow) ProtoCounter(
          proto_id, enable_throughput_stats, enable_behavior_stats);

      if (pc != NULL) {
        pc->sum(c);
        counters[proto_id] = pc;
      }
    }
  }

  for (it1 = stats->cat_counters.begin(); it1 != stats->cat_counters.end();
       ++it1) {
    u_int16_t cat_id = it1->first;

    if (cat_counters.find(cat_id) == cat_counters.end())
      cat_counters[cat_id] = it1->second;
    else
      cat_counters[cat_id].sum(it1->second);
  }
}

/* *************************************** */

void nDPIStats::lua(NetworkInterface *iface, lua_State *vm,
                    bool with_categories, bool tsLua, bool diff) {
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator it;

  lua_newtable(vm);

  for (it = counters.begin(); it != counters.end(); ++it)
    it->second->lua(vm, iface, tsLua, diff);

  lua_pushstring(vm, "ndpi");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* *********************************************** */

  if (with_categories) {
    std::unordered_map<u_int16_t, CategoryCounter>::iterator it;

    lua_newtable(vm);

    for (it = cat_counters.begin(); it != cat_counters.end(); ++it)
      it->second.lua(iface, vm, it->first, tsLua);

    lua_pushstring(vm, "ndpi_categories");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void nDPIStats::updateStats(const struct timeval *tv) {
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator it;

  for (it = counters.begin(); it != counters.end(); ++it)
    it->second->updateStats(tv, nextMinPeriodicUpdate);

  nextMinPeriodicUpdate = tv->tv_sec + NDPI_TRAFFIC_BEHAVIOR_REFRESH;
}

/* *************************************** */

void nDPIStats::incStats(u_int32_t when, u_int16_t proto_id,
                         u_int64_t sent_packets, u_int64_t sent_bytes,
                         u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator cbr =
      counters.find(proto_id);
  ProtoCounter *pc;

  if (cbr != counters.end()) {
    pc = cbr->second;
  } else {
    pc = new (std::nothrow)ProtoCounter(proto_id, enable_throughput_stats, enable_behavior_stats);

    if (!pc) return;

    counters[proto_id] = pc;
  }

  pc->incStats(when, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
}

/* *************************************** */

void nDPIStats::incCategoryStats(u_int32_t when,
                                 ndpi_protocol_category_t category_id,
                                 u_int64_t sent_bytes, u_int64_t rcvd_bytes) {
  std::unordered_map<u_int16_t, CategoryCounter>::iterator it =
      cat_counters.find(category_id);
  ;

  if (it == cat_counters.end()) {
    CategoryCounter c;

    c.incStats(when, sent_bytes, rcvd_bytes);
    cat_counters[category_id] = c;
  } else {
    it->second.incStats(when, sent_bytes, rcvd_bytes);
  }
}

/* *************************************** */

void nDPIStats::incFlowsStats(u_int16_t proto_id) {
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator pc =
      counters.find(proto_id);

  if (pc != counters.end()) pc->second->inc_total_flows();
}

/* *************************************** */

char *nDPIStats::serialize(NetworkInterface *iface) {
  json_object *my_object = getJSONObject(iface);
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return (rsp);
}

/* *************************************** */

json_object *nDPIStats::getJSONObject(NetworkInterface *iface) {
  json_object *my_object;
  json_object *inner;
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator it;
  std::unordered_map<u_int16_t, CategoryCounter>::iterator it1;

  my_object = json_object_new_object();

  for (it = counters.begin(); it != counters.end(); ++it)
    it->second->addProtoJson(my_object, iface);

  /* ********************* */

  inner = json_object_new_object();

  for (it1 = cat_counters.begin(); it1 != cat_counters.end(); ++it1)
    it1->second.addProtoJson(inner, iface, (ndpi_protocol_category_t)it->first);

  json_object_object_add(my_object, "categories", inner);

  return (my_object);
}

/* *************************************** */

void nDPIStats::resetStats() {
  std::unordered_map<u_int16_t, ProtoCounter *>::iterator it;
  std::unordered_map<u_int16_t, CategoryCounter>::iterator it1;

  /* NOTE: do not deallocate counters since they can be in use by other threads
   */

  for (it = counters.begin(); it != counters.end(); ++it)
    it->second->resetStats();

  for (it1 = cat_counters.begin(); it1 != cat_counters.end(); ++it1)
    it1->second.resetStats();
}
