/*
 *
 * (C) 2013-18 - ntop.org
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

  if(top_sites)       delete top_sites;
  if(old_sites)       free(old_sites);
  if(dns)             delete dns;
  if(http)            delete http;
  if(icmp)            delete icmp;

  if(syn_flood_attacker_alert)  delete syn_flood_attacker_alert;
  if(syn_flood_victim_alert)    delete syn_flood_victim_alert;
  if(flow_flood_attacker_alert) delete flow_flood_attacker_alert;
  if(flow_flood_victim_alert)   delete flow_flood_victim_alert;
}

/* *************************************** */

void LocalHost::initialize() {
  char key[64], redis_key[128], *k;
  char buf[64];

  local_network_id = -1;
  nextSitesUpdate = 0;
  top_sites = new FrequentStringItems(HOST_SITES_TOP_NUMBER);
  old_sites = strdup("{}");
  dhcpUpdated = false;
  icmp = NULL;
  num_alerts_detected = 0;
  drop_all_host_traffic = false, dump_host_traffic = false;
  trigger_host_alerts = false;

  os[0] = '\0';

  ip.isLocalHost(&local_network_id);
  networkStats = getNetworkStats(local_network_id);

  systemHost = ip.isLocalInterfaceAddress();

  readDHCPCache();

  dns  = new DnsStats();
  http = new HTTPstats(iface->get_hosts_hash());

  if(ntop->getPrefs()->is_idle_local_host_cache_enabled()) {
    char *json = NULL;

    k = ip.print(key, sizeof(key));
    snprintf(redis_key, sizeof(redis_key), HOST_SERIALIZED_KEY, iface->get_id(), k, vlan_id);

    if((json = (char*)malloc(HOST_MAX_SERIALIZED_LEN * sizeof(char))) == NULL)
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to allocate memory to deserialize %s", redis_key);
    else if(!ntop->getRedis()->get(redis_key, json, HOST_MAX_SERIALIZED_LEN)){
	/* Found saved copy of the host so let's start from the previous state */
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s => %s", redis_key, json);
	ntop->getTrace()->traceEvent(TRACE_INFO, "Deserializing %s", redis_key);

	deserialize(json, redis_key);
      }

      if(json) free(json);
    }

  attacker_max_num_syn_per_sec = ntop->getPrefs()->get_attacker_max_num_syn_per_sec();
  victim_max_num_syn_per_sec = ntop->getPrefs()->get_victim_max_num_syn_per_sec();
  attacker_max_num_flows_per_sec = ntop->getPrefs()->get_attacker_max_num_flows_per_sec();
  victim_max_num_flows_per_sec = ntop->getPrefs()->get_victim_max_num_flows_per_sec();

  syn_flood_attacker_alert = new AlertCounter(attacker_max_num_syn_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
  syn_flood_victim_alert = new AlertCounter(victim_max_num_syn_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
  flow_flood_attacker_alert = new AlertCounter(attacker_max_num_flows_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
  flow_flood_victim_alert = new AlertCounter(victim_max_num_flows_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);

  char host[96];
  char *strIP = ip.print(buf, sizeof(buf));
  snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);
  char rsp[256];

  if(ntop->getRedis()->getAddress(host, rsp, sizeof(rsp), true) == 0)
    setName(rsp);

  updateHostTrafficPolicy(host);

  iface->incNumHosts(true /* Local Host */);

  refreshHostAlertPrefs();

#ifdef LOCALHOST_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s is %s [%p]",
			       ip.print(buf, sizeof(buf)),
			       isSystemHost() ? "systemHost" : "", this);
#endif
}

/* *************************************** */

void LocalHost::loadAlertsCounter() {
  char buf[64], counters_key[64];
  char rsp[16];
  char *key = get_hostkey(buf, sizeof(buf), true /* force vlan */);

  if(ntop->getPrefs()->are_alerts_disabled()) {
    num_alerts_detected = 0;
    return;
  }

  snprintf(counters_key, sizeof(counters_key), CONST_HOSTS_ALERT_COUNTERS, iface->get_id());

  if (ntop->getRedis()->hashGet(counters_key, key, rsp, sizeof(rsp)) == 0)
    num_alerts_detected = atoi(rsp);
  else
    num_alerts_detected = 0;

#if 0
  printf("%s: num_alerts_detected = %d\n", key, num_alerts_detected);
#endif
}

/* *************************************** */

void LocalHost::incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {
  if(!icmp) icmp = new ICMPstats();
  if(icmp)  icmp->incStats(icmp_type, icmp_code, sent, peer);
}

/* *************************************** */

void LocalHost::incNumFlows(bool as_client) {
  AlertCounter *counter;

  Host::incNumFlows(as_client);

  if(as_client)
    counter = flow_flood_attacker_alert;
  else
    counter = flow_flood_victim_alert;

  if(triggerAlerts())
    counter->incHits(time(0));
}

/* *************************************** */

void LocalHost::incrVisitedWebSite(char *hostname) {
  u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
  char *firstdot = NULL, *nextdot = NULL;

  if(top_sites
     && ntop->getPrefs()->are_top_talkers_enabled()
     && (strstr(hostname, "in-addr.arpa") == NULL)
     && (sscanf(hostname, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) != 4)
     ) {
    if(ntop->isATrackerHost(hostname)) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "[TRACKER] %s", hostname);
      return; /* Ignore trackers */
    }

    firstdot = strchr(hostname, '.');

    if(firstdot)
      nextdot = strchr(&firstdot[1], '.');

    top_sites->add(nextdot ? &firstdot[1] : hostname, 1);
  }
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

json_object* LocalHost::getJSONObject() {
  json_object *my_object = Host::getJSONObject();

  if(dns)  json_object_object_add(my_object, "dns", dns->getJSONObject());
  if(http) json_object_object_add(my_object, "http", http->getJSONObject());

  return(my_object);
}

/* *************************************** */

void LocalHost::serialize2redis() {
  if((ntop->getPrefs()->is_idle_local_host_cache_enabled()
      || ntop->getPrefs()->is_active_local_host_cache_enabled())
     && (!ip.isEmpty())) {
    char *json = serialize();
    char host_key[128], key[128];
    char *k = ip.print(host_key, sizeof(host_key));

    snprintf(key, sizeof(key), HOST_SERIALIZED_KEY, iface->get_id(), k, vlan_id);
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

  if(json_object_object_get_ex(o, "symbolic_name", &obj))  { if(symbolic_name) free(symbolic_name); symbolic_name = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "os", &obj))             { snprintf(os, sizeof(os), "%s", json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "tcp_sent", &obj))  tcp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "tcp_rcvd", &obj))  tcp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "udp_sent", &obj))  udp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "udp_rcvd", &obj))  udp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "icmp_sent", &obj))  icmp_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "icmp_rcvd", &obj))  icmp_rcvd.deserialize(obj);
  if(json_object_object_get_ex(o, "other_ip_sent", &obj))  other_ip_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "other_ip_rcvd", &obj))  other_ip_rcvd.deserialize(obj);

  /* packet stats */
  if(json_object_object_get_ex(o, "pktStats.sent", &obj))  sent_stats.deserialize(obj);
  if(json_object_object_get_ex(o, "pktStats.recv", &obj))  recv_stats.deserialize(obj);

  /* TCP packet stats */
  if(json_object_object_get_ex(o, "tcpPacketStats.pktRetr", &obj)) tcpPacketStats.pktRetr = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "tcpPacketStats.pktOOO",  &obj)) tcpPacketStats.pktOOO  = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "tcpPacketStats.pktLost", &obj)) tcpPacketStats.pktLost = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "tcpPacketStats.pktKeepAlive", &obj)) tcpPacketStats.pktKeepAlive = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "flows.as_client", &obj))  total_num_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "flows.as_server", &obj))  total_num_flows_as_server = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "flows.dropped", &obj))    total_num_dropped_flows   = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "sent", &obj))  sent.deserialize(obj);
  if(json_object_object_get_ex(o, "rcvd", &obj))  rcvd.deserialize(obj);
  last_bytes = sent.getNumBytes() + rcvd.getNumBytes();
  last_packets = sent.getNumPkts() + rcvd.getNumPkts();

  if(json_object_object_get_ex(o, "total_activity_time", &obj))  total_activity_time = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "dns", &obj)) {
    if(dns) dns->deserialize(obj);
  }

  if(json_object_object_get_ex(o, "http", &obj)) {
    if(http) http->deserialize(obj);
  }

  if(ndpiStats) {
    delete ndpiStats;
    ndpiStats = NULL;
  }

  if(json_object_object_get_ex(o, "ndpiStats", &obj)) {
    ndpiStats = new nDPIStats();
    ndpiStats->deserialize(iface, obj);
  }

  /* We commented the line below to avoid strings too long */
#if 0
  activityStats.reset();
  if(json_object_object_get_ex(o, "activityStats", &obj)) activityStats.deserialize(obj);
#endif

  if(json_object_object_get_ex(o, "pktStats.sent", &obj)) sent_stats.deserialize(obj);
  if(json_object_object_get_ex(o, "pktStats.recv", &obj)) recv_stats.deserialize(obj);

  json_object_put(o);

  return(true);
}

/* *************************************** */

void LocalHost::updateSynFlags(time_t when, u_int8_t flags, Flow *f, bool syn_sent) {
  AlertCounter *counter = syn_sent ? syn_flood_attacker_alert : syn_flood_victim_alert;

  if(triggerAlerts())
    counter->incHits(when);
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

  if((ntop->getRedis()->hashGet((char*)DUMP_HOST_TRAFFIC,
				host, buf, sizeof(buf)) == -1)
     || (strcmp(buf, "true") != 0))
    dump_host_traffic = false;
  else
    dump_host_traffic = true;
}

/* *************************************** */

void LocalHost::setDumpTrafficPolicy(bool new_policy) {
  char buf[64], *host;

  if(dump_host_traffic == new_policy)
    return; /* Nothing to do */
  else
    dump_host_traffic = new_policy;

  host = get_hostkey(buf, sizeof(buf), true);

  ntop->getRedis()->hashSet((char*)DUMP_HOST_TRAFFIC, host,
			    (char*)(dump_host_traffic ? "true" : "false"));
};

/* *************************************** */

bool LocalHost::hasAnomalies() {
  time_t now = time(0);

  return syn_flood_victim_alert->isAboveThreshold(now)
    || syn_flood_attacker_alert->isAboveThreshold(now)
    || flow_flood_victim_alert->isAboveThreshold(now)
    || flow_flood_attacker_alert->isAboveThreshold(now);
}

/* *************************************** */

void LocalHost::luaAnomalies(lua_State* vm) {
  if(!vm)
    return;

  if(hasAnomalies()) {
    time_t now = time(0);
    lua_newtable(vm);

    if(syn_flood_victim_alert->isAboveThreshold(now))
      syn_flood_victim_alert->lua(vm, "syn_flood_victim");
    if(syn_flood_attacker_alert->isAboveThreshold(now))
      syn_flood_attacker_alert->lua(vm, "syn_flood_attacker");
    if(flow_flood_victim_alert->isAboveThreshold(now))
      flow_flood_victim_alert->lua(vm, "flows_flood_victim");
    if(flow_flood_attacker_alert->isAboveThreshold(now))
      flow_flood_attacker_alert->lua(vm, "flows_flood_attacker");

    lua_pushstring(vm, "anomalies");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
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

  if((!mask_host) && top_sites && ntop->getPrefs()->are_top_talkers_enabled()) {
    char *cur_sites = top_sites->json();
    lua_push_str_table_entry(vm, "sites", cur_sites ? cur_sites : (char*)"{}");
    lua_push_str_table_entry(vm, "sites.old", old_sites ? old_sites : (char*)"{}");
    if(cur_sites) free(cur_sites);
  }

  lua_push_int32_table_entry(vm, "local_network_id", local_network_id);

  local_net = ntop->getLocalNetworkName(local_network_id);
  if(local_net == NULL)
    lua_push_nil_table_entry(vm, "local_network_name");
  else
    lua_push_str_table_entry(vm, "local_network_name", local_net);

  /* Criteria */
  lua_newtable(vm);

  lua_push_int_table_entry(vm, "upload", getNumBytesSent());
  lua_push_int_table_entry(vm, "download", getNumBytesRcvd());
  lua_push_int_table_entry(vm, "unknown", get_ndpi_stats()->getProtoBytes(NDPI_PROTOCOL_UNKNOWN));
  lua_push_int_table_entry(vm, "incomingflows", getNumIncomingFlows());
  lua_push_int_table_entry(vm, "outgoingflows", getNumOutgoingFlows());

  lua_pushstring(vm, "criteria");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  if(host_details) {
    if(icmp)
      icmp->lua(ip.isIPv4(), vm);
  }

  if(verbose) {
    if(dns)            dns->lua(vm);
    if(http)           http->lua(vm);

    if(hasAnomalies()) luaAnomalies(vm);
  }

  if(asListElement) {
    host_id = get_hostkey(buf_id, sizeof(buf_id));

    lua_pushstring(vm, host_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void LocalHost::refreshHostAlertPrefs() {
  bool alerts_read = false;

  if(!ntop->getPrefs()->are_alerts_disabled()
      && (!ip.isEmpty())) {
    char *key, ip_buf[48], rsp[64], rkey[128];

    /* This value always contains vlan information */
    key = get_hostkey(ip_buf, sizeof(ip_buf), true);

    if(key) {
      snprintf(rkey, sizeof(rkey), CONST_SUPPRESSED_ALERT_PREFS, getInterface()->get_id());
      if(ntop->getRedis()->hashGet(rkey, key, rsp, sizeof(rsp)) == 0)
	trigger_host_alerts = ((strcmp(rsp, "false") == 0) ? 0 : 1);
      else
	trigger_host_alerts = true;

      alerts_read = true;

      if(trigger_host_alerts) {
	/* Defaults */
	int flow_attacker_pref = ntop->getPrefs()->get_attacker_max_num_flows_per_sec();
	int flow_victim_pref = ntop->getPrefs()->get_victim_max_num_flows_per_sec();
	int syn_attacker_pref = ntop->getPrefs()->get_attacker_max_num_syn_per_sec();
	int syn_victim_pref = ntop->getPrefs()->get_victim_max_num_syn_per_sec();

	key = ip.print(ip_buf, sizeof(ip_buf));
	snprintf(rkey, sizeof(rkey), CONST_HOST_ANOMALIES_THRESHOLD, key, vlan_id);

	/* per-host values */
	if((ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0')) {
	  /* Note: the order of the fields must match that of anomalies_config into alerts_utils.lua
	     e.g., %i|%i|%i|%i*/
	  char *a, *_t;

	  a = strtok_r(rsp, "|", &_t);
	  if(a && strncmp(a, "global", strlen("global")))
	    flow_attacker_pref = atoi(a);

	  a = strtok_r(NULL, "|", &_t);
	  if(a && strncmp(a, "global", strlen("global")))
	    flow_victim_pref = atoi(a);

	  a = strtok_r(NULL, "|", &_t);
	  if(a && strncmp(a, "global", strlen("global")))
	    syn_attacker_pref = atoi(a);

	  a = strtok_r(NULL, "|", &_t);
	  if(a && strncmp(a, "global", strlen("global")))
	    syn_victim_pref = atoi(a);

#if 0
	  printf("%s: %s\n", rkey, rsp);
#endif
	}

	/* Counter reload logic */
	if((u_int32_t)flow_attacker_pref != attacker_max_num_flows_per_sec) {
	  attacker_max_num_flows_per_sec = flow_attacker_pref;
	  flow_flood_attacker_alert->resetThresholds(attacker_max_num_flows_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
#if 0
	  printf("%s: attacker_max_num_flows_per_sec = %d\n", key, attacker_max_num_flows_per_sec);
#endif
	}

	if((u_int32_t)flow_victim_pref != victim_max_num_flows_per_sec) {
	  victim_max_num_flows_per_sec = flow_victim_pref;
	  flow_flood_victim_alert->resetThresholds(victim_max_num_flows_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
#if 0
	  printf("%s: victim_max_num_flows_per_sec = %d\n", key, victim_max_num_flows_per_sec);
#endif
	}

	if((u_int32_t)syn_attacker_pref != attacker_max_num_syn_per_sec) {
	  attacker_max_num_syn_per_sec = syn_attacker_pref;
	  syn_flood_attacker_alert->resetThresholds(attacker_max_num_syn_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);

#if 0
	  printf("%s: attacker_max_num_syn_per_sec = %d\n", key, attacker_max_num_syn_per_sec);
#endif
	}

	if((u_int32_t)syn_victim_pref != victim_max_num_syn_per_sec) {
	  victim_max_num_syn_per_sec = syn_victim_pref;
	  syn_flood_victim_alert->resetThresholds(victim_max_num_syn_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);

#if 0
	  printf("%s: victim_max_num_syn_per_sec = %d\n", key, victim_max_num_syn_per_sec);
#endif
	}
      }
    }
  }

  if(!alerts_read)
    trigger_host_alerts = false;
}

/* *************************************** */

void LocalHost::updateHTTPHostRequest(char *virtual_host_name, u_int32_t num_req,
				 u_int32_t bytes_sent, u_int32_t bytes_rcvd) {
  if(http)
    http->updateHTTPHostRequest(virtual_host_name, num_req, bytes_sent, bytes_rcvd);
}

/* *************************************** */

void LocalHost::updateStats(struct timeval *tv) {
  Host::updateStats(tv);

  if(http) http->updateStats(tv);

  if(top_sites && ntop->getPrefs()->are_top_talkers_enabled() && (tv->tv_sec >= nextSitesUpdate)) {
    if(nextSitesUpdate > 0) {
      if(old_sites)
	free(old_sites);
      old_sites = top_sites->json();
    }

    nextSitesUpdate = tv->tv_sec + HOST_SITES_REFRESH;
  }
}

/* *************************************** */

u_int32_t LocalHost::getNumAlerts(bool from_alertsmanager) {
  if(!from_alertsmanager)
    return(num_alerts_detected);

  num_alerts_detected = iface->getAlertsManager()->getNumHostAlerts(this, true);

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Refreshing alerts from alertsmanager [num: %i]",
			       num_alerts_detected);

  return(num_alerts_detected);
}

/* *************************************** */

void LocalHost::setOS(char *_os) {
  if((mac == NULL)
     /*
       When this happens then this is a (NAT+)router and
       the OS would be misleading
     */
     || (mac->getDeviceType() == device_networking)
     ) return;

  if(os[0] == '\0')
    snprintf(os, sizeof(os), "%s", _os);

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
