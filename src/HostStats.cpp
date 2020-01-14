/*
 *
 * (C) 2013-20 - ntop.org
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

HostStats::HostStats(Host *_host) : TimeseriesStats(_host) {
  iface = _host->getInterface();

  /* NOTE: deleted by ~GenericTrafficElement */
  ndpiStats = new nDPIStats();
  //printf("SIZE: %lu, %lu, %lu\n", sizeof(nDPIStats), MAX_NDPI_PROTOS, NDPI_PROTOCOL_NUM_CATEGORIES);

  last_epoch_update = 0;
  total_activity_time = 0;

#ifdef NTOPNG_PRO
  quota_enforcement_stats = quota_enforcement_stats_shadow = NULL;
#endif

  memset(&checkpoints, 0, sizeof(checkpoints));
}

/* *************************************** */

HostStats::~HostStats() {
#ifdef NTOPNG_PRO
  if(quota_enforcement_stats)        delete quota_enforcement_stats;
  if(quota_enforcement_stats_shadow) delete quota_enforcement_stats_shadow;
#endif
}

/* *************************************** */

/* NOTE: this function is used by Lua to create the minute-by-minute host top talkers,
   both for remote and local hosts. Top talkerts are created by doing a checkpoint
   of the current value. */
void HostStats::checkpoint(lua_State* vm) {
  u_int64_t new_val;

  lua_newtable(vm);

  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "sent", (new_val = getNumBytesSent()) - checkpoints.sent_bytes);
  checkpoints.sent_bytes = new_val;

  lua_push_uint64_table_entry(vm, "rcvd", (new_val = getNumBytesRcvd()) - checkpoints.rcvd_bytes);
  checkpoints.rcvd_bytes = new_val;

  lua_pushstring(vm, "delta");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

/* NOTE: check out LocalHostStats for deserialization */
void HostStats::getJSONObject(json_object *my_object, DetailsLevel details_level) {
  if(details_level >= details_high) {
    json_object_object_add(my_object, "flows.as_client", json_object_new_int(getTotalNumFlowsAsClient()));
    json_object_object_add(my_object, "flows.as_server", json_object_new_int(getTotalNumFlowsAsServer()));
    json_object_object_add(my_object, "misbehaving_flows.as_client", json_object_new_int(getTotalMisbehavingNumFlowsAsClient()));
    json_object_object_add(my_object, "misbehaving_flows.as_server", json_object_new_int(getTotalMisbehavingNumFlowsAsServer()));
    json_object_object_add(my_object, "unreachable_flows.as_client", json_object_new_int(unreachable_flows_as_client));
    json_object_object_add(my_object, "unreachable_flows.as_server", json_object_new_int(unreachable_flows_as_server));
    json_object_object_add(my_object, "host_unreachable_flows.as_client", json_object_new_int(host_unreachable_flows_as_client));
    json_object_object_add(my_object, "host_unreachable_flows.as_server", json_object_new_int(host_unreachable_flows_as_server));

    json_object_object_add(my_object, "total_activity_time", json_object_new_int(total_activity_time));
    GenericTrafficElement::getJSONObject(my_object, iface);

    /* TCP stats */
    if(tcp_packet_stats_sent.seqIssues())
      json_object_object_add(my_object, "tcpPacketStats.sent", tcp_packet_stats_sent.getJSONObject());
    if(tcp_packet_stats_rcvd.seqIssues())
      json_object_object_add(my_object, "tcpPacketStats.recv", tcp_packet_stats_rcvd.getJSONObject());
  }
}

/* *************************************** */

void HostStats::lua(lua_State* vm, bool mask_host, DetailsLevel details_level, bool tsLua) {
  if(details_level >= details_high)
    lua_push_uint64_table_entry(vm, "bytes.ndpi.unknown", getnDPIStats() ? getnDPIStats()->getProtoBytes(NDPI_PROTOCOL_UNKNOWN) : 0);

  if(details_level >= details_max) {
#ifdef NTOPNG_PRO
    if(custom_app_stats) custom_app_stats->lua(vm);
#endif

    sent_stats.lua(vm, "pktStats.sent");
    recv_stats.lua(vm, "pktStats.recv");
  }

  lua_push_bool_table_entry(vm, "tcp.packets.seq_problems",
			    tcp_packet_stats_sent.seqIssues() || tcp_packet_stats_rcvd.seqIssues() ? true : false);
  tcp_packet_stats_sent.lua(vm, "tcpPacketStats.sent");
  tcp_packet_stats_rcvd.lua(vm, "tcpPacketStats.rcvd");

  if(details_level >= details_higher) {
    /* Bytes anomalies */
    l4stats.luaAnomalies(vm);
  
    lua_push_uint64_table_entry(vm, "total_activity_time", total_activity_time);
    lua_push_uint64_table_entry(vm, "flows.as_client", getTotalNumFlowsAsClient());
    lua_push_uint64_table_entry(vm, "flows.as_server", getTotalNumFlowsAsServer());
  }

  if(details_level >= details_high) {
    ((GenericTrafficElement*)this)->lua(vm, details_level >= details_higher);
    ((TimeseriesStats*)this)->luaStats(vm, iface, details_level >= details_higher, details_level >= details_max, tsLua);
  }
}

/* *************************************** */

void HostStats::incStats(time_t when, u_int8_t l4_proto,
			 u_int ndpi_proto, ndpi_protocol_category_t ndpi_category,
			 custom_app_t custom_app,
			 u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
			 u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes,
			 bool peer_is_unicast) {
  sent.incStats(when, sent_packets, sent_bytes),
    rcvd.incStats(when, rcvd_packets, rcvd_bytes);
  
  if(ndpiStats) {
    ndpiStats->incStats(when, ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes),
      ndpiStats->incCategoryStats(when, ndpi_category, sent_bytes, rcvd_bytes);
  }

#ifdef NTOPNG_PRO
  if(custom_app.pen
     && (custom_app_stats || (custom_app_stats = new(std::nothrow) CustomAppStats(iface)))) {
    custom_app_stats->incStats(custom_app.remapped_app_id, sent_bytes + rcvd_bytes); 
  }
#endif

  if(when && when - last_epoch_update >= ntop->getPrefs()->get_housekeeping_frequency())
    total_activity_time += ntop->getPrefs()->get_housekeeping_frequency(), last_epoch_update = when;

  /* Packet stats sent_stats and rcvd_stats are incremented in Flow::incStats */
  l4stats.incStats(when, l4_proto, rcvd_packets, rcvd_bytes, sent_packets, sent_bytes);
}

#ifdef NTOPNG_PRO

/* *************************************** */

void HostStats::allocateQuotaEnforcementStats() {
      if(!quota_enforcement_stats) {
        quota_enforcement_stats = new HostPoolStats(iface);

#ifdef HOST_POOLS_DEBUG
        char buf[128];
        ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "Allocating quota stats for %s [quota_enforcement_stats: %p] [host pool: %i]",
				     ip.print(buf, sizeof(buf)), (void*)quota_enforcement_stats, host_pool_id);
#endif
      }
}

/* *************************************** */

void HostStats::deleteQuotaEnforcementStats() {
    if(quota_enforcement_stats_shadow) {
      delete quota_enforcement_stats_shadow;
      quota_enforcement_stats_shadow = NULL;

#ifdef HOST_POOLS_DEBUG
      char buf[128];
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
           "Freeing shadow pointer of longer quota stats for %s [host pool: %i]",
           ip.print(buf, sizeof(buf)), host_pool_id);
#endif
    }

    if(quota_enforcement_stats) {
      quota_enforcement_stats_shadow = quota_enforcement_stats;
      quota_enforcement_stats = NULL;

#ifdef HOST_POOLS_DEBUG
      char buf[128];
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
           "Moving quota stats to the shadow pointer for %s [host pool: %i]",
           ip.print(buf, sizeof(buf)), host_pool_id);
#endif
    }
}

#endif
