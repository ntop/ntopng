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

Host::Host(NetworkInterface *_iface, char *ipAddress, u_int16_t _vlanId) : GenericHashEntry(_iface) {
  ip.set(ipAddress);
  initialize(NULL, _vlanId, true);
}

/* *************************************** */

Host::Host(NetworkInterface *_iface, Mac *_mac,
	   u_int16_t _vlanId, IpAddress *_ip) : GenericHashEntry(_iface) {
  ip.set(_ip);

#ifdef BROADCAST_DEBUG
  char buf[32];
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting %s [broadcast: %u]", ip.print(buf, sizeof(buf)), ip.isBroadcastAddress() ? 1 : 0);
#endif

  initialize(_mac, _vlanId, true);
}

/* *************************************** */

Host::~Host() {
  if(num_uses > 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: num_uses=%u", num_uses);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleting %s (%s)", k, localHost ? "local": "remote");

  if(mac)           mac->decUses();
  if(as)            as->decUses();
  if(country)       country->decUses();
  if(vlan)          vlan->decUses();
#ifdef NTOPNG_PRO
  if(quota_enforcement_stats)        delete quota_enforcement_stats;
  if(quota_enforcement_stats_shadow) delete quota_enforcement_stats_shadow;

  if(host_traffic_shapers) {
    for(int i = 0; i < NUM_TRAFFIC_SHAPERS; i++) {
      if(host_traffic_shapers[i])
	delete host_traffic_shapers[i];
    }

    free(host_traffic_shapers);
  }

#endif

  if(symbolic_name)   free(symbolic_name);
  if(ssdpLocation_shadow) free(ssdpLocation_shadow);
  if(ssdpLocation)        free(ssdpLocation);
  if(m)               delete m;
  if(info)            free(info);

  /* Pool counters are updated both in and outside the datapath.
     So decPoolNumHosts must stay in the destructor to preserve counters
     consistency (no thread outside the datapath will change the last pool id) */
  iface->decPoolNumHosts(get_host_pool(), true /* Host is deleted inline */);
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

void Host::initialize(Mac *_mac, u_int16_t _vlanId, bool init_all) {
  ndpiStats = new nDPIStats();

  last_bytes = 0, last_bytes_thpt = bytes_thpt = 0, bytes_thpt_trend = trend_unknown;
  bytes_thpt_diff = 0, last_epoch_update = 0;
  total_activity_time = 0;
  last_packets = 0, last_pkts_thpt = pkts_thpt = 0, pkts_thpt_trend = trend_unknown;
  last_update_time.tv_sec = 0, last_update_time.tv_usec = 0, vlan_id = 0;
  low_goodput_client_flows = low_goodput_server_flows = 0;
  // readStats(); - Commented as if put here it's too early and the key is not yet set
  goodput_bytes_thpt = last_goodput_bytes_thpt = bytes_goodput_thpt_diff = 0;
  bytes_goodput_thpt_trend = trend_unknown;

#ifdef NTOPNG_PRO
  has_blocking_quota = has_blocking_shaper = false;
  quota_enforcement_stats = quota_enforcement_stats_shadow = NULL;
  host_traffic_shapers = NULL;
#endif

  if((mac = _mac))
    mac->incUses();

  if((vlan = iface->getVlan(_vlanId, true)) != NULL)
    vlan->incUses();

  num_resolve_attempts = 0, ssdpLocation = NULL, ssdpLocation_shadow = NULL;

  good_low_flow_detected = false;
  nextResolveAttempt = 0, info = NULL;
  host_label_set = false;
  num_uses = 0, symbolic_name = NULL, vlan_id = _vlanId % MAX_NUM_VLAN,
    total_num_flows_as_client = total_num_flows_as_server = 0,
    num_active_flows_as_client = num_active_flows_as_server = 0;
  first_seen = last_seen = iface->getTimeLastPktRcvd();
  checkpoint_set = false;
  checkpoint_sent_bytes = checkpoint_rcvd_bytes = 0;
  if((m = new(std::nothrow) Mutex()) == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: NULL mutex. Are you running out of memory?");

  memset(&tcpPacketStats, 0, sizeof(tcpPacketStats));
  asn = 0, asname = NULL;
  as = NULL, country = NULL;

  if(init_all) {
    if((as = iface->getAS(&ip, true)) != NULL) {
      as->incUses();
      asn = as->get_asn();
      asname = as->get_asname();
    }

    char country_name[64];
    get_country(country_name, sizeof(country_name));

    if((country = iface->getCountry(country_name, true)) != NULL)
      country->incUses();
  }

  updateHostPool(true /* inline with packet processing */, true /* first inc */);
  reloadHideFromTop();
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
      if(!quota_enforcement_stats) {
	quota_enforcement_stats = new HostPoolStats(iface);

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

void Host::set_mac(u_int8_t *_mac) {
  if(iface)
    set_mac(iface->getMac(_mac, false));
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

  set_mac(mac_address);
}

/* *************************************** */

void Host::lua(lua_State* vm, AddressTree *ptree,
	       bool host_details, bool verbose,
	       bool returnHost, bool asListElement) {
  char buf[64], buf_id[64], *host_id = buf_id;
  char ip_buf[64], *ipaddr = NULL;
  bool mask_host = Utils::maskHost(isLocalHost());
  Mac *m = mac; /* Cache macs as they can be swapped/updated */

  if((ptree && (!match(ptree))) || mask_host)
    return;

#if 0
  if(1) {
    char buf[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "********* %s is %s %s [%p]",
				 ip.print(buf, sizeof(buf)),
				 isLocalHost()  ? "local" : "remote",
				 isSystemHost() ? "systemHost" : "", this);
  }
#endif

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "ip", (ipaddr = printMask(ip_buf, sizeof(ip_buf))));
  lua_push_int_table_entry(vm, "ipkey", ip.key());
  lua_push_bool_table_entry(vm, "localhost", isLocalHost());

  lua_push_str_table_entry(vm, "mac", Utils::formatMac(m ? m->get_mac() : NULL, buf, sizeof(buf)));
  lua_push_int_table_entry(vm, "devtype", m ? m->getDeviceType() : device_unknown);
  lua_push_int_table_entry(vm, "operatingSystem", m ? m->getOperatingSystem() : os_unknown);

  lua_push_int_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_int_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());

  lua_push_bool_table_entry(vm, "privatehost", isPrivateHost());
  lua_push_bool_table_entry(vm, "hiddenFromTop", isHiddenFromTop());

  lua_push_int_table_entry(vm, "num_alerts", triggerAlerts() ? getNumAlerts() : 0);

  lua_push_str_table_entry(vm, "name", get_visual_name(buf, sizeof(buf)));

  lua_push_bool_table_entry(vm, "systemhost", isSystemHost());
  lua_push_bool_table_entry(vm, "is_blacklisted", isBlacklisted());
  lua_push_bool_table_entry(vm, "is_broadcast", ip.isBroadcastAddress());
  lua_push_bool_table_entry(vm, "is_multicast", ip.isMulticastAddress());
  lua_push_bool_table_entry(vm, "childSafe", isChildSafe());
  lua_push_int_table_entry(vm, "asn", asn);
  lua_push_int_table_entry(vm, "host_pool_id", host_pool_id);
  lua_push_str_table_entry(vm, "asname", asname ? asname : (char*)"");
  lua_push_str_table_entry(vm, "os", get_os());

  if(mac && mac->isDhcpHost()) lua_push_bool_table_entry(vm, "dhcpHost", true);
  lua_push_int_table_entry(vm, "active_flows.as_client", num_active_flows_as_client);
  lua_push_int_table_entry(vm, "active_flows.as_server", num_active_flows_as_server);

#ifdef NTOPNG_PRO
  lua_push_bool_table_entry(vm, "has_blocking_quota", has_blocking_quota);
  lua_push_bool_table_entry(vm, "has_blocking_shaper", has_blocking_shaper);
#endif

  lua_push_bool_table_entry(vm, "drop_all_host_traffic", dropAllTraffic());
  lua_push_bool_table_entry(vm, "dump_host_traffic", dumpHostTraffic());
  lua_push_int_table_entry(vm, "active_http_hosts", getActiveHTTPHosts());

  if(host_details) {
    /*
      This has been disabled as in case of an attack, most hosts do not have a name and we will waste
      a lot of time doing activities that are not necessary
    */
    if((symbolic_name == NULL) || (strcmp(symbolic_name, ipaddr) == 0)) {
      /* We resolve immediately the IP address by queueing on the top of address queue */

      ntop->getRedis()->pushHostToResolve(ipaddr, false, true /* Fake to resolve it ASAP */);
    }

    if(ssdpLocation)
      lua_push_str_table_entry(vm, "ssdp", ssdpLocation);
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
			       || tcpPacketStats.pktLost
			       || tcpPacketStats.pktKeepAlive) ? true : false);
    lua_push_int_table_entry(vm, "tcp.packets.retransmissions", tcpPacketStats.pktRetr);
    lua_push_int_table_entry(vm, "tcp.packets.out_of_order", tcpPacketStats.pktOOO);
    lua_push_int_table_entry(vm, "tcp.packets.lost", tcpPacketStats.pktLost);
    lua_push_int_table_entry(vm, "tcp.packets.keep_alive", tcpPacketStats.pktKeepAlive);

  } else {
    /* Limit tcp information to anomalies when host_details aren't required */
    if(tcpPacketStats.pktRetr)
      lua_push_int_table_entry(vm, "tcp.packets.retransmissions", tcpPacketStats.pktRetr);
    if(tcpPacketStats.pktOOO)
      lua_push_int_table_entry(vm, "tcp.packets.out_of_order", tcpPacketStats.pktOOO);
    if(tcpPacketStats.pktLost)
      lua_push_int_table_entry(vm, "tcp.packets.lost", tcpPacketStats.pktLost);
    if(tcpPacketStats.pktKeepAlive)
      lua_push_int_table_entry(vm, "tcp.packets.keep_alive", tcpPacketStats.pktKeepAlive);
  }

  if(host_details) {
    char *continent = NULL, *country_name = NULL, *city = NULL;
    float latitude = 0, longitude = 0;

    if(info) lua_push_str_table_entry(vm, "info", getInfo(buf, sizeof(buf)));

    ntop->getGeolocation()->getInfo(&ip, &continent, &country_name, &city, &latitude, &longitude);
    lua_push_str_table_entry(vm, "continent", continent ? continent : (char*)"");
    lua_push_str_table_entry(vm, "country", country_name ? country_name  : (char*)"");
    lua_push_float_table_entry(vm, "latitude", latitude);
    lua_push_float_table_entry(vm, "longitude", longitude);
    lua_push_str_table_entry(vm, "city", city ? city : (char*)"");
    ntop->getGeolocation()->freeInfo(&continent, &country_name, &city);

    lua_push_int_table_entry(vm, "total_activity_time", total_activity_time);
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

    /* Host ingress/egress drops */
    lua_push_int_table_entry(vm, "bridge.ingress_drops.bytes", ingress_drops.getNumBytes());
    lua_push_int_table_entry(vm, "bridge.ingress_drops.packets",  ingress_drops.getNumPkts());
    lua_push_int_table_entry(vm, "bridge.egress_drops.bytes", egress_drops.getNumBytes());
    lua_push_int_table_entry(vm, "bridge.egress_drops.packets",  egress_drops.getNumPkts());

    lua_push_int_table_entry(vm, "low_goodput_flows.as_client", low_goodput_client_flows);
    lua_push_int_table_entry(vm, "low_goodput_flows.as_server", low_goodput_server_flows);
  }

  lua_push_int_table_entry(vm, "seen.first", first_seen);
  lua_push_int_table_entry(vm, "seen.last", last_seen);
  lua_push_int_table_entry(vm, "duration", get_duration());

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[pkts_thpt: %.2f] [pkts_thpt_trend: %d]", pkts_thpt,pkts_thpt_trend);

  if(ntop->getPrefs()->is_httpbl_enabled())
    lua_push_str_table_entry(vm, "httpbl", get_httpbl());



  if(verbose) {
    char *rsp = serialize();

    if(ndpiStats) ndpiStats->lua(iface, vm, true);
    lua_push_str_table_entry(vm, "json", rsp);
    free(rsp);

    sent_stats.lua(vm, "pktStats.sent");
    recv_stats.lua(vm, "pktStats.recv");


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
    if(isLocalHost() || isSystemHost()) return(false);
    break;

  case location_remote_only:
    if(!(isLocalHost() || isSystemHost())) return(false);
    break;

  case location_all:
    return(false);
    break;
  }

  return(isIdle(ntop->getPrefs()->get_host_max_idle(isLocalHost())));
};

/* *************************************** */

void Host::incStats(u_int32_t when, u_int8_t l4_proto, u_int ndpi_proto,
		    u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
		    u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes) {

  if(sent_packets || rcvd_packets) {
    sent.incStats(sent_packets, sent_bytes), rcvd.incStats(rcvd_packets, rcvd_bytes);

    if(ndpiStats) {
      ndpiStats->incStats(when, ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes),
	ndpiStats->incCategoryStats(when,
				    getInterface()->get_ndpi_proto_category(ndpi_proto),
				    sent_bytes, rcvd_bytes);

    }

    if(when && when - last_epoch_update >= ntop->getPrefs()->get_housekeeping_frequency())
      total_activity_time += ntop->getPrefs()->get_housekeeping_frequency(), last_epoch_update = when;

    updateSeen();

    /* Packet stats sent_stats and rcvd_stats are incremented in Flow::incStats */

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

json_object* Host::getJSONObject() {
  json_object *my_object;
  char buf[32];
  Mac *m = mac;

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  json_object_object_add(my_object, "mac_address", json_object_new_string(Utils::formatMac(m ? m->get_mac() : NULL, buf, sizeof(buf))));

  json_object_object_add(my_object, "seen.first", json_object_new_int64(first_seen));
  json_object_object_add(my_object, "seen.last",  json_object_new_int64(last_seen));
  json_object_object_add(my_object, "asn", json_object_new_int(asn));
  if(symbolic_name)       json_object_object_add(my_object, "symbolic_name", json_object_new_string(symbolic_name));
  if(asname)              json_object_object_add(my_object, "asname",    json_object_new_string(asname ? asname : (char*)""));
  if(strlen(get_os()))    json_object_object_add(my_object, "os",        json_object_new_string(get_os()));
  if(get_traffic_category()[0] != '\0')
    json_object_object_add(my_object, "trafficCategory",    json_object_new_string(get_traffic_category()));
  if(vlan_id != 0)        json_object_object_add(my_object, "vlan_id",   json_object_new_int(vlan_id));
  json_object_object_add(my_object, "ip", ip.getJSONObject());

  json_object_object_add(my_object, "localHost", json_object_new_boolean(isLocalHost()));
  json_object_object_add(my_object, "systemHost", json_object_new_boolean(isSystemHost()));
  json_object_object_add(my_object, "is_blacklisted", json_object_new_boolean(isBlacklisted()));
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
  if(tcpPacketStats.pktKeepAlive) json_object_object_add(my_object,
							 "tcpPacketStats.pktKeepAlive",
							 json_object_new_int(tcpPacketStats.pktKeepAlive));

  /* throughput stats */
  json_object_object_add(my_object, "throughput_bps", json_object_new_double(bytes_thpt));
  json_object_object_add(my_object, "throughput_trend_bps", json_object_new_string(Utils::trend2str(bytes_thpt_trend)));
  json_object_object_add(my_object, "throughput_pps", json_object_new_double(pkts_thpt));
  json_object_object_add(my_object, "throughput_trend_pps", json_object_new_string(Utils::trend2str(pkts_thpt_trend)));
  json_object_object_add(my_object, "flows.as_client", json_object_new_int(total_num_flows_as_client));
  json_object_object_add(my_object, "flows.as_server", json_object_new_int(total_num_flows_as_server));
  if(total_num_dropped_flows)
    json_object_object_add(my_object, "flows.dropped", json_object_new_int(total_num_dropped_flows));

  /* Generic Host */
  json_object_object_add(my_object, "num_alerts", json_object_new_int(triggerAlerts() ? getNumAlerts() : 0));
  json_object_object_add(my_object, "sent", sent.getJSONObject());
  json_object_object_add(my_object, "rcvd", rcvd.getJSONObject());
  json_object_object_add(my_object, "ndpiStats", ndpiStats->getJSONObject(iface));
  json_object_object_add(my_object, "total_activity_time", json_object_new_int(total_activity_time));

  /* The value below is handled by reading dumps on disk as otherwise the string will be too long */
  //json_object_object_add(my_object, "activityStats", activityStats.getJSONObject());

  return(my_object);
}

/* *************************************** */

char* Host::get_visual_name(char *buf, u_int buf_len, bool from_info) {
  bool mask_host = Utils::maskHost(isLocalHost());
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

void Host::incNumFlows(bool as_client) {
  if(as_client)
    total_num_flows_as_client++, num_active_flows_as_client++;
  else
    total_num_flows_as_server++, num_active_flows_as_server++;
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

static bool getProtocolShaper(ndpi_protocol ndpiProtocol, L7Policy_t *policy, u_int8_t *shaper_id, bool isIngress) {
  ShaperDirection_t *sd = NULL;
  int protocol;
  bool shaper_set = false;

  if(!ndpi_is_subprotocol_informative(NULL, ndpiProtocol.master_protocol))
    protocol = ndpiProtocol.app_protocol;
  else
    protocol = ndpiProtocol.master_protocol;

  HASH_FIND_INT(policy->mapping_proto_shaper_id, &protocol, sd);
  if(!sd && protocol != ndpiProtocol.master_protocol && ndpiProtocol.master_protocol != NDPI_PROTOCOL_UNKNOWN) {
    protocol = ndpiProtocol.master_protocol;
    HASH_FIND_INT(policy->mapping_proto_shaper_id, &protocol, sd);
  }

  if(sd) {
    /* A protocol shaper has priority over the category shaper */
    if(sd->protocol_shapers.enabled
#ifdef HAVE_NEDGE
      && ((isIngress ? sd->protocol_shapers.ingress : sd->protocol_shapers.egress) != NEDGE_USER_DEFAULT_POLICY_SHAPER_ID)
#endif
    ) {
      *shaper_id = isIngress ? sd->protocol_shapers.ingress : sd->protocol_shapers.egress;
      shaper_set = true;
    } else if(sd->category_shapers.enabled
#ifdef HAVE_NEDGE
      && ((isIngress ? sd->category_shapers.ingress : sd->category_shapers.egress) != NEDGE_USER_DEFAULT_POLICY_SHAPER_ID)
#endif
    ) {
      *shaper_id = isIngress ? sd->category_shapers.ingress : sd->category_shapers.egress;
      shaper_set = true;
    }
  }

  return shaper_set;
}

TrafficShaper* Host::get_shaper(ndpi_protocol ndpiProtocol, bool isIngress) {
  HostPools *hp;
  TrafficShaper *ts = NULL, **shapers = NULL;
  u_int8_t shaper_id = DEFAULT_SHAPER_ID, pool_shaper = DEFAULT_SHAPER_ID;
  L7Policy_t *policy = NULL;
  L7Policer *policer;
  bool shaper_set = false;

  if(!(policer = iface->getL7Policer())) return NULL;
  if(!(hp = iface->getHostPools())) return policer->getShaper(PASS_ALL_SHAPER_ID);

#ifdef HAVE_NEDGE
  // Avoid setting drop verdicts for wan hosts policy
  if(getMac() && (getMac()->locate() != located_on_lan_interface)) {
    return policer->getShaper(DEFAULT_SHAPER_ID);
  }

  // Avoid dropping critical protocols
  if(Utils::isCriticalNetworkProtocol(ndpiProtocol.master_protocol) ||
	  Utils::isCriticalNetworkProtocol(ndpiProtocol.app_protocol))
    return policer->getShaper(PASS_ALL_SHAPER_ID);
#endif

  policy = policer->getIpPolicy(get_host_pool());
  pool_shaper = hp->getPoolShaper(get_host_pool());

  if(policy) {
    shaper_id = isIngress ? policy->default_shapers.ingress : policy->default_shapers.egress;
    shaper_set = getProtocolShaper(ndpiProtocol, policy, &shaper_id, isIngress);
  }

  if(!shaper_set)
    // Fallback to the pool shaper
    shaper_id = pool_shaper;

#ifdef SHAPER_DEBUG
  {
    char buf[64], buf1[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] [%s@%u][ndpiProtocol=%d/%s] => [policer=%p][shaper_id=%d]",
				 isIngress ? "INGRESS" : "EGRESS",
				 ip.print(buf, sizeof(buf)), vlan_id,
				 ndpiProtocol.app_protocol,
				 ndpi_protocol2name(iface->get_ndpi_struct(), ndpiProtocol, buf1, sizeof(buf1)),
				 policy ? policy : NULL, shaper_id);
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
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s@%u] SHARED Traffic Shaper", ip.print(buf, sizeof(buf)), vlan_id);
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

void Host::get_quota(u_int16_t protocol, u_int64_t *bytes_quota, u_int32_t *secs_quota, u_int32_t *schedule_bitmap, bool *is_category) {
  ShaperDirection_t *sd = NULL;
  u_int64_t bytes = 0;  /* Default: no quota */
  u_int32_t secs = 0;   /* Default: no quota */
  bool category = false; /* Default: no category */
  u_int32_t schedule = 0xFFFFFFFF; /* Default: all day */
  int protocol32 = (int)protocol; /* uthash macro HASH_FIND_INT requires an int */
  L7Policy_t *policy = NULL;

  if(iface->getL7Policer()) policy = iface->getL7Policer()->getIpPolicy(get_host_pool());

  if(policy) {
    HASH_FIND_INT(policy->mapping_proto_shaper_id, &protocol32, sd);

    if(sd) {
      /* A protocol quota has priority over the category quota */
      if(sd->protocol_shapers.enabled) {
	bytes = sd->protocol_shapers.bytes_quota;
	secs = sd->protocol_shapers.secs_quota;
	schedule = sd->protocol_shapers.schedule_bitmap;
	category = false;
      } else if(sd->category_shapers.enabled) {
	bytes = sd->category_shapers.bytes_quota;
	secs = sd->category_shapers.secs_quota;
	schedule = sd->category_shapers.schedule_bitmap;
	category = true;
      }
    }
  }

  *bytes_quota = bytes;
  *secs_quota = secs;
  *is_category = category;
  *schedule_bitmap = schedule;
}

/* *************************************** */

bool Host::checkQuota(u_int16_t protocol, bool *is_category, const struct tm *now) {
  u_int64_t bytes_quota, bytes;
  u_int32_t secs_quota, secs;
  u_int32_t schedule_bitmap;
  ndpi_protocol_category_t category;
  HostPools *pools = getInterface()->getHostPools();
  bool is_above = false;
  bool category_quota;

  if(!pools || get_host_pool() == NO_HOST_POOL_ID) /* Enforce quotas only for custom pools */
    return false;

  get_quota(protocol, &bytes_quota, &secs_quota, &schedule_bitmap, &category_quota);

#ifdef SCHEDULE_DEBUG
  printf("Schedule: proto=0x%08X pool=0x%08X final=%08X\n", schedule_bitmap, pools->getPoolSchedule(get_host_pool()), schedule_bitmap & pools->getPoolSchedule(get_host_pool()));
#endif

  // the actual schedule must honor both the pool schedule and the protocol schedule
  schedule_bitmap &= pools->getPoolSchedule(get_host_pool());

  if (schedule_bitmap != DEFAULT_TIME_SCHEDULE) {
    // see shaper_utils.lua schedule_to_bitmap for full format

    // verify day of the week (bits 1-7), bit 7 is monday
    if(! (schedule_bitmap & (1 << ((6 - now->tm_wday) + 1))))
      is_above = true;
    // verify the hour (bits 31-8), bit 31 is midnight
    else if(! (schedule_bitmap & (1 << ((23 - now->tm_hour) + 8))))
      is_above = true;
  }

  if((!is_above) && ((bytes_quota > 0) || (secs_quota > 0))) {
      category = getInterface()->get_ndpi_proto_category(protocol);

      if(!pools->enforceQuotasPerPoolMember(get_host_pool())) {

	if((category_quota && pools->getCategoryStats(get_host_pool(), category, &bytes, &secs))
	   || (!category_quota && pools->getProtoStats(get_host_pool(), protocol, &bytes, &secs))) {
	  if(((bytes_quota > 0) && (bytes >= bytes_quota))
	     || ((secs_quota > 0) && (secs >= secs_quota)))
	    is_above = true;
	}

      } else if(quota_enforcement_stats) { /* Per pool member quota enforcement */

	if(category_quota)
	  quota_enforcement_stats->getCategoryStats(category, &bytes, &secs);
	else
	  quota_enforcement_stats->getProtoStats(protocol, &bytes, &secs);

	if(((bytes_quota > 0) && (bytes >= bytes_quota))
	   || ((secs_quota > 0) && (secs >= secs_quota)))
	  is_above = true;

      }

    /* note: update is_category only if a quota policy has been found */
    *is_category = category_quota;

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

bool Host::checkCrossApplicationQuota() {
  HostPools *pools = getInterface()->getHostPools();
  u_int64_t cur_bytes = 0;
  u_int32_t cur_duration = 0;
  bool is_above = false;
  L7Policy_t *policy = NULL;

  if(iface->getL7Policer()) policy = iface->getL7Policer()->getIpPolicy(get_host_pool());

  if(pools && policy
     && (policy->cross_application_quotas.bytes_quota > 0
	 || policy->cross_application_quotas.secs_quota > 0)) {
    pools->getStats(get_host_pool(), &cur_bytes, &cur_duration);

    if((policy->cross_application_quotas.bytes_quota > 0
	&& cur_bytes >= policy->cross_application_quotas.bytes_quota)
      || (policy->cross_application_quotas.secs_quota > 0
	  && cur_duration >= policy->cross_application_quotas.secs_quota))
      is_above = true;
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
  GenericTrafficElement::updateStats(tv);
}

/* *************************************** */

void Host::postHashAdd() {
  loadAlertsCounter();
}

/* *************************************** */

bool Host::serializeCheckpoint(json_object *my_object, DetailsLevel details_level) {
  json_object_object_add(my_object, "sent", sent.getJSONObject());
  json_object_object_add(my_object, "rcvd", rcvd.getJSONObject());

  if (details_level >= details_high) {
    json_object_object_add(my_object, "total_activity_time", json_object_new_int(total_activity_time));
    json_object_object_add(my_object, "seen.last", json_object_new_int64(last_seen));
    json_object_object_add(my_object, "ndpiStats", ndpiStats->getJSONObjectForCheckpoint(iface));
    json_object_object_add(my_object, "flows.as_client", json_object_new_int(total_num_flows_as_client));
    json_object_object_add(my_object, "flows.as_server", json_object_new_int(total_num_flows_as_server));
  }

  return true;
}

/* *************************************** */

void Host::checkPointHostTalker(lua_State *vm, bool saveCheckpoint) {
  lua_newtable(vm);

  if (! checkpoint_set) {
    if(saveCheckpoint) checkpoint_set = true;
  } else {
    lua_newtable(vm);
    lua_push_int_table_entry(vm, "sent", checkpoint_sent_bytes);
    lua_push_int_table_entry(vm, "rcvd", checkpoint_rcvd_bytes);
    lua_pushstring(vm, "previous");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  u_int32_t sent_bytes = sent.getNumBytes();
  u_int32_t rcvd_bytes = rcvd.getNumBytes();

  if(saveCheckpoint) {
    checkpoint_sent_bytes = sent_bytes;
    checkpoint_rcvd_bytes = rcvd_bytes;
  }

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "sent", sent_bytes);
  lua_push_int_table_entry(vm, "rcvd", rcvd_bytes);
  lua_pushstring(vm, "current");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
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
    /* TODO: send end of alert  */
    good_low_flow_detected = false;
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
