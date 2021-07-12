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

Host::Host(NetworkInterface *_iface, char *ipAddress, VLANid _vlanId, u_int16_t observation_point_id)
  : GenericHashEntry(_iface), HostAlertableEntity(_iface, alert_entity_host), Score(_iface), HostChecksStatus() {
  ip.set(ipAddress);
  initialize(NULL, _vlanId, observation_point_id);
}

/* *************************************** */

Host::Host(NetworkInterface *_iface, Mac *_mac,
	   VLANid _vlanId, u_int16_t observation_point_id, IpAddress *_ip)
  : GenericHashEntry(_iface), HostAlertableEntity(_iface, alert_entity_host), Score(_iface), HostChecksStatus() {
  ip.set(_ip);

#ifdef BROADCAST_DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting %s [broadcast: %u]",
			       ip.print(buf, sizeof(buf)), isBroadcastHost() ? 1 : 0);
#endif

  initialize(_mac, _vlanId, observation_point_id);
}

/* *************************************** */

Host::~Host() {
  if((getUses() > 0)
     /* View hosts are not in sync with viewed flows so during shutdown it can be normal */
     && (!iface->isView() || !ntop->getGlobals()->isShutdownRequested()))
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: num_uses=%u", getUses());

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleting %s (%s)", k, localHost ? "local": "remote");

  if(mac)           mac->decUses();
  if(as)            as->decUses();
  if(os)            os->decUses();
  if(country)       country->decUses();
  if(vlan)          vlan->decUses();

#ifdef NTOPNG_PRO
  if(host_traffic_shapers) {
    for(int i = 0; i < NUM_TRAFFIC_SHAPERS; i++) {
      if(host_traffic_shapers[i])
	delete host_traffic_shapers[i];
    }

    free(host_traffic_shapers);
  }

#endif

  freeHostNames();

  if(syn_flood.attacker_counter)  delete syn_flood.attacker_counter;
  if(syn_flood.victim_counter)    delete syn_flood.victim_counter;
  if(flow_flood.attacker_counter) delete flow_flood.attacker_counter;
  if(flow_flood.victim_counter)   delete flow_flood.victim_counter;

  if(stats)                     delete stats;
  if(stats_shadow)              delete stats_shadow;

  /*
    Pool counters are updated both in and outside the datapath.
    So decPoolNumHosts must stay in the destructor to preserve counters
    consistency (no thread outside the datapath will change the last pool id)
  */
  iface->decPoolNumHosts(get_host_pool(), false /* Host is deleted offline */);
}

/* *************************************** */

/* NOTE: overrides Score::incScoreValue to handle increments for host members as well */
u_int16_t Host::incScoreValue(u_int16_t score_incr, ScoreCategory score_category, bool as_client) {
  NetworkStats *ns = getNetworkStats(get_local_network_id());
  u_int16_t score_inc;

  /* Do increments only on members that don't change during the lifecycle of the host */
  if(as)      as->incScoreValue(score_incr, score_category, as_client);
  if(vlan)    vlan->incScoreValue(score_incr, score_category, as_client);
  if(country) country->incScoreValue(score_incr, score_category, as_client);
  if(ns)      ns->incScoreValue(score_incr, score_category, as_client);
  if(iface)   iface->incScoreValue(score_incr, as_client);
  score_inc = Score::incScoreValue(score_incr, score_category, as_client);

  return score_inc;
}

/* *************************************** */

/* NOTE: overrides Score::decScoreValue to handle increments for host members as well */
u_int16_t Host::decScoreValue(u_int16_t score_decr, ScoreCategory score_category, bool as_client) {
  NetworkStats *ns = getNetworkStats(get_local_network_id());

  /* Keep decements in sync with Host::incScoreValue */
  if(as)      as->decScoreValue(score_decr, score_category, as_client);
  if(vlan)    vlan->decScoreValue(score_decr, score_category, as_client);
  if(country) country->decScoreValue(score_decr, score_category, as_client);
  if(ns)      ns->decScoreValue(score_decr, score_category, as_client);
  if(iface)   iface->decScoreValue(score_decr, as_client);
  
  return Score::decScoreValue(score_decr, score_category, as_client);
}


/* *************************************** */

void Host::updateSynAlertsCounter(time_t when, bool syn_sent) {
  AlertCounter *counter = syn_sent ? syn_flood.attacker_counter : syn_flood.victim_counter;

  counter->inc(when, this);

  if(syn_sent)
    syn_scan.syn_sent_last_min++;
  else
    syn_scan.syn_recvd_last_min++;
}

/* *************************************** */

void Host::updateSynAckAlertsCounter(time_t when, bool synack_sent) {
  if(synack_sent)
    syn_scan.synack_sent_last_min++;
  else
    syn_scan.synack_recvd_last_min++;
}

/* *************************************** */

/*
  This method is executed in the thread which processes packets/flows
  so it must be ultra-fast. Do NOT perform any time-consuming operation here.
 */
void Host::housekeep(time_t t) {  
  switch(get_state()) {
  case hash_entry_state_active:
    iface->execHostChecks(this);
    break;
  case hash_entry_state_idle:
    releaseAllEngagedAlerts();
    break;
  default:
    break;
  }
}

/* *************************************** */

void Host::initialize(Mac *_mac, VLANid _vlanId, u_int16_t observation_point_id) {
  char buf[64];
  u_int16_t masked_vlanId = filterVLANid(_vlanId); /* Cleanup any possible junk */
  
  stats = NULL; /* it will be instantiated by specialized classes */
  stats_shadow = NULL;
  data_delete_requested = false, stats_reset_requested = false, name_reset_requested = false;
  last_stats_reset = ntop->getLastStatsReset(); /* assume fresh stats, may be changed by deserialize */
  os = NULL, os_type = os_unknown;
  prefs_loaded = false;
  host_services_bitmap = 0;
  disabled_alerts_tstamp = 0;
  num_remote_access = 0;

  // readStats(); - Commented as if put here it's too early and the key is not yet set

#ifdef NTOPNG_PRO
  host_traffic_shapers = NULL;
  has_blocking_quota = has_blocking_shaper = false;
#endif

  if((mac = _mac))
    mac->incUses();

  observationPointId = observation_point_id;
  
  if((vlan = iface->getVLAN(masked_vlanId, true, true /* Inline call */)) != NULL)
    vlan->incUses();

  num_resolve_attempts = 0, ssdpLocation = NULL;
  num_active_flows_as_client = num_active_flows_as_server = 0;
  active_alerted_flows = 0;

  nextResolveAttempt = 0;
  vlan_id = _vlanId;
  memset(&names, 0, sizeof(names));
  asn = 0, asname = NULL;
  as = NULL, country = NULL;
  os = NULL, os_type = os_unknown;
  reloadHostBlacklist();
  is_dhcp_host = false;
  is_in_broadcast_domain = false;

  PROFILING_SUB_SECTION_ENTER(iface, "Host::initialize: new AlertCounter", 17);
  syn_flood.attacker_counter  = new (std::nothrow) AlertCounter();
  syn_flood.victim_counter    = new (std::nothrow) AlertCounter();
  flow_flood.attacker_counter = new (std::nothrow) AlertCounter();
  flow_flood.victim_counter   = new (std::nothrow) AlertCounter();
  syn_scan.syn_sent_last_min = syn_scan.synack_recvd_last_min = 0;
  syn_scan.syn_recvd_last_min = syn_scan.synack_sent_last_min = 0;
  PROFILING_SUB_SECTION_EXIT(iface, 17);

  if(ip.getVersion() /* IP is set */) {
    char country_name[64];
    
    if((as = iface->getAS(&ip, true /* Create if missing */, true /* Inline call */)) != NULL) {
      as->incUses();
      asn = as->get_asn();
      asname = as->get_asname();
    }

    get_country(country_name, sizeof(country_name));

    if((country = iface->getCountry(country_name, true /* Create if missing */, true /* Inline call */ )) != NULL)
      country->incUses();
  }

  inlineSetOS(os_unknown);

  reloadHideFromTop();
  reloadDhcpHost();
  setEntityValue(get_hostkey(buf, sizeof(buf), true));

  is_in_broadcast_domain = iface->isLocalBroadcastDomainHost(this, true /* Inline call */);

  memset(&num_blacklisted_flows, 0, sizeof(num_blacklisted_flows));
}

/* *************************************** */

char* Host::get_hostkey(char *buf, u_int buf_len, bool force_vlan) {
  char ipbuf[64];
  char *key = ip.print(ipbuf, sizeof(ipbuf));
  
  if((vlan_id > 0) || force_vlan) {
    char obsBuf[16] = { '\0' };

    /*
      Uncomment to add observationPointId in the host name
      
      if(observationPointId == 0)
        obsBuf[0] = '\0';
      else
        snprintf(obsBuf, sizeof(obsBuf), " (%u)", observationPointId);
    */
    
    if(get_vlan_id())
      snprintf(buf, buf_len, "%s@%u%s", key, get_vlan_id(), obsBuf);
    else
      snprintf(buf, buf_len, "%s%s", key, obsBuf);
  } else
    strncpy(buf, key, buf_len);

  buf[buf_len-1] = '\0';
  return buf;
}

/* *************************************** */

void Host::updateHostPool(bool isInlineCall, bool firstUpdate) {
  if(!iface)
    return;

  if(!firstUpdate) iface->decPoolNumHosts(get_host_pool(), isInlineCall);
  host_pool_id = iface->getHostPool(this);
  iface->incPoolNumHosts(get_host_pool(), isInlineCall);

#ifdef NTOPNG_PRO
  if(iface && iface->is_bridge_interface()) {
    HostPools *hp = iface->getHostPools();

    if(hp && hp->enforceQuotasPerPoolMember(get_host_pool())) {
      /* must allocate a structure to keep track of used quotas */
      if(stats) stats->allocateQuotaEnforcementStats();
    } else { /* Free the structure that is no longer needed */
      /* It is ensured by the caller that this method is called no more than 1 time per second.
      Therefore, it is safe to delete a previously allocated shadow class */
      if(stats) stats->deleteQuotaEnforcementStats();
    }

    if(hp && hp->enforceShapersPerPoolMember(get_host_pool())) {
      /* Align with global traffic shapers */
      iface->getL7Policer()->cloneShapers(&host_traffic_shapers);

#ifdef HOST_POOLS_DEBUG
      char buf[128];
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Cloned shapers for %s [host pool: %i]",
				   ip.print(buf, sizeof(buf)), host_pool_id);
#endif

    }
  }
#endif /* NTOPNG_PRO */

#ifdef HOST_POOLS_DEBUG
  char buf[128];
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Updating host pool for %s [host pool: %i]",
			       ip.print(buf, sizeof(buf)), host_pool_id);
#endif
}

/* *************************************** */

void Host::set_mac(Mac *_mac) {
  if((mac != _mac) && (_mac != NULL)) {
    if(mac) mac->decUses();
    mac = _mac;
    mac->incUses();
  }
}

/* *************************************** */

bool Host::hasAnomalies() const {
  time_t now = time(0);

  return (stats ? stats->hasAnomalies(now) : false);
}

/* *************************************** */

void Host::lua_get_anomalies(lua_State* vm) const {
  if(!vm)
    return;

  if(hasAnomalies()) {
    time_t now = time(0);

    lua_newtable(vm);

    stats->luaAnomalies(vm, now);

    lua_pushstring(vm, "anomalies");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void Host::luaStrTableEntryLocked(lua_State * const vm, const char * const entry_name, const char * const entry_value) {
  /* Perform access to const entry values using a lock as entry value can change for example during a data reset */
  if(entry_name) {
    m.lock(__FILE__, __LINE__);

    if(entry_value)
      lua_push_str_table_entry(vm, entry_name, entry_value);

    m.unlock(__FILE__, __LINE__);
  }
}

/* *************************************** */

void Host::lua_get_names(lua_State * const vm, char * const buf, ssize_t buf_size) {
  Mac * cur_mac = getMac();

  lua_newtable(vm);

  getMDNSName(buf, buf_size);
  if(buf[0]) lua_push_str_table_entry(vm, "mdns", buf);

  getMDNSTXTName(buf, buf_size);
  if(buf[0]) lua_push_str_table_entry(vm, "mdns_txt", buf);

  getResolvedName(buf, buf_size);
  if(buf[0]) lua_push_str_table_entry(vm, "resolved", buf);

  getNetbiosName(buf, buf_size);
  if(buf[0]) lua_push_str_table_entry(vm, "netbios", buf);

  if(isBroadcastDomainHost() && cur_mac) {
    cur_mac->getDHCPName(buf, buf_size);
    if(buf[0]) lua_push_str_table_entry(vm, "dhcp", buf);
  }

  lua_pushstring(vm, "names");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ***************************************************** */

void Host::lua_get_ip(lua_State *vm) const {
  char ip_buf[64];

  lua_push_str_table_entry(vm, "ip", ip.print(ip_buf, sizeof(ip_buf)));
  lua_push_uint32_table_entry(vm, "vlan", get_vlan_id());
  lua_push_uint32_table_entry(vm, "observation_point_id", get_observation_point_id());
}

/* ***************************************************** */

void Host::lua_get_localhost_info(lua_State *vm) const {
  lua_pushboolean(vm, isLocalHost());
}

/* ***************************************************** */

void Host::lua_get_mac(lua_State *vm) const {
  char buf[64];
  /* Cache macs as they can be swapped/updated */
  Mac *cur_mac = getMac();

  lua_push_str_table_entry(vm, "mac", Utils::formatMac(cur_mac ? cur_mac->get_mac() : NULL, buf, sizeof(buf)));
  lua_push_uint64_table_entry(vm, "devtype", getDeviceType());
}

/* ***************************************************** */

void Host::lua_get_bytes(lua_State *vm) const {
  lua_push_uint64_table_entry(vm, "bytes.sent", getNumBytesSent());
  lua_push_uint64_table_entry(vm, "bytes.rcvd", getNumBytesRcvd());
}

/* ***************************************************** */

void Host::lua_get_app_bytes(lua_State *vm, u_int app_id) const {
  lua_pushinteger(vm, get_ndpi_stats()->getProtoBytes(app_id));
}

/* ***************************************************** */

void Host::lua_get_cat_bytes(lua_State *vm, ndpi_protocol_category_t category_id) const {
  lua_pushinteger(vm, get_ndpi_stats()->getCategoryBytes(category_id));
}

/* ***************************************************** */

void Host::lua_get_packets(lua_State *vm) const {
  lua_push_uint64_table_entry(vm, "packets.sent", getNumPktsSent());
  lua_push_uint64_table_entry(vm, "packets.rcvd", getNumPktsRcvd());
}

/* ***************************************************** */

void Host::lua_get_as(lua_State *vm) const {
  const char *asn_n = get_asname();

  lua_push_uint64_table_entry(vm, "asn", get_asn());
  lua_push_str_table_entry(vm, "asname", asn_n ? asn_n : (char*)"");
}

/* ***************************************************** */

void Host::lua_get_host_pool(lua_State *vm) const {
  lua_push_uint64_table_entry(vm, "host_pool_id", get_host_pool());
}
/* ***************************************************** */

void Host::lua_get_os(lua_State *vm) {
  char buf[64];

  lua_push_int32_table_entry(vm, "os", getOS());
  lua_push_str_table_entry(vm, "os_detail", getOSDetail(buf, sizeof(buf)));
}

/* ***************************************************** */

void Host::lua_get_ndpi_info(lua_State *vm) {
  if(stats)
    stats->luaNdpiStats(vm);
  else
    lua_pushnil(vm);
}
  
/* ***************************************************** */

void Host::lua_get_min_info(lua_State *vm) {
  char buf[64];

  lua_push_str_table_entry(vm, "name", get_visual_name(buf, sizeof(buf)));
  lua_push_bool_table_entry(vm, "localhost", isLocalHost());
  lua_push_bool_table_entry(vm, "systemhost", isSystemHost());
  lua_push_bool_table_entry(vm, "privatehost", isPrivateHost());
  lua_push_bool_table_entry(vm, "broadcast_domain_host", isBroadcastDomainHost());
  lua_push_bool_table_entry(vm, "dhcpHost", isDhcpHost());
  lua_push_bool_table_entry(vm, "is_blacklisted", isBlacklisted());
  lua_push_bool_table_entry(vm, "is_broadcast", isBroadcastHost());
  lua_push_bool_table_entry(vm, "is_multicast", isMulticastHost());
  lua_push_int32_table_entry(vm, "host_services_bitmap", host_services_bitmap);
  lua_get_geoloc(vm);
  
#ifdef HAVE_NEDGE
  lua_push_bool_table_entry(vm, "childSafe", isChildSafe());
  lua_push_bool_table_entry(vm, "has_blocking_quota", has_blocking_quota);
  lua_push_bool_table_entry(vm, "has_blocking_shaper", has_blocking_shaper);
  lua_push_bool_table_entry(vm, "drop_all_host_traffic", dropAllTraffic());
#endif
}

/* ***************************************************** */

void Host::lua_get_geoloc(lua_State *vm) {
  char *continent = NULL, *country_name = NULL, *city = NULL;
  float latitude = 0, longitude = 0;

  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city, &latitude, &longitude);
  lua_push_str_table_entry(vm,   "continent", continent ? continent : (char*)"");
  lua_push_str_table_entry(vm,   "country", country_name ? country_name  : (char*)"");
  lua_push_float_table_entry(vm, "latitude", latitude);
  lua_push_float_table_entry(vm, "longitude", longitude);
  lua_push_str_table_entry(vm,   "city", city ? city : (char*)"");
  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);
}

/* ***************************************************** */

void Host::lua_get_syn_flood(lua_State *vm) const {
  u_int16_t hits;

  if((hits = syn_flood.victim_counter->hits()))
    lua_push_uint64_table_entry(vm, "hits.syn_flood_victim", hits);
  if((hits = syn_flood.attacker_counter->hits()))
    lua_push_uint64_table_entry(vm, "hits.syn_flood_attacker", hits);
}

/* ***************************************************** */

void Host::lua_get_flow_flood(lua_State *vm) const {
  u_int16_t hits;

  if((hits = flow_flood.victim_counter->hits()))
    lua_push_uint64_table_entry(vm, "hits.flow_flood_victim", hits);
  if((hits = flow_flood.attacker_counter->hits()))
    lua_push_uint64_table_entry(vm, "hits.flow_flood_attacker", hits);
}

/* ***************************************************** */

void Host::lua_get_services(lua_State *vm) const {
  if(host_services_bitmap == 0) return;

  lua_newtable(vm);

  if(isDhcpServer()) lua_push_bool_table_entry(vm, "dhcp", true);
  if(isDnsServer()) lua_push_bool_table_entry(vm,  "dns",  true);
  if(isSmtpServer()) lua_push_bool_table_entry(vm, "smtp", true);
  if(isNtpServer()) lua_push_bool_table_entry(vm,  "ntp",  true);
  
  lua_pushstring(vm, "services");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ***************************************************** */

void Host::lua_get_syn_scan(lua_State *vm) const {
  u_int32_t hits;

  hits = 0;
  if(syn_scan.syn_sent_last_min > syn_scan.synack_recvd_last_min)
    hits = syn_scan.syn_sent_last_min - syn_scan.synack_recvd_last_min;
  if(hits)
    lua_push_uint64_table_entry(vm, "hits.syn_scan_attacker", hits);

  hits = 0;
  if(syn_scan.syn_recvd_last_min > syn_scan.synack_sent_last_min)
    hits = syn_scan.syn_recvd_last_min - syn_scan.synack_sent_last_min;
  if(hits)
    lua_push_uint64_table_entry(vm, "hits.syn_scan_victim", hits);
}

/* ***************************************************** */

void Host::lua_get_time(lua_State* vm) const {
  lua_push_uint64_table_entry(vm, "seen.first", get_first_seen());
  lua_push_uint64_table_entry(vm, "seen.last", get_last_seen());
  lua_push_uint64_table_entry(vm, "duration", get_duration());

  if(stats)
    lua_push_uint64_table_entry(vm, "total_activity_time", stats->getTotalActivityTime());
}

/* ***************************************************** */

void Host::lua_get_num_alerts(lua_State* vm) const {
  lua_push_uint64_table_entry(vm, "num_alerts", getNumEngagedAlerts());
  lua_push_uint64_table_entry(vm, "active_alerted_flows", getNumAlertedFlows());

  if(stats)
    lua_push_uint64_table_entry(vm, "total_alerts", stats->getTotalAlerts());
}

/* ***************************************************** */

void Host::lua_get_num_total_flows(lua_State* vm) const {
  lua_push_uint64_table_entry(vm, "total_flows.as_client", getTotalNumFlowsAsClient());
  lua_push_uint64_table_entry(vm, "total_flows.as_server", getTotalNumFlowsAsServer());
}

/* ***************************************************** */

void Host::lua_get_num_flows(lua_State* vm) const {
  lua_push_uint64_table_entry(vm, "active_flows.as_client", getNumOutgoingFlows());
  lua_push_uint64_table_entry(vm, "active_flows.as_server", getNumIncomingFlows());
  lua_push_uint64_table_entry(vm, "alerted_flows.as_server", getTotalNumAlertedIncomingFlows());
  lua_push_uint64_table_entry(vm, "alerted_flows.as_client", getTotalNumAlertedOutgoingFlows());
  lua_push_uint64_table_entry(vm, "unreachable_flows.as_server", getTotalNumUnreachableIncomingFlows());
  lua_push_uint64_table_entry(vm, "unreachable_flows.as_client", getTotalNumUnreachableOutgoingFlows());
  lua_push_uint64_table_entry(vm, "host_unreachable_flows.as_server", getTotalNumHostUnreachableIncomingFlows());
  lua_push_uint64_table_entry(vm, "host_unreachable_flows.as_client", getTotalNumHostUnreachableOutgoingFlows());

  lua_blacklisted_flows(vm);
  
  if(stats)
    stats->luaHostBehaviour(vm); 
}

/* ***************************************************** */

void Host::lua_get_num_contacts(lua_State* vm) {
  lua_push_uint64_table_entry(vm, "contacts.as_client", getNumActiveContactsAsClient());
  lua_push_uint64_table_entry(vm, "contacts.as_server", getNumActiveContactsAsServer());
}

/* ***************************************************** */

void Host::lua_get_num_http_hosts(lua_State* vm) {
  lua_push_uint64_table_entry(vm, "active_http_hosts", getActiveHTTPHosts());
}

/* ***************************************************** */

void Host::lua_get_fingerprints(lua_State* vm) {
  fingerprints.ja3.lua("ja3_fingerprint", vm);
  fingerprints.hassh.lua("hassh_fingerprint", vm);
}

/* ***************************************************** */

void Host::lua_blacklisted_flows(lua_State* vm) const {
  /* Flow exchanged with blacklists hosts */
  lua_newtable(vm);

  /* Considering the datas from the last reset */
  lua_push_uint32_table_entry(vm, "as_client", getNumBlacklistedAsCliReset());
  lua_push_uint32_table_entry(vm, "as_server", getNumBlacklistedAsSrvReset());
  /* All data, without considering the reset. This is done for rrd. */
  lua_push_uint32_table_entry(vm, "tot_as_client", num_blacklisted_flows.as_client);
  lua_push_uint32_table_entry(vm, "tot_as_server", num_blacklisted_flows.as_server); 
  
  lua_pushstring(vm, "num_blacklisted_flows");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ***************************************************** */

void Host::lua(lua_State* vm, AddressTree *ptree,
	       bool host_details, bool verbose,
	       bool returnHost, bool asListElement) {
  char buf[64], buf_id[64], *host_id = buf_id;
  char ip_buf[64], *ipaddr = NULL;
  bool mask_host = Utils::maskHost(isLocalHost());

  if((ptree && (!match(ptree))) || mask_host)
    return;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "ip", (ipaddr = printMask(ip_buf, sizeof(ip_buf))));
  lua_push_uint32_table_entry(vm, "vlan", get_vlan_id());
  lua_push_uint32_table_entry(vm, "observation_point_id", get_observation_point_id());

  lua_push_bool_table_entry(vm, "hiddenFromTop", isHiddenFromTop());

  lua_push_uint64_table_entry(vm, "ipkey", ip.key());
  lua_push_str_table_entry(vm, "tskey", get_tskey(buf_id, sizeof(buf_id)));

  lua_push_str_table_entry(vm, "name", get_visual_name(buf, sizeof(buf)));

  lua_get_min_info(vm);
  lua_get_mac(vm);

  lua_get_num_alerts(vm);
  lua_get_score(vm);

  lua_get_as(vm);
  lua_get_os(vm);
  lua_get_host_pool(vm);

  if(stats)
    stats->lua(vm, mask_host, Utils::bool2DetailsLevel(verbose, host_details)),
      stats->luaHostBehaviour(vm);

  lua_get_num_flows(vm);
  lua_get_num_contacts(vm);
  lua_get_num_http_hosts(vm);

  lua_push_float_table_entry(vm, "bytes_ratio", ndpi_data_ratio(getNumBytesSent(), getNumBytesRcvd()));
  lua_push_float_table_entry(vm, "pkts_ratio", ndpi_data_ratio(getNumPktsSent(), getNumPktsRcvd()));
  
  luaDNS(vm, verbose);
  luaTCP(vm);
  luaICMP(vm, get_ip()->isIPv4(), false);
 
  if(host_details) {
    lua_get_score_breakdown(vm);
    lua_blacklisted_flows(vm);
    
    /*
      This has been disabled as in case of an attack, most hosts do not have a name and we will waste
      a lot of time doing activities that are not necessary
    */
    get_name(buf, sizeof(buf), false);
    if(strlen(buf) == 0 || strcmp(buf, ipaddr) == 0) {
      /* We resolve immediately the IP address by queueing on the top of address queue */
      ntop->getRedis()->pushHostToResolve(ipaddr, false, true /* Fake to resolve it ASAP */);
    }

    luaStrTableEntryLocked(vm, "ssdp", ssdpLocation); /* locked to protect against data-reset changes */

    /* ifid is useful for example for view interfaces to detemine
       the actual, original interface the host is associated to. */
    lua_push_uint64_table_entry(vm, "ifid", iface->get_id());
    if(!mask_host)
      luaStrTableEntryLocked(vm, "info", names.mdns_info); /* locked to protect against data-reset changes */

    lua_get_names(vm, buf, sizeof(buf));

    lua_get_geoloc(vm);

    lua_get_flow_flood(vm);
    lua_get_services(vm);
  }

  lua_get_time(vm);

  lua_get_fingerprints(vm);

  if(verbose) {
    if(hasAnomalies()) lua_get_anomalies(vm);
  }

  if(!returnHost)
    host_id = get_hostkey(buf_id, sizeof(buf_id));

  if(asListElement) {
    lua_pushstring(vm, host_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ***************************************** */

char* Host::get_name(char *buf, u_int buf_len, bool force_resolution_if_not_found) {
  char *addr = NULL, name_buf[96];
  int rc = -1;
  time_t now = time(NULL);
  bool skip_resolution = false;

  if(nextResolveAttempt
     && ((num_resolve_attempts > 1) || (nextResolveAttempt > now) || (nextResolveAttempt == (time_t)-1))) {
    skip_resolution = true;
  } else
    nextResolveAttempt = ntop->getPrefs()->is_dns_resolution_enabled() ? now + MIN_HOST_RESOLUTION_FREQUENCY : (time_t)-1;

  num_resolve_attempts++;

  getResolvedName(name_buf, sizeof(name_buf));
  if(name_buf[0])
    goto out;

  /* Most relevant names goes first */
  if(isBroadcastDomainHost()) {
    Mac *cur_mac = getMac(); /* Cache it as it can change */

    if(cur_mac) {
      cur_mac->getDHCPName(name_buf, sizeof(name_buf));
      if(strlen(name_buf))
        goto out;
    }
  }

  getMDNSTXTName(name_buf, sizeof(name_buf));
  if(name_buf[0])
    goto out;

  getMDNSName(name_buf, sizeof(name_buf));
  if(name_buf[0])
    goto out;

  getMDNSInfo(name_buf, sizeof(name_buf));
  if(name_buf[0])
    goto out;

  getNetbiosName(name_buf, sizeof(name_buf));
  if(name_buf[0])
    goto out;

  if(!skip_resolution) {
    addr = ip.print(buf, buf_len);
    rc = ntop->getRedis()->getAddress(addr, name_buf, sizeof(name_buf),
				      force_resolution_if_not_found);
  }

  if(rc == 0 && strcmp(addr, name_buf)) {
    char c;
    int i = 0;
    while(name_buf[i]) {
      c=name_buf[i];
      name_buf[i] = tolower(c);
      i++;
    }
    setResolvedName(name_buf);
  }
  else
    addr = ip.print(name_buf, sizeof(name_buf));

 out:
  snprintf(buf, buf_len, "%s", name_buf);
  return(buf);
}

/* ***************************************** */

/* Retrieve the host label. This should only be used to store persistent
 * information from C. In lua use hostinfo2label instead. */
char * Host::get_host_label(char * const buf, ssize_t buf_len) {
  char redis_key[CONST_MAX_LEN_REDIS_KEY];
  char ip_buf[64];

  /* Try to get a label first */
  snprintf(redis_key, sizeof(redis_key), HOST_LABEL_NAMES_KEY, ip.print(ip_buf, sizeof(ip_buf)));
  if(ntop->getRedis()->get(redis_key, buf, buf_len) != 0) {

    /* Not found, use the internal names instead */
    get_name(buf, buf_len, false /* don't resolve */);
  }

  return buf;
}

/* ***************************************** */

char * Host::getResolvedName(char * const buf, ssize_t buf_len) {
  if(buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.resolved ? names.resolved : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* ***************************************** */

char * Host::getMDNSName(char * const buf, ssize_t buf_len) {
  if(buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.mdns ? names.mdns : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}


/* ***************************************** */

char * Host::getMDNSTXTName(char * const buf, ssize_t buf_len) {
  if(buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.mdns_txt ? names.mdns_txt : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* ***************************************** */

char * Host::getMDNSInfo(char * const buf, ssize_t buf_len) {
  if(buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.mdns_info ? names.mdns_info : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* ***************************************** */

char * Host::getNetbiosName(char * const buf, ssize_t buf_len) {
  if(buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.netbios ? names.netbios : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* ***************************************** */

const char * Host::getOSDetail(char * const buf, ssize_t buf_len) {
  if(buf && buf_len)
    buf[0] = '\0';

  return buf;
}

/* ***************************************** */

bool Host::is_hash_entry_state_idle_transition_ready() {
  u_int32_t max_idle;

  /*
    Idle transition should only be allowed if host has NO alerts engaged.
    This is to always keep in-memory hosts with ongoing issues.

    - For hosts that actively generate traffic, this is achieved automatically (active hosts
      stay in memory).
    - For hosts that stop generating traffic, this is NOT achieved automatically (inactive hosts
      become candidates for purging).

    However, it is not desirable to keep inactive hosts in memory for an unlimited amount of time,
    even if they have ongoing inssues, as this could cause OOMs or make ntopng vulnerable to certain attacks.

    For this reason, when an host has ongoing issues, a different (larger) maximum idleness is used to:
    - Keep it in memory for a longer time
    - Avoid keeping inactive hosts in memory for an indefinite time
  */

  if(getNumEngagedAlerts() > 0)
    max_idle = ntop->getPrefs()->get_alerted_host_max_idle();
  else
    max_idle = ntop->getPrefs()->get_host_max_idle(isLocalHost());

  bool res = (getUses() == 0)
    && is_active_entry_now_idle(max_idle);

#if DEBUG_HOST_IDLE_TRANSITION
  char buf[64];
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Idle check [%s][local: %u][get_host_max_idle: %u][last seen: %u][ready: %u]",
			       ip.print(buf, sizeof(buf)), isLocalHost(), ntop->getPrefs()->get_host_max_idle(isLocalHost()), last_seen, res ? 1 : 0);
#endif

  return res;
};

/* *************************************** */

void Host::periodic_stats_update(const struct timeval *tv) {
  Mac *cur_mac = getMac();
  OSType cur_os_type = os_type, cur_os_from_fingerprint = os_unknown;

  checkReloadPrefs();
  checkNameReset();
  checkDataReset();
  checkStatsReset();
  checkBroadcastDomain();

  /* Update the pointer to the operating system according to what is specified in cur_os_type, if necessary */
  if(!os
     || os->get_os_type() != cur_os_type)
    inlineSetOS(cur_os_type);

  /*
    Update  the operating system, according to what comes from the fingerprint, if necessary.
    The actual pointer will be update above during the next call
   */
  if(cur_os_type == os_unknown
     && cur_mac
     && cur_mac->getFingerprint()
     && (cur_os_from_fingerprint = Utils::getOSFromFingerprint(cur_mac->getFingerprint(), cur_mac->get_manufacturer(), cur_mac->getDeviceType())) != cur_os_type)
    setOS(cur_os_from_fingerprint);

  if(stats)
    stats->updateStats(tv);

  GenericHashEntry::periodic_stats_update(tv);

  custom_periodic_stats_update(tv);
}

/* *************************************** */

void Host::incStats(u_int32_t when, u_int8_t l4_proto,
		    u_int ndpi_proto, ndpi_protocol_category_t ndpi_category,
		    custom_app_t custom_app,
		    u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		    u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes,
		    bool peer_is_unicast) {
  if(sent_bytes || rcvd_bytes) {
    if(stats)
      stats->incStats(when, l4_proto, ndpi_proto, ndpi_category, custom_app,
		      sent_packets, sent_bytes, sent_goodput_bytes, rcvd_packets,
		      rcvd_bytes, rcvd_goodput_bytes, peer_is_unicast);
    
    updateSeen();
  }
}

/* *************************************** */

void Host::serialize(json_object *my_object, DetailsLevel details_level) {
  char buf[96];
  Mac *m = mac;

  if(stats)
    stats->getJSONObject(my_object, details_level);

  json_object_object_add(my_object, "ip", ip.getJSONObject());
  if(vlan_id != 0)        json_object_object_add(my_object, "vlan_id",   json_object_new_int(vlan_id));
  json_object_object_add(my_object, "mac_address", json_object_new_string(Utils::formatMac(m ? m->get_mac() : NULL, buf, sizeof(buf))));
  json_object_object_add(my_object, "ifid", json_object_new_int(iface->get_id()));

  if(details_level >= details_high) {
    GenericHashEntry::getJSONObject(my_object, details_level);
    json_object_object_add(my_object, "last_stats_reset", json_object_new_int64(last_stats_reset));
    json_object_object_add(my_object, "asn", json_object_new_int(asn));

    get_name(buf, sizeof(buf), false);
    if(strlen(buf)) json_object_object_add(my_object, "symbolic_name", json_object_new_string(buf));
    if(asname)      json_object_object_add(my_object, "asname",    json_object_new_string(asname ? asname : (char*)""));

    json_object_object_add(my_object, "localHost", json_object_new_boolean(isLocalHost()));
    json_object_object_add(my_object, "systemHost", json_object_new_boolean(isSystemHost()));
    json_object_object_add(my_object, "broadcastDomainHost", json_object_new_boolean(isBroadcastDomainHost()));
    json_object_object_add(my_object, "is_blacklisted", json_object_new_boolean(isBlacklisted()));
    json_object_object_add(my_object, "host_services_bitmap", json_object_new_int(host_services_bitmap));
    
    /* Generic Host */
    json_object_object_add(my_object, "num_alerts", json_object_new_int(getNumEngagedAlerts()));
  }

  /* The value below is handled by reading dumps on disk as otherwise the string will be too long */
  //json_object_object_add(my_object, "activityStats", activityStats.getJSONObject());
}

/* *************************************** */

char* Host::get_visual_name(char *buf, u_int buf_len) {
  bool mask_host = Utils::maskHost(isLocalHost());
  char buf2[64];
  char ipbuf[64];
  char *sym_name;

  if(!mask_host) {
    sym_name = get_name(buf2, sizeof(buf2), false);

    if(sym_name && sym_name[0]) {
      if(ip.isIPv6() && strcmp(ip.print(ipbuf, sizeof(ipbuf)), sym_name)) {
	snprintf(buf, buf_len, "%s [IPv6]", sym_name);
      } else {
	strncpy(buf, sym_name, buf_len);
	buf[buf_len-1] = '\0';
      }
    } else
      buf[0] = '\0';
  } else
    buf[0] = '\0';

  return buf;
}

/* *************************************** */

bool Host::addIfMatching(lua_State* vm, AddressTree *ptree, char *key) {
  char keybuf[64] = { 0 }, *keybuf_ptr;
  char ipbuf[64] = { 0 }, *ipbuf_ptr;
  Mac *m = mac; /* Need to cache them as they can be swapped/updated */

  if(!match(ptree)) return(false);
  keybuf_ptr = get_hostkey(keybuf, sizeof(keybuf));

  if(strcasestr((ipbuf_ptr = Utils::formatMac(m ? m->get_mac() : NULL, ipbuf, sizeof(ipbuf))), key) /* Match by MAC */
     || strcasestr((ipbuf_ptr = keybuf_ptr), key)                                                  /* Match by hostkey */
     || strcasestr((ipbuf_ptr = get_visual_name(ipbuf, sizeof(ipbuf))), key)) {                    /* Match by name */
    lua_push_str_table_entry(vm, keybuf_ptr, ipbuf_ptr);
    return(true);
  }

  return(false);
}

/* *************************************** */

bool Host::addIfMatching(lua_State* vm, u_int8_t *_mac) {
  if(mac && mac->equal(_mac)) {
    char keybuf[64], ipbuf[32];

    lua_push_str_table_entry(vm,
			     get_string_key(ipbuf, sizeof(ipbuf)),
			     get_hostkey(keybuf, sizeof(keybuf)));
    return(true);
  }

  return(false);
}

/* *************************************** */

void Host::incNumFlows(time_t t, bool as_client) {
  AlertCounter *counter;

  if(as_client) {
    counter = flow_flood.attacker_counter;
    num_active_flows_as_client++;
  } else {
    counter = flow_flood.victim_counter;
    num_active_flows_as_server++;
  }

  counter->inc(t, this);
  if(stats)
    stats->incNumFlows(as_client);
}

/* *************************************** */

void Host::decNumFlows(time_t t, bool as_client) {
  if(as_client)
    num_active_flows_as_client--;
  else
    num_active_flows_as_server--;
}

/* *************************************** */

// TODO NTOPNG_PRO -> HAVE_NEDGE
#ifdef NTOPNG_PRO

TrafficShaper* Host::get_shaper(ndpi_protocol ndpiProtocol, bool isIngress) {
  HostPools *hp;
  TrafficShaper *ts = NULL, **shapers = NULL;
  u_int8_t shaper_id = DEFAULT_SHAPER_ID;
  L7Policer *policer;
  L7PolicySource_t policy_source;

  if(!(policer = iface->getL7Policer())) return NULL;
  if(!(hp = iface->getHostPools())) return policer->getShaper(PASS_ALL_SHAPER_ID);

  // Avoid setting drop verdicts for wan hosts policy
  if(getMac() && (getMac()->locate() != located_on_lan_interface)) {
    return policer->getShaper(DEFAULT_SHAPER_ID);
  }

  shaper_id = policer->getShaperIdForPool(get_host_pool(), ndpiProtocol, isIngress, &policy_source);

#ifdef SHAPER_DEBUG
  {
    char buf[64], buf1[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] [%s@%u][ndpiProtocol=%d/%s] => [shaper_id=%d]",
				 isIngress ? "INGRESS" : "EGRESS",
				 ip.print(buf, sizeof(buf)), vlan_id,
				 ndpiProtocol.app_protocol,
				 ndpi_protocol2name(iface->get_ndpi_struct(), ndpiProtocol, buf1, sizeof(buf1)),
				 shaper_id);
  }
#endif

  if(hp->enforceShapersPerPoolMember(get_host_pool())
     && (shapers = host_traffic_shapers)
     && shaper_id >= 0 && shaper_id < NUM_TRAFFIC_SHAPERS) {
    ts = shapers[shaper_id];

#ifdef SHAPER_DEBUG
    char buf[64], bufs[64];
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s@%u] PER-HOST Traffic shaper: %s",
				 ip.print(buf, sizeof(buf)), vlan_id,
				 ts->print(bufs, sizeof(bufs)));
#endif

  } else {
    ts = policer->getShaper(shaper_id);

#ifdef SHAPER_DEBUG
    char buf[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s@%u] SHARED Traffic Shaper",
				 ip.print(buf, sizeof(buf)), vlan_id);
#endif

  }

  /* Update blocking status */
  if(ts && ts->shaping_enabled() && ts->get_max_rate_kbit_sec() == 0)
    has_blocking_shaper = true;
  else
    has_blocking_shaper = false;

  return ts;
}

/* *************************************** */

bool Host::checkQuota(ndpi_protocol ndpiProtocol, L7PolicySource_t *quota_source, const struct tm *now) {
  bool is_above;
  L7Policer *policer;

  if((policer = iface->getL7Policer()) == NULL)
    return false;

  if(stats)
    is_above = policer->checkQuota(get_host_pool(), stats->getQuotaEnforcementStats(), ndpiProtocol, quota_source, now);
  else
    is_above = false;
  
#ifdef SHAPER_DEBUG
  char buf[128], protobuf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[QUOTA (%s)] [%s@%u] => %s %s",
       ndpi_protocol2name(iface->get_ndpi_struct(), ndpiProtocol, protobuf, sizeof(protobuf)),
       ip.print(buf, sizeof(buf)), vlan_id,
       is_above ? (char*)"EXCEEDED" : (char*)"ok",
       stats->getQuotaEnforcementStats() ? "[QUOTAS enforced per pool member]" : "");
#endif

  has_blocking_quota |= is_above;
  return is_above;
}

/* *************************************** */

void Host::luaUsedQuotas(lua_State* vm) {
  if(stats) {
    HostPoolStats *quota_stats = stats->getQuotaEnforcementStats();
    
    if(quota_stats)
      quota_stats->lua(vm, iface);
    else
      lua_newtable(vm);
  }
}
#endif

/* *************************************** */

/* Splits a string in the format hostip@vlanid: *buf=hostip, *vlan_id=vlanid */
void Host::splitHostVLAN(const char *at_sign_str, char*buf, int bufsize, VLANid *vlan_id) {
  int size;
  const char *vlan_ptr = strchr(at_sign_str, '@');

  if(vlan_ptr == NULL) {
    vlan_ptr = at_sign_str + strlen(at_sign_str);
    *vlan_id = 0;
  } else {
    *vlan_id = atoi(vlan_ptr + 1);
  }

  size = min(bufsize, (int)(vlan_ptr - at_sign_str + 1));
  strncpy(buf, at_sign_str, size);
  buf[size-1] = '\0';
}

/* *************************************** */

void Host::reloadHostBlacklist() {
  ip.reloadBlacklist(iface->get_ndpi_struct());
}

/* *************************************** */

void Host::offlineSetMDNSInfo(char * const str) {
  char *cur_info;
  const char *tokens[] = {
    "._http._tcp.local",
    "._sftp-ssh._tcp.local",
    "._smb._tcp.local",
    "._device-info._tcp.local",
    "._privet._tcp.local",
    "._afpovertcp._tcp.local",
    NULL
  };

  if(names.mdns_info || !str)
    return; /* Already set */

  if(strstr(str, ".ip6.arpa"))
    return; /* Ignored for the time being */

  for(int i = 0; tokens[i] != NULL; i++) {
    if(strstr(str, tokens[i])) {
      str[strlen(str)-strlen(tokens[i])] = '\0';

      if((cur_info = strdup(str))) {
	for(i = 0; cur_info[i] != '\0'; i++) {
	  if(!isascii(cur_info[i]))
	    cur_info[i] = ' ';
	}

	/* Time to set the actual info */
	names.mdns_info = cur_info;
      }

      return;
    }
  }
}

/* *************************************** */

void Host::offlineSetSSDPLocation(const char * const url) {
  if(!ssdpLocation && url && (ssdpLocation = strdup(url)))
    ;
}

/* *************************************** */

void Host::offlineSetMDNSName(const char * const mdns_n) {
  if(!names.mdns && mdns_n && (names.mdns = strdup(mdns_n)))
    ;
}

/* *************************************** */

void Host::offlineSetMDNSTXTName(const char * const mdns_n_txt) {
  if(!names.mdns_txt && mdns_n_txt && (names.mdns_txt = strdup(mdns_n_txt)))
    ;
}

/* *************************************** */

void Host::offlineSetNetbiosName(const char * const netbios_n) {
  if(!names.netbios && netbios_n && (names.netbios = strdup(netbios_n)))
    ;
}

/* *************************************** */

void Host::setResolvedName(const char * const resolved_name) {
  /* This is NOT set inline, so we must lock. */
  if(resolved_name && (resolved_name[0] != '\0')
     && (!names.resolved /* Don't set hostnames already set */) ) {
    m.lock(__FILE__, __LINE__);
    names.resolved = strdup(resolved_name);
    m.unlock(__FILE__, __LINE__);
  }
}

/* *************************************** */

char* Host::get_country(char *buf, u_int buf_len) {
  char *continent = NULL, *country_name = NULL, *city = NULL;
  float latitude = 0, longitude = 0;

  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city, &latitude, &longitude);

  if(country_name)
    snprintf(buf, buf_len, "%s", country_name);
  else
    buf[0] = '\0';

  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);

  return(buf);
}

/* *************************************** */

char* Host::get_city(char *buf, u_int buf_len) {
  char *continent = NULL, *country_name = NULL, *city = NULL;
  float latitude = 0, longitude = 0;

  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city, &latitude, &longitude);

  if(city) {
    snprintf(buf, buf_len, "%s", city);
  } else
    buf[0] = '\0';

  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);

  return(buf);
}

/* *************************************** */

void Host::get_geocoordinates(float *latitude, float *longitude) {
  char *continent = NULL, *country_name = NULL, *city = NULL;

  *latitude = 0, *longitude = 0;
  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city, latitude, longitude);
  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);
}

/* *************************************** */

void Host::serialize_geocoordinates(ndpi_serializer *s, const char *prefix) {
  char *continent = NULL, *country = NULL, *city = NULL, buf[64];
  float latitude = 0, longitude = 0;
  
  ntop->getGeolocation()->getInfo(&ip, &continent, &country, &city, &latitude, &longitude);

  if(city) {
    snprintf(buf, sizeof(buf), "%s_city_name", prefix);
    ndpi_serialize_string_string(s, buf, city);
  }

  if(country) {
    snprintf(buf, sizeof(buf), "%s_country_name", prefix);
    ndpi_serialize_string_string(s, buf, country);
  }

  if(continent) {
    snprintf(buf, sizeof(buf), "%s_continent_name", prefix);
    ndpi_serialize_string_string(s, buf, continent);
  }

  if(longitude) {
    snprintf(buf, sizeof(buf), "%s_location_lon", prefix);
    ndpi_serialize_string_float(s, buf, longitude, "%f");
  }

  if(latitude) {
    snprintf(buf, sizeof(buf), "%s_location_lat", prefix);
    ndpi_serialize_string_float(s, buf, latitude, "%f");
  }

  ntop->getGeolocation()->freeInfo(&continent, &country, &city);  
}

/* *************************************** */

bool Host::isOneWayTraffic() const {
  /* When both directions are at zero, it means no periodic update has visited the host yet,
     so nothing can be said about its traffic directions. One way is only returned when 
     exactly one direction is greater than zero. */
  return(stats ? stats->getNumBytes() && !(stats->getNumBytesRcvd() && stats->getNumBytesSent()) : false);
};

/* *************************************** */

bool Host::isTwoWaysTraffic() const {
  return(stats ? stats->getNumBytesRcvd() && stats->getNumBytesSent() : false);
}

/* *************************************** */

DeviceProtoStatus Host::getDeviceAllowedProtocolStatus(ndpi_protocol proto, bool as_client) {
  if(getMac() && !getMac()->isSpecialMac()
#ifdef HAVE_NEDGE
      /* On nEdge the concept of device protocol policies is only applied to unassigned devices on LAN */
      && (getMac()->locate() == located_on_lan_interface)
#endif
  )
    return ntop->getDeviceAllowedProtocolStatus(getMac()->getDeviceType(), proto, get_host_pool(), as_client);

  return device_proto_allowed;
}

/* *************************************** */

bool Host::statsResetRequested() {
  return(stats_reset_requested || (last_stats_reset < ntop->getLastStatsReset()));
}

/* *************************************** */

void Host::blacklistedStatsResetRequested() {
  num_blacklisted_flows.checkpoint_as_client = num_blacklisted_flows.as_client;
  num_blacklisted_flows.checkpoint_as_server = num_blacklisted_flows.as_server;
}

/* *************************************** */

void Host::checkStatsReset() {
  if(stats_shadow) {
    delete stats_shadow;
    stats_shadow = NULL;
  }

  if(statsResetRequested()) {
    HostStats *new_stats = allocateStats();
    stats_shadow = stats;
    stats = new_stats;
    stats_shadow->resetTopSitesData();
    blacklistedStatsResetRequested();
    
    /* Reset internal state */
#ifdef NTOPNG_PRO
    has_blocking_quota = false;
#endif

    last_stats_reset = ntop->getLastStatsReset();
    stats_reset_requested = false;
  }
}

/* *************************************** */

void Host::checkBroadcastDomain() {
  if(iface->reloadHostsBroadcastDomain())
    is_in_broadcast_domain = iface->isLocalBroadcastDomainHost(this, false /* Non-inline call */);
}

/* *************************************** */

void Host::freeHostNames() {
  if(ssdpLocation)   { free(ssdpLocation); ssdpLocation = NULL;     }
  if(names.mdns)     { free(names.mdns); names.mdns = NULL;         }
  if(names.mdns_info){ free(names.mdns_info); names.mdns_info = NULL; }
  if(names.mdns_txt) { free(names.mdns_txt); names.mdns_txt = NULL; }
  if(names.resolved) { free(names.resolved); names.resolved = NULL; }
  if(names.netbios)  { free(names.netbios); names.netbios = NULL;   }
}

/* *************************************** */

void Host::resetHostNames() {
  m.lock(__FILE__, __LINE__);
  freeHostNames();
  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Host::checkNameReset() {
  if(name_reset_requested) {
    resetHostNames();
    name_reset_requested = false;
  }
}

/* *************************************** */

void Host::deleteHostData() {
  resetHostNames();
  first_seen = last_seen;
}

/* *************************************** */

void Host::checkDataReset() {
  if(data_delete_requested) {
    deleteHostData();
    data_delete_requested = false;
  }
}

/* *************************************** */

char* Host::get_mac_based_tskey(Mac *mac, char *buf, size_t bufsize) {
  char *k = mac->print(buf, bufsize);

  /* NOTE: it is important to differentiate between v4 and v6 for macs */
  strncat(buf, get_ip()->isIPv4() ? "_v4" : "_v6", bufsize);

  return(k);
}

/* *************************************** */

/*
  Private method, called periodically to update the OperatingSystem os pointer
  to what is set in os_type by setters using setOS
 */
void Host::inlineSetOS(OSType _os) {
  if(!os
     || os->get_os_type() != _os) {
    if(os) os->decUses();

    if((os = iface->getOS(_os, true /* Create if missing */, true /* Inline call */)) != NULL)
      os->incUses();
  }
}

/* *************************************** */

/*
  Public method to set the operating system
 */
void Host::setOS(OSType _os) {
  Mac *mac = getMac();

  if(!mac || (mac->getDeviceType() != device_networking))
    os_type = _os;
}

/* *************************************** */

OSType Host::getOS() const {
  return os_type;
}

/* *************************************** */

void Host::incOSStats(time_t when, u_int16_t proto_id,
		       u_int64_t sent_packets, u_int64_t sent_bytes,
		       u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {
  OperatingSystem *cur_os = os; /* Cache the pointer as it can change (similar to what is done for MAC addresses) */

  if(cur_os)
    cur_os->incStats(when, proto_id, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
}

/* *************************************** */

char* Host::get_tskey(char *buf, size_t bufsize) {
  char *k;
  Mac *cur_mac = getMac(); /* Cache macs as they can be swapped/updated */

  if(serializeByMac())
    k = get_mac_based_tskey(cur_mac, buf, bufsize);
  else
    k = get_hostkey(buf, bufsize);
  
  return(k);
}

/* *************************************** */

void Host::refreshDisabledAlerts() {
#ifdef NTOPNG_PRO
  AlertExclusions *alert_exclusions = ntop->getAlertExclusions();
  if(alert_exclusions && alert_exclusions->checkChange(&disabled_alerts_tstamp))
    alert_exclusions->setDisabledHostAlertsBitmaps(get_ip(), &disabled_host_alerts, &disabled_flow_alerts);
#endif
}

/* *************************************** */

bool Host::isHostAlertDisabled(HostAlertType alert_type) {
  refreshDisabledAlerts();
  return disabled_host_alerts.isSetBit(alert_type.id);
}

/* *************************************** */

bool Host::isFlowAlertDisabled(FlowAlertType alert_type) {
  refreshDisabledAlerts();
  return disabled_flow_alerts.isSetBit(alert_type.id);
}

/* *************************************** */

/* Create a JSON in the alerts format */
void Host::alert2JSON(HostAlert *alert, bool released, ndpi_serializer *s) {
  char ip_buf[128], buf[128];
  ndpi_serializer *alert_json_serializer = NULL;
  char *alert_json = NULL;
  u_int32_t alert_json_len;

  ndpi_serialize_string_int32(s, "ifid", getInterface()->get_id());
  ndpi_serialize_string_uint64(s, "pool_id", get_host_pool());

  /* See AlertableEntity::luaAlert */
  ndpi_serialize_string_string(s, "action", released ? "release" : "engage");
  ndpi_serialize_string_int32(s, "alert_id", alert->getAlertType().id);
  ndpi_serialize_string_int32(s, "score", alert->getAlertScore());
  ndpi_serialize_string_string(s, "subtype", "" /* No subtype for hosts */);
  ndpi_serialize_string_int32(s, "ip_version", ip.getVersion());
  ndpi_serialize_string_string(s, "ip", ip.print(ip_buf, sizeof(ip_buf)));
  get_name(buf, sizeof(buf), false);
  ndpi_serialize_string_string(s, "name", buf);
  ndpi_serialize_string_int32(s, "vlan_id", get_vlan_id());
  ndpi_serialize_string_int32(s, "observation_point_id", get_observation_point_id());
  ndpi_serialize_string_int32(s, "entity_id", alert_entity_host);
  ndpi_serialize_string_string(s, "entity_val", getEntityValue().c_str());
  ndpi_serialize_string_uint32(s, "tstamp", alert->getEngageTime());
  ndpi_serialize_string_uint32(s, "tstamp_end", alert->getReleaseTime());
  ndpi_serialize_string_boolean(s, "is_attacker", alert->isAttacker());
  ndpi_serialize_string_boolean(s, "is_victim", alert->isVictim());
  ndpi_serialize_string_boolean(s, "is_client", alert->isClient());
  ndpi_serialize_string_boolean(s, "is_server", alert->isServer());

  HostCheck *cb = getInterface()->getCheck(alert->getCheckType());
  ndpi_serialize_string_int32(s, "granularity", cb ? cb->getPeriod() : 0);

  alert_json_serializer = alert->getSerializedAlert();

  if(alert_json_serializer)
    alert_json = ndpi_serializer_get_buffer(alert_json_serializer, &alert_json_len);

  ndpi_serialize_string_string(s, "json", alert_json ? alert_json : "");
 
  if(alert_json_serializer) {
    ndpi_term_serializer(alert_json_serializer);
    free(alert_json_serializer);
  }
}

/* *************************************** */

/* Enqueue alert to recipients */
bool Host::enqueueAlertToRecipients(HostAlert *alert, bool released) {
  bool rv = false;
  u_int32_t buflen;
  AlertFifoItem notification;
  ndpi_serializer host_json;
  const char *host_str;

  ndpi_init_serializer(&host_json, ndpi_serialization_format_json);

  /* Prepare the JSON, including a JSON specific of this HostAlertType */
  alert2JSON(alert, released, &host_json);

  host_str = ndpi_serializer_get_buffer(&host_json, &buflen);

  /* TODO: read all the recipients responsible for hosts, and enqueue only to them */
  /* Currenty, we forcefully enqueue only to the builtin sqlite */
    
  notification.alert = (char*)host_str;
  notification.score = alert->getAlertScore();
  notification.alert_severity = Utils::mapScoreToSeverity(notification.score);
  notification.alert_category = alert->getAlertType().category;

  rv = ntop->recipients_enqueue(notification.alert_severity >= alert_level_error ? recipient_notification_priority_high : recipient_notification_priority_low,
				&notification,
				alert_entity_host /* Host recipients */);

  if(!rv)
    getInterface()->incNumDroppedAlerts(alert_entity_host);

  ndpi_term_serializer(&host_json);

  if(released)
    delete alert;

  return rv;
}

/* **************************************************** */

/* Call this when setting host idle (before removing it from memory) */
void Host::releaseAllEngagedAlerts() {
  for (u_int i = 0; i < NUM_DEFINED_HOST_CHECKS; i++) {
    HostCheckID t = (HostCheckID) i;
    HostAlert *alert = getCheckEngagedAlert(t);
    if(alert)
      releaseAlert(alert);
  }
}

/* *************************************** */

/*
 * This is called by the Check to trigger an alert
 */
bool Host::triggerAlert(HostAlert *alert) {
  ScoreCategory score_category;
  HostAlertType alert_type;

  if(alert == NULL)
    return false;

  alert_type = alert->getAlertType();

  if(isHostAlertDisabled(alert_type)) {
#ifdef DEBUG_SCORE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Discarding disabled alert");
#endif
    if(getCheckEngagedAlert(alert->getCheckType()) == alert) /* Alert is engaged */
      alert->setExpiring(); /* Mark this alert as expiring to have it released soon */
    else /* Triggered alert is not yet engaged */
      delete alert; /* Delete it right now, don't even let it continue */

    return false;
  }

  /* Leave this AFTER the isHostAlertDisabled check */
  alert->setEngaged();

  if(hasCheckEngagedAlert(alert->getCheckType())) {
    if(getCheckEngagedAlert(alert->getCheckType()) == alert) {
      /* This is a refresh (see alert->isExpired()) */
      return true;
    } else {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal Error: One engaged alert is allowed per check");
      delete alert;
      return false;
    }
  }

#ifdef DEBUG_SCORE
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Set host score %u/%u", score_as_cli/score_as_srv);
#endif

  score_category = Utils::mapAlertToScoreCategory(alert_type.category);

  incScoreValue(alert->getCliScore(), score_category, true /* as client */);
  incScoreValue(alert->getSrvScore(), score_category, false /* as server */);

  /* Add to the list of engaged alerts*/
  addEngagedAlert(alert);

  /* Enqueue the alert to be notified */
  iface->enqueueHostAlert(alert);

  return true;
}

/* *************************************** */

/*
 * This is called by the Check (or by the HostChecksExecutor
 * for expired alerts with auto release) to release an alert
 */
void Host::releaseAlert(HostAlert *alert) {
  ScoreCategory score_category;

  /* Set as released */
  alert->release();

  /* Remove from the list of engaged alerts */
  removeEngagedAlert(alert);

  /* Dec score */
  score_category = Utils::mapAlertToScoreCategory(alert->getAlertType().category);
  decScoreValue(alert->getCliScore(), score_category,  true /* as client */);
  decScoreValue(alert->getSrvScore(), score_category,  false /* as server */);

  /* Enqueue the released alert to be notified */
  iface->enqueueHostAlert(alert);
}

/* *************************************** */

