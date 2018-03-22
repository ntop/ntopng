/*
 *
 * (C) 2015-18 - ntop.org
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

Grouper::Grouper(sortField sf){
  sorter = sf;
  group_id_i = -1;
  group_id_set = false;
  group_id_s = NULL;
  group_label = NULL;
  table_index = 1;
  memset(&stats, 0, sizeof(stats));
}

/* *************************************** */

Grouper::~Grouper(){
  if(group_id_s)
    free(group_id_s);
  if(group_label)
    free(group_label);
}

/* *************************************** */

bool Grouper::inGroup(Host *h) {
  if(h == NULL || group_id_set == false)
    return false;

  switch(sorter){
  case column_asn:
    return h->get_asn() == group_id_i;

  case column_vlan:
    return h->get_vlan_id() == group_id_i;

  case column_local_network:
  case column_local_network_id:
    return h->get_local_network_id() == group_id_i;

  case column_pool_id:
    return h->get_host_pool() == group_id_i;

  case column_mac:
    return Utils::macaddr_int(h->get_mac()) == (u_int64_t)group_id_i;

  case column_country:
    {
      char buf[32], *c = h->get_country(buf, sizeof(buf));
      return (strcmp(group_id_s, c) == 0) ? true : false;
    }
    break;
    
  case column_os:
    return h->get_os() ?
      !strcmp(group_id_s, h->get_os()) :
      !strcmp(group_id_s, (char*)UNKNOWN_OS);

  default:
    return false;
  };
}

/* *************************************** */

int8_t Grouper::newGroup(Host *h) {
  char buf[32];

  if(h == NULL)
    return -1;

  if(group_id_s){
    free(group_id_s);
    group_id_s = NULL;
  }

  if(group_label){
    free(group_label);
    group_label = NULL;
  }

  memset(&stats, 0, sizeof(stats));

  switch(sorter) {
  case column_asn:
    group_id_i = h->get_asn();
    group_label = strdup(h->get_asname() != NULL ? h->get_asname() : (char*)UNKNOWN_ASN);
    break;

  case column_vlan:
    group_id_i = h->get_vlan_id();
    sprintf(buf, "%i", h->get_vlan_id());
    group_label = strdup(buf);
    break;

  case column_local_network:
  case column_local_network_id:
    group_id_i = h->get_local_network_id();
    if(group_id_i >= 0)
      group_label = strdup(ntop->getLocalNetworkName(h->get_local_network_id()));
    else
      group_label = strdup((char*)UNKNOWN_LOCAL_NETWORK);
    break;

  case column_pool_id:
    group_id_i = h->get_host_pool();
    sprintf(buf, "%i", h->get_host_pool());
    group_label = strdup(buf);
    break;

  case column_mac:
    group_id_i = Utils::macaddr_int(h->get_mac());
    group_label = strdup(Utils::formatMac(h->get_mac(), buf, sizeof(buf)));
    break;

  case column_country:
    {
      char buf[32], *c = h->get_country(buf, sizeof(buf));
      
      group_id_s  = strdup(c);
      group_label = strdup(group_id_s);
    }
    break;

  case column_os:
    group_id_s  = strdup(h->get_os() ? h->get_os() : (char*)UNKNOWN_OS);
    group_label = strdup(group_id_s);
    break;

  default:
    return -1;
  };

  group_id_set = true;
  return 0;
}

/* *************************************** */

int8_t Grouper::incStats(Host *h) {
  char buf[32], *c = h->get_country(buf, sizeof(buf));
  
  if(h == NULL || !inGroup(h))
    return -1;

  stats.num_hosts++,
    stats.bytes_sent += h->getNumBytesSent(),
    stats.bytes_rcvd += h->getNumBytesRcvd(),
    stats.num_flows += h->getNumActiveFlows(),
    stats.num_dropped_flows += h->getNumDroppedFlows(),
    stats.num_alerts += h->getNumAlerts(),
    stats.throughput_bps += h->getBytesThpt(),
    stats.throughput_pps += h->getPacketsThpt(),
    stats.throughput_trend_bps_diff += h->getThptTrendDiff();

  if(stats.first_seen == 0 || h->get_first_seen() < stats.first_seen)
    stats.first_seen = h->get_first_seen();
  if(h->get_last_seen() > stats.last_seen)
    stats.last_seen = h->get_last_seen();  
 
  if(c) strncpy(stats.country, c, sizeof(stats.country));

  return 0;
}

/* *************************************** */

void Grouper::lua(lua_State* vm) {
  lua_newtable(vm);

  lua_push_str_table_entry(vm,   "name", group_label);
  lua_push_int_table_entry(vm,   "bytes.sent", stats.bytes_sent);
  lua_push_int_table_entry(vm,   "bytes.rcvd", stats.bytes_rcvd);
  lua_push_int_table_entry(vm,   "seen.first", stats.first_seen);
  lua_push_int_table_entry(vm,   "seen.last", stats.last_seen);
  lua_push_int_table_entry(vm,   "num_hosts", stats.num_hosts);
  lua_push_int_table_entry(vm,   "num_flows", stats.num_flows);
  lua_push_int_table_entry(vm,   "num_dropped_flows", stats.num_dropped_flows);
  lua_push_int_table_entry(vm,   "num_alerts", stats.num_alerts);
  lua_push_float_table_entry(vm, "throughput_bps", max_val(stats.throughput_bps, 0));
  lua_push_float_table_entry(vm, "throughput_pps", max_val(stats.throughput_pps, 0));
  lua_push_float_table_entry(vm, "throughput_trend_bps_diff", max_val(stats.throughput_trend_bps_diff, 0));
  lua_push_str_table_entry(vm,   "country", strlen(stats.country) ? stats.country : (char*)"");

  if(sorter == column_mac) // special case for mac
    lua_push_str_table_entry(vm, "id", group_label);
  else if(!group_id_s){ // integer group id
    lua_push_int32_table_entry(vm, "id", group_id_i);
  } else { // string group id
    lua_push_str_table_entry(vm, "id", group_id_s);
  }

  lua_rawseti(vm, -2, table_index++); /* Use indexes to preserve order */
}
