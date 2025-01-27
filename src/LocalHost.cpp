/*
 *
 * (C) 2013-25 - ntop.org
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

LocalHost::LocalHost(NetworkInterface *_iface, int32_t _iface_idx, Mac *_mac,
                     u_int16_t _vlanId, u_int16_t _observation_point_id,
                     IpAddress *_ip)
  : Host(_iface, _iface_idx, _mac, _vlanId, _observation_point_id, _ip),
    contacted_server_ports(CONST_MAX_NUM_QUEUED_PORTS, "localhost-serverportsproto"),
    usedPorts(this) {
  tcp_fingerprint = NULL;

  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

#ifdef LOCALHOST_DEBUG
  char buf[48];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Instantiating local host %s",
                               _ip ? _ip->print(buf, sizeof(buf)) : "");
#endif
  initialize();
}

/* *************************************** */

LocalHost::LocalHost(NetworkInterface *_iface, int32_t _iface_idx,
                     char *ipAddress, u_int16_t _vlanId,
                     u_int16_t _observation_point_id)
  : Host(_iface, _iface_idx, ipAddress, _vlanId, _observation_point_id),
    contacted_server_ports(CONST_MAX_NUM_QUEUED_PORTS,
			   "localhost-serverportsproto"),
    usedPorts(this) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  initialize();
}

/* *************************************** */

LocalHost::~LocalHost() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);

  dumpAssetInfo(true);

  if (initial_ts_point) delete (initial_ts_point);
  freeLocalHostData();

  /* Decrease number of active hosts */
  iface->decNumHosts(this, is_rx_only);
  asset_map.clear();
}

/* *************************************** */

void LocalHost::set_hash_entry_state_idle() {
  if (ntop->getPrefs()->is_active_local_host_cache_enabled() &&
      (!ip.isEmpty())) {
    Mac *mac = getMac();

    checkStatsReset();

    /* For LBD hosts in the DHCP range, also save the IP -> MAC
     * association. This allows us to both search the host by IP and to
     * bring up the host in memory with the correct stats. */
    if (mac && serializeByMac()) {
      char key[CONST_MAX_LEN_REDIS_KEY];
      char buf[64], mac_buf[32];

      snprintf(key, sizeof(key), IP_MAC_ASSOCIATION, iface->get_id(),
               ip.print(buf, sizeof(buf)), vlan_id);
      mac->print(mac_buf, sizeof(mac_buf));

      /* IP@VLAN -> MAC */
      ntop->getRedis()->set(key, mac_buf,
                            ntop->getPrefs()->get_local_host_cache_duration());
    }
  }

  /* Only increase the number of host if it's a unicast host */
  if (isUnicastHost()) {
    if (NetworkStats *ns = iface->getNetworkStats(local_network_id))
      ns->decNumHosts();
  }

  GenericHashEntry::set_hash_entry_state_idle();
}

/* *************************************** */

/* NOTE: Host::initialize will be called by the constructor after the Host
 * initializator */
void LocalHost::initialize() {
  char buf[64], host[96], rsp[256];
  stats = allocateStats();
  updateHostPool(true /* inline with packet processing */,
                 true /* first inc */);

  local_network_id = -1;
  os_detail = NULL;
  asset_map_updated = false;

  ip.isLocalHost(&local_network_id);
  inconsistent_host_os = false;
  systemHost = ip.isLocalInterfaceAddress();

  /* Clone the initial point. It will be written to the timeseries DB to
   * address the first point problem
   * (https://github.com/ntop/ntopng/issues/2184). */
  initial_ts_point = new (std::nothrow) LocalHostStats(*(LocalHostStats *)stats);
  initialization_time = time(NULL);

  char *strIP = ip.print(buf, sizeof(buf));
  snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);

  if (ntop->getPrefs()->is_dns_resolution_enabled()) {
    if (isBroadcastHost() || isMulticastHost() ||
        (isIPv6() &&
         ((strncmp(strIP, "ff0", 3) == 0) || (strncmp(strIP, "fe80", 4) == 0))))
      ;
    else {
      ntop->getRedis()->getAddress(strIP, rsp, sizeof(rsp), true);

      if (rsp[0] != '\0') setResolvedName(rsp);
    }
  }

  INTERFACE_PROFILING_SUB_SECTION_ENTER(iface, "LocalHost::initialize: updateHostTrafficPolicy", 18);
  updateHostTrafficPolicy(host);
  INTERFACE_PROFILING_SUB_SECTION_EXIT(iface, 18);

  /* Only increase the hosts number if it's a unicast host */
  if (isUnicastHost()) {
    if (NetworkStats *ns = iface->getNetworkStats(local_network_id))
      ns->incNumHosts();
  }
  
  iface->incNumHosts(this, true /* Initialization: bytes are 0, considered RX only */);

#ifdef LOCALHOST_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s is %s [%p]",
                               ip.print(buf, sizeof(buf)),
                               isSystemHost() ? "systemHost" : "", this);
#endif

  router_mac_set = 0, memset(router_mac, 0, sizeof(router_mac));

#ifdef HAVE_NEDGE
  drop_all_host_traffic = 0;
#endif

  if (ntop->getPrefs()->enableFingerprintStats())
    fingerprints = new (std::nothrow) HostFingerprints();
  else
    fingerprints = NULL;

  tcp_fingerprint_host_os = os_hint_unknown;
  dumpAssetInfo(false);
  gettimeofday(&last_periodic_asset_update, NULL);
}

/* *************************************** */

void LocalHost::deferredInitialization() {
  Host::deferredInitialization();
}

/* *************************************** */

void LocalHost::dumpAssetInfo(bool include_last_seen) {
  /* Return in case the preference is disabled */
  if (!ntop->getPrefs()->isAssetsCollectionEnabled()) {
#ifdef NTOPNG_DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Assets Collection Disabled, please enable it from the Preferences.");
#endif  
    return;
  }
  /* Remove the key from the hash, used to get the offline hosts */
  /* Exclude the multicast/broadcast addresses */
  if (!ntop->getRedis() || !isLocalUnicastHost()) return;

  /* Exclude local-link fe80::/10, marked as private */
  if (isIPv6() && isPrivateHost()) return;

  Mac *cur_mac = getMac();
  /* In case the MAC is NULL or the MAC is a special */
  /* address or a broadcast address do not include it */
  if (!cur_mac || cur_mac->isSpecialMac() || cur_mac->isBroadcast()) return;

  char key[128], buf[64], *serialization_key = NULL, *json_str = NULL;
  ndpi_serializer host_json;
  u_int32_t json_str_len = 0;

#ifdef NTOPNG_DEBUG
  cur_mac->print(buf, sizeof(buf));
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Adding Host %s to Assets [Ifid: %d][VLAN: %d][MAC: %s][Status: %s]",
			       ip.print(buf, sizeof(buf)),
			       iface->get_id(),
             vlan_id,
			       buf,
             include_last_seen ? "Inactive" : "Active");
#endif

  ndpi_init_serializer(&host_json, ndpi_serialization_format_json);

  ndpi_serialize_string_string(&host_json, "type", "host");
  ndpi_serialize_string_string(&host_json, "ip", ip.print(buf, sizeof(buf)));

  ndpi_serialize_string_uint64(&host_json, "first_seen", get_first_seen());
  if (include_last_seen) {
    /* This is done in a way that when an host disappear and reapper in the net, it is not 
     * going to be shown in the list of inactive hosts, the last seen is put to 0 again
     */
    ndpi_serialize_string_uint64(&host_json, "last_seen", get_last_seen());
  }

  if (cur_mac) {
    ndpi_serialize_string_uint32(&host_json, "device_type", getDeviceType());
    ndpi_serialize_string_string(&host_json, "mac", cur_mac->print(buf, sizeof(buf)));
    ndpi_serialize_string_string(&host_json, "manufacturer", cur_mac->get_manufacturer());
  }

  ndpi_serialize_string_uint32(&host_json, "vlan", (u_int16_t)get_vlan_id());
  ndpi_serialize_string_uint32(&host_json, "network", (u_int32_t)get_local_network_id());
  ndpi_serialize_string_string(&host_json, "name", get_name(buf, sizeof(buf), false));

  serialization_key = getSerializationKey(key, sizeof(key), true);

  ndpi_serialize_string_string(&host_json, "key", serialization_key);

  /* Now dump the json_info field */
  dumpAssetJson(&host_json);

  json_str = ndpi_serializer_get_buffer(&host_json, &json_str_len);
  if ((json_str != NULL) && (json_str_len > 0)) {
    char redis_key[64];

    snprintf(redis_key, sizeof(redis_key), OFFLINE_LOCAL_HOSTS_MACS_QUEUE_NAME, iface->get_id());
    ntop->getRedis()->lpush(redis_key, json_str, CONST_MAX_INACTIVE_HOSTS_MAC_QUEUE_LEN);
  }

  ndpi_term_serializer(&host_json);
}

/* *************************************** */

void LocalHost::periodic_stats_update(const struct timeval *tv) {
  checkGatewayInfo();
  /* If at least 5 minutes passed and the map was updated, dump the info */
  float diff = Utils::msTimevalDiff(tv, &last_periodic_asset_update) / 1000; /* in Sec */
  if ((diff > CONST_ASSETS_PERIODIC_UPDATE) && asset_map_updated) {
    memcpy(&last_periodic_asset_update, tv, sizeof(last_periodic_asset_update));
    asset_map_updated = false;
    dumpAssetInfo(false);
  }
  Host::periodic_stats_update(tv);
}

/* *************************************** */

void LocalHost::checkGatewayInfo() {
  if (mac) {
    //#define DEBUG_GATEWAY 1
    bool is_gateway = mac->getDeviceType() == device_networking;
#ifdef DEBUG_GATEWAY
    char buf[64];
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "Checking device type [IP: %s] [Type: %d]",
                                 ip.print(buf, sizeof(buf)), device_networking);
#endif
    if (is_gateway) {
      ip.setGateway(true);
#ifdef DEBUG_GATEWAY
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Gateway detected [IP: %s]",
                                   ip.print(buf, sizeof(buf)));
#endif
    } else {
      ip.setGateway(false);
    }
  }
}

/* *************************************** */

char *LocalHost::getSerializationKey(char *redis_key, u_int bufsize, bool short_format) {
  Mac *mac = getMac();

  if (mac && serializeByMac()) {
    char mac_buf[128];

    get_mac_based_tskey(mac, mac_buf, sizeof(mac_buf));

    return (getMacBasedSerializationKey(redis_key, bufsize, mac_buf, short_format));
  }

  return (getIPBasedSerializationKey(redis_key, bufsize, short_format));
}

/* *************************************** */

char *LocalHost::getRedisKey(char *buf, uint buf_len, bool skip_prefix) {
  Mac *mac = getMac();

  if (mac && serializeByMac()) {
    get_mac_based_tskey(mac, buf, buf_len, skip_prefix);
    return (buf);
  } else
    return (get_hostkey(buf, buf_len, false));
}

/* *************************************** */

void LocalHost::updateHostTrafficPolicy(char *key) {
#ifdef HAVE_NEDGE
  char buf[64], *host;

  if (key)
    host = key;
  else
    host = get_hostkey(buf, sizeof(buf));

  if (iface->isPacketInterface()) {
    if ((ntop->getRedis()->hashGet((char *)DROP_HOST_TRAFFIC, host, buf,
                                   sizeof(buf)) == -1) ||
        (strcmp(buf, "true") != 0))
      drop_all_host_traffic = 0;
    else
      drop_all_host_traffic = 1;
  }
#endif
}

/* ***************************************** */

const char *LocalHost::getOSDetail(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", os_detail ? os_detail : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* *************************************** */

void LocalHost::lua_contacts_stats(lua_State *vm) const {
  if (!stats) return;

  lua_newtable(vm);

  lua_push_uint32_table_entry(vm, "dns", stats->getDNSContactCardinality());
  lua_push_uint32_table_entry(vm, "smtp", stats->getSMTPContactCardinality());
  lua_push_uint32_table_entry(vm, "imap", stats->getIMAPContactCardinality());
  lua_push_uint32_table_entry(vm, "pop", stats->getPOPContactCardinality());
  lua_push_uint32_table_entry(vm, "ntp", stats->getNTPContactCardinality());
  lua_push_uint32_table_entry(vm, "domain_names",
                              stats->getDomainNamesCardinality());

  lua_pushstring(vm, "server_contacts");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHost::lua(lua_State *vm, AddressTree *ptree, bool host_details,
                    bool verbose, bool returnHost, bool asListElement) {
  char buf_id[64], *host_id = buf_id;
  const char *local_net;
  bool mask_host = Utils::maskHost(isLocalHost());
#ifdef NTOPNG_PRO
  char asset_key[96];
#endif

  if ((ptree && (!match(ptree))) || mask_host) return;

  Host::lua(vm, NULL /* ptree already checked */, host_details, verbose,
            returnHost, false /* asListElement possibly handled later */);

  /* *** */

  Host::lua_blacklisted_flows(vm);
  lua_contacts_stats(vm);
  usedPorts.lua(vm, iface);

  /* *** */

#ifdef NTOPNG_PRO
  snprintf(asset_key, sizeof(asset_key), ASSET_SERVICE_KEY,
           getInterface()->get_id(), getRedisKey(buf_id, sizeof(buf_id)));

  lua_push_str_table_entry(vm, "asset_key", asset_key);
#endif

  lua_push_int32_table_entry(vm, "local_network_id", local_network_id);

  local_net = ntop->getLocalNetworkName(local_network_id);

  if (local_net == NULL)
    lua_push_nil_table_entry(vm, "local_network_name");
  else
    lua_push_str_table_entry(vm, "local_network_name", local_net);

  if (router_mac_set) {
    char router_buf[24];

    lua_push_str_table_entry(vm, "router",
			     Utils::formatMac(router_mac, router_buf, sizeof(router_buf)));
  }

  if(inconsistent_host_os)
    lua_push_bool_table_entry(vm, "inconsistent_host_os", true);
  
  if(tcp_fingerprint_host_os != os_hint_unknown) {
    lua_newtable(vm);
    lua_push_str_table_entry(vm, "os", ndpi_print_os_hint(tcp_fingerprint_host_os));
    lua_pushstring(vm, "fingerprint");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  if(os_learning.size() > 0) {
    lua_newtable(vm);

    /* Theoretically we should lock here */
    for(std::map<OSLearningMode, OSType>::iterator it = os_learning.begin(); it != os_learning.end(); it++) {
      lua_push_str_table_entry(vm, Utils::learningMode2str(it->first), Utils::OSType2Str(it->second));
    }

    lua_pushstring(vm, "os_learning");
    lua_insert(vm, -2);
    lua_settable(vm, -3);

  }

  /* Add new entries before this line! */

  if (asListElement) {
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
  if ((mac == NULL)
      /*
        When this happens then this is a (NAT+)router and
        the OS would be misleading
      */
      || (mac->getDeviceType() == device_networking))
    return;

  if (os_detail || !_os_detail)
    return; /* Already set */

  if ((os_detail = strdup(_os_detail))) {
    enum operating_system_hint hint;

    // TODO set mac device type
    DeviceType devtype = Utils::getDeviceTypeFromOsDetail(os_detail, &hint);

    if (devtype != device_unknown) mac->setDeviceType(devtype);
  }
}

/* *************************************** */

void LocalHost::lua_peers_stats(lua_State *vm) const {
  if (stats)
    stats->luaPeers(vm);
  else
    lua_pushnil(vm);
}

/* *************************************** */

/*
 *Optimized method to fetch timeseries data for the host. Only returns
 * the ::Lua of the needed fields. Moreover, some fields are represented
 * in a compact way to speedup insertion and lookup (e.g. nDPIStats::lua with
 *tsLua)
 */
void LocalHost::lua_get_timeseries(lua_State *vm) {
  char buf_id[64], *host_id;

  lua_newtable(vm);

  /* The timeseries point */
  lua_newtable(vm);

  if (stats != NULL) {
    LocalHostStats *l = (LocalHostStats *)stats;

    l->lua_get_timeseries(vm);
  }

  Host::lua_blacklisted_flows(vm);
  lua_unidirectional_tcp_udp_flows(vm, true);

  /* NOTE: the following data is *not* exported for the initial_point */
  lua_push_uint64_table_entry(vm, "active_flows.as_client",
                              getNumOutgoingFlows());
  lua_push_uint64_table_entry(vm, "active_flows.as_server",
                              getNumIncomingFlows());
  lua_push_uint64_table_entry(vm, "contacts.as_client",
                              getNumActiveContactsAsClient());
  lua_push_uint64_table_entry(vm, "contacts.as_server",
                              getNumActiveContactsAsServer());
  lua_push_uint64_table_entry(vm, "engaged_alerts", getNumEngagedAlerts());

  lua_pushstring(vm, "ts_point");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* Additional data/metadata */
  lua_push_str_table_entry(vm, "tskey", get_tskey(buf_id, sizeof(buf_id)));
  if (initial_ts_point) {
    lua_push_uint64_table_entry(vm, "initial_point_time", initialization_time);

    /* Dump the initial host timeseries */
    lua_newtable(vm);
    initial_ts_point->lua_get_timeseries(vm);
    lua_pushstring(vm, "initial_point");
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    delete (initial_ts_point);
    initial_ts_point = NULL;
  }

  host_id = get_hostkey(buf_id, sizeof(buf_id));
  lua_pushstring(vm, host_id);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHost::freeLocalHostData() {
  /* Better not to use a virtual function as it is called in the destructor as
   * well */
  if (os_detail) {
    free(os_detail);
    os_detail = NULL;
  }

  if(tcp_fingerprint)
    free(tcp_fingerprint);

  for (std::unordered_map<u_int32_t, DoHDoTStats *>::iterator it = doh_dot_map.begin();
       it != doh_dot_map.end(); ++it)
    delete it->second;

  if (fingerprints) delete fingerprints;
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

char *LocalHost::getMacBasedSerializationKey(char *redis_key, size_t size,
                                             char *mac_key, bool short_format) {
  /* Serialize both IP and MAC for static hosts */
  snprintf(redis_key, size, short_format ? MAC_SERIALIZED_SHORT_KEY : HOST_BY_MAC_SERIALIZED_KEY, iface->get_id(),
           mac_key);

  return (redis_key);
}

/* *************************************** */

char *LocalHost::getIPBasedSerializationKey(char *redis_key, size_t size, bool short_format) {
  char buf[CONST_MAX_LEN_REDIS_KEY];

  snprintf(redis_key, size, short_format ? HOST_SERIALIZED_SHORT_KEY : HOST_SERIALIZED_KEY, iface->get_id(),
           ip.print(buf, sizeof(buf)), vlan_id);

  return redis_key;
}

/* *************************************** */

/*
 * Reload non-critical host prefs. Such prefs are not reloaded inline to
 * avoid slowing down the packet capture. The default value (set into the
 * host initializer) will be returned until this delayed method is called.
 */
void LocalHost::reloadPrefs() { Host::reloadPrefs(); }

/* *************************************** */

void LocalHost::incDohDoTUses(Host *host) {
  u_int32_t key = host->get_ip()->key() + host->get_vlan_id();
  std::unordered_map<u_int32_t, DoHDoTStats *>::iterator it;

  m.lock(__FILE__, __LINE__);
  it = doh_dot_map.find(key);

  if (it == doh_dot_map.end()) {
    if (doh_dot_map.size() < 8 /* Max # entries */) {
      DoHDoTStats *doh_dot =
	new (nothrow) DoHDoTStats(*(host->get_ip()), host->get_vlan_id());

      if (doh_dot) {
        doh_dot->incUses();
        doh_dot_map[key] = doh_dot;
      }
    }
  } else
    it->second->incUses();

  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void LocalHost::luaDoHDot(lua_State *vm) {
  u_int8_t i = 0;

  if (doh_dot_map.size() == 0) return;

  lua_newtable(vm);

  m.lock(__FILE__, __LINE__);

  for (std::unordered_map<u_int32_t, DoHDoTStats *>::iterator it =
	 doh_dot_map.begin();
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

void LocalHost::setRouterMac(Mac *gw) {
  if (!router_mac_set) {
    memcpy(router_mac, gw->get_mac(), 6), router_mac_set = true;
  }
}

/* ***************************************************** */

void LocalHost::setServerPort(bool isTCP, u_int16_t port, ndpi_protocol *proto,
                              time_t when) {
  bool set_port_status = usedPorts.setServerPort(isTCP, port, proto);

  if (set_port_status && ntop->getPrefs()->is_enterprise_l_edition()) {
    /* If the port is set for the first time set_port_status == true */
    u_int32_t learning_period = ntop->getPrefs()->hostPortLearningPeriod();

    if (when - get_first_seen() > learning_period) {
      if (!contacted_server_ports.isFull()) {
        /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** port %u ***", port);
         */
        contacted_server_ports.enqueue({port, proto->proto.app_protocol}, true);
      } else {
        char ip_buf[64];

        ntop->getTrace()->traceEvent(
				     TRACE_INFO,
				     "Server port %s:%d contacted but not reported: exceeded max number",
				     printMask(ip_buf, sizeof(ip_buf)), port);
      }
    }
  }
}

/* ***************************************************** */

void LocalHost::lua_get_fingerprints(lua_State *vm) {
  if (fingerprints) {
    fingerprints->ja4.lua("ja4_fingerprint", vm);
    fingerprints->hassh.lua("hassh_fingerprint", vm);
  }

  if(tcp_fingerprint != NULL)
    lua_push_str_table_entry(vm, "tcp_fingerprint", tcp_fingerprint);
}

/* *************************************** */

void LocalHost::setDhcpServer(char *name) {
  Host::setDhcpServer(name);
  addDataToAssets((char *) "dhcp_server", (char *) "true");
}

/* *************************************** */

void LocalHost::setDnsServer(char *name) {
  Host::setDnsServer(name);
  addDataToAssets((char *) "dns_server", (char *) "true");
}

/* *************************************** */

void LocalHost::setSmtpServer(char *name) {
  Host::setSmtpServer(name);
  addDataToAssets((char *) "smtp_server", (char *) "true");
}

/* *************************************** */

void LocalHost::setNtpServer(char *name) {
  Host::setNtpServer(name);
  addDataToAssets((char *) "ntp_server", (char *) "true");
}

/* *************************************** */

void LocalHost::setImapServer(char *name) {
  Host::setImapServer(name);
  addDataToAssets((char *) "imap_server", (char *) "true");
}

/* *************************************** */

void LocalHost::setPopServer(char *name) {
  Host::setPopServer(name);
  addDataToAssets((char *) "pop_server", (char *) "true");
}

/* *************************************** */

void LocalHost::offlineSetMDNSInfo(char *const str) {
  Host::offlineSetMDNSInfo(str);
}

/* *************************************** */

void LocalHost::offlineSetMDNSName(const char *mdns_n) {
  Host::offlineSetMDNSName(mdns_n);
  addDataToAssets((char *) "mdns_name", (char *) mdns_n);
}

/* *************************************** */

void LocalHost::offlineSetDHCPName(const char *dhcp_n) {
  Host::offlineSetDHCPName(dhcp_n);
  addDataToAssets((char *) "dhcp_name", (char *) dhcp_n);
}

/* *************************************** */

void LocalHost::offlineSetMDNSTXTName(const char *mdns_n_txt) {
  Host::offlineSetMDNSTXTName(mdns_n_txt);
  addDataToAssets((char *) "mdns_txt_name", (char *) mdns_n_txt);
}

/* *************************************** */

void LocalHost::offlineSetNetbiosName(const char *netbios_n) {
  Host::offlineSetNetbiosName(netbios_n);
  addDataToAssets((char *) "netbios_name", (char *) netbios_n);
}

/* *************************************** */

void LocalHost::offlineSetTLSName(const char *tls_n) {
  Host::offlineSetHTTPName(tls_n);
  addDataToAssets((char *) "tls_name", (char *) tls_n);
}

/* *************************************** */

void LocalHost::offlineSetHTTPName(const char *http_n) {
  Host::offlineSetHTTPName(http_n);
  addDataToAssets((char *) "http_name", (char *) http_n);
}

/* *************************************** */

void LocalHost::setServerName(const char *server_n) {
  Host::setServerName(server_n);
}

/* *************************************** */

void LocalHost::setResolvedName(const char *resolved_name) {
  char buf[64];

  if(strcmp(get_ip()->print(buf, sizeof(buf)), resolved_name)) {
    Host::setResolvedName(resolved_name);
    addDataToAssets((char *) "dns_name", (char *) resolved_name);
  }
}

/* *************************************** */

void LocalHost::setTCPfingerprint(char *_tcp_fingerprint,
				  enum operating_system_hint os) {
  if (_tcp_fingerprint && _tcp_fingerprint[0] != '\0')
    addDataToAssets((char *) "tcp_fingerprint", (char *) _tcp_fingerprint);
  if(tcp_fingerprint_host_os == os_hint_unknown) {
    /* Not yet set the host fingerprint */
    OSType os_type = Utils::OShint2OSType(os);

    if(os_type != os_unknown)
      setOS(os_type, os_learning_tcp_fingerprint);

    tcp_fingerprint_host_os = os;

    if(tcp_fingerprint == NULL)
      tcp_fingerprint = strdup(_tcp_fingerprint);

  } else if((os != os_hint_unknown) && (tcp_fingerprint_host_os != os)) {    
    char buf[64];

    ntop->getTrace()->traceEvent(TRACE_INFO, "Found OS inconsistency %s vs %s [%s][%s]",
				 ndpi_print_os_hint(tcp_fingerprint_host_os),
				 ndpi_print_os_hint(os),
				 _tcp_fingerprint ? _tcp_fingerprint : "",
				 get_ip()->print(buf, sizeof(buf)));

    inconsistent_host_os = true;
  }
}

/* *************************************** */

void LocalHost::setOS(OSType _os, OSLearningMode mode) {
  if((_os != os_unknown) && (getOS() != _os)) {
    os_learning[mode] = _os;

    char buf[8];
    snprintf(buf, sizeof(buf), "%d", _os);
    addDataToAssets((char *) "os_type", buf);
    
    Host::setOS(_os, mode);
  }
}

/* *************************************** */

/* This function is used to add a new field to the asset map;
 * this field is going to be automatically added to the json, when dumped to redis
 * Note: the function overwrite the old values if already present
 */
bool LocalHost::addDataToAssets(char *_field, char *_value) {
  if (!ntop->getPrefs()->isAssetsCollectionEnabled()) return false;

  /* Check for incorrect values */
  if (_field && _field[0] != '\0' && _value && _value[0] != '\0') {
    std::string field = _field;
    std::string value = _value;
    asset_map[field] = value;
    asset_map_updated = true; /* Next time dump data */
    return true;
  }
  return false;
}

/* *************************************** */

/* This function instead remove a field from the asset map */
bool LocalHost::removeDataFromAssets(char *field) {
  if (!ntop->getPrefs()->isAssetsCollectionEnabled()) return false;

  if (asset_map.size() > 0 && field && field[0] != '\0') {
    asset_map.erase(field);
    asset_map_updated = true; /* Next time dump data */
    return true;
  }
  return false;
}

/* *************************************** */

void LocalHost::dumpAssetJson(ndpi_serializer *serializer) {
  /* Check for the map size */
  if (asset_map.size() == 0) 
    return;

  ndpi_serialize_start_of_block(serializer, "json_info"); /* Custom fields block */
  for(std::map<std::string, std::string>::iterator it = asset_map.begin(); it != asset_map.end(); it++) {
    ndpi_serialize_string_string(serializer, it->first.c_str(), it->second.c_str());
  }
  ndpi_serialize_end_of_block(serializer);
}
