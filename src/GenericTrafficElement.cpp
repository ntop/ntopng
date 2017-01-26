/*
 *
 * (C) 2013-17 - ntop.org
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

GenericTrafficElement::GenericTrafficElement() {
  last_bytes = 0, last_bytes_thpt = bytes_thpt = 0, bytes_thpt_trend = trend_unknown;
  last_bytes_periodic = 0, bytes_thpt_diff = 0;
  last_packets = 0, last_pkts_thpt = pkts_thpt = 0, pkts_thpt_trend = trend_unknown;
  last_update_time.tv_sec = 0, last_update_time.tv_usec = 0, vlan_id = 0;
}

/* *************************************** */

void GenericTrafficElement::updateStats(struct timeval *tv) {
  if(last_update_time.tv_sec > 0) {
    float tdiff = (float)((tv->tv_sec-last_update_time.tv_sec)*1000+(tv->tv_usec-last_update_time.tv_usec)/1000);
    // Calculate bps throughput
    u_int64_t new_bytes = sent.getNumBytes()+rcvd.getNumBytes();
    float bytes_msec = ((float)((new_bytes-last_bytes)*1000))/tdiff;

    if(bytes_thpt < bytes_msec)      bytes_thpt_trend = trend_up;
    else if(bytes_thpt > bytes_msec) bytes_thpt_trend = trend_down;
    else                             bytes_thpt_trend = trend_stable;
    bytes_thpt_diff = bytes_msec - bytes_thpt;

    last_bytes_thpt = bytes_thpt, last_pkts_thpt = pkts_thpt;
    last_bytes_periodic += new_bytes - last_bytes;
    bytes_thpt = bytes_msec, last_bytes = new_bytes;
    // Calculate pps throughput
    u_int64_t new_packets = sent.getNumPkts()+ rcvd.getNumPkts();

    float pkts_msec = ((float)((new_packets-last_packets)*1000))/tdiff;

    if(pkts_thpt < pkts_msec)      pkts_thpt_trend = trend_up;
    else if(pkts_thpt > pkts_msec) pkts_thpt_trend = trend_down;
    else                           pkts_thpt_trend = trend_stable;

    pkts_thpt = pkts_msec, last_packets = new_packets;
  }

  memcpy(&last_update_time, tv, sizeof(struct timeval));
}

/* *************************************** */

void GenericTrafficElement::lua(lua_State* vm, bool host_details) {
  lua_push_int_table_entry(vm, "vlan", vlan_id);

  lua_push_float_table_entry(vm, "throughput_bps", bytes_thpt);
  lua_push_float_table_entry(vm, "last_throughput_bps", last_bytes_thpt);
  lua_push_int_table_entry(vm, "throughput_trend_bps", bytes_thpt_trend);
  lua_push_float_table_entry(vm, "throughput_trend_bps_diff", bytes_thpt_diff);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[bytes_thpt: %.2f] [bytes_thpt_trend: %d]", bytes_thpt,bytes_thpt_trend);
  lua_push_float_table_entry(vm, "throughput_pps", pkts_thpt);
  lua_push_float_table_entry(vm, "last_throughput_pps", last_pkts_thpt);
  lua_push_int_table_entry(vm, "throughput_trend_pps", pkts_thpt_trend);

  if(host_details) {
    lua_push_int_table_entry(vm, "bytes.sent", sent.getNumBytes());
    lua_push_int_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());
    lua_push_int_table_entry(vm, "packets.sent", sent.getNumPkts());
    lua_push_int_table_entry(vm, "packets.rcvd", rcvd.getNumPkts());
  }
}
