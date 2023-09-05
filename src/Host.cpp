/*
 *
 * (C) 2013-23 - ntop.org
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

Host::Host(NetworkInterface *_iface, char *ipAddress, u_int16_t _u_int16_t,
           u_int16_t observation_point_id)
    : GenericHashEntry(_iface),
      HostAlertableEntity(_iface, alert_entity_host),
      Score(_iface),
      HostChecksStatus() {
  ip.set(ipAddress);
  initialize(NULL, _u_int16_t, observation_point_id);
}

/* *************************************** */

Host::Host(NetworkInterface *_iface, Mac *_mac, u_int16_t _u_int16_t,
           u_int16_t observation_point_id, IpAddress *_ip)
    : GenericHashEntry(_iface),
      HostAlertableEntity(_iface, alert_entity_host),
      Score(_iface),
      HostChecksStatus() {
  ip.set(_ip);

#ifdef BROADCAST_DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting %s [broadcast: %u]",
                               ip.print(buf, sizeof(buf)),
                               isBroadcastHost() ? 1 : 0);
#endif

  initialize(_mac, _u_int16_t, observation_point_id);
}

/* *************************************** */

Host::~Host() {
  if ((getUses() > 0)
      /* View hosts are not in sync with viewed flows so during shutdown it can
         be normal */
      && (!iface->isView() || !ntop->getGlobals()->isShutdownRequested()))
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: num_uses=%u",
                                 getUses());

  if (mac) mac->decUses();
  if (as) as->decUses();
  if (os) os->decUses();
  if (country) country->decUses();
  if (obs_point) obs_point->decUses();
  if (vlan) vlan->decUses();

#ifdef NTOPNG_PRO
  if (host_traffic_shapers) {
    for (int i = 0; i < NUM_TRAFFIC_SHAPERS; i++) {
      if (host_traffic_shapers[i]) delete host_traffic_shapers[i];
    }

    free(host_traffic_shapers);
  }

#endif

  freeHostNames();

  if (syn_flood.attacker_counter) delete syn_flood.attacker_counter;
  if (syn_flood.victim_counter) delete syn_flood.victim_counter;
  if (flow_flood.attacker_counter) delete flow_flood.attacker_counter;
  if (flow_flood.victim_counter) delete flow_flood.victim_counter;
  if (icmp_flood.attacker_counter) delete icmp_flood.attacker_counter;
  if (icmp_flood.victim_counter) delete icmp_flood.victim_counter;
  if (dns_flood.attacker_counter) delete dns_flood.attacker_counter;
  if (dns_flood.victim_counter) delete dns_flood.victim_counter;
  if (snmp_flood.attacker_counter) delete snmp_flood.attacker_counter;
  if (snmp_flood.victim_counter) delete snmp_flood.victim_counter;
  if (rst_scan.attacker_counter) delete rst_scan.attacker_counter;
  if (rst_scan.victim_counter) delete rst_scan.victim_counter;

  if (stats) delete stats;
  if (stats_shadow) delete stats_shadow;

#ifndef HAVE_NEDGE
  if (listening_ports) delete listening_ports;
  if (listening_ports_shadow) delete listening_ports_shadow;
#endif

  if (blacklist_name) free(blacklist_name);

  /*
    Pool counters are updated both in and outside the datapath.
    So decPoolNumHosts must stay in the destructor to preserve counters
    consistency (no thread outside the datapath will change the last pool id)
  */
  iface->decPoolNumHosts(get_host_pool(), false /* Host is deleted offline */);
  if (customHostAlert.msg) free(customHostAlert.msg);
  if (tcp_udp_contacted_ports_no_tx)
    ndpi_bitmap_free(tcp_udp_contacted_ports_no_tx);

  ndpi_hll_destroy(&outgoing_hosts_tcp_udp_port_with_no_tx_hll);
  ndpi_hll_destroy(&incoming_hosts_tcp_udp_port_with_no_tx_hll);
}

/* *************************************** */

/* NOTE: overrides Score::incScoreValue to handle increments for host members as
 * well */
u_int16_t Host::incScoreValue(u_int16_t score_incr,
                              ScoreCategory score_category, bool as_client) {
  NetworkStats *ns = getNetworkStats(get_local_network_id());
  u_int16_t score_inc;

  /* Do increments only on members that don't change during the lifecycle of the
   * host */
  if (as) as->incScoreValue(score_incr, score_category, as_client);
  if (vlan) vlan->incScoreValue(score_incr, score_category, as_client);
  if (country) country->incScoreValue(score_incr, score_category, as_client);
  if (obs_point)
    obs_point->incScoreValue(score_incr, score_category, as_client);
  if (ns) ns->incScoreValue(score_incr, score_category, as_client);
  if (iface) iface->incScoreValue(score_incr, as_client);
  score_inc = Score::incScoreValue(score_incr, score_category, as_client);

  return score_inc;
}

/* *************************************** */

/* NOTE: overrides Score::decScoreValue to handle increments for host members as
 * well */
u_int16_t Host::decScoreValue(u_int16_t score_decr,
                              ScoreCategory score_category, bool as_client) {
  NetworkStats *ns = getNetworkStats(get_local_network_id());

  /* Keep decements in sync with Host::incScoreValue */
  if (as) as->decScoreValue(score_decr, score_category, as_client);
  if (vlan) vlan->decScoreValue(score_decr, score_category, as_client);
  if (country) country->decScoreValue(score_decr, score_category, as_client);
  if (obs_point)
    obs_point->decScoreValue(score_decr, score_category, as_client);
  if (ns) ns->decScoreValue(score_decr, score_category, as_client);
  if (iface) iface->decScoreValue(score_decr, as_client);

  return Score::decScoreValue(score_decr, score_category, as_client);
}

/* *************************************** */

void Host::updateSynAlertsCounter(time_t when, bool syn_sent) {
  AlertCounter *counter =
      syn_sent ? syn_flood.attacker_counter : syn_flood.victim_counter;

  counter->inc(when, this);

  if (syn_sent)
    syn_scan.syn_sent_last_min++;
  else
    syn_scan.syn_recvd_last_min++;
}

/* *************************************** */

void Host::updateFinAlertsCounter(time_t when, bool fin_sent) {
  fin_sent ? fin_scan.fin_sent_last_min++ : fin_scan.fin_recvd_last_min++;
}

/* *************************************** */

void Host::updateRstAlertsCounter(time_t when, bool rst_sent) {
  AlertCounter *counter =
      rst_sent ? rst_scan.attacker_counter : rst_scan.victim_counter;

  counter->inc(when, this);
}

/* *************************************** */

void Host::updateFinAckAlertsCounter(time_t when, bool finack_sent) {
  finack_sent ? fin_scan.finack_sent_last_min++
              : fin_scan.finack_recvd_last_min++;
}

/* *************************************** */

void Host::updateICMPAlertsCounter(time_t when, bool icmp_sent) {
  AlertCounter *counter =
      icmp_sent ? icmp_flood.attacker_counter : icmp_flood.victim_counter;

  counter->inc(when, this);
}

/* *************************************** */

void Host::updateDNSAlertsCounter(time_t when, bool dns_sent) {
  AlertCounter *counter =
      dns_sent ? dns_flood.attacker_counter : dns_flood.victim_counter;

  counter->inc(when, this);
}

/* *************************************** */

void Host::updateSNMPAlertsCounter(time_t when, bool snmp_sent) {
  AlertCounter *counter =
      snmp_sent ? snmp_flood.attacker_counter : snmp_flood.victim_counter;

  counter->inc(when, this);
}

/* *************************************** */

void Host::updateSynAckAlertsCounter(time_t when, bool synack_sent) {
  if (synack_sent)
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
  switch (get_state()) {
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

void Host::initialize(Mac *_mac, u_int16_t _vlanId,
                      u_int16_t observation_point_id) {
  if (_vlanId == (u_int16_t)-1) _vlanId = 0;

  vlan_id = _vlanId & 0xFFF; /* Cleanup any possible junk */

  /* stats = NULL; useless initi, it will be instantiated by specialized classes
   */
  stats_shadow = NULL;
#ifndef HAVE_NEDGE
  listening_ports = listening_ports_shadow = NULL;
#endif
  data_delete_requested = 0, stats_reset_requested = 0,
  name_reset_requested = 0, prefs_loaded = 0;
  host_services_bitmap = 0, disabled_alerts_tstamp = 0, num_remote_access = 0,
  num_incomplete_flows = 0;

  num_resolve_attempts = 0, nextResolveAttempt = 0,
  num_active_flows_as_client = 0, num_active_flows_as_server = 0,
  active_alerted_flows = 0;

  is_dhcp_host = 0, is_crawler_bot_scanner = 0, is_in_broadcast_domain = 0,
  more_then_one_device = 0, device_ip = 0;

  last_stats_reset = ntop->getLastStatsReset(); /* assume fresh stats, may be
                                                   changed by deserialize */
  asn = 0, asname = NULL, obs_point = NULL, os = NULL, os_type = os_unknown;
  ssdpLocation = NULL, blacklist_name = NULL;

  memset(&names, 0, sizeof(names));
  memset(view_interface_mac, 0, sizeof(view_interface_mac));
  memset(&unidirectionalTCPUDPFlows, 0, sizeof(unidirectionalTCPUDPFlows));
  memset(&num_blacklisted_flows, 0, sizeof(num_blacklisted_flows));
  memset(&customHostAlert, 0, sizeof(customHostAlert));

  setRxOnlyHost(true);

#ifdef NTOPNG_PRO
  host_traffic_shapers = NULL;
  has_blocking_quota = has_blocking_shaper = false;
#endif

  if ((mac = _mac)) mac->incUses();

  observationPointId = observation_point_id;

  if ((vlan = iface->getVLAN(vlan_id, true, true /* Inline call */)) != NULL)
    vlan->incUses();

  INTERFACE_PROFILING_SUB_SECTION_ENTER(
      iface, "Host::initialize: new AlertCounter", 17);
  syn_flood.attacker_counter = new (std::nothrow) AlertCounter();
  syn_flood.victim_counter = new (std::nothrow) AlertCounter();
  flow_flood.attacker_counter = new (std::nothrow) AlertCounter();
  flow_flood.victim_counter = new (std::nothrow) AlertCounter();
  icmp_flood.attacker_counter = new (std::nothrow) AlertCounter();
  icmp_flood.victim_counter = new (std::nothrow) AlertCounter();
  dns_flood.attacker_counter = new (std::nothrow) AlertCounter();
  dns_flood.victim_counter = new (std::nothrow) AlertCounter();
  snmp_flood.attacker_counter = new (std::nothrow) AlertCounter();
  snmp_flood.victim_counter = new (std::nothrow) AlertCounter();
  rst_scan.attacker_counter = new (std::nothrow) AlertCounter();
  rst_scan.victim_counter = new (std::nothrow) AlertCounter();
  syn_scan.syn_sent_last_min = syn_scan.synack_recvd_last_min = 0;
  syn_scan.syn_recvd_last_min = syn_scan.synack_sent_last_min = 0;
  fin_scan.fin_sent_last_min = fin_scan.finack_recvd_last_min = 0;
  fin_scan.fin_recvd_last_min = fin_scan.finack_sent_last_min = 0;
  INTERFACE_PROFILING_SUB_SECTION_EXIT(iface, 17);

  tcp_udp_contacted_ports_no_tx = ndpi_bitmap_alloc();
  ndpi_hll_init(&outgoing_hosts_tcp_udp_port_with_no_tx_hll,
                5 /* StdError: 18.4% */);
  ndpi_hll_init(&incoming_hosts_tcp_udp_port_with_no_tx_hll,
                5 /* StdError: 18.4% */);

  deferredInitialization(); /* TODO To be called asynchronously for improving
                               performance */
}

/* *************************************** */

void Host::deferredInitialization() {
  char buf[64];

  inlineSetOS(os_unknown);
  setEntityValue(get_hostkey(buf, sizeof(buf), true));

  is_in_broadcast_domain =
      iface->isLocalBroadcastDomainHost(this, true /* Inline call */);

  reloadHostBlacklist();
  is_blacklisted = ip.isBlacklistedAddress();

  if (ip.getVersion() /* IP is set */) {
    char country_name[64];

    /*
     * IMPORTANT: as and country are defined here, in case the initialization
     * is postponed, remember to initialize these values to NULL in the init
     */
    if ((as = iface->getAS(&ip, true /* Create if missing */,
                           true /* Inline call */)) != NULL) {
      as->incUses();
      asn = as->get_asn();
      asname = as->get_asname();
    }

    get_country(country_name, sizeof(country_name));

    if ((country = iface->getCountry(country_name, true /* Create if missing */,
                                     true /* Inline call */)) != NULL)
      country->incUses();

    if ((obs_point = iface->getObsPoint(observationPointId,
                                        true /* Create if missing */,
                                        true /* Inline call */)) != NULL)
      obs_point->incUses();
  }

  reloadDhcpHost();
}

/* *************************************** */

char *Host::get_hostkey(char *buf, u_int buf_len, bool force_vlan) {
  char ipbuf[64];
  char *key = ip.print(ipbuf, sizeof(ipbuf));

  if ((vlan_id > 0) || force_vlan) {
    char obsBuf[16] = {'\0'};

    /*
      Uncomment to add observationPointId in the host name

      if(observationPointId == 0)
        obsBuf[0] = '\0';
      else
        snprintf(obsBuf, sizeof(obsBuf), " (%u)", observationPointId);
    */

    if (get_vlan_id())
      snprintf(buf, buf_len, "%s@%u%s", key, get_vlan_id(), obsBuf);
    else
      snprintf(buf, buf_len, "%s%s", key, obsBuf);
  } else
    strncpy(buf, key, buf_len);

  buf[buf_len - 1] = '\0';
  return buf;
}

/* *************************************** */

void Host::updateHostPool(bool isInlineCall, bool firstUpdate) {
  if (!iface) return;

  if (!firstUpdate) iface->decPoolNumHosts(get_host_pool(), isInlineCall);
  host_pool_id = iface->getHostPool(this);
  iface->incPoolNumHosts(get_host_pool(), isInlineCall);

#ifdef NTOPNG_PRO
  if (iface && iface->is_bridge_interface()) {
    HostPools *hp = iface->getHostPools();

    if (hp && hp->enforceQuotasPerPoolMember(get_host_pool())) {
      /* must allocate a structure to keep track of used quotas */
      if (stats) stats->allocateQuotaEnforcementStats();
    } else { /* Free the structure that is no longer needed */
      /* It is ensured by the caller that this method is called no more than 1
      time per second. Therefore, it is safe to delete a previously allocated
      shadow class */
      if (stats) stats->deleteQuotaEnforcementStats();
    }

    if (hp && hp->enforceShapersPerPoolMember(get_host_pool())) {
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
  if ((mac != _mac) && (_mac != NULL)) {
    if (mac) mac->decUses();
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

void Host::lua_get_anomalies(lua_State *vm) const {
  if (!vm) return;

  if (hasAnomalies()) {
    time_t now = time(0);

    lua_newtable(vm);

    stats->luaAnomalies(vm, now);

    lua_pushstring(vm, "anomalies");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void Host::luaStrTableEntryLocked(lua_State *const vm, const char *entry_name,
                                  const char *entry_value) {
  /* Perform access to const entry values using a lock as entry value can change
   * for example during a data reset */
  if (entry_name) {
    m.lock(__FILE__, __LINE__);

    if (entry_value) lua_push_str_table_entry(vm, entry_name, entry_value);

    m.unlock(__FILE__, __LINE__);
  }
}

/* *************************************** */

void Host::lua_get_names(lua_State *const vm, char *const buf,
                         ssize_t buf_size) {
  Mac *cur_mac = getMac();

  lua_newtable(vm);

  if (ntop->getPrefs()->is_name_decoding_enabled()) {
    getMDNSName(buf, buf_size);
    if (buf[0]) lua_push_str_table_entry(vm, "mdns", buf);

    getMDNSTXTName(buf, buf_size);
    if (buf[0]) lua_push_str_table_entry(vm, "mdns_txt", buf);

    getResolvedName(buf, buf_size);
    if (buf[0]) lua_push_str_table_entry(vm, "resolved", buf);

    getNetbiosName(buf, buf_size);
    if (buf[0]) lua_push_str_table_entry(vm, "netbios", buf);

    getTLSName(buf, buf_size);
    if (buf[0]) lua_push_str_table_entry(vm, "tls", buf);

    getHTTPName(buf, buf_size);
    if (buf[0]) lua_push_str_table_entry(vm, "http", buf);

    if (isBroadcastDomainHost() && cur_mac) {
      cur_mac->getDHCPName(buf, buf_size);
      if (buf[0]) lua_push_str_table_entry(vm, "dhcp", buf);
    }
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
  lua_push_uint32_table_entry(vm, "observation_point_id",
                              get_observation_point_id());
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

  const u_int8_t *mac = cur_mac ? cur_mac->get_mac() : view_interface_mac;

  lua_push_str_table_entry(
      vm, "mac", Utils::formatMac(mac ? mac : NULL, buf, sizeof(buf)));
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

void Host::lua_get_cat_bytes(lua_State *vm,
                             ndpi_protocol_category_t category_id) const {
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
  lua_push_str_table_entry(vm, "asname", asn_n ? asn_n : (char *)"");
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
  if (stats)
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
  lua_push_bool_table_entry(vm, "broadcast_domain_host",
                            isBroadcastDomainHost());
  lua_push_bool_table_entry(vm, "dhcpHost", isDHCPHost());
  lua_push_bool_table_entry(vm, "crawlerBotScannerHost",
                            isCrawlerBotScannerHost());
  lua_push_bool_table_entry(vm, "is_blacklisted", isBlacklisted());
  lua_push_bool_table_entry(vm, "is_rx_only", is_rx_only);
  lua_push_bool_table_entry(vm, "is_broadcast", isBroadcastHost());
  lua_push_bool_table_entry(vm, "is_multicast", isMulticastHost());
  lua_push_int32_table_entry(vm, "host_services_bitmap", host_services_bitmap);
  lua_get_services(vm);
  lua_get_geoloc(vm);
  lua_get_ip(vm);
  lua_get_mac(vm);

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

  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city,
                                  &latitude, &longitude);
  lua_push_str_table_entry(vm, "continent", continent ? continent : (char *)"");
  lua_push_str_table_entry(vm, "country",
                           country_name ? country_name : (char *)"");
  lua_push_float_table_entry(vm, "latitude", latitude);
  lua_push_float_table_entry(vm, "longitude", longitude);
  lua_push_str_table_entry(vm, "city", city ? city : (char *)"");
  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);
}

/* ***************************************************** */

void Host::lua_get_syn_flood(lua_State *vm) const {
  u_int16_t hits;

  if ((hits = syn_flood.victim_counter->hits()))
    lua_push_uint64_table_entry(vm, "hits.syn_flood_victim", hits);
  if ((hits = syn_flood.attacker_counter->hits()))
    lua_push_uint64_table_entry(vm, "hits.syn_flood_attacker", hits);
}

/* ***************************************************** */

void Host::lua_get_flow_flood(lua_State *vm) const {
  u_int16_t hits;

  if ((hits = flow_flood.victim_counter->hits()))
    lua_push_uint64_table_entry(vm, "hits.flow_flood_victim", hits);
  if ((hits = flow_flood.attacker_counter->hits()))
    lua_push_uint64_table_entry(vm, "hits.flow_flood_attacker", hits);
}

/* ***************************************************** */

void Host::lua_get_services(lua_State *vm) const {
  if (host_services_bitmap == 0) return;

  lua_newtable(vm);

  if (isDhcpServer()) lua_push_bool_table_entry(vm, "dhcp", true);
  if (isDnsServer()) lua_push_bool_table_entry(vm, "dns", true);
  if (isSmtpServer()) lua_push_bool_table_entry(vm, "smtp", true);
  if (isPopServer()) lua_push_bool_table_entry(vm, "pop", true);
  if (isImapServer()) lua_push_bool_table_entry(vm, "imap", true);
  if (isNtpServer()) lua_push_bool_table_entry(vm, "ntp", true);

  lua_pushstring(vm, "services");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ***************************************************** */

void Host::lua_get_syn_scan(lua_State *vm) const {
  u_int32_t hits;

  hits = 0;
  if (syn_scan.syn_sent_last_min > syn_scan.synack_recvd_last_min)
    hits = syn_scan.syn_sent_last_min - syn_scan.synack_recvd_last_min;
  if (hits) lua_push_uint64_table_entry(vm, "hits.syn_scan_attacker", hits);

  hits = 0;
  if (syn_scan.syn_recvd_last_min > syn_scan.synack_sent_last_min)
    hits = syn_scan.syn_recvd_last_min - syn_scan.synack_sent_last_min;
  if (hits) lua_push_uint64_table_entry(vm, "hits.syn_scan_victim", hits);
}

/* ***************************************************** */

void Host::lua_get_fin_scan(lua_State *vm) const {
  u_int32_t hits;

  hits = 0;
  if (fin_scan.fin_sent_last_min > fin_scan.finack_recvd_last_min)
    hits = fin_scan.fin_sent_last_min - fin_scan.finack_recvd_last_min;
  if (hits) lua_push_uint64_table_entry(vm, "hits.fin_scan_attacker", hits);

  hits = 0;
  if (fin_scan.fin_recvd_last_min > fin_scan.finack_sent_last_min)
    hits = fin_scan.fin_recvd_last_min - fin_scan.finack_sent_last_min;
  if (hits) lua_push_uint64_table_entry(vm, "hits.fin_scan_victim", hits);
}

/* ***************************************************** */

void Host::lua_get_time(lua_State *vm) const {
  lua_push_uint64_table_entry(vm, "seen.first", get_first_seen());
  lua_push_uint64_table_entry(vm, "seen.last", get_last_seen());
  lua_push_uint64_table_entry(vm, "duration", get_duration());

  if (stats)
    lua_push_uint64_table_entry(vm, "total_activity_time",
                                stats->getTotalActivityTime());
}

/* ***************************************************** */

void Host::lua_get_num_alerts(lua_State *vm) const {
  lua_push_uint64_table_entry(vm, "num_alerts", getNumEngagedAlerts());
  lua_push_uint64_table_entry(vm, "active_alerted_flows", getNumAlertedFlows());

  if (stats)
    lua_push_uint64_table_entry(vm, "total_alerts", stats->getTotalAlerts());
}

/* ***************************************************** */

void Host::lua_get_num_total_flows(lua_State *vm) const {
  lua_push_uint64_table_entry(vm, "total_flows.as_client",
                              getTotalNumFlowsAsClient());
  lua_push_uint64_table_entry(vm, "total_flows.as_server",
                              getTotalNumFlowsAsServer());
}

/* ***************************************************** */

void Host::lua_get_num_flows(lua_State *vm) const {
  lua_push_uint64_table_entry(vm, "active_flows.as_client",
                              getNumOutgoingFlows());
  lua_push_uint64_table_entry(vm, "active_flows.as_server",
                              getNumIncomingFlows());
  lua_push_uint64_table_entry(vm, "alerted_flows.as_server",
                              getTotalNumAlertedIncomingFlows());
  lua_push_uint64_table_entry(vm, "alerted_flows.as_client",
                              getTotalNumAlertedOutgoingFlows());
  lua_push_uint64_table_entry(vm, "unreachable_flows.as_server",
                              getTotalNumUnreachableIncomingFlows());
  lua_push_uint64_table_entry(vm, "unreachable_flows.as_client",
                              getTotalNumUnreachableOutgoingFlows());
  lua_push_uint64_table_entry(vm, "host_unreachable_flows.as_server",
                              getTotalNumHostUnreachableIncomingFlows());
  lua_push_uint64_table_entry(vm, "host_unreachable_flows.as_client",
                              getTotalNumHostUnreachableOutgoingFlows());

  if (stats) stats->luaHostBehaviour(vm);
}

/* ***************************************************** */

void Host::lua_get_num_contacts(lua_State *vm) {
  lua_push_uint64_table_entry(vm, "contacts.as_client",
                              getNumActiveContactsAsClient());
  lua_push_uint64_table_entry(vm, "contacts.as_server",
                              getNumActiveContactsAsServer());
}

/* ***************************************************** */

void Host::lua_get_num_http_hosts(lua_State *vm) {
  lua_push_uint64_table_entry(vm, "active_http_hosts", getActiveHTTPHosts());
}

/* ***************************************************** */

void Host::lua_get_fingerprints(lua_State *vm) {
  fingerprints.ja3.lua("ja3_fingerprint", vm);
  fingerprints.hassh.lua("hassh_fingerprint", vm);
}

/* ***************************************************** */

void Host::lua_unidirectional_tcp_udp_flows(lua_State *vm,
                                            bool as_subtable) const {
  lua_newtable(vm);

  lua_push_uint32_table_entry(vm, "num_ingress",
                              unidirectionalTCPUDPFlows.numIngressFlows);
  lua_push_uint32_table_entry(vm, "num_egress",
                              unidirectionalTCPUDPFlows.numEgressFlows);

  if (as_subtable) {
    lua_pushstring(vm, "num_unidirectional_tcp_flows");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ***************************************************** */

void Host::lua_blacklisted_flows(lua_State *vm) const {
  /* Flow exchanged with blacklists hosts */
  lua_newtable(vm);

  /* Considering the datas from the last reset */
  lua_push_uint32_table_entry(vm, "as_client", getNumBlacklistedAsCliReset());
  lua_push_uint32_table_entry(vm, "as_server", getNumBlacklistedAsSrvReset());
  /* All data, without considering the reset. This is done for rrd. */
  lua_push_uint32_table_entry(vm, "tot_as_client",
                              num_blacklisted_flows.as_client);
  lua_push_uint32_table_entry(vm, "tot_as_server",
                              num_blacklisted_flows.as_server);

  lua_pushstring(vm, "num_blacklisted_flows");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ***************************************************** */

#ifndef HAVE_NEDGE
void Host::lua_get_listening_ports(lua_State *vm) {
  if (listening_ports == NULL) return;

  lua_newtable(vm);

  listening_ports->lua(vm);

  lua_pushstring(vm, "listening_ports");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
#endif

/* ***************************************************** */

void Host::lua(lua_State *vm, AddressTree *ptree, bool host_details,
               bool verbose, bool returnHost, bool asListElement) {
  char buf[64], buf_id[64], *host_id = buf_id;
  char ip_buf[64], *ipaddr = NULL;
  bool mask_host = Utils::maskHost(isLocalHost());

  if ((ptree && (!match(ptree))) || mask_host) return;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "ip",
                           (ipaddr = printMask(ip_buf, sizeof(ip_buf))));
  lua_push_uint32_table_entry(vm, "vlan", get_vlan_id());
  lua_push_uint32_table_entry(vm, "observation_point_id",
                              get_observation_point_id());
  lua_push_bool_table_entry(vm, "serialize_by_mac", serializeByMac());
  lua_push_uint64_table_entry(vm, "ipkey", ip.key());
  lua_push_str_table_entry(vm, "iphex", ip.get_ip_hex(buf_id, sizeof(buf_id)));
  lua_push_str_table_entry(vm, "tskey", get_tskey(buf_id, sizeof(buf_id)));

  lua_push_str_table_entry(vm, "name", get_visual_name(buf, sizeof(buf)));

  lua_get_min_info(vm);
  lua_get_mac(vm);

  lua_get_num_alerts(vm);
  lua_get_score(vm);

  lua_get_as(vm);
  lua_get_os(vm);
  lua_get_host_pool(vm);

  if (stats)
    stats->lua(vm, mask_host, Utils::bool2DetailsLevel(verbose, host_details)),
        stats->luaHostBehaviour(vm);

  lua_get_num_flows(vm);
  lua_get_num_contacts(vm);
  lua_get_num_http_hosts(vm);

  lua_push_float_table_entry(
      vm, "bytes_ratio", ndpi_data_ratio(getNumBytesSent(), getNumBytesRcvd()));
  lua_push_float_table_entry(
      vm, "pkts_ratio", ndpi_data_ratio(getNumPktsSent(), getNumPktsRcvd()));

  lua_push_int32_table_entry(
      vm, "num_contacted_peers_with_tcp_udp_flows_no_response",
      getNumContactedPeersAsClientTCPUDPNoTX());
  lua_push_int32_table_entry(
      vm, "num_incoming_peers_that_sent_tcp_udp_flows_no_response",
      getNumContactsFromPeersAsServerTCPUDPNoTX());

  if (device_ip)
    lua_push_str_table_entry(vm, "device_ip",
                             Utils::intoaV4(device_ip, buf, sizeof(buf)));

  if (blacklist_name != NULL)
    lua_push_str_table_entry(vm, "blacklist_name", blacklist_name);

  lua_push_bool_table_entry(vm, "is_rx_only", is_rx_only);

  if (more_then_one_device)
    lua_push_bool_table_entry(vm, "more_then_one_device", more_then_one_device);

  luaDNS(vm, verbose);
  luaTCP(vm);
  luaICMP(vm, get_ip()->isIPv4(), false);

  lua_unidirectional_tcp_udp_flows(vm, true);

  if (host_details) {
    lua_get_score_breakdown(vm);
    lua_blacklisted_flows(vm);

    /*
      This has been disabled as in case of an attack, most hosts do not have a
      name and we will waste a lot of time doing activities that are not
      necessary
    */
    get_name(buf, sizeof(buf), false);
    if (strlen(buf) == 0 || strcmp(buf, ipaddr) == 0) {
      if (isBroadcastHost() || isMulticastHost() ||
          (isIPv6() && ((strncmp(ipaddr, "ff0", 3) == 0) ||
                        (strncmp(ipaddr, "fe80", 4) == 0))))
        ; /* Nothing to do */
      else {
        /* We resolve immediately the IP address by queueing on the top of
         * address queue */
        ntop->getRedis()->pushHostToResolve(ipaddr, false,
                                            true /* Fake to resolve it ASAP */);
      }
    }

    luaStrTableEntryLocked(
        vm, "ssdp",
        ssdpLocation); /* locked to protect against data-reset changes */

    /* ifid is useful for example for view interfaces to detemine
       the actual, original interface the host is associated to. */
    lua_push_uint64_table_entry(vm, "ifid", iface->get_id());
    if (!mask_host)
      luaStrTableEntryLocked(
          vm, "info",
          names.mdns_info); /* locked to protect against data-reset changes */

    lua_get_names(vm, buf, sizeof(buf));

    lua_get_geoloc(vm);

    lua_get_flow_flood(vm);
    lua_get_services(vm);

#ifndef HAVE_NEDGE
    lua_get_listening_ports(vm);
#endif
  }

  lua_get_time(vm);

  lua_get_fingerprints(vm);

  if (verbose) {
    if (hasAnomalies()) lua_get_anomalies(vm);
  }

  if (!returnHost) host_id = get_hostkey(buf_id, sizeof(buf_id));

  if (asListElement) {
    lua_pushstring(vm, host_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ***************************************** */

char *Host::get_name(char *buf, u_int buf_len,
                     bool force_resolution_if_not_found) {
  char *addr = NULL, name_buf[128];
  int rc = -1;
  time_t now = time(NULL);
  bool skip_resolution = false;

  name_buf[0] = '\0';

  if (!ntop->getPrefs()->is_name_decoding_enabled()) goto out;

  if (isLocalHost() &&
      (!ntop->getPrefs()->is_localhost_name_decoding_enabled()))
    goto out;

  if (nextResolveAttempt &&
      ((num_resolve_attempts > 1) || (nextResolveAttempt > now) ||
       (nextResolveAttempt == (time_t)-1))) {
    skip_resolution = true;
  } else
    nextResolveAttempt = ntop->getPrefs()->is_dns_resolution_enabled()
                             ? now + MIN_HOST_RESOLUTION_FREQUENCY
                             : (time_t)-1;

  num_resolve_attempts++;

  getResolvedName(name_buf, sizeof(name_buf));
  if (name_buf[0] && !Utils::isIPAddress(name_buf)) goto out;

  getServerName(name_buf, sizeof(name_buf));
  if (name_buf[0] && !Utils::isIPAddress(name_buf)) goto out;

  /* Most relevant names goes first */
  if (isBroadcastDomainHost()) {
    Mac *cur_mac = getMac(); /* Cache it as it can change */

    if (cur_mac) {
      cur_mac->getDHCPName(name_buf, sizeof(name_buf));
      if (strlen(name_buf)) goto out;
    }
  }

  getMDNSTXTName(name_buf, sizeof(name_buf));
  if (name_buf[0] && !Utils::isIPAddress(name_buf)) goto out;

  getMDNSName(name_buf, sizeof(name_buf));
  if (name_buf[0] && !Utils::isIPAddress(name_buf)) goto out;

  getMDNSInfo(name_buf, sizeof(name_buf));
  if (name_buf[0] && !Utils::isIPAddress(name_buf)) goto out;

  getTLSName(name_buf, sizeof(name_buf));
  if (name_buf[0] && !Utils::isIPAddress(name_buf)) goto out;

  getHTTPName(name_buf, sizeof(name_buf));
  if (name_buf[0] && !Utils::isIPAddress(name_buf)) goto out;

  if (!skip_resolution) {
    addr = ip.print(buf, buf_len);
    rc = ntop->getRedis()->getAddress(addr, name_buf, sizeof(name_buf),
                                      force_resolution_if_not_found);
  }
  /*
    NetBIOS name should not address an IP, see
    https://github.com/ntop/ntopng/issues/6509

    getNetbiosName(name_buf, sizeof(name_buf));
    if(name_buf[0] && !Utils::isIPAddress(name_buf))
      goto out;
  */

  if (rc == 0 && strcmp(addr, name_buf))
    setResolvedName(name_buf);
  else if (!skip_resolution)
    addr = ip.print(name_buf, sizeof(name_buf));

out:
  snprintf(buf, buf_len, "%s", name_buf);
  return (buf);
}

/* ***************************************** */

/* Retrieve the host label. This should only be used to store persistent
 * information from C. In lua use hostinfo2label instead. */
char *Host::get_host_label(char *const buf, ssize_t buf_len) {
  char redis_key[CONST_MAX_LEN_REDIS_KEY];
  char ip_buf[64];

  /* Try to get a label first */
  snprintf(redis_key, sizeof(redis_key), HOST_LABEL_NAMES_KEY,
           ip.print(ip_buf, sizeof(ip_buf)));
  if (ntop->getRedis()->get(redis_key, buf, buf_len) != 0) {
    /* Not found, use the internal names instead */
    get_name(buf, buf_len, false /* don't resolve */);
  }

  return buf;
}

/* ***************************************** */

char *Host::getResolvedName(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.resolved ? names.resolved : "");
    m.unlock(__FILE__, __LINE__);
  }

  return Utils::stringtolower(buf);
}

/* ***************************************** */

char *Host::getMDNSName(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.mdns ? names.mdns : "");
    m.unlock(__FILE__, __LINE__);
  }

  return Utils::stringtolower(buf);
}

/* ***************************************** */

char *Host::getServerName(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.server_name ? names.server_name : "");
    m.unlock(__FILE__, __LINE__);
  }

  return Utils::stringtolower(buf);
}

/* ***************************************** */

char *Host::getMDNSTXTName(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.mdns_txt ? names.mdns_txt : "");
    m.unlock(__FILE__, __LINE__);
  }

  return Utils::stringtolower(buf);
}

/* ***************************************** */

char *Host::getMDNSInfo(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.mdns_info ? names.mdns_info : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* ***************************************** */

char *Host::getNetbiosName(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s",
             names.netbios ? Utils::stringtolower(names.netbios) : "");
    m.unlock(__FILE__, __LINE__);
  }

  return buf;
}

/* ***************************************** */

char *Host::getTLSName(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.tls ? names.tls : "");
    m.unlock(__FILE__, __LINE__);
  }

  return Utils::stringtolower(buf);
}

/* ***************************************** */

char *Host::getHTTPName(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_len, "%s", names.http ? names.http : "");
    m.unlock(__FILE__, __LINE__);
  }

  return Utils::stringtolower(buf);
}

/* ***************************************** */

const char *Host::getOSDetail(char *const buf, ssize_t buf_len) {
  if (buf && buf_len) buf[0] = '\0';

  return buf;
}

/* ***************************************** */

bool Host::is_hash_entry_state_idle_transition_ready() {
  u_int32_t max_idle;

  /*
    Idle transition should only be allowed if host has NO alerts engaged.
    This is to always keep in-memory hosts with ongoing issues.

    - For hosts that actively generate traffic, this is achieved automatically
    (active hosts stay in memory).
    - For hosts that stop generating traffic, this is NOT achieved automatically
    (inactive hosts become candidates for purging).

    However, it is not desirable to keep inactive hosts in memory for an
    unlimited amount of time, even if they have ongoing inssues, as this could
    cause OOMs or make ntopng vulnerable to certain attacks.

    For this reason, when an host has ongoing issues, a different (larger)
    maximum idleness is used to:
    - Keep it in memory for a longer time
    - Avoid keeping inactive hosts in memory for an indefinite time
  */

  if (getNumEngagedAlerts() > 0)
    max_idle = ntop->getPrefs()->get_alerted_host_max_idle();
  else
    max_idle = ntop->getPrefs()->get_host_max_idle(isLocalHost());

  bool res = (getUses() == 0) && is_active_entry_now_idle(max_idle);

#if DEBUG_HOST_IDLE_TRANSITION
  char buf[64];
  ntop->getTrace()->traceEvent(
      TRACE_WARNING,
      "Idle check [%s][local: %u][get_host_max_idle: %u][last seen: %u][ready: "
      "%u]",
      ip.print(buf, sizeof(buf)), isLocalHost(),
      ntop->getPrefs()->get_host_max_idle(isLocalHost()), last_seen,
      res ? 1 : 0);
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

  /* Update the pointer to the operating system according to what is specified
   * in cur_os_type, if necessary */
  if (!os || os->get_os_type() != cur_os_type) inlineSetOS(cur_os_type);

  /*
    Update  the operating system, according to what comes from the fingerprint,
    if necessary. The actual pointer will be update above during the next call
   */
  if (cur_os_type == os_unknown && cur_mac && cur_mac->getFingerprint() &&
      (cur_os_from_fingerprint = Utils::getOSFromFingerprint(
           cur_mac->getFingerprint(), cur_mac->get_manufacturer(),
           cur_mac->getDeviceType())) != cur_os_type)
    setOS(cur_os_from_fingerprint);

  if (stats) stats->updateStats(tv);

  GenericHashEntry::periodic_stats_update(tv);

#ifdef DEBUG_SCAN_DETECTION
  if (num_incomplete_flows > 0) {
    char buf[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s: %u",
                                 ip.print(buf, sizeof(buf)),
                                 num_incomplete_flows);
  }
#endif

  custom_periodic_stats_update(tv);
}

/* *************************************** */

void Host::incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
                    ndpi_protocol_category_t ndpi_category,
                    custom_app_t custom_app, u_int64_t sent_packets,
                    u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
                    u_int64_t rcvd_packets, u_int64_t rcvd_bytes,
                    u_int64_t rcvd_goodput_bytes, bool peer_is_unicast) {
  if (sent_bytes || rcvd_bytes) {
    if (stats)
      stats->incStats(when, l4_proto, ndpi_proto, ndpi_category, custom_app,
                      sent_packets, sent_bytes, sent_goodput_bytes,
                      rcvd_packets, rcvd_bytes, rcvd_goodput_bytes,
                      peer_is_unicast);

    updateSeen(when);
  }
}

/* *************************************** */

void Host::serialize(json_object *my_object, DetailsLevel details_level) {
  char buf[96];
  Mac *m = mac;

  if (stats) stats->getJSONObject(my_object, details_level);

  json_object_object_add(my_object, "ip", ip.getJSONObject());
  if (vlan_id != 0)
    json_object_object_add(my_object, "vlan_id", json_object_new_int(vlan_id));
  json_object_object_add(my_object, "mac_address",
                         json_object_new_string(Utils::formatMac(
                             m ? m->get_mac() : NULL, buf, sizeof(buf))));
  json_object_object_add(my_object, "ifid",
                         json_object_new_int(iface->get_id()));

  if (details_level >= details_high) {
    GenericHashEntry::getJSONObject(my_object, details_level);
    json_object_object_add(my_object, "last_stats_reset",
                           json_object_new_int64(last_stats_reset));
    json_object_object_add(my_object, "asn", json_object_new_int(asn));

    get_name(buf, sizeof(buf), false);
    if (strlen(buf))
      json_object_object_add(my_object, "symbolic_name",
                             json_object_new_string(buf));
    if (asname)
      json_object_object_add(
          my_object, "asname",
          json_object_new_string(asname ? asname : (char *)""));

    json_object_object_add(my_object, "localHost",
                           json_object_new_boolean(isLocalHost()));
    json_object_object_add(my_object, "systemHost",
                           json_object_new_boolean(isSystemHost()));
    json_object_object_add(my_object, "broadcastDomainHost",
                           json_object_new_boolean(isBroadcastDomainHost()));
    json_object_object_add(my_object, "is_blacklisted",
                           json_object_new_boolean(isBlacklisted()));
    json_object_object_add(my_object, "is_rx_only",
                           json_object_new_boolean(is_rx_only ? true : false));
    json_object_object_add(my_object, "host_services_bitmap",
                           json_object_new_int(host_services_bitmap));

    /* Generic Host */
    json_object_object_add(my_object, "num_alerts",
                           json_object_new_int(getNumEngagedAlerts()));
  }
}

/* *************************************** */

char *Host::get_visual_name(char *buf, u_int buf_len) {
  bool mask_host = Utils::maskHost(isLocalHost());
  char buf2[64];
  char *sym_name;

  buf[0] = '\0';

  if (mask_host) return buf;

  sym_name = get_name(buf2, sizeof(buf2), false);

  if (sym_name == NULL || !sym_name[0]) return buf;

  strncpy(buf, sym_name, buf_len);
  buf[buf_len - 1] = '\0';

  return buf;
}

/* *************************************** */

bool Host::addIfMatching(lua_State *vm, AddressTree *ptree, char *key) {
  char keybuf[64] = {0}, *keybuf_ptr;
  char ipbuf[64] = {0}, *ipbuf_ptr;
  Mac *m = mac; /* Need to cache them as they can be swapped/updated */

  if (!match(ptree)) return (false);
  keybuf_ptr = get_hostkey(keybuf, sizeof(keybuf));

  if (strcasestr((ipbuf_ptr = Utils::formatMac(m ? m->get_mac() : NULL, ipbuf,
                                               sizeof(ipbuf))),
                 key)                              /* Match by MAC */
      || strcasestr((ipbuf_ptr = keybuf_ptr), key) /* Match by hostkey */
      || strcasestr((ipbuf_ptr = get_visual_name(ipbuf, sizeof(ipbuf))),
                    key)) { /* Match by name */
    lua_push_str_table_entry(vm, keybuf_ptr, ipbuf_ptr);
    return (true);
  }

  return (false);
}

/* *************************************** */

bool Host::addIfMatching(lua_State *vm, u_int8_t *_mac) {
  if (mac && mac->equal(_mac)) {
    char keybuf[64], ipbuf[32];

    lua_push_str_table_entry(vm, get_string_key(ipbuf, sizeof(ipbuf)),
                             get_hostkey(keybuf, sizeof(keybuf)));
    return (true);
  }

  return (false);
}

/* *************************************** */

void Host::incNumFlows(time_t t, bool as_client) {
  /* Called every time a new flow appear */
  NetworkStats *ns = getNetworkStats(get_local_network_id());
  AlertCounter *counter;

  /* Increase network flows */
  if (ns) ns->incNumFlows(last_seen, as_client);

  if (as_client) {
    counter = flow_flood.attacker_counter;
    num_active_flows_as_client++;
  } else {
    counter = flow_flood.victim_counter;
    num_active_flows_as_server++;
  }

  counter->inc(t, this);
  if (stats) stats->incNumFlows(as_client);
}

/* *************************************** */

void Host::decNumFlows(time_t t, bool as_client) {
  if (as_client) {
    num_active_flows_as_client--;
  } else {
    num_active_flows_as_server--;
  }
}

/* *************************************** */

#ifdef HAVE_NEDGE
TrafficShaper *Host::get_shaper(ndpi_protocol ndpiProtocol, bool isIngress) {
  HostPools *hp;
  TrafficShaper *ts = NULL, **shapers = NULL;
  u_int8_t shaper_id = DEFAULT_SHAPER_ID;
  L7Policer *policer;
  L7PolicySource_t policy_source;

  if (!(policer = iface->getL7Policer())) return NULL;
  if (!(hp = iface->getHostPools()))
    return policer->getShaper(PASS_ALL_SHAPER_ID);

  // Avoid setting drop verdicts for wan hosts policy
  if (getMac() && (getMac()->locate() != located_on_lan_interface)) {
    return policer->getShaper(DEFAULT_SHAPER_ID);
  }

  shaper_id = policer->getShaperIdForPool(get_host_pool(), ndpiProtocol,
                                          isIngress, &policy_source);

#ifdef SHAPER_DEBUG
  {
    char buf[64], buf1[64];

    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "[%s] [%s@%u][ndpiProtocol=%d/%s] => [shaper_id=%d]",
        isIngress ? "INGRESS" : "EGRESS", ip.print(buf, sizeof(buf)), vlan_id,
        ndpiProtocol.app_protocol,
        ndpi_protocol2name(iface->get_ndpi_struct(), ndpiProtocol, buf1,
                           sizeof(buf1)),
        shaper_id);
  }
#endif

  if (hp->enforceShapersPerPoolMember(get_host_pool()) &&
      (shapers = host_traffic_shapers) && shaper_id >= 0 &&
      shaper_id < NUM_TRAFFIC_SHAPERS) {
    ts = shapers[shaper_id];

#ifdef SHAPER_DEBUG
    char buf[64], bufs[64];
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "[%s@%u] PER-HOST Traffic shaper: %s",
        ip.print(buf, sizeof(buf)), vlan_id, ts->print(bufs, sizeof(bufs)));
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
  if (ts && ts->shaping_enabled() && ts->get_max_rate_kbit_sec() == 0)
    has_blocking_shaper = true;
  else
    has_blocking_shaper = false;

  return ts;
}
#endif

/* *************************************** */

#ifdef NTOPNG_PRO
bool Host::checkQuota(ndpi_protocol ndpiProtocol,
                      L7PolicySource_t *quota_source, const struct tm *now) {
  bool is_above;
  L7Policer *policer;

  if ((policer = iface->getL7Policer()) == NULL) return false;

  if (stats)
    is_above =
        policer->checkQuota(get_host_pool(), stats->getQuotaEnforcementStats(),
                            ndpiProtocol, quota_source, now);
  else
    is_above = false;

#ifdef SHAPER_DEBUG
  char buf[128], protobuf[32];

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL, "[QUOTA (%s)] [%s@%u] => %s %s",
      ndpi_protocol2name(iface->get_ndpi_struct(), ndpiProtocol, protobuf,
                         sizeof(protobuf)),
      ip.print(buf, sizeof(buf)), vlan_id,
      is_above ? (char *)"EXCEEDED" : (char *)"ok",
      stats->getQuotaEnforcementStats() ? "[QUOTAS enforced per pool member]"
                                        : "");
#endif

  has_blocking_quota |= is_above;
  return is_above;
}

/* *************************************** */

void Host::luaUsedQuotas(lua_State *vm) {
  if (stats) {
    HostPoolStats *quota_stats = stats->getQuotaEnforcementStats();

    if (quota_stats)
      quota_stats->lua(vm, iface);
    else
      lua_newtable(vm);
  }
}
#endif

/* *************************************** */

/* Splits a string in the format hostip@u_int16_t: *buf=hostip,
 * *vlan_id=u_int16_t */
void Host::splitHostVLAN(const char *at_sign_str, char *buf, int bufsize,
                         u_int16_t *vlan_id) {
  int size;
  const char *vlan_ptr = strchr(at_sign_str, '@');

  if (vlan_ptr == NULL) {
    vlan_ptr = at_sign_str + strlen(at_sign_str);
    *vlan_id = 0;
  } else {
    *vlan_id = atoi(vlan_ptr + 1);
  }

  size = min(bufsize, (int)(vlan_ptr - at_sign_str + 1));
  strncpy(buf, at_sign_str, size);
  buf[size - 1] = '\0';
}

/* *************************************** */

void Host::reloadHostBlacklist() {
  ip.reloadBlacklist(iface->get_ndpi_struct());
}

/* *************************************** */

void Host::offlineSetMDNSInfo(char *const str) {
  char *cur_info;
  const char *tokens[] = {"._http._tcp.local",
                          "._sftp-ssh._tcp.local",
                          "._smb._tcp.local",
                          "._device-info._tcp.local",
                          "._privet._tcp.local",
                          "._afpovertcp._tcp.local",
                          NULL};

  if (names.mdns_info || !str) return; /* Already set */

  if (strstr(str, ".ip6.arpa")) return; /* Ignored for the time being */

  for (int i = 0; tokens[i] != NULL; i++) {
    if (strstr(str, tokens[i])) {
      str[strlen(str) - strlen(tokens[i])] = '\0';

      if ((cur_info = strdup(str))) {
        for (i = 0; cur_info[i] != '\0'; i++) {
          if (!isascii(cur_info[i])) cur_info[i] = ' ';
        }

        /* Time to set the actual info */
        names.mdns_info = cur_info;

#ifdef NTOPNG_PRO
        ntop->get_am()->setResolvedName(this, label_mdns_info, names.mdns_info);
#endif
      }

      return;
    }
  }
}

/* *************************************** */

void Host::offlineSetSSDPLocation(const char *url) {
  if (!ssdpLocation && url && (ssdpLocation = strdup(url)))
    ;
}

/* *************************************** */

void Host::offlineSetMDNSName(const char *mdns_n) {
  if (!isValidHostName(mdns_n)) return;

  if (!names.mdns && mdns_n &&
      (names.mdns = Utils::toLowerResolvedNames(mdns_n))) {
#ifdef NTOPNG_PRO
    ntop->get_am()->setResolvedName(this, label_mdns, names.mdns);
#endif
  }
}

/* *************************************** */

void Host::offlineSetMDNSTXTName(const char *mdns_n_txt) {
  if (!names.mdns_txt && mdns_n_txt &&
      (names.mdns_txt = Utils::toLowerResolvedNames(mdns_n_txt))) {
#ifdef NTOPNG_PRO
    ntop->get_am()->setResolvedName(this, label_mdns_txt, names.mdns_txt);
#endif
  }
}

/* *************************************** */

void Host::offlineSetNetbiosName(const char *netbios_n) {
  if (!isValidHostName(netbios_n)) return;

  if (!names.netbios && netbios_n &&
      (names.netbios = Utils::toLowerResolvedNames(netbios_n))) {
#ifdef NTOPNG_PRO
    ntop->get_am()->setResolvedName(this, label_netbios, names.netbios);
#endif
  }
}

/* *************************************** */

void Host::offlineSetTLSName(const char *tls_n) {
  if (!isValidHostName(tls_n)) return;

  if (!names.tls && tls_n && (names.tls = Utils::toLowerResolvedNames(tls_n))) {
#ifdef NTOPNG_PRO
    ntop->get_am()->setResolvedName(this, label_tls, names.tls);
#endif
  }
}

/* *************************************** */

void Host::offlineSetHTTPName(const char *http_n) {
  if (!isValidHostName(http_n)) return;

  if (!names.http && http_n &&
      (names.http = Utils::toLowerResolvedNames(http_n))) {
#ifdef NTOPNG_PRO
    ntop->get_am()->setResolvedName(this, label_http, names.http);
#endif
  }
}

/* *************************************** */

bool Host::isValidHostName(const char *name) {
  /* Make sure we do not use invalid names as strings */
  u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;

  if ((name == NULL) || Utils::endsWith(name, ".ip6.arpa") ||
      Utils::endsWith(name, "._udp.local") ||
      (sscanf(name, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) ==
       4) /* IPv4 address */
      /* Invlid chars */
      || (strchr(name, ':') != NULL) || (strchr(name, '*') != NULL) ||
      (strchr(name, ',') != NULL))
    return (false);

  return (true);
}

/* *************************************** */

void Host::setServerName(const char *server_n) {
  /* Discard invalid strings */

  if (!isValidHostName(server_n)) return;

  if (!names.server_name && server_n &&
      (names.server_name = Utils::toLowerResolvedNames(server_n))) {
#ifdef NTOPNG_PRO
    ntop->get_am()->setResolvedName(this, label_server_name, names.server_name);
#endif
  }
}

/* *************************************** */

void Host::setResolvedName(const char *resolved_name) {
  /* Multiple threads can set this so we must lock */
  if (resolved_name && resolved_name[0] != '\0') {
    m.lock(__FILE__, __LINE__);

    if (!names.resolved /* Don't set hostnames already set */) {
      names.resolved = Utils::toLowerResolvedNames(resolved_name);

#ifdef NTOPNG_PRO
      ntop->get_am()->setResolvedName(this, label_resolver, names.resolved);
#endif
    }

    m.unlock(__FILE__, __LINE__);
  }
}

/* *************************************** */

char *Host::get_country(char *buf, u_int buf_len) {
  char *continent = NULL, *country_name = NULL, *city = NULL;
  float latitude = 0, longitude = 0;

  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city,
                                  &latitude, &longitude);

  if (country_name)
    snprintf(buf, buf_len, "%s", country_name);
  else
    buf[0] = '\0';

  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);

  return (buf);
}

/* *************************************** */

char *Host::get_city(char *buf, u_int buf_len) {
  char *continent = NULL, *country_name = NULL, *city = NULL;
  float latitude = 0, longitude = 0;

  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city,
                                  &latitude, &longitude);

  if (city) {
    snprintf(buf, buf_len, "%s", city);
  } else
    buf[0] = '\0';

  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);

  return (buf);
}

/* *************************************** */

void Host::get_geocoordinates(float *latitude, float *longitude) {
  char *continent = NULL, *country_name = NULL, *city = NULL;

  *latitude = 0, *longitude = 0;
  ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city,
                                  latitude, longitude);
  ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);
}

/* *************************************** */

void Host::serialize_geocoordinates(ndpi_serializer *s, const char *prefix) {
  char *continent = NULL, *country = NULL, *city = NULL, buf[64];
  float latitude = 0, longitude = 0;

  ntop->getGeolocation()->getInfo(&ip, &continent, &country, &city, &latitude,
                                  &longitude);

  if (city) {
    snprintf(buf, sizeof(buf), "%scity_name", prefix);
    ndpi_serialize_string_string(s, buf, city);
  }

  if (country) {
    snprintf(buf, sizeof(buf), "%scountry_name", prefix);
    ndpi_serialize_string_string(s, buf, country);
  }

  if (continent) {
    snprintf(buf, sizeof(buf), "%scontinent_name", prefix);
    ndpi_serialize_string_string(s, buf, continent);
  }

  if (longitude) {
    snprintf(buf, sizeof(buf), "%slocation_lon", prefix);
    ndpi_serialize_string_float(s, buf, longitude, "%f");
  }

  if (latitude) {
    snprintf(buf, sizeof(buf), "%slocation_lat", prefix);
    ndpi_serialize_string_float(s, buf, latitude, "%f");
  }

  ntop->getGeolocation()->freeInfo(&continent, &country, &city);
}

/* *************************************** */

bool Host::isUnidirectionalTraffic() const {
  /* When both directions are at zero, it means no periodic update has visited
     the host yet, so nothing can be said about its traffic directions. One way
     is only returned when exactly one direction is greater than zero. */
  return (stats ? stats->getNumBytes() &&
                      !(stats->getNumBytesRcvd() && stats->getNumBytesSent())
                : false);
};

/* *************************************** */

bool Host::isBidirectionalTraffic() const {
  return (stats ? stats->getNumBytesRcvd() && stats->getNumBytesSent() : false);
}

/* *************************************** */

DeviceProtoStatus Host::getDeviceAllowedProtocolStatus(ndpi_protocol proto,
                                                       bool as_client) {
  if (getMac() &&
      !getMac()->isSpecialMac()
#ifdef HAVE_NEDGE
      /* On nEdge the concept of device protocol policies is only applied to
         unassigned devices on LAN */
      && (getMac()->locate() == located_on_lan_interface)
#endif
  )
    return ntop->getDeviceAllowedProtocolStatus(
        getMac()->getDeviceType(), proto, get_host_pool(), as_client);

  return device_proto_allowed;
}

/* *************************************** */

bool Host::statsResetRequested() {
  return (stats_reset_requested ||
          (last_stats_reset < ntop->getLastStatsReset()));
}

/* *************************************** */

void Host::blacklistedStatsResetRequested() {
  num_blacklisted_flows.checkpoint_as_client = num_blacklisted_flows.as_client;
  num_blacklisted_flows.checkpoint_as_server = num_blacklisted_flows.as_server;
}

/* *************************************** */

void Host::checkStatsReset() {
  if (stats_shadow) {
    delete stats_shadow;
    stats_shadow = NULL;
  }

  if (statsResetRequested()) {
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
    stats_reset_requested = 0;
  }
}

/* *************************************** */

void Host::checkBroadcastDomain() {
  if (iface->reloadHostsBroadcastDomain())
    is_in_broadcast_domain =
        iface->isLocalBroadcastDomainHost(this, false /* Non-inline call */);
}

/* *************************************** */

void Host::freeHostNames() {
  if (ssdpLocation) {
    free(ssdpLocation);
    ssdpLocation = NULL;
  }
  if (names.http) {
    free(names.http);
    names.http = NULL;
  }
  if (names.mdns) {
    free(names.mdns);
    names.mdns = NULL;
  }
  if (names.mdns_info) {
    free(names.mdns_info);
    names.mdns_info = NULL;
  }
  if (names.mdns_txt) {
    free(names.mdns_txt);
    names.mdns_txt = NULL;
  }
  if (names.netbios) {
    free(names.netbios);
    names.netbios = NULL;
  }
  if (names.resolved) {
    free(names.resolved);
    names.resolved = NULL;
  }
  if (names.server_name) {
    free(names.server_name);
    names.server_name = NULL;
  }
  if (names.tls) {
    free(names.tls);
    names.tls = NULL;
  }
}

/* *************************************** */

void Host::resetHostNames() {
  m.lock(__FILE__, __LINE__);
  freeHostNames();
  m.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void Host::checkNameReset() {
  if (name_reset_requested) {
    resetHostNames();
    name_reset_requested = 0;
  }
}

/* *************************************** */

void Host::deleteHostData() {
  resetHostNames();
  first_seen = last_seen;
}

/* *************************************** */

void Host::checkDataReset() {
  if (data_delete_requested) {
    deleteHostData();
    data_delete_requested = 0;
  }
}

/* *************************************** */

char *Host::get_mac_based_tskey(Mac *mac, char *buf, size_t bufsize,
                                bool skip_prefix) {
  char *k = mac ? Utils::formatMac(mac->get_mac(), buf, bufsize)
                : Utils::formatMac(NULL, buf, bufsize);

  if (!skip_prefix) {
    /* NOTE: it is important to differentiate between v4 and v6 for macs */
    strncat(buf, get_ip()->isIPv4() ? "_v4" : "_v6", bufsize);
  }

  return (k);
}

/* *************************************** */

/*
  Private method, called periodically to update the OperatingSystem os pointer
  to what is set in os_type by setters using setOS
 */
void Host::inlineSetOS(OSType _os) {
  if (!os || os->get_os_type() != _os) {
    if (os) os->decUses();

    if ((os = iface->getOS(_os, true /* Create if missing */,
                           true /* Inline call */)) != NULL)
      os->incUses();
  }
}

/* *************************************** */

/*
  Public method to set the operating system
 */
void Host::setOS(OSType _os) {
  Mac *mac = getMac();

  if (!mac || (mac->getDeviceType() != device_networking)) os_type = _os;
}

/* *************************************** */

OSType Host::getOS() const { return os_type; }

/* *************************************** */

void Host::incOSStats(time_t when, u_int16_t proto_id, u_int64_t sent_packets,
                      u_int64_t sent_bytes, u_int64_t rcvd_packets,
                      u_int64_t rcvd_bytes) {
  OperatingSystem *cur_os = os; /* Cache the pointer as it can change (similar
                                   to what is done for MAC addresses) */

  if (cur_os)
    cur_os->incStats(when, proto_id, sent_packets, sent_bytes, rcvd_packets,
                     rcvd_bytes);
}

/* *************************************** */

char *Host::get_tskey(char *buf, size_t bufsize) {
  char *k;
  Mac *cur_mac = getMac(); /* Cache macs as they can be swapped/updated */

  if (serializeByMac())
    k = get_mac_based_tskey(cur_mac, buf, bufsize);
  else
    k = get_hostkey(buf, bufsize);

  return (k);
}

/* *************************************** */

void Host::refreshDisabledAlerts() {
#ifdef NTOPNG_PRO
  AlertExclusions *ntop_alert_exclusions = ntop->getAlertExclusions();

  if (ntop_alert_exclusions &&
      ntop_alert_exclusions->checkChange(&disabled_alerts_tstamp)) {
    /* Set alert exclusion into the host */
    ntop_alert_exclusions->setDisabledHostAlertsBitmaps(this);
  }
#endif
}

/* *************************************** */

bool Host::isHostAlertDisabled(HostAlertType alert_type) {
  refreshDisabledAlerts();

#ifdef NTOPNG_PRO
  return (alert_exclusions.isSetHostExclusionBit(alert_type.id));
#else
  return false;
#endif
}

/* *************************************** */

bool Host::isFlowAlertDisabled(FlowAlertType alert_type) {
  refreshDisabledAlerts();

#ifdef NTOPNG_PRO
  return (alert_exclusions.isSetFlowExclusionBit(alert_type.id));
#else
  return false;
#endif
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
  ndpi_serialize_string_int32(s, "observation_point_id",
                              get_observation_point_id());
  ndpi_serialize_string_int32(s, "entity_id", alert_entity_host);
  ndpi_serialize_string_string(s, "entity_val", getEntityValue().c_str());
  ndpi_serialize_string_uint32(s, "tstamp", alert->getEngageTime());
  ndpi_serialize_string_uint32(s, "tstamp_end", alert->getReleaseTime());
  ndpi_serialize_string_boolean(s, "is_attacker", alert->isAttacker());
  ndpi_serialize_string_boolean(s, "is_victim", alert->isVictim());
  ndpi_serialize_string_boolean(s, "is_client", alert->isClient());
  ndpi_serialize_string_boolean(s, "is_server", alert->isServer());
  ndpi_serialize_string_int32(s, "host_pool_id", get_host_pool());
  ndpi_serialize_string_int32(s, "network", (u_int16_t)get_local_network_id());

  serialize_geocoordinates(s, "");

  HostCheck *cb = getInterface()->getCheck(alert->getCheckType());
  ndpi_serialize_string_int32(s, "granularity", cb ? cb->getPeriod() : 0);

  alert_json_serializer = alert->getSerializedAlert();

  if (alert_json_serializer)
    alert_json =
        ndpi_serializer_get_buffer(alert_json_serializer, &alert_json_len);

  ndpi_serialize_string_string(s, "json", alert_json ? alert_json : "");

  if (alert_json_serializer) {
    ndpi_term_serializer(alert_json_serializer);
    free(alert_json_serializer);
  }
}

/* *************************************** */

/* Enqueue alert to recipients */ 
bool Host::enqueueAlertToRecipients(HostAlert *alert, bool released) {
  bool rv = false;
  u_int32_t buflen;
  AlertFifoItem *notification;
  ndpi_serializer host_json;
  const char *host_str;
  const char *instance_name;

  ndpi_init_serializer(&host_json, ndpi_serialization_format_json);

  /* Prepare the JSON, including a JSON specific of this HostAlertType */
  alert2JSON(alert, released, &host_json);

  host_str = ndpi_serializer_get_buffer(&host_json, &buflen);

  notification = new AlertFifoItem();

  if (notification) {
    notification->alert = (char *)host_str;
    notification->score = alert->getAlertScore();
    notification->alert_severity = Utils::mapScoreToSeverity(notification->score);
    notification->alert_category = alert->getAlertType().category;
    notification->host.host_pool = get_host_pool();

    rv = ntop->recipients_enqueue(notification,
                                  alert_entity_host /* Host recipients */);

    if (!rv)
      delete notification;

    if (iface->isSmartRecordingEnabled() && (instance_name = iface->getSmartRecordingInstance())) {
      char key[256], ip_buf[64];
      int expiration = 30*60; /* 30 min */

      /* Note: see alerts_api.lua: pushSmartRecordingFilter() for alerts triggered from Lua */

      if (alert->isReleased() && alert->isLastReleased()) {
        /* Relased: 30 min expiration to make sure n2disk data is processed */
        expiration = 30*60;
      } else {
        /* Engaged: expiration will be set on release
         * Note: setting a 24h expiration as upper bound to stay on the safe side */
        expiration = 24*60*60;
      }

      snprintf(key, sizeof(key), "n2disk.%s.filter.host.%s", instance_name,
        get_ip()->print(ip_buf, sizeof(ip_buf)));

      ntop->getRedis()->set(key, "1", expiration);
    }
  }

  if (!rv)
    getInterface()->incNumDroppedAlerts(alert_entity_host);

  ndpi_term_serializer(&host_json);

  if (released) delete alert;

  return rv;
}

/* **************************************************** */

/* Call this when setting host idle (before removing it from memory) */
void Host::releaseAllEngagedAlerts() {
  for (u_int i = 0; i < NUM_DEFINED_HOST_CHECKS; i++) {
    HostCheckID t = (HostCheckID)i;
    HostAlert *alert = getCheckEngagedAlert(t);
    if (alert) {
      releaseAlert(alert);
    }
  }
}

/* *************************************** */

/*
 * This is called by the Check to trigger an alert
 */
bool Host::triggerAlert(HostAlert *alert) {
  ScoreCategory score_category;
  HostAlertType alert_type;

  if (alert == NULL) return false;

  alert_type = alert->getAlertType();

  if (ntop->getPrefs()->dontEmitHostAlerts() /* all host alerts disabled */ ||
      isHostAlertDisabled(
          alert_type) /* alerts disabled for this host and type */) {
#ifdef DEBUG_SCORE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Discarding disabled alert");
#endif
    if (getCheckEngagedAlert(alert->getCheckType()) ==
        alert)              /* Alert is engaged */
      alert->setExpiring(); /* Mark this alert as expiring to have it released
                               soon */
    else                    /* Triggered alert is not yet engaged */
      delete alert; /* Delete it right now, don't even let it continue */

    return false;
  }

  /* Leave this AFTER the isHostAlertDisabled check */
  alert->setEngaged();

  if (hasCheckEngagedAlert(alert->getCheckType())) {
    if (getCheckEngagedAlert(alert->getCheckType()) == alert) {
      /* This is a refresh (see alert->isExpired()) */
      return true;
    } else {
      ntop->getTrace()->traceEvent(
          TRACE_WARNING,
          "Internal Error: One engaged alert is allowed per check");
      delete alert;
      return false;
    }
  }

#ifdef DEBUG_SCORE
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Set host score %u/%u",
                               score_as_cli / score_as_srv);
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

  /* Mark this alert as last engaged if there are no more engaged alerts */
  if (!getNumEngagedAlerts())
    alert->setLastReleased();

  /* Dec score */
  score_category =
      Utils::mapAlertToScoreCategory(alert->getAlertType().category);
  decScoreValue(alert->getCliScore(), score_category, true /* as client */);
  decScoreValue(alert->getSrvScore(), score_category, false /* as server */);

  /* Enqueue the released alert to be notified */
  iface->enqueueHostAlert(alert);
}

/* *************************************** */

/*
 * This is called by the Check to store an alert (trigger as already released)
 */
bool Host::storeAlert(HostAlert *alert) {
  HostAlertType alert_type;

  if (alert == NULL) return false;

  alert_type = alert->getAlertType();

  if (ntop->getPrefs()->dontEmitHostAlerts() /* all host alerts disabled */ ||
      isHostAlertDisabled(
          alert_type) /* alerts disabled for this host and type */) {
#ifdef DEBUG_SCORE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Discarding disabled alert");
#endif
    delete alert;
    return false;
  }

  /* Enqueue the alert to be notified */
  iface->enqueueHostAlert(alert);

  /* Set as released */
  alert->release();

  if (!getNumEngagedAlerts())
    alert->setLastReleased();

  /* Enqueue the released alert to be notified */
  iface->enqueueHostAlert(alert);

  return true;
}

/* *************************************** */

u_int16_t Host::get_country_code() {
  if (country) {
    char *country_name = country->get_country_name();

    if (country_name) return (Utils::countryCode2U16(country_name));
  } /* No else here */

  return (0); /* Not found */
}

/* *************************************** */

/* Visit the host and add it to the vector */
void Host::visit(std::vector<ActiveHostWalkerInfo> *v, HostWalkMode mode) {
  char buf[64], key[96], *label = get_visual_name(buf, sizeof(buf));
  u_int64_t tot;

  if (get_vlan_id() == 0)
    snprintf(key, sizeof(key), "%s", printMask(buf, sizeof(buf)));
  else
    snprintf(key, sizeof(key), "%s@%u", printMask(buf, sizeof(buf)),
             get_vlan_id());

  if (label[0] == '\0') label = key;

  switch (mode) {
    case ALL_FLOWS:
      v->push_back(ActiveHostWalkerInfo(key, label, getNumIncomingFlows(),
                                        getNumOutgoingFlows(),
                                        getNumBytesSent() + getNumBytesRcvd()));
      break;

    case UNREACHABLE_FLOWS:
      v->push_back(ActiveHostWalkerInfo(key, label,
                                        getTotalNumUnreachableIncomingFlows(),
                                        getTotalNumUnreachableOutgoingFlows(),
                                        getNumBytesSent() + getNumBytesRcvd()));
      break;

    case ALERTED_FLOWS:
      tot =
          getTotalNumAlertedIncomingFlows() + getTotalNumAlertedOutgoingFlows();

      if (tot > 0)
        v->push_back(
            ActiveHostWalkerInfo(key, label, getTotalNumAlertedIncomingFlows(),
                                 getTotalNumAlertedOutgoingFlows(), tot));
      break;

    case DNS_QUERIES: {
      DnsStats *dns = getDNSstats();

      if (dns) {
        tot = dns->getRcvdNumRepliesOk() + dns->getSentNumQueries();

        if (tot > 0)
          v->push_back(ActiveHostWalkerInfo(key, label,
                                            dns->getRcvdNumRepliesOk(),
                                            dns->getSentNumQueries(), tot));
      }
    } break;

    case SYN_DISTRIBUTION: {
      HostStats *stats = getStats();

      if (stats) {
        tot = getNumOutgoingFlows() + getNumIncomingFlows();

        if (tot > 0)
          v->push_back(ActiveHostWalkerInfo(
              key, label, stats->getSentStats()->getNumSYN(),
              stats->getRecvStats()->getNumSYN(), tot));
      }
    } break;

    case SYN_VS_RST: {
      HostStats *stats = getStats();

      if (stats) {
        tot = getNumOutgoingFlows() + getNumIncomingFlows();

        if (tot > 0)
          v->push_back(ActiveHostWalkerInfo(
              key, label, stats->getSentStats()->getNumSYN(),
              stats->getRecvStats()->getNumRST(), tot));
      }
    } break;

    case SYN_VS_SYNACK: {
      HostStats *stats = getStats();

      if (stats) {
        tot = getNumOutgoingFlows() + getNumIncomingFlows();

        if (tot > 0)
          v->push_back(ActiveHostWalkerInfo(
              key, label, stats->getSentStats()->getNumSYN(),
              stats->getRecvStats()->getNumSYNACK(), tot));
      }
    } break;

    case TCP_PKTS_SENT_VS_RCVD: {
      HostStats *stats = getStats();

      if (stats) {
        L4Stats *l4 = stats->getL4Stats();

        if (l4) {
          tot =
              l4->getTCPSent()->getNumBytes() + l4->getTCPRcvd()->getNumBytes();

          if (tot > 0)
            v->push_back(
                ActiveHostWalkerInfo(key, label, l4->getTCPSent()->getNumPkts(),
                                     l4->getTCPRcvd()->getNumPkts(), tot));
        }
      }
    } break;

    case TCP_BYTES_SENT_VS_RCVD: {
      HostStats *stats = getStats();

      if (stats) {
        L4Stats *l4 = stats->getL4Stats();

        if (l4) {
          tot =
              l4->getTCPSent()->getNumBytes() + l4->getTCPRcvd()->getNumBytes();

          if (tot > 0)
            v->push_back(ActiveHostWalkerInfo(
                key, label, l4->getTCPSent()->getNumBytes(),
                l4->getTCPRcvd()->getNumBytes(), tot));
        }
      }
    } break;

    case ACTIVE_ALERT_FLOWS:
      if (getNumAlertedFlows() > 0)
        v->push_back(ActiveHostWalkerInfo(key, label, getNumIncomingFlows(),
                                          getNumOutgoingFlows(),
                                          getNumAlertedFlows()));
      break;

    case TRAFFIC_RATIO: {
      float bytes_ratio =
          ndpi_data_ratio(getNumBytesSent(), getNumBytesRcvd()) * 100.;
      float pkts_ratio =
          ndpi_data_ratio(getNumPktsSent(), getNumPktsRcvd()) * 100.;

      tot = getNumBytesSent() + getNumBytesRcvd();

      if (tot > 0)
        v->push_back(
            ActiveHostWalkerInfo(key, label, bytes_ratio, pkts_ratio, tot));
    } break;

    case SCORE:
      tot = getScoreAsClient() + getScoreAsServer();

      if (tot > 0)
        v->push_back(ActiveHostWalkerInfo(key, label, getScoreAsClient(),
                                          getScoreAsServer(), tot));
      break;

    case BLACKLISTED_FLOWS_HOSTS:
      tot = num_blacklisted_flows.as_client + num_blacklisted_flows.as_server;

      if (tot > 0)
        v->push_back(
            ActiveHostWalkerInfo(key, label, num_blacklisted_flows.as_client,
                                 num_blacklisted_flows.as_server, tot));
      break;

    case HOSTS_TCP_FLOWS_UNIDIRECTIONAL:
      tot = unidirectionalTCPUDPFlows.numIngressFlows +
            unidirectionalTCPUDPFlows.numEgressFlows;

      if (tot > 0)
        v->push_back(ActiveHostWalkerInfo(
            key, label, unidirectionalTCPUDPFlows.numEgressFlows,
            unidirectionalTCPUDPFlows.numIngressFlows, tot));
      break;
  }
}

/* *************************************** */

void Host::setDhcpServer(char *name) {
  if (!isDhcpServer()) {
    host_services_bitmap |= 1 << HOST_IS_DHCP_SERVER;

#ifdef NTOPNG_PRO
    ntop->get_am()->setServerInfo(this, dhcp_server, name);
#endif
  }
}

/* *************************************** */

void Host::setDnsServer(char *name) {
  if (!isDnsServer()) {
    host_services_bitmap |= 1 << HOST_IS_DNS_SERVER;

#ifdef NTOPNG_PRO
    ntop->get_am()->setServerInfo(this, dns_server, name);
#endif
  }
}

/* *************************************** */

void Host::setSmtpServer(char *name) {
  if (!isSmtpServer()) {
    host_services_bitmap |= 1 << HOST_IS_SMTP_SERVER;

#ifdef NTOPNG_PRO
    ntop->get_am()->setServerInfo(this, smtp_server, name);
#endif
  }
}

/* *************************************** */

void Host::setNtpServer(char *name) {
  if (!isNtpServer()) {
    host_services_bitmap |= 1 << HOST_IS_NTP_SERVER;

#ifdef NTOPNG_PRO
    ntop->get_am()->setServerInfo(this, ntp_server, name);
#endif
  }
}

/* *************************************** */

void Host::setImapServer(char *name) {
  if (!isImapServer()) {
    host_services_bitmap |= 1 << HOST_IS_IMAP_SERVER;

#ifdef NTOPNG_PRO
    ntop->get_am()->setServerInfo(this, imap_server, name);
#endif
  }
}

/* *************************************** */

void Host::setPopServer(char *name) {
  if (!isPopServer()) {
    host_services_bitmap |= 1 << HOST_IS_POP_SERVER;

#ifdef NTOPNG_PRO
    ntop->get_am()->setServerInfo(this, pop_server, name);
#endif
  }
}

/* *************************************** */

void Host::setBlacklistName(char *name) {
  if ((blacklist_name == NULL) && (name != NULL)) blacklist_name = strdup(name);
}

/* *************************************** */

/* The alert will be triggered by src/host_checks/CustomHostLuaScript.cpp */

void Host::triggerCustomHostAlert(u_int8_t score, char *msg) {
  customHostAlert.alertTriggered = true, customHostAlert.score = score;

  if (customHostAlert.msg) {
    free(customHostAlert.msg);
    customHostAlert.msg = NULL;
  }

  if (msg) customHostAlert.msg = strdup(msg);
}

/* *************************************** */

/*
  Used to estimate the cardinality of <server, server_port> contacted
  by this host over TCP or UDP and with no data received or connection refused
*/
void Host::setUnidirectionalTCPUDPNoTXEgressFlow(IpAddress *ip,
                                                 u_int16_t port) {
  ndpi_hll_add_number(&outgoing_hosts_tcp_udp_port_with_no_tx_hll,
                      ip->key() + (port << 8));  // Simple hash
}

/* *************************************** */

/*
  Used to estimate the cardinality of <client, server_port> that contacted
  this host over TCP or UDP and with no data replied (i.e. this host has not
  replied them back)
*/
void Host::setUnidirectionalTCPUDPNoTXIngressFlow(IpAddress *ip,
                                                  u_int16_t port) {
  ndpi_hll_add_number(&incoming_hosts_tcp_udp_port_with_no_tx_hll,
                      ip->key() + (port << 8));  // Simple hash
}

/* *************************************** */

void Host::resetHostContacts() {
  ndpi_hll_reset(&outgoing_hosts_tcp_udp_port_with_no_tx_hll);
  ndpi_hll_reset(&incoming_hosts_tcp_udp_port_with_no_tx_hll);
  ndpi_bitmap_clear(tcp_udp_contacted_ports_no_tx);
}
