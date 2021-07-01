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

LocalHost::LocalHost(NetworkInterface *_iface, Mac *_mac,
		     VLANid _vlanId, u_int16_t _observation_point_id,
		     IpAddress *_ip) : Host(_iface, _mac, _vlanId, _observation_point_id, _ip) {
#ifdef LOCALHOST_DEBUG
  char buf[48];
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Instantiating local host %s",
			       _ip ? _ip->print(buf, sizeof(buf)) : "");
#endif
  initialize();
}

/* *************************************** */

LocalHost::LocalHost(NetworkInterface *_iface, char *ipAddress,
		     VLANid _vlanId, u_int16_t _observation_point_id)
  : Host(_iface, ipAddress, _vlanId, _observation_point_id) {
  initialize();
}

/* *************************************** */

LocalHost::~LocalHost() {
  if(initial_ts_point) delete(initial_ts_point);
  freeLocalHostData();
}

/* *************************************** */

void LocalHost::set_hash_entry_state_idle() {
  /* Serialization is performed, inline, as soon as the LocalHost becomes idle, and
     not when it is deleted. This guarantees that, if the same host becomes active again,
     its counters will be consistent even if its other instance has still to be deleted. */
  if(data_delete_requested)
    deleteRedisSerialization();
  else if((ntop->getPrefs()->is_idle_local_host_cache_enabled()
      || ntop->getPrefs()->is_active_local_host_cache_enabled())
     && (!ip.isEmpty())) {
    Mac *mac = getMac();
    checkStatsReset();
    serializeToRedis();

    /* For LBD hosts in the DHCP range, also save the IP -> MAC
     * association. This allows us to both search the host by IP and to
     * bring up the host in memory with the correct stats. */
    if(mac && serializeByMac()) {
      char key[CONST_MAX_LEN_REDIS_KEY];
      char buf[64], mac_buf[32];

      snprintf(key, sizeof(key), IP_MAC_ASSOCIATION, iface->get_id(), ip.print(buf, sizeof(buf)), vlan_id);
      mac->print(mac_buf, sizeof(mac_buf));

      /* IP@VLAN -> MAC */
      ntop->getRedis()->set(key, mac_buf, ntop->getPrefs()->get_local_host_cache_duration());
    }
  }

  iface->decNumHosts(true /* A local host */);
  if(NetworkStats *ns = iface->getNetworkStats(local_network_id))
    ns->decNumHosts();

  GenericHashEntry::set_hash_entry_state_idle();
}

/* *************************************** */

/* NOTE: Host::initialize will be called from the Host initializator */
void LocalHost::initialize() {
  char buf[64], host[96], rsp[256];
  
  stats = allocateStats();
  updateHostPool(true /* inline with packet processing */, true /* first inc */);

  local_network_id = -1;
  drop_all_host_traffic = false;
  os_detail = NULL;

  ip.isLocalHost(&local_network_id);

  systemHost = ip.isLocalInterfaceAddress();

  PROFILING_SUB_SECTION_ENTER(iface, "LocalHost::initialize: local_host_cache", 16);
  if(ntop->getPrefs()->is_idle_local_host_cache_enabled()) {
    if(!deserializeFromRedis())
      deleteRedisSerialization();
  }
  PROFILING_SUB_SECTION_EXIT(iface, 16);

  /* Clone the initial point. It will be written to the timeseries DB to
   * address the first point problem (https://github.com/ntop/ntopng/issues/2184). */
  initial_ts_point = new (std::nothrow) LocalHostStats(*(LocalHostStats *)stats);
  initialization_time = time(NULL);

  char *strIP = ip.print(buf, sizeof(buf));
  snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);

  if(ntop->getPrefs()->is_dns_resolution_enabled())
    ntop->getRedis()->getAddress(strIP, rsp, sizeof(rsp), true);

  PROFILING_SUB_SECTION_ENTER(iface, "LocalHost::initialize: updateHostTrafficPolicy", 18);
  updateHostTrafficPolicy(host);
  PROFILING_SUB_SECTION_EXIT(iface, 18);

  iface->incNumHosts(true /* Local Host */);
  if(NetworkStats *ns = iface->getNetworkStats(local_network_id))
    ns->incNumHosts();
  
#ifdef LOCALHOST_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s is %s [%p]",
			       ip.print(buf, sizeof(buf)),
			       isSystemHost() ? "systemHost" : "", this);
#endif
}

/* *************************************** */

char* LocalHost::getSerializationKey(char *redis_key, uint bufsize) {
  Mac *mac = getMac();

  if(mac && serializeByMac()) {
    char mac_buf[128];

    get_mac_based_tskey(mac, mac_buf, sizeof(mac_buf));

    return(getMacBasedSerializationKey(redis_key, bufsize, mac_buf));
  }

  return(getIpBasedSerializationKey(redis_key, bufsize));
}

/* *************************************** */

void LocalHost::deserialize(json_object *o) {
  json_object *obj;

  if(!isBroadcastHost()) stats->deserialize(o);

  if(! mac) {
    u_int8_t mac_buf[6];
    memset(mac_buf, 0, sizeof(mac_buf));

    if(json_object_object_get_ex(o, "mac_address", &obj)) Utils::parseMac(mac_buf, json_object_get_string(obj));

    // sticky hosts enabled, we must bring up the mac address
    if((mac = iface->getMac(mac_buf, true /* create if not exists */, true /* Inline call */)) != NULL)
      mac->incUses();
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Internal error: NULL mac. Are you running out of memory or MAC hash is full?");
  }

  GenericHashEntry::deserialize(o);
  if(json_object_object_get_ex(o, "last_stats_reset", &obj)) last_stats_reset = json_object_get_int64(obj);

  if(json_object_object_get_ex(o, "os_id", &obj))
    inlineSetOS((OSType)json_object_get_int(obj));

  /* We commented the line below to avoid strings too long */
#if 0
  activityStats.reset();
  if(json_object_object_get_ex(o, "activityStats", &obj)) activityStats.deserialize(obj);
#endif

  checkStatsReset();
}

/* *************************************** */

void LocalHost::updateHostTrafficPolicy(char *key) {
#ifdef HAVE_NEDGE
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
#endif
}

/* ***************************************** */

const char * LocalHost::getOSDetail(char * const buf, ssize_t buf_len) {
  if(buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", os_detail ? os_detail : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* *************************************** */

void LocalHost::lua_contacts_stats(lua_State *vm) const {
  if(!stats)
    return;

  lua_newtable(vm);

  lua_push_uint32_table_entry(vm, "dns",  stats->getDNSContactCardinality());
  lua_push_uint32_table_entry(vm, "smtp", stats->getSMTPContactCardinality());
  lua_push_uint32_table_entry(vm, "ntp",  stats->getNTPContactCardinality());
  
  lua_pushstring(vm, "server_contacts");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHost::lua(lua_State* vm, AddressTree *ptree,
		    bool host_details, bool verbose,
		    bool returnHost, bool asListElement) {
  char buf_id[64], *host_id = buf_id;
  const char *local_net;
  bool mask_host = Utils::maskHost(isLocalHost());

  if((ptree && (!match(ptree))) || mask_host)
    return;

  Host::lua(vm,
	    NULL /* ptree already checked */,
	    host_details, verbose, returnHost,
	    false /* asListElement possibly handled later */);

  /* *** */

  Host::lua_blacklisted_flows(vm);
  lua_contacts_stats(vm);

  /* *** */
  
  lua_push_int32_table_entry(vm, "local_network_id", local_network_id);

  local_net = ntop->getLocalNetworkName(local_network_id);

  if(local_net == NULL)
    lua_push_nil_table_entry(vm, "local_network_name");
  else
    lua_push_str_table_entry(vm, "local_network_name", local_net);

  if(asListElement) {
    host_id = get_hostkey(buf_id, sizeof(buf_id));

    lua_pushstring(vm, host_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
  
  /* Don't add anything beyond this line (due to lua indexing) */
}

/* *************************************** */

// TODO move into nDPI
void LocalHost::inlineSetOSDetail(const char *_os_detail) {
  if((mac == NULL)
     /*
       When this happens then this is a (NAT+)router and
       the OS would be misleading
     */
     || (mac->getDeviceType() == device_networking)
     ) return;

  if(os_detail || !_os_detail)
    return; /* Already set */

  if((os_detail = strdup(_os_detail))) {
    // TODO set mac device type
    ;
    DeviceType devtype = Utils::getDeviceTypeFromOsDetail(os_detail);

    if(devtype != device_unknown)
      mac->setDeviceType(devtype);
  }
}

/* *************************************** */

void LocalHost::lua_peers_stats(lua_State* vm) const {
  if(stats)
    stats->luaPeers(vm);
  else
    lua_pushnil(vm);
}

/* *************************************** */

/* Optimized method to fetch timeseries data for the host. Only returns
 * the ::Lua of the needed fields. Moreover, some fields are represented
 * in a compact way to speedup insertion and lookup (e.g. nDPIStats::lua with tsLua) */
void LocalHost::lua_get_timeseries(lua_State* vm) {
  char buf_id[64], *host_id;

  lua_newtable(vm);

  /* The timeseries point */
  lua_newtable(vm);
  ((LocalHostStats*)stats)->lua_get_timeseries(vm);

  Host::lua_blacklisted_flows(vm);
  
  /* NOTE: the following data is *not* exported for the initial_point */
  lua_push_uint64_table_entry(vm, "active_flows.as_client", getNumOutgoingFlows());
  lua_push_uint64_table_entry(vm, "active_flows.as_server", getNumIncomingFlows());
  lua_push_uint64_table_entry(vm, "contacts.as_client", getNumActiveContactsAsClient());
  lua_push_uint64_table_entry(vm, "contacts.as_server", getNumActiveContactsAsServer());
  lua_push_uint64_table_entry(vm, "engaged_alerts", getNumEngagedAlerts());

  lua_pushstring(vm, "ts_point");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* Additional data/metadata */
  lua_push_str_table_entry(vm, "tskey", get_tskey(buf_id, sizeof(buf_id)));
  if(initial_ts_point) {
    lua_push_uint64_table_entry(vm, "initial_point_time", initialization_time);

    /* Dump the initial host timeseries */
    lua_newtable(vm);
    initial_ts_point->lua_get_timeseries(vm);
    lua_pushstring(vm, "initial_point");
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    delete(initial_ts_point);
    initial_ts_point = NULL;
  }

  host_id = get_hostkey(buf_id, sizeof(buf_id));
  lua_pushstring(vm, host_id);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHost::freeLocalHostData() {
  /* Better not to use a virtual function as it is called in the destructor as well */
  if(os_detail) { free(os_detail); os_detail = NULL; }
  
  for(std::unordered_map<u_int32_t, DoHDoTStats*>::iterator it = doh_dot_map.begin(); it != doh_dot_map.end(); ++it)
    delete it->second;
}

/* *************************************** */

void LocalHost::deleteHostData() {
  Host::deleteHostData();

  m.lock(__FILE__, __LINE__);
  freeLocalHostData();
  m.unlock(__FILE__, __LINE__);

  updateHostTrafficPolicy(NULL);
}

/* *************************************** */

char * LocalHost::getMacBasedSerializationKey(char *redis_key, size_t size, char *mac_key) {
  /* Serialize both IP and MAC for static hosts */
  snprintf(redis_key, size, HOST_BY_MAC_SERIALIZED_KEY, iface->get_id(), mac_key);

  return(redis_key);
}

/* *************************************** */

char * LocalHost::getIpBasedSerializationKey(char *redis_key, size_t size) {
  char buf[CONST_MAX_LEN_REDIS_KEY];

  snprintf(redis_key, size, HOST_SERIALIZED_KEY, iface->get_id(), ip.print(buf, sizeof(buf)), vlan_id);

  return redis_key;
}

/* *************************************** */

/*
 * Reload non-critical host prefs. Such prefs are not reloaded inline to
 * avoid slowing down the packet capture. The default value (set into the
 * host initializer) will be returned until this delayed method is called. 
 */
void LocalHost::reloadPrefs() {
  Host::reloadPrefs();
}

/* *************************************** */

void LocalHost::incDohDoTUses(Host *host) {
  u_int32_t key = host->get_ip()->key() + host->get_vlan_id();
  std::unordered_map<u_int32_t, DoHDoTStats*>::iterator it;

  m.lock(__FILE__, __LINE__);
  it = doh_dot_map.find(key);

  if(it == doh_dot_map.end()) {
    if(doh_dot_map.size() > 8 /* Max # entries */) return;
    
    doh_dot_map[key] = new DoHDoTStats(*(host->get_ip()), host->get_vlan_id());
  }

  doh_dot_map[key]->incUses();

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void LocalHost::luaDoHDot(lua_State *vm) {
  u_int8_t i = 0;
  
  if(doh_dot_map.size() == 0) return;
  
  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);
  
  for(std::unordered_map<u_int32_t, DoHDoTStats*>::iterator it = doh_dot_map.begin();
      it != doh_dot_map.end(); ++it) {
    lua_newtable(vm);
    
    it->second->lua(vm);
    
    lua_pushinteger(vm, i);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
    i++;
  }
  
  m.unlock(__FILE__, __LINE__);
  
  lua_pushstring(vm, "DoH_DoT");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */
