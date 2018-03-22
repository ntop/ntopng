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

Host::Host(NetworkInterface *_iface, u_int8_t _mac[6], u_int16_t _vlanId) : GenericHost(_iface) {
  initialize(_mac, _vlanId, true);
}

/* *************************************** */

Host::~Host() {
  if(num_uses > 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: num_uses=%u", num_uses);

  if(!ip.isEmpty()) dumpStats(false);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleting %s (%s)", k, localHost ? "local": "remote");

  serialize2redis(); /* possibly dumps counters and data to redis */

  if(mac)  mac->decUses();
  if(as)   as->decUses();
  if(vlan) vlan->decUses();
#ifdef NTOPNG_PRO
  if(sent_to_sketch)                 delete sent_to_sketch;
  if(rcvd_from_sketch)               delete rcvd_from_sketch;
  if(quota_enforcement_stats)        delete quota_enforcement_stats;
  if(quota_enforcement_stats_shadow) delete quota_enforcement_stats_shadow;

  if(l7Policy)         free_ptree_l7_policy_data((void*)l7Policy);
  if(l7PolicyShadow)   free_ptree_l7_policy_data((void*)l7PolicyShadow);
#endif
  if(icmp)            delete icmp;
  if(dns)             delete dns;
  if(http)            delete http;
  if(user_activities) delete user_activities;
  if(ifa_stats)       delete ifa_stats;
  if(symbolic_name)   free(symbolic_name);
  if(continent)       free(continent);
  if(country)         free(country);
  if(city)            free(city);
  if(categoryStats)   delete categoryStats;
  if(syn_flood_attacker_alert) delete syn_flood_attacker_alert;
  if(syn_flood_victim_alert)   delete syn_flood_victim_alert;
  if(flow_flood_attacker_alert) delete flow_flood_attacker_alert;
  if(flow_flood_victim_alert)  delete flow_flood_victim_alert;
  if(m)               delete m;
  if(top_sites)       delete top_sites;
  if(old_sites)       free(old_sites);
  if(info)            free(info);
}

/* *************************************** */

void Host::set_host_label(char *label_name, bool ignoreIfPresent) {
  if(label_name) {
    char buf[64], buf1[64], *host = ip.print(buf, sizeof(buf));

    host_label_set = true;
    
    if(ignoreIfPresent
       && (!ntop->getRedis()->hashGet((char*)HOST_LABEL_NAMES, host, buf1, (u_int)sizeof(buf1)) /* Found into redis */
       && (buf1[0] != '\0') /* Not empty */ ))
      return;
    else
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
  l7Policy = l7PolicyShadow = NULL;
  has_blocking_quota = has_blocking_shaper = false;
  quota_enforcement_stats = quota_enforcement_stats_shadow = NULL;
#endif
  host_pool_id = NO_HOST_POOL_ID;

  if(_mac == NULL)
    mac = NULL;
  else if((mac = iface->getMac(_mac, _vlanId, true)) != NULL)
    mac->incUses();

  if((vlan = iface->getVlan(_vlanId, true)) != NULL)
    vlan->incUses();

  num_alerts_detected = 0;
  drop_all_host_traffic = false, dump_host_traffic = false, dhcpUpdated = false,
    num_resolve_attempts = 0;
  attacker_max_num_syn_per_sec = ntop->getPrefs()->get_attacker_max_num_syn_per_sec();
  victim_max_num_syn_per_sec = ntop->getPrefs()->get_victim_max_num_syn_per_sec();
  attacker_max_num_flows_per_sec = ntop->getPrefs()->get_attacker_max_num_flows_per_sec();
  victim_max_num_flows_per_sec = ntop->getPrefs()->get_victim_max_num_flows_per_sec();
  good_low_flow_detected = false;
  networkStats = NULL, local_network_id = -1, nextResolveAttempt = 0, info = NULL;
  syn_flood_attacker_alert = new AlertCounter(attacker_max_num_syn_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
  syn_flood_victim_alert = new AlertCounter(victim_max_num_syn_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
  flow_flood_attacker_alert = new AlertCounter(attacker_max_num_flows_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
  flow_flood_victim_alert = new AlertCounter(victim_max_num_flows_per_sec, CONST_MAX_THRESHOLD_CROSS_DURATION);
  host_label_set = false;
  os[0] = '\0', trafficCategory[0] = '\0', blacklisted_host = false, blacklisted_alarm_emitted = false;
  num_uses = 0, symbolic_name = NULL, vlan_id = _vlanId % MAX_NUM_VLAN,
    total_num_flows_as_client = total_num_flows_as_server = 0,
    num_active_flows_as_client = num_active_flows_as_server = 0;
    trigger_host_alerts = false;
  first_seen = last_seen = iface->getTimeLastPktRcvd();
  nextSitesUpdate = 0;
  if((m = new(std::nothrow) Mutex()) == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: NULL mutex. Are you running out of memory?");

  memset(&tcpPacketStats, 0, sizeof(tcpPacketStats));
  continent = NULL, country = NULL, city = NULL;
  asn = 0, asname = NULL;
  as = NULL;
  longitude = 0, latitude = 0;
  k = ip.print(key, sizeof(key));
  snprintf(redis_key, sizeof(redis_key), HOST_SERIALIZED_KEY, iface->get_id(), k, vlan_id);
  dns = NULL, http = NULL, categoryStats = NULL, top_sites = NULL, old_sites = NULL,
    user_activities = NULL, ifa_stats = NULL, icmp = NULL;

  if(init_all) {
    char *strIP = ip.print(buf, sizeof(buf));

    snprintf(host, sizeof(host), "%s@%u", strIP, vlan_id);

    updateLocal();
    updateHostTrafficPolicy(host);
    
    if(localHost) {
      /* initialize this in any case to support runtime 'are_top_talkers_enabled' changes */
      top_sites = new FrequentStringItems(HOST_SITES_TOP_NUMBER);
      old_sites = strdup("{}");

      readDHCPCache();
    }

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loading %s (%s)", k, localHost ? "local": "remote");

    if(localHost || systemHost) {
      dns = new DnsStats();
      http = new HTTPstats(iface->get_hosts_hash());
    }

    if((localHost || systemHost)
       && ntop->getPrefs()->is_idle_local_host_cache_enabled()) {
      char *json;

      if((json = (char*)malloc(HOST_MAX_SERIALIZED_LEN * sizeof(char))) == NULL)
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "Unable to allocate memory to deserialize %s", redis_key);
      else if(!ntop->getRedis()->get(redis_key, json, HOST_MAX_SERIALIZED_LEN)){
	bool shadow_localHost = localHost, shadow_systemHost = systemHost; /* Just in case */
	/* Found saved copy of the host so let's start from the previous state */
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s => %s", redis_key, json);
	ntop->getTrace()->traceEvent(TRACE_INFO, "Deserializing %s", redis_key);

	deserialize(json, redis_key);
	localHost = shadow_localHost, systemHost = shadow_systemHost;
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

    if(!(localHost || systemHost)) {
      blacklisted_host = ntop->isBlacklistedIP(&ip);

      if((!blacklisted_host) && ntop->getPrefs()->is_httpbl_enabled() && ip.isIPv4()) {
	// http:bl only works for IPv4 addresses
	if(ntop->getRedis()->getAddressTrafficFiltering(host, iface, trafficCategory,
							sizeof(trafficCategory), true) == 0) {
	  if(strcmp(trafficCategory, NULL_BL)) {
	    blacklisted_host = true;
	  }
	}
      }
    }

    if((as = iface->getAS(&ip, true)) != NULL) {
      as->incUses();
      asn = as->get_asn();
      asname = as->get_asname();
    }

    if(continent) { free(continent); continent = NULL; }
    if(country)   { free(country);   country = NULL; }
    if(city)      { free(city);      city = NULL;       }
    ntop->getGeolocation()->getInfo(&ip, &continent, &country, &city, &latitude, &longitude);

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

  refreshHostAlertPrefs();
  
  if(!host_serial) computeHostSerial();
  updateHostPool();
  updateHostL7Policy();
}

/* *************************************** */

bool Host::readDHCPCache() {
  if(localHost && mac && (!dhcpUpdated)) {
    /* Check DHCP cache */
    char client_mac[24], buf[64], key[64];

    dhcpUpdated = true;

    if(!mac->isNull()) {
      Utils::formatMac(mac->get_mac(), client_mac, sizeof(client_mac));
      
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

char* Host::get_hostkey(char *buf, u_int buf_len, bool force_vlan) {
  char ipbuf[64];
  char *key = ip.print(ipbuf, sizeof(ipbuf));

  if((vlan_id > 0) || force_vlan)
    snprintf(buf, buf_len, "%s@%u", key, vlan_id);
  else
    strncpy(buf, key, buf_len);

  buf[buf_len-1] = '\0';
  return buf;
}

/* *************************************** */

void Host::updateHostTrafficPolicy(char *key) {
  if(localHost || systemHost) {
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
}

/* *************************************** */

void Host::updateHostL7Policy() {
#ifdef NTOPNG_PRO
    if(!iface->is_bridge_interface() && !iface->getL7Policer())
      return;

    if(ntop->getPro()->has_valid_license()) {

	if(l7PolicyShadow) {
	    free_ptree_l7_policy_data((void*)l7PolicyShadow);
	    l7PolicyShadow = NULL;
	}

	l7PolicyShadow = l7Policy;

#ifdef SHAPER_DEBUG
	{
	    char buf[64];

	    ntop->getTrace()->traceEvent(TRACE_NORMAL,
					 "Updating host policy %s",
					 ip.print(buf, sizeof(buf)));
	}
#endif

	l7Policy = getInterface()->getL7Policer()->getIpPolicy(host_pool_id);
	resetBlockedTrafficStatus();
    }
#endif
}

/* *************************************** */

void Host::updateHostPool() {
  if(!iface)
    return;

  host_pool_id = iface->getHostPool(this);

#ifdef NTOPNG_PRO
  HostPools *hp = iface->getHostPools();

  if(hp && hp->enforceQuotasPerPoolMember(host_pool_id)) {
    /* must allocate a structure to keep track of used quotas */
    if(!quota_enforcement_stats) {
      quota_enforcement_stats = new HostPoolStats();

#ifdef HOST_POOLS_DEBUG
    char buf[128];
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
	"Allocating quota stats for %s [quota_enforcement_stats: %p] [host pool: %i]",
	ip.print(buf, sizeof(buf)), (void*)quota_enforcement_stats, host_pool_id);
#endif

    }
  } else { /* Free the structure that is no longer needed */
    /* It is ensured by the caller that this method is called no more than 1 time per second.
     Therefore, it is safe to delete a previously allocated shadow class */
    if(quota_enforcement_stats_shadow) {
      delete quota_enforcement_stats_shadow;
      quota_enforcement_stats_shadow = NULL;

#ifdef HOST_POOLS_DEBUG
      char buf[128];
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Freeing shadow pointer of longer quota stats for %s [host pool: %i]",
				   ip.print(buf, sizeof(buf)), host_pool_id);
#endif

    }
    if(quota_enforcement_stats) {
      quota_enforcement_stats_shadow = quota_enforcement_stats;
      quota_enforcement_stats = NULL;

#ifdef HOST_POOLS_DEBUG
      char buf[128];
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Moving quota stats to the shadow pointer for %s [host pool: %i]",
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

void Host::updateLocal() {
  localHost = ip.isLocalHost(&local_network_id);

  if(local_network_id >= 0)
    networkStats = getNetworkStats(local_network_id);
  
  systemHost = localHost ? ip.isLocalInterfaceAddress() : false;

  if(0) {
    char buf[64];
    
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s is %s %s [%p]",
				 ip.print(buf, sizeof(buf)),
				 localHost ? "local" : "remote",
				 systemHost ? "systemHost" : "", this);
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

void Host::lua(lua_State* vm, AddressTree *ptree,
	       bool host_details, bool verbose,
	       bool returnHost, bool asListElement,
	       bool exclude_deserialized_bytes) {
  char buf[64], buf_id[64], ip_buf[64], *ipaddr = NULL, *local_net, *host_id = buf_id;
  bool mask_host = Utils::maskHost(localHost);
  
  if((ptree && (!match(ptree))) || mask_host)
    return;

#if 0
  if(1) {
    char buf[64];
    
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "********* %s is %s %s [%p]",
				 ip.print(buf, sizeof(buf)),
				 localHost ? "local" : "remote",
				 systemHost ? "systemHost" : "", this);
  }
#endif
  
  lua_newtable(vm);
  lua_push_str_table_entry(vm, "ip", (ipaddr = ip.printMask(ip_buf, sizeof(ip_buf), localHost)));
  lua_push_int_table_entry(vm, "ipkey", ip.key());

  lua_push_str_table_entry(vm, "mac", Utils::formatMac(mac ? mac->get_mac() : NULL, buf, sizeof(buf)));
  lua_push_bool_table_entry(vm, "localhost", localHost);

  lua_push_int_table_entry(vm, "bytes.sent",
			   sent.getNumBytes() - (exclude_deserialized_bytes ? sent.getNumDeserializedBytes() : 0));
  lua_push_int_table_entry(vm, "bytes.rcvd",
			   rcvd.getNumBytes() - (exclude_deserialized_bytes ? rcvd.getNumDeserializedBytes() : 0));

  lua_push_bool_table_entry(vm, "privatehost", isPrivateHost());

  lua_push_int_table_entry(vm, "num_alerts", triggerAlerts() ? getNumAlerts() : 0);

  lua_push_str_table_entry(vm, "name", get_visual_name(buf, sizeof(buf)));
  lua_push_int32_table_entry(vm, "local_network_id", local_network_id);

  local_net = ntop->getLocalNetworkName(local_network_id);
  if(local_net == NULL)
    lua_push_nil_table_entry(vm, "local_network_name");
  else
    lua_push_str_table_entry(vm, "local_network_name", local_net);

  lua_push_bool_table_entry(vm, "systemhost", systemHost);
  lua_push_bool_table_entry(vm, "is_blacklisted", blacklisted_host);
  lua_push_bool_table_entry(vm, "childSafe", isChildSafe());
  lua_push_int_table_entry(vm, "source_id", source_id);
  lua_push_int_table_entry(vm, "asn", asn);
  lua_push_int_table_entry(vm, "host_pool_id", host_pool_id);
  lua_push_str_table_entry(vm, "asname", asname ? asname : (char*)"");
  lua_push_str_table_entry(vm, "os", os);

  lua_push_str_table_entry(vm, "continent", continent ? continent : (char*)"");
  lua_push_str_table_entry(vm, "country", country ? country : (char*)"");
  lua_push_int_table_entry(vm, "active_flows.as_client", num_active_flows_as_client);
  lua_push_int_table_entry(vm, "active_flows.as_server", num_active_flows_as_server);
  lua_push_int_table_entry(vm, "active_http_hosts", http ? http->get_num_virtual_hosts() : 0);

#ifdef NTOPNG_PRO
  lua_push_bool_table_entry(vm, "has_blocking_quota", has_blocking_quota);
  lua_push_bool_table_entry(vm, "has_blocking_shaper", has_blocking_shaper);
#endif

  if(host_details) {
    /*
      This has been disabled as in case of an attack, most hosts do not have a name and we will waste
      a lot of time doing activities that are not necessary
    */
    if((symbolic_name == NULL) || (strcmp(symbolic_name, ipaddr) == 0)) {
      /* We resolve immediately the IP address by queueing on the top of address queue */

      ntop->getRedis()->pushHostToResolve(ipaddr, false, true /* Fake to resolve it ASAP */);
    }

    if(icmp)
      icmp->lua(ip.isIPv4(), vm);
  }

  /* TCP stats */
  if(host_details) {
    lua_push_int_table_entry(vm, "tcp.packets.sent",  tcp_sent.getNumPkts());
    lua_push_int_table_entry(vm, "tcp.packets.rcvd",  tcp_rcvd.getNumPkts());

    lua_push_int_table_entry(vm, "tcp.bytes.sent", tcp_sent.getNumBytes());
    lua_push_int_table_entry(vm, "tcp.bytes.rcvd", tcp_rcvd.getNumBytes());

    lua_push_bool_table_entry(vm, "tcp.packets.seq_problems",
			      (tcpPacketStats.pktRetr
			       || tcpPacketStats.pktOOO
			       || tcpPacketStats.pktLost) ? true : false);
    lua_push_int_table_entry(vm, "tcp.packets.retransmissions", tcpPacketStats.pktRetr);
    lua_push_int_table_entry(vm, "tcp.packets.out_of_order", tcpPacketStats.pktOOO);
    lua_push_int_table_entry(vm, "tcp.packets.lost", tcpPacketStats.pktLost);

  } else {
    /* Limit tcp information to anomalies when host_details aren't required */
    if(tcpPacketStats.pktRetr > 0)
      lua_push_int_table_entry(vm, "tcp.packets.retransmissions", tcpPacketStats.pktRetr);
    if(tcpPacketStats.pktOOO > 0)
      lua_push_int_table_entry(vm, "tcp.packets.out_of_order", tcpPacketStats.pktOOO);
    if(tcpPacketStats.pktLost)
      lua_push_int_table_entry(vm, "tcp.packets.lost", tcpPacketStats.pktLost);
  }

  if(host_details) {
    lua_push_int_table_entry(vm, "total_activity_time", total_activity_time);

    if(info) lua_push_str_table_entry(vm, "info", getInfo(buf, sizeof(buf)));

    lua_push_float_table_entry(vm, "latitude", latitude);
    lua_push_float_table_entry(vm, "longitude", longitude);
    lua_push_str_table_entry(vm, "city", city ? city : (char*)"");

    lua_push_int_table_entry(vm, "flows.as_client", total_num_flows_as_client);
    lua_push_int_table_entry(vm, "flows.as_server", total_num_flows_as_server);

    lua_push_int_table_entry(vm, "udp.packets.sent",  udp_sent.getNumPkts());
    lua_push_int_table_entry(vm, "udp.bytes.sent", udp_sent.getNumBytes());
    lua_push_int_table_entry(vm, "udp.packets.rcvd",  udp_rcvd.getNumPkts());
    lua_push_int_table_entry(vm, "udp.bytes.rcvd", udp_rcvd.getNumBytes());

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

    lua_push_int_table_entry(vm, "low_goodput_flows.as_client", low_goodput_client_flows);
    lua_push_int_table_entry(vm, "low_goodput_flows.as_server", low_goodput_server_flows);

    if((!mask_host) && top_sites && ntop->getPrefs()->are_top_talkers_enabled()) {
      lua_push_str_table_entry(vm, "sites", top_sites->json());
      lua_push_str_table_entry(vm, "sites.old", old_sites);
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

    if(dns)            dns->lua(vm);
    if(http)           http->lua(vm);
    if(hasAnomalies()) luaAnomalies(vm);
  }

  if(!returnHost)
    host_id = get_hostkey(buf_id, sizeof(buf_id));

  ((GenericTrafficElement*)this)->lua(vm, host_details);

  if(asListElement) {
    lua_pushstring(vm, host_id);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ***************************************** */

/*
  As this method can be called from Lua, in order to avoid concurrency issues
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

/* *************************************** */

bool Host::hasAnomalies() {
  time_t now = time(0);

  return syn_flood_victim_alert->isAboveThreshold(now)
    || syn_flood_attacker_alert->isAboveThreshold(now)
    || flow_flood_victim_alert->isAboveThreshold(now)
    || flow_flood_attacker_alert->isAboveThreshold(now);
}

/* *************************************** */

void Host::luaAnomalies(lua_State* vm) {
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

  if(nextResolveAttempt
     && ((num_resolve_attempts > 1) || (nextResolveAttempt > now) || (nextResolveAttempt == (time_t)-1))) {
    return(symbolic_name);
  } else
    nextResolveAttempt = ntop->getPrefs()->is_dns_resolution_enabled() ? now + MIN_HOST_RESOLUTION_FREQUENCY : (time_t)-1;

  num_resolve_attempts++;
  addr = ip.print(buf, buf_len);

  if((symbolic_name != NULL) && strcmp(symbolic_name, addr))
    return(symbolic_name);

  if(readDHCPCache() && symbolic_name) return(symbolic_name);

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

  switch(ntop->getPrefs()->get_host_stickiness()) {
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

void Host::incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
		    struct site_categories *category,
		    u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		    u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes) {

  if(sent_packets || rcvd_packets) {
    ((GenericHost*)this)->incStats(when, l4_proto, ndpi_proto, sent_packets, sent_bytes, sent_goodput_bytes,
				   rcvd_packets, rcvd_bytes, rcvd_goodput_bytes);

    /* Paket stats sent_stats and rcvd_stats are incremented in Flow::incStats */

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

    if(as) {
      as->incStats(when, ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
    }

    if(mac) {
      mac->incSentStats(sent_packets, sent_bytes);
      mac->incRcvdStats(rcvd_packets, rcvd_bytes);
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
    char *k = ip.print(host_key, sizeof(host_key));

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
  if(continent)           json_object_object_add(my_object, "continent", json_object_new_string(continent));
  if(country)             json_object_object_add(my_object, "country",   json_object_new_string(country));
  if(city)                json_object_object_add(my_object, "city",      json_object_new_string(city));
  if(asname)              json_object_object_add(my_object, "asname",    json_object_new_string(asname ? asname : (char*)""));
  if(strlen(os))          json_object_object_add(my_object, "os",        json_object_new_string(os));
  if(trafficCategory[0] != '\0')   json_object_object_add(my_object, "trafficCategory",    json_object_new_string(trafficCategory));
  if(vlan_id != 0)        json_object_object_add(my_object, "vlan_id",   json_object_new_int(vlan_id));
  if(latitude)            json_object_object_add(my_object, "latitude",  json_object_new_double(latitude));
  if(longitude)           json_object_object_add(my_object, "longitude", json_object_new_double(longitude));
  json_object_object_add(my_object, "ip", ip.getJSONObject());
  json_object_object_add(my_object, "localHost", json_object_new_boolean(localHost));
  json_object_object_add(my_object, "systemHost", json_object_new_boolean(systemHost));
  json_object_object_add(my_object, "is_blacklisted", json_object_new_boolean(blacklisted_host));
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
  json_object_object_add(my_object, "num_alerts", json_object_new_int(triggerAlerts() ? getNumAlerts() : 0));
  json_object_object_add(my_object, "sent", sent.getJSONObject());
  json_object_object_add(my_object, "rcvd", rcvd.getJSONObject());
  json_object_object_add(my_object, "ndpiStats", ndpiStats->getJSONObject(iface));
  json_object_object_add(my_object, "total_activity_time", json_object_new_int(total_activity_time));

  /* The value below is handled by reading dumps on disk as otherwise the string will be too long */
  //json_object_object_add(my_object, "activityStats", activityStats.getJSONObject());

  if(categoryStats)  json_object_object_add(my_object, "categories", categoryStats->getJSONObject());
  if(dns)  json_object_object_add(my_object, "dns", dns->getJSONObject());
  if(http) json_object_object_add(my_object, "http", http->getJSONObject());

  return(my_object);
}

/* *************************************** */

char* Host::get_visual_name(char *buf, u_int buf_len, bool from_info) {
  bool mask_host = Utils::maskHost(localHost);
  char buf2[64];
  char ipbuf[64];
  char *sym_name;

  if(! mask_host) {
    sym_name = from_info ? info : get_name(buf2, sizeof(buf2), false);

    if(sym_name && sym_name[0]) {
      if(ip.isIPv6() && strcmp(ip.print(ipbuf, sizeof(ipbuf)), sym_name)) {
        snprintf(buf, buf_len, "%s [IPv6]", sym_name);
      } else
        strncpy(buf, sym_name, buf_len);
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

  if(!match(ptree)) return(false);
  keybuf_ptr = get_hostkey(keybuf, sizeof(keybuf));

  if(strcasestr((ipbuf_ptr = Utils::formatMac(mac ? mac->get_mac() : NULL, ipbuf, sizeof(ipbuf))), key) /* Match by MAC */
     || strcasestr((ipbuf_ptr = keybuf_ptr), key)                                                  /* Match by hostkey */
     || strcasestr((ipbuf_ptr = get_visual_name(ipbuf, sizeof(ipbuf))), key)) {                    /* Match by name */
    lua_push_str_table_entry(vm, keybuf_ptr, ipbuf_ptr);
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
  if(json_object_object_get_ex(o, "source_id", &obj)) source_id = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "symbolic_name", &obj))  { if(symbolic_name) free(symbolic_name); symbolic_name = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "country", &obj))        { if(country) free(country); country = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "continent", &obj))      { if(continent) free(continent); continent = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "city", &obj))           { if(city) free(city); city = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "os", &obj))             { snprintf(os, sizeof(os), "%s", json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "trafficCategory", &obj)){ snprintf(trafficCategory, sizeof(trafficCategory), "%s", json_object_get_string(obj)); }
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

  if(json_object_object_get_ex(o, "is_blacklisted", &obj)) blacklisted_host     = json_object_get_boolean(obj);

  if(json_object_object_get_ex(o, "sent", &obj))  sent.deserialize(obj);
  if(json_object_object_get_ex(o, "rcvd", &obj))  rcvd.deserialize(obj);

  if(json_object_object_get_ex(o, "total_activity_time", &obj))  total_activity_time = json_object_get_int(obj);

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

  if(localHost && triggerAlerts())
    counter->incHits(when);
}

/* *************************************** */

void Host::incNumFlows(bool as_client) {
  AlertCounter *counter;

  if(as_client) {
    total_num_flows_as_client++, num_active_flows_as_client++;
    counter = flow_flood_attacker_alert;
  } else {
    total_num_flows_as_server++, num_active_flows_as_server++;
    counter = flow_flood_victim_alert;
  }

  if(localHost && triggerAlerts())
    counter->incHits(time(0));
}

/* *************************************** */

void Host::decNumFlows(bool as_client) {
  if(as_client) {
    if(num_active_flows_as_client)
      num_active_flows_as_client--;
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: invalid counter value");
  } else {
    if(num_active_flows_as_server)
      num_active_flows_as_server--;
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: invalid counter value");
  }
}

/* *************************************** */

#ifdef NTOPNG_PRO

u_int8_t Host::get_shaper_id(ndpi_protocol ndpiProtocol, bool isIngress) {
  u_int8_t ret = DEFAULT_SHAPER_ID;
  ShaperDirection_t *sd = NULL;
  L7Policy_t *policy = l7Policy; /*
				    Cache value so that even if updateHostL7Policy()
				    runs in the meantime, we're consistent with the policer
				 */

  if(policy) {
    int protocol = ndpiProtocol.app_protocol;

    HASH_FIND_INT(policy->mapping_proto_shaper_id, &protocol, sd);
    if(!sd) {
      protocol = ndpiProtocol.master_protocol;
      HASH_FIND_INT(policy->mapping_proto_shaper_id, &protocol, sd);
    }

    ret = isIngress ? policy->default_shapers.ingress : policy->default_shapers.egress;

    if(sd) {
      /* A protocol shaper has priority over the category shaper */
      if(sd->protocol_shapers.enabled)
	ret = isIngress ? sd->protocol_shapers.ingress : sd->protocol_shapers.egress;
      else if(sd->category_shapers.enabled)
	ret = isIngress ? sd->category_shapers.ingress : sd->category_shapers.egress;
    }
  }

#ifdef SHAPER_DEBUG
  {
    char buf[64], buf1[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] [%s@%u][ndpiProtocol=%d/%s] => [policer=%p][shaper_id=%d]%s",
				 isIngress ? "INGRESS" : "EGRESS",
				 ip.print(buf, sizeof(buf)), vlan_id,
				 ndpiProtocol.app_protocol,
				 ndpi_protocol2name(iface->get_ndpi_struct(), ndpiProtocol, buf1, sizeof(buf1)),
				 policy ? policy : NULL, ret, sd ? "" : " [DEFAULT]");
  }
#endif

  /* Update blocking status */
  if(!has_blocking_shaper && getInterface()->getL7Policer()) {
    TrafficShaper *shaper = getInterface()->getL7Policer()->getShaper(ret);
    if(shaper->shaping_enabled() && (shaper->get_max_rate_kbit_sec() == 0))
      has_blocking_shaper = true;
  }

  return(ret);
}

/* *************************************** */

void Host::get_quota(u_int16_t protocol, u_int64_t *bytes_quota, u_int32_t *secs_quota, bool *is_category) {
  L7Policy_t *policy = l7Policy; /*
				    Cache value so that even if updateHostL7Policy()
				    runs in the meantime, we're consistent with the policer
				 */
  ShaperDirection_t *sd = NULL;
  u_int64_t bytes = 0;  /* Default: no quota */
  u_int32_t secs = 0;   /* Default: no quota */
  bool category = false; /* Default: no category */
  int protocol32 = (int)protocol; /* uthash macro HASH_FIND_INT requires an int */

  if(policy) {
    HASH_FIND_INT(policy->mapping_proto_shaper_id, &protocol32, sd);

    if(sd) {
      /* A protocol quota has priority over the category quota */
      if(sd->protocol_shapers.enabled) {
        bytes = sd->protocol_shapers.bytes_quota;
        secs = sd->protocol_shapers.secs_quota;
        category = false;
      } else if(sd->category_shapers.enabled) {
        bytes = sd->category_shapers.bytes_quota;
        secs = sd->category_shapers.secs_quota;
        category = true;
      }
    }
  }

  *bytes_quota = bytes;
  *secs_quota = secs;
  *is_category = category;
}

/* *************************************** */

bool Host::checkQuota(u_int16_t protocol, bool *is_category) {
  u_int64_t bytes_quota, bytes;
  u_int32_t secs_quota, secs;
  ndpi_protocol_category_t category;
  HostPools *pools = getInterface()->getHostPools();
  bool is_above = false;

  if(!pools || get_host_pool() == NO_HOST_POOL_ID) /* Enforce quotas only for custom pools */
    return false;

  get_quota(protocol, &bytes_quota, &secs_quota, is_category);

  if((bytes_quota > 0) || (secs_quota > 0)) {
      category = getInterface()->get_ndpi_proto_category(protocol);

      if(!pools->enforceQuotasPerPoolMember(get_host_pool())) {

	if((*is_category && pools->getCategoryStats(get_host_pool(), category, &bytes, &secs))
	   || (!*is_category && pools->getProtoStats(get_host_pool(), protocol, &bytes, &secs))) {
	  if(((bytes_quota > 0) && (bytes >= bytes_quota))
	     || ((secs_quota > 0) && (secs >= secs_quota)))
	    is_above = true;
	}

      } else if(quota_enforcement_stats) { /* Per pool member quota enforcement */

	if(*is_category)
	  quota_enforcement_stats->getCategoryStats(category, &bytes, &secs);
	else
	  quota_enforcement_stats->getProtoStats(protocol, &bytes, &secs);

	if(((bytes_quota > 0) && (bytes >= bytes_quota))
	   || ((secs_quota > 0) && (secs >= secs_quota)))
	  is_above = true;

      }

#ifdef SHAPER_DEBUG
      char buf[128];

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[QUOTA (%s)] [%s@%u] [bytes: %ld/%lu][seconds: %d/%u] => %s %s",
				   ndpi_get_proto_name(iface->get_ndpi_struct(), protocol),
				   ip.print(buf, sizeof(buf)), vlan_id,
				   bytes, bytes_quota,
				   secs, secs_quota,
				   is_above ? (char*)"EXCEEDED" : (char*)"ok",
				   quota_enforcement_stats ? "[QUOTAS enforced per pool member]" : "");
#endif
  }

  has_blocking_quota |= is_above;
  return is_above;
}

/* *************************************** */

void Host::luaUsedQuotas(lua_State* vm) {
  if(quota_enforcement_stats)
    quota_enforcement_stats->lua(vm, iface);
  else
    lua_newtable(vm);
}
#endif

/* *************************************** */

void Host::updateStats(struct timeval *tv) {
  ((GenericHost*)this)->updateStats(tv);
  if(http) http->updateStats(tv);

  if(!localHost) return;

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

u_int32_t Host::getNumAlerts(bool from_alertsmanager) {
  if(!from_alertsmanager)
    return(num_alerts_detected);

  num_alerts_detected = iface->getAlertsManager()->getNumHostAlerts(this, true);

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Refreshing alerts from alertsmanager [num: %i]",
			       num_alerts_detected);

  return(num_alerts_detected);
}

/* *************************************** */

void Host::postHashAdd() {
  loadAlertsCounter();
}

/* *************************************** */

void Host::loadAlertsCounter() {
  char buf[64], counters_key[64];
  char rsp[16];
  char *key = get_hostkey(buf, sizeof(buf), true /* force vlan */);

  if(ntop->getPrefs()->are_alerts_disabled() || !isLocalHost()) {
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

void Host::refreshHostAlertPrefs() {
  bool alerts_read = false;

  if(!ntop->getPrefs()->are_alerts_disabled()
      && (localHost || systemHost)
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
        if((ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0'))
          /* Note: the order of the fields must match that of anomalies_config into alerts_utils.lua */
          sscanf(rsp, "%i|%i|%i|%i", &flow_attacker_pref, &flow_victim_pref, &syn_attacker_pref, &syn_victim_pref);

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
	     "Host <A HREF='%s/lua/host_details.lua?host=%s&ifid=%s'>%s</A> has %d low goodput active %s flows",
	     ntop->getPrefs()->get_http_prefix(),
	     c, iface->get_id(), get_name() ? get_name() : c,
	     HOST_LOW_GOODPUT_THRESHOLD, asClient ? "client" : "server");

    // iface->getAlertsManager()->engageHostAlert(this,
    // 					       asClient ? (char*)"low_goodput_victim", (char*)"low_goodput_attacker",
    // 					       asClient ? alert_host_under_attack : alert_host_attacker,
    // 					       alert_level_error, msg);
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
  char *firstdot = NULL, *nextdot = NULL;

  if(top_sites
     && ntop->getPrefs()->are_top_talkers_enabled()
     && (strstr(hostname, "in-addr.arpa") == NULL)
     && (sscanf(hostname, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) != 4)
     ) {

    firstdot = strchr(hostname, '.');

    if(firstdot)
      nextdot = strchr(&firstdot[1], '.');

    top_sites->add(nextdot ? &firstdot[1] : hostname, 1);

  }
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

void Host::setMDSNInfo(char *str) {
  const char *tokens[] = {
    "._http._tcp.local",
    "._sftp-ssh._tcp.local",
    "._smb._tcp.local",
    "._device-info._tcp.local",
    "._privet._tcp.local",
    "._afpovertcp._tcp.local",
    NULL
  };
  
  if(strstr(str, ".ip6.arpa")) return; /* Ignored for the time being */

  for(int i=0; tokens[i] != NULL; i++) {
    if(strstr(str, tokens[i])) {
      str[strlen(str)-strlen(tokens[i])] = '\0';
      setInfo(str);

      for(i=0; info[i] != '\0'; i++) {
	if(!isascii(info[i]))
	  info[i] = ' ';
      }

      set_host_label(info, true);
      return;
    }
  }  
}

/* *************************************** */

bool Host::IsAllowedTrafficCategory(struct site_categories *category) {
#ifdef NTOPNG_PRO
  if(!ntop->get_flashstart())
    return(true);
  
  L7Policy_t *policy = l7Policy; /*
				   Cache value so that even if updateHostL7Policy()
				   runs in the meantime, we're consistent with the policer
				 */
  
  if(policy) {
    for(int i=0; i<MAX_NUM_CATEGORIES; i++) {
      if(category->categories[i] == 0) break;
      
      u_int8_t cat_id = category->categories[i];
      
      if((cat_id < MAX_NUM_MAPPED_CATEGORIES) &&  /* Check if category id is valid */
         (policy->blocked_categories[cat_id]))    /* Check if the category id is blocked */
        return(false);
    }
  }

  return(true);
#else
  return(true);
#endif
}

/* *************************************** */

void Host::incICMP(u_int8_t icmp_type, u_int8_t icmp_code, bool sent, Host *peer) {
  if(localHost) {
    if(!icmp) icmp = new ICMPstats();
    if(icmp)  icmp->incStats(icmp_type, icmp_code, sent, peer);
  }
}
