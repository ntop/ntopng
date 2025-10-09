/*
 *
 * (C) 2019-25 - ntop.org
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

FlowStats::FlowStats() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  resetStats();
}

/* *************************************** */

FlowStats::~FlowStats() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);
}

/* *************************************** */

void FlowStats::incStats(Bitmap128 alert_bitmap, u_int8_t l4_protocol,
                         AlertLevel alert_level, u_int8_t dscp_cli2srv,
                         u_int8_t dscp_srv2cli, Flow *flow) {
  u_int i;

  for (i = 0; i < alert_bitmap.numBits(); i++) {
    if (alert_bitmap.isSetBit(i)) counters[i]++;
  }

  protocols[l4_protocol]++;
  alert_levels[alert_level]++;
  if (dscp_cli2srv != dscp_srv2cli) {
    dscps[dscp_cli2srv]++;
    dscps[dscp_srv2cli]++;
  } else
    dscps[dscp_cli2srv]++;

  if (flow) {
    u_int16_t cli_pool, srv_pool;
    bool cli_pool_found = false, srv_pool_found = false;

    if (flow->get_cli_host()) {
      cli_pool = flow->get_cli_host()->get_host_pool();
      cli_pool_found = true;
    } else {
      /* Host null, let's try using IpAddress */
      IpAddress *ip = (IpAddress *)flow->get_cli_ip_addr();
      ndpi_patricia_node_t *cli_target_node = NULL;

      if (flow->get_cli_ip_addr())
        cli_pool_found = flow->getInterface()->getHostPools()->findIpPool(
            ip, flow->get_vlan_id(), &cli_pool, &cli_target_node);
    }

    if (flow->get_srv_host()) {
      srv_pool = flow->get_srv_host()->get_host_pool();
      srv_pool_found = true;
    } else {
      /* Host null, let's try using IpAddress */
      ndpi_patricia_node_t *srv_target_node = NULL;
      IpAddress *ip = (IpAddress *)flow->get_srv_ip_addr();

      if (flow->get_srv_ip_addr())
        srv_pool_found = flow->getInterface()->getHostPools()->findIpPool(
            ip, flow->get_vlan_id(), &srv_pool, &srv_target_node);
    }

    if (srv_pool_found && cli_pool_found) {
      /* Both pools found */
      if (cli_pool != srv_pool) {
        /* Different pool id, inc both */
        host_pools[cli_pool]++;
        host_pools[srv_pool]++;
      } else {
        /* Same pool id, inc only one time */
        host_pools[cli_pool]++;
      }
    } else if (srv_pool_found) {
      host_pools[srv_pool]++;
    } else if (cli_pool_found) {
      host_pools[cli_pool]++;
    }

    /* Now handle the ASN Transit list */
    u_int32_t srcPeerAS = flow->getSrcPeerAS(), dstPeerAS = flow->getDstPeerAS();
    if ((srcPeerAS || dstPeerAS) && (srcPeerAS != dstPeerAS)) {
        /* Transit */
        u_int32_t srcAS, dstAS;
        char *asname = NULL; /* Not interested */
        flow->getSrcAS(&srcAS, asname);
        flow->getDstAS(&dstAS, asname);
        if (srcAS != srcPeerAS) transit_asn_list.insert(srcPeerAS);
        if (dstAS != dstPeerAS) transit_asn_list.insert(dstPeerAS);
    }

    /* Track source and destination AS numbers */
    u_int32_t srcAS = 0, dstAS = 0;
    char src_as_name[32], dst_as_name[32];
    flow->getSrcAS(&srcAS, src_as_name);
    flow->getDstAS(&dstAS, dst_as_name);

    if (srcAS > 0) {
      std::map<u_int32_t, u_int32_t>::iterator it = src_asn.find(srcAS);
      if (it == src_asn.end())
        src_asn[srcAS] = 1;
      else
        it->second++;
    }

    if (dstAS > 0) {
      std::map<u_int32_t, u_int32_t>::iterator it = dst_asn.find(dstAS);
      if (it == dst_asn.end())
        dst_asn[dstAS] = 1;
      else
        it->second++;
    }
  }
}

/* *************************************** */

void FlowStats::lua(lua_State *vm) {
  lua_newtable(vm);

  for (int i = 0; i < BITMAP_NUM_BITS; i++) {
    if (unlikely(counters[i] > 0)) {
      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "count", counters[i]);

      lua_pushinteger(vm, i);
      lua_insert(vm, -2);
      lua_rawset(vm, -3);
    }
  }

  lua_pushstring(vm, "status");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  for (int i = 0; i < 0x100; i++) {
    if (unlikely(protocols[i] > 0)) {
      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "count", protocols[i]);

      lua_pushinteger(vm, i);
      lua_insert(vm, -2);
      lua_rawset(vm, -3);
    }
  }

  lua_pushstring(vm, "l4_protocols");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  for (int i = 0; i < 64; i++) {
    if (unlikely(dscps[i] > 0)) {
      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "count", dscps[i]);

      lua_pushinteger(vm, i);
      lua_insert(vm, -2);
      lua_rawset(vm, -3);
    }
  }

  lua_pushstring(vm, "dscps");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* Host pool */
  lua_newtable(vm);

  for (int i = 0; i < MAX_NUM_HOST_POOLS; i++) {
    if (unlikely(host_pools[i] > 0)) {
      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "count", host_pools[i]);

      lua_pushinteger(vm, i);
      lua_insert(vm, -2);
      lua_rawset(vm, -3);
    }
  }

  lua_pushstring(vm, "host_pool_id");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* Alert levels */
  u_int32_t count_notice_or_lower = 0, count_warning = 0, count_error = 0,
            count_critical = 0, count_emergency = 0;

  for (int i = 0; i < ALERT_LEVEL_MAX_LEVEL; i++) {
    AlertLevel alert_level = (AlertLevel)i;

    switch (Utils::mapAlertLevelToGroup(alert_level)) {
      case alert_level_group_notice_or_lower:
        count_notice_or_lower += alert_levels[alert_level];
        break;
      case alert_level_group_warning:
        count_warning += alert_levels[alert_level];
        break;
      case alert_level_group_error:
        count_error += alert_levels[alert_level];
        break;
      case alert_level_group_critical:
        count_critical += alert_levels[alert_level];
        break;
      case alert_level_group_emergency:
        count_error += alert_levels[alert_level];
        break;
      default:
        break;
    }
  }

  lua_newtable(vm);

  if (count_notice_or_lower > 0)
    lua_push_uint64_table_entry(vm, "notice_or_lower", count_notice_or_lower);
  if (count_warning > 0)
    lua_push_uint64_table_entry(vm, "warning", count_warning);
  if (count_error > 0) lua_push_uint64_table_entry(vm, "error", count_error);
  if (count_critical > 0)
    lua_push_uint64_table_entry(vm, "critical", count_critical);
  if (count_emergency > 0)
    lua_push_uint64_table_entry(vm, "emergency", count_emergency);

  lua_pushstring(vm, "alert_levels");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  std::map<std::string, u_int16_t>::iterator it2;
  for (it2 = talking_hosts.begin(); it2 != talking_hosts.end(); it2++)
    lua_push_uint32_table_entry(vm, it2->first.c_str(), it2->second);

  lua_pushstring(vm, "talking_with");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  for (it2 = wlan_ssid.begin(); it2 != wlan_ssid.end(); it2++)
    lua_push_uint32_table_entry(vm, it2->first.c_str(), it2->second);

  lua_pushstring(vm, "wlan_ssid");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  std::set<u_int32_t>::iterator it3;
  for (it3 = transit_asn_list.begin(); it3 != transit_asn_list.end(); it3++) {
    lua_push_uint32_table_entry(vm, std::to_string(*it3).c_str(), 1);
  }

  lua_pushstring(vm, "transit_asn");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  std::map<u_int32_t, u_int32_t>::iterator it_src_as;
  for (it_src_as = src_asn.begin(); it_src_as != src_asn.end(); it_src_as++) {
    lua_push_uint32_table_entry(vm, std::to_string(it_src_as->first).c_str(), it_src_as->second);
  }

  lua_pushstring(vm, "src_asn");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);

  std::map<u_int32_t, u_int32_t>::iterator it_dst_as;
  for (it_dst_as = dst_asn.begin(); it_dst_as != dst_asn.end(); it_dst_as++) {
    lua_push_uint32_table_entry(vm, std::to_string(it_dst_as->first).c_str(), it_dst_as->second);
  }

  lua_pushstring(vm, "dst_asn");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void FlowStats::updateTalkingHosts(Flow *f) {
  char buf[64];
  std::pair<std::map<std::string, u_int16_t>::iterator, bool> ret;
  ret = talking_hosts.insert(std::pair<std::string, u_int16_t>(
      f->get_cli_ip_addr()->print(buf, sizeof(buf)), 1));

  if (!ret.second) ret.first->second++;

  ret = talking_hosts.insert(std::pair<std::string, u_int16_t>(
      f->get_srv_ip_addr()->print(buf, sizeof(buf)), 1));

  if (!ret.second) ret.first->second++;
}

/* *************************************** */

void FlowStats::updateWLANSSID(Flow *f) {
  char *wlan_ssid_string = f->getWLANSSID();
  if (wlan_ssid_string) {
    std::pair<std::map<std::string, u_int16_t>::iterator, bool> ret;
    ret = wlan_ssid.insert(
        std::pair<std::string, u_int16_t>(wlan_ssid_string, 1));
    if (!ret.second) ret.first->second++;
  }
}

/* *************************************** */

void FlowStats::resetStats() {
  memset(counters, 0, sizeof(counters));
  memset(protocols, 0, sizeof(protocols));
  memset(alert_levels, 0, sizeof(alert_levels));
  memset(dscps, 0, sizeof(dscps));
  memset(host_pools, 0, sizeof(host_pools));
  talking_hosts.clear();
  wlan_ssid.clear();
  src_asn.clear();
  dst_asn.clear();
}

/* *************************************** */
