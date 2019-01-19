/*
 *
 * (C) 2013-19 - ntop.org
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

LocalHost::LocalHost(NetworkInterface *_iface, Mac *_mac, u_int16_t _vlanId, IpAddress *_ip) : Host(_iface, _mac, _vlanId, _ip) {
#ifdef LOCALHOST_DEBUG
  char buf[48];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Instantiating local host %s", _ip ? _ip->print(buf, sizeof(buf)) : "");
#endif
  initialize();
}

/* *************************************** */

LocalHost::LocalHost(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId) : Host(_iface, ipAddress, _vlanId) {
  initialize();
}

/* *************************************** */

LocalHost::~LocalHost() {
  serialize2redis(); /* possibly dumps counters and data to redis */

  if(os)              free(os);
  if(os_shadow)       free(os_shadow);
}

/* *************************************** */

void LocalHost::initialize() {
  char key[64], redis_key[128], *k;
  char buf[64];

  stats = allocateStats();
  updateHostPool(true /* inline with packet processing */, true /* first inc */);

  local_network_id = -1;
  dhcpUpdated = false;
  drop_all_host_traffic = false;
  os = NULL, os_shadow = NULL;

  ip.isLocalHost(&local_network_id);
  networkStats = getNetworkStats(local_network_id);

  systemHost = ip.isLocalInterfaceAddress();

  PROFILING_SUB_SECTION_ENTER(iface, "LocalHost::initialize: readDHCPCache", 14);
  readDHCPCache();
  PROFILING_SUB_SECTION_EXIT(iface, 14);

  PROFILING_SUB_SECTION_ENTER(iface, "LocalHost::initialize: local_host_cache", 16);
  if(ntop->getPrefs()->is_idle_local_host_cache_enabled()) {
    char *json = NULL;
    u_int json_len = 0;

    k = ip.print(key, sizeof(key));
    snprintf(redis_key, sizeof(redis_key), HOST_SERIALIZED_KEY, iface->get_id(), k, vlan_id);

    if((json_len = ntop->getRedis()->len(redis_key)) > 0
       && ++json_len <= HOST_MAX_SERIALIZED_LEN) {
      if((json = (char*)malloc(json_len * sizeof(char))) == NULL)
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "Unable to allocate memory to deserialize %s", redis_key);
      else if(!ntop->getRedis()->get(redis_key, json, json_len)){
	/* Found saved copy of the host so let's start from the previous state */
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s => %s", redis_key, json);
	ntop->getTrace()->traceEvent(TRACE_INFO, "Deserializing %s", redis_key);

	deserialize(json, redis_key);
      }

      if(json) free(json);
    }
  }
  PROFILING_SUB_SECTION_EXIT(iface, 16);

  char host[96];
  char *strIP = ip.print(buf, sizeof(buf));
  snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);
  char rsp[256];

  if(ntop->getRedis()->getAddress(strIP, rsp, sizeof(rsp), true) == 0)
    setName(rsp);

  PROFILING_SUB_SECTION_ENTER(iface, "LocalHost::initialize: updateHostTrafficPolicy", 18);
  updateHostTrafficPolicy(host);
  PROFILING_SUB_SECTION_EXIT(iface, 18);

  iface->incNumHosts(true /* Local Host */);

#ifdef LOCALHOST_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s is %s [%p]",
			       ip.print(buf, sizeof(buf)),
			       isSystemHost() ? "systemHost" : "", this);
#endif
}

/* *************************************** */

bool LocalHost::readDHCPCache() {
  Mac *m = mac; /* Cache it as it can be replaced with secondary_mac */

  if(m && (!dhcpUpdated)) {
    /* Check DHCP cache */
    char client_mac[24], buf[64], key[64];

    dhcpUpdated = true;

    if(!m->isNull()) {
      Utils::formatMac(m->get_mac(), client_mac, sizeof(client_mac));

      snprintf(key, sizeof(key), DHCP_CACHE, iface->get_id());
      if(ntop->getRedis()->hashGet(key, client_mac, buf, sizeof(buf)) == 0) {
	setName(buf);
	return true;
      }
    }
  }

  return false;
}

/* *************************************** */

void LocalHost::serialize2redis() {
  char host_key[128], key[128];
  char *k = ip.print(host_key, sizeof(host_key));
  snprintf(key, sizeof(key), HOST_SERIALIZED_KEY, iface->get_id(), k, vlan_id);

  if(data_delete_requested) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Delete serialization %s", k);
    ntop->getRedis()->del(key);
  } else if((ntop->getPrefs()->is_idle_local_host_cache_enabled()
      || ntop->getPrefs()->is_active_local_host_cache_enabled())
     && (!ip.isEmpty())) {
    char *json = serialize();

    ntop->getRedis()->set(key, json, ntop->getPrefs()->get_local_host_cache_duration());
    ntop->getTrace()->traceEvent(TRACE_INFO, "Dumping serialization %s", k);
    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s => %s", k, json);
    free(json);
  }
}

/* *************************************** */

bool LocalHost::deserialize(char *json_str, char *key) {
  json_object *o, *obj;
  enum json_tokener_error jerr = json_tokener_success;

  if((o = json_tokener_parse_verbose(json_str, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] key: %s: %s",
				 json_tokener_error_desc(jerr),
				 key,
				 json_str);
    return(false);
  }

  stats->deserialize(o);

  if(! mac) {
    u_int8_t mac_buf[6];
    memset(mac_buf, 0, sizeof(mac_buf));

    if(json_object_object_get_ex(o, "mac_address", &obj)) Utils::parseMac(mac_buf, json_object_get_string(obj));

    // sticky hosts enabled, we must bring up the mac address
    if((mac = iface->getMac(mac_buf, true /* create if not exists*/)) != NULL)
      mac->incUses();
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: NULL mac. Are you running out of memory?");
  }

  if(json_object_object_get_ex(o, "seen.first", &obj)) first_seen = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "seen.last", &obj))  last_seen  = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "last_stats_reset", &obj)) last_stats_reset = json_object_get_int64(obj);

  if(json_object_object_get_ex(o, "symbolic_name", &obj))  { if(symbolic_name) free(symbolic_name); symbolic_name = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "os", &obj))             { if(os) free(os); os = strdup(json_object_get_string(obj)); }

  /* We commented the line below to avoid strings too long */
#if 0
  activityStats.reset();
  if(json_object_object_get_ex(o, "activityStats", &obj)) activityStats.deserialize(obj);
#endif

  json_object_put(o);
  checkStatsReset();

  return(true);
}

/* *************************************** */

void LocalHost::updateHostTrafficPolicy(char *key) {
  char buf[64], *host;

  if(key)
    host = key;
  else
    host = get_hostkey(buf, sizeof(buf));

  if(iface->isPacketInterface()) {
    if((ntop->getRedis()->hashGet((char*)DROP_HOST_TRAFFIC, host, buf, sizeof(buf)) == -1)
       || (strcmp(buf, "true") != 0))
      drop_all_host_traffic = false;
    else
      drop_all_host_traffic = true;

  }
}

/* *************************************** */

void LocalHost::lua(lua_State* vm, AddressTree *ptree,
		    bool host_details, bool verbose,
		    bool returnHost, bool asListElement) {
  char buf_id[64], *host_id = buf_id;
  char *local_net;
  bool mask_host = Utils::maskHost(isLocalHost());

  if((ptree && (!match(ptree))) || mask_host)
    return;

  Host::lua(vm,
	    NULL /* ptree already checked */,
	    host_details, verbose, returnHost,
	    false /* asListElement possibly handled later */);

  lua_push_int32_table_entry(vm, "local_network_id", local_network_id);

  local_net = ntop->getLocalNetworkName(local_network_id);
  if(local_net == NULL)
    lua_push_nil_table_entry(vm, "local_network_name");
  else
    lua_push_str_table_entry(vm, "local_network_name", local_net);

  /* Criteria */
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "upload", stats->getNumBytesSent());
  lua_push_uint64_table_entry(vm, "download", stats->getNumBytesRcvd());
  lua_push_uint64_table_entry(vm, "unknown", get_ndpi_stats()->getProtoBytes(NDPI_PROTOCOL_UNKNOWN));
  lua_push_uint64_table_entry(vm, "incomingflows", getNumIncomingFlows());
  lua_push_uint64_table_entry(vm, "outgoingflows", getNumOutgoingFlows());

  lua_pushstring(vm, "criteria");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  if(asListElement) {
    host_id = get_hostkey(buf_id, sizeof(buf_id));

    lua_pushstring(vm, host_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void LocalHost::setOS(char *_os, bool ignoreIfPresent) {
  if((mac == NULL)
     /*
       When this happens then this is a (NAT+)router and
       the OS would be misleading
     */
     || (mac->getDeviceType() == device_networking)
     ) return;

  if((os == NULL) || ignoreIfPresent) {
    if(os_shadow) free(os_shadow);
    os_shadow = os;
    os = _os ? strdup(_os) : NULL;
  }

  if (!os) return;

  if(strcasestr(os, "iPhone")
     || strcasestr(os, "Android")
     || strcasestr(os, "mobile"))
    mac->setDeviceType(device_phone);
  else if(strcasestr(os, "Mac OS")
	  || strcasestr(os, "Windows")
	  || strcasestr(os, "Linux"))
    mac->setDeviceType(device_workstation);
  else if(strcasestr(os, "iPad") || strcasestr(os, "tablet"))
    mac->setDeviceType(device_tablet);
}

/* *************************************** */

void LocalHost::tsLua(lua_State* vm) {
  char buf_id[64], *host_id;

  stats->tsLua(vm);

  host_id = get_hostkey(buf_id, sizeof(buf_id));
  lua_pushstring(vm, host_id);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHost::deleteHostData() {
  Host::deleteHostData();

  setOS(NULL, false /* overwrite */);
  dhcpUpdated = false;
  updateHostTrafficPolicy(NULL);
}
