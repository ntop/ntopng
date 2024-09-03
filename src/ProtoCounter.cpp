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

/* *************************************************/

ProtoCounter::ProtoCounter(u_int16_t _proto_id, bool enable_throughput_stats,
                           bool enable_behavior_stats) {
  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  proto_id = _proto_id;
  duration = last_epoch_update = total_flows = 0;

  if (enable_throughput_stats)
    bytes_thpt = new (std::nothrow) ThroughputStats();
  else
    bytes_thpt = NULL;
/*
#ifdef NTOPNG_PRO
  if (enable_behavior_stats)
    behavior_bytes_traffic = new (std::nothrow) BehaviorAnalysis();
  else
    behavior_bytes_traffic = NULL;
#endif
*/}

/* *************************************************/

ProtoCounter::~ProtoCounter() {
  /*
#ifdef NTOPNG_PRO
  if (behavior_bytes_traffic) delete behavior_bytes_traffic;
#endif
*/
  if (bytes_thpt) delete bytes_thpt;
}

/* *************************************************/

void ProtoCounter::sum(ProtoCounter *p) {
  packets.incStats(p->packets.getSent(), p->packets.getRcvd());
  bytes.incStats(p->bytes.getSent(), p->bytes.getRcvd());
  duration += p->duration;
  total_flows += p->total_flows;

  if(bytes_thpt && p->bytes_thpt)
    bytes_thpt->set(p->bytes_thpt);
}

/* *************************************************/

void ProtoCounter::print(u_int16_t proto_id, NetworkInterface *iface) {
  if (bytes.getTotal())
    printf("[%s] [pkts: %llu/%llu][bytes: %llu/%llu][duration: %u sec]\n",
           iface->get_ndpi_proto_name(proto_id),
           (long long unsigned)packets.getSent(),
           (long long unsigned)packets.getRcvd(),
           (long long unsigned)bytes.getSent(),
           (long long unsigned)bytes.getRcvd(), duration);
}

/* *************************************************/

void ProtoCounter::lua(lua_State *vm, NetworkInterface *iface, bool tsLua,
                       bool diff) {
  char *name = iface->get_ndpi_proto_name(proto_id);

  if (name != NULL) {
    if (bytes.getTotal() ||
        iface->hasSeenEBPFEvents() /* eBPF flows can have 0 traffic */) {
      if (!tsLua) {
        lua_newtable(vm);

        lua_push_str_table_entry(vm, "breed",
                                 iface->get_ndpi_proto_breed_name(proto_id));
        lua_push_uint64_table_entry(vm, "packets.sent", packets.getSent());
        lua_push_uint64_table_entry(vm, "packets.rcvd", packets.getRcvd());
        lua_push_uint64_table_entry(vm, "bytes.sent", bytes.getSent());
        lua_push_uint64_table_entry(vm, "bytes.rcvd", bytes.getRcvd());
        lua_push_uint64_table_entry(vm, "duration", duration);
        lua_push_uint64_table_entry(vm, "num_flows", total_flows);

	/*
#ifdef NTOPNG_PRO
	  if (behavior_bytes_traffic)
          behavior_bytes_traffic->luaBehavior(
	  vm, "l7_traffic_behavior");
#endif
	*/
        if (bytes_thpt) {
          lua_newtable(vm);

          lua_push_float_table_entry(vm, "bps", bytes_thpt->getThpt());
          lua_push_uint64_table_entry(vm, "trend_bps", bytes_thpt->getTrend());

          lua_pushstring(vm, "throughput");
          lua_insert(vm, -2);
          lua_rawset(vm, -3);
        }

        lua_pushstring(vm, name);
        lua_insert(vm, -2);
        lua_rawset(vm, -3);
      } else {
        char buf[64];

        snprintf(buf, sizeof(buf), "%llu|%llu|%u",
                 (unsigned long long)bytes.getSent(),
                 (unsigned long long)bytes.getRcvd(), total_flows);

        lua_push_str_table_entry(vm, name, buf);
      }
    }
  }
}

/* *************************************************/

void ProtoCounter::set(ProtoCounter *p) {
  proto_id = p->proto_id;
/*
#ifdef NTOPNG_PRO
  if (behavior_bytes_traffic != NULL) {
    delete behavior_bytes_traffic;
    behavior_bytes_traffic = NULL;
  }

  if (p->behavior_bytes_traffic) {
    behavior_bytes_traffic = new (std::nothrow) BehaviorAnalysis();

    if (behavior_bytes_traffic != NULL)
      behavior_bytes_traffic->set(p->behavior_bytes_traffic);
  }
#endif
*/
  if (bytes_thpt != NULL) {
    delete bytes_thpt;
    bytes_thpt = NULL;
  }

  if (p->bytes_thpt != NULL) {
    bytes_thpt = new (std::nothrow) ThroughputStats();

    if (bytes_thpt != NULL) bytes_thpt->set(p->bytes_thpt);
  }

  packets = p->packets, bytes = p->bytes;
  duration = p->duration, total_flows = p->total_flows;
}

/* *************************************************/

void ProtoCounter::updateStats(const struct timeval *tv,
                               time_t nextMinPeriodicUpdate) {
  if (!bytes_thpt) bytes_thpt = new (std::nothrow) ThroughputStats();

  if (bytes_thpt)
    bytes_thpt->updateStats(tv, bytes.getSent() + bytes.getRcvd());

#ifdef NTOPNG_PRO
#if 0
  if (tv->tv_sec >= nextMinPeriodicUpdate) {
    if (!behavior_bytes_traffic)
      behavior_bytes_traffic = new (std::nothrow)
          BehaviorAnalysis(0.9 /* Alpha parameter */, 0.1 /* Beta parameter */,
                           0.05 /* Significance */, true /* Counter */);

    if (behavior_bytes_traffic)
      behavior_bytes_traffic->updateBehavior(xNULL, bytes.getSent() + bytes.getRcvd(), NULL, false);
  }
#endif
#endif
}

/* ************************************************ */

void ProtoCounter::incStats(u_int32_t when, u_int64_t sent_packets,
                            u_int64_t sent_bytes, u_int64_t rcvd_packets,
                            u_int64_t rcvd_bytes) {
  packets.incStats(sent_packets, rcvd_packets);
  bytes.incStats(sent_bytes, rcvd_bytes);

  if ((when != 0) && (when - last_epoch_update >=
                      ntop->getPrefs()->get_housekeeping_frequency())) {
    duration += ntop->getPrefs()->get_housekeeping_frequency(),
        last_epoch_update = when;
  }
}

/* ************************************************ */

void ProtoCounter::addProtoJson(json_object *my_object,
                                NetworkInterface *iface) {
  json_object *inner, *inner1;
  char *name = iface->get_ndpi_proto_name(proto_id);

  if (!name) return;

  inner = json_object_new_object();
  if (!inner) return;

  json_object_object_add(inner, "duration", json_object_new_int64(duration));

  inner1 = json_object_new_object();
  if (!inner1) {
    json_object_put(inner);
    return;
  }

  json_object_object_add(inner1, "sent",
                         json_object_new_int64(bytes.getSent()));
  json_object_object_add(inner1, "rcvd",
                         json_object_new_int64(bytes.getRcvd()));
  json_object_object_add(inner, "bytes", inner1);

  inner1 = json_object_new_object();
  if (!inner1) {
    json_object_put(inner);
    return;
  }

  json_object_object_add(inner1, "sent",
                         json_object_new_int64(packets.getSent()));
  json_object_object_add(inner1, "rcvd",
                         json_object_new_int64(packets.getRcvd()));
  json_object_object_add(inner, "packets", inner1);

  json_object_object_add(my_object, name, inner);
}

/* ************************************************ */

void ProtoCounter::resetStats() {
  /*
#ifdef NTOPNG_PRO
  if (behavior_bytes_traffic) behavior_bytes_traffic->resetStats();
#endif
*/
  if (bytes_thpt) bytes_thpt->resetStats();

  packets.resetStats(), bytes.resetStats();
  duration = last_epoch_update = total_flows;
}
