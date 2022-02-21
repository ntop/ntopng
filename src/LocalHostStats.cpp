/*
 *
 * (C) 2013-22 - ntop.org
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

LocalHostStats::LocalHostStats(Host *_host) : HostStats(_host) {
  top_sites = new (std::nothrow) MostVisitedList(HOST_SITES_TOP_NUMBER);

  dns  = new (std::nothrow) DnsStats();
  http = new (std::nothrow) HTTPstats(_host);
  icmp = new (std::nothrow) ICMPstats();
  peers = new (std::nothrow) PeerStats(MAX_DYNAMIC_STATS_VALUES /* 10 as default */ );

  nextPeriodicUpdate = 0;
  num_contacts_as_cli = num_contacts_as_srv = 0;
  
  num_contacted_hosts_as_client.init(8);       /* 128 bytes */
  num_host_contacts_as_server.init(8);         /* 128 bytes */
  num_contacted_services_as_client.init(8);    /* 128 bytes */
  num_contacted_ports_as_client.init(4);       /* 16 bytes  */
  num_host_contacted_ports_as_server.init(4);  /* 16 bytes  */
  contacts_as_cli.init(4);                     /* 16 bytes  */
  contacts_as_srv.init(4);                     /* 16 bytes  */

  /* hll init, 8 bits -> 256 bytes per LocalHost */
  if(ndpi_hll_init(&hll_contacted_hosts, 8) != 0)
    throw "Failed HLL initialization";  
  hll_delta_value = 0, old_hll_value = 0, new_hll_value = 0;

  /* hll init, 5 bits -> 32 bytes per LocalHost */
  if(ndpi_hll_init(&hll_countries_contacts, 5) != 0)
    throw "Failed HLL initialization";  
  old_hll_countries_value = 0, new_hll_countries_value = 0, hll_delta_countries_value = 0;

  num_dns_servers.init(5);
  num_smtp_servers.init(5);
  num_ntp_servers.init(5);
  num_contacted_domain_names.init(4);
}

/* *************************************** */

LocalHostStats::LocalHostStats(LocalHostStats &s) : HostStats(s) {
  top_sites = new (std::nothrow) MostVisitedList(HOST_SITES_TOP_NUMBER);
  peers = new (std::nothrow) PeerStats(MAX_DYNAMIC_STATS_VALUES /* 10 as default */ );
  dns = s.getDNSstats() ? new (std::nothrow) DnsStats(*s.getDNSstats()) : NULL;
  http = NULL;
  icmp = NULL;
  nextPeriodicUpdate = 0;
  num_contacts_as_cli = num_contacts_as_srv = 0;

  /* hll init, 8 bits -> 256 bytes per LocalHost */
  if(ndpi_hll_init(&hll_contacted_hosts, 8))
    throw "Failed HLL initialization";
  hll_delta_value = 0, old_hll_value = 0, new_hll_value = 0;

  /* hll init, 5 bits -> 32 bytes per LocalHost */
  if(ndpi_hll_init(&hll_countries_contacts, 5) != 0)
    throw "Failed HLL initialization";
  old_hll_countries_value = 0, new_hll_countries_value = 0, hll_delta_countries_value = 0;  
  
  
  num_dns_servers.init(5);
  num_smtp_servers.init(5);
  num_ntp_servers.init(5);
  num_contacted_domain_names.init(4);
}

/* *************************************** */

LocalHostStats::~LocalHostStats() {
  if(top_sites)           delete top_sites;
  if(dns)                 delete dns;
  if(http)                delete http;
  if(icmp)                delete icmp;
  if(peers)               delete(peers);

  ndpi_hll_destroy(&hll_contacted_hosts);
  ndpi_hll_destroy(&hll_countries_contacts);
}

/* *************************************** */

void LocalHostStats::incrVisitedWebSite(char *hostname) {
  u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
  char *firstdot = NULL, *nextdot = NULL;

  if((strstr(hostname, "in-addr.arpa") == NULL)
     && (sscanf(hostname, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3) != 4)
     ) {
    /* HyperLogLog update regarding visited sites */
    ndpi_hll_add(&hll_contacted_hosts, hostname, strlen(hostname));
    
    /* Top Sites update, done only if the preference is enabled */
    if(top_sites
       && ntop->getPrefs()->are_top_talkers_enabled()) {
      if(ntop->isATrackerHost(hostname)) {
	ntop->getTrace()->traceEvent(TRACE_INFO, "[TRACKER] %s", hostname);
	return; /* Ignore trackers */
      }
      
      firstdot = strchr(hostname, '.');
      
      if(firstdot)
	      nextdot = strchr(&firstdot[1], '.');
      
      top_sites->incrVisitedData(nextdot ? &firstdot[1] : hostname, 1);
      iface->incrVisitedWebSite(nextdot ? &firstdot[1] : hostname);
    }
  }
}

/* *************************************** */

void LocalHostStats::updateStats(const struct timeval *tv) {
  HostStats::updateStats(tv);

  if(dns)  dns->updateStats(tv);
  if(icmp) icmp->updateStats(tv);
  if(http) http->updateStats(tv);

  /* 5 Min Update */
  if(tv->tv_sec >= nextPeriodicUpdate) {
    /* hll visited sites update */
    updateContactedHostsBehaviour();

    /* hll countries contacts update */
    updateCountriesContactsBehaviour();
    
    /* Contacted peers update */
    updateHostContacts();

    if(ntop->getPrefs()->are_top_talkers_enabled()) {      
      if(top_sites && host) {
        char additional_key_info[128];
        if(!host->get_mac() && !host->get_ip())
          return;

        /* String like `_1.1.1.1@2` */
        snprintf(additional_key_info, sizeof(additional_key_info), "_%s", host->get_tskey(additional_key_info, sizeof(additional_key_info)));
        top_sites->saveOldData(host->getInterface()->get_id(), additional_key_info, (char *) HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED);
      }
    }

    nextPeriodicUpdate = tv->tv_sec + HOST_SITES_REFRESH;
  }
}
  
/* *************************************** */

void LocalHostStats::updateHostContacts() {
  num_contacts_as_cli = contacts_as_cli.getEstimate(), num_contacts_as_srv = contacts_as_srv.getEstimate();
  if(peers) {
    peers->addElement(num_contacts_as_cli, true);
    peers->addElement(num_contacts_as_srv, false);
  }
  contacts_as_cli.reset(), contacts_as_srv.reset();
}

/* *************************************** */

void LocalHostStats::getJSONObject(json_object *my_object, DetailsLevel details_level) {
  HostStats::getJSONObject(my_object, details_level);

  if(dns)  json_object_object_add(my_object, "dns", dns->getJSONObject());
  if(http) json_object_object_add(my_object, "http", http->getJSONObject());

  /* UDP stats */
  if(udp_sent_unicast) json_object_object_add(my_object, "udpBytesSent.unicast", json_object_new_int64(udp_sent_unicast));
  if(udp_sent_non_unicast) json_object_object_add(my_object, "udpBytesSent.non_unicast", json_object_new_int64(udp_sent_non_unicast));

  addRedisSitesKey();
}

/* *************************************** */

void LocalHostStats::luaHostBehaviour(lua_State* vm) {
  HostStats::luaHostBehaviour(vm);
  
  lua_newtable(vm);
    
  lua_push_float_table_entry(vm, "value", hll_delta_value);
  lua_push_bool_table_entry(vm, "anomaly",      contacted_hosts.anomalyFound());
  lua_push_uint64_table_entry(vm, "lower_bound", contacted_hosts.getLastLowerBound());
  lua_push_uint64_table_entry(vm, "upper_bound", contacted_hosts.getLastUpperBound());

  lua_pushstring(vm, "contacted_hosts_behaviour");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHostStats::luaCountriesBehaviour(lua_State* vm) {
  HostStats::luaHostBehaviour(vm);
  
  lua_newtable(vm);
    
  lua_push_float_table_entry(vm, "value", hll_delta_countries_value);

  lua_pushstring(vm, "countries_contacts");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void LocalHostStats::lua(lua_State* vm, bool mask_host, DetailsLevel details_level) {
  HostStats::lua(vm, mask_host, details_level);

  if((!mask_host) && top_sites && ntop->getPrefs()->are_top_talkers_enabled()) {
    top_sites->lua(vm, (char *) "sites", (char *) "sites.old");
  }

  luaHostBehaviour(vm);

  luaCountriesBehaviour(vm);
  
  if(details_level >= details_high) {
    luaICMP(vm,host->get_ip()->isIPv4(),true);
    luaDNS(vm, true);
    luaHTTP(vm);
    
    /* Contacts */
    lua_newtable(vm);
      
    lua_push_int32_table_entry(vm, "num_contacted_hosts_as_client",
			       num_contacted_hosts_as_client.getEstimate()); 
    lua_push_int32_table_entry(vm, "num_host_contacts_as_server",
			       num_host_contacts_as_server.getEstimate());
    lua_push_int32_table_entry(vm, "num_contacted_services_as_client",
			       num_contacted_services_as_client.getEstimate());
    lua_push_int32_table_entry(vm, "num_contacted_ports_as_client",
			       num_contacted_ports_as_client.getEstimate());
    lua_push_int32_table_entry(vm, "num_host_contacted_ports_as_server",
			       num_host_contacted_ports_as_server.getEstimate());
      
    lua_pushstring(vm, "cardinality");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
    
  }  
}

/* *************************************** */

void LocalHostStats::luaPeers(lua_State *vm) {
  if (peers) {
    if (peers->getSlidingWinStatus()) {
      lua_newtable(vm);

      lua_push_int32_table_entry(vm, "contacted_peers_in_last_5mins_as_cli",
                num_contacts_as_cli); 
      lua_push_int32_table_entry(vm, "contacted_peers_in_last_5mins_as_srv",
                num_contacts_as_srv); 
      lua_push_int32_table_entry(vm, "sliding_avg_peers_as_client",
                peers->getCliSlidingEstimate()); 
      lua_push_int32_table_entry(vm, "sliding_avg_peers_as_server",
                peers->getSrvSlidingEstimate());
      lua_push_int32_table_entry(vm, "tot_avg_peers_as_client",
                peers->getCliTotEstimate());
      lua_push_int32_table_entry(vm, "tot_avg_peers_as_server",
                peers->getSrvTotEstimate());

      lua_pushstring(vm, "peers");
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      return;
    }
  }

  lua_pushnil(vm);
}

/* *************************************** */

void LocalHostStats::deserialize(json_object *o) {
  json_object *obj;

  HostStats::deserialize(o);

  l4stats.deserialize(o);
  removeRedisSitesKey();

  /* packet stats */
  if(json_object_object_get_ex(o, "pktStats.sent", &obj))  sent_stats.deserialize(obj);
  if(json_object_object_get_ex(o, "pktStats.recv", &obj))  recv_stats.deserialize(obj);

  /* UDP stats */
  if(json_object_object_get_ex(o, "udpBytesSent.unicast", &obj))      udp_sent_unicast = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "udpBytesSent.non_unicast", &obj))  udp_sent_non_unicast = json_object_get_int64(obj);

  /* TCP packet stats */
  if(json_object_object_get_ex(o, "tcpPacketStats.sent", &obj))  tcp_packet_stats_sent.deserialize(obj);
  if(json_object_object_get_ex(o, "tcpPacketStats.recv", &obj))  tcp_packet_stats_rcvd.deserialize(obj);

  GenericTrafficElement::deserialize(o, iface);

  if(json_object_object_get_ex(o, "total_activity_time", &obj))  total_activity_time = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "dns", &obj)) {
    if(dns) dns->deserialize(obj);
  }

  if(json_object_object_get_ex(o, "http", &obj)) {
    if(http) http->deserialize(obj);
  }

  if(json_object_object_get_ex(o, "pktStats.sent", &obj)) sent_stats.deserialize(obj);
  if(json_object_object_get_ex(o, "pktStats.recv", &obj)) recv_stats.deserialize(obj);

  if(json_object_object_get_ex(o, "flows.as_client", &obj))  total_num_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "flows.as_server", &obj))  total_num_flows_as_server = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "alerted_flows.as_client", &obj))  alerted_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "alerted_flows.as_server", &obj))  alerted_flows_as_server = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "unreachable_flows.as_client", &obj))  unreachable_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "unreachable_flows.as_server", &obj))  unreachable_flows_as_server = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "host_unreachable_flows.as_client", &obj))  host_unreachable_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "host_unreachable_flows.as_server", &obj))  host_unreachable_flows_as_server = json_object_get_int(obj);
  /* NOTE: total_alerts currently not (de)serialized */

  /* Restores possibly checkpointed data */
  checkpoints.sent_bytes = getNumBytesSent();
  checkpoints.rcvd_bytes = getNumBytesRcvd();
}

/* *************************************** */

void LocalHostStats::lua_get_timeseries(lua_State* vm) {
  luaStats(vm, iface, true /* host details */, true /* verbose */, true /* tsLua */);

  tcp_packet_stats_sent.lua(vm, "tcpPacketStats.sent");
  tcp_packet_stats_rcvd.lua(vm, "tcpPacketStats.rcvd");

  if(dns) dns->lua(vm, false /* NOT verbose */);

  if(icmp) {
    struct ts_icmp_stats icmp_s;
    icmp->getTsStats(&icmp_s);

    lua_push_uint64_table_entry(vm, "icmp.echo_pkts_sent", icmp_s.echo_packets_sent);
    lua_push_uint64_table_entry(vm, "icmp.echo_pkts_rcvd", icmp_s.echo_packets_rcvd);
    lua_push_uint64_table_entry(vm, "icmp.echo_reply_pkts_sent", icmp_s.echo_reply_packets_sent);
    lua_push_uint64_table_entry(vm, "icmp.echo_reply_pkts_rcvd", icmp_s.echo_reply_packets_rcvd);
  }

  luaHostBehaviour(vm);
  luaCountriesBehaviour(vm);
}

/* *************************************** */

bool LocalHostStats::hasAnomalies(time_t when) {
  bool ret = false;

  if(dns)  ret |= dns->hasAnomalies(when);
  if(icmp) ret |= icmp->hasAnomalies(when);

  return ret;
}

/* *************************************** */

void LocalHostStats::luaAnomalies(lua_State* vm, time_t when) {
  if(dns)  dns->luaAnomalies(vm, when);
  if(icmp) icmp->luaAnomalies(vm, when);
}

/* *************************************** */

void LocalHostStats::incStats(time_t when, u_int8_t l4_proto,
			      u_int ndpi_proto, ndpi_protocol_category_t ndpi_category,
			      custom_app_t custom_app,
			      u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
			      u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes,
			      bool peer_is_unicast) {
  HostStats::incStats(when, l4_proto, ndpi_proto, ndpi_category, custom_app,
		      sent_packets, sent_bytes, sent_goodput_bytes,
		      rcvd_packets, rcvd_bytes, rcvd_goodput_bytes, peer_is_unicast);
  
  if(l4_proto == IPPROTO_UDP) {
    if(peer_is_unicast)
      udp_sent_unicast += sent_bytes;
    else
      udp_sent_non_unicast += sent_bytes;
  }
}

/* *************************************** */

void LocalHostStats::removeRedisSitesKey() {
  char additional_key_info[128];

  if(!host->get_mac() && !host->get_ip())
    return;

  /* String like `_1.1.1.1@2` */
  snprintf(additional_key_info, sizeof(additional_key_info), "%s_", host->get_tskey(additional_key_info, sizeof(additional_key_info)));
  /* Deserializing the info */
  top_sites->serializeDeserialize(host->getInterface()->get_id(), false, additional_key_info, (char *) HASHKEY_TOP_SITES_SERIALIZATION_KEY, 
    (char*) HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED, (char*) HASHKEY_LOCAL_HOSTS_TOP_SITES_DAY_KEYS_PUSHED);
}

/* *************************************** */
  
void LocalHostStats::addRedisSitesKey() {
  char additional_key_info[128];

  if(!host->get_mac() && !host->get_ip())
    return;

  /* String like `_1.1.1.1@2` */
  snprintf(additional_key_info, sizeof(additional_key_info), "%s_", host->get_tskey(additional_key_info, sizeof(additional_key_info)));
  /* Serializing the info */
  top_sites->serializeDeserialize(host->getInterface()->get_id(), true, additional_key_info, (char *) HASHKEY_TOP_SITES_SERIALIZATION_KEY, 
    (char*) HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED, (char*) HASHKEY_LOCAL_HOSTS_TOP_SITES_DAY_KEYS_PUSHED);
}

/* *************************************** */

void LocalHostStats::resetTopSitesData() {
  char additional_key_info[128];

  if(!host->get_mac() && !host->get_ip())
    return;
  
  if(!host->getInterface())
    return;

  /* String like `_1.1.1.1@2` */
  snprintf(additional_key_info, sizeof(additional_key_info), "%s_", host->get_tskey(additional_key_info, sizeof(additional_key_info)));
  top_sites->resetTopSitesData(host->getInterface()->get_id(), additional_key_info, (char*) HASHKEY_LOCAL_HOSTS_TOP_SITES_RESET);
}

/* *************************************** */

void LocalHostStats::updateContactedHostsBehaviour() {
  /* Update the old and new hll value and do the delta */
  old_hll_value = new_hll_value;
  new_hll_value = ndpi_hll_count(&hll_contacted_hosts);
  hll_delta_value = abs(new_hll_value - old_hll_value);

#ifdef TRACE_ME
  char buf[64];
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s / %f contacts",
			       host->get_ip()->print(buf, sizeof(buf)),
			       last_hll_contacted_hosts_value);
  ndpi_hll_reset(&hll_contacted_hosts);
#endif
  
  contacted_hosts.addObservation((u_int64_t)hll_delta_value);
}

void LocalHostStats::updateCountriesContactsBehaviour() {
  /* Update the old and new hll value and do the delta */
  old_hll_countries_value = new_hll_countries_value;
  new_hll_countries_value = ndpi_hll_count(&hll_countries_contacts);
  hll_delta_countries_value = abs(new_hll_countries_value - old_hll_countries_value);

#ifdef TRACE_ME
  char buf[64];
  
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s / %f contacts",
			       host->get_ip()->print(buf, sizeof(buf)),
			       last_hll_countries_contacts_value);
  ndpi_hll_reset(&hll_countries_contacts);
#endif

  host->resetCountriesContacts();
}
