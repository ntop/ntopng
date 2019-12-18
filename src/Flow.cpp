/*
 *
 * (C) 2013-19 - ntop.org
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

/* static so default is zero-initialization, let's just define it */

const ndpi_protocol Flow::ndpiUnknownProtocol = { NDPI_PROTOCOL_UNKNOWN,
						  NDPI_PROTOCOL_UNKNOWN,
						  NDPI_PROTOCOL_CATEGORY_UNSPECIFIED };
//#define DEBUG_DISCOVERY
//#define DEBUG_UA

/* *************************************** */

Flow::Flow(NetworkInterface *_iface,
	   u_int16_t _vlanId, u_int8_t _protocol,
	   Mac *_cli_mac, IpAddress *_cli_ip, u_int16_t _cli_port,
	   Mac *_srv_mac, IpAddress *_srv_ip, u_int16_t _srv_port,
	   const ICMPinfo * const _icmp_info,
	   time_t _first_seen, time_t _last_seen) : GenericHashEntry(_iface) {
  last_partial = periodic_stats_update_partial = NULL;
  vlanId = _vlanId, protocol = _protocol, cli_port = _cli_port, srv_port = _srv_port;
  cli_host = srv_host = NULL;
  good_tls_hs = true, flow_dropped_counts_increased = false, vrfId = 0;
  alert_score = CONST_NO_SCORE_SET;
  alert_status_info = NULL;
  alert_type = alert_none;
  alert_level = alert_level_none;
  alerted_status = status_normal;
  predominant_status = status_normal;

  detection_completed = update_flow_port_stats = false;
  fully_processed = false;
  ndpiDetectedProtocol = ndpiUnknownProtocol;
  doNotExpireBefore = iface->getTimeLastPktRcvd() + DONT_NOT_EXPIRE_BEFORE_SEC;
  periodic_update_ctr = 0;

#ifdef HAVE_NEDGE
  last_conntrack_update = 0;
  marker = MARKER_NO_ACTION;
#endif

  icmp_info = _icmp_info ? new (std::nothrow) ICMPinfo(*_icmp_info) : NULL;

  ndpiFlow = NULL, cli_id = srv_id = NULL;
  cli_ebpf = srv_ebpf = NULL;
  json_info = NULL, tlv_info = NULL, cli2srv_direction = true, twh_over = twh_ok = false,
    dissect_next_http_packet = false,
    host_server_name = NULL;
    bt_hash = NULL;

  operating_system = os_unknown;
  src2dst_tcp_flags = 0, dst2src_tcp_flags = 0, last_update_time.tv_sec = 0, last_update_time.tv_usec = 0,
    bytes_thpt = 0, goodput_bytes_thpt = 0, top_bytes_thpt = 0, top_pkts_thpt = 0;
  bytes_thpt_cli2srv  = 0, goodput_bytes_thpt_cli2srv = 0;
  bytes_thpt_srv2cli  = 0, goodput_bytes_thpt_srv2cli = 0;
  pkts_thpt = 0, pkts_thpt_cli2srv = 0, pkts_thpt_srv2cli = 0;
  top_bytes_thpt = 0, top_goodput_bytes_thpt = 0, applLatencyMsec = 0;

  external_alert = NULL;
  trigger_immediate_periodic_update = false;
  pending_lua_call_protocol_detected = false;
  next_lua_call_periodic_update = 0;

  last_db_dump.partial = NULL;
  last_db_dump.first_seen = last_db_dump.last_seen = 0;
  memset(&protos, 0, sizeof(protos));
  memset(&flow_device, 0, sizeof(flow_device));

  PROFILING_SUB_SECTION_ENTER(iface, "Flow::Flow: iface->findFlowHosts", 7);
  iface->findFlowHosts(_vlanId, _cli_mac, _cli_ip, &cli_host, _srv_mac, _srv_ip, &srv_host);
  PROFILING_SUB_SECTION_EXIT(iface, 7);

  if(cli_host) {
    NetworkStats *network_stats = cli_host->getNetworkStats(cli_host->get_local_network_id());
    cli_host->incUses();
    cli_host->incNumFlows(last_seen, true, srv_host);
    if(network_stats) network_stats->incNumFlows(last_seen, true);
    cli_ip_addr = cli_host->get_ip();
  } else /* Client host has not been allocated, let's keep the info in an IpAddress */
    cli_ip_addr = new (std::nothrow) IpAddress(*_cli_ip);

  if(srv_host) {
    NetworkStats *network_stats = srv_host->getNetworkStats(srv_host->get_local_network_id());
    srv_host->incUses();
    srv_host->incNumFlows(last_seen, false, cli_host);
    if(network_stats) network_stats->incNumFlows(last_seen, false);
    srv_ip_addr = srv_host->get_ip();
  } else /* Server host has not been allocated, let's keep the info in an IpAddress */
    srv_ip_addr = new (std::nothrow) IpAddress(*_srv_ip);


  memset(&custom_app, 0, sizeof(custom_app));

#ifdef NTOPNG_PRO
  HostPools *hp = iface->getHostPools();

  routing_table_id = DEFAULT_ROUTING_TABLE_ID;

  if(hp) {
    if(cli_host) routing_table_id = hp->getRoutingPolicy(cli_host->get_host_pool());
    if(srv_host) routing_table_id = max_val(routing_table_id, hp->getRoutingPolicy(srv_host->get_host_pool()));
  }

  counted_in_aggregated_flow = status_counted_in_aggregated_flow = false;
#endif

  passVerdict = true, quota_exceeded = false;
  has_malicious_cli_signature = has_malicious_srv_signature = false;
  is_alerted = false;
#ifdef ALERTED_FLOWS_DEBUG
  iface_alert_inc = iface_alert_dec = false;
#endif
  if(_first_seen > _last_seen) _first_seen = _last_seen;
  first_seen = _first_seen, last_seen = _last_seen;
  bytes_thpt_trend = trend_unknown, pkts_thpt_trend = trend_unknown;
  //bytes_rate = new TimeSeries<float>(4096);
  protocol_processed = false;

  synTime.tv_sec = synTime.tv_usec = 0,
    ackTime.tv_sec = ackTime.tv_usec = 0,
    synAckTime.tv_sec = synAckTime.tv_usec = 0,
    rttSec = 0, cli2srv_window = srv2cli_window = 0,
    c2sFirstGoodputTime.tv_sec = c2sFirstGoodputTime.tv_usec = 0;
  memset(&ip_stats_s2d, 0, sizeof(ip_stats_s2d)), memset(&ip_stats_d2s, 0, sizeof(ip_stats_d2s));
  memset(&tcp_seq_s2d, 0, sizeof(tcp_seq_s2d)), memset(&tcp_seq_d2s, 0, sizeof(tcp_seq_d2s));
  memset(&clientNwLatency, 0, sizeof(clientNwLatency)), memset(&serverNwLatency, 0, sizeof(serverNwLatency));

  if(!iface->isPacketInterface())
    last_update_time.tv_sec = (long)first_seen;

  if(iface->isPacketInterface() && !iface->isSampledTraffic()) {
    cli2srvPktTime = new (std::nothrow) InterarrivalStats();
    srv2cliPktTime = new (std::nothrow) InterarrivalStats();
  } else {
    cli2srvPktTime = NULL;
    srv2cliPktTime = NULL;
  }    

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  trafficProfile = NULL;
#else
  cli2srv_in = cli2srv_out = srv2cli_in = srv2cli_out = DEFAULT_SHAPER_ID;
  memset(&flowShaperIds, 0, sizeof(flowShaperIds));
  cli_quota_source = srv_quota_source = policy_source_default;
#endif
#endif

  /* Reset the initial state */
  hash_entry_id = 0;
  set_hash_entry_state_allocated();

  switch(protocol) {
  case IPPROTO_TCP:
  case IPPROTO_UDP:
    if(iface->is_ndpi_enabled() && (!iface->isSampledTraffic()))
      allocDPIMemory();

    if(protocol == IPPROTO_UDP)
      set_hash_entry_state_flow_notyetdetected();
    break;

  case IPPROTO_ICMP:
    ndpiDetectedProtocol.app_protocol = NDPI_PROTOCOL_IP_ICMP,
      ndpiDetectedProtocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;
    setDetectedProtocol(ndpiDetectedProtocol, true);
    break;

  case IPPROTO_ICMPV6:
    ndpiDetectedProtocol.app_protocol = NDPI_PROTOCOL_IP_ICMPV6,
      ndpiDetectedProtocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;
    setDetectedProtocol(ndpiDetectedProtocol, true);
    break;

  default:
    ndpiDetectedProtocol = ndpi_guess_undetected_protocol(iface->get_ndpi_struct(),
							  NULL, protocol, 0, 0, 0, 0);
    setDetectedProtocol(ndpiDetectedProtocol, true);
    break;
  }

  protos.tls.dissect_certificate = true,
    protos.tls.subject_alt_name_match = false;
}

/* *************************************** */

void Flow::allocDPIMemory() {
  if((ndpiFlow = (ndpi_flow_struct*)calloc(1, iface->get_flow_size())) == NULL)
    throw "Not enough memory";

  if((cli_id = calloc(1, iface->get_size_id())) == NULL)
    throw "Not enough memory";

  if((srv_id = calloc(1, iface->get_size_id())) == NULL)
    throw "Not enough memory";
}

/* *************************************** */

void Flow::freeDPIMemory() {
  if(ndpiFlow)  { ndpi_free_flow(ndpiFlow); ndpiFlow = NULL;  }
  if(cli_id)    { free(cli_id);             cli_id = NULL;    }
  if(srv_id)    { free(srv_id);             srv_id = NULL;    }
}

/* *************************************** */

Flow::~Flow() {
#ifdef ALERTED_FLOWS_DEBUG
  if(iface_alert_inc && !iface_alert_dec) {
    char buf[256];
    ntop->getTrace()->traceEvent(TRACE_WARNING, "[MISMATCH][inc but not dec][alerted: %u] %s",
				 isFlowAlerted() ? 1 : 0, print(buf, sizeof(buf)));
  }
#endif
  if(cli_host)
    cli_host->decUses();
  else if(cli_ip_addr) /* Dynamically allocated only when cli_host was NULL */
    delete cli_ip_addr;

  if(srv_host)
    srv_host->decUses();
  else if(srv_ip_addr) /* Dynamically allocated only when srv_host was NULL */
    delete srv_ip_addr;

  if(last_partial)                  delete(last_partial);
  if(periodic_stats_update_partial) delete(periodic_stats_update_partial);
  if(last_db_dump.partial)          delete(last_db_dump.partial);

  if(json_info)            json_object_put(json_info);
  if(tlv_info) {
    ndpi_term_serializer(tlv_info);
    free(tlv_info);
  }
  if(host_server_name)     free(host_server_name);

  if(cli_ebpf) delete cli_ebpf;
  if(srv_ebpf) delete srv_ebpf;

  if(cli2srvPktTime) delete cli2srvPktTime;
  if(srv2cliPktTime) delete srv2cliPktTime;

  if(isHTTP()) {
    if(protos.http.last_method) free(protos.http.last_method);
    if(protos.http.last_url)    free(protos.http.last_url);
    if(protos.http.last_content_type) free(protos.http.last_content_type);
  } else if(isDNS()) {
    if(protos.dns.last_query)   free(protos.dns.last_query);
  } else if (isMDNS()) {
    if(protos.mdns.answer)           free(protos.mdns.answer);
    if(protos.mdns.name)             free(protos.mdns.name);
    if(protos.mdns.name_txt)         free(protos.mdns.name_txt);
    if(protos.mdns.ssid)             free(protos.mdns.ssid);
  } else if (isSSDP()) {
    if(protos.ssdp.location)         free(protos.ssdp.location);
  } else if (isNetBIOS()) {
    if(protos.netbios.name)          free(protos.netbios.name);
  } else if(isSSH()) {
    if(protos.ssh.client_signature)  free(protos.ssh.client_signature);
    if(protos.ssh.server_signature)  free(protos.ssh.server_signature);
    if(protos.ssh.hassh.client_hash) free(protos.ssh.hassh.client_hash);
    if(protos.ssh.hassh.server_hash) free(protos.ssh.hassh.server_hash);
  } else if(isTLS()) {
    if(protos.tls.certificate)         free(protos.tls.certificate);
    if(protos.tls.server_certificate)  free(protos.tls.server_certificate);
    if(protos.tls.ja3.client_hash)     free(protos.tls.ja3.client_hash);
    if(protos.tls.ja3.server_hash)     free(protos.tls.ja3.server_hash);
  }

  if(bt_hash)                free(bt_hash);

  freeDPIMemory();
  if(icmp_info) delete(icmp_info);
  if(external_alert) free(external_alert);
  if(alert_status_info) free(alert_status_info);
}

/* *************************************** */

u_int16_t Flow::getStatsProtocol() const {
  u_int16_t stats_protocol;

  if(ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN
      && !ndpi_is_subprotocol_informative(NULL, ndpiDetectedProtocol.master_protocol))
    stats_protocol = ndpiDetectedProtocol.app_protocol;
  else
    stats_protocol = ndpiDetectedProtocol.master_protocol;

  return(stats_protocol);
}

/* *************************************** */

/* This function is called as soon as the protocol detection is
 * completed. See processFullyDissectedProtocol for a later callback. */
void Flow::processDetectedProtocol() {
  u_int16_t l7proto;
  u_int16_t stats_protocol;

  if(protocol_processed || (ndpiFlow == NULL))
    return;

  stats_protocol = getStatsProtocol();

  /* Update the active flows stats */
  if(cli_host) cli_host->incnDPIFlows(stats_protocol);
  if(srv_host) srv_host->incnDPIFlows(stats_protocol);
  iface->incnDPIFlows(stats_protocol);

  l7proto = ndpi_get_lower_proto(ndpiDetectedProtocol);

  if((l7proto != NDPI_PROTOCOL_DNS)
     && (l7proto != NDPI_PROTOCOL_DHCP) /* host_server_name in DHCP is for the client name, not the server */
     && (ndpiFlow->host_server_name[0] != '\0')
     && (host_server_name == NULL)) {
    Utils::sanitizeHostName((char*)ndpiFlow->host_server_name);

    if(ndpi_is_proto(ndpiDetectedProtocol, NDPI_PROTOCOL_HTTP)) {
      char *double_column = strrchr((char*)ndpiFlow->host_server_name, ':');

      if(double_column) double_column[0] = '\0';
    }

    /*
      Host server name equals the Host: HTTP header field.
    */
    host_server_name = strdup((char*)ndpiFlow->host_server_name);
  }

  switch(l7proto) {
  case NDPI_PROTOCOL_BITTORRENT:
    if(bt_hash == NULL) {
      setBittorrentHash((char*)ndpiFlow->protos.bittorrent.hash);
      protocol_processed = true;
    }
    break;

  case NDPI_PROTOCOL_MDNS:
    /*
      The statement below can create issues sometimes as devices publish
      themselves with varisous names depending on the context (**)
    */
    if(ndpiFlow->protos.mdns.answer[0] != '\0' && !protos.mdns.answer)
      protos.mdns.answer = strdup(ndpiFlow->protos.mdns.answer);
    break;

  case NDPI_PROTOCOL_DNS:
    if(ndpiFlow->host_server_name[0] != '\0') {

      if(protos.dns.last_query) {
	free(protos.dns.last_query);
	protos.dns.invalid_chars_in_query = false;
      }
      protos.dns.last_query = strdup((const char*)ndpiFlow->host_server_name);
      protos.dns.last_query_type = ndpiFlow->protos.dns.query_type;

      for(int i = 0; protos.dns.last_query[i] != '\0'; i++) {
	if(!isprint(protos.dns.last_query[i])) {
	  protos.dns.last_query[i] = '?';
	  protos.dns.invalid_chars_in_query = true;
	}
      }
    }
    /* See Flow::processFullyDissectedProtocol for reply dissection */
    break;

  case NDPI_PROTOCOL_TOR:
  case NDPI_PROTOCOL_TLS:
#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "-> [client: %s][server: %s]",
				 ndpiFlow->protos.stun_ssl.ssl.client_certificate,
				 ndpiFlow->protos.stun_ssl.ssl.server_certificate);
#endif

    if(protos.tls.certificate
       && cli_host
       && cli_host->isLocalHost())
      cli_host->incrVisitedWebSite(protos.tls.certificate);

    protocol_processed = true;
    break;

    /* No break here !*/
  case NDPI_PROTOCOL_HTTP:
  case NDPI_PROTOCOL_HTTP_PROXY:
    if(ndpiFlow->host_server_name[0] != '\0') {
      char *doublecol, delimiter = ':';

      protocol_processed = true;

      /* If <host>:<port> we need to remove ':' */
      if((doublecol = (char*)strchr((const char*)ndpiFlow->host_server_name, delimiter)) != NULL)
	doublecol[0] = '\0';

      if(srv_host && (ndpiFlow->protos.http.detected_os[0] != '\0') && cli_host)
	cli_host->inlineSetOSDetail((char*)ndpiFlow->protos.http.detected_os);

      if(cli_host && cli_host->isLocalHost())
	cli_host->incrVisitedWebSite(host_server_name);
    }
    break;
  } /* switch */
}

/* *************************************** */

/* This is called only once per Flow, when all the protocol information,
 * including extra dissection information (e.g. the TLS certificate), is
 * available. */
void Flow::processFullyDissectedProtocol() {
  if(fully_processed)
    return;

  if(ndpiFlow) {
    u_int16_t l7proto;

    l7proto = ndpi_get_lower_proto(ndpiDetectedProtocol);

    switch(l7proto) {

    case NDPI_PROTOCOL_SSH:
      if(protos.ssh.client_signature == NULL)
	protos.ssh.client_signature = strdup(ndpiFlow->protos.ssh.client_signature);
      if(protos.ssh.server_signature == NULL)
	protos.ssh.server_signature = strdup(ndpiFlow->protos.ssh.server_signature);

      if(protos.ssh.hassh.client_hash == NULL
	 && ndpiFlow->protos.ssh.hassh_client[0] != '\0') {
	protos.ssh.hassh.client_hash = strdup(ndpiFlow->protos.ssh.hassh_client);
	updateHASSH(true /* As client */);
      }

      if(protos.ssh.hassh.server_hash == NULL
	 && ndpiFlow->protos.ssh.hassh_server[0] != '\0') {
	protos.ssh.hassh.server_hash = strdup(ndpiFlow->protos.ssh.hassh_server);
	updateHASSH(false /* As server */);
      }
      break;

    case NDPI_PROTOCOL_TLS:
      protos.tls.tls_version = ndpiFlow->protos.stun_ssl.ssl.ssl_version;

      if((protos.tls.server_certificate == NULL)
	 && (ndpiFlow->protos.stun_ssl.ssl.server_certificate[0] != '\0')) {
	protos.tls.server_certificate = strdup(ndpiFlow->protos.stun_ssl.ssl.server_certificate);
      }

      if((protos.tls.certificate == NULL)
	 && (ndpiFlow->protos.stun_ssl.ssl.client_certificate[0] != '\0')) {
	protos.tls.certificate = strdup(ndpiFlow->protos.stun_ssl.ssl.client_certificate);
      }

      if((protos.tls.ja3.client_hash == NULL) && (ndpiFlow->protos.stun_ssl.ssl.ja3_client[0] != '\0')) {
	protos.tls.ja3.client_hash = strdup(ndpiFlow->protos.stun_ssl.ssl.ja3_client);
	updateCliJA3();
      }

      if((protos.tls.ja3.server_hash == NULL) && (ndpiFlow->protos.stun_ssl.ssl.ja3_server[0] != '\0')) {
	protos.tls.ja3.server_hash = strdup(ndpiFlow->protos.stun_ssl.ssl.ja3_server);
	protos.tls.ja3.server_unsafe_cipher = ndpiFlow->protos.stun_ssl.ssl.server_unsafe_cipher;
	protos.tls.ja3.server_cipher = ndpiFlow->protos.stun_ssl.ssl.server_cipher;
	updateSrvJA3();
      }
      break;

    case NDPI_PROTOCOL_DNS:
      if(ntop->getPrefs()->decode_dns_responses()) {

	if(ndpiFlow->host_server_name[0] != '\0') {
	  char delimiter = '@', *name = NULL;
	  char *at = (char*)strchr((const char*)ndpiFlow->host_server_name, delimiter);

	  /* Consider only positive DNS replies */
	  if(at != NULL)
	    name = &at[1], at[0] = '\0';
	  else if((!strstr((const char*)ndpiFlow->host_server_name, ".in-addr.arpa"))
		  && (!strstr((const char*)ndpiFlow->host_server_name, ".ip6.arpa")))
	    name = (char*)ndpiFlow->host_server_name;

	  if(name) {
	    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[DNS] %s", (char*)ndpiFlow->host_server_name);
	    protos.dns.last_return_code = ndpiFlow->protos.dns.reply_code;

	    if(ndpiFlow->protos.dns.reply_code == 0) {
	      if(ndpiFlow->protos.dns.num_answers > 0) {
		protocol_processed = true;

		if(at != NULL) {
		  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[DNS] %s <-> %s", name, (char*)ndpiFlow->host_server_name);
		  ntop->getRedis()->setResolvedAddress(name, (char*)ndpiFlow->host_server_name);
		}
	      }
	    }
	  }
	}
      }
      break;
    }
  }

  /* Free the nDPI memory */
  freeDPIMemory();

  fully_processed = true;

  /*
    We need to change state here as in Lua scripts we need to know
    all metadata available
  */
  set_hash_entry_state_flow_protocoldetected();
}

/* *************************************** */

bool Flow::needsExtraDissection() {
  ndpi_flow_struct* ndpif;

  /* NOTE: do not check hasDissectedTooManyPackets() here, otherwise
   * ndpi_detection_giveup won't be called. */
  return((ndpif = get_ndpi_flow())
     && (!fully_processed)
     && (ndpi_extra_dissection_possible(iface->get_ndpi_struct(), ndpif))
  );
}

/* *************************************** */

/* NOTE: this function can be called multiple times, even after the detection
 * has compleated. This usually happens if needsExtraDissection() returns true.
 * See doc/README.developers.flow_state.md for more details. */
void Flow::setDetectedProtocol(ndpi_protocol proto_id, bool forceDetection) {
  if((proto_id.app_protocol != NDPI_PROTOCOL_UNKNOWN)
     || forceDetection
     || hasDissectedTooManyPackets()
     || (!iface->is_ndpi_enabled())
     || iface->isSampledTraffic()) {
    /* Only execute this if the detection is was not already completed. */
    if(!detection_completed) {
        u_int8_t is_proto_user_defined;

      if(forceDetection && (proto_id.app_protocol == NDPI_PROTOCOL_UNKNOWN))
        proto_id.app_protocol = (int16_t)ndpi_guess_protocol_id(iface->get_ndpi_struct(),
							      NULL, protocol, get_cli_port(),
							      get_srv_port(), &is_proto_user_defined);

      ndpiDetectedProtocol.master_protocol = proto_id.master_protocol;
      ndpiDetectedProtocol.app_protocol = proto_id.app_protocol;

      /* NOTE: only overwrite the category if it was not set.
      * This prevents overwriting already determined category (e.g. by IP or Host)
      */
      if(ndpiDetectedProtocol.category == NDPI_PROTOCOL_CATEGORY_UNSPECIFIED)
        ndpiDetectedProtocol.category = proto_id.category;

      stats.setDetectedProtocol(&ndpiDetectedProtocol);
      processDetectedProtocol();
      detection_completed = true;      

#ifdef HAVE_NEDGE
      updateFlowShapers(true);
#endif
      update_flow_port_stats = true;
    }

    if(detection_completed && (forceDetection || !needsExtraDissection())) {
      switch(protocol) {
      case IPPROTO_TCP:
      case IPPROTO_UDP:
	break;

      default:
	/* nDPI is not allocated for non-TCP non-UDP flows so, in order to
	   make sure custom cateories are properly populated, function ndpi_fill_ip_protocol_category
	   must be called explicitly. */
	if(ndpiDetectedProtocol.category == NDPI_PROTOCOL_CATEGORY_UNSPECIFIED /* Override only if unspecified */
	   && get_cli_ip_addr()->get_ipv4() && get_srv_ip_addr()->get_ipv4() /* Only IPv4 is supported */) {
	  ndpi_fill_ip_protocol_category(iface->get_ndpi_struct(),
					 get_cli_ip_addr()->get_ipv4(), get_srv_ip_addr()->get_ipv4(),
					 &ndpiDetectedProtocol);
	  stats.setDetectedProtocol(&ndpiDetectedProtocol);
	} 

	break;
      }

      /* Always called, not just for TCP or UDP */
      processFullyDissectedProtocol();
    }

#ifdef BLACKLISTED_FLOWS_DEBUG
    if(ndpiDetectedProtocol.category == CUSTOM_CATEGORY_MALWARE) {
      char buf[512];
      print(buf, sizeof(buf));
      snprintf(&buf[strlen(buf)], sizeof(buf) - strlen(buf),
	       "Malware category detected. [cli_blacklisted: %u][srv_blacklisted: %u][category: %s]",
	       cli_host->isBlacklisted(), srv_host->isBlacklisted(), get_protocol_category_name());
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", buf);
    }
#endif
  }

#ifdef NTOPNG_PRO
  // Update the profile even if the detection is not yet completed.
  // Indeed, even if the L7 detection is not yet completed
  // the flow already carries information on all the other fields,
  // e.g., IP src and DST, vlan, L4 proto, etc
#ifndef HAVE_NEDGE
  updateProfile();
#endif
#endif
}

/* *************************************** */

void Flow::setJSONInfo(json_object *json) {
  if(json == NULL) return;

  if(json_info != NULL) 
    json_object_put(json_info);

  json_info = json_object_get(json);
}

/* *************************************** */

void Flow::setTLVInfo(ndpi_serializer *tlv) {
  if(tlv == NULL) return;

  if(tlv_info != NULL) { 
    ndpi_term_serializer(tlv_info);
    free(tlv_info);
  }

  tlv_info = tlv;
}

/* *************************************** */

/*
 * A faster replacement for inet_ntoa().
 */
char* Flow::intoaV4(unsigned int addr, char* buf, u_short bufLen) {
  char *cp, *retStr;
  int n;

  cp = &buf[bufLen];
  *--cp = '\0';

  n = 4;
  do {
    u_int byte = addr & 0xff;

    *--cp = byte % 10 + '0';
    byte /= 10;
    if(byte > 0) {
      *--cp = byte % 10 + '0';
      byte /= 10;
      if(byte > 0)
	*--cp = byte + '0';
    }
    *--cp = '.';
    addr >>= 8;
  } while (--n > 0);

  /* Convert the string to srccase */
  retStr = (char*)(cp+1);

  return(retStr);
}

/* *************************************** */

u_int64_t Flow::get_current_bytes_cli2srv() const {
  int64_t diff = get_bytes_cli2srv() - (periodic_stats_update_partial ? periodic_stats_update_partial->get_cli2srv_bytes() : 0);

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_bytes_srv2cli() const {
  int64_t diff = get_bytes_srv2cli() - (periodic_stats_update_partial ? periodic_stats_update_partial->get_srv2cli_bytes() : 0);

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_goodput_bytes_cli2srv() const {
  int64_t diff = get_goodput_bytes_cli2srv() - (periodic_stats_update_partial ? periodic_stats_update_partial->get_cli2srv_goodput_bytes() : 0);

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_goodput_bytes_srv2cli() const {
  int64_t diff = get_goodput_bytes_srv2cli() - (periodic_stats_update_partial ? periodic_stats_update_partial->get_srv2cli_goodput_bytes() : 0);

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_packets_cli2srv() const {
  int64_t diff = get_packets_cli2srv() - (periodic_stats_update_partial ? periodic_stats_update_partial->get_cli2srv_packets() : 0);

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_packets_srv2cli() const {
  int64_t diff = get_packets_srv2cli() - (periodic_stats_update_partial ? periodic_stats_update_partial->get_srv2cli_packets() : 0);

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* ****************************************************** */

char* Flow::printTCPflags(u_int8_t flags, char * const buf, u_int buf_len) const {
  snprintf(buf, buf_len, "%s%s%s%s%s%s%s%s%s",
	   (flags & TH_SYN) ? " SYN" : "",
	   (flags & TH_ACK) ? " ACK" : "",
	   (flags & TH_FIN) ? " FIN" : "",
	   (flags & TH_RST) ? " RST" : "",
	   (flags & TH_PUSH) ? " PUSH" : "",
	   isTCPEstablished() ? " est" : "",
	   isTCPConnecting() ? " conn" : "",
	   isTCPClosed() ? " closed" : "",
	   isTCPReset() ? " reset" : "");
  if(buf[0] == ' ')
    return(&buf[1]);
  else
    return(buf);
}
/* *************************************** */

char* Flow::print(char *buf, u_int buf_len) const {
  char buf1[32], buf2[32], buf3[32], buf4[32], pbuf[32], tcp_buf[64];
  buf[0] = '\0';

#if defined(NTOPNG_PRO) && defined(SHAPER_DEBUG)
  char shapers[64];

  TrafficShaper *cli2srv_in  = flowShaperIds.cli2srv.ingress;
  TrafficShaper *cli2srv_out = flowShaperIds.cli2srv.egress;
  TrafficShaper *srv2cli_in  = flowShaperIds.srv2cli.ingress;
  TrafficShaper *srv2cli_out = flowShaperIds.srv2cli.egress;

  if(iface->is_bridge_interface()) {
    snprintf(shapers, sizeof(shapers),
	     "[pass_verdict: %s] "
	     "[shapers: cli2srv=%u/%u, srv2cli=%u/%u] "
	     "[cli2srv_ingress shaping_enabled: %i max_rate: %lu] "
	     "[cli2srv_egress shaping_enabled: %i max_rate: %lu] "
	     "[srv2cli_ingress shaping_enabled: %i max_rate: %lu] "
	     "[srv2cli_egress shaping_enabled: %i max_rate: %lu] ",
	     passVerdict ? "PASS" : "DROP",
	     flowShaperIds.cli2srv.ingress ? flowShaperIds.cli2srv.ingress->get_shaper_id() : DEFAULT_SHAPER_ID,
	     flowShaperIds.cli2srv.egress  ? flowShaperIds.cli2srv.egress->get_shaper_id()  : DEFAULT_SHAPER_ID,
	     flowShaperIds.srv2cli.ingress ? flowShaperIds.srv2cli.ingress->get_shaper_id() : DEFAULT_SHAPER_ID,
	     flowShaperIds.srv2cli.egress  ? flowShaperIds.srv2cli.egress->get_shaper_id()  : DEFAULT_SHAPER_ID,
	     cli2srv_in->shaping_enabled(), cli2srv_in->get_max_rate_kbit_sec(),
	     cli2srv_out->shaping_enabled(), cli2srv_out->get_max_rate_kbit_sec(),
	     srv2cli_in->shaping_enabled(), srv2cli_in->get_max_rate_kbit_sec(),
	     srv2cli_out->shaping_enabled(), srv2cli_out->get_max_rate_kbit_sec()
	     );
  } else
    shapers[0] = '\0';

#endif

  tcp_buf[0] = '\0';
  if(protocol == IPPROTO_TCP) {
    int len = 0;

    if((stats.get_cli2srv_tcp_ooo() + stats.get_srv2cli_tcp_ooo()) > 0)
      len += snprintf(&tcp_buf[len], sizeof(tcp_buf)-len, "[OOO=%u/%u]",
		      stats.get_cli2srv_tcp_ooo(), stats.get_srv2cli_tcp_ooo());

    if((stats.get_cli2srv_tcp_lost() + stats.get_srv2cli_tcp_lost()) > 0)
      len += snprintf(&tcp_buf[len], sizeof(tcp_buf)-len, "[Lost=%u/%u]",
		      stats.get_cli2srv_tcp_lost(), stats.get_srv2cli_tcp_lost());

    if((stats.get_cli2srv_tcp_retr() + stats.get_srv2cli_tcp_retr()) > 0)
      len += snprintf(&tcp_buf[len], sizeof(tcp_buf)-len, "[Retr=%u/%u]",
		      stats.get_cli2srv_tcp_retr(), stats.get_srv2cli_tcp_retr());

    if((stats.get_cli2srv_tcp_keepalive() + stats.get_srv2cli_tcp_keepalive()) > 0)
      len += snprintf(&tcp_buf[len], sizeof(tcp_buf)-len, "[KeepAlive=%u/%u]",
		      stats.get_cli2srv_tcp_keepalive(), stats.get_srv2cli_tcp_keepalive());
  }

  snprintf(buf, buf_len,
	   "%s %s:%u &gt; %s:%u [first: %u][last: %u][proto: %u.%u/%s][cat: %u/%s][device: %u in: %u out:%u][%u/%u pkts][%llu/%llu bytes][src2dst: %s][dst2stc: %s]"
	   "%s%s%s"
#if defined(NTOPNG_PRO) && defined(SHAPER_DEBUG)
	   "%s"
#endif
	   ,
	   get_protocol_name(),
	   get_cli_ip_addr() ? get_cli_ip_addr()->print(buf1, sizeof(buf1)) : "", ntohs(cli_port),
	   get_srv_ip_addr() ? get_srv_ip_addr()->print(buf2, sizeof(buf2)) : "", ntohs(srv_port),
	   (u_int32_t)first_seen, (u_int32_t)last_seen,
	   ndpiDetectedProtocol.master_protocol, ndpiDetectedProtocol.app_protocol,
	   get_detected_protocol_name(pbuf, sizeof(pbuf)),
	   get_protocol_category(),
	   get_protocol_category_name(),
	   flow_device.device_ip, flow_device.in_index, flow_device.out_index,
	   get_packets_cli2srv(), get_packets_srv2cli(),
	   (long long unsigned) get_bytes_cli2srv(), (long long unsigned) get_bytes_srv2cli(),
	   printTCPflags(src2dst_tcp_flags, buf3, sizeof(buf3)),
	   printTCPflags(dst2src_tcp_flags, buf4, sizeof(buf4)),
	   (isTLS() && protos.tls.certificate) ? "[" : "",
	   (isTLS() && protos.tls.certificate) ? protos.tls.certificate : "",
	   (isTLS() && protos.tls.certificate) ? "]" : ""
#if defined(NTOPNG_PRO) && defined(SHAPER_DEBUG)
	   , shapers
#endif
	   );

return(buf);
}

/* *************************************** */

bool Flow::dumpFlow(const struct timeval *tv, NetworkInterface *dumper) {
  bool rc = false;

  if(ntop->getPrefs()->do_dump_flows()
#ifndef HAVE_NEDGE
     || ntop->get_export_interface()
#endif
     ) {
    if(!ntop->getPrefs()->is_tiny_flows_export_enabled() && isTiny()) {
#ifdef TINY_FLOWS_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Skipping tiny flow dump "
				   "[flow key: %u]"
				   "[packets current/max: %i/%i] "
				   "[bytes current/max: %i/%i].",
				   key(),
				   get_packets(),
				   ntop->getPrefs()->get_max_num_packets_per_tiny_flow(),
				   get_bytes(),
				   ntop->getPrefs()->get_max_num_bytes_per_tiny_flow());

#endif
      return(rc);
    }

    if(!idle()) {
      if(dumper->getIfType() == interface_type_PCAP_DUMP
         || tv->tv_sec - get_first_seen() < CONST_DB_DUMP_FREQUENCY
	 || tv->tv_sec - get_partial_last_seen() < CONST_DB_DUMP_FREQUENCY) {
	return(rc);
      }
    } else {
      /* Flow idle, i.e., ready to be purged, are always dumped */
    }

    if(!update_partial_traffic_stats_db_dump())
      return rc; /* Partial stats update has failed */

    /* Check for bytes, and not for packets, as with nprobeagent
       there are not packet counters, just bytes. */
    if(!get_partial_bytes())
      return rc; /* Nothing to dump */

#ifdef NTOPNG_PRO
    if(ntop->getPro()->has_valid_license() && ntop->getPrefs()->is_enterprise_edition())
      dumper->aggregatePartialFlow(tv, this);
#endif

    dumper->dumpFlow(last_seen, this);

#ifndef HAVE_NEDGE
    if(ntop->get_export_interface()) {
      char *json = serialize(false);

      if(json) {
	ntop->get_export_interface()->export_data(json);
	free(json);
      }
    }
#endif

    rc = true;
  }

  return(rc);
}

/* *************************************** */

void Flow::setDropVerdict() {
#if defined(HAVE_NEDGE)
  if((iface->getIfType() == interface_type_NETFILTER) && (passVerdict == true))
   ((NetfilterInterface *) iface)->setPolicyChanged();
#endif

  passVerdict = false;
}

/* *************************************** */

void Flow::incFlowDroppedCounters() {
  if(!flow_dropped_counts_increased) {
    if(cli_host) {
      cli_host->incNumDroppedFlows();
      if(cli_host->getMac()) cli_host->getMac()->incNumDroppedFlows();
    }

#ifdef NTOPNG_PRO
    HostPools *h = iface ? iface->getHostPools() : NULL;
    u_int16_t cli_pool = NO_HOST_POOL_ID;

    if(h) {
      cli_pool = cli_host ? cli_host->get_host_pool() : NO_HOST_POOL_ID;

      if(cli_pool != NO_HOST_POOL_ID)
	h->incPoolNumDroppedFlows(cli_pool);
    }
#endif

    /* Increasing stats on the server is pointless.
     If a flow is dropped, the server doesn't even see it,
     it is just the client that gets a drop. */
    flow_dropped_counts_increased = true;
  }
}

/* *************************************** */

void Flow::hosts_periodic_stats_update(NetworkInterface *iface, Host *cli_host, Host *srv_host, PartializableFlowTrafficStats *partial, bool first_partial, const struct timeval *tv) const {
  update_pools_stats(iface, cli_host, srv_host, tv, partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
		     partial->get_srv2cli_packets(), partial->get_srv2cli_bytes());
 
if(cli_host && srv_host) {
    bool cli_and_srv_in_same_subnet = false;
    bool cli_and_srv_in_same_country = false;
    Vlan *vl;
    int16_t cli_network_id = cli_host->get_local_network_id();
    int16_t srv_network_id = srv_host->get_local_network_id();
    int16_t stats_protocol = getStatsProtocol(); /* The protocol (among ndpi master_ and app_) that is chosen to increase stats */
    NetworkStats *cli_network_stats = NULL, *srv_network_stats = NULL;

    if(cli_network_id >= 0 && (cli_network_id == srv_network_id))
      cli_and_srv_in_same_subnet = true;

    if(iface && (vl = iface->getVlan(vlanId, false, false /* NOT an inline call */))) {
      /* Note: source and destination hosts have, by definition, the same VLAN so the increase is done only one time. */
      /* Note: vl will never be null as we're in a flow with that vlan. Hence, it is guaranteed that at least
	 two hosts exists for that vlan and that any purge attempt will be prevented. */
#ifdef VLAN_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Increasing Vlan %u stats", vlanId);
#endif
      vl->incStats(tv->tv_sec, stats_protocol,
		   partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
		   partial->get_srv2cli_packets(), partial->get_srv2cli_bytes());
    }

    // Update network stats
    cli_network_stats = cli_host->getNetworkStats(cli_network_id);
    cli_host->incStats(tv->tv_sec, get_protocol(),
		       stats_protocol, get_protocol_category(), custom_app,
		       partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(), partial->get_cli2srv_goodput_bytes(),
		       partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(), partial->get_srv2cli_goodput_bytes(),
		       srv_host->get_ip()->isNonEmptyUnicastAddress());

    // update per-subnet byte counters
    if(cli_network_stats) { // only if the network is known and local
      if(!cli_and_srv_in_same_subnet) {
	cli_network_stats->incEgress(tv->tv_sec, partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
				     srv_host->get_ip()->isBroadcastAddress());
	cli_network_stats->incIngress(tv->tv_sec, partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(),
				      cli_host->get_ip()->isBroadcastAddress());
      } else // client and server ARE in the same subnet
	// need to update the inner counter (just one time, will intentionally skip this for srv_host)
	cli_network_stats->incInner(tv->tv_sec, partial->get_cli2srv_packets() + partial->get_srv2cli_packets(),
				    partial->get_cli2srv_bytes() + partial->get_srv2cli_bytes(),
				    srv_host->get_ip()->isBroadcastAddress()
				    || cli_host->get_ip()->isBroadcastAddress());
    }

    srv_network_stats = srv_host->getNetworkStats(srv_network_id);
    srv_host->incStats(tv->tv_sec, get_protocol(),
		       stats_protocol, get_protocol_category(), custom_app,
		       partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(), partial->get_srv2cli_goodput_bytes(),
		       partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(), partial->get_cli2srv_goodput_bytes(),
		       cli_host->get_ip()->isNonEmptyUnicastAddress());

    if(srv_network_stats) {
      // local and known server network
      if(!cli_and_srv_in_same_subnet) {
	srv_network_stats->incIngress(tv->tv_sec, partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
				      srv_host->get_ip()->isBroadcastAddress());
	srv_network_stats->incEgress(tv->tv_sec, partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(),
				     cli_host->get_ip()->isBroadcastAddress());
      }
    }

    if(cli_host->get_asn() != srv_host->get_asn()) {
      AutonomousSystem *cli_as = cli_host ? cli_host->get_as() : NULL,
	*srv_as = srv_host ? srv_host->get_as() : NULL;

      if(cli_as)
	cli_as->incStats(tv->tv_sec, stats_protocol, partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(), partial->get_srv2cli_packets(), partial->get_srv2cli_bytes());
      if(srv_as)
	srv_as->incStats(tv->tv_sec, stats_protocol, partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(), partial->get_cli2srv_packets(), partial->get_cli2srv_bytes());
    }

    // Update Country stats
    Country *cli_country_stats = cli_host->getCountryStats();
    Country *srv_country_stats = srv_host->getCountryStats();

    if(cli_country_stats && srv_country_stats && cli_country_stats->equal(srv_country_stats))
      cli_and_srv_in_same_country = true;

    if(cli_country_stats) {
      if(!cli_and_srv_in_same_country) {
	cli_country_stats->incEgress(tv->tv_sec, partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
				     srv_host->get_ip()->isBroadcastAddress());
	cli_country_stats->incIngress(tv->tv_sec, partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(),
				      cli_host->get_ip()->isBroadcastAddress());
      } else // client and server ARE in the same country
	// need to update the inner counter (just one time, will intentionally skip this for srv_host)
	cli_country_stats->incInner(tv->tv_sec, partial->get_cli2srv_packets() + partial->get_srv2cli_packets(),
				    partial->get_cli2srv_bytes() + partial->get_srv2cli_bytes(),
				    srv_host->get_ip()->isBroadcastAddress()
				    || cli_host->get_ip()->isBroadcastAddress());
    }

    if(srv_country_stats) {
      if(!cli_and_srv_in_same_country) {
	srv_country_stats->incIngress(tv->tv_sec, partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
				      srv_host->get_ip()->isBroadcastAddress());
	srv_country_stats->incEgress(tv->tv_sec, partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(),
				     cli_host->get_ip()->isBroadcastAddress());
      }
    }
  }

  switch(get_protocol()) {
  case IPPROTO_TCP:
    Flow::incTcpBadStats(true, cli_host, srv_host, iface,
			 partial->get_cli2srv_tcp_ooo(), partial->get_cli2srv_tcp_retr(),
			 partial->get_cli2srv_tcp_lost(), partial->get_cli2srv_tcp_keepalive());
    Flow::incTcpBadStats(false, cli_host, srv_host, iface,
			 partial->get_srv2cli_tcp_ooo(), partial->get_srv2cli_tcp_retr(),
			 partial->get_srv2cli_tcp_lost(), partial->get_srv2cli_tcp_keepalive());
    break;

  case IPPROTO_ICMP:
    if(iface) {
      if(partial->get_cli2srv_packets())
	iface->incICMPStats(false /* icmp v4 */ , partial->get_cli2srv_packets(), protos.icmp.cli2srv.icmp_type, protos.icmp.cli2srv.icmp_code, true);
      if(partial->get_srv2cli_packets())
	iface->incICMPStats(false /* icmp v4 */ , partial->get_srv2cli_packets(), protos.icmp.srv2cli.icmp_type, protos.icmp.srv2cli.icmp_code, true);
    }
    break;

  case IPPROTO_ICMPV6:
    if(iface) {
      if(partial->get_cli2srv_packets())
	iface->incICMPStats(true /* icmp v6 */ , partial->get_cli2srv_packets(), protos.icmp.cli2srv.icmp_type, protos.icmp.cli2srv.icmp_code, true);
      if(partial->get_srv2cli_packets())
	iface->incICMPStats(true /* icmp v6 */ , partial->get_srv2cli_packets(), protos.icmp.srv2cli.icmp_type, protos.icmp.srv2cli.icmp_code, true);
    }

    break;
  default:
    break;
  }

  switch(ndpi_get_lower_proto(ndpiDetectedProtocol)) {
  case NDPI_PROTOCOL_HTTP:
    if(cli_host && cli_host->getHTTPstats()) cli_host->getHTTPstats()->incStats(true  /* Client */, partial->get_flow_http_stats());
    if(srv_host && srv_host->getHTTPstats()) srv_host->getHTTPstats()->incStats(false /* Server */, partial->get_flow_http_stats());

    if(operating_system != os_unknown) {
      if(cli_host
	 && !(get_cli_ip_addr()->isBroadcastAddress()
	      || get_cli_ip_addr()->isMulticastAddress()))
	cli_host->setOS(operating_system);
    }
    /* Don't break, let's process also HTTP_PROXY */
  case NDPI_PROTOCOL_HTTP_PROXY:
    if(srv_host
       && srv_host->getHTTPstats()
       && host_server_name
       && isThreeWayHandshakeOK()) {
      srv_host->getHTTPstats()->updateHTTPHostRequest(tv->tv_sec, host_server_name,
						      partial->get_num_http_requests(),
						      partial->get_cli2srv_bytes(),
						      partial->get_srv2cli_bytes());
    }
    break;
  case NDPI_PROTOCOL_DNS:
    if(cli_host && cli_host->getDNSstats())
      cli_host->getDNSstats()->incStats(true  /* Client */, partial->get_flow_dns_stats());
    if(srv_host && srv_host->getDNSstats())
      srv_host->getDNSstats()->incStats(false /* Server */, partial->get_flow_dns_stats());
    break;
  case NDPI_PROTOCOL_MDNS:
    if(cli_host) {
      if(protos.mdns.answer)   cli_host->offlineSetMDNSInfo(protos.mdns.answer);
      if(protos.mdns.name)     cli_host->offlineSetMDNSName(protos.mdns.name);
      if(protos.mdns.name_txt) cli_host->offlineSetMDNSTXTName(protos.mdns.name_txt);
    }
    break;
  case NDPI_PROTOCOL_SSDP:
    if(cli_host) {
      if(protos.ssdp.location) cli_host->offlineSetSSDPLocation(protos.ssdp.location);
    }
    break;
  case NDPI_PROTOCOL_NETBIOS:
    if(cli_host) {
      if(protos.netbios.name) cli_host->set_host_label(protos.netbios.name, true);
    }
    break;
  case NDPI_PROTOCOL_IP_ICMP:
  case NDPI_PROTOCOL_IP_ICMPV6:
    if(cli_host && cli_host->getICMPstats()) {
      if(partial->get_cli2srv_packets())
	cli_host->getICMPstats()->incStats(partial->get_cli2srv_packets(), protos.icmp.cli2srv.icmp_type, protos.icmp.cli2srv.icmp_code, true  /* Sent */, srv_host);
      if(partial->get_srv2cli_packets())
	cli_host->getICMPstats()->incStats(partial->get_srv2cli_packets(), protos.icmp.srv2cli.icmp_type, protos.icmp.srv2cli.icmp_code, false /* Rcvd */, srv_host);
    }
    if(srv_host && srv_host->getICMPstats()) {
      if(partial->get_cli2srv_packets())
	srv_host->getICMPstats()->incStats(partial->get_cli2srv_packets(), protos.icmp.cli2srv.icmp_type, protos.icmp.cli2srv.icmp_code, false /* Rcvd */, cli_host);
      if(partial->get_srv2cli_packets())
	srv_host->getICMPstats()->incStats(partial->get_srv2cli_packets(), protos.icmp.srv2cli.icmp_type, protos.icmp.srv2cli.icmp_code, true  /* Sent */, cli_host);
    }

    if(first_partial && icmp_info) {
      if(icmp_info->isPortUnreachable()) { // Port unreachable icmpv6/icmpv4

	if(srv_host) srv_host->incNumUnreachableFlows(true  /* as server */);
	if(cli_host) cli_host->incNumUnreachableFlows(false /* as client */);
      } else if(icmp_info->isHostUnreachable(protocol)) {
	if(srv_host) srv_host->incNumHostUnreachableFlows(true  /* as server */);
	if(cli_host) cli_host->incNumHostUnreachableFlows(false /* as client */);
      }
    }

    break;
  default:
    break;
  }
}

/* *************************************** */

void Flow::periodic_stats_update(void *user_data, bool quick) {
  periodic_stats_update_user_data_t *periodic_stats_update_user_data = (periodic_stats_update_user_data_t*) user_data;
  struct timeval *tv = periodic_stats_update_user_data->tv;
  bool first_partial;
  PartializableFlowTrafficStats partial;
  get_partial_traffic_stats(&periodic_stats_update_partial, &partial, &first_partial);

  u_int32_t diff_sent_packets = partial.get_cli2srv_packets();
  u_int64_t diff_sent_bytes = partial.get_cli2srv_bytes();
  u_int64_t diff_sent_goodput_bytes = partial.get_cli2srv_goodput_bytes();

  u_int32_t diff_rcvd_packets = partial.get_srv2cli_packets();
  u_int64_t diff_rcvd_bytes = partial.get_srv2cli_bytes();
  u_int64_t diff_rcvd_goodput_bytes = partial.get_srv2cli_goodput_bytes();

  u_int64_t diff_bytes = diff_sent_bytes + diff_rcvd_bytes;
  u_int64_t diff_pkts  = diff_sent_packets + diff_rcvd_packets;
  
  int16_t stats_protocol; /* The protocol (among ndpi master_ and app_) that is chosen to increase stats */
  Mac *cli_mac = get_cli_host() ? get_cli_host()->getMac() : NULL;
  Mac *srv_mac = get_srv_host() ? get_srv_host()->getMac() : NULL;

  if(update_flow_port_stats) {
    bool dump_flow = false;

    if(protocol == IPPROTO_TCP) {
      /*
	 update the ports only if the flow has been observed from the beginning
	 and it has been established
      */
      dump_flow = ((src2dst_tcp_flags|dst2src_tcp_flags) & (TH_SYN|TH_PUSH)) == (TH_SYN|TH_PUSH);
    } else if(protocol == IPPROTO_UDP) {
      if(
	 (srv_host && srv_host->get_ip()->isBroadMulticastAddress())
	 || (get_packets_srv2cli() > 0 /* We see a response, hence we assume this is not a probing attempt */)
	 )
	dump_flow = true;
    }

#if 0
    char buf[128];
    
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][%u/%u] %s",
				 dump_flow ? "DUMP" : "",
				 get_packets_cli2srv(), get_packets_srv2cli(),
				 print(buf, sizeof(buf)));
#endif

      if(dump_flow && (srv_port != 0)) {
      u_int16_t p = ndpiDetectedProtocol.master_protocol;
      u_int16_t port = ntohs(srv_port);

      if(p == NDPI_PROTOCOL_UNKNOWN)
	p = ndpiDetectedProtocol.app_protocol;

      if(cli_host && cli_host->isLocalHost())
	cli_host->setFlowPort(false /* client */, srv_host, protocol, port, p,
			      getFlowInfo() ? getFlowInfo() : "",
			      iface->getTimeLastPktRcvd());

      if(srv_host && srv_host->isLocalHost())
	srv_host->setFlowPort(true /* server */, cli_host, protocol, port, p,
			      getFlowInfo() ? getFlowInfo() : "",
			      iface->getTimeLastPktRcvd());

#if 0
      char buf[128];

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", print(buf, sizeof(buf)));
#endif
    }

    update_flow_port_stats = false;
  }

  stats_protocol = getStatsProtocol();

  if(diff_sent_bytes || diff_rcvd_bytes)
    hosts_periodic_stats_update(getInterface(), cli_host, srv_host, &partial, first_partial, tv);

  if(cli_host && srv_host) {
    if(diff_sent_bytes || diff_rcvd_bytes) {
      /* Update L2 Device stats */
      if(srv_mac) {
#ifdef HAVE_NEDGE
        srv_mac->incSentStats(tv->tv_sec, diff_rcvd_packets, diff_rcvd_bytes);
        srv_mac->incRcvdStats(tv->tv_sec, diff_sent_packets, diff_sent_bytes);
#endif

        if(ntop->getPrefs()->areMacNdpiStatsEnabled()) {
	  srv_mac->incnDPIStats(tv->tv_sec, get_protocol_category(),
				diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes,
				diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes);

        }
      }

      if(cli_mac) {
#ifdef HAVE_NEDGE
        cli_mac->incSentStats(tv->tv_sec, diff_sent_packets, diff_sent_bytes);
        cli_mac->incRcvdStats(tv->tv_sec, diff_rcvd_packets, diff_rcvd_bytes);
#endif

        if(ntop->getPrefs()->areMacNdpiStatsEnabled()) {
          cli_mac->incnDPIStats(tv->tv_sec, get_protocol_category(),
				diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
				diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes);
        }
      }

#ifdef NTOPNG_PRO
      if(ntop->getPro()->has_valid_license()) {

#ifndef HAVE_NEDGE
	if(trafficProfile)
	  trafficProfile->incBytes(diff_sent_bytes + diff_rcvd_bytes);
#endif
      }
#endif
    }

    /* Check and possibly enqueue host remote-to-remote alerts */
    // TODO migrate to lua
    if(!cli_host->isLocalHost() && !srv_host->isLocalHost()
       && get_cli_ip_addr()->isNonEmptyUnicastAddress()
       && get_srv_ip_addr()->isNonEmptyUnicastAddress()
       && !cli_host->setRemoteToRemoteAlerts()) {
      iface->getAlertsQueue()->pushRemoteToRemoteAlert(cli_host);
    }
  } /* Closes if(cli_host && srv_host) */

  if(last_update_time.tv_sec > 0) {
    float tdiff_msec = ((float)(tv->tv_sec-last_update_time.tv_sec)*1000)+((tv->tv_usec-last_update_time.tv_usec)/(float)1000);

    if(tdiff_msec >= 1000 /* Do not update when less than 1 second (1000 msec) */) {
      // bps
      float bytes_msec_cli2srv         = ((float)(diff_sent_bytes*1000))/tdiff_msec;
      float bytes_msec_srv2cli         = ((float)(diff_rcvd_bytes*1000))/tdiff_msec;
      float bytes_msec                 = bytes_msec_cli2srv + bytes_msec_srv2cli;

      float goodput_bytes_msec_cli2srv = ((float)(diff_sent_goodput_bytes*1000))/tdiff_msec;
      float goodput_bytes_msec_srv2cli = ((float)(diff_rcvd_goodput_bytes*1000))/tdiff_msec;
      float goodput_bytes_msec         = goodput_bytes_msec_cli2srv + goodput_bytes_msec_srv2cli;

      if(isDetectionCompleted() && cli_host && srv_host) {
	iface->topProtocolsAdd(cli_host->get_host_pool(), stats_protocol, diff_bytes);

	if(cli_host->get_host_pool() != srv_host->get_host_pool())
	  iface->topProtocolsAdd(srv_host->get_host_pool(), stats_protocol, diff_bytes);

	if(cli_mac)
	  iface->topMacsAdd(cli_mac, stats_protocol, diff_bytes);

	if(srv_mac)
	  iface->topMacsAdd(srv_mac, stats_protocol, diff_bytes);
      }

      /* Just to be safe */
      if(bytes_msec < 0)                 bytes_msec                 = 0;
      if(bytes_msec_cli2srv < 0)         bytes_msec_cli2srv         = 0;
      if(bytes_msec_srv2cli < 0)         bytes_msec_srv2cli         = 0;
      if(goodput_bytes_msec < 0)         goodput_bytes_msec         = 0;
      if(goodput_bytes_msec_cli2srv < 0) goodput_bytes_msec_cli2srv = 0;
      if(goodput_bytes_msec_srv2cli < 0) goodput_bytes_msec_srv2cli = 0;

      if((bytes_msec > 0) || iface->isPacketInterface()) {
	// refresh trend stats for the overall throughput
	if(bytes_thpt < bytes_msec)      bytes_thpt_trend = trend_up;
	else if(bytes_thpt > bytes_msec) bytes_thpt_trend = trend_down;
	else                             bytes_thpt_trend = trend_stable;

	// refresh goodput stats for the overall throughput
	if(goodput_bytes_thpt < goodput_bytes_msec)      goodput_bytes_thpt_trend = trend_up;
	else if(goodput_bytes_thpt > goodput_bytes_msec) goodput_bytes_thpt_trend = trend_down;
	else                                             goodput_bytes_thpt_trend = trend_stable;

	if(false)
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[msec: %.1f][bytes: %lu][bits_thpt: %.4f Mbps]",
				       bytes_msec, diff_bytes, (bytes_thpt*8)/((float)(1024*1024)));

	// update the old values with the newly calculated ones
	bytes_thpt_cli2srv         = bytes_msec_cli2srv;
	bytes_thpt_srv2cli         = bytes_msec_srv2cli;
	goodput_bytes_thpt_cli2srv = goodput_bytes_msec_cli2srv;
	goodput_bytes_thpt_srv2cli = goodput_bytes_msec_srv2cli;

	bytes_thpt = bytes_msec, goodput_bytes_thpt = goodput_bytes_msec;
	if(top_bytes_thpt < bytes_thpt) top_bytes_thpt = bytes_thpt;
	if(top_goodput_bytes_thpt < goodput_bytes_thpt) top_goodput_bytes_thpt = goodput_bytes_thpt;

#ifdef NTOPNG_PRO
	throughputTrend.update(bytes_thpt), goodputTrend.update(goodput_bytes_thpt);
	thptRatioTrend.update(((double)(goodput_bytes_msec*100))/(double)bytes_msec);

#ifdef DEBUG_TREND
	if((get_goodput_bytes_cli2srv() + get_goodput_bytes_srv2cli()) > 0) {
	  char buf[256];

	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [Goodput long/mid/short %.3f/%.3f/%.3f][ratio: %s][goodput/thpt: %.3f]",
				       print(buf, sizeof(buf)),
				       goodputTrend.getLongTerm(), goodputTrend.getMidTerm(), goodputTrend.getShortTerm(),
				       goodputTrend.getTrendMsg(),
				       ((float)(100*(get_goodput_bytes_cli2srv() + get_goodput_bytes_srv2cli())))/(float)(get_bytes_cli2srv() + get_bytes_srv2cli()));
	}
#endif
#endif

	// pps
	float pkts_msec_cli2srv     = ((float)(diff_sent_packets*1000))/tdiff_msec;
	float pkts_msec_srv2cli     = ((float)(diff_rcvd_packets*1000))/tdiff_msec;
	float pkts_msec             = pkts_msec_cli2srv + pkts_msec_srv2cli;

	/* Just to be safe */
	if(pkts_msec < 0)         pkts_msec         = 0;
	if(pkts_msec_cli2srv < 0) pkts_msec_cli2srv = 0;
	if(pkts_msec_srv2cli < 0) pkts_msec_srv2cli = 0;

	if(pkts_thpt < pkts_msec)      pkts_thpt_trend = trend_up;
	else if(pkts_thpt > pkts_msec) pkts_thpt_trend = trend_down;
	else                           pkts_thpt_trend = trend_stable;

	pkts_thpt_cli2srv = pkts_msec_cli2srv;
	pkts_thpt_srv2cli = pkts_msec_srv2cli;
	pkts_thpt = pkts_msec;
	if(top_pkts_thpt < pkts_thpt) top_pkts_thpt = pkts_thpt;

	if(false)
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[msec: %.1f][tdiff: %f][pkts: %lu][pkts_thpt: %.2f pps]",
				       pkts_msec, tdiff_msec, diff_pkts, pkts_thpt);

      }
    }
  }

  memcpy(&last_update_time, tv, sizeof(struct timeval));
  GenericHashEntry::periodic_stats_update(user_data, quick);
}

/* *************************************** */

void Flow::periodic_dump_check(const struct timeval *tv) {
  /* Viewed interfaces don't dump flows, their flows are dumped by the overlying ViewInterface.
     ViewInterface dump their flows in another thread, not this one. */
  dumpFlow(tv, iface->isViewed() ? iface->viewedBy() : iface);
}

/* *************************************** */

void Flow::update_pools_stats(NetworkInterface *iface,
			      Host *cli_host, Host *srv_host,
			      const struct timeval *tv,
			      u_int64_t diff_sent_packets, u_int64_t diff_sent_bytes,
			      u_int64_t diff_rcvd_packets, u_int64_t diff_rcvd_bytes) const {
  if(!diff_sent_bytes && !diff_rcvd_bytes)
    return; /* Nothing to update */

  HostPools *hp;
  u_int16_t cli_host_pool_id, srv_host_pool_id;
  ndpi_protocol_category_t category_id = get_protocol_category();

  hp = iface->getHostPools();
  if(hp) {
    /* Client host */
    if(cli_host
#ifdef HAVE_NEDGE
      && cli_host->getMac() && (cli_host->getMac()->locate() == located_on_lan_interface)
#endif
    ) {
      cli_host_pool_id = cli_host->get_host_pool();

      /* Overall host pool stats */
      if(ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN
	  && !ndpi_is_subprotocol_informative(NULL, ndpiDetectedProtocol.master_protocol))
	hp->incPoolStats(tv->tv_sec, cli_host_pool_id, ndpiDetectedProtocol.app_protocol, category_id,
		       diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
      else
	hp->incPoolStats(tv->tv_sec, cli_host_pool_id, ndpiDetectedProtocol.master_protocol, category_id,
		       diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);

#ifdef NTOPNG_PRO
      /* Per host quota-enforcement stats */
      if(hp->enforceQuotasPerPoolMember(cli_host_pool_id)) {
	cli_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.master_protocol,
					   diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
	cli_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.app_protocol,
					   diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
	cli_host->incQuotaEnforcementCategoryStats(tv->tv_sec, category_id, diff_sent_bytes, diff_rcvd_bytes);
      }
#endif
    }

    /* Server host */
    if(srv_host
#ifdef HAVE_NEDGE
       && srv_host->getMac()  && (srv_host->getMac()->locate() == located_on_lan_interface)
#endif
    ) {
      srv_host_pool_id = srv_host->get_host_pool();

      /* Update server pool stats only if the pool is not equal to the client pool */
      if(!cli_host || srv_host_pool_id != cli_host_pool_id) {
	if(ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN
	    && !ndpi_is_subprotocol_informative(NULL, ndpiDetectedProtocol.master_protocol))
	  hp->incPoolStats(tv->tv_sec, srv_host_pool_id, ndpiDetectedProtocol.app_protocol, category_id,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
	else
	  hp->incPoolStats(tv->tv_sec, srv_host_pool_id, ndpiDetectedProtocol.master_protocol, category_id,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
      }

      /* When quotas have to be enforced per pool member, stats must be increased even if cli and srv are on the same pool */
#ifdef NTOPNG_PRO
      if(hp->enforceQuotasPerPoolMember(srv_host_pool_id)) {
	srv_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.master_protocol,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
	srv_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.app_protocol,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
	srv_host->incQuotaEnforcementCategoryStats(tv->tv_sec, category_id, diff_rcvd_bytes, diff_sent_bytes);
      }
#endif
    }
  }
}

/* *************************************** */

bool Flow::equal(const IpAddress *_cli_ip, const IpAddress *_srv_ip,
		 u_int16_t _cli_port, u_int16_t _srv_port,
		 u_int16_t _vlanId, u_int8_t _protocol,
		 const ICMPinfo * const _icmp_info,
		 bool *src2srv_direction) const {
  const IpAddress *cli_ip = get_cli_ip_addr(), *srv_ip = get_srv_ip_addr();

#if 0
  char buf1[64],buf2[64],buf3[64],buf4[64];
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%s][%s][%s][%s]",
			       cli_ip->print(buf1, sizeof(buf1)),
			       srv_ip->print(buf2, sizeof(buf2)),
			       _cli_ip->print(buf3, sizeof(buf3)),
			       _srv_ip->print(buf4, sizeof(buf4)));
#endif

  if(_vlanId != vlanId)
    return(false);

  if(_protocol != protocol)
    return(false);

  if(icmp_info && !icmp_info->equal(_icmp_info))
    return(false);

  if(cli_ip && cli_ip->equal(_cli_ip)
     && srv_ip && srv_ip->equal(_srv_ip)
     && _cli_port == cli_port && _srv_port == srv_port) {
    *src2srv_direction = true;
    return(true);
  } else if(srv_ip && srv_ip->equal(_cli_ip)
	    && cli_ip && cli_ip->equal(_srv_ip)
	    && _srv_port == cli_port && _cli_port == srv_port) {
    *src2srv_direction = false;
    return(true);
  } else
    return(false);
}

/* *************************************** */

const char* Flow::cipher_weakness2str(ndpi_cipher_weakness w) const {
  switch(w) {
  case ndpi_cipher_safe:
    return("safe");
    break;

  case ndpi_cipher_weak:
    return("weak");
    break;

  case ndpi_cipher_insecure:
    return("insecure");
    break;
  }

  return(""); /* NOTREACHED */
}

/* *************************************** */

void Flow::lua(lua_State* vm, AddressTree * ptree,
	       DetailsLevel details_level, bool skipNewTable) {
  const IpAddress *src_ip = get_cli_ip_addr(), *dst_ip = get_srv_ip_addr();
  bool src_match = true, dst_match = true;
  bool mask_flow;
  bool has_json_info = false;

  if(ptree) {
    if(src_ip) src_match = src_ip->match(ptree);
    if(dst_ip) dst_match = dst_ip->match(ptree);
    if(!src_match && !dst_match) return;
  }

  if(!skipNewTable)
    lua_newtable(vm);

  lua_get_ip(vm, true  /* Client */);
  lua_get_ip(vm, false /* Server */);

  lua_get_port(vm, true  /* Client */);
  lua_get_port(vm, false /* Server */);

  mask_flow = isMaskedFlow(); // mask_cli_host || mask_dst_host;

  lua_get_bytes(vm);

  if(details_level >= details_high) {
    lua_push_bool_table_entry(vm, "cli.allowed_host", src_match);
    lua_push_bool_table_entry(vm, "srv.allowed_host", dst_match);

    lua_get_info(vm, true /* Client */);
    lua_get_info(vm, false /* Server */);

    if(vrfId) lua_push_uint64_table_entry(vm, "vrfId", vrfId);
    lua_push_uint64_table_entry(vm, "vlan", get_vlan_id());

    lua_get_protocols(vm);

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    if((!mask_flow) && trafficProfile && ntop->getPro()->has_valid_license())
      lua_push_str_table_entry(vm, "profile", trafficProfile->getName());
#endif
#endif

    lua_get_packets(vm);

    lua_get_time(vm);

    lua_get_dir_traffic(vm, true /* Client to Server */);
    lua_get_dir_traffic(vm, false /* Server to Client */);

    lua_push_int32_table_entry(vm, "score", alert_score != CONST_NO_SCORE_SET ? alert_score : -1);

    if(isICMP()) {
      lua_newtable(vm);
      if(isBidirectional()) {
	lua_push_uint64_table_entry(vm, "type", protos.icmp.srv2cli.icmp_type);
	lua_push_uint64_table_entry(vm, "code", protos.icmp.srv2cli.icmp_code);
      }else {
	lua_push_uint64_table_entry(vm, "type", protos.icmp.cli2srv.icmp_type);
	lua_push_uint64_table_entry(vm, "code", protos.icmp.cli2srv.icmp_code);
      }

      if(icmp_info)
	icmp_info->lua(vm, NULL, iface, get_vlan_id());

      lua_pushstring(vm, "icmp");
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }

    lua_push_int32_table_entry(vm, "cli.devtype", (cli_host && cli_host->getMac()) ? cli_host->getMac()->getDeviceType() : device_unknown);
    lua_push_int32_table_entry(vm, "srv.devtype", (srv_host && srv_host->getMac()) ? srv_host->getMac()->getDeviceType() : device_unknown);

#ifdef HAVE_NEDGE
    if(iface->is_bridge_interface())
      lua_push_bool_table_entry(vm, "verdict.pass", isPassVerdict() ? (json_bool)1 : (json_bool)0);
#endif

    if(get_protocol() == IPPROTO_TCP)
      lua_get_tcp_info(vm);

    if(!mask_flow) {
      if(host_server_name) lua_push_str_table_entry(vm, "host_server_name", host_server_name);
      if(bt_hash)          lua_push_str_table_entry(vm, "bittorrent_hash", bt_hash);
      lua_push_str_table_entry(vm, "info", getFlowInfo() ? getFlowInfo() : (char*)"");
    }

    if(isDNS() && protos.dns.last_query) {
      lua_push_uint64_table_entry(vm, "protos.dns.last_query_type", protos.dns.last_query_type);
      lua_push_uint64_table_entry(vm, "protos.dns.last_return_code", protos.dns.last_return_code);
    }

#ifdef HAVE_NEDGE
    lua_push_uint64_table_entry(vm, "marker", marker);

    if(cli_host && srv_host) {
      /* Shapers */
      lua_push_uint64_table_entry(vm,
				  "shaper.cli2srv_ingress",
				  flowShaperIds.cli2srv.ingress ? flowShaperIds.cli2srv.ingress->get_shaper_id() : DEFAULT_SHAPER_ID);
      lua_push_uint64_table_entry(vm,
				  "shaper.cli2srv_egress",
				  flowShaperIds.cli2srv.egress ? flowShaperIds.cli2srv.egress->get_shaper_id() : DEFAULT_SHAPER_ID);
      lua_push_uint64_table_entry(vm,
				  "shaper.srv2cli_ingress",
				  flowShaperIds.srv2cli.ingress ? flowShaperIds.srv2cli.ingress->get_shaper_id() : DEFAULT_SHAPER_ID);
      lua_push_uint64_table_entry(vm,
				  "shaper.srv2cli_egress",
				  flowShaperIds.srv2cli.egress ? flowShaperIds.srv2cli.egress->get_shaper_id() : DEFAULT_SHAPER_ID);

      /* Quota */
      lua_push_str_table_entry(vm, "cli.quota_source", Utils::policySource2Str(cli_quota_source));
      lua_push_str_table_entry(vm, "srv.quota_source", Utils::policySource2Str(srv_quota_source));
    }
#endif

    if(!mask_flow) {
      if(isHTTP())
	lua_get_http_info(vm);

      if(isDNS())
	lua_get_dns_info(vm);

      if(isSSH())
	lua_get_ssh_info(vm);

      if(isTLS())
	lua_get_tls_info(vm);
    }

    if(get_json_info()) {
      lua_push_str_table_entry(vm, "moreinfo.json", json_object_to_json_string(get_json_info()));
      has_json_info = true;
    } else if (get_tlv_info()) {
      ndpi_deserializer deserializer;
      if (ndpi_init_deserializer(&deserializer, get_tlv_info()) == 0) {
        ndpi_serializer serializer;
        if (ndpi_init_serializer(&serializer, ndpi_serialization_format_json) >= 0) {
          char *buffer;
          u_int32_t buffer_len;
          ndpi_deserialize_clone_all(&deserializer, &serializer);
          buffer = ndpi_serializer_get_buffer(&serializer, &buffer_len);
          if (buffer) {
            lua_push_str_table_entry(vm, "moreinfo.json", buffer);
            has_json_info = true;
          }
          ndpi_term_serializer(&serializer);
        }
      }
    }
    if (!has_json_info)
      lua_push_str_table_entry(vm, "moreinfo.json", "{}");

    if(cli_ebpf) cli_ebpf->lua(vm, true);
    if(srv_ebpf) srv_ebpf->lua(vm, false);

    lua_get_throughput(vm);

    /* Interarrival Times */
    lua_get_dir_iat(vm, true /* Client to Server */);
    lua_get_dir_iat(vm, false /* Server to Client */);

    if((!mask_flow) && (details_level >= details_higher)) {
      lua_get_geoloc(vm, true /* Client */, true /* Coordinates */, false /* Country and City */);
      lua_get_geoloc(vm, false /* Server */, true /* Coordinates */, false /* Country and City */);

      if(details_level >= details_max) {
	lua_get_geoloc(vm, true /* Client */, false /* Coordinates */, true /* Country and City */);
	lua_get_geoloc(vm, false /* Server */, false /* Coordinates */, true /* Country and City */);
      }
    }

    if(alert_status_info)
      lua_push_str_table_entry(vm, "status_info", alert_status_info);
  }

  lua_get_status(vm);

  // this is used to dynamicall update entries in the GUI
  lua_push_uint64_table_entry(vm, "ntopng.key", key()); // Key
  lua_push_uint64_table_entry(vm, "hash_entry_id", get_hash_entry_id());
}

/* *************************************** */

u_int32_t Flow::key() {
  u_int32_t k = cli_port + srv_port + vlanId + protocol;

  if(get_cli_ip_addr()) k += get_cli_ip_addr()->key();
  if(get_srv_ip_addr()) k += get_srv_ip_addr()->key();
  if(icmp_info) k += icmp_info->key();

  return(k);
}

/* *************************************** */

u_int32_t Flow::key(Host *_cli, u_int16_t _cli_port,
		    Host *_srv, u_int16_t _srv_port,
		    u_int16_t _vlan_id,
		    u_int16_t _protocol) {
  u_int32_t k = _cli_port + _srv_port + _vlan_id + _protocol;

  if(_cli) k += _cli -> key();
  if(_srv) k += _srv -> key();

  return(k);
}

/* *************************************** */

void Flow::set_hash_entry_id(u_int assigned_hash_entry_id) {
  hash_entry_id = assigned_hash_entry_id;
};

/* *************************************** */

u_int Flow::get_hash_entry_id() const {
  return hash_entry_id;
};

/* *************************************** */

void Flow::set_hash_entry_state_idle() {
  if(cli_host)
    cli_host->decNumFlows(last_seen, true, srv_host);

  if(srv_host)
    srv_host->decNumFlows(last_seen, false, cli_host);

  if(isFlowAlerted()) {
    iface->decNumAlertedFlows(this);
#ifdef ALERTED_FLOWS_DEBUG
      iface_alert_dec = true;
#endif
  }

  GenericHashEntry::set_hash_entry_state_idle();
}

/* *************************************** */

bool Flow::is_hash_entry_state_idle_transition_ready() const {
#ifdef HAVE_NEDGE
  if(iface->getIfType() == interface_type_NETFILTER)
    return(isNetfilterIdleFlow());
#endif

  if(protocol == IPPROTO_TCP) {
    u_int8_t tcp_flags = src2dst_tcp_flags | dst2src_tcp_flags;

    /* The flow is considered idle after a MAX_TCP_FLOW_IDLE
       when RST/FIN are set or when the TWH is not completed.
       This prevents finalized/reset flows, or flows with an imcomplete
       TWH from staying in memory for too long. */
    if((tcp_flags & TH_FIN
	|| tcp_flags & TH_RST
	|| ((iface->isPacketInterface()
	     || tcp_flags /* If not a packet interfaces, we expect flags to be set to be sure they've been exported */)
	    && !isThreeWayHandshakeOK()))
       /* Flows won't expire if less than DONT_NOT_EXPIRE_BEFORE_SEC old */
       && iface->getTimeLastPktRcvd() > doNotExpireBefore
       && isIdle(MAX_TCP_FLOW_IDLE)) {
      /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "[TCP] Early flow expire"); */
      return(true);
    }
  }

  return(isIdle(iface->getFlowMaxIdle()));
}

/* *************************************** */

void Flow::periodic_hash_entry_state_update(void *user_data, bool quick) {
  periodic_ht_state_update_user_data_t *periodic_ht_state_update_user_data = (periodic_ht_state_update_user_data_t*)user_data;
  struct timeval *tv = periodic_ht_state_update_user_data->tv;

#if 0
  char buf[256];

  if(quick) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deadline approaching, quick update [%s][%s]", getInterface()->get_name(), print(buf, sizeof(buf)));
  }
#endif

  switch(get_state()) {
  case hash_entry_state_allocated:
  case hash_entry_state_flow_notyetdetected:
    /* Nothing to do here */
    break;

  case hash_entry_state_flow_protocoldetected:
    pending_lua_call_protocol_detected = true;
    set_hash_entry_state_active();
    break;

  case hash_entry_state_active:
    if(next_lua_call_periodic_update == 0) next_lua_call_periodic_update = tv->tv_sec + FLOW_LUA_CALL_PERIODIC_UPDATE_SECS;
    if(!quick)
      periodic_dump_check(tv); /* TODO: move it in a lua script; NOTE: this call can take a long time! */
    /* Don't change state: purgeIdle() will do */
    break;

  case hash_entry_state_idle:
    postFlowSetIdle(tv, quick);
    if(!quick)
      periodic_dump_check(tv); /* TODO: move it in a lua script; NOTE: this call can take a long time! */
    break;
  }

  /* Now that the states in the finite state machine have been moved forward, it is time to check and 
     possibly perform lua calls on the flow. */
  performLuaCalls(tv, periodic_ht_state_update_user_data, quick);

  GenericHashEntry::periodic_hash_entry_state_update(user_data, quick);
}

/* *************************************** */

void Flow::sumStats(nDPIStats *ndpi_stats, FlowStats *status_stats) {
  ndpi_stats->incStats(0, ndpiDetectedProtocol.app_protocol,
		       get_packets_cli2srv(), get_bytes_cli2srv(),
		       get_packets_srv2cli(), get_bytes_srv2cli());

  status_stats->incStats(getStatusBitmap(), protocol);
}

/* *************************************** */

char* Flow::serialize(bool es_json) {
  json_object *my_object;
  char *rsp;

  if(es_json) {
    ntop->getPrefs()->set_json_symbolic_labels_format(true);
    if((my_object = flow2json()) != NULL) {

      /* JSON string */
      rsp = strdup(json_object_to_json_string(my_object));

      /* Free memory */
      json_object_put(my_object);
    } else
      rsp = NULL;
  } else {
    /* JSON string */
    ntop->getPrefs()->set_json_symbolic_labels_format(false);
    my_object = flow2json();
    rsp = strdup(json_object_to_json_string(my_object));
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Emitting Flow: %s", rsp);

    /* Free memory */
    json_object_put(my_object);
  }

  return(rsp);
}

/* *************************************** */

json_object* Flow::flow2json() {
  json_object *my_object;
  char buf[64], jsonbuf[64], *c;
  time_t t;
  const IpAddress *cli_ip = get_cli_ip_addr(), *srv_ip = get_srv_ip_addr();

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  if(ntop->getPrefs()->do_dump_flows_on_es()
    || ntop->getPrefs()->do_dump_flows_on_ls()
    ) {
    struct tm* tm_info;

    t = last_seen;
    tm_info = gmtime(&t);

    /*
      strftime in the VS2013 library and earlier are not C99-conformant,
      as they do not accept that format-specifier: MSDN VS2013 strftime page

      https://msdn.microsoft.com/en-us/library/fe06s4ak.aspx
    */
    strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S.0Z", tm_info);

    if(ntop->getPrefs()->do_dump_flows_on_ls()) {
      /*  Add current timestamp differently for Logstash, in case of delay
       *  Note: Logstash generates it's own @timestamp field on input
       */
      json_object_object_add(my_object,"ntop_timestamp",json_object_new_string(buf));
    }

    if(ntop->getPrefs()->do_dump_flows_on_es()) {
      json_object_object_add(my_object, "@timestamp", json_object_new_string(buf));
      json_object_object_add(my_object, "type", json_object_new_string(ntop->getPrefs()->get_es_type()));
    }
    /* json_object_object_add(my_object, "@version", json_object_new_int(1)); */

    // MAC addresses are set only when dumping to ES to optimize space consumption
    if(cli_host && cli_host->getMac() && !cli_host->getMac()->isNull())
      json_object_object_add(my_object, Utils::jsonLabel(IN_SRC_MAC, "IN_SRC_MAC", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(Utils::formatMac(cli_host ? cli_host->get_mac() : NULL, buf, sizeof(buf))));

    if(srv_host && srv_host->getMac() && !srv_host->getMac()->isNull())
      json_object_object_add(my_object, Utils::jsonLabel(OUT_DST_MAC, "OUT_DST_MAC", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(Utils::formatMac(srv_host ? srv_host->get_mac() : NULL, buf, sizeof(buf))));
  }

  if(cli_ip) {
    if(cli_ip->isIPv4()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV4_SRC_ADDR, "IPV4_SRC_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(cli_ip->print(buf, sizeof(buf))));
    } else if(cli_ip->isIPv6()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV6_SRC_ADDR, "IPV6_SRC_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(cli_ip->print(buf, sizeof(buf))));
    }
  }

  if(srv_ip) {
    if(srv_ip->isIPv4()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV4_DST_ADDR, "IPV4_DST_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(srv_ip->print(buf, sizeof(buf))));
    } else if(srv_ip->isIPv6()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV6_DST_ADDR, "IPV6_DST_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(srv_ip->print(buf, sizeof(buf))));
    }
  }

  json_object_object_add(my_object, Utils::jsonLabel(L4_SRC_PORT, "L4_SRC_PORT", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(get_cli_port()));
  json_object_object_add(my_object, Utils::jsonLabel(L4_DST_PORT, "L4_DST_PORT", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(get_srv_port()));

  json_object_object_add(my_object, Utils::jsonLabel(PROTOCOL, "PROTOCOL", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(protocol));

  if(((get_packets_cli2srv() + get_packets_srv2cli()) > NDPI_MIN_NUM_PACKETS)
     || (ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN)) {
    json_object_object_add(my_object, Utils::jsonLabel(L7_PROTO, "L7_PROTO", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int(ndpiDetectedProtocol.app_protocol));
    json_object_object_add(my_object, Utils::jsonLabel(L7_PROTO_NAME, "L7_PROTO_NAME", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_string(get_detected_protocol_name(buf, sizeof(buf))));
  }

  if(protocol == IPPROTO_TCP)
    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "TCP_FLAGS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int(src2dst_tcp_flags | dst2src_tcp_flags));

  json_object_object_add(my_object, Utils::jsonLabel(IN_PKTS, "IN_PKTS", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(get_partial_packets_cli2srv()));
  json_object_object_add(my_object, Utils::jsonLabel(IN_BYTES, "IN_BYTES", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(get_partial_bytes_cli2srv()));

  json_object_object_add(my_object, Utils::jsonLabel(OUT_PKTS, "OUT_PKTS", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(get_partial_packets_srv2cli()));
  json_object_object_add(my_object, Utils::jsonLabel(OUT_BYTES, "OUT_BYTES", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(get_partial_bytes_srv2cli()));

  json_object_object_add(my_object, Utils::jsonLabel(FIRST_SWITCHED, "FIRST_SWITCHED", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int((u_int32_t)get_partial_first_seen()));
  json_object_object_add(my_object, Utils::jsonLabel(LAST_SWITCHED, "LAST_SWITCHED", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int((u_int32_t)get_partial_last_seen()));

  if(json_info && json_object_object_length(json_info) > 0)
    json_object_object_add(my_object, "json", json_object_get(json_info));

  if(vlanId > 0) json_object_object_add(my_object,
					Utils::jsonLabel(SRC_VLAN, "SRC_VLAN", jsonbuf, sizeof(jsonbuf)),
					json_object_new_int(vlanId));

  if(protocol == IPPROTO_TCP) {
    json_object_object_add(my_object, Utils::jsonLabel(CLIENT_NW_LATENCY_MS, "CLIENT_NW_LATENCY_MS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_double(toMs(&clientNwLatency)));
    json_object_object_add(my_object, Utils::jsonLabel(SERVER_NW_LATENCY_MS, "SERVER_NW_LATENCY_MS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_double(toMs(&serverNwLatency)));
  }

  c = cli_host ? cli_host->get_country(buf, sizeof(buf)) : NULL;
  if(c) {
    json_object *location = json_object_new_array();

    json_object_object_add(my_object, "SRC_IP_COUNTRY", json_object_new_string(c));
    if(location && cli_host) {
      float latitude, longitude;

      cli_host->get_geocoordinates(&latitude, &longitude);
      json_object_array_add(location, json_object_new_double(longitude));
      json_object_array_add(location, json_object_new_double(latitude));
      json_object_object_add(my_object, "SRC_IP_LOCATION", location);
    }
  }

  c = srv_host ? srv_host->get_country(buf, sizeof(buf)) : NULL;
  if(c) {
    json_object *location = json_object_new_array();

    json_object_object_add(my_object, "DST_IP_COUNTRY", json_object_new_string(c));
    if(location && srv_host) {
      float latitude, longitude;

      srv_host->get_geocoordinates(&latitude, &longitude);
      json_object_array_add(location, json_object_new_double(longitude));
      json_object_array_add(location, json_object_new_double(latitude));
      json_object_object_add(my_object, "DST_IP_LOCATION", location);
    }
  }

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  // Traffic profile information, if any
  if(trafficProfile && trafficProfile->getName())
    json_object_object_add(my_object, "PROFILE", json_object_new_string(trafficProfile->getName()));
#endif
#endif
  if(ntop->getPrefs() && ntop->getPrefs()->get_instance_name())
    json_object_object_add(my_object, "NTOPNG_INSTANCE_NAME",
			   json_object_new_string(ntop->getPrefs()->get_instance_name()));
  if(iface && iface->get_name())
    json_object_object_add(my_object, "INTERFACE", json_object_new_string(iface->get_name()));

  if(isDNS() && protos.dns.last_query)
    json_object_object_add(my_object, "DNS_QUERY", json_object_new_string(protos.dns.last_query));

  if(isHTTP()) {
    if(host_server_name && host_server_name[0] != '\0')
      json_object_object_add(my_object, "HTTP_HOST", json_object_new_string(host_server_name));
    if(protos.http.last_url && protos.http.last_url[0] != '0')
      json_object_object_add(my_object, "HTTP_URL", json_object_new_string(protos.http.last_url));
    if(protos.http.last_method && protos.http.last_method[0] != '\0')
      json_object_object_add(my_object, "HTTP_METHOD", json_object_new_string(protos.http.last_method));
    if(protos.http.last_return_code > 0)
      json_object_object_add(my_object, "HTTP_RET_CODE", json_object_new_int((u_int32_t)protos.http.last_return_code));
  }

  if(bt_hash)
    json_object_object_add(my_object, "BITTORRENT_HASH", json_object_new_string(bt_hash));

  if(isTLS() && protos.tls.certificate)
    json_object_object_add(my_object, "SSL_SERVER_NAME", json_object_new_string(protos.tls.certificate));

#ifdef HAVE_NEDGE
  if(iface && iface->is_bridge_interface())
    json_object_object_add(my_object, "verdict.pass",
			   json_object_new_boolean(isPassVerdict() ? (json_bool)1 : (json_bool)0));
#endif

  if(cli_ebpf) cli_ebpf->getJSONObject(my_object, true);
  if(srv_ebpf) srv_ebpf->getJSONObject(my_object, false);

  return(my_object);
}

/* *************************************** */

/* Create a JSON in the alerts format
 * Using the nDPI json serializer instead of jsonc for faster speed (~2.5x) */
void Flow::flow2alertJson(ndpi_serializer *s, time_t now) {
  ndpi_serializer json_info;
  u_int32_t buflen;
  const char *info;
  char buf[64];

  ndpi_init_serializer(&json_info, ndpi_serialization_format_json);

  /* AlertsManager::storeFlowAlert requires a string */
  info = getFlowInfo();
  ndpi_serialize_string_string(&json_info, "info", info ? info : "");
  ndpi_serialize_string_string(&json_info, "status_info", alert_status_info ? alert_status_info : "");
  ndpi_serialize_string_string(s, "alert_json", ndpi_serializer_get_buffer(&json_info, &buflen));
  ndpi_term_serializer(&json_info);

  ndpi_serialize_string_int32(s, "ifid", iface->get_id());
  ndpi_serialize_string_string(s, "action", "store");

  ndpi_serialize_string_boolean(s, "is_flow_alert", true);
  ndpi_serialize_string_int64(s, "alert_tstamp", now);
  ndpi_serialize_string_int64(s, "flow_status", alerted_status);
  ndpi_serialize_string_int32(s, "alert_type", alert_type);
  ndpi_serialize_string_int32(s, "alert_severity", alert_level);

  ndpi_serialize_string_int32(s, "vlan_id", get_vlan_id());
  ndpi_serialize_string_int32(s, "proto", protocol);
  ndpi_serialize_string_int32(s, "l7_master_proto", ndpiDetectedProtocol.master_protocol);
  ndpi_serialize_string_int32(s, "l7_proto", ndpiDetectedProtocol.app_protocol);

  ndpi_serialize_string_int64(s, "cli2srv_bytes", get_bytes_cli2srv());
  ndpi_serialize_string_int64(s, "cli2srv_packets", get_packets_cli2srv());
  ndpi_serialize_string_int64(s, "srv2cli_bytes", get_bytes_srv2cli());
  ndpi_serialize_string_int64(s, "srv2cli_packets", get_packets_srv2cli());

  if(cli_host) {
    ndpi_serialize_string_string(s, "cli_addr", cli_host->get_ip()->print(buf, sizeof(buf)));
    ndpi_serialize_string_string(s, "cli_country", cli_host->get_country(buf, sizeof(buf)));
    ndpi_serialize_string_string(s, "cli_os", cli_host->getOSDetail(buf, sizeof(buf)));
    ndpi_serialize_string_int32(s, "cli_asn", cli_host->get_asn());
    ndpi_serialize_string_boolean(s, "cli_localhost", cli_host->isLocalHost());
    ndpi_serialize_string_boolean(s, "cli_blacklisted", cli_host->isBlacklisted());
  }
  if(srv_host) {
    ndpi_serialize_string_string(s, "srv_addr", srv_host->get_ip()->print(buf, sizeof(buf)));
    ndpi_serialize_string_string(s, "srv_country", srv_host->get_country(buf, sizeof(buf)));
    ndpi_serialize_string_string(s, "srv_os", srv_host->getOSDetail(buf, sizeof(buf)));
    ndpi_serialize_string_int32(s, "srv_asn", srv_host->get_asn());
    ndpi_serialize_string_boolean(s, "srv_localhost", srv_host->isLocalHost());
    ndpi_serialize_string_boolean(s, "srv_blacklisted", srv_host->isBlacklisted());
  }
}

/* *************************************** */

#ifdef HAVE_NEDGE

bool Flow::isNetfilterIdleFlow() const {
  /*
     Note that on netfilter interfaces we never observe the
     FIN/RST flags as they have been offloaded to kernel

     Hence on netfilter interfaces flows are purged only for
     inactivity based on lastSeen updates
  */

  if(last_conntrack_update > 0) {
    /*
      - At latest every MIN_CONNTRACK_UPDATE the scan is performed
      - the conntrack scan time that we  assume is less than MIN_CONNTRACK_UPDATE
      - in the worst case this method is called when iface->getTimeLastPktRcvd()
        is almost MIN_CONNTRACK_UPDATE past the last scan

      Thuis in total we assume that every 3*MIN_CONNTRACK_UPDATE
      seconds an active flow should have been updated
      by conntrack
    */
    if(iface->getTimeLastPktRcvd() > (last_conntrack_update + (3 * MIN_CONNTRACK_UPDATE)))
      return(true);

    return(false);
  } else {
    /* if an conntrack update hasn't been seen for this flow
       we use the standard idleness check */
    return(isIdle(iface->getFlowMaxIdle()));
  }
}
#endif

/* *************************************** */

void Flow::housekeep(time_t t) {
  if(((t - get_last_seen()) > 5 /* sec */)     
     && iface->get_ndpi_struct() && get_ndpi_flow()) {
    u_int8_t proto_guessed;
    ndpi_protocol givenup_protocol = ndpi_detection_giveup(iface->get_ndpi_struct(),
							   get_ndpi_flow(), 1, &proto_guessed);
    
    setDetectedProtocol(givenup_protocol, true);
  }
}

/* *************************************** */

bool Flow::get_partial_traffic_stats(PartializableFlowTrafficStats **dst, PartializableFlowTrafficStats *fts, bool *first_partial) const {
  if(!fts || !dst)
    return(false);

  if(!*dst) {
    if(!(*dst = new (std::nothrow) PartializableFlowTrafficStats()))
      return(false);
    *first_partial = true;
  } else
    *first_partial = false;

  stats.get_partial(dst, fts);

  return(true);
}

/* *************************************** */

bool Flow::get_partial_traffic_stats_view(PartializableFlowTrafficStats *fts, bool *first_partial) {
  return get_partial_traffic_stats(&last_partial, fts, first_partial);
}
  
/* *************************************** */

bool Flow::update_partial_traffic_stats_db_dump() {  
  bool first_partial;

  if(!get_partial_traffic_stats(&last_db_dump.partial, &last_db_dump.delta, &first_partial))
    return(false);

  if(first_partial)
    last_db_dump.first_seen = get_first_seen();
  else
    last_db_dump.first_seen = last_db_dump.last_seen;

  last_db_dump.last_seen = get_last_seen();

  return(true);
}

/* *************************************** */

void Flow::updatePacketStats(InterarrivalStats *stats,
			     const struct timeval *when, bool update_iat) {
  if(stats)
    stats->updatePacketStats((struct timeval*)when, update_iat);
}

/* *************************************** */

bool Flow::isBlacklistedFlow() const {
  bool res = ((cli_host && cli_host->isBlacklisted())
	      || (srv_host && srv_host->isBlacklisted())
	      || (get_protocol_category() == CUSTOM_CATEGORY_MALWARE));

#ifdef BLACKLISTED_FLOWS_DEBUG
  if(res) {
    char buf[512];
    print(buf, sizeof(buf));
    snprintf(&buf[strlen(buf)], sizeof(buf) - strlen(buf), "[cli_blacklisted: %u][srv_blacklisted: %u][category: %s]", cli_host->isBlacklisted(), srv_host->isBlacklisted(), get_protocol_category_name());
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", buf);
  }
#endif

  return res;
};

/* *************************************** */

bool Flow::isTLSProto() {
  u_int16_t lower = ndpi_get_lower_proto(ndpiDetectedProtocol);

  return(
    (lower == NDPI_PROTOCOL_TLS) ||
    (lower == NDPI_PROTOCOL_MAIL_IMAPS) ||
    (lower == NDPI_PROTOCOL_MAIL_SMTPS) ||
    (lower == NDPI_PROTOCOL_MAIL_POPS)
  );
}

/* *************************************** */

void Flow::incStats(bool cli2srv_direction, u_int pkt_len,
		    u_int8_t *payload, u_int payload_len,
                    u_int8_t l4_proto, u_int8_t is_fragment,
		    u_int16_t tcp_flags, const struct timeval *when) {
  bool update_iat = true;
  
  payload_len *= iface->getScalingFactor();
  updateSeen();

  /*
    Do not update IAT during initial or final 3WH as we want to compute
    it only on the main traffic flow and not on connection or tear-down
  */
  if((l4_proto == IPPROTO_TCP) && (tcp_flags & (TH_SYN|TH_FIN|TH_RST)))
    update_iat = false;
  
  updatePacketStats(cli2srv_direction ? getCli2SrvIATStats() : getSrv2CliIATStats(), when, update_iat);

  stats.incStats(cli2srv_direction, 1, pkt_len, payload_len);

  if(cli2srv_direction) {
    ip_stats_s2d.pktFrag += is_fragment;
    if(cli_host) cli_host->incSentStats(1, pkt_len);
    if(srv_host) srv_host->incRecvStats(1, pkt_len);
  } else {
    ip_stats_d2s.pktFrag += is_fragment;
    if(cli_host) cli_host->incRecvStats(1, pkt_len);
    if(srv_host) srv_host->incSentStats(1, pkt_len);
  }

  if((applLatencyMsec == 0) && (payload_len > 0)) {
    if(cli2srv_direction) {
      memcpy(&c2sFirstGoodputTime, when, sizeof(struct timeval));
    } else {
      if(c2sFirstGoodputTime.tv_sec != 0)
	applLatencyMsec = ((float)(Utils::timeval2usec((struct timeval*)when)
				   - Utils::timeval2usec(&c2sFirstGoodputTime)))/1000;
    }
  }
}

/* *************************************** */

void Flow::updateInterfaceLocalStats(bool src2dst_direction, u_int num_pkts, u_int pkt_len) {
  Host *from = src2dst_direction ? cli_host : srv_host;
  Host *to   = src2dst_direction ? srv_host : cli_host;

  iface->incLocalStats(num_pkts, pkt_len,
		       from ? from->isLocalHost() : false,
		       to ? to->isLocalHost() : false);
}

/* *************************************** */

void Flow::addFlowStats(bool cli2srv_direction,
			u_int in_pkts, u_int in_bytes, u_int in_goodput_bytes,
			u_int out_pkts, u_int out_bytes, u_int out_goodput_bytes,
			u_int in_fragments, u_int out_fragments, time_t last_seen) {

  /* Don't update seen if no traffic has been observed */
  if((in_bytes == 0) && (out_bytes == 0)) return;

  updateSeen(last_seen);

  if(cli2srv_direction) {
    stats.incStats(true, in_pkts, in_bytes, in_goodput_bytes);
    stats.incStats(false, out_pkts, out_bytes, out_goodput_bytes);
    ip_stats_s2d.pktFrag += in_fragments, ip_stats_d2s.pktFrag += out_fragments;
  } else {
    stats.incStats(true, out_pkts, out_bytes, out_goodput_bytes);
    stats.incStats(false, in_pkts, in_bytes, in_goodput_bytes);
    ip_stats_s2d.pktFrag += out_fragments, ip_stats_d2s.pktFrag += in_fragments;
  }

  if(bytes_thpt == 0 && last_seen >= first_seen + 1) {
    /* Do a fist estimation while waiting for the periodic activities */
    bytes_thpt = (get_bytes_cli2srv() + get_bytes_srv2cli()) / (float)(last_seen - first_seen),
      pkts_thpt = (get_packets_cli2srv() + get_packets_srv2cli()) / (float)(last_seen - first_seen);
  }
}
/* *************************************** */

void Flow::setTcpFlags(u_int8_t flags, bool src2dst_direction) {
  if(iface->isPacketInterface())
    return; /* Use updateTcpFlags for packet interfaces */

  iface->incFlagsStats(flags);

  if(cli_host) cli_host->incFlagStats(src2dst_direction, flags);
  if(srv_host) srv_host->incFlagStats(!src2dst_direction, flags);

  if((flags & TH_SYN) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_SYN) != TH_SYN))
    iface->getTcpFlowStats()->incSyn();

  if((flags & TH_RST) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_RST) != TH_RST))
    iface->getTcpFlowStats()->incReset();

  if((flags & TH_FIN) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_FIN) != TH_FIN))
    iface->getTcpFlowStats()->incFin();

  /* The update below must be after the above check */
  if(src2dst_direction)
    src2dst_tcp_flags |= flags;
  else
    dst2src_tcp_flags |= flags;

  if(!twh_over) {
    if((src2dst_tcp_flags & (TH_SYN|TH_ACK)) == (TH_SYN|TH_ACK)
       && ((dst2src_tcp_flags & (TH_SYN|TH_ACK)) == (TH_SYN|TH_ACK)))
      twh_ok = twh_over = true,
	iface->getTcpFlowStats()->incEstablished();
  }

  /* Can't set these guys for non-packet interfaces */
  memset(&synTime, 0, sizeof(synTime)),
    memset(&synAckTime, 0, sizeof(synAckTime)),
    memset(&ackTime, 0, sizeof(ackTime));
}

/* *************************************** */

void Flow::updateTcpFlags(const struct bpf_timeval *when,
			  u_int8_t flags, bool src2dst_direction) {
  NetworkStats *cli_network_stats = NULL, *srv_network_stats = NULL;

  if(!iface->isPacketInterface())
    return; /* Use setTcpFlags for non-packet interfaces */

  iface->incFlagsStats(flags);
  if(cli_host) {
    cli_host->incFlagStats(src2dst_direction, flags);
    cli_network_stats = cli_host->getNetworkStats(cli_host->get_local_network_id());
  }
  if(srv_host) {
    srv_host->incFlagStats(!src2dst_direction, flags);
    srv_network_stats = srv_host->getNetworkStats(srv_host->get_local_network_id());
  }

  if(flags == TH_SYN) {
    if(cli_host) cli_host->updateSynAlertsCounter(when->tv_sec, src2dst_direction);
    if(srv_host) srv_host->updateSynAlertsCounter(when->tv_sec, !src2dst_direction);
    if(cli_network_stats) cli_network_stats->updateSynAlertsCounter(when->tv_sec, src2dst_direction);
    if(srv_network_stats) srv_network_stats->updateSynAlertsCounter(when->tv_sec, !src2dst_direction);
  }

  if((flags & TH_SYN) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_SYN) != TH_SYN))
    iface->getTcpFlowStats()->incSyn();
  else if((flags & TH_RST) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_RST) != TH_RST))
    iface->getTcpFlowStats()->incReset();
  else if((flags & TH_FIN) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_FIN) != TH_FIN))
    iface->getTcpFlowStats()->incFin();

  /* The update below must be after the above check */
  if(src2dst_direction)
    src2dst_tcp_flags |= flags;
  else
    dst2src_tcp_flags |= flags;

  if(!twh_over) {
    if(flags == TH_SYN) {
      cli2srv_direction = src2dst_direction;
      if(synTime.tv_sec == 0) memcpy(&synTime, when, sizeof(struct timeval));
    } else if(flags == (TH_SYN|TH_ACK)) {
      cli2srv_direction = !src2dst_direction;
      if((synAckTime.tv_sec == 0) && (synTime.tv_sec > 0)) {
	memcpy(&synAckTime, when, sizeof(struct timeval));
	timeval_diff(&synTime, (struct timeval*)when, &serverNwLatency, 1);
	/* Sanity check */
	if(serverNwLatency.tv_sec > 5)
	  memset(&serverNwLatency, 0, sizeof(serverNwLatency));
	else if(srv_host)
	  srv_host->updateRoundTripTime(Utils::timeval2ms(&serverNwLatency));
      }
      if(cli_host) cli_host->update3WHSCompletedAlertsCounter(when->tv_sec, src2dst_direction);
      if(srv_host) srv_host->update3WHSCompletedAlertsCounter(when->tv_sec, !src2dst_direction);
      if(cli_network_stats) cli_network_stats->update3WHSCompletedAlertsCounter(when->tv_sec, src2dst_direction);
      if(srv_network_stats) srv_network_stats->update3WHSCompletedAlertsCounter(when->tv_sec, !src2dst_direction);
    } else if(flags == TH_ACK) {
      if((ackTime.tv_sec == 0) && (synAckTime.tv_sec > 0)) {
	memcpy(&ackTime, when, sizeof(struct timeval));
	timeval_diff(&synAckTime, (struct timeval*)when, &clientNwLatency, 1);

	/* Sanity check */
	if(clientNwLatency.tv_sec > 5)
	  memset(&clientNwLatency, 0, sizeof(clientNwLatency));
	else if(cli_host)
	  cli_host->updateRoundTripTime(Utils::timeval2ms(&clientNwLatency));

	setRtt();

	twh_ok = true;
      }

      goto not_yet;
    } else {
    not_yet:
      twh_over = true, iface->getTcpFlowStats()->incEstablished();

      /*
	Sometimes nDPI detects the protocol at the first packet
	so we're already on the protocol detected slot. This is
	is not a good news as we might have protocol detected
	when 3WH is not yet completed.
       */
      if(get_state() == hash_entry_state_allocated)
	set_hash_entry_state_flow_notyetdetected();
    }
  }
}

/* *************************************** */

void Flow::timeval_diff(struct timeval *begin, const struct timeval *end,
			struct timeval *result, u_short divide_by_two) {
  if(end->tv_sec >= begin->tv_sec) {
    result->tv_sec = end->tv_sec-begin->tv_sec;

    if((end->tv_usec - begin->tv_usec) < 0) {
      result->tv_usec = 1000000 + end->tv_usec - begin->tv_usec;
      if(result->tv_usec > 1000000) begin->tv_usec = 1000000;
      result->tv_sec--;
    } else
      result->tv_usec = end->tv_usec-begin->tv_usec;

    if(divide_by_two) {
      result->tv_usec /= 2;
      if(result->tv_sec % 2)
	result->tv_usec += 500000;
      result->tv_sec /= 2;
    }
  } else
    result->tv_sec = 0, result->tv_usec = 0;
}

/* *************************************** */

const char* Flow::getFlowInfo() {
  if(!isMaskedFlow()) {
    if(isDNS() && protos.dns.last_query)
      return protos.dns.last_query;

    else if(isHTTP() && protos.http.last_url)
      return protos.http.last_url;

    else if(isTLS() && protos.tls.certificate)
      return protos.tls.certificate;

    else if(bt_hash)
      return bt_hash;

    else if(host_server_name)
      return host_server_name;

    else if(isSSH()) {
      if(protos.ssh.server_signature)
	return protos.ssh.server_signature;
      else if(protos.ssh.client_signature)
	return protos.ssh.client_signature;
    }
  }
  
  return (char*)"";
}

/* *************************************** */

double Flow::toMs(const struct timeval *t) {
  return(((double)t->tv_sec)*1000+((double)t->tv_usec)/1000);
}

/* *************************************** */

u_int32_t Flow::getNextTcpSeq ( u_int8_t tcpFlags,
				u_int32_t tcpSeqNum,
				u_int32_t payloadLen) {
  return(tcpSeqNum + ((tcpFlags & TH_SYN) ? 1 : 0) + payloadLen);
}

/* *************************************** */

void Flow::incTcpBadStats(bool src2dst_direction,
			  Host *cli, Host *srv,
			  NetworkInterface *iface,
			  u_int32_t ooo_pkts,
			  u_int32_t retr_pkts,
			  u_int32_t lost_pkts,
			  u_int32_t keep_alive_pkts) {
#ifdef HAVE_NEDGE
  return;
#endif

  if(!ooo_pkts && !retr_pkts && !lost_pkts && !keep_alive_pkts)
    return;

  int16_t cli_network_id = -1, srv_network_id = -1;
  u_int32_t cli_asn = (u_int32_t)-1, srv_asn = (u_int32_t)-1;
  AutonomousSystem *cli_as = NULL, *srv_as = NULL;
  NetworkStats *cli_network_stats = NULL, *srv_network_stats = NULL;
  bool cli_and_srv_in_same_subnet = false, cli_and_srv_in_same_as = false;

  if(iface) {
    if(retr_pkts)       iface->incRetransmittedPkts(retr_pkts);
    if(lost_pkts)       iface->incLostPkts(lost_pkts);
    if(ooo_pkts)        iface->incOOOPkts(ooo_pkts);
    if(keep_alive_pkts) iface->incKeepAlivePkts(keep_alive_pkts);
  }

  if(cli) {
    cli_network_id = cli->get_local_network_id();
    cli_network_stats = cli->getNetworkStats(cli_network_id);
    cli_asn = cli->get_asn();
    cli_as = cli->get_as();

    if(src2dst_direction)
      cli->incSentTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
    else
      cli->incRcvdTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
  }

  if(srv) {
    srv_network_id = srv->get_local_network_id();
    srv_network_stats = srv->getNetworkStats(srv_network_id);
    srv_asn = srv->get_asn();
    srv_as = srv->get_as();

    if(src2dst_direction)
      srv->incRcvdTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
    else
      srv->incSentTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
  }

  if(cli_network_id >= 0 && (cli_network_id == srv_network_id))
    cli_and_srv_in_same_subnet = true;

  if(cli_network_stats) {
    if(!cli_and_srv_in_same_subnet) {
      if(src2dst_direction)
	cli_network_stats->incEgressTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
      else
	cli_network_stats->incIngressTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
    } else
      cli_network_stats->incInnerTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
  }

  if(srv_network_stats) {
    if(!cli_and_srv_in_same_subnet) {
      if(src2dst_direction)
 	srv_network_stats->incIngressTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
      else
	srv_network_stats->incEgressTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
    }
  }

  if(cli_asn != (u_int32_t)-1 && (cli_asn == srv_asn))
    cli_and_srv_in_same_as = true;

  if(!cli_and_srv_in_same_as) {
    if(cli_as) {
      if(src2dst_direction)
	cli_as->incSentTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
      else
	cli_as->incRcvdTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
    }

    if(srv_as) {
      if(src2dst_direction)
	srv_as->incRcvdTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
      else
	srv_as->incSentTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
    }
  }
}

/* *************************************** */

void Flow::updateTcpSeqNum(const struct bpf_timeval *when,
			   u_int32_t seq_num, u_int32_t ack_seq_num,
			   u_int16_t window, u_int8_t flags,
			   u_int16_t payload_Len, bool src2dst_direction) {
  u_int32_t next_seq_num;
  bool update_last_seqnum = true;
  bool debug = false;
  u_int32_t cnt_keep_alive = 0, cnt_lost = 0, cnt_ooo = 0, cnt_retx = 0;

#ifdef HAVE_NEDGE
  return;
#endif

  next_seq_num = getNextTcpSeq(flags, seq_num, payload_Len);

  if(debug)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "[act: %u][next: %u][next - act (in flight): %d][ack: %u][payload len: %u]",
				 seq_num, next_seq_num,
				 next_seq_num - seq_num,
				 ack_seq_num,
				 payload_Len);

  if(src2dst_direction) {
    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst][last: %u][next: %u]", tcp_seq_s2d.last, tcp_seq_s2d.next);

    if(window > 0) srv2cli_window = window; /* Note the window is reverted */
    if(tcp_seq_s2d.next > 0) {
      if((tcp_seq_s2d.next != seq_num) /* If equal, seq_num is the expected seq_num as determined with prev. segment */
	 && (tcp_seq_s2d.next != (seq_num - 1))) {
	if((seq_num == tcp_seq_s2d.next - 1)
	   && (payload_Len == 0 || payload_Len == 1)
	   && ((flags & (TH_SYN|TH_FIN|TH_RST)) == 0)) {
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet KeepAlive");
	  cnt_keep_alive++;
	} else if(tcp_seq_s2d.last == seq_num) {
          if (tcp_seq_s2d.next != tcp_seq_s2d.last) {
	    cnt_retx++;
	    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet retransmission");
          }
	} else if((tcp_seq_s2d.last > seq_num)
		  && (seq_num < tcp_seq_s2d.next)) {
	  cnt_lost++;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet lost [last: %u][act: %u]", tcp_seq_s2d.last, seq_num);
	} else {
	  cnt_ooo++;
	  update_last_seqnum = ((seq_num - 1) > tcp_seq_s2d.last) ? true : false;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet OOO [last: %u][act: %u]", tcp_seq_s2d.last, seq_num);
	}
      }
    }

    tcp_seq_s2d.next = next_seq_num;
    if(update_last_seqnum) tcp_seq_s2d.last = seq_num;
  } else {
    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src][last: %u][next: %u]", tcp_seq_d2s.last, tcp_seq_d2s.next);

    if(window > 0) cli2srv_window = window; /* Note the window is reverted */
    if(tcp_seq_d2s.next > 0) {
      if((tcp_seq_d2s.next != seq_num)
	 && (tcp_seq_d2s.next != (seq_num-1))) {
	if((seq_num == tcp_seq_d2s.next - 1)
	   && (payload_Len == 0 || payload_Len == 1)
	   && ((flags & (TH_SYN|TH_FIN|TH_RST)) == 0)) {
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet KeepAlive");
	  cnt_keep_alive++;
	} else if(tcp_seq_d2s.last == seq_num) {
          if (tcp_seq_d2s.next != tcp_seq_d2s.last) {
	    cnt_retx++;
	    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet retransmission");
          }
	  // bytes
	} else if((tcp_seq_d2s.last > seq_num)
		  && (seq_num < tcp_seq_d2s.next)) {
	  cnt_lost++;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet lost [last: %u][act: %u]", tcp_seq_d2s.last, seq_num);
	} else {
	  cnt_ooo++;
	  update_last_seqnum = ((seq_num - 1) > tcp_seq_d2s.last) ? true : false;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] [last: %u][next: %u]", tcp_seq_d2s.last, tcp_seq_d2s.next);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet OOO [last: %u][act: %u]", tcp_seq_d2s.last, seq_num);
	}
      }
    }

    tcp_seq_d2s.next = next_seq_num;
    if(update_last_seqnum) tcp_seq_d2s.last = seq_num;
  }

  if(cnt_keep_alive || cnt_lost || cnt_ooo || cnt_retx)
    stats.incTcpStats(src2dst_direction, cnt_retx, cnt_ooo, cnt_lost, cnt_keep_alive);
}

/* *************************************** */

u_int32_t Flow::getPid(bool client) {
  if(client && cli_ebpf && cli_ebpf->process_info_set)
    return cli_ebpf->process_info.pid;

  if(!client && srv_ebpf && srv_ebpf->process_info_set)
    return srv_ebpf->process_info.pid;

  return NO_PID;
};

/* *************************************** */

u_int32_t Flow::getFatherPid(bool client) {
  if(client && cli_ebpf && cli_ebpf->process_info_set)
    return cli_ebpf->process_info.father_pid;

  if(!client && srv_ebpf && srv_ebpf->process_info_set)
    return srv_ebpf->process_info.father_pid;

  return NO_PID;
};

/* *************************************** */

u_int32_t Flow::get_uid(bool client) const {
#ifdef WIN32
  return NO_UID;
#else
  if(client && cli_ebpf && cli_ebpf->process_info_set)
    return cli_ebpf->process_info.uid;

  if(!client && srv_ebpf && srv_ebpf->process_info_set)
    return srv_ebpf->process_info.uid;

  return NO_UID;
#endif
}

/* *************************************** */

char* Flow::get_proc_name(bool client) {
  if(client && cli_ebpf && cli_ebpf->process_info_set)
    return cli_ebpf->process_info.process_name;

  if(!client && srv_ebpf && srv_ebpf->process_info_set)
    return srv_ebpf->process_info.process_name;

  return NULL;
};

/* *************************************** */

char* Flow::get_user_name(bool client) {
  if(client && cli_ebpf && cli_ebpf->process_info_set)
    return cli_ebpf->process_info.uid_name;

  if(!client && srv_ebpf && srv_ebpf->process_info_set)
    return srv_ebpf->process_info.uid_name;

  return NULL;
}

/* *************************************** */

bool Flow::match(AddressTree *ptree) {
  if((get_cli_ip_addr() && get_cli_ip_addr()->match(ptree))
     || (get_srv_ip_addr() && get_srv_ip_addr()->match(ptree)))
    return(true);
  else
    return(false);
};

/* *************************************** */

void Flow::setBittorrentHash(char *hash) {
  int i, j, n = 0;
  char bittorrent_hash[41];

  for(i=0, j = 0; i<20; i++) {
    u_char c = hash[i] & 0xFF;
    sprintf(&bittorrent_hash[j], "%02x", c);
    j += 2, n += c;
  }

  if(n > 0) bt_hash = strdup(bittorrent_hash);
}

/* *************************************** */

void Flow::dissectBittorrent(char *payload, u_int16_t payload_len) {
  /* This dissector is called only for uTP/UDP protocol */

  if(payload_len > 47) {
    char *bt_proto = ndpi_strnstr((const char *)&payload[20],
				  "BitTorrent protocol", payload_len-20);

    if(bt_proto)
      setBittorrentHash(&bt_proto[27]);
  }
}

/* *************************************** */

void Flow::dissectDNS(bool src2dst_direction, char *payload, u_int16_t payload_len) {
  if(isDNSQuery())
    stats.incDNSQuery(getLastQueryType());
  else
    stats.incDNSResp(getDNSRetCode());
}

/* *************************************** */

void Flow::dissectHTTP(bool src2dst_direction, char *payload, u_int16_t payload_len) {
  ssize_t host_server_name_len = host_server_name && host_server_name[0] != '\0' ? strlen(host_server_name) : 0;

  if(!isThreeWayHandshakeOK())
    ; /* Useless to compute http stats as client and server could be swapped */
  else if(src2dst_direction) {
    char *space;
    dissect_next_http_packet = true;

    /* use memchr to prevent possibly non-NULL terminated HTTP requests */
    if(payload && ((space = (char*)memchr(payload, ' ', payload_len - 1)) != NULL)) {
      u_int l = space - payload;
      bool go_deeper = true;

      if(payload_len >= 2) {
	switch(payload[0]) {
	case 'P':
	  switch(payload[1]) {
	  case 'O': stats.incHTTPReqPOST();  break;
	  case 'U': stats.incHTTPReqPUT();   break;
	  default:  stats.incHTTPReqOhter(); go_deeper = false; break;
	  }
	  break;
	case 'G': stats.incHTTPReqGET();   break;
	case 'H': stats.incHTTPReqHEAD();  break;
	default:  stats.incHTTPReqOhter(); go_deeper = false; break;
	}
      } else
	go_deeper = false;

      if(go_deeper) {
	char *ua;

	if(protos.http.last_method) free(protos.http.last_method);
	if((protos.http.last_method = (char*)malloc(l + 1)) != NULL) {
	  strncpy(protos.http.last_method, payload, l);
	  protos.http.last_method[l] = '\0';
	}

	payload_len -= (l + 1);
	payload = &space[1];
	if((space = (char*)memchr(payload, ' ', payload_len)) != NULL) {
	  l = min_val(space - payload, 512); /* Avoid jumbo URLs */

	  /* Stop at the first non-printable char of the HTTP URL */
	  for(u_int i = 0; i < l; i++) {
	    if(!isprint(payload[i])) {
	      l = i;
	      break;
	    }
	  }

	  if(protos.http.last_url) free(protos.http.last_url);
	  if((protos.http.last_url = (char*)malloc(host_server_name_len + l + 1)) != NULL) {
	    protos.http.last_url[0] = '\0';

	    if(host_server_name_len > 0) {
	      strncat(protos.http.last_url, host_server_name, host_server_name_len);
	    }

	    strncat(protos.http.last_url, payload, l);
	  }
	}

	if((ua = strstr(payload, "User-Agent:")) != NULL) {
	  char buf[128];
	  u_int i;

	  ua = &ua[11];
	  while(ua[0] == ' ') ua++;

	  for(i=0; (i < payload_len) && (i < (sizeof(buf)-1) && (ua[i] != '\r')); i++)
	    buf[i] = ua[i];

	  buf[i] = '\0';

#ifdef DEBUG_UA
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "[UA] %s", buf);
#endif

	  /*
	    https://en.wikipedia.org/wiki/User_agent

	    Most Web browsers use a User-Agent string value as follows:
	    Mozilla/[version] ([system and browser information]) [platform] ([platform details]) [extensions]
	  */

	  if((ua = strchr(buf, '(')) != NULL) {
	    char *end = strchr(buf, ')');

	    if(end) {
	      /* TODO: move into nDPI */
	      end[0] = '\0';
	      ua++;

	      if(strstr(ua, "iPad") || strstr(ua, "iPod") || strstr(ua, "iPhone"))
		operating_system = os_ios;
	      else if(strstr(ua, "Android"))
		operating_system = os_android;
	      else if(strstr(ua, "Airport"))
		operating_system = os_apple_airport;
	      else if(strstr(ua, "Macintosh") || strstr(ua, "OS X"))
		operating_system = os_macos;
	      else if(strstr(ua, "Windows"))
		operating_system = os_windows;
	      else if(strcasestr(ua, "Linux") || strstr(ua, "Debian") || strstr(ua, "Ubuntu"))
		operating_system = os_linux;
	    }
	  }
	}
      }
    }
  } else {
    if(dissect_next_http_packet) {
      char *space;

      // payload[10]=0; ntop->getTrace()->traceEvent(TRACE_WARNING, "[len: %u][%s]", payload_len, payload);
      dissect_next_http_packet = false;

      if((space = (char*)memchr(payload, ' ', payload_len)) != NULL) {
	u_int l = space - payload;

	payload_len -= (l + 1);
	payload = &space[1];

	switch(payload[0]) {
	case '1': stats.incHTTPResp1xx(); break;
	case '2': stats.incHTTPResp2xx(); break;
	case '3': stats.incHTTPResp3xx(); break;
	case '4': stats.incHTTPResp4xx(); break;
	case '5': stats.incHTTPResp5xx(); break;
	}

	if((space = (char*)memchr(payload, ' ', payload_len)) != NULL) {
	  char tmp[32];
	  l = min_val(space - payload, (int)(sizeof(tmp) - 1));

	  strncpy(tmp, payload, l);
	  tmp[l] = 0;
	  protos.http.last_return_code = atoi(tmp);
	}
      }

      // Detect content type in response header
      char buf[sizeof(HTTP_CONTENT_TYPE_HEADER) + HTTP_MAX_CONTENT_TYPE_LENGTH];
      const char * s = payload;
      size_t len = payload_len;

      for (int i=0; i<HTTP_MAX_HEADER_LINES && len > 2; i++) {
	const char * newline = (const char *) memchr(s, '\n', len);

	if((!newline) || (newline - s < 2) || (*(newline - 1) != '\r')) break;

	size_t linesize = newline - s + 1;
	const char * terminator = (const char *) memchr(s, ';', linesize);
	size_t effsize = terminator ? (terminator - s) : (linesize - 2);

	if(effsize < sizeof(buf)) {
	  strncpy(buf, s, effsize);
	  buf[effsize] = '\0';

	  if(strstr(buf, HTTP_CONTENT_TYPE_HEADER) == buf) {
	    const char * ct = buf + sizeof(HTTP_CONTENT_TYPE_HEADER) - 1;

	    if(protos.http.last_content_type) free(protos.http.last_content_type);
	    protos.http.last_content_type = strdup(ct);
	    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "LAST CONTENT TYPE: '%s'", protos.http.last_content_type);
	    break;
	  }
	}

	len -= linesize;
	s = newline + 1;
      }
    }
  }
}

/* *************************************** */

void Flow::dissectMDNS(u_int8_t *payload, u_int16_t payload_len) {
  u_int16_t answers, i = 0;

  PACK_ON
    struct mdns_rsp_entry {
    u_int16_t rsp_type, rsp_class;
    u_int32_t ttl;
    u_int16_t data_len;
  } PACK_OFF;

  if(((payload[2] & 0x80) != 0x80) || (payload_len < 12))
    return; /* This is a not MDNS response */

  answers = ntohs(*((u_int16_t*)&payload[6]))
    + ntohs(*((u_int16_t*)&payload[8]))
    + ntohs(*((u_int16_t*)&payload[10]));

  payload = &payload[12], payload_len -= 12;

  while((answers > 0) && (i < payload_len)) {
    char _name[256], *name;
    struct mdns_rsp_entry rsp;
    u_int j;
    u_int16_t rsp_type, data_len;
    DeviceType dtype = device_unknown;

    memset(_name, 0, sizeof(_name));

    for(j=0; (i < payload_len) && (j < (sizeof(_name)-1)); i++) {
      if(payload[i] == 0x0) {
	i++;
	break;
      } else if(payload[i] < 32) {
	if(j > 0) _name[j++] = '.';
      } else if(payload[i] == 0x22) {
	_name[j++] = 'a';
	_name[j++] = 'r';
	_name[j++] = 'p';
	_name[j++] = 'a';
	i++;
	break;
      } else if(payload[i] == 0xC0) {
	u_int8_t offset;
	u_int16_t i_save = i;
	u_int8_t num_loops = 0;
	const u_int8_t max_nested_loops = 8;

      nested_dns_definition:
	offset = payload[i+1] - 12;
	i = offset;

	if((offset > i)|| (i > payload_len) || (num_loops > max_nested_loops)) {
#ifdef DEBUG_DISCOVERY
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid MDNS packet");
#endif
	  return; /* Invalid packet */
	} else {
	  /* Pointer back */
	  while((i < payload_len)
		&& (payload[i] != 0)
		&& (j < (sizeof(_name)-1))) {
	    if(payload[i] == 0)
	      break;
	    else if(payload[i] == 0xC0) {
	      num_loops++;
	      goto nested_dns_definition;
	    } else if(payload[i] < 32) {
	      if(j > 0)	_name[j++] = '.';
	      i++;
	    } else
	      _name[j++] = payload[i++];
	  }

	  if(i_save > 0) {
	    i = i_save;
	    i_save = 0;
	  }

	  i += 2;
	  /*  ntop->getTrace()->traceEvent(TRACE_NORMAL, "===>>> [%d] %s", i, &payload[i-12]); */
	  break;
	}
      } else
	_name[j++] = payload[i];
    }

    memcpy(&rsp, &payload[i], sizeof(rsp));
    data_len = ntohs(rsp.data_len), rsp_type = ntohs(rsp.rsp_type);

    /* Skip lenght for strings >= 32 with head length */
    name = &_name[((data_len <= 32) || (_name[0] >= '0'))? 0 : 1];

#ifdef DEBUG_DISCOVERY
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "===>>> [%u][%s][len=%u]", ntohs(rsp.rsp_type) & 0xFFFF, name, data_len);
#endif

    if(strstr(name, "._device-info._"))
      ;
    else if(strstr(name, "._airplay._") || strstr(name, "._spotify-connect._") )
      dtype = device_multimedia;
    else if(strstr(name, "_ssh._"))
      dtype = device_workstation;
    else if(strstr(name, "._daap._")
	    || strstr(name, "_afpovertcp._")
	    || strstr(name, "_adisk._")
	    || strstr(name, "_smb._")
      )
      dtype = device_nas;
    else if(strstr(name, "_hap._"))
      dtype = device_iot;
    else if(strstr(name, "_pdl-datastream._"))
      dtype = device_printer;

    if((dtype != device_unknown) && cli_host && cli_host->getMac()) {
      Mac *m = cli_host->getMac();

      if(m->getDeviceType() == device_unknown)
	m->setDeviceType(dtype);
    }

    switch(rsp_type) {
    case 0x1C: /* AAAA */
    case 0x01: /* AA */
    case 0x10: /* TXT */
      {
	int len = strlen(name);
	char *c;

	if((len > 6) && (strcmp(&name[len-6], ".local") == 0))
	  name[len-6] = 0;

	c = strstr(name, "._");
	if(c && (c != name) /* Does not begin with... */)
	  c[0] = '\0';
      }

      if(!protos.mdns.name) protos.mdns.name = strdup(name);

      if((rsp_type == 0x10 /* TXT */) && (data_len > 0)) {
	char *txt = (char*)&payload[i+sizeof(rsp)], txt_buf[256];
	u_int16_t off = 0;

	while(off < data_len) {
	  u_int8_t txt_len = (u_int8_t)txt[off];

	  if(txt_len < data_len) {
	    txt_len = min_val(data_len-off, txt_len);

	    off++;

	    if(txt_len > 0) {
	      char *model = NULL;

	      strncpy(txt_buf, &txt[off], txt_len);
	      txt_buf[txt_len] = '\0';
	      off += txt_len;

#ifdef DEBUG_DISCOVERY
	      ntop->getTrace()->traceEvent(TRACE_NORMAL, "===>>> [TXT][%s]", txt_buf);
#endif

	      if(strncmp(txt_buf, "am=", 3 /* Apple Model */) == 0) model = &txt_buf[3];
	      else if(strncmp(txt_buf, "model=", 6) == 0)           model = &txt_buf[6];
	      else if(strncmp(txt_buf, "md=", 3) == 0)              model = &txt_buf[3];

	      if(model && cli_host) {
		Mac *mac = cli_host->getMac();

		if(mac) {
		    mac->inlineSetModel(model);
		}
	      }

	      if(strncmp(txt_buf, "nm=", 3) == 0)
		if(!protos.mdns.name_txt) protos.mdns.name_txt = strdup(&txt_buf[3]);

	      if(strncmp(txt_buf, "ssid=", 5) == 0) {
		if(!protos.mdns.ssid) protos.mdns.ssid = strdup(&txt_buf[5]);

		if(cli_host && cli_host->getMac())
		  cli_host->getMac()->inlineSetSSID(&txt_buf[5]);
	      }
	    }
	  } else
	    break;
	}
      }

#ifdef DEBUG_DISCOVERY
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u) %u [%s]", answers, rsp_type, name);
#endif
      //return; /* It's enough to decode the first name */
    }

    i += sizeof(rsp) + data_len, answers--;
  }
}

/* *************************************** */

void Flow::dissectSSDP(bool src2dst_direction, char *payload, u_int16_t payload_len) {
  char url[512];
  u_int i = 0;

  if(payload_len < 6 /* NOTIFY */) return;

  if(strncmp(payload, "NOTIFY", 6) == 0) {
    payload += 6, payload_len -= 6;

    for(; 0 < payload_len - 9 /* strlen("Location:") */; payload++, payload_len--) {
      if(strncasecmp(payload, "Location:", 9)) {
	continue;
      } else {
	payload += 9, payload_len -= 9;

	for(; (payload_len > 0)
	      && (payload[0] != '\n')
	      && (payload[0] != '\r'); payload++, payload_len--) {
	  if(*payload == ' ')       continue;
	  if(i == sizeof(url) - 1)  break;
	  url[i++] = *payload;
	}

	url[i] = '\0';
	// ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SSDP URL:] %s", url);
	if(!protos.ssdp.location) protos.ssdp.location = strdup(url);
	break;
      }
    }
  }
}

/* *************************************** */

void Flow::dissectNetBIOS(u_int8_t *payload, u_int16_t payload_len) {
  char name[64];

  if(((payload[2] & 0x80) /* NetBIOS Response */ || ((payload[2] & 0x78) == 0x28 /* NetBIOS Registration */))
     && (ndpi_netbios_name_interpret((char*)&payload[12], name, sizeof(name)) > 0)
     && (!strstr(name, "__MSBROWSE__"))
     ) {

    if(name[0] == '*') {
      int limit = min_val(payload_len-57, (int)sizeof(name)-1);
      int i = 0;

      while((i<limit) && (payload[57+i] != 0x20) && isprint(payload[57+i])) {
	name[i] = payload[57+i];
	i++;
      }

      if((i<limit) && (payload[57+i] != 0x00 /* Not a Workstation/Redirector */))
	name[0] = '\0'; /* ignore */
      else
	name[i] = '\0';
    }
#if 0
    char buf[32];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting hostname from NetBios [raw=0x%x opcode=0x%x response=0x%x]: ip=%s -> '%s'",
				 payload[2], (payload[2] & 0x78) >> 3, (payload[2] & 0x80) >> 7,
				 (*srcHost)->get_ip()->print(buf, sizeof(buf)), name);
#endif

    if(name[0])
      protos.netbios.name = strdup(name);
  }
}

/* *************************************** */

#ifdef HAVE_NEDGE

bool Flow::isPassVerdict() const {
  if(!passVerdict)
    return(false);

  if(cli_host && srv_host)
    return((!quota_exceeded)
	   && (!(cli_host->dropAllTraffic() || srv_host->dropAllTraffic()))
	   && (!isBlacklistedFlow()));
  else
    return(true);
}

/* *************************************** */

bool Flow::checkPassVerdict(const struct tm *now) {
  if(!passVerdict)
    return(false);

  if(!isDetectionCompleted())
    return(true); /* Always pass until detection is completed */

  recheckQuota(now);
  return isPassVerdict();
}

#endif

/* *************************************** */

#ifdef HAVE_NEDGE

bool Flow::updateDirectionShapers(bool src2dst_direction, TrafficShaper **ingress_shaper, TrafficShaper **egress_shaper) {
  bool verdict = true;

  if(cli_host && srv_host) {
    if(src2dst_direction) {
      *ingress_shaper = srv_host->get_ingress_shaper(ndpiDetectedProtocol),
	*egress_shaper = cli_host->get_egress_shaper(ndpiDetectedProtocol);

      if(*ingress_shaper) srv2cli_in = (*ingress_shaper)->get_shaper_id();
      if(*egress_shaper) cli2srv_out = (*egress_shaper)->get_shaper_id();

    } else {
      *ingress_shaper = cli_host->get_ingress_shaper(ndpiDetectedProtocol),
	*egress_shaper = srv_host->get_egress_shaper(ndpiDetectedProtocol);

      if(*ingress_shaper) cli2srv_in = (*ingress_shaper)->get_shaper_id();
      if(*egress_shaper) srv2cli_out = (*egress_shaper)->get_shaper_id();
    }

    if((*ingress_shaper && (*ingress_shaper)->shaping_enabled() && (*ingress_shaper)->get_max_rate_kbit_sec() == 0)
	|| (*egress_shaper && (*egress_shaper)->shaping_enabled() && (*egress_shaper)->get_max_rate_kbit_sec() == 0))
      verdict = false;
  } else
    *ingress_shaper = *egress_shaper = NULL;

  return verdict;
}

/* *************************************** */

void Flow::updateFlowShapers(bool first_update) {
  bool cli2srv_verdict, srv2cli_verdict;
  bool old_verdict = passVerdict;
  bool new_verdict;
  u_int16_t old_cli2srv_in = cli2srv_in,
    old_cli2srv_out = cli2srv_out,
    old_srv2cli_in = srv2cli_in,
    old_srv2cli_out = srv2cli_out;

  /* Re-compute the verdict */
  cli2srv_verdict = updateDirectionShapers(true, &flowShaperIds.cli2srv.ingress, &flowShaperIds.cli2srv.egress);
  srv2cli_verdict = updateDirectionShapers(false, &flowShaperIds.srv2cli.ingress, &flowShaperIds.srv2cli.egress);
  new_verdict = (cli2srv_verdict && srv2cli_verdict);

  if(ntop->getPrefs()->are_device_protocol_policies_enabled() && cli_host && srv_host && new_verdict) {
    /* NOTE: this must be handled differently to only consider actual peers direction */
    if((cli_host->getDeviceAllowedProtocolStatus(ndpiDetectedProtocol, true /* client */) != device_proto_allowed) ||
       (srv_host->getDeviceAllowedProtocolStatus(ndpiDetectedProtocol, false /* server */) != device_proto_allowed))
      new_verdict = false;
  }

  /* Set the new verdict */
  passVerdict = new_verdict;

  if((!first_update) && (iface->getIfType() == interface_type_NETFILTER) &&
           (((old_verdict != passVerdict)) ||
            (old_cli2srv_in != cli2srv_in) ||
            (old_cli2srv_out != cli2srv_out) ||
            (old_srv2cli_in != srv2cli_in) ||
            (old_srv2cli_out != srv2cli_out)))
   ((NetfilterInterface *) iface)->setPolicyChanged();

#ifdef SHAPER_DEBUG
  {
    char buf[1024];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SHAPERS] %s", print(buf, sizeof(buf)));
  }
#endif
}

/* *************************************** */

void Flow::recheckQuota(const struct tm *now) {
  bool above_quota = false;

  if(cli_host && srv_host) {
    L7PolicySource_t cli_src, srv_src;

    if((above_quota = cli_host->checkQuota(ndpiDetectedProtocol, &cli_src, now)))
      srv_src = policy_source_default;
    else if((above_quota = srv_host->checkQuota(ndpiDetectedProtocol, &srv_src, now)))
      ;

    /* Use temporary values to guard against partial changes */
    cli_quota_source = cli_src, srv_quota_source = srv_src;
  }

  quota_exceeded = above_quota;
}

#endif

/* ***************************************************** */

bool Flow::isTiny() const {
  //if((cli2srv_packets < 3) && (srv2cli_packets == 0))
  if((get_packets() <= ntop->getPrefs()->get_max_num_packets_per_tiny_flow())
     || (get_bytes() <= ntop->getPrefs()->get_max_num_bytes_per_tiny_flow()))
    return(true);
  else
    return(false);
}

/* ***************************************************** */

#ifdef HAVE_NEDGE
void Flow::setPacketsBytes(time_t now, u_int32_t s2d_pkts, u_int32_t d2s_pkts,
			   u_int64_t s2d_bytes, u_int64_t d2s_bytes) {
  u_int16_t eth_proto = ETHERTYPE_IP;
  u_int overhead = 0;
  bool nf_existing_flow;

  /* netfilter (depending on configured timeouts) could expire a flow before than
     ntopng. This heuristics attempt to detect such events.

     Basically, if netfilter is sending counters for a new flow and ntopng
     already have an existing flow matching the same 5-tuple, we sum counters
     rather than overwriting them.

     A complete solution would require the registration of a netfilter callback
     and the detection of event NFCT_T_DESTROY.
  */
  nf_existing_flow = !(get_packets_cli2srv() > s2d_pkts || get_bytes_cli2srv() > s2d_bytes
		       || get_packets_srv2cli() > d2s_pkts || get_bytes_srv2cli() > d2s_bytes);

  updateSeen();

  /*
     We need to set last_conntrack_update even with 0 packtes/bytes
     as this function has been called only within netfilter through
     the conntrack handler, and thus the flow is still alive.
  */
  last_conntrack_update = now;

  iface->_incStats(isIngress2EgressDirection(), now, eth_proto,
		   getStatsProtocol(), get_protocol_category(),
		   protocol,
		   nf_existing_flow ? s2d_bytes - get_bytes_cli2srv() : s2d_bytes,
		   nf_existing_flow ? s2d_pkts - get_packets_cli2srv() : s2d_pkts,
		   overhead);

  iface->_incStats(!isIngress2EgressDirection(), now, eth_proto,
		   getStatsProtocol(), get_protocol_category(),
		   protocol,
		   nf_existing_flow ? d2s_bytes - get_bytes_srv2cli() : d2s_bytes,
		   nf_existing_flow ? d2s_pkts - get_packets_srv2cli() : d2s_pkts,
		   overhead);

  if(nf_existing_flow) {
    stats.setStats(true, s2d_pkts, s2d_bytes, 0);
    stats.setStats(false, d2s_pkts, d2s_bytes, 0);
  } else {
    stats.incStats(true, s2d_pkts, s2d_bytes, 0);
    stats.incStats(false, d2s_pkts, d2s_bytes, 0);
  }
}
#endif

/* ***************************************************** */

void Flow::setParsedeBPFInfo(const ParsedeBPF * const ebpf, bool src2dst_direction) {
  bool client_process = true;
  ParsedeBPF *cur = NULL;
  bool update_ok = true;

  if(!ebpf)
    return;

  if(!iface->hasSeenEBPFEvents())
    iface->setSeenEBPFEvents();

  if(ebpf->isServerInfo())
    client_process = false;

  if(!src2dst_direction)
    client_process = !client_process;

  if(client_process) {
    if(!cli_ebpf)
      cur = cli_ebpf = new (std::nothrow) ParsedeBPF(*ebpf);
    else
      update_ok = cli_ebpf->update(ebpf);
  } else { /* server_process */
    if(!srv_ebpf)
      cur = srv_ebpf = new (std::nothrow) ParsedeBPF(*ebpf);
    else
      update_ok = srv_ebpf->update(ebpf);
  }

  if(!update_ok) {
    static bool warning_shown = false;
    char *fbuf;
    ssize_t fbuf_len = 512;

    if(!warning_shown && (fbuf = (char*)malloc(fbuf_len))) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Identical flow seen across multiple containers? %s",
				   print(fbuf, fbuf_len));

      warning_shown = true;
      free(fbuf);
    }
  }

  if(cur && cur->container_info_set) {
    if(!iface->hasSeenContainers())
      iface->setSeenContainers();

    if(cur->container_info.data_type == container_info_data_type_k8s
       && !iface->hasSeenPods()
       && cur->container_info.data.k8s.pod)
      iface->setSeenPods();
  }

  updateCliJA3();
  updateSrvJA3();
  updateHASSH(true /* AS client */);
  updateHASSH(false /* AS server */);
}

/* ***************************************************** */

void Flow::updateCliJA3() {
  if(cli_host && isTLS() && protos.tls.ja3.client_hash) {
    cli_host->getJA3Fingerprint()->update(protos.tls.ja3.client_hash,
					  cli_ebpf ? cli_ebpf->process_info.process_name : NULL);

    has_malicious_cli_signature |= ntop->isMaliciousJA3Hash(protos.tls.ja3.client_hash);
  }
}

/* ***************************************************** */

void Flow::updateSrvJA3() {
  if(srv_host && isTLS() && protos.tls.ja3.server_hash) {
    srv_host->getJA3Fingerprint()->update(protos.tls.ja3.server_hash,
					  srv_ebpf ? srv_ebpf->process_info.process_name : NULL);

    has_malicious_srv_signature |= ntop->isMaliciousJA3Hash(protos.tls.ja3.server_hash);
  }
}

/* ***************************************************** */

void Flow::updateHASSH(bool as_client) {
  if(!isSSH())
    return;

  Host *h = as_client ? get_cli_host() : get_srv_host();
  const char *hassh = as_client ? protos.ssh.hassh.client_hash : protos.ssh.hassh.server_hash;
  ParsedeBPF *pebpf = as_client ? cli_ebpf : srv_ebpf;
  Fingerprint *fp;

  if(h && hassh && hassh[0] != '\0' && (fp = h->getHASSHFingerprint()))
    fp->update(hassh, pebpf ? pebpf->process_info.process_name : NULL);
}

/* ***************************************************** */

/* Called when a flow is set_idle */
void Flow::postFlowSetIdle(const struct timeval *tv, bool quick) {
  if(status_map.get() != status_normal) {
#if 0
    char buf[256];
    printf("%s status=%d\n", print(buf, sizeof(buf)), status);
#endif

    if(cli_host) cli_host->incNumAnomalousFlows(true);
    if(srv_host) srv_host->incNumAnomalousFlows(false);
  }

  if(isFlowAlerted()) {
    if(cli_host) cli_host->decNumAlertedFlows();
    if(srv_host) srv_host->decNumAlertedFlows();
  }
}

/* ***************************************************** */

void Flow::fillZmqFlowCategory() {
  struct ndpi_detection_module_struct *ndpi_struct = iface->get_ndpi_struct();
  char *srv_name = getFlowServerInfo();
  const IpAddress *cli_ip = get_cli_ip_addr(), *srv_ip = get_srv_ip_addr();

  if(!cli_ip || !srv_ip)
    return;

  if(cli_ip->isIPv4()) {
    if(ndpi_fill_ip_protocol_category(ndpi_struct, cli_ip->get_ipv4(), srv_ip->get_ipv4(), &ndpiDetectedProtocol))
      return;
  }

  if(srv_name && srv_name[0]) {
    unsigned long id;

    if(ndpi_match_custom_category(ndpi_struct, srv_name, strlen(srv_name), &id) == 0) {
      ndpiDetectedProtocol.category = (ndpi_protocol_category_t)id;
      return;
    }
  }
}

/* ***************************************************** */

void Flow::dissectTLS(char *payload, u_int16_t payload_len) {
  if(protos.tls.dissect_certificate) {
    u_int16_t _payload_len = payload_len + protos.tls.certificate_leftover;
    u_char *_payload       = (u_char*)malloc(_payload_len);
    bool find_initial_pattern = true;

    if(!_payload)
      return;
    else {
      int i = 0;

      if(protos.tls.certificate_leftover > 0) {
	memcpy(_payload, protos.tls.certificate_buf_leftover, (i = protos.tls.certificate_leftover));
	free(protos.tls.certificate_buf_leftover);
	protos.tls.certificate_buf_leftover = NULL, protos.tls.certificate_leftover = 0;
	find_initial_pattern = false;
      }

      memcpy(&_payload[i], payload, payload_len);
    }

    if(_payload_len > 4) {
      for(int i = (find_initial_pattern ? 9 : 0); i < _payload_len - 4 && protos.tls.dissect_certificate; i++) {

	/* Look for the Subject Alternative Name Extension with OID 55 1D 11 */
	if((find_initial_pattern && (_payload[i] == 0x55) && (_payload[i+1] == 0x1d) && (_payload[i+2] == 0x11))
	   || (!find_initial_pattern)) {

	  if(find_initial_pattern) {
	    i += 3 /* skip the initial patten 55 1D 11 */;
	    i++; /* skip the first type, 0x04 == BIT STRING, and jump to it's length */
	    i += _payload[i] & 0x80 ? _payload[i] & 0x7F : 0; /* skip BIT STRING length */
	    i += 2; /* skip the second type, 0x30 == SEQUENCE, and jump to it's length */
	    i += _payload[i] & 0x80 ? _payload[i] & 0x7F : 0; /* skip SEQUENCE length */
	    i++;
	  }

	  while(i < _payload_len) {
	    if(_payload[i] == 0x82) {
	      u_int8_t len;

	      if((i < (_payload_len - 1))
		 && (len = _payload[i + 1])
		 && ((i + len + 2) < _payload_len)) {
		i += 2;

		if(!isalpha(_payload[i]) && _payload[i] != '*') {
		  protos.tls.dissect_certificate = false;
		  break;
		}
		else {
		  char buf[256];

		  strncpy(buf, (const char*)&_payload[i], len);
		  buf[len] = '\0';

#if 0
		  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [Len %u][sizeof(buf): %u][tls cert: %s]", buf, len, sizeof(buf), getTLSCertificate());
#endif

		  /*
		    CNs are NOT case sensitive as per RFC 5280
		  */
		  if (protos.tls.certificate
		      && ((buf[0] != '*' && !strncasecmp(protos.tls.certificate, buf, sizeof(buf)))
			  || (buf[0] == '*' && strcasestr(protos.tls.certificate, &buf[1])))) {
		    protos.tls.subject_alt_name_match = true;
		    protos.tls.dissect_certificate = false;
		    break;
		  }

		  i += len;
		}
	      } else {
#if 0
		ntop->getTrace()->traceEvent(TRACE_NORMAL, "Leftover %u bytes [%u len]", _payload_len - i, len);
#endif
		protos.tls.certificate_leftover = _payload_len - i;

		if((protos.tls.certificate_buf_leftover = (char*)malloc(protos.tls.certificate_leftover)) != NULL)
		  memcpy(protos.tls.certificate_buf_leftover, &_payload[i], protos.tls.certificate_leftover);
		else
		  protos.tls.certificate_leftover = 0;

		break;
	      }
	    } else {
	      protos.tls.dissect_certificate = false;
	      break;
	    }
	  } /* while */
	}
      } /* for */
    }

    free(_payload);
  }
}

/* ***************************************************** */

void Flow::lua_get_status(lua_State* vm) const {
  lua_push_bool_table_entry(vm, "flow.idle", idle());
  lua_push_uint64_table_entry(vm, "flow.status", getPredominantStatus());
  lua_push_uint64_table_entry(vm, "status_map", status_map.get());

  if(is_alerted) {
    lua_push_bool_table_entry(vm, "flow.alerted", true);
    lua_push_uint64_table_entry(vm, "alerted_status", alerted_status);
  }
}

/* ***************************************************** */

void Flow::lua_get_protocols(lua_State* vm) const {
  char buf[64];

  lua_push_uint64_table_entry(vm, "proto.l4_id", get_protocol());
  lua_push_str_table_entry(vm, "proto.l4", get_protocol_name());

  if(((get_packets_cli2srv() + get_packets_srv2cli()) > NDPI_MIN_NUM_PACKETS)
     || (ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN)
     || iface->is_ndpi_enabled()
     || iface->isSampledTraffic()
     || (iface->getIfType() == interface_type_ZMQ)
     || (iface->getIfType() == interface_type_SYSLOG)
     || (iface->getIfType() == interface_type_ZC_FLOW)) {
    lua_push_str_table_entry(vm, "proto.ndpi", get_detected_protocol_name(buf, sizeof(buf)));
  } else
    lua_push_str_table_entry(vm, "proto.ndpi", (char*)CONST_TOO_EARLY);

  lua_push_uint64_table_entry(vm, "proto.ndpi_id", ndpiDetectedProtocol.app_protocol);
  lua_push_uint64_table_entry(vm, "proto.master_ndpi_id", ndpiDetectedProtocol.master_protocol);
  lua_push_str_table_entry(vm, "proto.ndpi_breed", get_protocol_breed_name());

  lua_push_uint64_table_entry(vm, "proto.ndpi_cat_id", get_protocol_category());
  lua_push_str_table_entry(vm, "proto.ndpi_cat", get_protocol_category_name());
}

/* ***************************************************** */

void Flow::lua_get_bytes(lua_State* vm) const {
  lua_push_uint64_table_entry(vm, "bytes", get_bytes_cli2srv() + get_bytes_srv2cli());
  lua_push_uint64_table_entry(vm, "goodput_bytes", get_goodput_bytes_cli2srv() + get_goodput_bytes_srv2cli());
  lua_push_uint64_table_entry(vm, "bytes.last",
			      get_current_bytes_cli2srv() + get_current_bytes_srv2cli());
  lua_push_uint64_table_entry(vm, "goodput_bytes.last",
			      get_current_goodput_bytes_cli2srv() + get_current_goodput_bytes_srv2cli());
}

/* ***************************************************** */

void Flow::lua_get_throughput(lua_State* vm) const {  
  // overall throughput stats
  lua_push_float_table_entry(vm,  "top_throughput_bps",   top_bytes_thpt);
  lua_push_float_table_entry(vm,  "throughput_bps",       bytes_thpt);
  lua_push_uint64_table_entry(vm, "throughput_trend_bps", bytes_thpt_trend);
  lua_push_float_table_entry(vm,  "top_throughput_pps",   top_pkts_thpt);
  lua_push_float_table_entry(vm,  "throughput_pps",       pkts_thpt);
  lua_push_uint64_table_entry(vm, "throughput_trend_pps", pkts_thpt_trend);

  // throughput stats cli2srv and srv2cli breakdown
  lua_push_float_table_entry(vm, "throughput_cli2srv_bps", bytes_thpt_cli2srv);
  lua_push_float_table_entry(vm, "throughput_srv2cli_bps", bytes_thpt_srv2cli);
  lua_push_float_table_entry(vm, "throughput_cli2srv_pps", pkts_thpt_cli2srv);
  lua_push_float_table_entry(vm, "throughput_srv2cli_pps", pkts_thpt_srv2cli);
}

/* ***************************************************** */

void Flow::lua_get_dir_traffic(lua_State* vm, bool cli2srv) const {
  ndpi_analyze_struct *cur_analyze = (ndpi_analyze_struct*)stats.get_analize_struct(cli2srv);
  const IPPacketStats *cur_ip_stats = cli2srv ? &ip_stats_s2d : &ip_stats_d2s;

  lua_push_uint64_table_entry(vm,
			      cli2srv ? "cli2srv.bytes" : "srv2cli.bytes",
			      cli2srv ? get_bytes_cli2srv() : get_bytes_srv2cli());
  lua_push_uint64_table_entry(vm,
			      cli2srv ? "cli2srv.goodput_bytes" : "srv2cli.goodput_bytes",
			      cli2srv ? get_goodput_bytes_cli2srv() : get_goodput_bytes_srv2cli());
  lua_push_uint64_table_entry(vm, cli2srv ? "cli2srv.packets" : "srv2cli.packets",
			      cli2srv ? get_packets_cli2srv() : get_packets_srv2cli());

  lua_push_uint64_table_entry(vm,
			      cli2srv ? "cli2srv.last" : "srv2cli.last",
			      cli2srv ? get_current_bytes_cli2srv() : get_current_bytes_srv2cli());

  lua_push_uint64_table_entry(vm, cli2srv ? "cli2srv.pkt_len.min" : "srv2cli.pkt_len.min", ndpi_data_min(cur_analyze));
  lua_push_uint64_table_entry(vm, cli2srv ? "cli2srv.pkt_len.max" : "srv2cli.pkt_len.max", ndpi_data_max(cur_analyze));
  lua_push_uint64_table_entry(vm, cli2srv ? "cli2srv.pkt_len.avg" : "srv2cli.pkt_len.avg", ndpi_data_average(cur_analyze));
  lua_push_uint64_table_entry(vm, cli2srv ? "cli2srv.pkt_len.stddev" : "srv2cli.pkt_len.stddev", ndpi_data_stddev(cur_analyze));

  lua_push_uint64_table_entry(vm, cli2srv ? "cli2srv.fragments" : "srv2cli.fragments", cur_ip_stats->pktFrag);
}

/* ***************************************************** */

void Flow::lua_get_dir_iat(lua_State* vm, bool cli2srv) const {
  InterarrivalStats *s = cli2srv ? getCli2SrvIATStats() : getSrv2CliIATStats();

  if(s) {
    lua_newtable(vm);

    lua_push_uint64_table_entry(vm, "min",   s->getMin());
    lua_push_uint64_table_entry(vm, "max",   s->getMax());
    lua_push_float_table_entry(vm, "avg",    s->getAvg());
    lua_push_float_table_entry(vm, "stddev", s->getStdDev());

    lua_pushstring(vm, cli2srv ? "interarrival.cli2srv" : "interarrival.srv2cli");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* ***************************************************** */

void Flow::lua_get_packets(lua_State* vm) const {  
  lua_push_uint64_table_entry(vm, "packets", get_packets_cli2srv() + get_packets_srv2cli());
  lua_push_uint64_table_entry(vm, "packets.sent", get_packets_cli2srv());
  lua_push_uint64_table_entry(vm, "packets.rcvd", get_packets_srv2cli());
  lua_push_uint64_table_entry(vm, "packets.last",
			      get_current_packets_cli2srv() + get_current_packets_srv2cli());
}

/* ***************************************************** */

void Flow::lua_get_time(lua_State* vm) const {
  lua_push_uint64_table_entry(vm, "seen.first", get_first_seen());
  lua_push_uint64_table_entry(vm, "seen.last", get_last_seen());
  lua_push_uint64_table_entry(vm, "duration", get_duration());
}

/* ***************************************************** */

void Flow::lua_get_ip(lua_State *vm, bool client) const {
  char buf[64];
  Host *h = client ? get_cli_host() : get_srv_host();
  const IpAddress *h_ip = client ? get_cli_ip_addr() :  get_srv_ip_addr();
  bool mask_host = true;

  if(h) {
    mask_host = Utils::maskHost(h->isLocalHost());

    lua_push_str_table_entry(vm, client ? "cli.ip" : "srv.ip",
			     h->get_ip()->printMask(buf, sizeof(buf),
						    h->isLocalHost()));

    lua_push_uint64_table_entry(vm, client ? "cli.key" : "srv.key", mask_host ? 0 : h->key());
  } else if(h_ip) {
    /* Host hasn't been instantiated but we still have the ip address (e.g, in viewed interfaces) */
    lua_push_str_table_entry(vm, client ? "cli.ip" : "srv.ip", h_ip->print(buf, sizeof(buf)));
    lua_push_uint64_table_entry(vm, client ? "cli.key" : "srv.key", h_ip->key());
  }

  if(get_vlan_id())
    lua_push_uint64_table_entry(vm, client ? "cli.vlan" : "srv.vlan", get_vlan_id());

  lua_push_bool_table_entry(vm, client ? "cli.broadmulticast" : "srv.broadmulticast", h_ip->isBroadMulticastAddress());
}

/* ***************************************************** */

void Flow::lua_get_info(lua_State *vm, bool client) const {
  char buf[64];
  Host *h = client ? get_cli_host() : get_srv_host();
  const IpAddress *h_ip = client ? get_cli_ip_addr() :  get_srv_ip_addr();
  bool mask_host = true;

  if(h) {
    mask_host = Utils::maskHost(h->isLocalHost());

    if(!mask_host) {
      char cb[64], os[64];
      lua_push_str_table_entry(vm, client ? "cli.host" : "srv.host", h->get_visual_name(buf, sizeof(buf)));
      lua_push_uint64_table_entry(vm, client ? "cli.source_id" : "srv.source_id", 0 /* was never set by src->getSourceId()*/ );
      lua_push_str_table_entry(vm, client ? "cli.mac" : "srv.mac", Utils::formatMac(h->get_mac(), buf, sizeof(buf)));
      lua_push_bool_table_entry(vm, client ? "cli.localhost" : "srv.localhost", h->isLocalHost());
      lua_push_bool_table_entry(vm, client ? "cli.systemhost" : "srv.systemhost", h->isSystemHost());
      lua_push_bool_table_entry(vm, client ? "cli.blacklisted" : "srv.blacklisted", h->isBlacklisted());
      lua_push_int32_table_entry(vm, client ? "cli.network_id" : "srv.network_id", h->get_local_network_id());
      lua_push_uint64_table_entry(vm, client ? "cli.pool_id" : "srv.pool_id", h->get_host_pool());
      lua_push_uint64_table_entry(vm, client ? "cli.asn" : "srv.asn", h->get_asn());
      lua_push_str_table_entry(vm, client ? "cli.country" : "srv.country", h->get_country(cb, sizeof(cb)));
      lua_push_str_table_entry(vm, client ? "cli.os" : "srv.os", h->getOSDetail(os, sizeof(os)));
    }
  }

  if(h_ip)
    lua_push_bool_table_entry(vm, client ? "cli.private" : "srv.private", h_ip->isPrivateAddress());
}

/* ***************************************************** */

/* Get minimal flow information.
 * NOTE: this is intended to be called only from flow user scripts
 * via flow.getInfo(). mask_host/allowed networks are not honored.
 */
void Flow::lua_get_min_info(lua_State *vm) {
  const IpAddress *cli_ip = get_cli_ip_addr();
  const IpAddress *srv_ip = get_srv_ip_addr();
  char buf[32];

  lua_newtable(vm);

  if(cli_ip) lua_push_str_table_entry(vm, "cli.ip", cli_ip->print(buf, sizeof(buf)));
  if(srv_ip) lua_push_str_table_entry(vm, "srv.ip", srv_ip->print(buf, sizeof(buf)));
  lua_push_int32_table_entry(vm, "cli.port", get_cli_port());
  lua_push_int32_table_entry(vm, "srv.port", get_srv_port());
  lua_push_bool_table_entry(vm, "cli.localhost", cli_host ? cli_host->isLocalHost() : false);
  lua_push_bool_table_entry(vm, "srv.localhost", srv_host ? srv_host->isLocalHost() : false);
  lua_push_int32_table_entry(vm, "duration", get_duration());
  lua_push_str_table_entry(vm, "proto.l4", get_protocol_name());
  lua_push_str_table_entry(vm, "proto.ndpi", get_detected_protocol_name(buf, sizeof(buf)));
  lua_push_str_table_entry(vm, "proto.ndpi_app", ndpi_get_proto_name(iface->get_ndpi_struct(), ndpiDetectedProtocol.app_protocol));
  lua_push_str_table_entry(vm, "proto.ndpi_cat", get_protocol_category_name());
  lua_push_uint64_table_entry(vm, "cli2srv.bytes", get_bytes_cli2srv());
  lua_push_uint64_table_entry(vm, "srv2cli.bytes", get_bytes_srv2cli());
  lua_push_uint64_table_entry(vm, "cli2srv.packets", get_packets_cli2srv());
  lua_push_uint64_table_entry(vm, "srv2cli.packets", get_packets_srv2cli());
  if(getFlowInfo()) lua_push_str_table_entry(vm, "info", getFlowInfo());
}

/* ***************************************************** */

u_int32_t Flow::getCliTcpIssues() {
  return(stats.get_cli2srv_tcp_retr() + stats.get_cli2srv_tcp_ooo() + stats.get_cli2srv_tcp_lost());
}

u_int32_t Flow::getSrvTcpIssues() {
  return(stats.get_srv2cli_tcp_retr() + stats.get_srv2cli_tcp_ooo() + stats.get_srv2cli_tcp_lost());
}

/* ***************************************************** */

void Flow::lua_get_tcp_stats(lua_State *vm) const {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "cli2srv.retransmissions", stats.get_cli2srv_tcp_retr());
  lua_push_uint64_table_entry(vm, "cli2srv.out_of_order", stats.get_cli2srv_tcp_ooo());
  lua_push_uint64_table_entry(vm, "cli2srv.lost", stats.get_cli2srv_tcp_lost());
  lua_push_uint64_table_entry(vm, "srv2cli.retransmissions", stats.get_srv2cli_tcp_retr());
  lua_push_uint64_table_entry(vm, "srv2cli.out_of_order", stats.get_srv2cli_tcp_ooo());
  lua_push_uint64_table_entry(vm, "srv2cli.lost", stats.get_srv2cli_tcp_lost());
}

/* ***************************************************** */

void Flow::lua_duration_info(lua_State *vm) {
  lua_newtable(vm);

  lua_push_uint64_table_entry(vm, "first_seen", get_first_seen());
  lua_push_uint64_table_entry(vm, "last_seen", get_first_seen());
  lua_push_bool_table_entry(vm, "twh_over", twh_over);
}

/* ***************************************************** */

void Flow::lua_device_protocol_allowed_info(lua_State *vm) {
  DeviceProtoStatus cli_ps, srv_ps;
  bool cli_allowed, srv_allowed;

  lua_newtable(vm);

  if(!cli_host || !srv_host)
    return;

  cli_ps = cli_host->getDeviceAllowedProtocolStatus(ndpiDetectedProtocol, true);
  srv_ps = srv_host->getDeviceAllowedProtocolStatus(ndpiDetectedProtocol, false);
  cli_allowed = (cli_ps == device_proto_allowed);
  srv_allowed = (srv_ps == device_proto_allowed);

  lua_push_int32_table_entry(vm, "cli.devtype", cli_host->getMac() ? cli_host->getMac()->getDeviceType() : device_unknown);
  lua_push_int32_table_entry(vm, "srv.devtype", srv_host->getMac() ? srv_host->getMac()->getDeviceType() : device_unknown);

  lua_push_bool_table_entry(vm, "cli.allowed", cli_allowed);
  if(!cli_allowed)
    lua_push_int32_table_entry(vm, "cli.disallowed_proto", (cli_ps == device_proto_forbidden_app) ? ndpiDetectedProtocol.app_protocol : ndpiDetectedProtocol.master_protocol);

  lua_push_bool_table_entry(vm, "srv.allowed", srv_allowed);
  if(!srv_allowed)
    lua_push_int32_table_entry(vm, "srv.disallowed_proto", (srv_ps == device_proto_forbidden_app) ? ndpiDetectedProtocol.app_protocol : ndpiDetectedProtocol.master_protocol);
}

/* ***************************************************** */

void Flow::lua_get_unicast_info(lua_State* vm) const {
  const IpAddress *cli_ip = get_cli_ip_addr();
  const IpAddress *srv_ip = get_srv_ip_addr();

  lua_newtable(vm);

  if(cli_ip) lua_push_bool_table_entry(vm, "cli.broadmulticast", cli_ip->isBroadMulticastAddress());
  if(srv_ip) lua_push_bool_table_entry(vm, "srv.broadmulticast", srv_ip->isBroadMulticastAddress());
}

/* ***************************************************** */

void Flow::lua_get_tls_info(lua_State *vm) const {
  if(isTLS()) {
    lua_push_bool_table_entry(vm, "protos.tls.subject_alt_name_match", protos.tls.subject_alt_name_match);
    lua_push_int32_table_entry(vm, "protos.tls_version", protos.tls.tls_version);

    if(protos.tls.certificate)
      lua_push_str_table_entry(vm, "protos.tls.certificate", protos.tls.certificate);

    if(protos.tls.server_certificate)
      lua_push_str_table_entry(vm, "protos.tls.server_certificate", protos.tls.server_certificate);

    if(protos.tls.ja3.client_hash) {
      lua_push_str_table_entry(vm, "protos.tls.ja3.client_hash", protos.tls.ja3.client_hash);

      if(has_malicious_cli_signature)
	lua_push_bool_table_entry(vm, "protos.tls.ja3.client_malicious", true);
    }

    if(protos.tls.ja3.server_hash) {
      lua_push_str_table_entry(vm, "protos.tls.ja3.server_hash", protos.tls.ja3.server_hash);
      lua_push_str_table_entry(vm, "protos.tls.ja3.server_unsafe_cipher",
			       cipher_weakness2str(protos.tls.ja3.server_unsafe_cipher));
      lua_push_int32_table_entry(vm, "protos.tls.ja3.server_cipher",
				 protos.tls.ja3.server_cipher);

      if(has_malicious_srv_signature)
	lua_push_bool_table_entry(vm, "protos.tls.ja3.server_malicious", true);
    }
  }
}

/* ***************************************************** */

void Flow::lua_get_ssh_info(lua_State *vm) const {  
  if(isSSH()) {
    if(protos.ssh.client_signature) lua_push_str_table_entry(vm, "protos.ssh.client_signature", protos.ssh.client_signature);
    if(protos.ssh.server_signature) lua_push_str_table_entry(vm, "protos.ssh.server_signature", protos.ssh.server_signature);

    if(protos.ssh.hassh.client_hash) lua_push_str_table_entry(vm, "protos.ssh.hassh.client_hash", protos.ssh.hassh.client_hash);
    if(protos.ssh.hassh.server_hash) lua_push_str_table_entry(vm, "protos.ssh.hassh.server_hash", protos.ssh.hassh.server_hash);
  }
}

/* ***************************************************** */

void Flow::lua_get_http_info(lua_State *vm) const {
  if(isHTTP()) {
    if(protos.http.last_url) {
      lua_push_str_table_entry(vm, "protos.http.last_method", protos.http.last_method);
      lua_push_uint64_table_entry(vm, "protos.http.last_return_code", protos.http.last_return_code);
      lua_push_str_table_entry(vm, "protos.http.last_url", protos.http.last_url);
    }

    if(host_server_name)
      lua_push_str_table_entry(vm, "protos.http.server_name", host_server_name);
  }
}

/* ***************************************************** */

void Flow::lua_get_dns_info(lua_State *vm) const {
  if(isDNS()) {
    if(protos.dns.last_query) {
      lua_push_uint64_table_entry(vm, "protos.dns.last_query_type", protos.dns.last_query_type);
      lua_push_uint64_table_entry(vm, "protos.dns.last_return_code", protos.dns.last_return_code);
      lua_push_str_table_entry(vm, "protos.dns.last_query", protos.dns.last_query);

      if(protos.dns.invalid_chars_in_query)
        lua_push_bool_table_entry(vm, "protos.dns.invalid_chars_in_query", protos.dns.invalid_chars_in_query);
    }
  }
}

/* ***************************************************** */

void Flow::lua_get_tcp_info(lua_State *vm) const {  
  if(get_protocol() == IPPROTO_TCP) {
    lua_push_bool_table_entry(vm, "tcp.seq_problems",
			      (stats.get_cli2srv_tcp_retr()
			       || stats.get_cli2srv_tcp_ooo()
			       || stats.get_cli2srv_tcp_lost()
			       || stats.get_cli2srv_tcp_keepalive()
			       || stats.get_srv2cli_tcp_retr()
			       || stats.get_srv2cli_tcp_ooo()
			       || stats.get_srv2cli_tcp_lost()
			       || stats.get_srv2cli_tcp_keepalive()) ? true : false);

    lua_push_float_table_entry(vm, "tcp.nw_latency.client", toMs(&clientNwLatency));
    lua_push_float_table_entry(vm, "tcp.nw_latency.server", toMs(&serverNwLatency));
    lua_push_float_table_entry(vm, "tcp.appl_latency", applLatencyMsec);
    lua_push_float_table_entry(vm, "tcp.max_thpt.cli2srv", getCli2SrvMaxThpt());
    lua_push_float_table_entry(vm, "tcp.max_thpt.srv2cli", getSrv2CliMaxThpt());

    lua_push_uint64_table_entry(vm, "cli2srv.retransmissions", stats.get_cli2srv_tcp_retr());
    lua_push_uint64_table_entry(vm, "cli2srv.out_of_order", stats.get_cli2srv_tcp_ooo());
    lua_push_uint64_table_entry(vm, "cli2srv.lost", stats.get_cli2srv_tcp_lost());
    lua_push_uint64_table_entry(vm, "cli2srv.keep_alive", stats.get_cli2srv_tcp_keepalive());
    lua_push_uint64_table_entry(vm, "srv2cli.retransmissions", stats.get_srv2cli_tcp_retr());
    lua_push_uint64_table_entry(vm, "srv2cli.out_of_order", stats.get_srv2cli_tcp_ooo());
    lua_push_uint64_table_entry(vm, "srv2cli.lost", stats.get_srv2cli_tcp_lost());
    lua_push_uint64_table_entry(vm, "srv2cli.keep_alive", stats.get_srv2cli_tcp_keepalive());

    lua_push_uint64_table_entry(vm, "cli2srv.tcp_flags", src2dst_tcp_flags);
    lua_push_uint64_table_entry(vm, "srv2cli.tcp_flags", dst2src_tcp_flags);

    lua_push_bool_table_entry(vm, "tcp_established", isTCPEstablished());
    lua_push_bool_table_entry(vm, "tcp_connecting", isTCPConnecting());
    lua_push_bool_table_entry(vm, "tcp_closed", isTCPClosed());
    lua_push_bool_table_entry(vm, "tcp_reset", isTCPReset());
  }
}

/* ***************************************************** */

void Flow::lua_get_port(lua_State *vm, bool client) const {
  u_int16_t h_port = client ? get_cli_port() : get_srv_port();

  lua_push_uint64_table_entry(vm, client ? "cli.port" : "srv.port", h_port);
}

/* ***************************************************** */

void Flow::lua_get_geoloc(lua_State *vm, bool client, bool coords, bool country_city) const {
  Host *h = client ? get_cli_host() : get_srv_host();
  float latitude, longitude;
  char buf[32];

  if(h) {
    if(coords) {
      h->get_geocoordinates(&latitude, &longitude);

      lua_push_float_table_entry(vm, client ? "cli.latitude" : "srv.latitude", latitude);
      lua_push_float_table_entry(vm, client ? "cli.longitude" : "srv.longitude", longitude);
    }

    if(country_city) {
      lua_push_str_table_entry(vm,  client ? "cli.country" : "srv.country", h->get_country(buf, sizeof(buf)));
      lua_push_str_table_entry(vm,  client ? "cli.city" : "srv.city", h->get_city(buf, sizeof(buf)));
    }
  }
}

/* ***************************************************** */

bool Flow::performLuaCall(FlowLuaCall flow_lua_call, const struct timeval *tv, periodic_ht_state_update_user_data_t *periodic_ht_state_update_user_data, bool quick) {
  const char *lua_call_fn_name = NULL;

  if(flow_lua_call != flow_lua_call_idle
     && ntop->getGlobals()->isShutdownRequested())
    return false; /* Only flow_lua_call_idle go through during a shutdown */

  if(!periodic_ht_state_update_user_data->acle
     && !(periodic_ht_state_update_user_data->acle = new (std::nothrow) FlowAlertCheckLuaEngine(getInterface())))
    return false; /* Cannot allocate memory */

  FlowAlertCheckLuaEngine *acle = (FlowAlertCheckLuaEngine*)periodic_ht_state_update_user_data->acle;

  if(quick) {
    switch(get_state()) {
    case hash_entry_state_idle:
      acle->incSkippedPcalls(flow_lua_call);
      break;
    default:
      acle->incPendingPcalls(flow_lua_call);
      break;
    }

    return false; /* Need to return as there's no time to do the actual call */
  }

  lua_State *L = acle->getState();
  acle->setFlow(this);

  switch(flow_lua_call) {
  case flow_lua_call_protocol_detected:
    lua_call_fn_name = FLOW_LUA_CALL_PROTOCOL_DETECTED_FN_NAME;
    break;
  case flow_lua_call_flow_status_changed:
    lua_call_fn_name = FLOW_LUA_CALL_FLOW_STATUS_CHANGE_FN_NAME;
    break;
  case flow_lua_call_periodic_update:
    lua_call_fn_name = FLOW_LUA_CALL_PERIODIC_UPDATE_FN_NAME;
    break;
  case flow_lua_call_idle:
    lua_call_fn_name = FLOW_LUA_CALL_IDLE_FN_NAME;
    break;
  default:
    return false;
  }

  int num_args = 3;

  /* Call the function */
  lua_getglobal(L, lua_call_fn_name); /* Called function */
  lua_pushinteger(L, protocol);
  lua_pushinteger(L, ndpiDetectedProtocol.master_protocol);
  lua_pushinteger(L, ndpiDetectedProtocol.app_protocol);

  if(flow_lua_call == flow_lua_call_periodic_update) {
    /* pass the periodic_update counter as the second argument,
     * needed to determine which periodic scripts to call. */
    lua_pushinteger(L, periodic_update_ctr++);
    num_args++;
  }

  acle->pcall(num_args, 0 /* 0 results */);

  return true;
}


/* ***************************************************** */

void Flow::performLuaCalls(const struct timeval *tv, periodic_ht_state_update_user_data_t *periodic_ht_state_update_user_data, bool quick) {
  Bitmap prev_status = status_map;
  HashEntryState cur_state = get_state();

  /* Check if it is time to call the protocol detected */
  if(pending_lua_call_protocol_detected
     && performLuaCall(flow_lua_call_protocol_detected, tv, periodic_ht_state_update_user_data, quick))
    pending_lua_call_protocol_detected = false;

  /* Check if it is time to call the periodic update. Need to make sure this is not called BEFORE
     the protocol detected has been called */
  if(cur_state >= hash_entry_state_active /* This check guarantees no periodic update is called before protocol detected */
     && (trigger_immediate_periodic_update ||
	 (next_lua_call_periodic_update > 0 /* 0 means not-yet-set */
	  && next_lua_call_periodic_update <= tv->tv_sec))
     && performLuaCall(flow_lua_call_periodic_update, tv, periodic_ht_state_update_user_data, quick)) {
    next_lua_call_periodic_update = tv->tv_sec + FLOW_LUA_CALL_PERIODIC_UPDATE_SECS; /* Set the time of the new periodic call */
    if(trigger_immediate_periodic_update) trigger_immediate_periodic_update = false; /* Reset if necessary */
  }

  /* Check if it is time to call the idle. There is no need to change any boolean here to remember
     the call has been performed: each flow in idle state is visited exactly once. */
  if(cur_state == hash_entry_state_idle)
    performLuaCall(flow_lua_call_idle, tv, periodic_ht_state_update_user_data, quick);

  /* Regardless of the calls performed previously, if someone of them has changed the state of the flow,
     thi extra status_changed lua function is executed. */
  if(prev_status.get() != status_map.get()) {
    performLuaCall(flow_lua_call_flow_status_changed, tv, periodic_ht_state_update_user_data, quick);

    /* Update the hosts status */
    if(cli_host) cli_host->setAnomalousFlowsStatusMap(status_map, true);
    if(srv_host) srv_host->setAnomalousFlowsStatusMap(status_map, false);
  }
}

/* ***************************************************** */

bool Flow::hasDissectedTooManyPackets() {
  u_int32_t num_packets;

#ifdef HAVE_NEDGE
  /* NOTE: in nEdge packet stats are update periodically, so
   * we cannot rely on get_packets() */
  if(ndpiFlow)
    /* WARNING: can wrap! */
    num_packets = ndpiFlow->num_processed_pkts;
  else
    num_packets = get_packets();
#else
  num_packets = get_packets();
#endif

  return(num_packets >= NDPI_MIN_NUM_PACKETS);
}

/* ***************************************************** */

bool Flow::triggerAlert(FlowStatus status, AlertType atype, AlertLevel severity, const char *alert_json) {
  
  /* Triggering multiple alerts is not supported */
  if(isFlowAlerted())
    return(false);

  alert_status_info = alert_json ? strdup(alert_json) : NULL;
  alerted_status = status;
  alert_level = severity;
  alert_type = atype; /* set this as the last thing to avoid concurrency issues */

  if(cli_host && srv_host) {
    bool cli_thresh, srv_thresh;
    time_t when = time(0);

    /* Check per-host thresholds */
    cli_thresh = cli_host->incFlowAlertHits(when);
    srv_thresh = srv_host->incFlowAlertHits(when);
    if((cli_thresh || srv_thresh) && !getInterface()->read_from_pcap_dump())
      return(false);
  }

  is_alerted = true;

  if(!idle()) {
    /* If idle() and not alerted, the interface
     * counter for active alerted flows is not incremented as
     * it means the purgeIdle() has traversed this flow and marked 
     * it as state_idle before it was alerted */
    iface->incNumAlertedFlows(this);
#ifdef ALERTED_FLOWS_DEBUG
    iface_alert_inc = true;
#endif
  }

  if(cli_host) {
    cli_host->incNumAlertedFlows();
    cli_host->incTotalAlerts(alert_type);
  }

  if(srv_host) {
    srv_host->incNumAlertedFlows();
    srv_host->incTotalAlerts(alert_type);
  }

  /* Success - alert is dumped/notified from lua */
  return(true);
}

/* *************************************** */

void Flow::setExternalAlert(json_object *a) {
  if(!external_alert) {
    /* In order to avoid concurrency issues with the getter, at most
     * 1 pending external alert is supported. */
    external_alert = strdup(json_object_to_json_string(a));

    /* Manually trigger a periodic update to process the alert */
    trigger_immediate_periodic_update = true;
  }

  json_object_put(a);
}

/* *************************************** */

void Flow::luaRetrieveExternalAlert(lua_State *vm) {
  if(external_alert) {
    lua_pushstring(vm, external_alert);

    /* Must delte the data to avoid returning it in the next call */
    free(external_alert);
    external_alert = NULL;
  } else
    lua_pushnil(vm);
}
