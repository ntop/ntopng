/*
 *
 * (C) 2013-16 - ntop.org
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

Host::Host(NetworkInterface *_iface) : GenericHost(_iface) {
  initialize(NULL, 0, false);
}

/* *************************************** */

Host::Host(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId) : GenericHost(_iface) {
  ip.set(ipAddress);
  initialize(NULL, _vlanId, true);
}

/* *************************************** */

Host::Host(NetworkInterface *_iface, u_int8_t _mac[6],
	   u_int16_t _vlanId, IpAddress *_ip) : GenericHost(_iface) {
  ip.set(_ip);
  initialize(_mac, _vlanId, true);
}

/* *************************************** */

Host::~Host() {
  if(num_uses > 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: num_uses=%u", num_uses);

  if(topSitesKey) {
    char oldk[64];

    snprintf(oldk, sizeof(oldk), "%s.old", topSitesKey);
    ntop->getRedis()->rename(topSitesKey, oldk);
  }

  if(!ip.isEmpty()) dumpStats(false);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleting %s (%s)", k, localHost ? "local": "remote");

  serialize2redis(); /* possibly dumps counters and data to redis */

  if(mac) mac->decUses();
#ifdef NTOPNG_PRO
  if(sent_to_sketch)   delete sent_to_sketch;
  if(rcvd_from_sketch) delete rcvd_from_sketch;
#endif

  if(dns)  delete dns;
  if(http) delete http;
  if(user_activities) delete user_activities;
  if(ifa_stats)       delete ifa_stats;
  if(symbolic_name)   free(symbolic_name);
  if(country)         free(country);
  if(city)            free(city);
  if(asname)          free(asname);
  if(categoryStats)   delete categoryStats;
  if(syn_flood_attacker_alert) delete syn_flood_attacker_alert;
  if(syn_flood_victim_alert)   delete syn_flood_victim_alert;
  if(m) delete m;
  if(topSitesKey) free(topSitesKey);
}

/* *************************************** */

void Host::set_host_label(char *label_name) {
  if(label_name) {
    char buf[64], *host = ip.print(buf, sizeof(buf));

    ntop->getRedis()->hashSet((char*)HOST_LABEL_NAMES, host, label_name);
  }
}

/* *************************************** */

void Host::computeHostSerial() {
  if(iface && Utils::dumpHostToDB(&ip, ntop->getPrefs()->get_dump_hosts_to_db_policy())) {
    if(host_serial) {
      char buf[64];

      /* We need to reconfirm the id (e.g. after a day wrap) */
      ntop->getRedis()->setHostId(iface, NULL, ip.print(buf, sizeof(buf)), host_serial);
    } else
      host_serial = ntop->getRedis()->addHostToDBDump(iface, &ip, NULL);
  }
}

/* *************************************** */

void Host::initialize(u_int8_t _mac[6], u_int16_t _vlanId, bool init_all) {
  char key[64], redis_key[128], *k;
  char buf[64], host[96];

#ifdef NTOPNG_PRO
  sent_to_sketch = rcvd_from_sketch = NULL;
#endif

  if(_mac == NULL)
    mac = NULL;
  else if((mac = iface->getMac(_mac, _vlanId, true)) != NULL)
    mac->incUses();

  drop_all_host_traffic = false, dump_host_traffic = false,
    deviceIP = 0, deviceIfIdx = 0;
  max_new_flows_sec_threshold = CONST_MAX_NEW_FLOWS_SECOND;
  max_num_syn_sec_threshold = CONST_MAX_NUM_SYN_PER_SECOND;
  max_num_active_flows = CONST_MAX_NUM_HOST_ACTIVE_FLOWS, good_low_flow_detected = false;
  networkStats = NULL, local_network_id = -1, nextResolveAttempt = 0;
  syn_flood_attacker_alert = new AlertCounter(max_num_syn_sec_threshold, CONST_MAX_THRESHOLD_CROSS_DURATION);
  syn_flood_victim_alert = new AlertCounter(max_num_syn_sec_threshold, CONST_MAX_THRESHOLD_CROSS_DURATION);
  flow_flood_attacker_alert = flow_flood_victim_alert = false;
  os[0] = '\0', trafficCategory[0] = '\0', blacklisted_host = false;
  num_uses = 0, symbolic_name = NULL, vlan_id = _vlanId % MAX_NUM_VLAN,
    ingress_shaper_id = egress_shaper_id = -1,
    total_num_flows_as_client = total_num_flows_as_server = 0,
    num_active_flows_as_client = num_active_flows_as_server = 0;
  first_seen = last_seen = iface->getTimeLastPktRcvd();
  nextSitesUpdate = 0;
  if((m = new(std::nothrow) Mutex()) == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: NULL mutex. Are you running out of memory?");

  memset(&tcpPacketStats, 0, sizeof(tcpPacketStats));
  asn = 0, asname = NULL, country = NULL, city = NULL;
  longitude = 0, latitude = 0, host_quota_mb = 0;
  k = get_string_key(key, sizeof(key));
  snprintf(redis_key, sizeof(redis_key), HOST_SERIALIZED_KEY, iface->get_id(), k, vlan_id);
  dns = NULL, http = NULL, categoryStats = NULL, topSitesKey = NULL,
    user_activities = NULL, ifa_stats = NULL;

#ifdef NTOPNG_PRO
  l7Policy = NULL;
  l7NetworkIndex = -1;
  memset(l7Network, 0, sizeof(l7Network));
#endif

  if(init_all) {
    char sitesBuf[64], *strIP = ip.print(buf, sizeof(buf));

    snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);

    updateLocal();
    updateHostTrafficPolicy(host);
    systemHost = ip.isLocalInterfaceAddress();

    if(localHost) {
      char oldk[64];

      snprintf(sitesBuf, sizeof(sitesBuf), "sites.%s", strIP);
      topSitesKey = strdup(sitesBuf);

      snprintf(oldk, sizeof(oldk), "%s.old", topSitesKey);
      ntop->getRedis()->rename(topSitesKey, oldk);
      readDHCPCache();
    }

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loading %s (%s)", k, localHost ? "local": "remote");

    if(localHost || systemHost) {
      dns = new DnsStats();
      http = new HTTPstats(iface->get_hosts_hash());
    }

    if((localHost || systemHost)
       && ntop->getPrefs()->is_idle_local_host_cache_enabled()){
      char *json;
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

    if(localHost || systemHost
       || ntop->getPrefs()->is_dns_resolution_enabled_for_all_hosts()) {
      char rsp[256];

      if(ntop->getRedis()->getAddress(host, rsp, sizeof(rsp), true) == 0)
	setName(rsp);
      // else ntop->getRedis()->pushHostToResolve(host, false, localHost);
    }

    if(!localHost || systemHost) {
      blacklisted_host = ntop->isBlacklistedIP(&ip);

      if((!blacklisted_host) || (ntop->getPrefs()->is_httpbl_enabled() && ip.isIPv4())) {
	// http:bl only works for IPv4 addresses
	if(ntop->getRedis()->getAddressTrafficFiltering(host, iface, trafficCategory,
							sizeof(trafficCategory), true) == 0) {
	  if(strcmp(trafficCategory, NULL_BL)) {
	    blacklisted_host = true;
	  }
	}
      }

      if(blacklisted_host) {
	char msg[64];

	snprintf(msg, sizeof(msg), "Blacklisted host found %s", host);
	ntop->getTrace()->traceEvent(TRACE_INFO, "%s", msg);
	iface->getAlertsManager()->storeHostAlert(this, alert_malware_detection, alert_level_error, msg);
      }
    }

    if(asname) { free(asname); asname = NULL; }
    ntop->getGeolocation()->getAS(&ip, &asn, &asname);

    if(country) { free(country); country = NULL; }
    if(city)    { free(city); city = NULL;       }
    ntop->getGeolocation()->getInfo(&ip, &country, &city, &latitude, &longitude);

    if(localHost || systemHost) {
#ifdef NTOPNG_PRO
      sent_to_sketch   = new CountMinSketch();
      rcvd_from_sketch = new CountMinSketch();
#endif
      readStats();

      if(ntop->getPrefs()->is_flow_activity_enabled()) {
	ifa_stats = new InterFlowActivityStats[IFA_STATS_PROTOS_N*INTER_FLOW_ACTIVITY_SLOTS];
	user_activities = new UserActivityStats;

	if(ifa_stats) memset(ifa_stats, 0, sizeof(InterFlowActivityStats)*IFA_STATS_PROTOS_N*INTER_FLOW_ACTIVITY_SLOTS);
	if(user_activities) memset(user_activities, 0, sizeof(UserActivityStats));
      }
    }
  }

  loadAlertPrefs();
  readAlertPrefs();
  if(!host_serial) computeHostSerial();
  updateHostL7Policy();
}

/* *************************************** */

void Host::readDHCPCache() {
  if(mac) {
    /* Check DHCP cache */
    char client_mac[24], buf[64];

    Utils::formatMac(mac->get_mac(), client_mac, sizeof(client_mac));

    if(ntop->getRedis()->hashGet((char*)DHCP_CACHE, client_mac, buf, sizeof(buf)) == 0) {
      if(symbolic_name == NULL)
	symbolic_name = strdup(buf);
    }
  }
}

/* *************************************** */

void Host::updateHostTrafficPolicy(char *key) {
  if(localHost || systemHost) {
    char buf[64], *host, host_buf[96];

    if(key)
      host = key;
    else {
      if(vlan_id > 0) {
	snprintf(host_buf, sizeof(host_buf), "%s@%u", ip.print(buf, sizeof(buf)), vlan_id);
	host = host_buf;
      } else
	host = ip.print(buf, sizeof(buf));
    }

    if(iface->isPacketInterface()) {
      if((ntop->getRedis()->hashGet((char*)DROP_HOST_TRAFFIC, host, buf, sizeof(buf)) == -1)
	 || (strcmp(buf, "true") != 0))
	drop_all_host_traffic = false;
      else
	drop_all_host_traffic = true;

      if(ntop->getRedis()->hashGet((char*)HOST_TRAFFIC_QUOTA, host, buf, sizeof(buf)) == -1)
	host_quota_mb = atol(buf);
    }

    if((ntop->getRedis()->hashGet((char*)DUMP_HOST_TRAFFIC,
				  host, buf, sizeof(buf)) == -1)
       || (strcmp(buf, "true") != 0))
      dump_host_traffic = false;
    else
      dump_host_traffic = true;
  }
}

/* *************************************** */

void Host::updateHostL7Policy() {
#ifdef NTOPNG_PRO
  if(!iface->is_bridge_interface()) return;

  if(ntop->getPro()->has_valid_license()) {
    if(localHost || systemHost) {
      char hash_name[64], rsp[32];
      char buf[64], *host;
      u_int8_t bitmask;

      l7Policy = getInterface()->getL7Policer()->getIpPolicy(&ip, vlan_id, &bitmask);

      host = ip.print(buf, sizeof(buf), bitmask);
      snprintf(l7Network, sizeof(l7Network), "%s/%u@%u", host,
	       bitmask, vlan_id);

      /* ************************************************* */

      snprintf(hash_name, sizeof(hash_name),
	       "ntopng.prefs.%u.l7_policy_ingress_shaper_id",
	       getInterface()->get_id());

      if((ntop->getRedis()->hashGet(hash_name, l7Network, rsp, sizeof(rsp)) != 0)
	 || (rsp[0] == '\0'))
	ingress_shaper_id = -1;
      else {
	ingress_shaper_id = atoi(rsp);

	if(ingress_shaper_id < 0)
	  ingress_shaper_id = -1;
      }

      /* ************************************************* */

      snprintf(hash_name, sizeof(hash_name),
	       "ntopng.prefs.%u.l7_policy_egress_shaper_id",
	       getInterface()->get_id());

      if((ntop->getRedis()->hashGet(hash_name, l7Network, rsp, sizeof(rsp)) != 0)
	 || (rsp[0] == '\0'))
	egress_shaper_id = -1;
      else {
	egress_shaper_id = atoi(rsp);

	if(egress_shaper_id < 0)
	  egress_shaper_id = -1;
      }
	//~ char name[256]; printf("%s -> %s - %d %d\n", get_name(name, sizeof(name), false), l7Network, ingress_shaper_id, egress_shaper_id);
    } else {
      l7Policy = NULL;
      memset(l7Network, 0, sizeof(l7Network));
      ingress_shaper_id = egress_shaper_id = -1;
    }

    /* cache l7 network ID to speedup per packet access */
    updateL7NetworkIndex();
  }
#endif
}

/* *************************************** */

bool Host::doDropProtocol(ndpi_protocol l7_proto) {
#ifdef NTOPNG_PRO
  if(ntop->getPro()->has_valid_license()) {
    if(l7Policy)
      return((NDPI_ISSET(l7Policy, l7_proto.protocol)
	      || NDPI_ISSET(l7Policy, l7_proto.master_protocol)) ? true : false);
    else
      return(false);
  }
#endif
  return false;
}

/* *************************************** */

void Host::updateLocal() {
  localHost = ip.isLocalHost(&local_network_id);

  if(local_network_id >= 0)
    networkStats = getNetworkStats(local_network_id);

  if(0) {
    char buf[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s is %s",
				 ip.print(buf, sizeof(buf)),
				 localHost ? "local" : "remote");
  }
}

/* *************************************** */

void Host::set_mac(char *m) {
  u_int8_t mac_address[6];
  u_int32_t _mac[6] = { 0 };

  if((m == NULL) || (!strcmp(m, "00:00:00:00:00:00")))
    return;

  sscanf(m, "%02X:%02X:%02X:%02X:%02X:%02X",
	 &_mac[0], &_mac[1], &_mac[2], &_mac[3], &_mac[4], &_mac[5]);

  mac_address[0] = _mac[0], mac_address[1] = _mac[1],
    mac_address[2] = _mac[2], mac_address[3] = _mac[3],
    mac_address[4] = _mac[4], mac_address[5] = _mac[5];

  if(mac) mac->decUses();

  if((mac = iface->getMac(mac_address, vlan_id, true)) != NULL)
    mac->incUses();
}

/* *************************************** */

void Host::getSites(lua_State* vm, char *k, const char *label) {
  int rc;
  char **sites;

  lua_newtable(vm);

  if((rc = ntop->getRedis()->zRevRange(k, &sites)) > 0) {

    for(int i = 0; i < rc; i++) {
      if((sites[i] == NULL) || (sites[i+1] == NULL))
	continue; /* safety check */

      lua_push_int_table_entry(vm, sites[i], atoi(sites[i+1]));

      free(sites[i]), free(sites[i+1]);
      i++;
    }

    free(sites);
  }

  lua_pushstring(vm, label);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void Host::lua(lua_State* vm, patricia_tree_t *ptree,
	       bool host_details, bool verbose,
	       bool returnHost, bool asListElement,
	       bool exclude_deserialized_bytes) {
  char buf[64];
  char buf_id[64];
  char ip_buf[64];
  char *ipaddr = NULL;
  char *local_net;

  if(ptree && (!match(ptree)))
    return;

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "ip", (ipaddr = ip.print(ip_buf, sizeof(ip_buf))));
  lua_push_int_table_entry(vm, "ipkey", ip.key());

  lua_push_str_table_entry(vm, "mac", Utils::formatMac(mac ? mac->get_mac() : NULL, buf, sizeof(buf)));
  lua_push_bool_table_entry(vm, "localhost", localHost);

  lua_push_int_table_entry(vm, "bytes.sent",
			   sent.getNumBytes() - (exclude_deserialized_bytes ? sent.getNumDeserializedBytes() : 0));
  lua_push_int_table_entry(vm, "bytes.rcvd",
			   rcvd.getNumBytes() - (exclude_deserialized_bytes ? rcvd.getNumDeserializedBytes() : 0));

  lua_push_bool_table_entry(vm, "privatehost", isPrivateHost());

  if(host_details) {
    /*
      This has been disabled as in case of an attack, most hosts do not have a name and we will waste
      a lot of time doing activities that are not necessary
    */
    if((symbolic_name == NULL) || (strcmp(symbolic_name, ipaddr) == 0)) {
      /* We resolve immediately the IP address by queueing on the top of address queue */

      ntop->getRedis()->pushHostToResolve(ipaddr, false, true /* Fake to resolve it ASAP */);
    }
  }

  lua_push_str_table_entry(vm, "name",
			   get_name(buf, sizeof(buf), false));
  lua_push_int32_table_entry(vm, "local_network_id", local_network_id);

  local_net = ntop->getLocalNetworkName(local_network_id);
  if(local_net == NULL)
    lua_push_nil_table_entry(vm, "local_network_name");
  else
    lua_push_str_table_entry(vm, "local_network_name", local_net);

  lua_push_bool_table_entry(vm, "systemhost", systemHost);
  lua_push_int_table_entry(vm, "source_id", source_id);
  lua_push_int_table_entry(vm, "asn", asn);

  lua_push_str_table_entry(vm, "asname", asname);
  lua_push_str_table_entry(vm, "os", os);

  lua_push_str_table_entry(vm, "country", country ? country : (char*)"");
  lua_push_int_table_entry(vm, "active_flows.as_client", num_active_flows_as_client);
  lua_push_int_table_entry(vm, "active_flows.as_server", num_active_flows_as_server);
  lua_push_int_table_entry(vm, "active_http_hosts", http ? http->get_num_virtual_hosts() : 0);

  if(host_details) {
    lua_push_str_table_entry(vm, "deviceIP", Utils::intoaV4(deviceIP, buf, sizeof(buf)));
    lua_push_int_table_entry(vm, "deviceIfIdx", deviceIfIdx);
    lua_push_float_table_entry(vm, "latitude", latitude);
    lua_push_float_table_entry(vm, "longitude", longitude);
    lua_push_str_table_entry(vm, "city", city ? city : (char*)"");
    lua_push_int_table_entry(vm, "flows.as_client", total_num_flows_as_client);
    lua_push_int_table_entry(vm, "flows.as_server", total_num_flows_as_server);
    lua_push_int_table_entry(vm, "udp.packets.sent",  udp_sent.getNumPkts());
    lua_push_int_table_entry(vm, "udp.bytes.sent", udp_sent.getNumBytes());
    lua_push_int_table_entry(vm, "udp.packets.rcvd",  udp_rcvd.getNumPkts());
    lua_push_int_table_entry(vm, "udp.bytes.rcvd", udp_rcvd.getNumBytes());

    lua_push_int_table_entry(vm, "tcp.packets.sent",  tcp_sent.getNumPkts());

    lua_push_bool_table_entry(vm, "tcp.packets.seq_problems",
			      (tcpPacketStats.pktRetr
			       || tcpPacketStats.pktOOO
			       || tcpPacketStats.pktLost) ? true : false);
    lua_push_int_table_entry(vm, "tcp.packets.retransmissions", tcpPacketStats.pktRetr);
    lua_push_int_table_entry(vm, "tcp.packets.out_of_order", tcpPacketStats.pktOOO);
    lua_push_int_table_entry(vm, "tcp.packets.lost", tcpPacketStats.pktLost);

    lua_push_int_table_entry(vm, "tcp.bytes.sent", tcp_sent.getNumBytes());
    lua_push_int_table_entry(vm, "tcp.packets.rcvd",  tcp_rcvd.getNumPkts());
    lua_push_int_table_entry(vm, "tcp.bytes.rcvd", tcp_rcvd.getNumBytes());

    lua_push_int_table_entry(vm, "icmp.packets.sent",  icmp_sent.getNumPkts());
    lua_push_int_table_entry(vm, "icmp.bytes.sent", icmp_sent.getNumBytes());
    lua_push_int_table_entry(vm, "icmp.packets.rcvd",  icmp_rcvd.getNumPkts());
    lua_push_int_table_entry(vm, "icmp.bytes.rcvd", icmp_rcvd.getNumBytes());

    lua_push_int_table_entry(vm, "other_ip.packets.sent",  other_ip_sent.getNumPkts());
    lua_push_int_table_entry(vm, "other_ip.bytes.sent", other_ip_sent.getNumBytes());
   lua_push_int_table_entry(vm, "other_ip.packets.rcvd",  other_ip_rcvd.getNumPkts());
    lua_push_int_table_entry(vm, "other_ip.bytes.rcvd", other_ip_rcvd.getNumBytes());

    lua_push_bool_table_entry(vm, "drop_all_host_traffic", drop_all_host_traffic);

    /* Host ingress/egress drops */
    lua_push_int_table_entry(vm, "bridge.ingress_drops.bytes", ingress_drops.getNumBytes());
    lua_push_int_table_entry(vm, "bridge.ingress_drops.packets",  ingress_drops.getNumPkts());
    lua_push_int_table_entry(vm, "bridge.egress_drops.bytes", egress_drops.getNumBytes());
    lua_push_int_table_entry(vm, "bridge.egress_drops.packets",  egress_drops.getNumPkts());

    lua_push_int_table_entry(vm, "host_quota_mb", host_quota_mb);

    if(localHost || systemHost) {
      lua_push_int_table_entry(vm, "bridge.ingress_shaper_id", ingress_shaper_id);
      lua_push_int_table_entry(vm, "bridge.egress_shaper_id", egress_shaper_id);
      lua_push_int_table_entry(vm, "bridge.host_quota_mb", host_quota_mb);
    }

    lua_push_int_table_entry(vm, "low_goodput_flows.as_client", low_goodput_client_flows);
    lua_push_int_table_entry(vm, "low_goodput_flows.as_server", low_goodput_server_flows);

    if(topSitesKey) {
      char oldk[64];

      snprintf(oldk, sizeof(oldk), "%s.old", topSitesKey);

      getSites(vm, topSitesKey, "sites");
      getSites(vm, oldk, "sites.old");
    }
  }

  if(localHost) {
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
  }

  lua_push_int_table_entry(vm, "seen.first", first_seen);
  lua_push_int_table_entry(vm, "seen.last", last_seen);
  lua_push_int_table_entry(vm, "duration", get_duration());

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[pkts_thpt: %.2f] [pkts_thpt_trend: %d]", pkts_thpt,pkts_thpt_trend);
  lua_push_int_table_entry(vm, "num_alerts", triggerAlerts() ? getNumAlerts() : 0);

  if(ntop->getPrefs()->is_httpbl_enabled())
    lua_push_str_table_entry(vm, "httpbl", get_httpbl());

  lua_push_bool_table_entry(vm, "dump_host_traffic", dump_host_traffic);

  if(verbose) {
    char *rsp = serialize();

    if(categoryStats) categoryStats->lua(vm);
    if(ndpiStats) ndpiStats->lua(iface, vm);
    lua_push_str_table_entry(vm, "json", rsp);
    free(rsp);

    sent_stats.lua(vm, "pktStats.sent");
    recv_stats.lua(vm, "pktStats.recv");

    if(dns)  dns->lua(vm);
    if(http) http->lua(vm);

#ifdef NTOPNG_PRO
    if(ntop->getPro()->has_valid_license()) {
      if(l7Policy != NULL) {
	lua_newtable(vm);

	for(int i=1; i<NDPI_MAX_SUPPORTED_PROTOCOLS+NDPI_MAX_NUM_CUSTOM_PROTOCOLS; i++) {
	  if(NDPI_ISSET(l7Policy, i)) {
	    char *proto = ndpi_get_proto_by_id(iface->get_ndpi_struct(), i);

	    if(proto)
	      lua_push_int_table_entry(vm, proto, i);
	  }
	}

	lua_pushstring(vm, "l7_traffic_policy");
	lua_insert(vm, -2);
	lua_settable(vm, -3);
      }
    }
#endif
  }

  if(!returnHost) {
    /* Use the ip@vlan_id as a key only in case of multi vlan_id, otherwise use only the ip as a key */
    if(vlan_id == 0) {
      sprintf(buf_id, "%s", ip.print(buf, sizeof(buf)));
    } else {
      sprintf(buf_id, "%s@%d", ip.print(buf, sizeof(buf)), vlan_id);
    }
  }

  ((GenericTrafficElement*)this)->lua(vm, host_details);

  if(asListElement) {
    lua_pushstring(vm, buf_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ***************************************** */

/*
  As this method can be called from Lua, in order to avoid concurency issues
  we need to lock/unlock
*/
void Host::setName(char *name) {
  if(m) m->lock(__FILE__, __LINE__);
  if((symbolic_name == NULL) || (symbolic_name && strcmp(symbolic_name, name))) {
    if(symbolic_name) free(symbolic_name);
    symbolic_name = strdup(name);
  }

  if(m) m->unlock(__FILE__, __LINE__);
}

/* ***************************************** */

void Host::refreshHTTPBL() {
  if(ip.isIPv4()
     && (!localHost)
     && (trafficCategory[0] == '\0')
     && ntop->get_httpbl()) {
    char buf[128] =  { 0 };
    char* ip_addr = ip.print(buf, sizeof(buf));

    ntop->get_httpbl()->findCategory(ip_addr, trafficCategory, sizeof(trafficCategory), false);
  }
}

/* ***************************************** */

char* Host::get_name(char *buf, u_int buf_len, bool force_resolution_if_not_found) {
  char *addr, redis_buf[64];
  int rc;
  time_t now = time(NULL);

  if(nextResolveAttempt && ((nextResolveAttempt > now) || (nextResolveAttempt == (time_t)-1))) {
    return(symbolic_name);
  } else
    nextResolveAttempt = ntop->getPrefs()->is_dns_resolution_enabled() ? now + MIN_HOST_RESOLUTION_FREQUENCY : (time_t)-1;

  addr = ip.print(buf, buf_len);

  if((symbolic_name != NULL) && strcmp(symbolic_name, addr))
    return(symbolic_name);

  readDHCPCache();

  if(symbolic_name) return(symbolic_name);
					 
  rc = ntop->getRedis()->getAddress(addr, redis_buf, sizeof(redis_buf),
				    force_resolution_if_not_found);

  if(rc == 0)
    setName(redis_buf);
  else
    setName(addr);

  return(symbolic_name);
}

/* ***************************************** */

bool Host::idle() {
  if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);

  switch(ntop->getPrefs()->get_host_stickness()) {
  case location_none:
    break;

  case location_local_only:
    if(localHost || systemHost) return(false);
    break;

  case location_remote_only:
    if(!(localHost||systemHost)) return(false);
    break;

  case location_all:
    return(false);
    break;
  }

  return(isIdle(ntop->getPrefs()->get_host_max_idle(localHost)));
};

/* *************************************** */

void Host::incStats(u_int8_t l4_proto, u_int ndpi_proto,
		    struct site_categories *category,
		    u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		    u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes) {

  if(sent_packets || rcvd_packets) {
    ((GenericHost*)this)->incStats(l4_proto, ndpi_proto, sent_packets, sent_bytes, sent_goodput_bytes,
				   rcvd_packets, rcvd_bytes, rcvd_goodput_bytes);

    if(sent_packets == 1) sent_stats.incStats((u_int)sent_bytes);
    if(rcvd_packets == 1) recv_stats.incStats((u_int)rcvd_bytes);

    switch(l4_proto) {
    case 0:
      /* Unknown protocol */
      break;
    case IPPROTO_UDP:
      udp_rcvd.incStats(rcvd_packets, rcvd_bytes),
	udp_sent.incStats(sent_packets, sent_bytes);
      break;
    case IPPROTO_TCP:
      tcp_rcvd.incStats(rcvd_packets, rcvd_bytes),
	tcp_sent.incStats(sent_packets, sent_bytes);
      break;
    case IPPROTO_ICMP:
      icmp_rcvd.incStats(rcvd_packets, rcvd_bytes),
	icmp_sent.incStats(sent_packets, sent_bytes);
      break;
    default:
      other_ip_rcvd.incStats(rcvd_packets, rcvd_bytes),
	other_ip_sent.incStats(sent_packets, sent_bytes);
      break;
    }

    if(category && localHost && ntop->get_flashstart()) {
      if(categoryStats == NULL)
	categoryStats = new CategoryStats();

      if(categoryStats) {
	for(int i=0; i <MAX_NUM_CATEGORIES; i++)
	  if(category->categories[i] == NTOP_UNKNOWN_CATEGORY_ID)
	    break;
	  else
	    categoryStats->incStats(category->categories[i],
				    sent_bytes+rcvd_bytes);
      }
    }
  }
}

/* *************************************** */

char* Host::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* *************************************** */

void Host::serialize2redis() {
  if((localHost || systemHost)
     && (ntop->getPrefs()->is_idle_local_host_cache_enabled()
	 || ntop->getPrefs()->is_active_local_host_cache_enabled())
     && (!ip.isEmpty())) {
    char *json = serialize();
    char host_key[128], key[128];
    char *k = get_string_key(host_key, sizeof(host_key));

    snprintf(key, sizeof(key), HOST_SERIALIZED_KEY, iface->get_id(), k, vlan_id);
    ntop->getRedis()->set(key, json, ntop->getPrefs()->get_local_host_cache_duration());
    ntop->getTrace()->traceEvent(TRACE_INFO, "Dumping serialization %s", k);
    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s => %s", k, json);
    free(json);
  }
}

/* *************************************** */

json_object* Host::getJSONObject() {
  json_object *my_object;
  char buf[32];

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  json_object_object_add(my_object, "mac_address", json_object_new_string(Utils::formatMac(mac ? mac->get_mac() : NULL, buf, sizeof(buf))));
  json_object_object_add(my_object, "seen.first", json_object_new_int64(first_seen));
  json_object_object_add(my_object, "seen.last",  json_object_new_int64(last_seen));
  json_object_object_add(my_object, "asn", json_object_new_int(asn));
  if(symbolic_name)       json_object_object_add(my_object, "symbolic_name", json_object_new_string(symbolic_name));
  if(country)             json_object_object_add(my_object, "country",   json_object_new_string(country));
  if(city)                json_object_object_add(my_object, "city",      json_object_new_string(city));
  if(asname)              json_object_object_add(my_object, "asname",    json_object_new_string(asname));
  if(strlen(os))          json_object_object_add(my_object, "os",        json_object_new_string(os));
  if(trafficCategory[0] != '\0')   json_object_object_add(my_object, "trafficCategory",    json_object_new_string(trafficCategory));
  if(vlan_id != 0)        json_object_object_add(my_object, "vlan_id",   json_object_new_int(vlan_id));
  if(latitude)            json_object_object_add(my_object, "latitude",  json_object_new_double(latitude));
  if(longitude)           json_object_object_add(my_object, "longitude", json_object_new_double(longitude));
  json_object_object_add(my_object, "ip", ip.getJSONObject());
  if(deviceIfIdx)         json_object_object_add(my_object, "device_if_idx", json_object_new_int(deviceIfIdx));
  if(deviceIP)            json_object_object_add(my_object, "device_ip",     json_object_new_int(deviceIP));
  json_object_object_add(my_object, "localHost", json_object_new_boolean(localHost));
  json_object_object_add(my_object, "systemHost", json_object_new_boolean(systemHost));
  json_object_object_add(my_object, "is_blacklisted", json_object_new_boolean(blacklisted_host));
  json_object_object_add(my_object, "flow_flood_attacker_alert", json_object_new_boolean(flow_flood_attacker_alert));
  json_object_object_add(my_object, "flow_flood_victim_alert",   json_object_new_boolean(flow_flood_victim_alert));
  json_object_object_add(my_object, "tcp_sent", tcp_sent.getJSONObject());
  json_object_object_add(my_object, "tcp_rcvd", tcp_rcvd.getJSONObject());
  json_object_object_add(my_object, "udp_sent", udp_sent.getJSONObject());
  json_object_object_add(my_object, "udp_rcvd", udp_rcvd.getJSONObject());
  json_object_object_add(my_object, "icmp_sent", icmp_sent.getJSONObject());
  json_object_object_add(my_object, "icmp_rcvd", icmp_rcvd.getJSONObject());
  json_object_object_add(my_object, "other_ip_sent", other_ip_sent.getJSONObject());
  json_object_object_add(my_object, "other_ip_rcvd", other_ip_rcvd.getJSONObject());

  /* packet stats */
  json_object_object_add(my_object, "pktStats.sent", sent_stats.getJSONObject());
  json_object_object_add(my_object, "pktStats.recv", recv_stats.getJSONObject());

  /* TCP packet stats (serialize only anomalies) */
  if(tcpPacketStats.pktRetr) json_object_object_add(my_object,
						    "tcpPacketStats.pktRetr",
						    json_object_new_int(tcpPacketStats.pktRetr));
  if(tcpPacketStats.pktOOO)  json_object_object_add(my_object,
						    "tcpPacketStats.pktOOO",
						    json_object_new_int(tcpPacketStats.pktOOO));
  if(tcpPacketStats.pktLost) json_object_object_add(my_object,
						    "tcpPacketStats.pktLost",
						    json_object_new_int(tcpPacketStats.pktLost));

  /* throughput stats */
  json_object_object_add(my_object, "throughput_bps", json_object_new_double(bytes_thpt));
  json_object_object_add(my_object, "throughput_trend_bps", json_object_new_string(Utils::trend2str(bytes_thpt_trend)));
  json_object_object_add(my_object, "throughput_pps", json_object_new_double(pkts_thpt));
  json_object_object_add(my_object, "throughput_trend_pps", json_object_new_string(Utils::trend2str(pkts_thpt_trend)));
  json_object_object_add(my_object, "flows.as_client", json_object_new_int(total_num_flows_as_client));
  json_object_object_add(my_object, "flows.as_server", json_object_new_int(total_num_flows_as_server));
  if(user_activities)
    json_object_object_add(my_object, "userActivities", user_activities->getJSONObject());

  /* Generic Host */
  json_object_object_add(my_object, "num_alerts", json_object_new_int(getNumAlerts()));
  json_object_object_add(my_object, "sent", sent.getJSONObject());
  json_object_object_add(my_object, "rcvd", rcvd.getJSONObject());
  json_object_object_add(my_object, "ndpiStats", ndpiStats->getJSONObject(iface));

  /* The value below is handled by reading dumps on disk as otherwise the string will be too long */
  //json_object_object_add(my_object, "activityStats", activityStats.getJSONObject());

  if(categoryStats)  json_object_object_add(my_object, "categories", categoryStats->getJSONObject());
  if(dns)  json_object_object_add(my_object, "dns", dns->getJSONObject());
  if(http) json_object_object_add(my_object, "http", http->getJSONObject());

  return(my_object);
}

/* *************************************** */

bool Host::addIfMatching(lua_State* vm, patricia_tree_t *ptree, char *key) {
  char keybuf[64] = { 0 }, *r;

  if(!match(ptree)) return(false);

  // if(symbolic_name) ntop->getTrace()->traceEvent(TRACE_WARNING, "%s/%s", symbolic_name, ip.print(keybuf, sizeof(keybuf)));

  if(strcasestr((r = Utils::formatMac(mac ? mac->get_mac() : NULL, keybuf, sizeof(keybuf))), key)) {
    lua_push_str_table_entry(vm, get_string_key(keybuf, sizeof(keybuf)), r);
    return(true);
  } else if(strcasestr((r = ip.print(keybuf, sizeof(keybuf))), key)) {
    if(vlan_id != 0) {
      char valuebuf[96];

      snprintf(valuebuf, sizeof(valuebuf), "%s@%u", r, vlan_id);
      lua_push_str_table_entry(vm, get_string_key(keybuf, sizeof(keybuf)), valuebuf);
    } else
      lua_push_str_table_entry(vm, get_string_key(keybuf, sizeof(keybuf)), r);

    return(true);
  } else if(symbolic_name && strcasestr(symbolic_name, key)) {
    lua_push_str_table_entry(vm, get_string_key(keybuf, sizeof(keybuf)), symbolic_name);
    return(true);
  }

  return(false);
}

/* *************************************** */

bool Host::deserialize(char *json_str, char *key) {
  json_object *o, *obj;
  enum json_tokener_error jerr = json_tokener_success;

  if((o = json_tokener_parse_verbose(json_str, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] key: %s: %s",
				 json_tokener_error_desc(jerr),
				 key,
				 json_str);
    return(false);
  }

  if(json_object_object_get_ex(o, "seen.first", &obj)) first_seen = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "seen.last", &obj))  last_seen  = json_object_get_int64(obj);

  if(json_object_object_get_ex(o, "mac_address", &obj)) set_mac((char*)json_object_get_string(obj));
  if(json_object_object_get_ex(o, "asn", &obj)) asn = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "source_id", &obj)) source_id = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "symbolic_name", &obj))  { if(symbolic_name) free(symbolic_name); symbolic_name = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "country", &obj))        { if(country) free(country); country = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "city", &obj))           { if(city) free(city); city = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "asname", &obj))         { if(asname) free(asname); asname = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "os", &obj))             { snprintf(os, sizeof(os), "%s", json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "trafficCategory", &obj)){ snprintf(trafficCategory, sizeof(trafficCategory), "%s", json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "vlan_id", &obj))       vlan_id     = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "device_if_idx", &obj)) deviceIfIdx = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "device_ip", &obj))     deviceIP    = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "latitude", &obj))  latitude  = (float)json_object_get_double(obj);
  if(json_object_object_get_ex(o, "longitude", &obj)) longitude = (float)json_object_get_double(obj);
  if(json_object_object_get_ex(o, "ip", &obj))  { ip.deserialize(obj); }
  if(json_object_object_get_ex(o, "localHost", &obj)) localHost = (json_object_get_boolean(obj) ? true : false);
  if(json_object_object_get_ex(o, "systemHost", &obj)) systemHost = (json_object_get_boolean(obj) ? true : false);
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

  if(json_object_object_get_ex(o, "flows.as_client", &obj))  total_num_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "flows.as_server", &obj))  total_num_flows_as_server = json_object_get_int(obj);
  if(user_activities) if(json_object_object_get_ex(o, "userActivities", &obj))  user_activities->deserialize(obj);

  if(json_object_object_get_ex(o, "flow_flood_attacker_alert", &obj)) flow_flood_attacker_alert = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "flow_flood_victim_alert", &obj))   flow_flood_victim_alert   = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "is_blacklisted", &obj)) blacklisted_host     = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "num_alerts", &obj))     num_alerts_detected  = json_object_get_boolean(obj);

  if(json_object_object_get_ex(o, "sent", &obj))  sent.deserialize(obj);
  if(json_object_object_get_ex(o, "rcvd", &obj))  rcvd.deserialize(obj);

  if(json_object_object_get_ex(o, "dns", &obj)) {
    if(dns) dns->deserialize(obj);
  }

  if(json_object_object_get_ex(o, "http", &obj)) {
    if(http) http->deserialize(obj);
  }

  if(categoryStats) {
    delete categoryStats;
    categoryStats = NULL;
  }

  // deserialize categories only if flashstart is enabled for the current instance
  if(json_object_object_get_ex(o, "categories", &obj) && ntop->get_flashstart()) {
    categoryStats = new CategoryStats();
    if(categoryStats) categoryStats->deserialize(obj);
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

  computeHostSerial();
  if(json_object_object_get_ex(o, "pktStats.sent", &obj)) sent_stats.deserialize(obj);
  if(json_object_object_get_ex(o, "pktStats.recv", &obj)) recv_stats.deserialize(obj);

  json_object_put(o);

  /* We need to update too the stats for traffic */
  last_update_time.tv_sec = (long)time(NULL), last_update_time.tv_usec = 0;
  // Update bps throughput
  bytes_thpt = 0, last_bytes = sent.getNumBytes()+rcvd.getNumBytes(),
    bytes_thpt_trend = trend_unknown;

  // Update pps throughput
  pkts_thpt = 0, last_packets = sent.getNumPkts()+rcvd.getNumPkts(),
    pkts_thpt_trend = trend_unknown;

  return(true);
}

/* *************************************** */

void Host::updateSynFlags(time_t when, u_int8_t flags, Flow *f, bool syn_sent) {
  AlertCounter *counter = syn_sent ? syn_flood_attacker_alert : syn_flood_victim_alert;

  if(!localHost || !triggerAlerts()) return;

  if(counter->incHits(when)) {
    char ip_buf[48], flow_buf[256], msg[512], *h;
    const char *error_msg;

#if 0
    /*
      It's normal that at startup several flows are created
    */
    if(ntop->getUptime() < 10 /* sec */) return;
#endif

    h = ip.print(ip_buf, sizeof(ip_buf));

    if(syn_sent) {
      error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is a SYN flooder [%u SYNs sent in the last %u sec] %s";
      snprintf(msg, sizeof(msg),
	       error_msg, ntop->getPrefs()->get_http_prefix(),
	       h, iface->get_name(), h,
	       counter->getCurrentHits(),
	       counter->getOverThresholdDuration(),
	       f->print(flow_buf, sizeof(flow_buf)));
    } else {
      char attacker_buf[64], *attacker_str;
      Host *attacker = f->get_srv_host();
      IpAddress *aip = attacker->get_ip();
      char aip_buf[48], *aip_ptr;

      attacker_str = attacker->get_ip()->print(attacker_buf, sizeof(attacker_buf));
      aip_ptr = aip->print(aip_buf, sizeof(aip_buf));
      error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is under SYN flood attack by host %s [%u SYNs received in the last %u sec] %s";
      snprintf(msg, sizeof(msg),
	       error_msg, ntop->getPrefs()->get_http_prefix(),
	       h, iface->get_name(), attacker_str, aip_ptr,
	       counter->getCurrentHits(),
	       counter->getOverThresholdDuration(),
	       f->print(flow_buf, sizeof(flow_buf)));
    }

    ntop->getTrace()->traceEvent(TRACE_INFO, "SYN Flood: %s", msg);
    /* the f->get_srv_host() is just a guess */
    iface->getAlertsManager()->storeHostAlert(this, alert_syn_flood, alert_level_error, msg,
					      syn_sent ? this /* .. we are the cause of the trouble */ : f->get_srv_host(),
					      syn_sent ? f->get_srv_host() /* .. the srve is a victim .. */: this);
  }
}

/* *************************************** */

void Host::incNumFlows(bool as_client) {
  if(as_client) {
    total_num_flows_as_client++, num_active_flows_as_client++;

    if(num_active_flows_as_client >= max_num_active_flows && localHost && triggerAlerts() && !flow_flood_attacker_alert) {
      const char* error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is a possible scanner [%u active flows exceeded]";
      char ip_buf[48], *h, msg[512];

      h = ip.print(ip_buf, sizeof(ip_buf));

      snprintf(msg, sizeof(msg),
	       error_msg, ntop->getPrefs()->get_http_prefix(),
	       h, iface->get_name(), h, max_num_active_flows);

      ntop->getTrace()->traceEvent(TRACE_INFO, "Begin scan attack: %s", msg);
      iface->getAlertsManager()->engageHostAlert(this,
						 (char*)"scan_attacker",
						 alert_flow_flood, alert_level_error, msg,
						 this /* the originator of the alert, i.e., the cause of the trouble */,
						 NULL /* the target of the alert, possibly many hosts */);
      flow_flood_attacker_alert = true;
    }
  } else {
    total_num_flows_as_server++, num_active_flows_as_server++;

    if(num_active_flows_as_server >= max_num_active_flows && localHost && triggerAlerts() && !flow_flood_victim_alert) {
      const char* error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is possibly under scan attack [%u active flows exceeded]";
      char ip_buf[48], *h, msg[512];

      h = ip.print(ip_buf, sizeof(ip_buf));

      snprintf(msg, sizeof(msg),
	       error_msg, ntop->getPrefs()->get_http_prefix(),
	       h, iface->get_name(), h, max_num_active_flows);

      ntop->getTrace()->traceEvent(TRACE_INFO, "Begin scan attack: %s", msg);
      iface->getAlertsManager()->engageHostAlert(this,
						 (char*)"scan_victim",
						 alert_flow_flood, alert_level_error, msg,
						 NULL /* presently we don't know the originator(s) of the alert ... */,
						 this /* ... but we can say that we're the victim ... */);
      flow_flood_victim_alert = true;
    }
  }
}

/* *************************************** */

void Host::decNumFlows(bool as_client) {
  if(as_client) {
    if(num_active_flows_as_client) {
      num_active_flows_as_client--;

      if(num_active_flows_as_client <= max_num_active_flows && localHost && triggerAlerts() && flow_flood_attacker_alert) {
	const char* error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is no longer a possible scanner [less than %u active flows]";
	char ip_buf[48], *h, msg[512];

	h = ip.print(ip_buf, sizeof(ip_buf));

	snprintf(msg, sizeof(msg),
		 error_msg, ntop->getPrefs()->get_http_prefix(),
		 h, iface->get_name(), h, max_num_active_flows);

	ntop->getTrace()->traceEvent(TRACE_INFO, "End scan attack: %s", msg);
	iface->getAlertsManager()->releaseHostAlert(this,
						    (char*)"scan_attacker",
						    alert_flow_flood, alert_level_error, msg);
	flow_flood_attacker_alert = false;
      }
    } else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: invalid counter value");
  } else {
    if(num_active_flows_as_server) {
      num_active_flows_as_server--;

      if(num_active_flows_as_server <= max_num_active_flows && localHost && triggerAlerts() && flow_flood_victim_alert) {
	const char* error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is no longer under scan attack [less than %u active flows]";
	char ip_buf[48], *h, msg[512];

	h = ip.print(ip_buf, sizeof(ip_buf));

	snprintf(msg, sizeof(msg),
		 error_msg, ntop->getPrefs()->get_http_prefix(),
		 h, iface->get_name(), h, max_num_active_flows);

	ntop->getTrace()->traceEvent(TRACE_INFO, "End scan attack: %s", msg); // TODO: remove
	iface->getAlertsManager()->releaseHostAlert(this,
						    (char*)"scan_victim",
						    alert_flow_flood, alert_level_error, msg);
	flow_flood_victim_alert = false;
      }
    } else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: invalid counter value");
  }
}

/* *************************************** */

void Host::setQuota(u_int32_t new_quota) {
  char buf[64], host[96];

  snprintf(host, sizeof(host), "%s@%u", ip.print(buf, sizeof(buf)), vlan_id);
  snprintf(buf, sizeof(buf), "%u", new_quota);
  if(ntop->getRedis()->hashSet((char*)HOST_TRAFFIC_QUOTA, host, (char *)buf) == -1) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Error updating host quota");
    return;
  }
  host_quota_mb = new_quota;
}

/* *************************************** */

bool Host::isAboveQuota() {
  return host_quota_mb > 0 /* 0 == unlimited */ &&
    ((GenericHost*)this)->getPeriodicStats() > (host_quota_mb * 1000000);
}

/* *************************************** */

void Host::updateStats(struct timeval *tv) {
  ((GenericHost*)this)->updateStats(tv);
  if(http) http->updateStats(tv);

  if(!localHost) return;

  if(tv->tv_sec >= nextSitesUpdate) {
    if(nextSitesUpdate > 0) {
      char oldk[64];

      snprintf(oldk, sizeof(oldk), "%s.old", topSitesKey);
      ntop->getRedis()->rename(topSitesKey, oldk);

      ntop->getRedis()->zTrim(oldk, 10);
    }

    nextSitesUpdate = tv->tv_sec + HOST_SITES_REFRESH;
  }

  if(isAboveQuota() && triggerAlerts()) {
    const char *error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is above quota [%u])";
    char ip_buf[48], *h, msg[512];
    h = ip.print(ip_buf, sizeof(ip_buf));

    snprintf(msg, sizeof(msg),
	     error_msg, ntop->getPrefs()->get_http_prefix(),
	     h, iface->get_name(), h, host_quota_mb);
    iface->getAlertsManager()->storeHostAlert(this, alert_quota, alert_level_warning, msg);
  }

}

/* *************************************** */

u_int32_t Host::getNumAlerts(bool from_alertsmanager)     {
  if(!from_alertsmanager)
    return(num_alerts_detected);

  num_alerts_detected = iface->getAlertsManager()->getNumHostAlerts(this, true)
    + iface->getAlertsManager()->getNumHostAlerts(this, false);

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Refreshing alerts from alertsmanager [num: %i]", num_alerts_detected);

  return(num_alerts_detected);
}

/* *************************************** */

void Host::loadAlertPrefs() {
  loadFlowRateAlertPrefs();
  loadSynAlertPrefs();
  loadFlowsAlertPrefs();
}

/* *************************************** */

void Host::loadFlowRateAlertPrefs() {
  int retval = CONST_MAX_NEW_FLOWS_SECOND;
  char rkey[128], rsp[16];
  char ip_buf[48];

  snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s:%d.flow_rate_alert_threshold",
	   ip.print(ip_buf, sizeof(ip_buf)), vlan_id);
  if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
    retval = atoi(rsp);

  max_new_flows_sec_threshold = retval;
}

/* *************************************** */

void Host::loadSynAlertPrefs() {
  int retval = CONST_MAX_NUM_SYN_PER_SECOND;
  char rkey[128], rsp[16];
  char ip_buf[48];

  snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s:%d.syn_alert_threshold",
	   ip.print(ip_buf, sizeof(ip_buf)), vlan_id);
  if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
    retval = atoi(rsp);

  max_num_syn_sec_threshold = retval;
}

/* *************************************** */

void Host::loadFlowsAlertPrefs() {
  u_int32_t retval = CONST_MAX_NUM_HOST_ACTIVE_FLOWS;
  char rkey[128], rsp[16];
  char ip_buf[48];

  snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s:%d.flows_alert_threshold",
	   ip.print(ip_buf, sizeof(ip_buf)), vlan_id);
  if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
    retval = (u_int32_t)strtoul(rsp, NULL, 10);

  max_num_active_flows = retval;
}

/* *************************************** */

void Host::resetPeriodicStats() {
  ((GenericHost*)this)->resetPeriodicStats();
}

/* *************************************** */

void Host::updateHTTPHostRequest(char *virtual_host_name, u_int32_t num_req,
				 u_int32_t bytes_sent, u_int32_t bytes_rcvd) {
  if(http)
    http->updateHTTPHostRequest(virtual_host_name, num_req, bytes_sent, bytes_rcvd);
}

/* *************************************** */

void Host::setDumpTrafficPolicy(bool new_policy) {
  char buf[64], host[96];

  if(dump_host_traffic == new_policy)
    return; /* Nothing to do */
  else
    dump_host_traffic = new_policy;

  snprintf(host, sizeof(host), "%s@%u", ip.print(buf, sizeof(buf)), vlan_id);

  ntop->getRedis()->hashSet((char*)DUMP_HOST_TRAFFIC, host,
			    (char*)(dump_host_traffic ? "true" : "false"));
};


/* *************************************** */

void Host::readAlertPrefs() {
  trigger_host_alerts = false;

  if(!localHost) return;

  if(!ip.isEmpty()) {
    if(!ntop->getPrefs()->are_alerts_disabled()) {
      char *key, ip_buf[48];

      key = get_string_key(ip_buf, sizeof(ip_buf));
      if(key) {
	char rsp[32];
	ntop->getRedis()->hashGet((char*)CONST_ALERT_PREFS, key, rsp, sizeof(rsp));

	trigger_host_alerts = ((strcmp(rsp, "false") == 0) ? 0 : 1);
      } else
	trigger_host_alerts = false;
    }
  }
}

/* *************************************** */

void Host::incHitter(Host *peer, u_int64_t sent_bytes, u_int64_t rcvd_bytes) {
#ifdef NOTUSED // check for memory corruptions here!
#ifdef NTOPNG_PRO
  if(sent_bytes) sent_to_sketch->update(peer->key(), sent_bytes);
  if(rcvd_bytes) rcvd_from_sketch->update(peer->key(), rcvd_bytes);
#endif
#endif
}

/* *************************************** */

void Host::getPeerBytes(lua_State* vm, u_int32_t peer_key) {
#ifdef NOTUSED
  lua_newtable(vm);

#ifdef NTOPNG_PRO
  if(sent_to_sketch && rcvd_from_sketch) {
    lua_push_int_table_entry(vm, "sent", sent_to_sketch->estimate(peer_key));
    lua_push_int_table_entry(vm, "rcvd", rcvd_from_sketch->estimate(peer_key));
    return;
  }
#endif

  lua_push_int_table_entry(vm, "sent", 0);
  lua_push_int_table_entry(vm, "rcvd", 0);
#endif
}

/* *************************************** */

void Host::incLowGoodputFlows(bool asClient) {
  bool alert = false;

  if(asClient) {
    if(++low_goodput_client_flows > HOST_LOW_GOODPUT_THRESHOLD) alert = true;
  } else {
    if(++low_goodput_server_flows > HOST_LOW_GOODPUT_THRESHOLD) alert = true;
  }

  /* TODO: decide if an alert should be sent in a future version */
  if(alert && (!good_low_flow_detected)) {
#if 0
    char alert_msg[1024], *c, c_buf[64];

    c = get_ip()->print(c_buf, sizeof(c_buf));

    snprintf(alert_msg, sizeof(alert_msg),
	     "Host <A HREF='%s/lua/host_details.lua?host=%s&ifname=%s'>%s</A> has %d low goodput active %s flows",
	     ntop->getPrefs()->get_http_prefix(),
	     c, iface->get_name(), get_name() ? get_name() : c,
	     HOST_LOW_GOODPUT_THRESHOLD, asClient ? "client" : "server");

    iface->getAlertsManager()->engageHostAlert(this,
					       asClient ? (char*)"low_goodput_victim", (char*)"low_goodput_attacker",
					       asClient ? alert_host_under_attack : alert_host_attacker,
					       alert_level_error, msg);
#endif
    good_low_flow_detected = true;
  }
}

/* *************************************** */

void Host::decLowGoodputFlows(bool asClient) {
  bool alert = false;

  if(asClient) {
    if(--low_goodput_client_flows < HOST_LOW_GOODPUT_THRESHOLD) alert = true;
  } else {
    if(--low_goodput_server_flows < HOST_LOW_GOODPUT_THRESHOLD) alert = true;
  }

  if(alert && good_low_flow_detected) {
    /* TODO: send end of alert
       iface->getAlertsManager()->releaseHostAlert(this,
       asClient ? (char*)"low_goodput_victim", (char*)"low_goodput_attacker",
       asClient ? alert_host_under_attack : alert_host_attacker,
       alert_level_error, msg);
    */
    good_low_flow_detected = false;
  }
}

/* *************************************** */

void Host::incrVisitedWebSite(char *hostname) {
  u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;

  if(topSitesKey
     && (strstr(hostname, "in-addr.arpa") == NULL)
     && (sscanf(hostname, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) != 4)
     ) {
#if 0
    char *firstdot = strchr(hostname, '.');

    if(firstdot) {
      char *nextdot = strchr(&firstdot[1], '.');

      ntop->getRedis()->zIncr(topSitesKey, nextdot ? &firstdot[1] : hostname);
    }
#else
    ntop->getRedis()->zIncr(topSitesKey, hostname);
#endif
  }
}

/* *************************************** */

void Host::setDeviceIfIdx(u_int32_t _ip, u_int16_t _v) {
  char dev[48], port[16], value[128], buf[128], buf1[32];

  deviceIfIdx = _v, deviceIP = _ip;

  snprintf(dev, sizeof(dev), "flow_devs.%s", Utils::intoaV4(deviceIP, buf, sizeof(buf)));
  snprintf(port, sizeof(port), "%u", deviceIfIdx);

  snprintf(value, sizeof(value), "%s/%s",
	   Utils::formatMac(mac ? mac->get_mac() : NULL, buf1, sizeof(buf1)),
	   ip.print(buf, sizeof(buf)));

  ntop->getRedis()->hashSet(dev, port, value);
}

/* *************************************** */

void Host::incActivityBytes(UserActivityID id, u_int64_t upbytes, u_int64_t downbytes, u_int64_t bgbytes) {
  if(user_activities) user_activities->incBytes(id, upbytes, downbytes, bgbytes);
}

/* *************************************** */

const UserActivityCounter* Host::getActivityBytes(UserActivityID id) {
  return(user_activities ? user_activities->getBytes(id) : NULL);
}

/* *************************************** */

void Host::incIfaPackets(InterFlowActivityProtos proto, const Flow * flow, time_t when) {
  if(!ifa_stats)
    return;
  else {
    int k = -1;
    float worst = 0.f;
    int i, idx;
    uint tbase = proto*INTER_FLOW_ACTIVITY_SLOTS;

    for (i=0; (i < INTER_FLOW_ACTIVITY_SLOTS)
	   && (ifa_stats[tbase+i].flow != flow); i++) {
      float bad;

      idx = tbase+i;
      if(ifa_stats[idx].flow == NULL)
        // empty slot
        bad = 1.f;
      else
        // old value: estimate goodness
        bad = (when - ifa_stats[idx].last) * 1.f / INTER_FLOW_ACTIVITY_MAX_INTERVAL - ifa_stats[idx].pkts / 100.f;

      if(bad > worst) {
        k = i;
        worst = bad;
      }
    }

    if(i < INTER_FLOW_ACTIVITY_SLOTS) {
      idx = tbase+i;

      if((when - ifa_stats[idx].last) <= INTER_FLOW_ACTIVITY_MAX_INTERVAL) {
        // update slot
        ifa_stats[idx].pkts += 1;
        ifa_stats[idx].last = when;
        k = -1;
      } else {
        // reset slot counters
        k = i;
      }
    }

    if(k != -1) {
      u_int idx = tbase+k;
      // allocate or reset slot
      ifa_stats[idx].flow = flow, ifa_stats[idx].pkts = 1,
	ifa_stats[idx].first = when, ifa_stats[idx].last = when;
    }
  }
}

/* *************************************** */

void Host::getIfaStats(InterFlowActivityProtos proto, time_t when,
		       int * count, u_int32_t * packets, time_t * max_diff) {
  *count = 0, *max_diff = 0, *packets = 0;

  if(ifa_stats) {
    uint tbase = proto*INTER_FLOW_ACTIVITY_SLOTS;

    for(int i=0; i < INTER_FLOW_ACTIVITY_SLOTS; i++) {
      int idx = tbase+i;
      bool timeok = (when - ifa_stats[idx].last) <= INTER_FLOW_ACTIVITY_MAX_INTERVAL;
      bool continuity = (when - ifa_stats[idx].last) <= INTER_FLOW_ACTIVITY_MAX_CONTINUITY_INTERVAL;

      if(continuity || timeok) {
        if(timeok) {
          *count += 1;
          *max_diff = max(ifa_stats[idx].last - ifa_stats[idx].first, *max_diff);
        }

        // this is affected by activity continuity
        *packets += ifa_stats[idx].pkts;
      }
    }
  }
}

/* *************************************** */

/* Splits a string in the format hostip@vlanid: *buf=hostip, *vlan_id=vlanid */
void Host::splitHostVlan(const char *at_sign_str, char*buf, int bufsize, u_int16_t *vlan_id) {
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
  buf[size-1] = '\0';
}
