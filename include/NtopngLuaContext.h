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

#ifndef _NTOP_LUACONTEXT_H_
#define _NTOP_LUACONTEXT_H_

#include "ntop_includes.h"

class LuaEngine;
class ThreadedActivity;

class NtopngLuaContext {
public:
  char *allowed_ifname, *user, *group, *csrf;
  char *sqlite_hosts_filter, *sqlite_flows_filter;
  bool sqlite_filters_loaded;
  void *zmq_context, *zmq_subscriber;
  struct mg_connection *conn;
  AddressTree *allowedNets;
  NetworkInterface *iface;
  AddressTree *addr_tree;
  SNMP *snmpBatch, *snmpAsyncEngine[MAX_NUM_ASYNC_SNMP_ENGINES];
  Host *host;
  NetworkStats *network;
  Flow *flow;
  bool localuser;
  u_int16_t observationPointId, getbulkMaxNumRepetitions;
  LuaEngine *engine;
  
  /* Capabilities bitmap */
  u_int64_t capabilities;

  /* Packet capture */
  struct {
    bool captureInProgress;
    pthread_t captureThreadLoop;
    pcap_t *pd;
    pcap_dumper_t *dumper;
    u_int32_t end_capture;
  } pkt_capture;

  /* Live capture written to mongoose socket */
  struct {
    u_int32_t capture_until, capture_max_pkts, num_captured_packets;
    void *matching_host;
    bool bpfFilterSet;
    struct bpf_program fcode;

    /* Status */
    bool pcaphdr_sent;
    bool stopped;

    /* Partial sends */
    char send_buffer[1600];
    u_int data_not_yet_sent_len; /*
				   Amount of data that was
				   not sent mostly due to
				   socket buffering
				 */
  } live_capture;

  /*
    Indicate the time when the vm will be reloaded.
    This can be used so that Lua scripts running in an infinite-loop fashion,
    e.g., notifications.lua, can know when to break so they can be reloaded
    with new configurations. Useful when user scripts change or when recipient
    configurations change.
  */
  time_t next_reload;
  /* Periodic scripts (ThreadedActivity.cpp) */
  time_t deadline;
  const ThreadedActivity *threaded_activity;
  ThreadedActivityStats *threaded_activity_stats;

#if defined(NTOPNG_PRO)
  BinAnalysis *bin;
#endif
  
  NtopngLuaContext();
  ~NtopngLuaContext();
};

#endif /* _NTOP_LUACONTEXT_H_ */
