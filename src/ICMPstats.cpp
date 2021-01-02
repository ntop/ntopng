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

/* *************************************** */

ICMPstats::ICMPstats() {
  num_destination_unreachable.reset();
}

/* *************************************** */

ICMPstats::~ICMPstats() {
  std::map<u_int16_t, ICMPstats_t>::const_iterator it;

  for(it = stats.begin(); it != stats.end(); ++it) {
    if(it->second.last_host_sent_peer) free(it->second.last_host_sent_peer);
    if(it->second.last_host_rcvd_peer) free(it->second.last_host_rcvd_peer);
  }
  stats.clear();
}

/* *************************************** */

void ICMPstats::incStats(u_int32_t num_pkts, u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {
  std::map<u_int16_t, ICMPstats_t>::const_iterator it;
  ICMPstats_t s;
  u_int16_t key = get_typecode(icmp_type, icmp_code);
  char buf[64];

  if(!num_pkts)
    return;

  m.lock(__FILE__, __LINE__);

  if((it = stats.find(key)) != stats.end())
    s = it->second;
  else
    memset(&s, 0, sizeof(s));

  if(icmp_type == ICMP_DEST_UNREACH)
    num_destination_unreachable.inc(num_pkts);

  if(sent) {
    s.pkt_sent += num_pkts;

    if(peer) {
      if(s.last_host_sent_peer) free(s.last_host_sent_peer);
      s.last_host_sent_peer = strdup(peer->get_string_key(buf, sizeof(buf)));
    }
  } else {
    s.pkt_rcvd += num_pkts;

    if(peer) {
      if(s.last_host_rcvd_peer) free(s.last_host_rcvd_peer);
      s.last_host_rcvd_peer = strdup(peer->get_string_key(buf, sizeof(buf)));
    }
  }

  stats[key] = s;

  m.unlock(__FILE__, __LINE__);
};

/* *************************************** */

void ICMPstats::addToTable(const char *label, lua_State *vm, const ICMPstats_t *curr, bool verbose) {
  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "sent", curr->pkt_sent);
  if(verbose)
    lua_push_str_table_entry(vm, "last_host_sent_peer", curr->last_host_sent_peer);
  lua_push_uint64_table_entry(vm, "rcvd", curr->pkt_rcvd);
  if(verbose)
    lua_push_str_table_entry(vm, "last_host_rcvd_peer", curr->last_host_rcvd_peer);
  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ******************************************* */

void ICMPstats::updateStats(const struct timeval * const tv) {
  time_t when = tv->tv_sec;

  num_destination_unreachable.computeAnomalyIndex(when);

#if 0
  char buf[64];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "num_destination_unreachable: %s",
			       num_destination_unreachable.print(buf, sizeof(buf)));
#endif
 }

/* *************************************** */

void ICMPstats::lua(bool isV4, lua_State *vm, bool verbose) {
  std::map<u_int16_t, ICMPstats_t>::const_iterator it;

  m.lock(__FILE__, __LINE__);

  lua_newtable(vm);

  for(it = stats.begin(); it != stats.end(); ++it) {
    u_int8_t icmp_type, icmp_code;
    char label[32];

    to_typecode(it->first, &icmp_type, &icmp_code);
    snprintf(label, sizeof(label), "%u,%u", icmp_type, icmp_code);
    addToTable(label, vm, &it->second, verbose);
  }

  m.unlock(__FILE__, __LINE__);

  lua_pushstring(vm, isV4 ? "ICMPv4" : "ICMPv6");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

bool ICMPstats::hasAnomalies(time_t when) {
  return num_destination_unreachable.is_misbehaving(when);
}

/* *************************************** */

void ICMPstats::luaAnomalies(lua_State *vm, time_t when) {
  if(num_destination_unreachable.is_misbehaving(when))
    num_destination_unreachable.lua(vm, "icmp.num_destination_unreachable");
}

/* *************************************** */

void ICMPstats::sum(ICMPstats *e) {
  std::map<u_int16_t, ICMPstats_t>::const_iterator orig_it;

  for(orig_it = e->stats.begin(); orig_it != e->stats.end(); ++orig_it) {
    std::map<u_int16_t, ICMPstats_t>::const_iterator it;
    ICMPstats_t s;
    u_int16_t key = orig_it->first;
    const ICMPstats_t *curr = &orig_it->second;

    if((it = stats.find(key)) != stats.end())
      s = it->second;
    else
      memset(&s, 0, sizeof(s));

    s.pkt_sent = curr->pkt_sent, s.pkt_rcvd = curr->pkt_rcvd;

    if(curr->last_host_sent_peer && (! s.last_host_sent_peer))
      s.last_host_sent_peer = strdup(curr->last_host_sent_peer);

    if(curr->last_host_rcvd_peer && (! s.last_host_rcvd_peer))
      s.last_host_rcvd_peer = strdup(curr->last_host_rcvd_peer);

    stats[key] = s;
  }
}

/* *************************************** */

/* Get minimal stats required by the timeseries */
void ICMPstats::getTsStats(ts_icmp_stats *s) {
  u_int16_t echo_key = get_typecode(8, 0);
  u_int16_t echo_reply_key = get_typecode(0, 0);
  std::map<u_int16_t, ICMPstats_t>::const_iterator it;

  m.lock(__FILE__, __LINE__);

  if((it = stats.find(echo_key)) != stats.end()) {
    s->echo_packets_sent = it->second.pkt_sent;
    s->echo_packets_rcvd = it->second.pkt_rcvd;
  }

  if((it = stats.find(echo_reply_key)) != stats.end()) {
    s->echo_reply_packets_sent = it->second.pkt_sent;
    s->echo_reply_packets_rcvd = it->second.pkt_rcvd;
  }

  m.unlock(__FILE__, __LINE__);
}
