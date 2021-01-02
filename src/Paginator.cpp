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

/* **************************************************** */

Paginator::Paginator() {
  /* char* */
  sort_column = strdup("column_thpt");
  country_filter = NULL;
  host_filter = NULL;
  container_filter = NULL;
  pod_filter = NULL;
  traffic_profile_filter = NULL;
  username_filter = NULL;
  pidname_filter = NULL;

  /* bool */
  a2z_sort_order = true;
  detailed_results = false;

  /* int */
  max_hits = CONST_MAX_NUM_HITS;
  to_skip = 0;
  l7proto_filter = l7category_filter = -1;
  port_filter = 0;
  local_network_filter = 0;
  vlan_id_filter = 0;
  ip_version = 0;
  l4_protocol = 0;
  client_mode = location_all;
  server_mode = location_all;
  tcp_flow_state_filter = tcp_flow_state_filter_all;
  unicast_traffic = -1;
  unidirectional_traffic = -1;
  alerted_flows = -1;
  filtered_flows = -1;
  pool_filter = ((u_int16_t)-1);
  mac_filter = NULL;
  flow_status_filter = ((u_int16_t)-1);
  flow_status_severity_filter = alert_level_group_none;

  deviceIP = 0;
  inIndex = outIndex = (u_int16_t)-1;
  asn_filter = (u_int32_t)-1;

  icmp_type = u_int8_t(-1);
  icmp_code = u_int8_t(-1);

  details_level = details_normal;
  details_level_set = false;

  /*
    TODO MISSING

    osFilter
    vlanFilter
  */
};

/* **************************************************** */

Paginator::~Paginator() {
  if(sort_column)    free(sort_column);
  if(country_filter) free(country_filter);
  if(host_filter)    free(host_filter);
  if(container_filter) free(container_filter);
  if(pod_filter)     free(pod_filter);
  if(mac_filter)     free(mac_filter);
  if(traffic_profile_filter) free(traffic_profile_filter);
  if(username_filter) free(username_filter);
  if(pidname_filter) free(pidname_filter);
}

/* **************************************************** */

void Paginator::readOptions(lua_State *L, int index) {
  /*
    See https://www.lua.org/ftp/refman-5.0.pdf for a detailed description
    of lua traversal of tables
  */
  lua_pushnil(L);

  while(lua_next(L, index) != 0) {
      const char *key = lua_tostring(L, -2);
      int t = lua_type(L, -1);

      switch(t) {
      case LUA_TSTRING:
	if(!strcmp(key, "sortColumn")) {
	  if(sort_column) free(sort_column);
	  sort_column = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "deviceIpFilter")) {
	  deviceIP = ntohl(inet_addr(lua_tostring(L, -1)));
	} else if(!strcmp(key, "countryFilter")) {
	  if(country_filter) free(country_filter);
	  country_filter = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "hostFilter")) {
	  if(host_filter) free(host_filter);
	  host_filter = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "container")) {
	  if(container_filter) free(container_filter);
	  container_filter = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "pod")) {
	  if(pod_filter) free(pod_filter);
	  pod_filter = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "clientMode")) {
	  const char* value = lua_tostring(L, -1);
	  if (!strcmp(value, "local"))
	    client_mode = location_local_only;
	  else if (!strcmp(value, "remote"))
	    client_mode = location_remote_only;
	  else
	    client_mode = location_all;
	} else if(!strcmp(key, "serverMode")) {
	  const char* value = lua_tostring(L, -1);
	  if (!strcmp(value, "local"))
	    server_mode = location_local_only;
	  else if (!strcmp(value, "remote"))
	    server_mode = location_remote_only;
	  else
	    server_mode = location_all;
	} else if(!strcmp(key, "tcpFlowStateFilter")) {
	  const char* value = lua_tostring(L, -1);
	  if (!strcmp(value, "established"))
	    tcp_flow_state_filter = tcp_flow_state_established;
	  else if (!strcmp(value, "connecting"))
	    tcp_flow_state_filter = tcp_flow_state_connecting;
	  else if (!strcmp(value, "closed"))
	    tcp_flow_state_filter = tcp_flow_state_closed;
	  else if (!strcmp(value, "reset"))
	    tcp_flow_state_filter = tcp_flow_state_reset;
	  else
	    tcp_flow_state_filter = tcp_flow_state_filter_all;
	} else if(!strcmp(key, "detailsLevel")) {
	  const char* value = lua_tostring(L, -1);
	  details_level_set = Utils::str2DetailsLevel(value, &details_level);
	} else if(!strcmp(key, "macFilter")) {
	  const char* value = lua_tostring(L, -1);
	  if(mac_filter) free(mac_filter);
	  mac_filter = (u_int8_t *) malloc(6);
	  Utils::parseMac(mac_filter, value);
	} else if(!strcmp(key, "usernameFilter")) {
	  if(username_filter) free(username_filter);
	  username_filter = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "pidnameFilter")) {
	  if(pidname_filter) free(pidname_filter);
	  pidname_filter = strdup(lua_tostring(L, -1));
	} else if(!strcmp(key, "trafficProfileFilter")) {
	  if(traffic_profile_filter) free(traffic_profile_filter);
	  traffic_profile_filter = strdup(lua_tostring(L, -1));
	} //else
	  //ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid string type (%s) for option %s", lua_tostring(L, -1), key);
	break;

      case LUA_TNUMBER:
	if(!strcmp(key, "maxHits"))
	  max_hits = lua_tointeger(L, -1);
	else if(!strcmp(key, "toSkip"))
	  to_skip = lua_tointeger(L, -1);
	else if(!strcmp(key, "l7protoFilter"))
	  l7proto_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "l7categoryFilter"))
	  l7category_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "portFilter"))
	  port_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "LocalNetworkFilter"))
	  local_network_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "vlanIdFilter"))
	  vlan_id_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "inIndexFilter"))
	  inIndex = lua_tointeger(L, -1);
	else if(!strcmp(key, "outIndexFilter"))
	  outIndex = lua_tointeger(L, -1);
	else if(!strcmp(key, "ipVersion"))
	  ip_version = lua_tointeger(L, -1);
	else if(!strcmp(key, "L4Protocol"))
	  l4_protocol = lua_tointeger(L, -1);
	else if(!strcmp(key, "poolFilter"))
	  pool_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "asnFilter"))
	  asn_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "icmp_type"))
	  icmp_type = lua_tointeger(L, -1);
	else if(!strcmp(key, "icmp_code"))
	  icmp_code = lua_tointeger(L, -1);
	else if(!strcmp(key, "statusFilter"))
	  flow_status_filter = lua_tointeger(L, -1);
	else if(!strcmp(key, "statusSeverityFilter"))
	  flow_status_severity_filter = (AlertLevelGroup)lua_tointeger(L, -1);
	//else
	  //ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid int type (%d) for option %s", lua_tointeger(L, -1), key);
	break;

      case LUA_TBOOLEAN:
	if(!strcmp(key, "a2zSortOrder"))
	  a2z_sort_order = lua_toboolean(L, -1) ? true : false;
	else if(!strcmp(key, "detailedResults"))
	  detailed_results = lua_toboolean(L, -1) ? true : false;
	else if (!strcmp(key, "unicast"))
	  unicast_traffic = lua_toboolean(L, -1) ? 1 : 0;
	else if (!strcmp(key, "unidirectional"))
	  unidirectional_traffic = lua_toboolean(L, -1) ? 1 : 0;
	else if (!strcmp(key, "alertedFlows"))
	  alerted_flows = lua_toboolean(L, -1) ? 1 : 0;
	else if (!strcmp(key, "filteredFlows"))
	  filtered_flows = lua_toboolean(L, -1) ? 1 : 0;
	//else
	  //ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid bool type for option %s", key);
	break;

      default:
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error: type %d not handled", t);
	break;
      }

    lua_pop(L, 1);
  }
}
