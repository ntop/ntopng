/*
 *
 * (C) 2013-15 - ntop.org
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
  ip = new IpAddress();
  initialize(NULL, 0, false);
}

/* *************************************** */

Host::Host(NetworkInterface *_iface, char *ipAddress) : GenericHost(_iface) {
  ip = new IpAddress(ipAddress);
  initialize(NULL, 0, false);
}

/* *************************************** */

Host::Host(NetworkInterface *_iface, u_int8_t mac[6],
	   u_int16_t _vlanId, IpAddress *_ip) : GenericHost(_iface) {
  ip = new IpAddress(_ip);
  initialize(mac, _vlanId, true);
}

/* *************************************** */

Host::Host(NetworkInterface *_iface, u_int8_t mac[6],
	   u_int16_t _vlanId) : GenericHost(_iface) {
  ip = NULL;
  initialize(mac, _vlanId, true);
}

/* *************************************** */

Host::~Host() {
  if(num_uses > 0)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: num_uses=%u", num_uses);

  if(ip && (!ip->isEmpty())) dumpStats(false);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleting %s (%s)", k, localHost ? "local": "remote");

  if((localHost || systemHost)
     && ntop->getPrefs()->is_host_persistency_enabled()) {
    char *json = serialize();
    char host_key[128], key[128];
    char *k = get_string_key(host_key, sizeof(host_key));

    snprintf(key, sizeof(key), "%s.%d.json", k, vlan_id);
    ntop->getRedis()->set(key, json, 3600 /* 1 hour */);
    ntop->getTrace()->traceEvent(TRACE_INFO, "Dumping serialization %s", k);
    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s => %s", k, json);
    free(json);
  }

#ifdef NTOPNG_PRO
  if(sent_to_sketch)   delete sent_to_sketch;
  if(rcvd_from_sketch) delete rcvd_from_sketch;
#endif

  if(dns)  delete dns;
  if(http) delete http;

  if(symbolic_name)  free(symbolic_name);
  if(country)        free(country);
  if(city)           free(city);
  if(asname)         free(asname);

  if(syn_flood_attacker_alert) delete syn_flood_attacker_alert;
  if(syn_flood_victim_alert)   delete syn_flood_victim_alert;
  if(ip) delete ip;
  if(m) delete m;
}

/* *************************************** */

void Host::set_host_label(char *label_name) {
  if(label_name) {
    char buf[64], *host = ip->print(buf, sizeof(buf));

    ntop->getRedis()->hashSet((char*)HOST_LABEL_NAMES, host, label_name);
  }
}

/* *************************************** */

void Host::computeHostSerial() {
  if(ip
     && iface
     && Utils::dumpHostToDB(ip, ntop->getPrefs()->get_dump_hosts_to_db_policy())) {
    if(host_serial) {
      char buf[64];

      /* We need to reconfirm the id (e.g. after a day wrap) */
      ntop->getRedis()->setHostId(iface, NULL, ip->print(buf, sizeof(buf)), host_serial);
    } else
      host_serial = ntop->getRedis()->addHostToDBDump(iface, ip, NULL);
  }
}

/* *************************************** */

void Host::initialize(u_int8_t mac[6], u_int16_t _vlanId, bool init_all) {
  char key[64], redis_key[128], *k;
  u_char* ant_mac =  iface->getAntennaMac();

#ifdef NTOPNG_PRO
  sent_to_sketch = rcvd_from_sketch = NULL;
#endif

  if(ant_mac)
    memcpy(antenna_mac_address, ant_mac, 6); 
  else
    memset(antenna_mac_address, 0, sizeof(antenna_mac_address));
    
  if(mac) memcpy(mac_address, mac, 6); else memset(mac_address, 0, 6);

  //if(_vlanId > 0) ntop->getTrace()->traceEvent(TRACE_NORMAL, "VLAN => %d", _vlanId);

  drop_all_host_traffic = false,  dump_host_traffic = false;

  max_new_flows_sec_threshold = CONST_MAX_NEW_FLOWS_SECOND;
  max_num_syn_sec_threshold = CONST_MAX_NUM_SYN_PER_SECOND;
  max_num_active_flows = CONST_MAX_NUM_HOST_ACTIVE_FLOWS;

  syn_flood_attacker_alert = new AlertCounter(max_num_syn_sec_threshold, CONST_MAX_THRESHOLD_CROSS_DURATION);
  syn_flood_victim_alert = new AlertCounter(max_num_syn_sec_threshold, CONST_MAX_THRESHOLD_CROSS_DURATION);
  category[0] = '\0', os[0] = '\0', httpbl[0] = '\0', blacklisted_host = false;
  num_uses = 0, symbolic_name = NULL, vlan_id = _vlanId,
    ingress_shaper_id = egress_shaper_id = DEFAULT_SHAPER_ID,
    total_num_flows_as_client = total_num_flows_as_server = 0,
    num_active_flows_as_client = num_active_flows_as_server = 0;
  first_seen = last_seen = iface->getTimeLastPktRcvd();
  if((m = new(std::nothrow) Mutex()) == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: NULL mutex. Are you running out of memory?");

  memset(&tcpPacketStats, 0, sizeof(tcpPacketStats));
  asn = 0, asname = NULL, country = NULL, city = NULL;
  longitude = 0, latitude = 0, host_quota_mb = 0;
  k = get_string_key(key, sizeof(key));
  snprintf(redis_key, sizeof(redis_key), "%s.%d.json", k, vlan_id);
  dns = NULL, http = NULL;

#ifdef NTOPNG_PRO
  l7Policy = NULL;
#endif

  if(init_all) {
    if(ip) {
      char buf[64], host[96], json[4096];

      snprintf(host, sizeof(host), "%s@%u", ip->print(buf, sizeof(buf)), vlan_id);

      updateLocal();
      updateHostTrafficPolicy(host);
      systemHost = ip->isLocalInterfaceAddress();

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loading %s (%s)", k, localHost ? "local": "remote");

      if(localHost || systemHost) {
	dns = new DnsStats();
	http = new HTTPStats(iface->get_hosts_hash());
      }

      if(((localHost || systemHost)
	  && ntop->getPrefs()->is_host_persistency_enabled())
	 && (!ntop->getRedis()->get(redis_key, json, sizeof(json)))) {
	/* Found saved copy of the host so let's start from the previous state */
        // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s => %s", redis_key, json);
	ntop->getTrace()->traceEvent(TRACE_INFO, "Deserializing %s", redis_key);
	deserialize(json);
      }

      if(localHost || systemHost
	 || ntop->getPrefs()->is_dns_resolution_enabled_for_all_hosts()) {
	char rsp[256];

	if(ntop->getRedis()->getAddress(host, rsp, sizeof(rsp), true) == 0) {
	  if(symbolic_name) free(symbolic_name);
	  symbolic_name = strdup(rsp);
	}
	// else ntop->getRedis()->pushHostToResolve(host, false, localHost);
      }

      if((!localHost || systemHost) && ntop->getPrefs()->is_httpbl_enabled() && ip->isIPv4()) {
	// http:bl only works for IPv4 addresses
	if(ntop->getRedis()->getAddressHTTPBL(host, iface, httpbl, sizeof(httpbl), true) == 0) {
          if(strcmp(httpbl, NULL_BL)) {
	    blacklisted_host = true;
	    ntop->getTrace()->traceEvent(TRACE_INFO,
					 "Blacklisted host found %s [%s]",
					 host, httpbl);
	  }
	}
      }

      if(asname) { free(asname); asname = NULL; }
      ntop->getGeolocation()->getAS(ip, &asn, &asname);

      if(country) { free(country); country = NULL; }
      if(city)    { free(city); city = NULL;       }
      ntop->getGeolocation()->getInfo(ip, &country, &city, &latitude, &longitude);
    } else {
      char buf[32];

      snprintf(buf, sizeof(buf), "%02X:%02X:%02X:%02X:%02X:%02X",
	       mac_address[0], mac_address[1], mac_address[2],
	       mac_address[3], mac_address[4], mac_address[5]);

      if(symbolic_name) free(symbolic_name);
      symbolic_name = strdup(buf);
      localHost = true;
    }

    if((localHost || systemHost) && ip) {
#ifdef NTOPNG_PRO
      sent_to_sketch   = new CountMinSketch();
      rcvd_from_sketch = new CountMinSketch();
#endif
      readStats();
    }

    readAlertPrefs();
  }

  if(!host_serial) computeHostSerial();
  updateHostL7Policy();
}

/* *************************************** */

void Host::updateHostTrafficPolicy(char *key) {
  if(localHost || systemHost) {
    char buf[64], *host, host_buf[96];

    if(!ip) return;

    if(key)
      host = key;
    else {
      if(vlan_id > 0) {
	snprintf(host_buf, sizeof(host_buf), "%s@%u", ip->print(buf, sizeof(buf)), vlan_id);
	host = host_buf;
      } else
	host = ip->print(buf, sizeof(buf));
    }

    if(iface->is_packet_interface()) {
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
    if((localHost || systemHost) && ip) {
      char host_key[64], hash_name[64], rsp[32];
      char buf[64], *host;
      u_int8_t bitmask;

      l7Policy = getInterface()->getL7Policer()->getIpPolicy(ip, vlan_id, &bitmask);

      host = ip->print(buf, sizeof(buf), bitmask);
      snprintf(host_key, sizeof(host_key), "%s/%u@%u", host,
	       bitmask, vlan_id);

      /* ************************************************* */

      snprintf(hash_name, sizeof(hash_name),
	       "ntopng.prefs.%u.l7_policy_ingress_shaper_id",
	       getInterface()->get_id());

      if((ntop->getRedis()->hashGet(hash_name, host_key, rsp, sizeof(rsp)) != 0)
	 || (rsp[0] == '\0'))
	ingress_shaper_id = DEFAULT_SHAPER_ID;
      else {
	ingress_shaper_id = atoi(rsp);

	if((ingress_shaper_id < DEFAULT_SHAPER_ID) || (ingress_shaper_id >= NUM_TRAFFIC_SHAPERS))
	  ingress_shaper_id = DEFAULT_SHAPER_ID;
      }

      /* ************************************************* */

      snprintf(hash_name, sizeof(hash_name),
	       "ntopng.prefs.%u.l7_policy_egress_shaper_id",
	       getInterface()->get_id());

      if((ntop->getRedis()->hashGet(hash_name, host_key, rsp, sizeof(rsp)) != 0)
	 || (rsp[0] == '\0'))
	egress_shaper_id = DEFAULT_SHAPER_ID;
      else {
	egress_shaper_id = atoi(rsp);

	if((egress_shaper_id < DEFAULT_SHAPER_ID) || (egress_shaper_id >= NUM_TRAFFIC_SHAPERS))
	  egress_shaper_id = DEFAULT_SHAPER_ID;
      }
    } else
      l7Policy = NULL, ingress_shaper_id = egress_shaper_id = DEFAULT_SHAPER_ID;
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
  if(ip)
    localHost = ip->isLocalHost(&local_network_id);

  if(0) {
    char buf[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s is %s",
				 ip->print(buf, sizeof(buf)), localHost ? "local" : "remote");
  }
}

/* *************************************** */

char* Host::get_mac(char *buf, u_int buf_len, u_int8_t *mac) {
  snprintf(buf, buf_len,
	   "%02X:%02X:%02X:%02X:%02X:%02X",
	   mac[0] & 0xFF, mac[1] & 0xFF,
	   mac[2] & 0xFF, mac[3] & 0xFF,
	   mac[4] & 0xFF, mac[5] & 0xFF);

  return(buf);
}

/* *************************************** */

void Host::set_mac(char *m) {
  u_int32_t mac[6] = { 0 };

  if(!strcmp(m, "00:00:00:00:00:00")) return;
  
  sscanf(m, "%02X:%02X:%02X:%02X:%02X:%02X",
	 &mac[0], &mac[1], &mac[2], &mac[3], &mac[4], &mac[5]);
  
  mac_address[0] = mac[0], mac_address[1] = mac[1],
    mac_address[2] = mac[2], mac_address[3] = mac[3],
    mac_address[4] = mac[4], mac_address[5] = mac[5];
}

/* *************************************** */

void Host::lua(lua_State* vm, patricia_tree_t *ptree,
	       bool host_details, bool verbose, bool returnHost) {
  char buf[64];
  char buf_id[64];
  char *ipaddr = NULL;

  if(!match(ptree)) return;

  lua_newtable(vm);
  if(ip) {
    char ip_buf[64];

    lua_push_str_table_entry(vm, "ip", (ipaddr = ip->print(ip_buf, sizeof(ip_buf))));
  } else
    lua_push_nil_table_entry(vm, "ip");
  
  if((antenna_mac_address[0] != 0)
     && (antenna_mac_address[1] != 0)
     && (antenna_mac_address[2] != 0)
     && (antenna_mac_address[3] != 0)
     && (antenna_mac_address[4] != 0)
     && (antenna_mac_address[5] != 0))  
    lua_push_str_table_entry(vm, "antenna_mac", get_mac(buf, sizeof(buf), antenna_mac_address));

  lua_push_str_table_entry(vm, "mac", get_mac(buf, sizeof(buf), mac_address));
  lua_push_int_table_entry(vm, "vlan", vlan_id);
  lua_push_bool_table_entry(vm, "localhost", localHost);

  lua_push_int_table_entry(vm, "bytes.sent", sent.getNumBytes());
  lua_push_int_table_entry(vm, "bytes.rcvd", rcvd.getNumBytes());

  if(ip) {
    char *local_net;

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
			     host_details ? get_name(buf, sizeof(buf), false) :  symbolic_name);
    lua_push_int32_table_entry(vm, "local_network_id", local_network_id);

    local_net = ntop->getLocalNetworkName(local_network_id);
    if(local_net == NULL)
      lua_push_nil_table_entry(vm, "local_network_name");
    else
      lua_push_str_table_entry(vm, "local_network_name", local_net);

    lua_push_bool_table_entry(vm, "systemhost", systemHost);
    lua_push_int_table_entry(vm, "source_id", source_id);
    lua_push_int_table_entry(vm, "asn", ip ? asn : 0);

    lua_push_str_table_entry(vm, "asname", ip ? asname : (char*)"");
    lua_push_str_table_entry(vm, "os", os);

    lua_push_str_table_entry(vm, "country", country ? country : (char*)"");
    lua_push_int_table_entry(vm, "active_flows.as_client", num_active_flows_as_client);
    lua_push_int_table_entry(vm, "active_flows.as_server", num_active_flows_as_server);
    lua_push_int_table_entry(vm, "active_http_hosts", http ? http->get_num_virtual_hosts() : 0);

    if(host_details) {
      lua_push_float_table_entry(vm, "latitude", latitude);
      lua_push_float_table_entry(vm, "longitude", longitude);
      lua_push_str_table_entry(vm, "city", city ? city : (char*)"");
      lua_push_int_table_entry(vm, "packets.sent", sent.getNumPkts());
      lua_push_int_table_entry(vm, "packets.rcvd", rcvd.getNumPkts());
      lua_push_int_table_entry(vm, "flows.as_client", total_num_flows_as_client);
      lua_push_int_table_entry(vm, "flows.as_server", total_num_flows_as_server);
      lua_push_int_table_entry(vm, "udp.packets.sent",  udp_sent.getNumPkts());
      lua_push_int_table_entry(vm, "udp.bytes.sent", udp_sent.getNumBytes());
      lua_push_int_table_entry(vm, "udp.packets.rcvd",  udp_rcvd.getNumPkts());
      lua_push_int_table_entry(vm, "udp.bytes.rcvd", udp_rcvd.getNumBytes());

      lua_push_int_table_entry(vm, "tcp.packets.sent",  tcp_sent.getNumPkts());

      lua_push_bool_table_entry(vm, "tcp.packets.seq_problems",
				(tcpPacketStats.pktRetr
				 | tcpPacketStats.pktOOO
				 | tcpPacketStats.pktLost) ? true : false);
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
    }

    lua_push_int_table_entry(vm, "seen.first", first_seen);
    lua_push_int_table_entry(vm, "seen.last", last_seen);
    lua_push_int_table_entry(vm, "duration", get_duration());

    lua_push_float_table_entry(vm, "throughput_bps", bytes_thpt);
    lua_push_float_table_entry(vm, "last_throughput_bps", last_bytes_thpt);
    lua_push_int_table_entry(vm, "throughput_trend_bps", bytes_thpt_trend);
    lua_push_float_table_entry(vm, "throughput_trend_bps_diff", bytes_thpt_diff);

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[bytes_thpt: %.2f] [bytes_thpt_trend: %d]", bytes_thpt,bytes_thpt_trend);
    lua_push_float_table_entry(vm, "throughput_pps", pkts_thpt);
    lua_push_float_table_entry(vm, "last_throughput_pps", last_pkts_thpt);
    lua_push_int_table_entry(vm, "throughput_trend_pps", pkts_thpt_trend);

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[pkts_thpt: %.2f] [pkts_thpt_trend: %d]", pkts_thpt,pkts_thpt_trend);
    lua_push_int_table_entry(vm, "num_alerts", getNumAlerts());

    if(ip) {
      if(ntop->get_categorization()) lua_push_str_table_entry(vm, "category", get_category());
      if(ntop->getPrefs()->is_httpbl_enabled()) lua_push_str_table_entry(vm, "httpbl", get_httpbl());
    }

    lua_push_bool_table_entry(vm, "dump_host_traffic", dump_host_traffic);

    if(verbose) {
      char *rsp = serialize();

      if(ndpiStats) ndpiStats->lua(iface->get_view(), vm);
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
        sprintf(buf_id, "%s",(ip != NULL) ? ip->print(buf, sizeof(buf)) : get_mac(buf, sizeof(buf), mac_address));
      } else {
        sprintf(buf_id, "%s@%d",(ip != NULL) ? ip->print(buf, sizeof(buf)) : get_mac(buf, sizeof(buf), mac_address), vlan_id );
      }

      lua_pushstring(vm,buf_id);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  } else {
    /* Use the ip@vlan_id as a key only in case of multi vlan_id, otherwise use only the ip as a key */
    if(vlan_id == 0) {
      sprintf(buf_id, "%s",(ip != NULL) ? ip->print(buf, sizeof(buf)) : get_mac(buf, sizeof(buf), mac_address));
    } else {
      sprintf(buf_id, "%s@%d",(ip != NULL) ? ip->print(buf, sizeof(buf)) : get_mac(buf, sizeof(buf), mac_address),vlan_id );
    }
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
void Host::setName(char *name, bool update_categorization) {
  if(m) m->lock(__FILE__, __LINE__);
  if((symbolic_name == NULL) || (symbolic_name && strcmp(symbolic_name, name))) {
    if(symbolic_name) free(symbolic_name);
    symbolic_name = strdup(name);
  }
  if(m) m->unlock(__FILE__, __LINE__);

  refreshCategory();
}

/* ***************************************** */

void Host::refreshCategory() {
  char buf[128] =  { 0 };
  char* ip_addr = ip->print(buf, sizeof(buf));

  if((symbolic_name != NULL)
     && strcmp(ip_addr, symbolic_name)
     && (category[0] == '\0')
     && ip
     && ip->isIPv4()
     && (!ip->isMulticastAddress())
     && (!ip->isBroadcastAddress())
     && ntop->get_categorization()
     ) {
    ntop->get_categorization()->findCategory(symbolic_name, category, sizeof(category), false);
  }

  if(category[0] == '\0')
    snprintf(category, sizeof(category), "%s", CATEGORIZATION_SAFE_SITE);
}

/* ***************************************** */

void Host::refreshHTTPBL() {
  if(ip && ip->isIPv4() && (!localHost) && (httpbl[0] == '\0') && ntop->getPrefs()->is_httpbl_enabled()) {
    char buf[128] =  { 0 };
    char* ip_addr = ip->print(buf, sizeof(buf));

    ntop->get_httpbl()->findHTTPBL(ip_addr, httpbl, sizeof(httpbl), false);
  }
}

/* ***************************************** */

char* Host::get_name(char *buf, u_int buf_len, bool force_resolution_if_not_found) {
  if(ip == NULL) {
    return(get_mac(buf, buf_len, mac_address));
  } else {
    char *addr, redis_buf[64];
    int rc;

    addr = ip->print(buf, buf_len);

    if((symbolic_name != NULL) && strcmp(symbolic_name, addr))
      return(symbolic_name);

    rc = ntop->getRedis()->getAddress(addr, redis_buf, sizeof(redis_buf),
				      force_resolution_if_not_found);

    if(rc == 0)
      setName(redis_buf, false);
    else {
      if(symbolic_name != NULL) free(symbolic_name);

      symbolic_name = strdup(addr);
    }

    return(symbolic_name);
  }
}

/* *************************************** */

int Host::compare(Host *h) {
  if(ip)
    return(ip->compare(h->ip));
  else
    return(memcmp(mac_address, h->mac_address, 6));
}

/* ***************************************** */

bool Host::idle() {
  if(num_uses > 0) return(false);

  if(!iface->is_purge_idle_interface()) return(false);

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

/* ***************************************** */

u_int32_t Host::key() {
  if(ip)
    return(ip->key());
  else {
    u_int32_t hash = 0;

    for(int i=0; i<6; i++) hash += mac_address[i] << (i+1);

    return(hash);
  }
}

/* *************************************** */

void Host::incStats(u_int8_t l4_proto, u_int ndpi_proto,
		    u_int64_t sent_packets, u_int64_t sent_bytes,
		    u_int64_t rcvd_packets, u_int64_t rcvd_bytes) {

  if(sent_packets || rcvd_packets) {
    ((GenericHost*)this)->incStats(l4_proto, ndpi_proto, sent_packets,
				   sent_bytes, rcvd_packets, rcvd_bytes);

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
  }
}

/* *************************************** */

char* Host::get_string_key(char *buf, u_int buf_len) {
  if(ip != NULL)
    return(ip->print(buf, buf_len));
  else
    return(get_mac(buf, buf_len, mac_address));
}

/* *************************************** */

char* Host::serialize() {
  json_object *my_object;
  char *rsp, buf[32];

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  json_object_object_add(my_object, "mac_address", json_object_new_string(get_mac(buf, sizeof(buf), mac_address)));

  json_object_object_add(my_object, "asn", json_object_new_int(asn));
  if(symbolic_name)       json_object_object_add(my_object, "symbolic_name", json_object_new_string(symbolic_name));
  if(country)             json_object_object_add(my_object, "country",   json_object_new_string(country));
  if(city)                json_object_object_add(my_object, "city",      json_object_new_string(city));
  if(asname)              json_object_object_add(my_object, "asname",    json_object_new_string(asname));
  if(category[0] != '\0') json_object_object_add(my_object, "category",  json_object_new_string(category));
  if(httpbl[0] != '\0')   json_object_object_add(my_object, "httpbl",    json_object_new_string(httpbl));
  if(vlan_id != 0)        json_object_object_add(my_object, "vlan_id",   json_object_new_int(vlan_id));
  if(latitude)            json_object_object_add(my_object, "latitude",  json_object_new_double(latitude));
  if(longitude)           json_object_object_add(my_object, "longitude", json_object_new_double(longitude));
  if(ip)                  json_object_object_add(my_object, "ip", ip->getJSONObject());
  json_object_object_add(my_object, "localHost", json_object_new_boolean(localHost));
  json_object_object_add(my_object, "systemHost", json_object_new_boolean(systemHost));
  json_object_object_add(my_object, "tcp_sent", tcp_sent.getJSONObject());
  json_object_object_add(my_object, "tcp_rcvd", tcp_rcvd.getJSONObject());
  json_object_object_add(my_object, "udp_sent", udp_sent.getJSONObject());
  json_object_object_add(my_object, "udp_rcvd", udp_rcvd.getJSONObject());
  json_object_object_add(my_object, "icmp_sent", icmp_sent.getJSONObject());
  json_object_object_add(my_object, "icmp_rcvd", icmp_rcvd.getJSONObject());
  json_object_object_add(my_object, "other_ip_sent", other_ip_sent.getJSONObject());
  json_object_object_add(my_object, "other_ip_rcvd", other_ip_rcvd.getJSONObject());
  json_object_object_add(my_object, "pktStats.sent", sent_stats.getJSONObject());
  json_object_object_add(my_object, "pktStats.recv", recv_stats.getJSONObject());
  json_object_object_add(my_object, "throughput_bps", json_object_new_double(bytes_thpt));
  json_object_object_add(my_object, "throughput_trend_bps", json_object_new_string(Utils::trend2str(bytes_thpt_trend)));
  json_object_object_add(my_object, "throughput_pps", json_object_new_double(pkts_thpt));
  json_object_object_add(my_object, "throughput_trend_pps", json_object_new_string(Utils::trend2str(pkts_thpt_trend)));
  json_object_object_add(my_object, "flows.as_client", json_object_new_int(total_num_flows_as_client));
  json_object_object_add(my_object, "flows.as_server", json_object_new_int(total_num_flows_as_server));

  /* Generic Host */
  json_object_object_add(my_object, "num_alerts", json_object_new_int(getNumAlerts()));
  json_object_object_add(my_object, "sent", sent.getJSONObject());
  json_object_object_add(my_object, "rcvd", rcvd.getJSONObject());
  json_object_object_add(my_object, "ndpiStats", ndpiStats->getJSONObject(iface));

  /* The value below is handled by reading dumps on disk as otherwise the string will be too long */
  //json_object_object_add(my_object, "activityStats", activityStats.getJSONObject());

  if(dns)  json_object_object_add(my_object, "dns", dns->getJSONObject());
  if(http) json_object_object_add(my_object, "http", http->getJSONObject());

  //ntop->getTrace()->traceEvent(TRACE_WARNING, "%s()", __FUNCTION__);
  rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* *************************************** */

bool Host::addIfMatching(lua_State* vm, patricia_tree_t *ptree, char *key) {
  char keybuf[64] = { 0 }, *r;

  if(!match(ptree)) return(false);

  // if(symbolic_name) ntop->getTrace()->traceEvent(TRACE_WARNING, "%s/%s", symbolic_name, ip->print(keybuf, sizeof(keybuf)));

  if(strcasestr((r = get_mac(keybuf, sizeof(keybuf), mac_address)), key)) {
    lua_push_str_table_entry(vm, get_string_key(keybuf, sizeof(keybuf)), r);
    return(true);
  } else if(ip && strcasestr((r = ip->print(keybuf, sizeof(keybuf))), key)) {
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

bool Host::deserialize(char *json_str) {
  json_object *o, *obj;

  if((o = json_tokener_parse(json_str)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error: %s", json_str);
    return(false);
  }

  if(json_object_object_get_ex(o, "mac_address", &obj)) set_mac((char*)json_object_get_string(obj));
  if(json_object_object_get_ex(o, "asn", &obj)) asn = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "source_id", &obj)) source_id = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "symbolic_name", &obj))  { if(symbolic_name) free(symbolic_name); symbolic_name = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "country", &obj))        { if(country) free(country); country = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "city", &obj))           { if(city) free(city); city = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "asname", &obj))         { if(asname) free(asname); asname = strdup(json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "category", &obj))       { snprintf(category, sizeof(category), "%s", json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "httpbl", &obj))         { snprintf(httpbl, sizeof(httpbl), "%s", json_object_get_string(obj)); }
  if(json_object_object_get_ex(o, "vlan_id", &obj))   vlan_id = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "latitude", &obj))  latitude  = (float)json_object_get_double(obj);
  if(json_object_object_get_ex(o, "longitude", &obj)) longitude = (float)json_object_get_double(obj);
  if(json_object_object_get_ex(o, "ip", &obj))  { if(ip == NULL) ip = new IpAddress(); if(ip) ip->deserialize(obj); }
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
  if(json_object_object_get_ex(o, "flows.as_client", &obj))  total_num_flows_as_client = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "flows.as_server", &obj))  total_num_flows_as_server = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "num_alerts", &obj)) num_alerts_detected = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "sent", &obj))  sent.deserialize(obj);
  if(json_object_object_get_ex(o, "rcvd", &obj))  rcvd.deserialize(obj);

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

    h = ip->print(ip_buf, sizeof(ip_buf));

    if(syn_sent) {
      error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is a SYN flooder [%u SYNs sent in the last %u sec] %s";
      snprintf(msg, sizeof(msg),
	       error_msg, ntop->getPrefs()->get_http_prefix(),
	       h, iface->get_name(), h,
	       counter->getCurrentHits(),
	       counter->getOverThresholdDuration(),
	       f->print(flow_buf, sizeof(flow_buf)));
    } else {
      Host *attacker = f->get_srv_host();
      IpAddress *aip = attacker->get_ip();
      char aip_buf[48], *aip_ptr;
      aip_ptr = aip->print(aip_buf, sizeof(aip_buf));
      error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is under SYN flood attack by host %s [%u SYNs received in the last %u sec] %s";
      snprintf(msg, sizeof(msg),
	       error_msg, ntop->getPrefs()->get_http_prefix(),
	       h, iface->get_name(), h, aip_ptr,
	       counter->getCurrentHits(),
	       counter->getOverThresholdDuration(),
	       f->print(flow_buf, sizeof(flow_buf)));
    }

    ntop->getTrace()->traceEvent(TRACE_INFO, "SYN Flood: %s", msg);
    ntop->getRedis()->queueAlert(alert_level_error, alert_syn_flood, msg);
    incNumAlerts();
  }
}

/* *************************************** */

void Host::incNumFlows(bool as_client) {
  if(!localHost || !triggerAlerts()) return;

  if(as_client) {
    total_num_flows_as_client++, num_active_flows_as_client++;

    if(num_active_flows_as_client == max_num_active_flows) {
      const char* error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is a possible scanner [%u active flows]";
      char ip_buf[48], *h, msg[512];

      h = ip->print(ip_buf, sizeof(ip_buf));

      snprintf(msg, sizeof(msg),
	       error_msg, ntop->getPrefs()->get_http_prefix(),
	       h, iface->get_name(), h, num_active_flows_as_client);

      ntop->getTrace()->traceEvent(TRACE_INFO, "Begin scan attack: %s", msg);
      ntop->getRedis()->queueAlert(alert_level_error, alert_flow_flood, msg);
      incNumAlerts();
    }
  } else {
    total_num_flows_as_server++, num_active_flows_as_server++;

    if(num_active_flows_as_server == max_num_active_flows) {
      const char* error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is possibly under scan attack [%u active flows]";
      char ip_buf[48], *h, msg[512];

      h = ip->print(ip_buf, sizeof(ip_buf));

      snprintf(msg, sizeof(msg),
	       error_msg, ntop->getPrefs()->get_http_prefix(),
	       h, iface->get_name(), h, num_active_flows_as_server);

      ntop->getTrace()->traceEvent(TRACE_INFO, "Begin scan attack: %s", msg);
      ntop->getRedis()->queueAlert(alert_level_error, alert_flow_flood, msg);
      incNumAlerts();
    }
  }
}

/* *************************************** */

void Host::decNumFlows(bool as_client) {
  if(!localHost || !triggerAlerts()) return;

  if(as_client) {
    if(num_active_flows_as_client) {
      num_active_flows_as_client--;

      if(num_active_flows_as_client == max_num_active_flows) {
	const char* error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is no longer a possible scanner [%u active flows]";
	char ip_buf[48], *h, msg[512];

	h = ip->print(ip_buf, sizeof(ip_buf));

	snprintf(msg, sizeof(msg),
		 error_msg, ntop->getPrefs()->get_http_prefix(),
		 h, iface->get_name(), h, num_active_flows_as_client);

	ntop->getTrace()->traceEvent(TRACE_INFO, "End scan attack: %s", msg);
	ntop->getRedis()->queueAlert(alert_level_info, alert_flow_flood, msg);
	incNumAlerts();
      }
    } else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: invalid counter value");
  } else {
    if(num_active_flows_as_server) {
      num_active_flows_as_server--;

      if(num_active_flows_as_server == max_num_active_flows) {
	const char* error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is no longer under scan attack [%u active flows]";
	char ip_buf[48], *h, msg[512];

	h = ip->print(ip_buf, sizeof(ip_buf));

	snprintf(msg, sizeof(msg),
		 error_msg, ntop->getPrefs()->get_http_prefix(),
		 h, iface->get_name(), h, num_active_flows_as_server);

	ntop->getTrace()->traceEvent(TRACE_INFO, "End scan attack: %s", msg);
	ntop->getRedis()->queueAlert(alert_level_info, alert_flow_flood, msg);
	incNumAlerts();
      }
    } else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: invalid counter value");
  }
}

/* *************************************** */

void Host::setQuota(u_int32_t new_quota) {
  char buf[64], host[96];

  snprintf(host, sizeof(host), "%s@%u", ip->print(buf, sizeof(buf)), vlan_id);
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

  if(!localHost || !triggerAlerts()) return;

  if(isAboveQuota()) {
    const char *error_msg = "Host <A HREF=%s/lua/host_details.lua?host=%s&ifname=%s>%s</A> is above quota [%u])";
    char ip_buf[48], *h, msg[512];
    h = ip->print(ip_buf, sizeof(ip_buf));

    snprintf(msg, sizeof(msg),
             error_msg, ntop->getPrefs()->get_http_prefix(),
             h, iface->get_name(), h, host_quota_mb);
    ntop->getRedis()->queueAlert(alert_level_warning, alert_quota, msg);
  }
}

/* *************************************** */

void Host::loadAlertPrefs() {
  loadFlowRateAlertPrefs();
  loadSynAlertPrefs();
  loadFlowsAlertPrefs();
}

void Host::loadFlowRateAlertPrefs() {
  int retval = CONST_MAX_NEW_FLOWS_SECOND;

  if(ip != NULL) {
    char rkey[128], rsp[16];
    char ip_buf[48];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s:%d.flow_rate_alert_threshold",
             ip->print(ip_buf, sizeof(ip_buf)), vlan_id);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = atoi(rsp);
  }

  max_new_flows_sec_threshold = retval;
}

void Host::loadSynAlertPrefs() {
  int retval = CONST_MAX_NUM_SYN_PER_SECOND;

  if(ip != NULL) {
    char rkey[128], rsp[16];
    char ip_buf[48];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s:%d.syn_alert_threshold",
             ip->print(ip_buf, sizeof(ip_buf)), vlan_id);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = atoi(rsp);
  }

  max_num_syn_sec_threshold = retval;
}

void Host::loadFlowsAlertPrefs() {
  int retval = CONST_MAX_NUM_HOST_ACTIVE_FLOWS;

  if(ip != NULL) {
    char rkey[128], rsp[16];
    char ip_buf[48];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s:%d.flows_alert_threshold",
             ip->print(ip_buf, sizeof(ip_buf)), vlan_id);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = atoi(rsp);
  }

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

  snprintf(host, sizeof(host), "%s@%u", ip->print(buf, sizeof(buf)), vlan_id);

  ntop->getRedis()->hashSet((char*)DUMP_HOST_TRAFFIC, host,
			    (char*)(dump_host_traffic ? "true" : "false"));
};


/* *************************************** */

void Host::readAlertPrefs() {
  trigger_host_alerts = false;

  if(!localHost) return;

  if(ip && (!ip->isEmpty())) {
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

bool Host::isInCommunity(int community_id) {
  CommunitiesManager *cm = ntop->getCommunitiesManager();
  struct ipAddress *ip = NULL;

  if(get_ip() == NULL)
    return false;
  ip = get_ip()->getIP();
  assert(ip);

  return cm->findAddress(community_id, ip->ipVersion,
                         ip->ipVersion == 4 ? (void *)&ip->ipType.ipv4 : (void *)&ip->ipType.ipv6);
}

/* *************************************** */

void Host::incHitter(Host *peer, u_int64_t sent_bytes, u_int64_t rcvd_bytes) {
#ifdef NTOPNG_PRO
  if(sent_bytes) sent_to_sketch->update(peer->key(), sent_bytes);
  if(rcvd_bytes) rcvd_from_sketch->update(peer->key(), rcvd_bytes);
#endif
}

/* *************************************** */

void Host::getPeerBytes(lua_State* vm, u_int32_t peer_key) {
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
}
