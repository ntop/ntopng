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

/* static so default is zero-initialization, let's just define it */

const ndpi_protocol Flow::ndpiUnknownProtocol = { NDPI_PROTOCOL_UNKNOWN, /* master_protocol */
						  NDPI_PROTOCOL_UNKNOWN, /* app_protocol    */
						  NDPI_PROTOCOL_UNKNOWN, /* protocol_by_ip */
						  NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, NULL };
// #define DEBUG_DISCOVERY
// #define DEBUG_UA
// #define DEBUG_SCORE

/* *************************************** */

Flow::Flow(NetworkInterface *_iface,
	   VLANid _vlanId, u_int16_t _observation_point_id,
	   u_int32_t _private_flow_id, u_int8_t _protocol,
	   Mac *_cli_mac, IpAddress *_cli_ip, u_int16_t _cli_port,
	   Mac *_srv_mac, IpAddress *_srv_ip, u_int16_t _srv_port,
	   const ICMPinfo * const _icmp_info,
	   time_t _first_seen, time_t _last_seen,
	   u_int8_t *_view_cli_mac, u_int8_t *_view_srv_mac) : GenericHashEntry(_iface) {
  periodic_stats_update_partial = NULL;
  viewFlowStats = NULL;
  vlanId = _vlanId, protocol = _protocol, cli_port = _cli_port, srv_port = _srv_port;
  flow_device.observation_point_id = _observation_point_id;
  cli_host = srv_host = NULL;
  cli_ip_addr = srv_ip_addr = NULL;
  flow_dropped_counts_increased = 0, vrfId = 0;
  srcAS = dstAS  = prevAdjacentAS = nextAdjacentAS = 0;
  predominant_alert.id = flow_alert_normal, predominant_alert.category = alert_category_other;
  predominant_alert_score = 0;
  predominant_alert_info.is_cli_attacker = 0;
  predominant_alert_info.is_cli_victim = 0;
  predominant_alert_info.is_srv_attacker = 0;
  predominant_alert_info.is_srv_victim = 0;
  json_protocol_info = NULL, riskInfo = NULL, ndpiAddressFamilyProtocol = NULL;
  privateFlowId = _private_flow_id;
  clearRisks();
  detection_completed = 0;
  non_zero_payload_observed = 0;
  extra_dissection_completed = 0;
  ndpiDetectedProtocol = ndpiUnknownProtocol;
  doNotExpireBefore = iface->getTimeLastPktRcvd() + DONT_NOT_EXPIRE_BEFORE_SEC;
  periodic_update_ctr = 0, cli2srv_tos = srv2cli_tos = 0, iec104 = NULL;
  suspicious_dga_domain = NULL;
  src2dst_tcp_zero_window = dst2src_tcp_zero_window = 0;
  swap_done = swap_requested = 0;
  flowCreationTime = iface->getTimeLastPktRcvd();

#ifdef HAVE_NEDGE
  last_conntrack_update = 0;
  marker = MARKER_NO_ACTION;
#endif

  icmp_info = _icmp_info ? new (std::nothrow) ICMPinfo(*_icmp_info) : NULL;
  ndpiFlow = NULL, confidence = NDPI_CONFIDENCE_UNKNOWN;
  ebpf = NULL;
  json_info = NULL, tlv_info = NULL, twh_over = twh_ok = 0,
    dissect_next_http_packet = 0, host_server_name = NULL;
  bt_hash = NULL;
  flow_payload = NULL, flow_payload_len = 0;
  flow_verdict = 0;
  flow_serial = _iface->getNewFlowSerial();
  operating_system = os_unknown;
  src2dst_tcp_flags = 0, dst2src_tcp_flags = 0, last_update_time.tv_sec = 0, last_update_time.tv_usec = 0,
    top_bytes_thpt = 0, top_pkts_thpt = 0;
  bytes_thpt_cli2srv  = 0, goodput_bytes_thpt_cli2srv = 0;
  bytes_thpt_srv2cli  = 0, goodput_bytes_thpt_srv2cli = 0;
  pkts_thpt_cli2srv = 0, pkts_thpt_srv2cli = 0;
  top_bytes_thpt = 0, top_goodput_bytes_thpt = 0, applLatencyMsec = 0;
  external_alert.json = NULL;
  external_alert.source = NULL;
  trigger_immediate_periodic_update = false;
  next_call_periodic_update = 0;

  last_db_dump.partial = NULL;
  last_db_dump.first_seen = last_db_dump.last_seen = 0;
  last_db_dump.in_progress = false;
  memset(&protos, 0, sizeof(protos));
  memset(&flow_device, 0, sizeof(flow_device));

  flow_score = 0;

  INTERFACE_PROFILING_SUB_SECTION_ENTER(iface, "Flow::Flow: iface->findFlowHosts", 7);
  iface->findFlowHosts(_vlanId, _observation_point_id, _private_flow_id, _cli_mac, _cli_ip, &cli_host, _srv_mac, _srv_ip, &srv_host);
  INTERFACE_PROFILING_SUB_SECTION_EXIT(iface, 7);

  char country[64];

  if(_observation_point_id)
    iface->incObservationPointIdFlows(_observation_point_id);

  if(_iface->isViewed()) {
    memset(view_cli_mac, 0, sizeof(view_cli_mac));
    memset(view_srv_mac, 0, sizeof(view_srv_mac));

    if(_view_cli_mac)
      memcpy(view_cli_mac, _view_cli_mac, sizeof(view_cli_mac));

    if(_view_srv_mac)
      memcpy(view_srv_mac, _view_srv_mac, sizeof(view_srv_mac));
  }

  if(cli_host) {
    NetworkStats *network_stats = cli_host->getNetworkStats(cli_host->get_local_network_id());

    cli_host->incUses(), cli_host->incNumFlows(last_seen, true);
    if(network_stats) network_stats->incNumFlows(last_seen, true);
    cli_ip_addr = cli_host->get_ip();
    cli_host->incCliContactedPorts(_srv_port);

    if(cli_host->isLocalHost() && srv_host) {
      srv_host->get_country(country, sizeof(country));
      if(country[0] != '\0') cli_host->incCountriesContacts(country);

      if(_srv_mac && (!srv_host->isLocalHost())) {
	LocalHost *lh = (LocalHost*)cli_host;

	lh->setRouterMac(_srv_mac);
      }
    }

    switch(protocol) {
    case IPPROTO_TCP:
    case IPPROTO_UDP:
      cli_host->setContactedPort((protocol == IPPROTO_TCP), ntohs(srv_port));
      break;
    }
  } else {
    /* Client host has not been allocated, let's keep the info in an IpAddress */

    if((cli_ip_addr = new (std::nothrow) IpAddress(*_cli_ip)))
      cli_ip_addr->reloadBlacklist(iface->get_ndpi_struct());
  }

  if(srv_host) {
    NetworkStats *network_stats = srv_host->getNetworkStats(srv_host->get_local_network_id());

    srv_host->incUses(), srv_host->incNumFlows(last_seen, false);
    if(network_stats) network_stats->incNumFlows(last_seen, false);
    srv_ip_addr = srv_host->get_ip();

    srv_host->incSrvHostContacts(_cli_ip);
    srv_host->incSrvPortsContacts(_cli_port);

    if(srv_host->isLocalHost() && cli_host) {
      cli_host->get_country(country, sizeof(country));
      if(country[0] != '\0') srv_host->incCountriesContacts(country);
    }
  } else {
    /* Server host has not been allocated, let's keep the info in an IpAddress */

    if((srv_ip_addr = new (std::nothrow) IpAddress(*_srv_ip)))
      srv_ip_addr->reloadBlacklist(iface->get_ndpi_struct());
  }

  /* Update broadcast domain, if destination MAC address is broadcast */
  if(_cli_mac && _srv_mac
     && _srv_mac->isBroadcast() /* Broadcast MAC address */
     && get_cli_ip_addr()->isIPv4()
     && get_srv_ip_addr()->isIPv4() /* IPv4 only */
     && !get_srv_ip_addr()->isBroadcastAddress() /* Avoid 255.255.255.255 */)
    getInterface()->updateBroadcastDomains(_vlanId, _cli_mac->get_mac(),
					   _srv_mac->get_mac(), ntohl(_cli_ip->get_ipv4()),
					   ntohl(_srv_ip->get_ipv4()));

  memset(&custom_app, 0, sizeof(custom_app));

#ifdef NTOPNG_PRO
  HostPools *hp = iface->getHostPools();

  routing_table_id = DEFAULT_ROUTING_TABLE_ID;

  if(hp) {
    if(cli_host) routing_table_id = hp->getRoutingPolicy(cli_host->get_host_pool());
    if(srv_host) routing_table_id = max_val(routing_table_id,
					    hp->getRoutingPolicy(srv_host->get_host_pool()));
  }
#endif

  passVerdict = 1, quota_exceeded = 0;
  has_malicious_cli_signature = has_malicious_srv_signature = 0;
#ifdef ALERTED_FLOWS_DEBUG
  iface_alert_inc = iface_alert_dec = false;
#endif
  if(_first_seen > _last_seen) _first_seen = _last_seen;
  first_seen = _first_seen, last_seen = _last_seen;
  bytes_thpt_trend = trend_unknown, pkts_thpt_trend = trend_unknown;
  //bytes_rate = new TimeSeries<float>(4096);

  synTime.tv_sec = synTime.tv_usec = 0,
    ackTime.tv_sec = ackTime.tv_usec = 0,
    synAckTime.tv_sec = synAckTime.tv_usec = 0,
    rttSec = 0, cli2srv_window = srv2cli_window = 0,
    c2sFirstGoodputTime.tv_sec = c2sFirstGoodputTime.tv_usec = 0;

  memset(&ip_stats_s2d, 0, sizeof(ip_stats_s2d)), memset(&ip_stats_d2s, 0, sizeof(ip_stats_d2s));
  memset(&tcp_seq_s2d, 0, sizeof(tcp_seq_s2d)), memset(&tcp_seq_d2s, 0, sizeof(tcp_seq_d2s));
  memset(&clientNwLatency, 0, sizeof(clientNwLatency)), memset(&serverNwLatency, 0, sizeof(serverNwLatency));

  if(iface->isPacketInterface() && !iface->isSampledTraffic()) {
    cli2srvPktTime = new (std::nothrow) InterarrivalStats();
    srv2cliPktTime = new (std::nothrow) InterarrivalStats();
    entropy.c2s = ndpi_alloc_data_analysis(256);
    entropy.s2c = ndpi_alloc_data_analysis(256);
  } else {
    cli2srvPktTime = NULL;
    srv2cliPktTime = NULL;
    entropy.c2s = entropy.s2c = NULL;
  }

#ifdef NTOPNG_PRO
  lateral_movement = false;
  periodicity_status = periodicity_status_unknown;
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
    if(iface->is_ndpi_enabled())
      allocDPIMemory();

    if(protocol == IPPROTO_UDP)
      set_hash_entry_state_flow_notyetdetected();
    break;

  case IPPROTO_ICMP:
    ndpiDetectedProtocol.app_protocol = NDPI_PROTOCOL_IP_ICMP,
      ndpiDetectedProtocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;

    /* Use nDPI to check potential flow risks */
    if(iface->is_ndpi_enabled()) allocDPIMemory();
    set_hash_entry_state_flow_notyetdetected();
    break;

  case IPPROTO_ICMPV6:
    ndpiDetectedProtocol.app_protocol = NDPI_PROTOCOL_IP_ICMPV6,
      ndpiDetectedProtocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;

    /* Use nDPI to check potential flow risks */
    if(iface->is_ndpi_enabled()) allocDPIMemory();
    set_hash_entry_state_flow_notyetdetected();
    break;

  default:
    setDetectedProtocol(ndpi_guess_undetected_protocol(iface->get_ndpi_struct(),
						       NULL, protocol, 0, 0, 0, 0));
    break;
  }

  if(isBlacklistedClient()) {
    if(srv_host) srv_host->inc_num_blacklisted_flows(false);
  } else if(isBlacklistedServer()) {
    if(cli_host) cli_host->inc_num_blacklisted_flows(true);
  }

  iface->execFlowBeginChecks(this);
}

/* *************************************** */

void Flow::allocDPIMemory() {
  if((ndpiFlow = (ndpi_flow_struct*)calloc(1, iface->get_flow_size())) == NULL)
    throw "Not enough memory";
}

/* *************************************** */

void Flow::freeDPIMemory() {
  if(ndpiFlow)  {
    ndpi_free_flow(ndpiFlow);
    ndpiFlow = NULL;
  }
}

/* *************************************** */

Flow::~Flow() {
  bool is_oneway_tcp_syn_seen = ((protocol == IPPROTO_TCP) && (get_packets_srv2cli() == 0) && (src2dst_tcp_flags == TH_SYN)) ? true : false;
  
  if(getUses() != 0 && !ntop->getGlobals()->isShutdown())
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] Deleting flow [%u]", __FUNCTION__, getUses());

#ifdef ALERTED_FLOWS_DEBUG
  if(iface_alert_inc && !iface_alert_dec) {
    char buf[256];

    ntop->getTrace()->traceEvent(TRACE_WARNING, "[MISMATCH][inc but not dec][alerted: %u] %s",
				 isFlowAlerted() ? 1 : 0, print(buf, sizeof(buf)));
  }
#endif

  /*
    Get client and server hosts. Use unsafe* methods to get the client and server also for 'viewed' interfaces.
    For 'Viewed' interfaces, host pointers are shared across multiple 'viewed' interfaces and thus they are termed as unsafe.

    IMPORTANT: only call here methods that are safe (e.g., locked or atomic-ed).

    It is fundamental to only call
   */
  Host *cli_u = getViewSharedClient(), *srv_u = getViewSharedServer();

  if(getInterface()->isViewed()) /* Score decrements done here for 'viewed' interfaces to avoid races. */
    decAllFlowScores();

  
  if(cli_u) {
    cli_u->decUses(); /* Decrease the number of uses */
    cli_u->decNumFlows(get_last_seen(), true);

    if(is_oneway_tcp_syn_seen)
      cli_u->incUnidirectionalEgressFlows();
  }

  if(!cli_host && cli_ip_addr) /* Dynamically allocated only when cli_host was NULL in Flow constructor (viewed interfaces) */
    delete cli_ip_addr;

  if(srv_u) {
    srv_u->decUses(); /* Decrease the number of uses */
    srv_u->decNumFlows(get_last_seen(), false);

    if(is_oneway_tcp_syn_seen)
      srv_u->incUnidirectionalIngressFlows();    
  }

  if(!srv_host && srv_ip_addr) /* Dynamically allocated only when srv_host was NULL in Flow constructor (viewed interfaces) */
    delete srv_ip_addr;

  /*
    Finish deleting other flow data structures
   */

  if(riskInfo)                      free(riskInfo);
  if(viewFlowStats)                 delete(viewFlowStats);
  if(periodic_stats_update_partial) delete(periodic_stats_update_partial);
  if(last_db_dump.partial)          delete(last_db_dump.partial);
  if(json_info)                     json_object_put(json_info);
  if(tlv_info) {
    ndpi_term_serializer(tlv_info);
    free(tlv_info);
  }

  if(host_server_name)              free(host_server_name);
  if(iec104)                        delete iec104;
  if(suspicious_dga_domain)         free(suspicious_dga_domain);
  if(ndpiAddressFamilyProtocol)     free(ndpiAddressFamilyProtocol);
  if(ebpf)                          delete ebpf;

  if(cli2srvPktTime) delete cli2srvPktTime;
  if(srv2cliPktTime) delete srv2cliPktTime;

  if(entropy.c2s) ndpi_free_data_analysis(entropy.c2s, 1);
  if(entropy.s2c) ndpi_free_data_analysis(entropy.s2c, 1);

  if(flow_payload)                   free(flow_payload);

  if(isHTTP()) {
    if(protos.http.last_url)         free(protos.http.last_url);
    if(protos.http.last_user_agent)  free(protos.http.last_user_agent);
  } else if(isDNS()) {
    if(protos.dns.last_query)        free(protos.dns.last_query);
    if(protos.dns.last_query_shadow) free(protos.dns.last_query_shadow);
  } else if(isMDNS()) {
    if(protos.mdns.answer)           free(protos.mdns.answer);
    if(protos.mdns.name)             free(protos.mdns.name);
    if(protos.mdns.name_txt)         free(protos.mdns.name_txt);
    if(protos.mdns.ssid)             free(protos.mdns.ssid);
  } else if(isSSDP()) {
    if(protos.ssdp.location)         free(protos.ssdp.location);
  } else if(isNetBIOS()) {
    if(protos.netbios.name)          free(protos.netbios.name);
  } else if(isSSH()) {
    if(protos.ssh.client_signature)  free(protos.ssh.client_signature);
    if(protos.ssh.server_signature)  free(protos.ssh.server_signature);
    if(protos.ssh.hassh.client_hash) free(protos.ssh.hassh.client_hash);
    if(protos.ssh.hassh.server_hash) free(protos.ssh.hassh.server_hash);
  } else if(isTLS()) {
    if(protos.tls.client_requested_server_name)  free(protos.tls.client_requested_server_name);
    if(protos.tls.server_names)                  free(protos.tls.server_names);
    if(protos.tls.ja3.client_hash)               free(protos.tls.ja3.client_hash);
    if(protos.tls.ja3.server_hash)               free(protos.tls.ja3.server_hash);
    if(protos.tls.client_alpn)                   free(protos.tls.client_alpn);
    if(protos.tls.client_tls_supported_versions) free(protos.tls.client_tls_supported_versions);
    if(protos.tls.issuerDN)                      free(protos.tls.issuerDN);
    if(protos.tls.subjectDN)                     free(protos.tls.subjectDN);
  }

  if(bt_hash)
    free(bt_hash);

  freeDPIMemory();
  if(icmp_info) delete(icmp_info);
  if(json_protocol_info) free(json_protocol_info);
  if(external_alert.json) json_object_put(external_alert.json);
  if(external_alert.source) free(external_alert.source);
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
 * completed. See processExtraDissectedInformation for a later check.
 * NOTE: does NOT need ndpiFlow
 */
void Flow::processDetectedProtocol(u_int8_t *payload, u_int16_t payload_len) {
  u_int16_t l7proto;
  u_int16_t stats_protocol;
  Host *cli_h = NULL, *srv_h = NULL, /* *real_cli_h, */ *real_srv_h;
  char *domain_name = NULL;

  /*
    If peers should be swapped, then pointers are inverted.
    NOTE: only function pointers are inverted, not pointers in the flow.
   */
  get_actual_peers(&cli_h, &srv_h);

  stats_protocol = getStatsProtocol();

  /* Update the active flows stats */
  if(cli_h) cli_h->incnDPIFlows(stats_protocol);
  if(srv_h) srv_h->incnDPIFlows(stats_protocol);
  iface->incnDPIFlows(stats_protocol);

  l7proto = ndpi_get_lower_proto(ndpiDetectedProtocol);

  /* Domain Concats Alert */
  if(ndpiFlow)
    domain_name = ndpi_get_flow_name(ndpiFlow), confidence = ndpiFlow->confidence;

  if(cli_h && domain_name && domain_name[0] != '\0')
    cli_h->addContactedDomainName(domain_name);

  switch(l7proto) {
  case NDPI_PROTOCOL_DHCP:
    if(cli_port == htons(67)) {
      /* Server -> Client */
      if(cli_host && (!cli_host->isBroadcastHost())) {
	cli_host->setDhcpServer(domain_name);
      } else if(cli_ip_addr && !cli_ip_addr->isBroadcastAddress()) {
        cli_ip_addr->setDhcpServer();
      }
    } else {
      if(srv_host && (!srv_host->isBroadcastHost())) {
	srv_host->setDhcpServer(domain_name);
      } else if(srv_ip_addr && !srv_ip_addr->isBroadcastAddress()) {
        srv_ip_addr->setDhcpServer();
      }
    }
    break;

  case NDPI_PROTOCOL_NTP:
    real_srv_h = srv_h /* , real_cli_h = cli_h */;

    /* Check direction first */
    if(payload && (payload_len > 1)) {
      u_int8_t mode = payload[0] & 0x07;

      if(mode == 2 /* server -> client */)
	real_srv_h = cli_h /* , real_cli_h = srv_h */;
    }

    if(real_srv_h)
      real_srv_h->setNtpServer(domain_name);
    else if(srv_ip_addr)
      srv_ip_addr->setNtpServer();
    break;

  case NDPI_PROTOCOL_MAIL_SMTPS:
  case NDPI_PROTOCOL_MAIL_SMTP:
    if(srv_h)
      srv_h->setSmtpServer(domain_name);
    else if(srv_ip_addr)
      srv_ip_addr->setSmtpServer();
    break;

  case NDPI_PROTOCOL_MAIL_IMAPS:
  case NDPI_PROTOCOL_MAIL_IMAP:
    if(srv_h)
      srv_h->setImapServer(domain_name);
    else if (srv_ip_addr)
      srv_ip_addr->setImapServer();
    break;

  case NDPI_PROTOCOL_MAIL_POPS:
  case NDPI_PROTOCOL_MAIL_POP:
    if(srv_h)
      srv_h->setPopServer(domain_name);
    else if (srv_ip_addr)
      srv_ip_addr->setPopServer();
    break;

  case NDPI_PROTOCOL_DNS:
    /*
      No need to swap as Flow::processDNSPacket()
      take care of directions
    */
    if(srv_h)
      srv_h->setDnsServer(domain_name);
    else if (srv_ip_addr)
      srv_ip_addr->setDnsServer();
    break;

  case NDPI_PROTOCOL_TOR:
  case NDPI_PROTOCOL_TLS:
  case NDPI_PROTOCOL_QUIC:
    if(ndpiDetectedProtocol.app_protocol == NDPI_PROTOCOL_DOH_DOT
       && cli_h && srv_h && cli_h->isLocalHost())
      cli_h->incDohDoTUses(srv_h);
    break;

  default:
    break;
  } /* switch */
}

/* *************************************** */

/* This function is called as soon as the protocol detection is
 * completed to process nDPI-dissected data (only for packet interfaces).
 * NOTE: needs ndpiFlow
 */
void Flow::processDetectedProtocolData() {
  u_int16_t l7proto;
  Host *cli_h = NULL, *srv_h = NULL;
  /*
    Make sure to actual client and server to avoid setting wrong names (e.g., set the server name to the client)
    https://github.com/ntop/ntopng/issues/5506
   */
  get_actual_peers(&cli_h, &srv_h);

  if(ndpiFlow == NULL)
    return;

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
    if(bt_hash == NULL)
      setBittorrentHash((char*)ndpiFlow->protos.bittorrent.hash);
    break;

  case NDPI_PROTOCOL_MDNS:
    /* protos.mdns.{answer,name} already propagated to hosts in Flow::hosts_periodic_stats_update  */
    break;

  case NDPI_PROTOCOL_TOR:
  case NDPI_PROTOCOL_TLS:
  case NDPI_PROTOCOL_QUIC:
    if(ndpiFlow->host_server_name[0] != '\0') {
      if(ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_DOH_DOT
	 && cli_h && cli_h->isLocalHost())
	cli_h->incrVisitedWebSite(ndpiFlow->host_server_name);

      if(cli_h) cli_h->incContactedService(ndpiFlow->host_server_name);
      if(srv_h) srv_h->setServerName(host_server_name);
    }
    break;

  case NDPI_PROTOCOL_HTTP:
    if(srv_h && ndpiFlow->host_server_name[0] != '\0') srv_h->setServerName(host_server_name);
  case NDPI_PROTOCOL_HTTP_PROXY:
    if(ndpiFlow->http.url) {
      if(!protos.http.last_url) protos.http.last_url = strdup(ndpiFlow->http.url);

      if((!protos.http.last_user_agent) && ndpiFlow->http.user_agent)
	protos.http.last_user_agent = strdup(ndpiFlow->http.user_agent);

      setHTTPMethod(ndpiFlow->http.method);
    }

    if(ndpiFlow->host_server_name[0] != '\0') {
      char *doublecol, delimiter = ':';

      /* If <host>:<port> we need to remove ':' */
      if((doublecol = (char*)strchr((const char*)ndpiFlow->host_server_name, delimiter)) != NULL)
	doublecol[0] = '\0';

      if(cli_h) {
	cli_h->incContactedService((char*)ndpiFlow->host_server_name);

	if(ndpiFlow->http.detected_os)
	  cli_h->inlineSetOSDetail((char*)ndpiFlow->http.detected_os);

	if(cli_h->isLocalHost())
	  cli_h->incrVisitedWebSite(host_server_name);
      }

      if(srv_h && (ndpiFlow->protos.dns.reply_code == 0 /* No Error */))
	srv_h->setResolvedName((char*)ndpiFlow->host_server_name);
    }
    break;
  } /* switch */
}

/* *************************************** */

/* This is called only once per Flow, when all the protocol information,
 * including extra dissection information (e.g. the TLS certificate), is
 * available. */
void Flow::processExtraDissectedInformation() {
  bool free_ndpi_memory = true; /* Possibly set to false if the flow is DNS and all the packets need to be dissected */

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

    /* Protocols with TLS transport (keep in sync with isTLS()) */
    case NDPI_PROTOCOL_TLS:
    case NDPI_PROTOCOL_MAIL_IMAPS:
    case NDPI_PROTOCOL_MAIL_SMTPS:
    case NDPI_PROTOCOL_MAIL_POPS:
    case NDPI_PROTOCOL_QUIC:
      protos.tls.tls_version = ndpiFlow->protos.tls_quic.ssl_version;

      protos.tls.notBefore = ndpiFlow->protos.tls_quic.notBefore,
	protos.tls.notAfter = ndpiFlow->protos.tls_quic.notAfter;

      if((protos.tls.client_requested_server_name == NULL)
	 && (ndpiFlow->host_server_name[0] != '\0')) {
	protos.tls.client_requested_server_name = strdup(ndpiFlow->host_server_name);

	/* Now some minor cleanup */
	char *c;

	if((c = strchr(protos.tls.client_requested_server_name, ',')) != NULL)
	  c[0] = '\0';
	else if((c = strchr(protos.tls.client_requested_server_name, ' ')) != NULL)
	  c[0] = '\0';
      }

      if((protos.tls.server_names == NULL)
	 && (ndpiFlow->protos.tls_quic.server_names != NULL))
	protos.tls.server_names = strdup(ndpiFlow->protos.tls_quic.server_names);

      if((protos.tls.client_alpn == NULL)
	 && (ndpiFlow->protos.tls_quic.alpn != NULL))
	protos.tls.client_alpn = strdup(ndpiFlow->protos.tls_quic.alpn);

      if((protos.tls.client_tls_supported_versions == NULL)
	 && (ndpiFlow->protos.tls_quic.tls_supported_versions != NULL))
	protos.tls.client_tls_supported_versions = strdup(ndpiFlow->protos.tls_quic.tls_supported_versions);

      if((protos.tls.issuerDN == NULL) && (ndpiFlow->protos.tls_quic.issuerDN != NULL))
	protos.tls.issuerDN= strdup(ndpiFlow->protos.tls_quic.issuerDN);

      if((protos.tls.subjectDN == NULL) && (ndpiFlow->protos.tls_quic.subjectDN != NULL))
	protos.tls.subjectDN= strdup(ndpiFlow->protos.tls_quic.subjectDN);

      if((protos.tls.ja3.client_hash == NULL) && (ndpiFlow->protos.tls_quic.ja3_client[0] != '\0')) {
	protos.tls.ja3.client_hash = strdup(ndpiFlow->protos.tls_quic.ja3_client);
	updateCliJA3();
      }

      if((protos.tls.ja3.server_hash == NULL) && (ndpiFlow->protos.tls_quic.ja3_server[0] != '\0')) {
	protos.tls.ja3.server_hash = strdup(ndpiFlow->protos.tls_quic.ja3_server);
	protos.tls.ja3.server_unsafe_cipher = ndpiFlow->protos.tls_quic.server_unsafe_cipher;
	protos.tls.ja3.server_cipher = ndpiFlow->protos.tls_quic.server_cipher;
	updateSrvJA3();
      }
      break;

    case NDPI_PROTOCOL_DNS:
    case NDPI_PROTOCOL_IEC60870:
      /*
	Don't free the memory, let the nDPI dissection run for DNS.
	See Method Flow::processDNSPacket and Flow::processIEC60870Packet
      */
      if(getInterface()->isPacketInterface())
	free_ndpi_memory = false;
      break;

    case NDPI_PROTOCOL_HTTP:
      if(protos.http.last_url) {
	ndpi_risk_enum risk = ndpi_validate_url(protos.http.last_url);

	if((risk != NDPI_NO_RISK) && (risk < NDPI_MAX_RISK))
	  addRisk(2 << (risk-1));
      }

      break;
    }

    updateSuspiciousDGADomain();
  }

#if defined(NTOPNG_PRO)
  getInterface()->updateFlowPeriodicity(this);
  getInterface()->updateServiceMap(this);
#endif

  if(get_ndpi_flow()) {
    /* Save riskInfo */
    char *out, buf[512];
    struct ndpi_flow_struct* f = get_ndpi_flow();

    out = ndpi_get_flow_risk_info(f, buf, sizeof(buf), 1 /* JSON */);

    if(out != NULL)
      setJSONRiskInfo(out);

    flow_payload = f->flow_payload, flow_payload_len = f->flow_payload_len;
    ndpiFlow->flow_payload = NULL; /* ntopng will free this memory not nDPI */
  }

  /* Free the nDPI memory */
  if(free_ndpi_memory)
    freeDPIMemory();

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
	 && (!extra_dissection_completed)
	 && (ndpi_extra_dissection_possible(iface->get_ndpi_struct(), ndpif))
	 );
}

/* *************************************** */

/* Process a packet and advance the flow detection state. */
void Flow::processPacket(const struct pcap_pkthdr *h,
			 const u_char *ip_packet, u_int16_t ip_len, u_int64_t packet_time,
			 u_int8_t *payload, u_int16_t payload_len, u_int16_t src_port) {
  bool detected;
  ndpi_protocol proto_id;

  /* Note: do not call endProtocolDissection before ndpi_detection_process_packet. In case of
   * early giveup (e.g. sampled traffic), nDPI should process at least one packet in order to
   * be able to guess the protocol. */

  proto_id = ndpi_detection_process_packet(iface->get_ndpi_struct(), ndpiFlow,
					   ip_packet, ip_len, packet_time,
					   NULL);

  detected = ndpi_is_protocol_detected(iface->get_ndpi_struct(), proto_id);

  if(!detected && hasDissectedTooManyPackets()) {
    /*
       Perform a giveup and finalize all additional operations such as
       the processing of extra dissection data.
     */
    endProtocolDissection();
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

  if(payload_len > 0)
    non_zero_payload_observed = 1;

  if(detected) {
    if(ndpiFlow->risk != 0) {
      if(srv_host) {
	/* Ignore unsafe protocols for broadcast packets (e.g. SMBv1) */
	Mac *srv_mac = srv_host->getMac();

	if(srv_mac && srv_mac->isBroadcast()) {
	  ndpi_risk r = ((ndpi_risk)1) << NDPI_UNSAFE_PROTOCOL;

	  if((ndpiFlow->risk & r) == r)
	    ndpiFlow->risk &= ~r; /* Clear the bit */
	}
      }

      if(cli_host) {
	if(NDPI_ISSET_BIT(ndpiFlow->risk, NDPI_HTTP_CRAWLER_BOT))
	  cli_host->setCrawlerBotScannerHost();
      }

      setRisk(ndpiFlow->risk);
    }

    updateProtocol(proto_id);
    setProtocolDetectionCompleted(payload, payload_len);
  }

  /*
    Perform other protocol-specific processing before marking the detection as completed.
    For example, for the DNS, additional processing on the query is performed and later used by
    checks.
  */

  if(isDNS())
    processDNSPacket(ip_packet, ip_len, packet_time);
  else if(isIEC60870())
    processIEC60870Packet((htons(src_port) == 2404) ? true : false,
			  payload, payload_len,
			  (struct timeval *)&h->ts);

  if(detection_completed) {
    if(!needsExtraDissection()) {
      setExtraDissectionCompleted();
      updateProtocol(proto_id);
    }

    if(get_custom_category_file()) {
      if(isBlacklistedClient()) {
	if(cli_host) cli_host->setBlacklistName((char*)get_custom_category_file());
      } else if(isBlacklistedServer()) {
	if(srv_host) srv_host->setBlacklistName((char*)get_custom_category_file());
      }

      ntop->incBlacklisHits(std::string(get_custom_category_file()));
    }
  }
}

/* *************************************** */

/* Special handling of DNS which is always performed. */
void Flow::processDNSPacket(const u_char *ip_packet, u_int16_t ip_len, u_int64_t packet_time) {
  ndpi_protocol proto_id;

  /* Exits if the flow isn't DNS or it the interface is not a packet-interface */
  if((!isDNS()) || (!getInterface()->isPacketInterface()) || (ndpiFlow == NULL))
    return;

  /* Instruct nDPI to continue the dissection
     See https://github.com/ntop/ntopng/commit/30f52179d9f7a1eb774534def93d55c77d6070bc#diff-20b1df29540b6de59ceb6c6d2f3afdb5R387
  */
  ndpiFlow->max_extra_packets_to_check = 10;

  proto_id = ndpi_detection_process_packet(iface->get_ndpi_struct(), ndpiFlow,
					   ip_packet, ip_len, packet_time,
					   NULL);

  /*
    A DNS flow won't change to a non-DNS flow. However, this check is
    just in case for safety. What can change is the application protocol, e.g.,
    a DNS.Google can become DNS.Facebook.
  */
  switch(ndpi_get_lower_proto(proto_id)) {
  case NDPI_PROTOCOL_DNS:
    ndpiDetectedProtocol = proto_id; /* Override! */

    if(ndpiFlow->host_server_name[0] != '\0') {
      if(cli_host
	 && (ndpiFlow->protos.dns.reply_code == 0 /* no Error */)) {
	cli_host->incContactedService((char*)ndpiFlow->host_server_name);
	cli_host->incrVisitedWebSite((char*)ndpiFlow->host_server_name);
      }

      char *q = strdup((const char*)ndpiFlow->host_server_name);
      if(q) {
	if(!setDNSQuery(q))
	  /* Unable to set the DNS query, must free the memory */
	  free(q);
      }
      if(ndpiFlow->protos.dns.query_type != 0)
	protos.dns.last_query_type = ndpiFlow->protos.dns.query_type;

      if(!ndpiFlow->protos.dns.is_query) {
	/* this is a response... */
	if(ntop->getPrefs()->is_dns_decoding_enabled()) {
	  char delimiter = '@', *name = NULL;
	  char *at = (char*)strchr((const char*)ndpiFlow->host_server_name, delimiter);

	  protos.dns.last_return_code = ndpiFlow->protos.dns.reply_code;

	  /* Consider only positive DNS replies */
	  if(at != NULL)
	    name = &at[1], at[0] = '\0';
	  else if((!strstr((const char*)ndpiFlow->host_server_name, ".in-addr.arpa"))
		  && (!strstr((const char*)ndpiFlow->host_server_name, ".ip6.arpa")))
	    name = (char*)ndpiFlow->host_server_name;

	  if(name) {
#if 0
	    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[DNS] %s [query_type: %u][reply_code: %u][is_query: %u][num_queries: %u][num_answers: %u]",
					 (char*)ndpiFlow->host_server_name,
					 ndpiFlow->protos.dns.query_type,
					 ndpiFlow->protos.dns.reply_code,
					 ndpiFlow->protos.dns.is_query ? 1 : 0,
					 ndpiFlow->protos.dns.num_queries,
					 ndpiFlow->protos.dns.num_answers);
#endif


	    if(ndpiFlow->protos.dns.reply_code == 0) {
	      if(ndpiFlow->protos.dns.num_answers > 0) {
		if(at != NULL) {
		  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[DNS] %s <-> %s", name, (char*)ndpiFlow->host_server_name);
		  ntop->getRedis()->setResolvedAddress(name, (char*)ndpiFlow->host_server_name);
		}
	      }
	    }
	  }
	}
      }
    }

#ifdef HAVE_NEDGE
    updateFlowShapers(false);
#endif
    break;
  default:
    break;
  }

#if 0
  char buf[256];
  ntop->getTrace()->traceEvent(TRACE_ERROR, "%s %s", ndpiFlow->host_server_name[0] != '\0' ? ndpiFlow->host_server_name : (unsigned char*)"", print(buf, sizeof(buf)));
#endif
}

/* *************************************** */

/* Special handling of IEC60870 which is always performed. */
void Flow::processIEC60870Packet(bool tx_direction,
				 const u_char *payload, u_int16_t payload_len,
				 struct timeval *packet_time) {

  /* Exits if the flow isn't IEC60870 or it the interface is not a packet-interface */
  if(!isIEC60870()
     || (!getInterface()->isPacketInterface())
     || (payload_len < 6))
    return;

  if(iec104 == NULL)
    iec104 = new (std::nothrow) IEC104Stats();

  if(iec104)
    iec104->processPacket(this, tx_direction, payload, payload_len, packet_time);
}

/* *************************************** */

/* End the nDPI dissection on a flow. Guess the protocol if not already
 * detected. It is safe to call endProtocolDissection() multiple times. */
void Flow::endProtocolDissection() {
  if(!detection_completed) {
    u_int8_t proto_guessed;

    updateProtocol(ndpi_detection_giveup(iface->get_ndpi_struct(),
					 ndpiFlow, 1, &proto_guessed));
    setRisk(ndpi_flow_risk_bitmap | ndpiFlow->risk);
    setProtocolDetectionCompleted(NULL, 0);
  }

  if(!extra_dissection_completed)
    setExtraDissectionCompleted();
}

/* *************************************** */

/* Manually set a protocol on the flow and terminate the dissection. */
void Flow::setDetectedProtocol(ndpi_protocol proto_id) {
  updateProtocol(proto_id);
  setProtocolDetectionCompleted(NULL, 0);

  endProtocolDissection();
}

/* *************************************** */

/* Called when the extra dissection on the flow is completed. */
void Flow::setExtraDissectionCompleted() {
  if(extra_dissection_completed)
    return;

  if(!detection_completed) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Bad internal status: setExtraDissectionCompleted called before setDetectedProtocol");
    return;
  }

  if((protocol == IPPROTO_TCP)
     || (protocol == IPPROTO_UDP)
     || (protocol == IPPROTO_ICMP)
     || (protocol == IPPROTO_ICMPV6)
     ) {
    /* nDPI is not allocated for non-TCP non-UDP flows so, in order to
       make sure custom cateories are properly populated, function ndpi_fill_ip_protocol_category
       must be called explicitly. */
    if(get_cli_ip_addr()->get_ipv4() && get_srv_ip_addr()->get_ipv4() /* Only IPv4 is supported */) {
      ndpi_fill_ip_protocol_category(iface->get_ndpi_struct(),
				     get_cli_ip_addr()->get_ipv4(), get_srv_ip_addr()->get_ipv4(),
				     &ndpiDetectedProtocol);
      stats.setDetectedProtocol(&ndpiDetectedProtocol);
    }
  }

  if(ndpiFlow) {
    setErrorCode(ndpi_get_flow_error_code(ndpiFlow));

    if(ndpiDetectedProtocol.protocol_by_ip != NDPI_PROTOCOL_UNKNOWN) {
      char *p = ndpi_get_proto_name(iface->get_ndpi_struct(), ndpiDetectedProtocol.protocol_by_ip);

      setAddressFamilyProtocol(p);
    }
  }

  processExtraDissectedInformation();

  extra_dissection_completed = 1;
}

/* *************************************** */

void Flow::updateProtocol(ndpi_protocol proto_id) {
  /* NOTE: in order to avoid inconsistent states, only overwrite the
   * protocools if UNKNOWN. */
  if(ndpiDetectedProtocol.master_protocol == NDPI_PROTOCOL_UNKNOWN)
    ndpiDetectedProtocol.master_protocol = proto_id.master_protocol;

  if((ndpiDetectedProtocol.app_protocol == NDPI_PROTOCOL_UNKNOWN)
     || (/*
	   Update the protocols when adding a subprotocol, not when things
	   are totally different
	 */
	 (ndpiDetectedProtocol.master_protocol == ndpiDetectedProtocol.app_protocol)
	 && (ndpiDetectedProtocol.app_protocol != proto_id.app_protocol)))
    ndpiDetectedProtocol.app_protocol = proto_id.app_protocol;

  if(ndpiDetectedProtocol.master_protocol == ndpiDetectedProtocol.app_protocol)
    ndpiDetectedProtocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;

  ndpiDetectedProtocol.protocol_by_ip = proto_id.protocol_by_ip;

  /* NOTE: only overwrite the category if it was not set.
   * This prevents overwriting already determined category (e.g. by IP or Host)
   */
  if(ndpiDetectedProtocol.category == NDPI_PROTOCOL_CATEGORY_UNSPECIFIED)
    ndpiDetectedProtocol.category = proto_id.category;
}

/* *************************************** */

/* Called to update the flow protocol and possibly advance the flow to
 * the protocol_detected state. */
void Flow::setProtocolDetectionCompleted(u_int8_t *payload, u_int16_t payload_len) {
  if(detection_completed)
    return;

  stats.setDetectedProtocol(&ndpiDetectedProtocol);

  /* Process detected protocol and doesn't need ndpiFlow not allocated for non-packet interfaces */
  processDetectedProtocol(payload, payload_len);

  /* Process detected protocol data and needs ndpiFlow only allocated for packet interfaces */
  processDetectedProtocolData();

  detection_completed = 1;

#ifdef BLACKLISTED_FLOWS_DEBUG
  if(ndpiDetectedProtocol.category == CUSTOM_CATEGORY_MALWARE) {
    char buf[512];
    print(buf, sizeof(buf));
    snprintf(&buf[strlen(buf)], sizeof(buf) - strlen(buf),
	     "Malware category detected. [cli_blacklisted: %u][srv_blacklisted: %u][category: %s]",
	     isBlacklistedClient(), isBlacklistedServer(), get_protocol_category_name());
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", buf);
  }
#endif

#ifdef NTOPNG_PRO
#ifdef HAVE_NEDGE
  updateFlowShapers(true);
#else
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

char* Flow::printTCPflags(u_int8_t flags, char * const buf, u_int buf_len) {
  snprintf(buf, buf_len, "%s%s%s%s%s%s%s%s",
	   (flags & TH_SYN) ? " SYN" : "",
	   (flags & TH_ACK) ? " ACK" : "",
	   (flags & TH_FIN) ? " FIN" : "",
	   (flags & TH_RST) ? " RST" : "",
	   (flags & TH_PUSH) ? " PUSH" : "",
	   (flags & TH_URG) ? " URG" : "",
	   (flags & TH_ECE) ? " ECE" : "",
	   (flags & TH_CWR) ? " CWR" : "");

  if(buf[0] == ' ')
    return(&buf[1]);
  else
    return(buf);
}

/* ****************************************************** */

char * Flow::printTCPState(char * const buf, u_int buf_len) const {
  snprintf(buf, buf_len, "%s%s%s%s",
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
  char buf1[32], buf2[32], buf3[32], buf4[32], buf5[32], pbuf[32], tcp_buf[64];
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
	   "%s %s:%u &gt; %s:%u [first: %u][last: %u][proto: %u.%u/%s][cat: %u/%s][device: %u in: %u out:%u]"
	   "[%u/%u pkts][%llu/%llu bytes][flags src2dst: %s][flags dst2stc: %s][state: %s]"
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
	   printTCPState(buf5, sizeof(buf5)),
	   (isTLS() && protos.tls.server_names) ? "[" : "",
	   (isTLS() && protos.tls.server_names) ? protos.tls.server_names : "",
	   (isTLS() && protos.tls.server_names) ? "]" : ""
#if defined(NTOPNG_PRO) && defined(SHAPER_DEBUG)
	   , shapers
#endif
	   );

  return(buf);
}

/* *************************************** */

bool Flow::dump(time_t t, bool last_dump_before_free) {
  bool rc = false;

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

  if(!last_dump_before_free) {
    if((getInterface()->getIfType() == interface_type_PCAP_DUMP
	&& (!getInterface()->read_from_pcap_dump_done()))
       || !timeToPeriodicDump(t)
       || last_db_dump.in_progress) {
      return(rc); /* Don't call too often periodic flow dump */
    }
  }

  /* Add protocol information in the JSON field (if not already set by alerts) */
  setProtocolJSONInfo();

  getInterface()->dumpFlow(get_last_seen(), this);

#ifndef HAVE_NEDGE
  if(ntop->get_export_interface()) {
    char *json = serialize(false);

    if(json) {
      ntop->get_export_interface()->export_data(json);
      free(json);
    }
  }
#endif

  return(true);
}

/* *************************************** */

void Flow::setDropVerdict() {
#if defined(HAVE_NEDGE)
  if((iface->getIfType() == interface_type_NETFILTER) && (passVerdict == 1))
    ((NetfilterInterface *) iface)->setPolicyChanged();
#endif

  passVerdict = 0;
}

/* *************************************** */

#ifdef HAVE_NEDGE
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
    flow_dropped_counts_increased = 1;
  }
}
#endif

/* *************************************** */

/* NOTE: this function is periodically executed both on normal interfaces
 * and ViewInterface. On ViewInterface, the cli_host and srv_host *do not*
 * correspond to the flow hosts (which remain NULL). This is the correct
 * place to increment stats on cli/srv hosts and make them work with ViewInterfaces.
 *
 * const is *required* here as the flow must not be modified (as it could go in concuncurrency
 * with the subinterfaces). */
void Flow::hosts_periodic_stats_update(NetworkInterface *iface, Host *cli_host, Host *srv_host,
				       PartializableFlowTrafficStats *partial,
				       bool first_partial, const struct timeval *tv) {
  update_pools_stats(iface, cli_host, srv_host, tv, partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
		     partial->get_srv2cli_packets(), partial->get_srv2cli_bytes());

  if(cli_host && srv_host) {
    bool cli_and_srv_in_same_subnet = false;
    bool cli_and_srv_in_same_country = false;
    VLAN *vl;
    int16_t cli_network_id = cli_host->get_local_network_id();
    int16_t srv_network_id = srv_host->get_local_network_id();
    int16_t stats_protocol = getStatsProtocol(); /* The protocol (among ndpi master_ and app_) that is chosen to increase stats */
    NetworkStats *cli_network_stats = NULL, *srv_network_stats = NULL;

    if(cli_network_id >= 0 && (cli_network_id == srv_network_id))
      cli_and_srv_in_same_subnet = true;

    cli_host->incCliContactedHosts(srv_host->get_ip());
    srv_host->incSrvHostContacts(cli_host->get_ip());

    if(iface && (vl = iface->getVLAN(vlanId, false, false /* NOT an inline call */))) {
      /* Note: source and destination hosts have, by definition, the same VLAN so the increase is done only one time. */
      /* Note: vl will never be null as we're in a flow with that vlan. Hence, it is guaranteed that at least
	 two hosts exists for that vlan and that any purge attempt will be prevented. */
#ifdef VLAN_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Increasing VLAN %u stats", vlanId);
#endif
      vl->incStats(tv->tv_sec, stats_protocol,
		   partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
		   partial->get_srv2cli_packets(), partial->get_srv2cli_bytes());
    }

    // Update local stats (local vs remote)
    // this replaces the old call to Flow::updateInterfaceLocalStats from packet processing
    iface->incLocalStats(partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
			 cli_host->isLocalHost(), srv_host->isLocalHost());
    iface->incLocalStats(partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(),
			 srv_host->isLocalHost(), cli_host->isLocalHost());

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
	cli_as->incStats(tv->tv_sec, stats_protocol, partial->get_cli2srv_packets(),
			 partial->get_cli2srv_bytes(), partial->get_srv2cli_packets(),
			 partial->get_srv2cli_bytes());
      if(srv_as)
	srv_as->incStats(tv->tv_sec, stats_protocol, partial->get_srv2cli_packets(),
			 partial->get_srv2cli_bytes(), partial->get_cli2srv_packets(),
			 partial->get_cli2srv_bytes());
    }

  if(cli_host->get_observation_point_id() && srv_host->get_observation_point_id()) {
      ObservationPoint *cli_obs_point = cli_host ? cli_host->get_obs_point() : NULL,
  *srv_obs_point = srv_host ? srv_host->get_obs_point() : NULL;

      if(cli_obs_point)
  cli_obs_point->incStats(tv->tv_sec, stats_protocol, partial->get_cli2srv_packets(),
       partial->get_cli2srv_bytes(), partial->get_srv2cli_packets(),
       partial->get_srv2cli_bytes());
      if(srv_obs_point)
  srv_obs_point->incStats(tv->tv_sec, stats_protocol, partial->get_srv2cli_packets(),
       partial->get_srv2cli_bytes(), partial->get_cli2srv_packets(),
       partial->get_cli2srv_bytes());
  }

  if(cli_host->getOS() != srv_host->getOS()) {
	cli_host->incOSStats(tv->tv_sec, stats_protocol, partial->get_cli2srv_packets(),
			 partial->get_cli2srv_bytes(), partial->get_srv2cli_packets(),
			 partial->get_srv2cli_bytes());
	srv_host->incOSStats(tv->tv_sec, stats_protocol, partial->get_srv2cli_packets(),
			 partial->get_srv2cli_bytes(), partial->get_cli2srv_packets(),
			 partial->get_cli2srv_bytes());
    }
    // Update client DSCP stats
    cli_host->incDSCPStats(getCli2SrvDSCP(),
      partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
      partial->get_srv2cli_packets(), partial->get_srv2cli_bytes());

    // Update server DSCP stats
    srv_host->incDSCPStats(getSrv2CliDSCP(),
      partial->get_srv2cli_packets(), partial->get_srv2cli_bytes(),
      partial->get_cli2srv_packets(), partial->get_cli2srv_bytes());

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

  // Update interface DSCP stats
  if(iface) {
    iface->incDSCPStats(getCli2SrvDSCP(),
      partial->get_cli2srv_packets(), partial->get_cli2srv_bytes(),
      partial->get_srv2cli_packets(), partial->get_srv2cli_bytes());
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
    if(srv_host) {
      if(!Utils::isIPAddress(host_server_name) && hasRisk(NDPI_HTTP_NUMERIC_IP_HOST)) {
        srv_host->offlineSetHTTPName(host_server_name);
      }

      if(srv_host->getHTTPstats()
         && host_server_name
         && isThreeWayHandshakeOK()) {
        srv_host->getHTTPstats()->updateHTTPHostRequest(tv->tv_sec, host_server_name,
                  partial->get_num_http_requests(),
                  partial->get_cli2srv_bytes(),
                  partial->get_srv2cli_bytes());
      }
    }
    break;

  case NDPI_PROTOCOL_DNS:
    if(cli_host && cli_host->getDNSstats())
      cli_host->getDNSstats()->incStats(true  /* Client */, partial->get_flow_dns_stats());
    if(srv_host && srv_host->getDNSstats())
      srv_host->getDNSstats()->incStats(false /* Server */, partial->get_flow_dns_stats());
    if(cli_host && srv_host) {
      if(cli_host->incDNSContactCardinality(srv_host)) {
#ifdef NTOPNG_PRO
	ntop->get_am()->addClientServerUsage(cli_host, srv_host, dns_server, NULL /* no DNS server name */);
#endif
      }
    }
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
      if(protos.netbios.name) cli_host->offlineSetNetbiosName(protos.netbios.name);
    }
    break;

  case NDPI_PROTOCOL_NTP:
    if(cli_host && srv_host) {
      if(cli_host->incNTPContactCardinality(srv_host)) {
#ifdef NTOPNG_PRO
	ntop->get_am()->addClientServerUsage(cli_host, srv_host, ntp_server, NULL /* no NTP server name */);
#endif
      }
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

  case NDPI_PROTOCOL_MAIL_SMTPS:
  case NDPI_PROTOCOL_MAIL_SMTP:
    if(cli_host && srv_host) {
      if(cli_host->incSMTPContactCardinality(srv_host)) {
#ifdef NTOPNG_PRO
	ntop->get_am()->addClientServerUsage(cli_host, srv_host, smtp_server, getFlowServerInfo());
#endif
      }
    }
    break;

  case NDPI_PROTOCOL_MAIL_IMAPS:
  case NDPI_PROTOCOL_MAIL_IMAP:
    if(cli_host && srv_host) {
      if(cli_host->incIMAPContactCardinality(srv_host)) {
#ifdef NTOPNG_PRO
	ntop->get_am()->addClientServerUsage(cli_host, srv_host, imap_server, getFlowServerInfo());
#endif
      }
    }
    break;

  case NDPI_PROTOCOL_MAIL_POPS:
  case NDPI_PROTOCOL_MAIL_POP:
    if(cli_host && srv_host) {
      if(cli_host->incPOPContactCardinality(srv_host)) {
#ifdef NTOPNG_PRO
	ntop->get_am()->addClientServerUsage(cli_host, srv_host, pop_server, getFlowServerInfo());
#endif
      }
    }
    break;

  default:
    break;
  }

  if(srv_host
     && isTLS()
     && !hasRisk(NDPI_TLS_CERTIFICATE_MISMATCH)
     && !Utils::isIPAddress(protos.tls.client_requested_server_name))
    srv_host->offlineSetTLSName(protos.tls.client_requested_server_name);
}

/* *************************************** */

void Flow::updateThroughputStats(float tdiff_msec,
				 u_int32_t diff_sent_packets, u_int64_t diff_sent_bytes, u_int64_t diff_sent_goodput_bytes,
				 u_int32_t diff_rcvd_packets, u_int64_t diff_rcvd_bytes, u_int64_t diff_rcvd_goodput_bytes) {
  if(tdiff_msec == 0)
    return;
  else {
    // bps
    float bytes_msec_cli2srv         = ((float)(diff_sent_bytes*1000))/tdiff_msec;
    float bytes_msec_srv2cli         = ((float)(diff_rcvd_bytes*1000))/tdiff_msec;
    float bytes_msec                 = bytes_msec_cli2srv + bytes_msec_srv2cli;

    float goodput_bytes_msec_cli2srv = ((float)(diff_sent_goodput_bytes*1000))/tdiff_msec;
    float goodput_bytes_msec_srv2cli = ((float)(diff_rcvd_goodput_bytes*1000))/tdiff_msec;
    float goodput_bytes_msec         = goodput_bytes_msec_cli2srv + goodput_bytes_msec_srv2cli;

    /* Just to be safe */
    if(bytes_msec < 0)                 bytes_msec                 = 0;
    if(bytes_msec_cli2srv < 0)         bytes_msec_cli2srv         = 0;
    if(bytes_msec_srv2cli < 0)         bytes_msec_srv2cli         = 0;
    if(goodput_bytes_msec < 0)         goodput_bytes_msec         = 0;
    if(goodput_bytes_msec_cli2srv < 0) goodput_bytes_msec_cli2srv = 0;
    if(goodput_bytes_msec_srv2cli < 0) goodput_bytes_msec_srv2cli = 0;

    if((bytes_msec > 0) || iface->isPacketInterface()) {
      // refresh trend stats for the overall throughput
      if(get_bytes_thpt() < bytes_msec)      bytes_thpt_trend = trend_up;
      else if(get_bytes_thpt() > bytes_msec) bytes_thpt_trend = trend_down;
      else                                   bytes_thpt_trend = trend_stable;

      // refresh goodput stats for the overall throughput
      if(get_goodput_bytes_thpt() < goodput_bytes_msec)      goodput_bytes_thpt_trend = trend_up;
      else if(get_goodput_bytes_thpt() > goodput_bytes_msec) goodput_bytes_thpt_trend = trend_down;
      else                                                   goodput_bytes_thpt_trend = trend_stable;

      // update the old values with the newly calculated ones
      bytes_thpt_cli2srv         = bytes_msec_cli2srv;
      bytes_thpt_srv2cli         = bytes_msec_srv2cli;
      goodput_bytes_thpt_cli2srv = goodput_bytes_msec_cli2srv;
      goodput_bytes_thpt_srv2cli = goodput_bytes_msec_srv2cli;

#if DEBUG_TREND
      u_int64_t diff_bytes = diff_sent_bytes + diff_rcvd_bytes;
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[tdiff_msec: %.2f][diff_bytes: %lu][diff_sent_bytes: %lu][diff_rcvd_bytes: %lu][bytes_thpt: %.4f]",
				   tdiff_msec, diff_bytes, diff_sent_bytes, diff_rcvd_bytes, get_bytes_thpt() * 8);
#endif

      if(top_bytes_thpt < get_bytes_thpt()) top_bytes_thpt = get_bytes_thpt();
      if(top_goodput_bytes_thpt < get_goodput_bytes_thpt()) top_goodput_bytes_thpt = get_goodput_bytes_thpt();

#ifdef NTOPNG_PRO
      throughputTrend.update(get_bytes_thpt()), goodputTrend.update(get_goodput_bytes_thpt());
      thptRatioTrend.update((bytes_msec != 0) ? (((double)(goodput_bytes_msec*100))/(double)bytes_msec) : 0);

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

      if(get_pkts_thpt() < pkts_msec)      pkts_thpt_trend = trend_up;
      else if(get_pkts_thpt() > pkts_msec) pkts_thpt_trend = trend_down;
      else                                 pkts_thpt_trend = trend_stable;

      pkts_thpt_cli2srv = pkts_msec_cli2srv;
      pkts_thpt_srv2cli = pkts_msec_srv2cli;
      if(top_pkts_thpt < get_pkts_thpt()) top_pkts_thpt = get_pkts_thpt();

#if DEBUG_TREND
      u_int64_t diff_pkts = diff_sent_packets + diff_rcvd_packets;
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[msec: %.1f][tdiff: %f][pkts: %lu][pkts_thpt: %.2f pps]",
				   pkts_msec, tdiff_msec, diff_pkts, get_pkts_thpt());
#endif
    }
  }
}

/* *************************************** */

void Flow::periodic_stats_update(const struct timeval *tv) {
  bool first_partial;
  PartializableFlowTrafficStats partial;
  Host *cli_h = NULL, *srv_h = NULL;
  get_partial_traffic_stats(&periodic_stats_update_partial, &partial, &first_partial);

  u_int32_t diff_sent_packets = partial.get_cli2srv_packets();
  u_int64_t diff_sent_bytes = partial.get_cli2srv_bytes();
  u_int64_t diff_sent_goodput_bytes = partial.get_cli2srv_goodput_bytes();

  u_int32_t diff_rcvd_packets = partial.get_srv2cli_packets();
  u_int64_t diff_rcvd_bytes = partial.get_srv2cli_bytes();
  u_int64_t diff_rcvd_goodput_bytes = partial.get_srv2cli_goodput_bytes();

  get_actual_peers(&cli_h, &srv_h); /* Do the stats update on the actual peers, i.e., peers possibly swapped due to the heuristic */

  Mac *cli_mac = cli_h ? cli_h->getMac() : NULL;
  Mac *srv_mac = srv_h ? srv_h->getMac() : NULL;

  hosts_periodic_stats_update(getInterface(), cli_h, srv_h, &partial, first_partial, tv);

  if(cli_h && srv_h) {
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
  } /* Closes if(cli_h && srv_h) */

#ifndef HAVE_NEDGE /* For nEdge check Flow::setPacketsBytes */
  /* Non-Packet interfaces (e.g., ZMQ) have flow throughput stats updated as soon as the flow is received.
     This makes throughput more precise as it is averaged on a timespan which is last-first switched. */
  if(iface->isPacketInterface() && last_update_time.tv_sec > 0) {
    float tdiff_msec = Utils::msTimevalDiff(tv, &last_update_time);
    updateThroughputStats(tdiff_msec,
			  diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
			  diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes);

  }
#endif

  memcpy(&last_update_time, tv, sizeof(struct timeval));
  GenericHashEntry::periodic_stats_update(tv);
}

/* *************************************** */

void Flow::dumpCheck(time_t t, bool last_dump_before_free) {

  if((ntop->getPrefs()->is_flows_dump_enabled()
#ifndef HAVE_NEDGE
      || ntop->get_export_interface()
#endif
     )
#ifdef NTOPNG_PRO
     && (getInterface()->isPacketInterface() /* Not a ZMQ interface */
         || !ntop->getPrefs()->do_dump_flows_direct() /* Direct dump not enabled */ )
#endif
    ) {
    dump(t, last_dump_before_free);
  }
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
  u_int16_t cli_host_pool_id = 0, srv_host_pool_id;
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
      if(!cli_host || (srv_host_pool_id != cli_host_pool_id)) {
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
		 VLANid _vlanId, u_int16_t _observation_point_id,
		 u_int32_t _private_flow_id, u_int8_t _protocol,
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

  if(getPrivateFlowId() != _private_flow_id)
    return(false);

  if((get_vlan_id() != _vlanId)
#ifdef MAKE_OBSERVATION_POINT_KEY
     /*
       Uncomment the line below if you want the same host
       seen from various observation points, to be considered
       a unique host */
     || (get_observation_point_id() != _observation_point_id)
#endif
    )
    return(false);

  if(_protocol != protocol)
    return(false);

#ifdef DONT_MERGE_ICMP_FLOWS
  if(icmp_info && !icmp_info->equal(_icmp_info))
    return(false);
#endif

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

void Flow::luaScore(lua_State* vm) {
  u_int32_t tot;

  lua_newtable(vm);

  lua_push_int32_table_entry(vm, "flow_score", getScore());

  /* ***************************************** */

  lua_newtable(vm);
  for(u_int i=0; i<MAX_NUM_SCORE_CATEGORIES; i++) {
    ScoreCategory score_category = (ScoreCategory)i;
    char tmp[8];

    snprintf(tmp, sizeof(tmp), "%u", i);
    lua_push_int32_table_entry(vm, tmp, stats.get_cli_score(score_category) + stats.get_srv_score(score_category));
  }

  lua_pushstring(vm, "host_categories_total");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* ***************************************** */

  lua_newtable(vm);

  tot = 0;
  for(u_int i=0; i<MAX_NUM_SCORE_CATEGORIES; i++) {
    ScoreCategory score_category = (ScoreCategory)i;
    tot += stats.get_cli_score(score_category);
  }
  lua_push_int32_table_entry(vm, "client_score", tot);

  tot = 0;
  for(u_int i=0; i<MAX_NUM_SCORE_CATEGORIES; i++) {
    ScoreCategory score_category = (ScoreCategory)i;
    tot += stats.get_srv_score(score_category);
  }
  lua_push_int32_table_entry(vm, "server_score", tot);

  lua_pushstring(vm, "host_score_total");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* ***************************************** */

  lua_pushstring(vm, "score");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void Flow::lua(lua_State* vm, AddressTree * ptree,
	       DetailsLevel details_level, bool skipNewTable) {
  const IpAddress *src_ip = get_cli_ip_addr(), *dst_ip = get_srv_ip_addr();
  bool src_match = true, dst_match = true;
  bool mask_flow;
  bool has_json_info = false;
  u_char community_id[200];
  char buf[64];

  if(ptree) {
    if(src_ip) src_match = src_ip->match(ptree);
    if(dst_ip) dst_match = dst_ip->match(ptree);
    if(!src_match && !dst_match) return;
  }

  if(!skipNewTable)
    lua_newtable(vm);

  lua_get_ip(vm, true  /* Client */);
  lua_get_ip(vm, false /* Server */);
  lua_push_uint32_table_entry(vm, "vlan", get_vlan_id());
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

    /* See VLANAddressTree.h for details */
    lua_push_uint32_table_entry(vm, "observation_point_id", get_observation_point_id());

    if(srcAS)
      lua_push_int32_table_entry(vm, "src_as", srcAS);
    else {
      Host *h = get_cli_host();

      if(h) {
	lua_push_int32_table_entry(vm, "src_as", h->get_asn());
	lua_push_str_table_entry(vm, "src_as_name", h->get_asname());
      }
    }

    if(dstAS)
      lua_push_int32_table_entry(vm, "dst_as", dstAS);
    else {
      Host *h = get_srv_host();

      if(h) {
	lua_push_int32_table_entry(vm, "dst_as", h->get_asn());
	lua_push_str_table_entry(vm, "dst_as_name", h->get_asname());
      }
    }

    if(prevAdjacentAS) lua_push_int32_table_entry(vm, "prev_adjacent_as", prevAdjacentAS);
    if(nextAdjacentAS)lua_push_int32_table_entry(vm, "next_adjacent_as", nextAdjacentAS);

    lua_tos(vm);
    lua_get_protocols(vm);
    lua_push_str_table_entry(vm, "community_id",
			     (char*)getCommunityId(community_id, sizeof(community_id)));

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

    luaScore(vm);

    if(isICMP()) {
      lua_newtable(vm);

      if(isBidirectional()) {
	lua_push_uint64_table_entry(vm, "type", protos.icmp.srv2cli.icmp_type);
	lua_push_uint64_table_entry(vm, "code", protos.icmp.srv2cli.icmp_code);
      } else {
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

    lua_push_int32_table_entry(vm, "flow_serial", flow_serial);

#ifdef HAVE_NEDGE
    if(iface->is_bridge_interface())
      lua_push_bool_table_entry(vm, "verdict.pass", isPassVerdict() ? 1 : 0);
#else
    if(!passVerdict)
      lua_push_bool_table_entry(vm, "verdict.pass", 0);
#endif

    if(get_protocol() == IPPROTO_TCP)
      lua_get_tcp_info(vm);

    if(!mask_flow) {
      char buf[64];
      char *info = getFlowInfo(buf, sizeof(buf), true);

      if(host_server_name) lua_push_str_table_entry(vm, "host_server_name", host_server_name);
      if(suspicious_dga_domain) lua_push_str_table_entry(vm, "suspicious_dga_domain", suspicious_dga_domain);
      if(bt_hash)          lua_push_str_table_entry(vm, "bittorrent_hash", bt_hash);
      lua_push_str_table_entry(vm, "info", info ? info : (char*)"");
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

    if(!getInterface()->isPacketInterface())
      lua_snmp_info(vm);

    lua_push_int32_table_entry(vm, "l7_error_code", getErrorCode());
    lua_push_int32_table_entry(vm, "flow_verdict", flow_verdict);

    if(flow_payload != NULL) {
      flow_payload[flow_payload_len] = '\0';
      lua_push_str_table_entry(vm, "flow_payload", flow_payload);
    }

    if(get_json_info()) {
      lua_push_str_table_entry(vm, "moreinfo.json", json_object_to_json_string(get_json_info()));
      has_json_info = true;
    } else if(get_tlv_info()) {
      ndpi_deserializer deserializer;

      if(ndpi_init_deserializer(&deserializer, get_tlv_info()) == 0) {
        ndpi_serializer serializer;

        if(ndpi_init_serializer(&serializer, ndpi_serialization_format_json) >= 0) {
          char *buffer;
          u_int32_t buffer_len;

          ndpi_deserialize_clone_all(&deserializer, &serializer);
          buffer = ndpi_serializer_get_buffer(&serializer, &buffer_len);

          if(buffer) {
            lua_push_str_table_entry(vm, "moreinfo.json", buffer);
            has_json_info = true;
          }

          ndpi_term_serializer(&serializer);
        }
      }
    }

    if(iec104) iec104->lua(vm);

    if(!has_json_info)
      lua_push_str_table_entry(vm, "moreinfo.json", "{}");

    if(ebpf) ebpf->lua(vm);

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
    lua_confidence(vm);
    lua_get_risk_info(vm);
    lua_entropy(vm);

    if(getJSONRiskInfo())
      lua_push_str_table_entry(vm, "riskInfo", getJSONRiskInfo());
  }

  lua_get_status(vm);

  lua_push_str_table_entry(vm, "proto.ndpi",
			   detection_completed ? get_detected_protocol_name(buf, sizeof(buf)) : (char*)CONST_TOO_EARLY);

  // this is used to dynamicall update entries in the GUI
  lua_push_uint64_table_entry(vm, "ntopng.key", key()); // Key
  lua_push_uint64_table_entry(vm, "hash_entry_id", get_hash_entry_id());
}

/* *************************************** */

void Flow::lua_confidence(lua_State* vm) {
  switch(getConfidence()) {
  case NDPI_CONFIDENCE_DPI_CACHE:
  case NDPI_CONFIDENCE_DPI_PARTIAL_CACHE:
  case NDPI_CONFIDENCE_DPI:
  case NDPI_CONFIDENCE_NBPF:
    lua_push_uint32_table_entry(vm, "confidence", (ndpiConfidence) confidence_dpi);
    break;

  default:
    lua_push_uint32_table_entry(vm, "confidence", (ndpiConfidence) confidence_guessed);
    break;
  }
}

/* *************************************** */

void Flow::lua_tos(lua_State* vm) {
  lua_newtable(vm);

  lua_newtable(vm);
  lua_push_int32_table_entry(vm, "DSCP", getCli2SrvDSCP());
  lua_push_int32_table_entry(vm, "ECN",  getCli2SrvECN());
  lua_pushstring(vm, "client");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* *********************** */

  lua_newtable(vm);
  lua_push_int32_table_entry(vm, "DSCP", getSrv2CliDSCP());
  lua_push_int32_table_entry(vm, "ECN",  getSrv2CliECN());
  lua_pushstring(vm, "server");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_pushstring(vm, "tos");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void Flow::lua_get_risk_info(lua_State* vm) {
  if(ndpi_flow_risk_bitmap != 0) {
    ndpi_risk unhandled_ndpi_risks = ntop->getUnhandledRisks();

    if(unhandled_ndpi_risks & ndpi_flow_risk_bitmap) {
      /* This flow has some unhandled risks, that is, risks set by nDPI but not handled by flow checks */

      lua_newtable(vm);

      for(u_int i = 0; i < NDPI_MAX_RISK; i++)
	if(hasRisk((ndpi_risk_enum)i) && NDPI_ISSET_BIT(unhandled_ndpi_risks, (ndpi_risk_enum)i))
	  lua_push_uint64_table_entry(vm, ndpi_risk2str((ndpi_risk_enum)i), i);

      lua_pushstring(vm, "unhandled_flow_risk");
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }
}

/* *************************************** */

void Flow::setRisk(ndpi_risk risk_bitmap) {
  /* Handle OR of risks with no risk */
  NDPI_CLR_BIT(risk_bitmap, NDPI_NO_RISK);

  if(risk_bitmap == 0)
    NDPI_SET_BIT(risk_bitmap, NDPI_NO_RISK);

  ndpi_flow_risk_bitmap = risk_bitmap;

  has_malicious_cli_signature = NDPI_ISSET_BIT(ndpi_flow_risk_bitmap, NDPI_MALICIOUS_JA3);
}

/* *************************************** */

void Flow::addRisk(ndpi_risk risk_bitmap) {
  setRisk(ndpi_flow_risk_bitmap | risk_bitmap);
}

/* *************************************** */

bool Flow::hasRisk(ndpi_risk_enum r) const {
  if(r < NDPI_MAX_RISK)
    return NDPI_ISSET_BIT(ndpi_flow_risk_bitmap, r);

  return false;
}

/* *************************************** */

/* Returns true if at least one nDPI flow risk is set */
bool Flow::hasRisks() const {
  for(int i = 0; i < NDPI_MAX_RISK; i++) {
    if(hasRisk((ndpi_risk_enum)i))
      return true;
  }

  return false;
}

/* *************************************** */

void Flow::clearRisks() {
  ndpi_flow_risk_bitmap = 0;
  NDPI_SET_BIT(ndpi_flow_risk_bitmap, NDPI_NO_RISK);
}

/* *************************************** */

u_int32_t Flow::key() {
  u_int32_t k = cli_port + srv_port + vlanId + protocol + privateFlowId;

#ifdef MAKE_OBSERVATION_POINT_KEY
  k += get_observation_point_id();
#endif

  if(get_cli_ip_addr()) k += get_cli_ip_addr()->key();
  if(get_srv_ip_addr()) k += get_srv_ip_addr()->key();
  if(icmp_info)         k += icmp_info->key();

  return(k);
}

/* *************************************** */

u_int32_t Flow::key(Host *_cli, u_int16_t _cli_port,
		    Host *_srv, u_int16_t _srv_port,
		    VLANid _vlan_id, u_int16_t _observation_point_id,
		    u_int16_t _protocol) {
  u_int32_t k = _cli_port + _srv_port + _vlan_id + _protocol;

#ifdef MAKE_OBSERVATION_POINT_KEY
  k += _observation_point_id;
#endif

  if(_cli) k += _cli -> key();
  if(_srv) k += _srv -> key();

  return(k);
}

/* *************************************** */

void Flow::set_hash_entry_id(u_int32_t assigned_hash_entry_id) {
  hash_entry_id = assigned_hash_entry_id;
};

/* *************************************** */

u_int32_t Flow::get_hash_entry_id() const {
  return(hash_entry_id);
};

/* *************************************** */

bool Flow::is_hash_entry_state_idle_transition_ready() {
  bool ret = false;

#ifdef EXPIRE_FLOWS_IMMEDIATELY
  return(true); /* Debug only */
#endif

#ifdef HAVE_NEDGE
  if(iface->getIfType() == interface_type_NETFILTER)
    return(isNetfilterIdleFlow());
#endif

  if(iface->getIfType() == interface_type_ZMQ ||
     iface->getIfType() == interface_type_SYSLOG) {
    ret = is_active_entry_now_idle(iface->getFlowMaxIdle());

  } else {
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
	 && (iface->getTimeLastPktRcvd() > doNotExpireBefore)
	 && is_active_entry_now_idle(MAX_TCP_FLOW_IDLE)) {
	/* ntop->getTrace()->traceEvent(TRACE_NORMAL, "[TCP] Early flow expire"); */
	ret = true;
      }
    }

    if(!ret)
      ret = is_active_entry_now_idle(iface->getFlowMaxIdle());
  }

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s() [uses: %u][time: %d][idle: %s]",
			       __FUNCTION__, getUses(),
			       (last_seen + iface->getFlowMaxIdle()) - iface->getTimeLastPktRcvd(),
			       ret ? "true" : "false");

  if(ret)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s] Idle flow found", iface->get_name());
#endif

  if(ret && ((iface->getTimeLastPktRcvd()-flowCreationTime) < 10 /* sec */)) {
    /*
      Trick to keep flows a minimum amount of time in memory
      and thus avoid quick purging
    */
    ret = false;
  }

  return(ret);
}

/* *************************************** */

void Flow::sumStats(nDPIStats *ndpi_stats, FlowStats *status_stats) {
  ndpi_protocol detected_protocol = get_detected_protocol();

  if(detected_protocol.app_protocol != detected_protocol.master_protocol
     && detected_protocol.app_protocol != NDPI_PROTOCOL_UNKNOWN) {
    ndpi_stats->incStats(0, detected_protocol.app_protocol,
			 get_packets_cli2srv(), get_bytes_cli2srv(),
			 get_packets_srv2cli(), get_bytes_srv2cli());
    ndpi_stats->incFlowsStats(detected_protocol.app_protocol);
  } else {
    ndpi_stats->incStats(0, detected_protocol.master_protocol,
		       get_packets_cli2srv(), get_bytes_cli2srv(),
		       get_packets_srv2cli(), get_bytes_srv2cli());
    ndpi_stats->incFlowsStats(detected_protocol.master_protocol);
  }

  status_stats->incStats(getAlertsBitmap(), protocol, Utils::mapScoreToSeverity(getPredominantAlertScore()), getCli2SrvDSCP(), getSrv2CliDSCP(), this);
}

/* *************************************** */

char* Flow::serialize(bool use_labels) {
  json_object *my_object;
  char *rsp = NULL;

  ntop->getPrefs()->set_json_symbolic_labels_format(use_labels);

  my_object = flow2JSON();

  if(my_object != NULL) {
    /* JSON string */
    rsp = strdup(json_object_to_json_string(my_object));

    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Emitting Flow: %s", rsp);

    /* Free memory */
    json_object_put(my_object);
  }

  return(rsp);
}

/* *************************************** */

void Flow::formatECSObserver(json_object *my_object) {
  json_object *observer_object;
  if((observer_object = json_object_new_object()) != NULL) {
    json_object_object_add(observer_object, "product", json_object_new_string("ntopng"));
    json_object_object_add(observer_object, "vendor", json_object_new_string("ntop"));

    if(ntop->getPrefs() && ntop->getPrefs()->get_instance_name())
      json_object_object_add(observer_object, "name", json_object_new_string(ntop->getPrefs()->get_instance_name()));

    json_object_object_add(my_object, "observer", observer_object);
  }
}

/* *************************************** */

void Flow::formatECSEvent(json_object *my_object) {
  json_object *event_object;
  if((event_object = json_object_new_object()) != NULL) {
    json_object_object_add(event_object, "risk_score", json_object_new_int(getScore()));
    json_object_object_add(my_object, "event", event_object);
  }
}

/* *************************************** */

void Flow::formatECSInterface(json_object *my_object) {
  json_object *interface_object;
  if((interface_object = json_object_new_object()) != NULL) {
    json_object_object_add(interface_object, "id", json_object_new_int(iface->get_id()));

    if(iface && iface->get_name())
      json_object_object_add(interface_object, "name", json_object_new_string(iface->get_name()));

    json_object_object_add(my_object, "interface", interface_object);
  }
}

/* *************************************** */

void Flow::formatECSExtraInfo(json_object *my_object) {
  json_object *interface_object;

  if((interface_object = json_object_new_object()) != NULL) {
    if(ntop->getPrefs()->do_dump_extended_json()) {
      json_object_object_add(my_object, "flow_time", json_object_new_int(last_seen));

  #if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
      json_object_object_add(my_object, "profile", json_object_new_string(get_profile_name()));
  #endif

      json_object_object_add(my_object, "interface", interface_object);
    }
  }
}

/* *************************************** */

void Flow::formatECSAppProto(json_object *my_object) {
  json_object *application_object;
  if((application_object = json_object_new_object()) != NULL) {
    if(isDNS() && protos.dns.last_query) {
      json_object_object_add(application_object, "question.name", json_object_new_string(protos.dns.last_query));
      json_object_object_add(my_object, "dns", application_object);
    }

    if(isTLS() && protos.tls.client_requested_server_name) {
      json_object_object_add(application_object, "server_name", json_object_new_string(protos.tls.client_requested_server_name));
      json_object_object_add(my_object, "tls", application_object);
    }

    if(isHTTP()) {
      if(protos.http.last_url && protos.http.last_url[0] != '0')
        json_object_object_add(application_object, "request.url", json_object_new_string(protos.http.last_url));
      if(protos.http.last_user_agent && protos.http.last_user_agent[0] != '0')
        json_object_object_add(application_object, "user_agent", json_object_new_string(protos.http.last_user_agent));
      if(protos.http.last_method != NDPI_HTTP_METHOD_UNKNOWN)
        json_object_object_add(application_object, "request.method", json_object_new_string(ndpi_http_method2str(protos.http.last_method)));
      if(protos.http.last_return_code > 0)
        json_object_object_add(application_object, "response.status_code", json_object_new_int((u_int32_t)protos.http.last_return_code));

      json_object_object_add(my_object, "http", application_object);
    }

    if(bt_hash) {
      json_object_object_add(application_object, "hash", json_object_new_string(bt_hash));
      json_object_object_add(my_object, "bittorrent", application_object);
    }
  }
}

/* *************************************** */

void Flow::formatECSNetwork(json_object *my_object, const IpAddress *addr) {
  json_object *network_object;
  if((network_object = json_object_new_object()) != NULL) {
    char buf[64], jsonbuf[64];
    u_char community_id[200];
    const char *info;

    json_object_object_add(network_object, Utils::jsonLabel(PROTOCOL, "iana_number", jsonbuf, sizeof(jsonbuf)), json_object_new_int(protocol));

    if(((get_packets_cli2srv() + get_packets_srv2cli()) > NDPI_MIN_NUM_PACKETS) || (ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN))
      json_object_object_add(network_object, Utils::jsonLabel(L7_PROTO_NAME, "protocol", jsonbuf, sizeof(jsonbuf)), json_object_new_string(get_detected_protocol_name(buf, sizeof(buf))));

    if(protocol == IPPROTO_TCP)
      json_object_object_add(network_object, Utils::jsonLabel(TCP_FLAGS, "tcp_flags", jsonbuf, sizeof(jsonbuf)), json_object_new_int(src2dst_tcp_flags | dst2src_tcp_flags));

    json_object_object_add(network_object, Utils::jsonLabel(FIRST_SWITCHED, "first_seen", jsonbuf, sizeof(jsonbuf)), json_object_new_int((u_int32_t)get_partial_first_seen()));
    json_object_object_add(network_object, Utils::jsonLabel(LAST_SWITCHED, "last_seen", jsonbuf, sizeof(jsonbuf)), json_object_new_int((u_int32_t)get_partial_last_seen()));

    json_object *category_object;
    if((category_object = json_object_new_object()) != NULL) {
      json_object_object_add(category_object, Utils::jsonLabel(L7_CATEGORY, "name", jsonbuf, sizeof(jsonbuf)), json_object_new_string(get_protocol_category_name()));
      json_object_object_add(category_object, Utils::jsonLabel(L7_CATEGORY_ID, "id", jsonbuf, sizeof(jsonbuf)), json_object_new_int((u_int32_t)get_protocol_category()));
      json_object_object_add(network_object, "category", category_object);
    }

    json_object_object_add(my_object, "community_id", json_object_new_string((char *)getCommunityId(community_id, sizeof(community_id))));


  #ifdef NTOPNG_PRO
  #ifndef HAVE_NEDGE
    // Traffic profile information, if any
    if(trafficProfile && trafficProfile->getName())
      json_object_object_add(network_object, "profile", json_object_new_string(trafficProfile->getName()));
  #endif
  #endif

  #ifdef HAVE_NEDGE
    if(iface && iface->is_bridge_interface())
      json_object_object_add(my_object, "verdict.pass", json_object_new_boolean(isPassVerdict() ? (json_bool)1 : (json_bool)0));
  #else
    if(!passVerdict) json_object_object_add(my_object, "pass_verdict", json_object_new_boolean((json_bool)0));
  #endif

    if(addr)
      json_object_object_add(network_object, Utils::jsonLabel(IP_PROTOCOL_VERSION, "type", jsonbuf, sizeof(jsonbuf)), json_object_new_string(addr->isIPv4() ? "ipv4" : "ipv6"));

    if(flow_device.device_ip)
      json_object_object_add(network_object, "exporter", json_object_new_string(intoaV4(flow_device.device_ip, buf, sizeof(buf))));

    info = getFlowInfo(buf, sizeof(buf), false);
    if(info)
      json_object_object_add(network_object, "info", json_object_new_string(info));

    json_object_object_add(my_object, "network", network_object);
  }
}

/* *************************************** */

void Flow::formatECSHost(json_object *my_object, bool is_client, const IpAddress *addr, Host *host) {
  json_object *host_object;

  if((host_object = json_object_new_object()) != NULL) {
    char buf[64], jsonbuf[64], *c;

    /* Adding MAC */
    if(host && host->getMac() && !host->getMac()->isNull())
      json_object_object_add(host_object, Utils::jsonLabel(is_client ? IN_SRC_MAC : IN_DST_MAC, "mac", jsonbuf, sizeof(jsonbuf)), json_object_new_string(Utils::formatMac(host ? host->get_mac() : NULL, buf, sizeof(buf))));

    /* Adding IP */
    if(addr) {
      json_object_object_add(host_object, Utils::jsonLabel(is_client ? (addr->isIPv4() ? IPV4_SRC_ADDR : IPV6_SRC_ADDR) : (addr->isIPv4() ? IPV4_DST_ADDR : IPV6_DST_ADDR) , "ip", jsonbuf, sizeof(jsonbuf)), json_object_new_string(addr->print(buf, sizeof(buf))));

      /* Custom information elements, Local, Blacklisted, Has Services and domain name */
      json_object_object_add(host_object, Utils::jsonLabel(is_client ? SRC_ADDR_LOCAL : DST_ADDR_LOCAL, "is_local", jsonbuf, sizeof(jsonbuf)), json_object_new_boolean(addr->isLocalHost()));
      json_object_object_add(host_object, Utils::jsonLabel(is_client ? SRC_ADDR_BLACKLISTED : DST_ADDR_BLACKLISTED, "is_blacklisted", jsonbuf, sizeof(jsonbuf)), json_object_new_boolean(addr->isBlacklistedAddress()));

      if(get_cli_host()) {
        json_object_object_add(host_object, Utils::jsonLabel(is_client ? SRC_ADDR_SERVICES : DST_ADDR_SERVICES, "has_services", jsonbuf, sizeof(jsonbuf)), json_object_new_int(get_cli_host()->getServicesMap()));
        json_object_object_add(host_object, Utils::jsonLabel(is_client ? SRC_NAME : DST_NAME, "domain", jsonbuf, sizeof(jsonbuf)), json_object_new_string(get_cli_host()->get_visual_name(buf, sizeof(buf))));
      }
    }

    /* Geolocation info */
    c = host ? host->get_country(buf, sizeof(buf)) : NULL;
    if(c) {
      json_object *geo = json_object_new_object();
      json_object *location = json_object_new_object();

      if(geo) {
        json_object_object_add(geo, "country_name", json_object_new_string(c));

        if(host && location) {
          float latitude, longitude;

          host->get_geocoordinates(&latitude, &longitude);
          json_object_object_add(location, "lon", json_object_new_double(longitude));
          json_object_object_add(location, "lat", json_object_new_double(latitude));
          json_object_object_add(geo, "location", location);
        }

        json_object_object_add(host_object, "geo", geo);
      }
    }

    /* Type of Service */
    json_object_object_add(host_object, Utils::jsonLabel(is_client ? SRC_TOS : DST_TOS, "tos", jsonbuf, sizeof(jsonbuf)), json_object_new_int(getTOS(true)));
    json_object_object_add(host_object, Utils::jsonLabel(is_client ? L4_SRC_PORT : L4_DST_PORT, "port", jsonbuf, sizeof(jsonbuf)), json_object_new_int(is_client ? get_cli_port() : get_srv_port()));
    json_object_object_add(host_object, Utils::jsonLabel(is_client ? IN_PKTS : OUT_PKTS, "packets", jsonbuf, sizeof(jsonbuf)), json_object_new_int64(is_client ? get_partial_packets_cli2srv() : get_partial_packets_srv2cli()));
    json_object_object_add(host_object, Utils::jsonLabel(is_client ? IN_BYTES : OUT_BYTES, "bytes", jsonbuf, sizeof(jsonbuf)), json_object_new_int64(is_client ? get_partial_bytes_cli2srv() : get_partial_bytes_srv2cli()));
    json_object_object_add(host_object, Utils::jsonLabel(TCP_FLAGS, "packtes_retrasmissions", jsonbuf, sizeof(jsonbuf)), json_object_new_int64(is_client ? stats.get_cli2srv_tcp_retr() : stats.get_srv2cli_tcp_retr()));
    json_object_object_add(host_object, Utils::jsonLabel(TCP_FLAGS, "packtes_out_of_order", jsonbuf, sizeof(jsonbuf)), json_object_new_int64(is_client ? stats.get_cli2srv_tcp_ooo() : stats.get_srv2cli_tcp_ooo()));
    json_object_object_add(host_object, Utils::jsonLabel(TCP_FLAGS, "packtes_lost", jsonbuf, sizeof(jsonbuf)), json_object_new_int64(is_client ? stats.get_cli2srv_tcp_lost() : stats.get_srv2cli_tcp_lost()));

    if(vlanId > 0)
      json_object_object_add(host_object, Utils::jsonLabel(is_client ? SRC_VLAN : DST_VLAN, "vlan", jsonbuf, sizeof(jsonbuf)), json_object_new_int(vlanId));

    if(protocol == IPPROTO_TCP)
      json_object_object_add(host_object, Utils::jsonLabel(is_client ? CLIENT_NW_LATENCY_MS : SERVER_NW_LATENCY_MS, "latency", jsonbuf, sizeof(jsonbuf)), json_object_new_double(toMs(&clientNwLatency)));

    json_object_object_add(my_object, is_client ? "client" : "server", host_object);
  }
}

/* *************************************** */

void Flow::formatECSFlow(json_object *my_object) {
  char buf[64];
  time_t t;
  const IpAddress *cli_ip = get_cli_ip_addr(), *srv_ip = get_srv_ip_addr();
  struct tm* tm_info;

  t = last_seen;
  tm_info = gmtime(&t);

  /*
    strftime in the VS2013 library and earlier are not C99-conformant,
    as they do not accept that format-specifier: MSDN VS2013 strftime page

    https://msdn.microsoft.com/en-us/library/fe06s4ak.aspx
  */
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S.0Z", tm_info);

  /*
    Dumping flows, using ECS Format
    https://www.elastic.co/guide/en/ecs/current/index.html
  */

  json_object_object_add(my_object, "@timestamp", json_object_new_string(buf));
  json_object_object_add(my_object, "type", json_object_new_string(ntop->getPrefs()->get_es_type()));

  /* Formatting Client */
  formatECSHost(my_object, true, cli_ip, cli_host);

  /* Formatting Server */
  formatECSHost(my_object, false, srv_ip, srv_host);

  formatECSNetwork(my_object, cli_ip);
  formatECSInterface(my_object);
  formatECSObserver(my_object);
  formatECSEvent(my_object);
  formatECSAppProto(my_object);
  formatECSExtraInfo(my_object);

  if(json_info && json_object_object_length(json_info) > 0)
    json_object_object_add(my_object, "json", json_object_get(json_info));
}

/* *************************************** */

void Flow::formatSyslogFlow(json_object *my_object) {
  char buf[64], jsonbuf[64];

  if(cli_host && cli_host->getMac() && !cli_host->getMac()->isNull())
    json_object_object_add(my_object, Utils::jsonLabel(IN_SRC_MAC, "IN_SRC_MAC", jsonbuf, sizeof(jsonbuf)),
          json_object_new_string(Utils::formatMac(cli_host ? cli_host->get_mac() : NULL, buf, sizeof(buf))));

  if(srv_host && srv_host->getMac() && !srv_host->getMac()->isNull())
    json_object_object_add(my_object, Utils::jsonLabel(OUT_DST_MAC, "OUT_DST_MAC", jsonbuf, sizeof(jsonbuf)),
          json_object_new_string(Utils::formatMac(srv_host ? srv_host->get_mac() : NULL, buf, sizeof(buf))));

  if(isTLS() && protos.tls.ja3.client_hash)
    json_object_object_add(my_object, Utils::jsonLabel(JA3C_HASH, "JA3C_HASH", jsonbuf, sizeof(jsonbuf)),
          json_object_new_string(protos.tls.ja3.client_hash));

  if(isSSH() && protos.ssh.hassh.client_hash)
    json_object_object_add(my_object, Utils::jsonLabel(HASSHC_HASH, "HASSHC_HASH", jsonbuf, sizeof(jsonbuf)),
          json_object_new_string(protos.ssh.hassh.client_hash));

  formatGenericFlow(my_object);
}

/* *************************************** */

void Flow::formatGenericFlow(json_object *my_object) {
  char buf[64], jsonbuf[64], *c;
  u_char community_id[200];
  const IpAddress *cli_ip = get_cli_ip_addr(), *srv_ip = get_srv_ip_addr();

  if(cli_ip) {
    if(cli_ip->isIPv4()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV4_SRC_ADDR, "IPV4_SRC_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(cli_ip->print(buf, sizeof(buf))));
    } else if(cli_ip->isIPv6()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV6_SRC_ADDR, "IPV6_SRC_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(cli_ip->print(buf, sizeof(buf))));
    }

    /* Custom information elements not supported (yet) by nProbe */
    json_object_object_add(my_object, Utils::jsonLabel(SRC_ADDR_LOCAL, "SRC_ADDR_LOCAL", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_boolean(cli_ip->isLocalHost()));
    json_object_object_add(my_object, Utils::jsonLabel(SRC_ADDR_BLACKLISTED, "SRC_ADDR_BLACKLISTED", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_boolean(cli_ip->isBlacklistedAddress()));

    if(get_cli_host()) {
      json_object_object_add(my_object, Utils::jsonLabel(SRC_ADDR_SERVICES, "SRC_ADDR_SERVICES", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_int(get_cli_host()->getServicesMap()));
      json_object_object_add(my_object, Utils::jsonLabel(SRC_NAME, "SRC_NAME", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(get_cli_host()->get_visual_name(buf, sizeof(buf))));
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

    /* Custom information elements not supported (yet) by nProbe */
    json_object_object_add(my_object, Utils::jsonLabel(DST_ADDR_LOCAL, "DST_ADDR_LOCAL", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_boolean(srv_ip->isLocalHost()));
    json_object_object_add(my_object, Utils::jsonLabel(DST_ADDR_BLACKLISTED, "DST_ADDR_BLACKLISTED", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_boolean(srv_ip->isBlacklistedAddress()));

    if(get_srv_host()) {
      json_object_object_add(my_object, Utils::jsonLabel(DST_ADDR_SERVICES, "DST_ADDR_SERVICES", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_int(get_srv_host()->getServicesMap()));
      json_object_object_add(my_object, Utils::jsonLabel(SRC_NAME, "DST_NAME", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(get_srv_host()->get_visual_name(buf, sizeof(buf))));
    }
  }

  json_object_object_add(my_object, Utils::jsonLabel(SRC_TOS, "SRC_TOS", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(getTOS(true)));
  json_object_object_add(my_object, Utils::jsonLabel(DST_TOS, "DST_TOS", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(getTOS(false)));

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

  if(protocol == IPPROTO_TCP) {
    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "TCP_FLAGS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int(src2dst_tcp_flags | dst2src_tcp_flags));

    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "IN_RETRASMISSIONS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int64(stats.get_cli2srv_tcp_retr()));
    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "OUT_RETRASMISSIONS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int64(stats.get_srv2cli_tcp_retr()));
    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "IN_OUT_OF_ORDER", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int64(stats.get_cli2srv_tcp_ooo()));
    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "OUT_OUT_OF_ORDER", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int64(stats.get_srv2cli_tcp_ooo()));
    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "IN_LOST", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int64(stats.get_cli2srv_tcp_lost()));
    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "OUT_LOST", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int64(stats.get_srv2cli_tcp_lost()));
  }

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

  json_object_object_add(my_object, "COMMUNITY_ID", json_object_new_string((char *)getCommunityId(community_id, sizeof(community_id))));

  if(isHTTP()) {
    if(host_server_name && host_server_name[0] != '\0')
      json_object_object_add(my_object, "HTTP_HOST", json_object_new_string(host_server_name));
    if(protos.http.last_url && protos.http.last_url[0] != '0')
      json_object_object_add(my_object, "HTTP_URL", json_object_new_string(protos.http.last_url));
    if(protos.http.last_user_agent && protos.http.last_user_agent[0] != '0')
      json_object_object_add(my_object, "HTTP_USER_AGENT", json_object_new_string(protos.http.last_user_agent));
    if(protos.http.last_method != NDPI_HTTP_METHOD_UNKNOWN)
      json_object_object_add(my_object, "HTTP_METHOD", json_object_new_string(ndpi_http_method2str(protos.http.last_method)));
    if(protos.http.last_return_code > 0)
      json_object_object_add(my_object, "HTTP_RET_CODE", json_object_new_int((u_int32_t)protos.http.last_return_code));
  }

  if(flow_device.device_ip)
    json_object_object_add(my_object, "EXPORTER_IPV4_ADDRESS",
         json_object_new_string(intoaV4(flow_device.device_ip, buf, sizeof(buf))));

  if(bt_hash)
    json_object_object_add(my_object, "BITTORRENT_HASH", json_object_new_string(bt_hash));

  if(isTLS() && protos.tls.client_requested_server_name)
    json_object_object_add(my_object, "TLS_SERVER_NAME",
			   json_object_new_string(protos.tls.client_requested_server_name));

#ifdef HAVE_NEDGE
  if(iface && iface->is_bridge_interface())
    json_object_object_add(my_object, "verdict.pass",
			   json_object_new_boolean(isPassVerdict() ? (json_bool)1 : (json_bool)0));
#else
  if(!passVerdict) json_object_object_add(my_object, "verdict.pass", json_object_new_boolean((json_bool)0));
#endif

  if(ebpf) ebpf->getJSONObject(my_object);

  if(ntop->getPrefs()->do_dump_extended_json()) {
    const char *info;
    char buf[64];

    /* Add items usually dumped on nIndex (useful for debugging) */

    json_object_object_add(my_object, "FLOW_TIME", json_object_new_int(last_seen));

    if(cli_ip) {
      if(cli_ip->isIPv4()) {
        json_object_object_add(my_object,
          Utils::jsonLabel(IP_PROTOCOL_VERSION, "IP_PROTOCOL_VERSION", jsonbuf, sizeof(jsonbuf)),
          json_object_new_int(4));
      } else if(cli_ip->isIPv6()) {
        json_object_object_add(my_object,
          Utils::jsonLabel(IP_PROTOCOL_VERSION, "IP_PROTOCOL_VERSION", jsonbuf, sizeof(jsonbuf)),
          json_object_new_int(6));
      }
    }

    info = getFlowInfo(buf, sizeof(buf), false);

    if(info)
      json_object_object_add(my_object, "INFO", json_object_new_string(info));

#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
    json_object_object_add(my_object, "PROFILE", json_object_new_string(get_profile_name()));
#endif

    json_object_object_add(my_object, "INTERFACE_ID", json_object_new_int(iface->get_id()));
    json_object_object_add(my_object, "STATUS", json_object_new_int((u_int8_t)getPredominantAlert().id));
  }

}

/* *************************************** */

json_object* Flow::flow2JSON() {
  json_object *my_object;

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  if(ntop->getPrefs()->do_dump_flows_on_es()) {
    formatECSFlow(my_object);
  } else if(ntop->getPrefs()->do_dump_flows_on_syslog()) {
    formatSyslogFlow(my_object);
  } else {
    formatGenericFlow(my_object);
  }

  return(my_object);
}

/* *************************************** */

u_char* Flow::getCommunityId(u_char *community_id, u_int community_id_len) {
  if(cli_host && srv_host) {
    IpAddress *c = cli_host->get_ip(), *s = srv_host->get_ip();
    u_int8_t icmp_type = 0, icmp_code = 0;

    if(c->isIPv4()) {
      if(get_protocol() == IPPROTO_ICMP)
	icmp_type = protos.icmp.cli2srv.icmp_type, icmp_code = protos.icmp.cli2srv.icmp_code;

      if(ndpi_flowv4_flow_hash(protocol, ntohl(c->get_ipv4()), ntohl(s->get_ipv4()),
			       get_cli_port(), get_srv_port(),
			       icmp_type, icmp_code,
			       community_id, community_id_len) == 0)
	return(community_id);
    } else {
      if(get_protocol() == IPPROTO_ICMPV6)
	icmp_type = protos.icmp.cli2srv.icmp_type, icmp_code = protos.icmp.cli2srv.icmp_code;

      if(c->isIPv6()) {
	if(ndpi_flowv6_flow_hash(protocol, (struct ndpi_in6_addr*)c->get_ipv6(),
				 (struct ndpi_in6_addr*)s->get_ipv6(), get_cli_port(), get_srv_port(),
				 icmp_type, icmp_code,
				 community_id, community_id_len) == 0)
	  return(community_id);
      }
    }
  }

  community_id[0] = '\0';
  return(community_id);
}

/* *************************************** */

/* Create a JSON in the alerts format
 * Using the nDPI json serializer instead of jsonc for faster speed (~2.5x) */
void Flow::alert2JSON(FlowAlert *alert, ndpi_serializer *s) {
  ndpi_serializer *alert_json_serializer = NULL;
  char *alert_json = NULL;
  u_int32_t alert_json_len;
  char buf[64];
  u_char community_id[200];
  time_t now = time(NULL);
  const char *info;

  /*
    If the interface is viewed, the id of the view interface is specified as ifid. This ensures
    flow alerts of any viewed interface end up in the view interface, thus giving the user a single point
    where to look at all the troubles.
   */
  ndpi_serialize_string_int32(s, "ifid", iface->isViewed() ? iface->viewedBy()->get_id() : iface->get_id());

  ndpi_serialize_string_string(s, "action", "store");
  ndpi_serialize_string_int64(s, "first_seen", get_first_seen());
  ndpi_serialize_string_int32(s, "score", getScore());

  ndpi_serialize_string_boolean(s, "is_flow_alert", true);
  ndpi_serialize_string_int64(s, "tstamp", now);
  ndpi_serialize_string_int64(s, "alert_id", alert->getAlertType().id);
  ndpi_serialize_string_boolean(s, "is_cli_attacker", alert->isCliAttacker());
  ndpi_serialize_string_boolean(s, "is_cli_victim",   alert->isCliVictim());
  ndpi_serialize_string_boolean(s, "is_srv_attacker", alert->isSrvAttacker());
  ndpi_serialize_string_boolean(s, "is_srv_victim",   alert->isSrvVictim());

  // alert_entity MUST be in sync with alert_consts.lua flow alert entity
  ndpi_serialize_string_int32(s, "entity_id", alert_entity_flow);
  ndpi_serialize_string_string(s, "entity_val", "flow");
  // flows don't have any pool for now
  ndpi_serialize_string_int32(s, "pool_id", NO_HOST_POOL_ID);

  /* See VLANAddressTree.h for details */
  ndpi_serialize_string_int32(s, "vlan_id", get_vlan_id());
  ndpi_serialize_string_int32(s, "observation_point_id", get_observation_point_id());

  ndpi_serialize_string_int32(s, "proto", get_protocol());

  if(hasRisks())
    ndpi_serialize_string_uint64(s, "flow_risk_bitmap", ndpi_flow_risk_bitmap);

  /* All the statuses set */
  char status_buf[64];
  ndpi_serialize_string_string(s, "alerts_map", alerts_map.toHexString(status_buf, sizeof(status_buf)));

  /* nDPI data */
  ndpi_serialize_string_string(s, "proto.ndpi", detection_completed ? get_detected_protocol_name(buf, sizeof(buf)) : (char*)CONST_TOO_EARLY);
  ndpi_serialize_string_int32(s, "l7_master_proto", detection_completed ? ndpiDetectedProtocol.master_protocol : -1);
  ndpi_serialize_string_int32(s, "l7_proto", detection_completed ? ndpiDetectedProtocol.app_protocol : -1);
  ndpi_serialize_string_int32(s, "l7_cat", get_protocol_category());

  if(isDNS())
    ndpi_serialize_string_string(s, "dns_last_query", getDNSQuery());

  ndpi_serialize_string_int64(s, "cli2srv_bytes", get_bytes_cli2srv());
  ndpi_serialize_string_int64(s, "cli2srv_packets", get_packets_cli2srv());
  ndpi_serialize_string_int64(s, "srv2cli_bytes", get_bytes_srv2cli());
  ndpi_serialize_string_int64(s, "srv2cli_packets", get_packets_srv2cli());

  ndpi_serialize_string_int32(s, "ip_version", get_cli_ip_addr()->getVersion());

  ndpi_serialize_string_string(s, "cli_ip", get_cli_ip_addr()->print(buf, sizeof(buf)));
  ndpi_serialize_string_boolean(s, "cli_blacklisted", isBlacklistedClient());
  ndpi_serialize_string_int32(s, "cli_port", get_cli_port());
  ndpi_serialize_string_int32(s, "cli_location", getCliLocation());

  if(cli_host) {
    cli_host->serialize_geocoordinates(s, "cli_");
    ndpi_serialize_string_string(s, "cli_name", cli_host->get_visual_name(buf, sizeof(buf)));
    ndpi_serialize_string_string(s, "cli_os", cli_host->getOSDetail(buf, sizeof(buf)));
    ndpi_serialize_string_int32(s, "cli_asn", cli_host->get_asn());
    ndpi_serialize_string_boolean(s, "cli_localhost", cli_host->isLocalHost());

    ndpi_serialize_string_int32(s, "cli_host_pool_id", cli_host->get_host_pool());
    ndpi_serialize_string_int32(s, "cli_network", (u_int16_t) cli_host->get_local_network_id());
  }

  ndpi_serialize_string_string(s, "srv_ip", get_srv_ip_addr()->print(buf, sizeof(buf)));
  ndpi_serialize_string_boolean(s, "srv_blacklisted", isBlacklistedServer());
  ndpi_serialize_string_int32(s, "srv_port", get_srv_port());
  ndpi_serialize_string_int32(s, "srv_location", getSrvLocation());

  if(srv_host) {
    srv_host->serialize_geocoordinates(s, "srv_");
    ndpi_serialize_string_string(s, "srv_name", srv_host->get_visual_name(buf, sizeof(buf)));
    ndpi_serialize_string_string(s, "srv_os", srv_host->getOSDetail(buf, sizeof(buf)));
    ndpi_serialize_string_int32(s, "srv_asn", srv_host->get_asn());
    ndpi_serialize_string_boolean(s, "srv_localhost", srv_host->isLocalHost());

    ndpi_serialize_string_int32(s, "srv_host_pool_id", srv_host->get_host_pool());
    ndpi_serialize_string_int32(s, "srv_network", (u_int16_t) srv_host->get_local_network_id());
  }

  ndpi_serialize_string_string(s, "probe_ip", Utils::intoaV4(getFlowDeviceIP(), buf, sizeof(buf)));
  ndpi_serialize_string_int32(s, "input_snmp", getFlowDeviceInIndex());
  ndpi_serialize_string_int32(s, "output_snmp", getFlowDeviceOutIndex());

  ndpi_serialize_string_string(s, "community_id",
			       (char*)getCommunityId(community_id, sizeof(community_id)));

  if(protos.tls.ja3.client_hash)
    ndpi_serialize_string_string(s, "ja3_client_hash",
				 protos.tls.ja3.client_hash);

  if(protos.tls.ja3.server_hash)
    ndpi_serialize_string_string(s, "ja3_server_hash",
				 protos.tls.ja3.server_hash);

  if(getErrorCode() != 0)
    ndpi_serialize_string_uint32(s, "l7_error_code", getErrorCode());

  info = getFlowInfo(buf, sizeof(buf), false);
  ndpi_serialize_string_string(s, "info", (char*) (info ? info : ""));

  /* Serialize alert JSON */

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
    if((u_int32_t)(iface->getTimeLastPktRcvd()) > (last_conntrack_update + (3 * MIN_CONNTRACK_UPDATE)))
      return(true);

    return(false);
  } else {
    /* if an conntrack update hasn't been seen for this flow
       we use the standard idleness check */
    return(is_active_entry_now_idle(iface->getFlowMaxIdle()));
  }
}
#endif

/* *************************************** */

void Flow::decAllFlowScores() {
  Host *cli_u = getViewSharedClient(), *srv_u = getViewSharedServer();

  for(int i = 0; i < MAX_NUM_SCORE_CATEGORIES; i++) {
    ScoreCategory score_category = (ScoreCategory)i;
    u_int16_t cli_score_val = stats.get_cli_score(score_category);
    u_int16_t srv_score_val = stats.get_srv_score(score_category);

    if(getViewInterfaceFlowStats()) {
      /*
	If this flow belong to a view, the actual score value is the one registered
	in the partializable stats of the view.
      */
      cli_score_val = getViewInterfaceFlowStats()->getPartializableStats()->get_cli_score(score_category);
      srv_score_val = getViewInterfaceFlowStats()->getPartializableStats()->get_srv_score(score_category);
    }

    if(cli_u && cli_score_val) cli_u->decScoreValue(cli_score_val, score_category, true  /* as client */);
    if(srv_u && srv_score_val) srv_u->decScoreValue(srv_score_val, score_category, false /* as server */);
  }
    /*
    Perform other operations to decrease counters increased by flow user script hooks (we're in the same thread)
   */

  if(isFlowAlerted()) {
    iface->decNumAlertedFlows(this, Utils::mapScoreToSeverity(getPredominantAlertScore()));

    if(!getInterface()->isViewed() /* Always for non-viewed interfaces (increments are always performed and in the same thread) */
      /*
	For viewed interfaces, do the decrement only if previously incremented.
	A previous increment can fail when the view flows queue is full and enqueues fail.
      */
       || (getViewInterfaceFlowStats() && getViewInterfaceFlowStats()->getPartializableStats()->get_is_flow_alerted())) {
      if(cli_u) cli_u->decNumAlertedFlows(true /* As client */);
      if(srv_u) srv_u->decNumAlertedFlows(false /* As server */);
    }

#ifdef ALERTED_FLOWS_DEBUG
    iface_alert_dec = true;
#endif
  }
}

/* *************************************** */

/*
  This method is executed in the thread which processes packets/flows
  so it must be ultra-fast. Do NOT perform any time-consuming operation here.

  This is called by GenericHash::purgeIdle, in some cases there is a state
  transition after calling this (see purgeIdle), in other cases the transition
  is done in this class (e.g. set_hash_entry_state_flow_notyetdetected)
 */
void Flow::housekeep(time_t t) {
  switch(get_state()) {
  case hash_entry_state_allocated:
    /* This code can be executed multiple times, until there is a call to set_hash_entry_state_flow_notyetdetected */

  case hash_entry_state_flow_notyetdetected:
    /*
      Possibly the time to giveup and end the protocol dissection.
      This happens when a flow with an incomplete TWH stops receiving packets for example.

      Giveup is handled differently, depending on whether we are processing pcap files or not:
      - When not reading from pcap files, before giving up, we wait at least 5 seconds since the last flow packet
      - When reading from pcap files, we wait until all the packets in the file have been processed before ending the dissection
    */
    if(iface->get_ndpi_struct() && get_ndpi_flow()) {
      if(likely(!getInterface()->read_from_pcap_dump())) {
	/* NOT processing pcap files, at most 5 seconds since the last packet */
	if((t - get_last_seen()) > 5 /* sec */) endProtocolDissection();
      } else {
	/* pcap files - wait until all the file has been processed */
	if(getInterface()->read_from_pcap_dump_done()) endProtocolDissection();
      }
    }

    /*
       If a condition above has determined the flow trasnition to the protocol detected state,
       don't break, continue so to execute detection completed checks.
     */
    if(get_state() != hash_entry_state_flow_protocoldetected)
      break;

  case hash_entry_state_flow_protocoldetected:
    if(!is_swap_requested()) /* The flow will be swapped, hook execution will occur on the swapped flow. */
      iface->execProtocolDetectedChecks(this);
    break;

  case hash_entry_state_active:
    /*
      The hook for periodicUpdate is checked when increasing flow stats inline
      to guarantee timely execution.
      hookPeriodicUpdateCheck(t);
     */
    dumpCheck(t, false /* NOT the last dump before delete */);

    /*
      Swap requested but not yet performed (no more packets seen).
      In case of interfaces processing pcap files, if the processing of the pcap file is completed,
      i.e. read_from_pcap_dump_done() is true, then there will be no more packets so the flow swap won't take
      place. For this reason, the callbacks are executed on the original flow that should have been swapped but actually it is not.
     */
    if(getInterface()->read_from_pcap_dump_done()
       && is_swap_requested()
       && !is_swap_done())
      iface->execProtocolDetectedChecks(this);

    break;

  case hash_entry_state_idle:
    /* This code is executed once, as the flow is removed from the hash table after calling housekeep in this state */

    if(is_swap_requested() && !is_swap_done()) /* Swap requested but never performed (no more packets seen) */
      iface->execProtocolDetectedChecks(this);

    if(!is_swap_requested() /* Swap not requested */
       || (is_swap_requested() && !is_swap_done())) /* Or requested but never performed (no more packets seen) */
      iface->execFlowEndChecks(this);

    dumpCheck(t, true /* LAST dump before delete */);

  #ifdef NTOPNG_PRO
    if(cli_host && srv_host) {
      u_int16_t cli_net_id = cli_host->get_local_network_id(), srv_net_id = srv_host->get_local_network_id();

      if(cli_net_id != (u_int16_t) -1 &&
         srv_net_id != (u_int16_t) -1 &&
         cli_net_id != srv_net_id) {
        NetworkStats *cli_network_stats = iface->getNetworkStats(cli_net_id), *srv_network_stats = iface->getNetworkStats(srv_net_id);
        if(cli_network_stats) cli_network_stats->incTrafficBetweenNets(srv_net_id, get_bytes_cli2srv(), get_bytes_srv2cli());
        if(srv_network_stats) srv_network_stats->incTrafficBetweenNets(cli_net_id, get_bytes_srv2cli(), get_bytes_cli2srv());
      #ifdef DEBUG
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Cli Network ID: %u | Srv Network ID: %u | Bytes: %lu | Num Loc Nets: %u", cli_net_id, srv_net_id, get_bytes(), ntop->getNumLocalNetworks());
      #endif
      }
    }
  #endif

    /*
      Score decrements MUST be performed here as this is the same thread of checks execution where
      scores are increased.
      NOTE: for view interfaces, decrement are performed in ~Flow to avoid races.
     */
    if(!getInterface()->isViewed()) decAllFlowScores();

    switch(protocol) {
    case IPPROTO_TCP:
      if(cli_host
	 && ((getTcpFlagsCli2Srv() == TH_SYN)
	     || (!non_zero_payload_observed)
	     )
	 )
	cli_host->incIncompleteFlows();
      break;

    case IPPROTO_UDP:
      if(cli_host
	 && (get_packets_srv2cli() == 0) /* unidirectional flow */
	 && srv_ip_addr
	 && srv_ip_addr->isNonEmptyUnicastAddress())
	cli_host->incIncompleteFlows();
      break;
    }

#ifdef DEBUG_SCAN_DETECTION
    char buf[64];

    ntop->getTrace()->traceEvent(TRACE_WARNING, "IDLE %s", print(buf, sizeof(buf)));
    break;
#endif
    break;

  default:
    break;
  }

  /*
    Check (and possibly enqueue) the flow for processing by a view interface.
    Make sure to enqueue the flow to view interfaces AFTER all housekeeping tasks have been performed.
    This guarantees any change set by these operations (e.g., changes in the flow status, flow alerts, etc.)
    are done before the flow is propagated to the view.
  */
  getInterface()->viewEnqueue(t, this);
}

/* *************************************** */

bool Flow::get_partial_traffic_stats(PartializableFlowTrafficStats **dst,
				     PartializableFlowTrafficStats *fts, bool *first_partial) const {
  if(!fts || !dst)
    return(false);

  if(!*dst) {
    if(!(*dst = new (std::nothrow) PartializableFlowTrafficStats()))
      return(false);
    *first_partial = true;
  } else {
    *first_partial = false;
  }

  stats.get_partial(*dst, fts);

  return(true);
}

/* *************************************** */

/* NOTE: this is only called by the ViewInterface */
bool Flow::get_partial_traffic_stats_view(PartializableFlowTrafficStats *fts, bool *first_partial) {
  if(!fts)
    return(false);

  if(!viewFlowStats) {
    if(!(viewFlowStats = new (std::nothrow) ViewInterfaceFlowStats()))
      return(false);

    *first_partial = true;
  } else
    *first_partial = false;

  stats.get_partial(viewFlowStats->getPartializableStats(), fts);

  return(true);
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
  bool res = (isBlacklistedClient()
	      || isBlacklistedServer()
	      || get_protocol_category() == CUSTOM_CATEGORY_MALWARE);

#ifdef BLACKLISTED_FLOWS_DEBUG
  if(res) {
    char buf[512];
    print(buf, sizeof(buf));
    snprintf(&buf[strlen(buf)], sizeof(buf) - strlen(buf), "[cli_blacklisted: %u][srv_blacklisted: %u][category: %s]",
	     isBlacklistedClient(), isBlacklistedServer(), get_protocol_category_name());
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", buf);
  }
#endif

  return res;
};

/* *************************************** */

bool Flow::isBlacklistedClient() const {
  if(cli_host)
    return cli_host->isBlacklisted();
  else
    return get_cli_ip_addr()->isBlacklistedAddress();
}

/* *************************************** */

bool Flow::isBlacklistedServer() const {
  if(srv_host)
    return srv_host->isBlacklisted();
  else
    return get_srv_ip_addr()->isBlacklistedAddress();
}

/* *************************************** */

bool Flow::isTLS() const {
  return(
	 isProto(NDPI_PROTOCOL_TLS)
	 || isProto(NDPI_PROTOCOL_MAIL_IMAPS)
	 || isProto(NDPI_PROTOCOL_MAIL_SMTPS)
	 || isProto(NDPI_PROTOCOL_MAIL_POPS)
	 || isProto(NDPI_PROTOCOL_QUIC)
	 );
}

/* *************************************** */

void Flow::callFlowUpdate(time_t t) {

  if(get_state() != hash_entry_state_active)
    return;

  /*
    Flow update is conditional here as it is only performed every 5 minutes when the flow is active.
  */
  if(next_call_periodic_update == 0)
    next_call_periodic_update = t + FLOW_LUA_CALL_PERIODIC_UPDATE_SECS; /* Set the time of the new periodic call */

  if(trigger_immediate_periodic_update || next_call_periodic_update <= t) {
    iface->execPeriodicUpdateChecks(this);
    next_call_periodic_update = 0; /* Reset */

    if(trigger_immediate_periodic_update)
      trigger_immediate_periodic_update = false; /* Reset if necessary */
  }
}

/* *************************************** */

/* Enqueue alert to recipients */
bool Flow::enqueueAlertToRecipients(FlowAlert *alert) {
  bool first_alert = isFlowAlerted();
  bool rv = false;
  u_int32_t buflen;
  AlertFifoItem notification;
  ndpi_serializer flow_json;
  const char *flow_str;

  ndpi_init_serializer(&flow_json, ndpi_serialization_format_json);

  /* Prepare the JSON, including a JSON specific of this FlowAlertType */
  alert2JSON(alert, &flow_json);

  if(!first_alert)
    ndpi_serialize_string_boolean(&flow_json, "replace_alert", true);

  flow_str = ndpi_serializer_get_buffer(&flow_json, &buflen);

  notification.alert = (char*)flow_str;
  notification.score = getPredominantAlertScore();
  notification.alert_severity = Utils::mapScoreToSeverity(notification.score);
  notification.alert_category = alert->getAlertType().category;
  notification.pools.flow.cli_host_pool = cli_host ? cli_host->get_host_pool() : 0;
  notification.pools.flow.srv_host_pool = srv_host ? srv_host->get_host_pool() : 0;

  rv = ntop->recipients_enqueue(&notification, alert_entity_flow /* Flow recipients */);

  if(!rv)
    getInterface()->incNumDroppedAlerts(alert_entity_flow);

  ndpi_term_serializer(&flow_json);

  delete alert;

  return rv;
}

/* *************************************** */

void Flow::incStats(bool cli2srv_direction, u_int pkt_len,
		    u_int8_t *payload, u_int payload_len,
                    u_int8_t l4_proto, u_int8_t is_fragment,
		    u_int16_t tcp_flags, const struct timeval *when,
		    u_int16_t fragment_extra_overhead) {
  bool update_iat = true;

  /* Updated server -> client in case no traffic was already observed on the server side */
  if(srv_host
     && (cli2srv_direction == false)
     && (get_bytes_srv2cli() == 0)) {
    switch(protocol) {
    case IPPROTO_TCP:
    case IPPROTO_UDP:
      srv_host->setServerPort((protocol == IPPROTO_TCP), ntohs(srv_port));
      break;
    }
  }
  
  payload_len *= iface->getScalingFactor();
  updateSeen();

  if(fragment_extra_overhead) {
    /* Add artificial packet overhead */
    stats.incStats(cli2srv_direction, 1, fragment_extra_overhead, fragment_extra_overhead);
  }

  callFlowUpdate((when->tv_sec));

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

    /*
      Need to reset this bit as nDPI might "forget" to do it in case of
      protocol detection with onl one packet
    */
    ndpi_flow_risk_bitmap &= ~(1UL << NDPI_UNIDIRECTIONAL_TRAFFIC); /* Clear bit */
  }

  if(payload_len > 0) {
    if(cli2srv_direction) {
      if(get_bytes_cli2srv() < MAX_ENTROPY_BYTES)
	updateEntropy(entropy.c2s, payload, payload_len);
    } else {
      if(get_bytes_srv2cli() < MAX_ENTROPY_BYTES)
	updateEntropy(entropy.s2c, payload, payload_len);
    }

    if(applLatencyMsec == 0) {
      if(cli2srv_direction) {
	memcpy(&c2sFirstGoodputTime, when, sizeof(struct timeval));
      } else {
	if(c2sFirstGoodputTime.tv_sec != 0)
	  applLatencyMsec = ((float)(Utils::timeval2usec((struct timeval*)when)
				     - Utils::timeval2usec(&c2sFirstGoodputTime)))/1000;
      }
    }
  }
}

/* *************************************** */

/*
void Flow::updateInterfaceLocalStats(bool src2dst_direction, u_int num_pkts, u_int pkt_len) {
  const IpAddress *from = src2dst_direction ? get_cli_ip_addr() : get_srv_ip_addr();
  const IpAddress *to   = src2dst_direction ? get_srv_ip_addr() : get_cli_ip_addr();

  iface->incLocalStats(num_pkts, pkt_len,
		       from ? from->isLocalHost() : false,
		       to ? to->isLocalHost() : false);
}
*/

/* *************************************** */

void Flow::addFlowStats(bool new_flow,
			bool cli2srv_direction,
			u_int in_pkts, u_int in_bytes, u_int in_goodput_bytes,
			u_int out_pkts, u_int out_bytes, u_int out_goodput_bytes,
			u_int in_fragments, u_int out_fragments,
			time_t first_seen, time_t last_seen) {

  /* Don't update seen if no traffic has been observed */
  if(!(in_bytes || out_bytes || in_pkts || out_pkts))
    return;

  double thp_delta_time;

  if(new_flow)
    /* Average between last and first seen */
    thp_delta_time = difftime(last_seen, first_seen);
  else
    /* Average of the latest update, that is between the new and the previous last_seen */
    thp_delta_time = difftime(last_seen, get_last_seen());

#if 0
<  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[first: %u][last: %u][get_last_seen: %u][%u][%u][in_bytes: %u][out_bytes: %u][bytes : %u][thpt: %.2f]",
			       first_seen, last_seen,
			       get_last_seen(),
			       last_seen - first_seen,
			       last_seen - get_last_seen(),
			       in_bytes,
			       out_bytes,
			       in_bytes + out_bytes,
			       ((in_bytes + out_bytes) / thp_delta_time) / 1024 / 1024 * 8);
#endif

  updateSeen(last_seen);
  callFlowUpdate(last_seen);

  if(cli2srv_direction) {
    stats.incStats(true, in_pkts, in_bytes, in_goodput_bytes);
    stats.incStats(false, out_pkts, out_bytes, out_goodput_bytes);
    ip_stats_s2d.pktFrag += in_fragments, ip_stats_d2s.pktFrag += out_fragments;
  } else {
    stats.incStats(true, out_pkts, out_bytes, out_goodput_bytes);
    stats.incStats(false, in_pkts, in_bytes, in_goodput_bytes);
    ip_stats_s2d.pktFrag += out_fragments, ip_stats_d2s.pktFrag += in_fragments;
  }

  /*
    The throughput is updated roughly by estimating
    the average throughput. This prevents
    having flows with seemingly zero throughput.
  */
  if(!new_flow && thp_delta_time <= 5) {
    /*
       If here, delta time is too small to enable meaningful throughput calculations
       using only bytes/packets delta. In this case, totals are used and averaged
       using the overall flow lifetime.
     */
    if(cli2srv_direction)
      updateThroughputStats(get_duration() * 1000,
			    get_packets_cli2srv(), get_bytes_cli2srv(), 0,
			    get_packets_srv2cli(), get_bytes_srv2cli(), 0);
    else
      updateThroughputStats(get_duration() * 1000,
			    get_packets_srv2cli(), get_bytes_srv2cli(), 0,
			    get_packets_cli2srv(), get_bytes_cli2srv(), 0);
  } else {
    /*
      If here, delta time is enough to enable throughput estimations using
      bytes/packets delta. In this case, we can give throughput values
      that are averaged using the time delta, and not the overall flow lifetime.
     */
    if(cli2srv_direction)
      updateThroughputStats(thp_delta_time * 1000, in_pkts, in_bytes, 0, out_pkts, out_bytes, 0);
    else
      updateThroughputStats(thp_delta_time * 1000, out_pkts, out_bytes, 0, in_pkts, in_bytes, 0);
  }
}

/* *************************************** */

void Flow::updateTcpSeqIssues(const ParsedFlow *pf) {
  stats.incTcpStats(true   /* src2dst */, pf->tcp.retr_in_pkts,
		    pf->tcp.ooo_in_pkts, pf->tcp.lost_in_pkts,
		    0 /* keepalive not supported */);
  stats.incTcpStats(false  /* dst2src */, pf->tcp.retr_out_pkts,
		    pf->tcp.ooo_out_pkts, pf->tcp.lost_out_pkts,
		    0 /* keepalive not supported */);
}

/* *************************************** */

void Flow::updateTcpWindow(u_int16_t window, bool src2dst_direction) {
  /* The update depends on the direction of the flow */
  if(window == 0) {
    if(src2dst_direction)
      src2dst_tcp_zero_window = 1;
    else
      dst2src_tcp_zero_window = 1;
  }
}

/* *************************************** */

void Flow::updateICMPFlood(const struct bpf_timeval *when, bool src2dst_direction) {
  if(cli_host) cli_host->updateICMPAlertsCounter(when->tv_sec, src2dst_direction);
  if(srv_host) srv_host->updateICMPAlertsCounter(when->tv_sec, !src2dst_direction);
}

/* *************************************** */

void Flow::updateTcpFlags(const struct bpf_timeval *when,
			  u_int8_t flags, bool src2dst_direction) {
  NetworkStats *cli_network_stats = NULL, *srv_network_stats = NULL;
  /* Only packet-interfaces see every segment. Non-packet-interfaces
     have cumulative flags */
  bool cumulative_flags = !getInterface()->isPacketInterface();
  /* Flags used for the analysis of the 3WH. Original flags are masked for this analysis
     to ignore certain bits such as ECE or CWR which may be present during a valid 3WH.
     See https://github.com/ntop/ntopng/issues/3255 */
  u_int8_t flags_3wh = flags & TCP_3WH_MASK;

  iface->incFlagStats(flags, cumulative_flags);

  if(cli_host) {
    cli_host->incFlagStats(src2dst_direction, flags, cumulative_flags);
    cli_network_stats = cli_host->getNetworkStats(cli_host->get_local_network_id());
  }
  if(srv_host) {
    srv_host->incFlagStats(!src2dst_direction, flags, cumulative_flags);
    srv_network_stats = srv_host->getNetworkStats(srv_host->get_local_network_id());
  }

  /* Update syn alerts counters. In case of cumulative flags, the AND is used as possibly other flags can be present  */
  if((!cumulative_flags && flags_3wh == TH_SYN)
     || (cumulative_flags && (flags_3wh & TH_SYN) == TH_SYN)) {
    if(cli_host) cli_host->updateSynAlertsCounter(when->tv_sec, src2dst_direction);
    if(srv_host) srv_host->updateSynAlertsCounter(when->tv_sec, !src2dst_direction);
    if(cli_network_stats) cli_network_stats->updateSynAlertsCounter(when->tv_sec, src2dst_direction);
    if(srv_network_stats) srv_network_stats->updateSynAlertsCounter(when->tv_sec, !src2dst_direction);
  }

  /* Update synack alerts counter. In case of cumulative flags, the AND is used as possibly other flags can be present */
  if((!cumulative_flags && (flags_3wh == (TH_SYN|TH_ACK)))
     || (cumulative_flags && ((flags_3wh & (TH_SYN|TH_ACK)) == (TH_SYN|TH_ACK)))) {
    if(cli_host) cli_host->updateSynAckAlertsCounter(when->tv_sec, src2dst_direction);
    if(srv_host) srv_host->updateSynAckAlertsCounter(when->tv_sec, !src2dst_direction);
    if(cli_network_stats) cli_network_stats->updateSynAckAlertsCounter(when->tv_sec, src2dst_direction);
    if(srv_network_stats) srv_network_stats->updateSynAckAlertsCounter(when->tv_sec, !src2dst_direction);
  }

  if((flags & TH_SYN) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_SYN) != TH_SYN))
    iface->getTcpFlowStats()->incSyn();

  if((flags & TH_RST) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_RST) != TH_RST))
    iface->getTcpFlowStats()->incReset();

  if((flags & TH_FIN) && (((src2dst_tcp_flags | dst2src_tcp_flags) & TH_FIN) != TH_FIN)) {
    if(cli_host) cli_host->updateFinAlertsCounter(when->tv_sec, src2dst_direction);
    if(srv_host) srv_host->updateFinAlertsCounter(when->tv_sec, !src2dst_direction);
    iface->getTcpFlowStats()->incFin();
  }

  if((flags & (TH_FIN|TH_ACK)) && (((src2dst_tcp_flags | dst2src_tcp_flags) & (TH_FIN|TH_ACK)) != (TH_FIN|TH_ACK))) {
    if(cli_host) cli_host->updateFinAckAlertsCounter(when->tv_sec, src2dst_direction);
    if(srv_host) srv_host->updateFinAckAlertsCounter(when->tv_sec, !src2dst_direction);
    iface->getTcpFlowStats()->incFin();
  }

  /* The update below must be after the above check */
  if(src2dst_direction)
    src2dst_tcp_flags |= flags;
  else
    dst2src_tcp_flags |= flags;

  if(cumulative_flags) {
    if(!twh_over) {
      if((src2dst_tcp_flags & (TH_SYN|TH_ACK)) == (TH_SYN|TH_ACK)
	 && ((dst2src_tcp_flags & (TH_SYN|TH_ACK)) == (TH_SYN|TH_ACK)))
	twh_ok = twh_over = 1,
	  iface->getTcpFlowStats()->incEstablished();
    }
  } else {
    if(!twh_over) {
      if(flags_3wh == TH_SYN) {
	if(synTime.tv_sec == 0) memcpy(&synTime, when, sizeof(struct timeval));
      } else if(flags_3wh == (TH_SYN|TH_ACK)) {
	if((synAckTime.tv_sec == 0) && (synTime.tv_sec > 0)) {
	  memcpy(&synAckTime, when, sizeof(struct timeval));
	  timeval_diff(&synTime, (struct timeval*)when, &serverNwLatency, 1);
	  /* Coherence check */
	  if(serverNwLatency.tv_sec > 5)
	    memset(&serverNwLatency, 0, sizeof(serverNwLatency));
	  else if(srv_host)
	    srv_host->updateRoundTripTime(Utils::timeval2ms(&serverNwLatency));
	}
      } else if((flags_3wh == TH_ACK)
		|| (flags_3wh == (TH_ACK|TH_PUSH)) /* TCP Fast Open may contain data and PSH in the final TWH ACK */
		) {
	if((ackTime.tv_sec == 0) && (synAckTime.tv_sec > 0)) {
	  memcpy(&ackTime, when, sizeof(struct timeval));
	  timeval_diff(&synAckTime, (struct timeval*)when, &clientNwLatency, 1);

	  /* Coherence check */
	  if(clientNwLatency.tv_sec > 5)
	    memset(&clientNwLatency, 0, sizeof(clientNwLatency));
	  else if(cli_host)
	    cli_host->updateRoundTripTime(Utils::timeval2ms(&clientNwLatency));

	  setRtt();

	  twh_ok = 1;
	  iface->getTcpFlowStats()->incEstablished();
	}
	goto not_yet;
      } else {
      not_yet:
	twh_over = 1;

#if 0
	if(!twh_ok) {
	  char buf[256];

	  ntop->getTrace()->traceEvent(TRACE_WARNING, "[flags: %u][src2dst: %u] not ok %s",
				       flags, src2dst_direction ? 1 : 0, print(buf, sizeof(buf)));
	}
#endif

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

char* Flow::getFlowInfo(char *buf, u_int buf_len, bool isLuaRequest) {
  if(!isMaskedFlow()) {
    if(iec104)
      return(iec104->getFlowInfo(buf, buf_len));

    if(isDNS() && protos.dns.last_query)
      return protos.dns.last_query;

    else if(isHTTP() && protos.http.last_url)
      return protos.http.last_url;

    else if(isTLS() && protos.tls.client_requested_server_name)
      return protos.tls.client_requested_server_name;

    else if(isBittorrent() && bt_hash)
      return bt_hash;

    else if(host_server_name)
      return host_server_name;

    else if(isSSH()) {
      if(protos.ssh.server_signature)
	return protos.ssh.server_signature;
      else if(protos.ssh.client_signature)
	return protos.ssh.client_signature;
    }

    else if(isLuaRequest && hasRisk(NDPI_DESKTOP_OR_FILE_SHARING_SESSION))
      return((char*)"<i class='fa fa-lg fa-binoculars'></i> Desktop Sharing");
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
          if(tcp_seq_s2d.next != tcp_seq_s2d.last) {
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
          if(tcp_seq_d2s.next != tcp_seq_d2s.last) {
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
  if(client && ebpf && ebpf->process_info_set)
    return ebpf->src_process_info.pid;

  if(!client && ebpf && ebpf->process_info_set)
    return ebpf->dst_process_info.pid;

  return NO_PID;
};

/* *************************************** */

u_int32_t Flow::getFatherPid(bool client) {
  if(client && ebpf && ebpf->process_info_set)
    return ebpf->src_process_info.father_pid;

  if(!client && ebpf && ebpf->process_info_set)
    return ebpf->dst_process_info.father_pid;

  return NO_PID;
};

/* *************************************** */

u_int32_t Flow::get_uid(bool client) const {
#ifdef WIN32
  return NO_UID;
#else
  if(client && ebpf && ebpf->process_info_set)
    return ebpf->src_process_info.uid;

  if(!client && ebpf && ebpf->process_info_set)
    return ebpf->dst_process_info.uid;

  return NO_UID;
#endif
}

/* *************************************** */

char* Flow::get_proc_name(bool client) {
  if(client && ebpf && ebpf->process_info_set)
    return ebpf->src_process_info.process_name;

  if(!client && ebpf && ebpf->process_info_set)
    return ebpf->dst_process_info.process_name;

  return NULL;
};

/* *************************************** */

char* Flow::get_user_name(bool client) {
  if(client && ebpf && ebpf->process_info_set)
    return ebpf->src_process_info.uid_name;

  if(!client && ebpf && ebpf->process_info_set)
    return ebpf->dst_process_info.uid_name;

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

    snprintf(&bittorrent_hash[j], 3, "%02x", (u_int8_t)c);
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

/*
  Performs DNS query updates. No more than one update per second is performed to handle concurrency issues.
  This is safe in general as it is unlikely to see more than one query per second for the same DNS flow.
 */
bool Flow::setDNSQuery(char *v) {
  if(isDNS()) {
    time_t last_pkt_rcvd = getInterface()->getTimeLastPktRcvd();

    if(!protos.dns.last_query_shadow /* The first time the swap is done */
       || protos.dns.last_query_update_time + 1 < last_pkt_rcvd /* Latest swap occurred at least one second ago */) {
      if(protos.dns.last_query_shadow) free(protos.dns.last_query_shadow);
      protos.dns.last_query_shadow = protos.dns.last_query;
      protos.dns.last_query = v;
      protos.dns.last_query_update_time = last_pkt_rcvd;

      return true; /* Swap successful */
    }
  }

  /* Unable to set the DNS query. Too early or not a DNS flow. */
  return false;
}

/* *************************************** */

/*
  @brief Update DNS stats for flows received via ZMQ
 */
void Flow::updateDNS(ParsedFlow *zflow) {
  if(isDNS()) {
    if(zflow->dns_query) {
      if(setDNSQuery(zflow->dns_query)) {
	/* Set successful, query will be freed in the destructor */
	setDNSQueryType(zflow->dns_query_type);
	setDNSRetCode(zflow->dns_ret_code);
      } else
	/* Set error, query must be freed now */
	free(zflow->dns_query);

      zflow->dns_query = NULL;
    }

    stats.incDNSQuery(getLastQueryType());
    stats.incDNSResp(getDNSRetCode());
  }
}

/* *************************************** */

/*
  @brief Update TLS stats for flows received via ZMQ
 */
void Flow::updateTLS(ParsedFlow *zflow) {
  if(zflow->tls_server_name) {
    if(isTLS()) {
      if(!protos.tls.client_requested_server_name)
	protos.tls.client_requested_server_name = zflow->tls_server_name;
      else
      	/* Already set, can be freed */
      	free(zflow->tls_server_name);
    } else {
      /* Not TLS, free the server name */
      free(zflow->tls_server_name);
    }

    zflow->tls_server_name = NULL;
  }
}

/* *************************************** */

void Flow::dissectDNS(bool src2dst_direction, char *payload, u_int16_t payload_len) {
  struct ndpi_dns_packet_header dns_header;
  u_int8_t payload_offset = get_protocol() == IPPROTO_UDP ? 0 : 2;

  if(payload_len + payload_offset < sizeof(dns_header))
    return;

  memcpy(&dns_header, &payload[payload_offset], sizeof(dns_header));

  if((dns_header.flags & 0x8000) == 0x0000)
    stats.incDNSQuery(getLastQueryType());
  else if((dns_header.flags & 0x8000) == 0x8000)
    stats.incDNSResp(getDNSRetCode());
}

/* *************************************** */

void Flow::updateHTTP(ParsedFlow *zflow) {
  if(isHTTP()) {
    if(zflow->http_url) {
      setHTTPURL(zflow->http_url);
      zflow->http_url = NULL;
    }

    if(zflow->http_user_agent) {
      setHTTPUserAgent(zflow->http_user_agent);
      zflow->http_user_agent = NULL;
    }

    if(zflow->http_site) {
      setServerName(zflow->http_site);
      zflow->http_site = NULL;
    }

    if(zflow->http_method != NDPI_HTTP_METHOD_UNKNOWN) {
      setHTTPMethod(zflow->http_method);
      const char *http_method = getHTTPMethod();
      if(http_method && http_method[0] && http_method[1]) {
	switch(http_method[0]) {
	case 'P':
	  switch(http_method[1]) {
	  case 'O': stats.incHTTPReqPOST();  break;
	  case 'U': stats.incHTTPReqPUT();   break;
	  default:  stats.incHTTPReqOhter(); break;
	  }
	  break;
	case 'G': stats.incHTTPReqGET();   break;
	case 'H': stats.incHTTPReqHEAD();  break;
	default:  stats.incHTTPReqOhter(); break;
	}
      } else
	stats.incHTTPReqOhter();
    }

    setHTTPRetCode(zflow->http_ret_code);
    u_int16_t ret_code = getHTTPRetCode();
    while(ret_code > 9) ret_code /= 10; /* Take the first digit */
    switch(ret_code) {
    case 1: stats.incHTTPResp1xx(); break;
    case 2: stats.incHTTPResp2xx(); break;
    case 3: stats.incHTTPResp3xx(); break;
    case 4: stats.incHTTPResp4xx(); break;
    case 5: stats.incHTTPResp5xx(); break;
    }
  }
}

/* *************************************** */

void Flow::updateSuspiciousDGADomain() {
  if(hasRisk(NDPI_SUSPICIOUS_DGA_DOMAIN) && !suspicious_dga_domain) {
    char *domain = getFlowInfo(NULL, 0, false);

    if(domain)
      suspicious_dga_domain = strdup(domain);
  }
}

/* *************************************** */

void Flow::setHTTPMethod(ndpi_http_method m) {
  if(protos.http.last_method == NDPI_HTTP_METHOD_UNKNOWN)
    protos.http.last_method = m;
}

/* *************************************** */

void Flow::setHTTPMethod(const char* method, ssize_t method_len) {
  setHTTPMethod(ndpi_http_str2method(method, method_len));
}

/* *************************************** */

void Flow::dissectHTTP(bool src2dst_direction, char *payload, u_int16_t payload_len) {
  ssize_t host_server_name_len = host_server_name && host_server_name[0] != '\0' ? strlen(host_server_name) : 0;

  if((payload == NULL) || (payload_len == 0))
    return;

#if 0 /* Not sure it this is really necessary */
  if(!isThreeWayHandshakeOK())
    ; /* Useless to compute http stats as client and server could be swapped */
  else
#endif

    if(src2dst_direction) {
      char *space;
      dissect_next_http_packet = 1;

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

	  setHTTPMethod(payload, l);

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

	    if(!protos.http.last_url
	       && (protos.http.last_url = (char*)malloc(host_server_name_len + l + 1)) != NULL) {
	      protos.http.last_url[0] = '\0';

	      if(host_server_name_len > 0) {
		strncat(protos.http.last_url, host_server_name, host_server_name_len);
	      }

	      strncat(protos.http.last_url, payload, l);
	    }
	  }

	  if((ua = ndpi_strnstr(payload, "User-Agent:", payload_len)) != NULL) {
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
	dissect_next_http_packet = 0;

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
    bool first_char = true;

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
      } else if(!first_char)
	_name[j++] = payload[i];

      first_char = false;
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

  /* Already dissected ? */
  if(protos.netbios.name)
    return;

  if(((payload[2] & 0x80) /* NetBIOS Response */ || ((payload[2] & 0x78) == 0x28 /* NetBIOS Registration */))
     && (payload_len >= 12)
     && (ndpi_netbios_name_interpret((u_char*)&payload[12], payload_len - 12,
				     (u_char*)name, sizeof(name)) > 0)
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
  u_int8_t old_verdict = passVerdict;
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

  quota_exceeded = above_quota ? 1 : 0;
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
  bool nf_existing_flow;

  /* netfilter (depending on configured timeouts) could expire a flow before than
     ntopng. This heuristics attempt to detect such events.

     Basically, if netfilter is sending counters for a new flow and ntopng
     already have an existing flow matching the same 5-tuple, we sum counters
     rather than overwriting them.

     A complete solution would require the registration of a netfilter check
     and the detection of event NFCT_T_DESTROY.
  */
  nf_existing_flow = !(get_packets_cli2srv() > s2d_pkts || get_bytes_cli2srv() > s2d_bytes
		       || get_packets_srv2cli() > d2s_pkts || get_bytes_srv2cli() > d2s_bytes);

  updateSeen();

  if(last_conntrack_update > 0) {
    float tdiff_msec = (now - last_conntrack_update)*1000;
    updateThroughputStats(tdiff_msec,
      nf_existing_flow ? s2d_pkts - get_packets_cli2srv() : s2d_pkts,
      nf_existing_flow ? s2d_bytes - get_bytes_cli2srv() : s2d_bytes,
      0,
      nf_existing_flow ? d2s_pkts - get_packets_srv2cli() : d2s_pkts,
      nf_existing_flow ? d2s_bytes - get_bytes_srv2cli() : d2s_bytes,
      0);
  }

  /*
    We need to set last_conntrack_update even with 0 packtes/bytes
    as this function has been called only within netfilter through
    the conntrack handler, and thus the flow is still alive.
  */
  last_conntrack_update = now;

  static_cast<NetfilterInterface*>(iface)->incStatsConntrack(isIngress2EgressDirection(), now, eth_proto,
							     getStatsProtocol(), get_protocol_category(),
							     protocol,
							     nf_existing_flow ? s2d_bytes - get_bytes_cli2srv() : s2d_bytes,
							     nf_existing_flow ? s2d_pkts - get_packets_cli2srv() : s2d_pkts);

  static_cast<NetfilterInterface*>(iface)->incStatsConntrack(!isIngress2EgressDirection(), now, eth_proto,
							     getStatsProtocol(), get_protocol_category(),
							     protocol,
							     nf_existing_flow ? d2s_bytes - get_bytes_srv2cli() : d2s_bytes,
							     nf_existing_flow ? d2s_pkts - get_packets_srv2cli() : d2s_pkts);

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

void Flow::setParsedeBPFInfo(const ParsedeBPF * const _ebpf, bool swap_directions) {
  ParsedeBPF *cur = NULL;
  bool update_ok = true;

  if(!_ebpf)
    return;

  if(!iface->hasSeenEBPFEvents())
    iface->setSeenEBPFEvents();

  if(!ebpf)
    cur = ebpf = new (std::nothrow) ParsedeBPF(*_ebpf, swap_directions);
  else
    update_ok = ebpf->update(_ebpf);

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

    if(!iface->hasSeenPods() && (
       (cur->src_container_info.data_type == container_info_data_type_k8s && cur->src_container_info.data.k8s.pod) ||
       (cur->dst_container_info.data_type == container_info_data_type_k8s && cur->dst_container_info.data.k8s.pod)))
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
					  ebpf ? ebpf->src_process_info.process_name : NULL,
					  has_malicious_cli_signature);
  }
}

/* ***************************************************** */

void Flow::updateSrvJA3() {
  if(srv_host && isTLS() && protos.tls.ja3.server_hash) {
    srv_host->getJA3Fingerprint()->update(protos.tls.ja3.server_hash,
					  ebpf ? ebpf->dst_process_info.process_name : NULL, false);
  }
}

/* ***************************************************** */

void Flow::updateHASSH(bool as_client) {
  if(!isSSH())
    return;

  Host *h = as_client ? get_cli_host() : get_srv_host();
  const char *hassh = as_client ? protos.ssh.hassh.client_hash : protos.ssh.hassh.server_hash;
  ProcessInfo *pinfo = NULL;
  Fingerprint *fp;

  if(ebpf)
    pinfo = as_client ? &ebpf->src_process_info : &ebpf->dst_process_info;

  if(h && hassh && hassh[0] != '\0' && (fp = h->getHASSHFingerprint()))
    fp->update(hassh, pinfo ? pinfo->process_name : NULL, false /* We track client JA3 */);
}

/* ***************************************************** */

void Flow::fillZmqFlowCategory(const ParsedFlow *zflow, ndpi_protocol *res) const {
  struct ndpi_detection_module_struct *ndpi_struct = iface->get_ndpi_struct();
  const char *dst_name = NULL;
  const IpAddress *cli_ip = get_cli_ip_addr(), *srv_ip = get_srv_ip_addr();

  if(cli_ip && srv_ip && cli_ip->isIPv4()) {
    if(ndpi_fill_ip_protocol_category(ndpi_struct, cli_ip->get_ipv4(), srv_ip->get_ipv4(), res))
      return;
  }

  switch(ndpi_get_lower_proto(*res)) {
  case NDPI_PROTOCOL_DNS:
    dst_name = zflow->dns_query;
    break;
  case NDPI_PROTOCOL_HTTP_PROXY:
  case NDPI_PROTOCOL_HTTP:
    dst_name = zflow->http_site;
    break;
  case NDPI_PROTOCOL_TLS:
    dst_name = zflow->tls_server_name;
    break;
  default:
    break;
  }

  if(dst_name) {
    int rc;
    ndpi_protocol_match_result tmp;
    ndpi_protocol_category_t c;

    /* Match for custom protocols (protos.txt) */
    if((rc = ndpi_match_string_subprotocol(ndpi_struct, (char*)dst_name, strlen(dst_name), &tmp)) != 0) {
      if(rc >= NDPI_MAX_SUPPORTED_PROTOCOLS) {
	/* If the protocol is greater than NDPI_MAX_SUPPORTED_PROTOCOLS, it means it is
           a custom protocol so the application protocol received from nprobe can be
           overridden */
	if(res->master_protocol == NDPI_PROTOCOL_UNKNOWN)
	  res->master_protocol = res->app_protocol;

	res->app_protocol = (ndpi_protocol_category_t)rc;
      }
    }

    /* Match for custom categories */
    if(ndpi_match_custom_category(ndpi_struct, (char*)dst_name, strlen(dst_name), &c) == 0)
      res->category = c;
  }
}

/* ***************************************************** */

void Flow::lua_get_status(lua_State* vm) const {
  lua_push_bool_table_entry(vm, "flow.idle", idle());
  lua_push_uint64_table_entry(vm, "flow.status", getPredominantAlert().id);

  alerts_map.lua(vm, "alerts_map");

  if(isFlowAlerted()) {
    lua_push_bool_table_entry(vm, "flow.alerted", true);
    lua_push_uint64_table_entry(vm, "predominant_alert", getPredominantAlert().id);
    lua_push_uint64_table_entry(vm, "predominant_alert_score", getPredominantAlertScore());
  }
}

/* ***************************************************** */

void Flow::lua_get_protocols(lua_State* vm) const {
  char buf[64];

  lua_push_uint64_table_entry(vm, "proto.l4_id", get_protocol());
  lua_push_str_table_entry(vm, "proto.l4", get_protocol_name());

  if(((get_packets_cli2srv() + get_packets_srv2cli()) > NDPI_MIN_NUM_PACKETS)
     || (ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN)
     || (iface->is_ndpi_enabled() && detection_completed)
     || iface->isSampledTraffic()
     || (iface->getIfType() == interface_type_ZMQ)
     || (iface->getIfType() == interface_type_SYSLOG)
     || (iface->getIfType() == interface_type_ZC_FLOW)) {
    lua_push_str_table_entry(vm, "proto.ndpi", get_detected_protocol_name(buf, sizeof(buf)));
    lua_push_uint64_table_entry(vm, "proto.ndpi_id", ndpiDetectedProtocol.app_protocol);
    lua_push_uint64_table_entry(vm, "proto.ndpi_informative_proto", (!ndpi_is_subprotocol_informative(NULL, ndpiDetectedProtocol.master_protocol) ?
                                                                      ndpiDetectedProtocol.app_protocol : ndpiDetectedProtocol.master_protocol));
    lua_push_uint64_table_entry(vm, "proto.master_ndpi_id", ndpiDetectedProtocol.master_protocol);
  } else {
    lua_push_str_table_entry(vm, "proto.ndpi", (char*)CONST_TOO_EARLY);
    lua_push_int32_table_entry(vm, "proto.ndpi_id", -1);
    lua_push_int32_table_entry(vm, "proto.master_ndpi_id", -1);
  }

  lua_push_str_table_entry(vm, "proto.ndpi_breed", get_protocol_breed_name());
  lua_push_bool_table_entry(vm, "proto.is_encrypted", isEncryptedProto());

  lua_push_uint64_table_entry(vm, "proto.ndpi_cat_id", get_protocol_category());
  lua_push_str_table_entry(vm, "proto.ndpi_cat", get_protocol_category_name());

  if(getAddressFamilyProtocol())
    lua_push_str_table_entry(vm, "proto.ndpi_address_family", getAddressFamilyProtocol());

  if(get_custom_category_file())
    lua_push_str_table_entry(vm, "proto.ndpi_cat_file", get_custom_category_file());
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
  lua_push_float_table_entry(vm,  "throughput_bps",       get_bytes_thpt());
  lua_push_uint64_table_entry(vm, "throughput_trend_bps", bytes_thpt_trend);
  lua_push_float_table_entry(vm,  "top_throughput_pps",   top_pkts_thpt);
  lua_push_float_table_entry(vm,  "throughput_pps",       get_pkts_thpt());
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

    if(h->isProtocolServer())
      lua_push_bool_table_entry(vm, client ? "cli.protocol_server" : "srv.protocol_server", true);
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

void Flow::lua_get_mac(lua_State *vm, bool client) const {
  char buf[24];
  Host *h = client ? get_cli_host() : get_srv_host();

  if(h)
    lua_push_str_table_entry(vm, client ? "cli.mac" : "srv.mac", Utils::formatMac(h->get_mac(), buf, sizeof(buf)));
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

      lua_push_bool_table_entry(vm, client ? "cli.localhost" : "srv.localhost", h->isLocalHost());
      lua_push_bool_table_entry(vm, client ? "cli.systemhost" : "srv.systemhost", h->isSystemHost());
      lua_push_bool_table_entry(vm, client ? "cli.blacklisted" : "srv.blacklisted", client ? isBlacklistedClient() : isBlacklistedServer());
      lua_push_bool_table_entry(vm, client ? "cli.broadcast_domain_host" : "srv.broadcast_domain_host", h->isBroadcastDomainHost());
      lua_push_bool_table_entry(vm, client ? "cli.dhcpHost" : "srv.dhcpHost", h->isDHCPHost());
      lua_push_int32_table_entry(vm, client ? "cli.network_id" : "srv.network_id", h->get_local_network_id());
      lua_push_uint64_table_entry(vm, client ? "cli.pool_id" : "srv.pool_id", h->get_host_pool());
      lua_push_uint64_table_entry(vm, client ? "cli.asn" : "srv.asn", h->get_asn());
      lua_push_str_table_entry(vm, client ? "cli.country" : "srv.country", h->get_country(cb, sizeof(cb)));
      lua_push_str_table_entry(vm, client ? "cli.os" : "srv.os", h->getOSDetail(os, sizeof(os)));
    }
  }

  lua_get_mac(vm, client);

  if(h_ip)
    lua_push_bool_table_entry(vm, client ? "cli.private" : "srv.private", h_ip->isPrivateAddress());
}

/* ***************************************************** */

/* Get minimal flow information.
 * NOTE: this is intended to be called only from flow user scripts
 * via flow.getInfo(). mask_host/allowed networks are not honored.
 */
void Flow::lua_get_min_info(lua_State *vm) {
  char buf[64];
  char *info = getFlowInfo(buf, sizeof(buf), true);

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "cli.ip", get_cli_ip_addr()->print(buf, sizeof(buf)));
  lua_push_str_table_entry(vm, "srv.ip", get_srv_ip_addr()->print(buf, sizeof(buf)));

  if(get_cli_host() && get_cli_host()->isProtocolServer())
    lua_push_bool_table_entry(vm, "cli.protocol_server", true);
  else if(get_srv_host() && get_srv_host()->isProtocolServer())
    lua_push_bool_table_entry(vm, "srv.protocol_server", true);

  lua_push_int32_table_entry(vm, "cli.port", get_cli_port());
  lua_push_int32_table_entry(vm, "srv.port", get_srv_port());
  lua_push_bool_table_entry(vm, "cli.localhost", cli_host ? cli_host->isLocalHost() : false);
  lua_push_bool_table_entry(vm, "srv.localhost", srv_host ? srv_host->isLocalHost() : false);
  lua_push_int32_table_entry(vm, "duration", get_duration());
  lua_push_str_table_entry(vm, "proto.l4", get_protocol_name());
  lua_push_str_table_entry(vm, "proto.ndpi", get_detected_protocol_name(buf, sizeof(buf)));
  lua_push_str_table_entry(vm, "proto.ndpi_app", ndpi_get_proto_name(iface->get_ndpi_struct(), ndpiDetectedProtocol.app_protocol));
  lua_push_str_table_entry(vm, "proto.ndpi_cat", get_protocol_category_name());
  lua_push_uint64_table_entry(vm, "proto.ndpi_cat_id", get_protocol_category());
  lua_push_str_table_entry(vm, "proto.ndpi_breed", get_protocol_breed_name());
  lua_push_bool_table_entry(vm, "proto.is_encrypted", isEncryptedProto());
  lua_push_uint64_table_entry(vm, "cli2srv.bytes", get_bytes_cli2srv());
  lua_push_uint64_table_entry(vm, "srv2cli.bytes", get_bytes_srv2cli());
  lua_push_uint64_table_entry(vm, "cli2srv.packets", get_packets_cli2srv());
  lua_push_uint64_table_entry(vm, "srv2cli.packets", get_packets_srv2cli());
  if(info) lua_push_str_table_entry(vm, "info", info);
}

/* ***************************************************** */

/*
 * Get minimal flow information.
 * NOTE: this is intended to be called only from flow user scripts
 */
void Flow::getInfo(ndpi_serializer *serializer) {
  char buf[64];
  char *info = getFlowInfo(buf, sizeof(buf), true);

  ndpi_serialize_string_string(serializer, "cli.ip", get_cli_ip_addr()->print(buf, sizeof(buf)));
  ndpi_serialize_string_string(serializer, "srv.ip", get_srv_ip_addr()->print(buf, sizeof(buf)));

  if(get_cli_host() && get_cli_host()->isProtocolServer())
    ndpi_serialize_string_boolean(serializer, "cli.protocol_server", true);
  else if(get_srv_host() && get_srv_host()->isProtocolServer())
    ndpi_serialize_string_boolean(serializer, "srv.protocol_server", true);

  ndpi_serialize_string_int32(serializer, "cli.port", get_cli_port());
  ndpi_serialize_string_int32(serializer, "srv.port", get_srv_port());
  ndpi_serialize_string_boolean(serializer, "cli.localhost", cli_host ? cli_host->isLocalHost() : false);
  ndpi_serialize_string_boolean(serializer, "srv.localhost", srv_host ? srv_host->isLocalHost() : false);
  ndpi_serialize_string_int32(serializer, "duration", get_duration());
  ndpi_serialize_string_string(serializer, "proto.l4", get_protocol_name());
  ndpi_serialize_string_string(serializer, "proto.ndpi", get_detected_protocol_name(buf, sizeof(buf)));
  ndpi_serialize_string_string(serializer, "proto.ndpi_app", ndpi_get_proto_name(iface->get_ndpi_struct(), ndpiDetectedProtocol.app_protocol));
  ndpi_serialize_string_string(serializer, "proto.ndpi_cat", get_protocol_category_name());
  ndpi_serialize_string_uint64(serializer, "proto.ndpi_cat_id", get_protocol_category());
  ndpi_serialize_string_string(serializer, "proto.ndpi_breed", get_protocol_breed_name());
  ndpi_serialize_string_uint64(serializer, "cli2srv.bytes", get_bytes_cli2srv());
  ndpi_serialize_string_uint64(serializer, "srv2cli.bytes", get_bytes_srv2cli());
  ndpi_serialize_string_uint64(serializer, "cli2srv.packets", get_packets_cli2srv());
  ndpi_serialize_string_uint64(serializer, "srv2cli.packets", get_packets_srv2cli());
  if(info) ndpi_serialize_string_string(serializer, "info", info);
}

/* ***************************************************** */

u_int32_t Flow::getCliTcpIssues() {
  return(stats.get_cli2srv_tcp_retr() + stats.get_cli2srv_tcp_ooo() + stats.get_cli2srv_tcp_lost());
}

u_int32_t Flow::getSrvTcpIssues() {
  return(stats.get_srv2cli_tcp_retr() + stats.get_srv2cli_tcp_ooo() + stats.get_srv2cli_tcp_lost());
}

double Flow::getCliRetrPercentage() {
  if(get_packets_cli2srv() > 10 /* Do not compute retrasmissions with too few packets */)
    return((double)stats.get_cli2srv_tcp_retr()/ (double)get_packets_cli2srv());
  else
    return 0;
}

double Flow::getSrvRetrPercentage() {
  if(get_packets_srv2cli() > 10 /* Do not compute retrasmissions with too few packets */)
    return((double)stats.get_srv2cli_tcp_retr()/ (double)get_packets_srv2cli());
  else
    return 0;
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
  lua_push_uint64_table_entry(vm, "last_seen", get_last_seen());
  lua_push_bool_table_entry(vm, "twh_over", twh_over ? true : false);
}

/* ***************************************************** */

void Flow::lua_snmp_info(lua_State *vm) {
  char str[16];
  u_int32_t device_ip = htonl(flow_device.device_ip);
  inet_ntop(AF_INET, &(device_ip), str, INET_ADDRSTRLEN);
  lua_push_str_table_entry(vm, "device_ip", str);
  lua_push_uint64_table_entry(vm, "in_index", flow_device.in_index);
  lua_push_uint64_table_entry(vm, "out_index", flow_device.out_index);
  lua_push_uint64_table_entry(vm, "observation_point_id", flow_device.observation_point_id);
}

/* ***************************************************** */

void Flow::lua_device_protocol_allowed_info(lua_State *vm) {
  bool cli_allowed, srv_allowed;

  lua_newtable(vm);

  if(!cli_host || !srv_host)
    return;

  cli_allowed = isCliDeviceAllowedProtocol();
  srv_allowed = isSrvDeviceAllowedProtocol();

  lua_push_int32_table_entry(vm, "cli.devtype", cli_host->getMac() ? cli_host->getMac()->getDeviceType() : device_unknown);
  lua_push_int32_table_entry(vm, "srv.devtype", srv_host->getMac() ? srv_host->getMac()->getDeviceType() : device_unknown);

  lua_push_bool_table_entry(vm, "cli.allowed", cli_allowed);
  if(!cli_allowed)
    lua_push_int32_table_entry(vm, "cli.disallowed_proto", getCliDeviceDisallowedProtocol());

  lua_push_bool_table_entry(vm, "srv.allowed", srv_allowed);
  if(!srv_allowed)
    lua_push_int32_table_entry(vm, "srv.disallowed_proto", getSrvDeviceDisallowedProtocol());
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
    lua_push_int32_table_entry(vm, "protos.tls_version", protos.tls.tls_version);

    if(protos.tls.server_names)
      lua_push_str_table_entry(vm, "protos.tls.server_names", protos.tls.server_names);

    if(protos.tls.client_alpn)
      lua_push_str_table_entry(vm, "protos.tls.client_alpn", protos.tls.client_alpn);

    if(protos.tls.client_tls_supported_versions)
      lua_push_str_table_entry(vm, "protos.tls.client_tls_supported_versions", protos.tls.client_tls_supported_versions);

    if(protos.tls.issuerDN)
      lua_push_str_table_entry(vm, "protos.tls.issuerDN", protos.tls.issuerDN);

    if(protos.tls.subjectDN)
      lua_push_str_table_entry(vm, "protos.tls.subjectDN", protos.tls.subjectDN);

    if(protos.tls.client_requested_server_name)
      lua_push_str_table_entry(vm, "protos.tls.client_requested_server_name",
			       protos.tls.client_requested_server_name);

    if(protos.tls.notBefore && protos.tls.notAfter) {
      lua_push_uint32_table_entry(vm, "protos.tls.notBefore", protos.tls.notBefore);
      lua_push_uint32_table_entry(vm, "protos.tls.notAfter", protos.tls.notAfter);
    }

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

void Flow::getTLSInfo(ndpi_serializer *serializer) const {
  if(isTLS()) {
    ndpi_serialize_string_int32(serializer, "tls_version", protos.tls.tls_version);

    if(protos.tls.server_names)
      ndpi_serialize_string_string(serializer, "server_names", protos.tls.server_names);

    if(protos.tls.client_alpn)
      ndpi_serialize_string_string(serializer, "client_alpn", protos.tls.client_alpn);

    if(protos.tls.client_tls_supported_versions)
      ndpi_serialize_string_string(serializer, "client_tls_supported_versions", protos.tls.client_tls_supported_versions);

    if(protos.tls.issuerDN)
      ndpi_serialize_string_string(serializer, "issuerDN", protos.tls.issuerDN);

    if(protos.tls.subjectDN)
      ndpi_serialize_string_string(serializer, "subjectDN", protos.tls.subjectDN);

    if(protos.tls.client_requested_server_name)
      ndpi_serialize_string_string(serializer, "client_requested_server_name",
			           protos.tls.client_requested_server_name);

    if(protos.tls.notBefore && protos.tls.notAfter) {
      ndpi_serialize_string_int32(serializer, "notBefore", protos.tls.notBefore);
      ndpi_serialize_string_int32(serializer, "notAfter", protos.tls.notAfter);
    }

    if(protos.tls.ja3.client_hash) {
      ndpi_serialize_string_string(serializer, "ja3.client_hash", protos.tls.ja3.client_hash);

      if(has_malicious_cli_signature)
	ndpi_serialize_string_boolean(serializer, "ja3.client_malicious", true);
    }

    if(protos.tls.ja3.server_hash) {
      ndpi_serialize_string_string(serializer, "ja3.server_hash", protos.tls.ja3.server_hash);
      ndpi_serialize_string_string(serializer, "ja3.server_unsafe_cipher",
			           cipher_weakness2str(protos.tls.ja3.server_unsafe_cipher));
      ndpi_serialize_string_int32(serializer, "ja3.server_cipher",
				  protos.tls.ja3.server_cipher);

      if(has_malicious_srv_signature)
	ndpi_serialize_string_boolean(serializer, "ja3.server_malicious", true);
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

void Flow::getSSHInfo(ndpi_serializer *serializer) const {
  if(isSSH()) {
    if(protos.ssh.client_signature) ndpi_serialize_string_string(serializer, "client_signature", protos.ssh.client_signature);
    if(protos.ssh.server_signature) ndpi_serialize_string_string(serializer, "server_signature", protos.ssh.server_signature);

    if(protos.ssh.hassh.client_hash) ndpi_serialize_string_string(serializer, "hassh.client_hash", protos.ssh.hassh.client_hash);
    if(protos.ssh.hassh.server_hash) ndpi_serialize_string_string(serializer, "hassh.server_hash", protos.ssh.hassh.server_hash);
  }
}

/* ***************************************************** */

void Flow::lua_get_http_info(lua_State *vm) const {
  if(isHTTP()) {
    if(protos.http.last_url) {
      lua_push_str_table_entry(vm, "protos.http.last_method", ndpi_http_method2str(protos.http.last_method));
      lua_push_uint64_table_entry(vm, "protos.http.last_return_code", protos.http.last_return_code);
      lua_push_str_table_entry(vm, "protos.http.last_url", protos.http.last_url);
      if(protos.http.last_user_agent)
	lua_push_str_table_entry(vm, "protos.http.last_user_agent", protos.http.last_user_agent);
    }

    if(host_server_name)
      lua_push_str_table_entry(vm, "protos.http.server_name", host_server_name);
  }
}

/* ***************************************************** */

void Flow::getHTTPInfo(ndpi_serializer *serializer) const {
  if(isHTTP()) {
    if(protos.http.last_url) {
      ndpi_serialize_string_string(serializer, "last_method", ndpi_http_method2str(protos.http.last_method));
      ndpi_serialize_string_uint64(serializer, "last_return_code", protos.http.last_return_code);
      ndpi_serialize_string_string(serializer, "last_url", protos.http.last_url);
      ndpi_serialize_string_string(serializer, "last_user_agent", protos.http.last_user_agent);
    }

    if(host_server_name)
      ndpi_serialize_string_string(serializer, "server_name", host_server_name);
  }
}

/* ***************************************************** */

void Flow::lua_get_dns_info(lua_State *vm) const {
  if(isDNS()) {
    if(protos.dns.last_query) {
      lua_push_uint64_table_entry(vm, "protos.dns.last_query_type", protos.dns.last_query_type);
      lua_push_uint64_table_entry(vm, "protos.dns.last_return_code", protos.dns.last_return_code);
      lua_push_str_table_entry(vm, "protos.dns.last_query", protos.dns.last_query);

      if(hasInvalidDNSQueryChars())
        lua_push_bool_table_entry(vm, "protos.dns.invalid_chars_in_query", true);
    }
  }
}

/* ***************************************************** */

void Flow::getDNSInfo(ndpi_serializer *serializer) const {
  if(isDNS()) {
    if(protos.dns.last_query) {
      ndpi_serialize_string_int64(serializer, "last_query_type", protos.dns.last_query_type);
      ndpi_serialize_string_int64(serializer, "last_return_code", protos.dns.last_return_code);
      ndpi_serialize_string_string(serializer, "last_query", protos.dns.last_query);

      if(hasInvalidDNSQueryChars())
        ndpi_serialize_string_boolean(serializer, "invalid_chars_in_query", true);
    }
  }
}

/* ***************************************************** */

void Flow::getICMPInfo(ndpi_serializer *serializer) const {
  if(isICMP()) {
    ndpi_serialize_string_int32(serializer, "type", isBidirectional() ? protos.icmp.srv2cli.icmp_type : protos.icmp.cli2srv.icmp_type);
    ndpi_serialize_string_int32(serializer, "code", isBidirectional() ? protos.icmp.srv2cli.icmp_code : protos.icmp.cli2srv.icmp_code);
  }
}

/* ***************************************************** */

void Flow::getMDNSInfo(ndpi_serializer *serializer) const {
  if(isMDNS()) {
    ndpi_serialize_string_string(serializer, "answer", protos.mdns.answer);
    ndpi_serialize_string_string(serializer, "name", protos.mdns.name);
    ndpi_serialize_string_string(serializer, "name_txt", protos.mdns.name_txt);
    ndpi_serialize_string_string(serializer, "ssid", protos.mdns.ssid);
  }
}

/* ***************************************************** */

void Flow::getNetBiosInfo(ndpi_serializer *serializer) const {
  if(isNetBIOS()) {
    ndpi_serialize_string_string(serializer, "name", protos.netbios.name);
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

bool Flow::hasDissectedTooManyPackets() {
  u_int32_t num_packets;

  if(iface->isSampledTraffic() || (!iface->is_ndpi_enabled()))
    /* Cannot reliably process sampled traffic, giveup the dissection */
    return(true);

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

  return((num_packets >= NDPI_MIN_NUM_PACKETS) && (!needsExtraDissection()));
}

/* ***************************************************** */

void Flow::setNormalToAlertedCounters() {
  Host *cli_h = get_cli_host(), *srv_h = get_srv_host();

  if(cli_h) {
    u_int16_t local_net_id = cli_h->get_local_network_id();
    NetworkStats *net_stats = cli_h->getNetworkStats(local_net_id);
    AutonomousSystem *cli_as = cli_h ? cli_h->get_as() : NULL;

    if(cli_as) cli_as->incNumAlertedFlows(true /* As client */);
    if(net_stats) net_stats->incNumAlertedFlows(true /* As client */);
    cli_h->incNumAlertedFlows(true /* As client */);
    cli_h->incTotalAlerts();
  }

  if(srv_h) {
    u_int16_t local_net_id = srv_h->get_local_network_id();
    NetworkStats *net_stats = srv_h->getNetworkStats(local_net_id);
    AutonomousSystem *srv_as = srv_h ? srv_h->get_as() : NULL;

    if(srv_as) srv_as->incNumAlertedFlows(true /* As client */);
    if(net_stats) net_stats->incNumAlertedFlows(false /* As server */);
    srv_h->incNumAlertedFlows(false /* As server */);
    srv_h->incTotalAlerts();
  }

  /* Set this into the partializable flow traffic stats as well (necessary for view interfaces) */
  stats.setFlowAlerted();

#ifdef ALERTED_FLOWS_DEBUG
  iface_alert_inc = true;
#endif
}

/* ***************************************************** */

void Flow::setProtocolJSONInfo() {
   if(!json_protocol_info) {
      ndpi_serializer *json_serializer = NULL;
      char *json = NULL;
      u_int32_t json_len = 0;

      json_serializer = (ndpi_serializer *) malloc(sizeof(ndpi_serializer));

      if(json_serializer == NULL)
         return ;

      if(ndpi_init_serializer(json_serializer, ndpi_serialization_format_json) == -1) {
         free(json_serializer);
         return ;
      }

      /* Serialize alert JSON
       * Note: this is called by setPredominantAlertInfo in case of alerts */
      getProtocolJSONInfo(json_serializer);

      if(json_serializer)
         json = ndpi_serializer_get_buffer(json_serializer, &json_len);

      json_protocol_info = strdup(json ? json : "");

      if(json_serializer) {
         ndpi_term_serializer(json_serializer);
         free(json_serializer);
      }
   }
}

/* ***************************************************** */

void Flow::getJSONRiskInfo(ndpi_serializer *serializer) {
  if(serializer && riskInfo) {
    ndpi_serialize_string_string(serializer, "flow_risk_info", riskInfo);
  }
}

/* ***************************************************** */

void Flow::getProtocolJSONInfo(ndpi_serializer *serializer) {
  /* Check JSON info != NULL to not override info */

  if(serializer == NULL)
    return;

  u_int16_t l7proto = getLowerProtocol();

  ndpi_serialize_start_of_block(serializer, "proto"); /* proto block */

  /* Adding protocol info; switch the lower application protocol */
  switch(l7proto) {
    case NDPI_PROTOCOL_DNS:
      ndpi_serialize_start_of_block(serializer, "dns");
      getDNSInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
    break;

    case NDPI_PROTOCOL_HTTP:
    case NDPI_PROTOCOL_HTTP_PROXY:
      ndpi_serialize_start_of_block(serializer, "http");
      getHTTPInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
    break;

    case NDPI_PROTOCOL_TLS:
    case NDPI_PROTOCOL_MAIL_IMAPS:
    case NDPI_PROTOCOL_MAIL_SMTPS:
    case NDPI_PROTOCOL_MAIL_POPS:
    case NDPI_PROTOCOL_QUIC:
      ndpi_serialize_start_of_block(serializer, "tls");
      getTLSInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
    break;

    case NDPI_PROTOCOL_IP_ICMP:
    case NDPI_PROTOCOL_IP_ICMPV6:
      ndpi_serialize_start_of_block(serializer, "icmp");
      getICMPInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
    break;

    case NDPI_PROTOCOL_MDNS:
      ndpi_serialize_start_of_block(serializer, "mdns");
      getMDNSInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
    break;

    case NDPI_PROTOCOL_NETBIOS:
      ndpi_serialize_start_of_block(serializer, "netbios");
      getNetBiosInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
    break;

    case NDPI_PROTOCOL_SSH:
      ndpi_serialize_start_of_block(serializer, "ssh");
      getSSHInfo(serializer);
      ndpi_serialize_end_of_block(serializer);
    break;
  }

  if(getErrorCode() != 0)
    ndpi_serialize_string_uint32(serializer, "l7_error_code", getErrorCode());

  if(getConfidence() != NDPI_CONFIDENCE_UNKNOWN) {
    switch(getConfidence()) {
    case NDPI_CONFIDENCE_DPI_CACHE:
    case NDPI_CONFIDENCE_DPI:
    case NDPI_CONFIDENCE_NBPF:
        ndpi_serialize_string_uint32(serializer, "confidence", (ndpiConfidence) confidence_dpi);
      break;

      default:
	ndpi_serialize_string_uint32(serializer, "confidence", (ndpiConfidence) confidence_guessed);
      break;
    }
  }

  ndpi_serialize_end_of_block(serializer); /* proto block */

  if (ebpf && ebpf->process_info_set) {
    ndpi_serialize_start_of_block(serializer, "process");

    if (ebpf->src_process_info.process_name)
      ndpi_serialize_string_string(serializer, "src_process_name", ebpf->src_process_info.process_name);

    if (ebpf->dst_process_info.process_name)
      ndpi_serialize_string_string(serializer, "dst_process_name", ebpf->dst_process_info.process_name);

    ndpi_serialize_end_of_block(serializer); /* process block */
  }
}

/* ***************************************************** */

void Flow::setPredominantAlertInfo(FlowAlert *alert) {
  ndpi_serializer *alert_json_serializer = NULL;
  char *alert_json = NULL;
  u_int32_t alert_json_len = 0;

  if (!alert) return;

  predominant_alert_info.is_cli_attacker = alert->isCliAttacker();
  predominant_alert_info.is_cli_victim = alert->isCliVictim();
  predominant_alert_info.is_srv_attacker = alert->isSrvAttacker();
  predominant_alert_info.is_srv_victim = alert->isSrvVictim();

  /* Serialize alert JSON
   * Note: this will also add protocol information by calling flow->getProtocolJSONInfo */
  alert_json_serializer = alert->getSerializedAlert();

  if(alert_json_serializer)
    alert_json = ndpi_serializer_get_buffer(alert_json_serializer, &alert_json_len);

  if (json_protocol_info != NULL) free(json_protocol_info);
  json_protocol_info = strdup(alert_json ? alert_json : "");

  if(alert_json_serializer) {
    ndpi_term_serializer(alert_json_serializer);
    free(alert_json_serializer);
  }
}

/* ***************************************************** */

void Flow::setPredominantAlert(FlowAlertType alert_type, u_int16_t score) {

  if(predominant_alert_score) {
    /* Decrease the value previously increased for the previous alert (if not normal) */
    iface->decNumAlertedFlows(this, Utils::mapScoreToSeverity(predominant_alert_score));
  }

  /* Increase the value for the newly set level (if not normal) */
  iface->incNumAlertedFlows(this, Utils::mapScoreToSeverity(score));

  /* Update the current predominant alert and score */
  predominant_alert = alert_type;
  predominant_alert_score = score;
}

/* ***************************************************** */

/*
  This method is called to set score and various other values of the flow

  Return true if the activities are completed successfully, of false otherwise
*/
bool Flow::setAlertsBitmap(FlowAlertType alert_type, u_int16_t cli_inc, u_int16_t srv_inc, bool async) {
  ScoreCategory score_category = Utils::mapAlertToScoreCategory(alert_type.category);
  u_int16_t flow_inc;
  Host *cli_h = get_cli_host(), *srv_h = get_srv_host();

  /* Safety checks */
  cli_inc = min_val(cli_inc, SCORE_MAX_VALUE);
  srv_inc = min_val(srv_inc, SCORE_MAX_VALUE);
  if(cli_inc + srv_inc > SCORE_MAX_VALUE)
    srv_inc = SCORE_MAX_VALUE - cli_inc;

  flow_inc = cli_inc + srv_inc;

#ifdef DEBUG_SCORE
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Set alert score: %u (%u/%u) | MAX VALUE: %u", flow_inc, cli_inc, srv_inc, SCORE_MAX_VALUE);
#endif

  if(alert_type.id == flow_alert_normal) {
#ifdef DEBUG_SCORE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Discarding alert (normal)");
#endif
    return false;
  }

  /* Check if the same alert has been already triggered and
   * accounted in the score, unless this is a "sync" alert */
  if(async && alerts_map.isSetBit(alert_type.id)) {
#ifdef DEBUG_SCORE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Discarding alert (already set)");
#endif
    return false;
  }

  /*
    Check host filter and if such alert needs to be disabled
    due to alert exclusions
  */
  if((cli_h && cli_h->isFlowAlertDisabled(alert_type))
     || (srv_h && srv_h->isFlowAlertDisabled(alert_type))) {
#ifdef DEBUG_SCORE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Discarding alert (host filter)");
#endif
    return false;
  }

  if(!isFlowAlerted())
    /* This is the first time an alert is set on this flow. The flow was normal and now becomes alerted. */
    setNormalToAlertedCounters();

  alerts_map.setBit(alert_type.id);

  flow_score += flow_inc;

  stats.incScore(cli_inc, score_category, true  /* as client */);
  stats.incScore(srv_inc, score_category, false /* as server */);

  if(!getInterface()->isView()) {
    /* For views, score increments are done periodically */
    if(cli_h) cli_h->incScoreValue(cli_inc, score_category, true  /* as client */);
    if(srv_h) srv_h->incScoreValue(srv_inc, score_category, false /* as server */);
  }

  /* Check if also the predominant alert_type should be updated */
  if(!isFlowAlerted() /* Flow is not yet alerted */
     || getPredominantAlertScore() < flow_inc /* The score of the current alerted alert_type is less than the score of this alert_type */) {
#ifdef DEBUG_SCORE
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting predominant with score: %u", flow_inc);
#endif
    setPredominantAlert(alert_type, flow_inc);
#ifdef DEBUG_SCORE
  } else {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Discarding alert (score <= %u)", getPredominantAlertScore());
#endif
  }

  return true;
}

/* *************************************** */

bool Flow::triggerAlertAsync(FlowAlertType alert_type, u_int16_t cli_inc, u_int16_t srv_inc) {
  bool res;

  res = setAlertsBitmap(alert_type, cli_inc, srv_inc, true);

  return res;
}

/* *************************************** */

bool Flow::triggerAlertSync(FlowAlert *alert, u_int16_t cli_inc, u_int16_t srv_inc) {
  bool res;

  res = setAlertsBitmap(alert->getAlertType(), cli_inc, srv_inc, false);

  /* Synchronous, this alert must be sent straight to the recipients now. Let's put it into the recipient queues. */
  if(alert) {
    if(ntop->getPrefs()->dontEmitFlowAlerts())
      /* Nothing to enqueue, can dispose the memory */
      delete alert;
    else if(res)
      /* enqueue the alert (memory is disposed automatically upon failing enqueues) */
      iface->enqueueFlowAlert(alert);
  }

  return res;
}

/* *************************************** */

void Flow::setExternalAlert(json_object *a) {

  /* In order to avoid concurrency issues with the getter, at most
   * 1 pending external alert is supported. */
  if(!external_alert.json) {
    json_object *val;

    if(!iface->hasSeenExternalAlerts())
      iface->setSeenExternalAlerts();

    if(json_object_object_get_ex(a, "source", &val))
      external_alert.source = strdup(json_object_get_string(val));

    external_alert.json = a;

    /* Manually trigger a periodic update to process the alert */
    trigger_immediate_periodic_update = true;
  }
}

/* *************************************** */

void Flow::luaRetrieveExternalAlert(lua_State *vm) {
  const char *json = external_alert.json ? json_object_to_json_string(external_alert.json) : NULL;

  if(json)
    lua_pushstring(vm, json);
  else
    lua_pushnil(vm);
}

/* *************************************** */

void Flow::updateEntropy(struct ndpi_analyze_struct *e,
			 u_int8_t *payload, u_int payload_len) {
  if(e != NULL) {
    for(u_int i=0; i<payload_len; i++)
      ndpi_data_add_value(e, payload[i]);
  }
}

/* *************************************** */

void Flow::lua_entropy(lua_State* vm) {
  if(entropy.c2s && entropy.s2c) {
    lua_newtable(vm);

    lua_push_float_table_entry(vm,  "client", getEntropy(true));
    lua_push_float_table_entry(vm,  "server", getEntropy(false));

    lua_pushstring(vm, "entropy");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

void Flow::check_swap() {
  if(!(get_cli_ip_addr()->isNonEmptyUnicastAddress() && !get_srv_ip_addr()->isNonEmptyUnicastAddress()) /* Everything that is NOT unicast-to-non-unicast needs to be checked */
     /* && get_cli_port() < 1024 // Relax this constraint and also apply to non-well-known ports such as 8080 */
     && get_cli_port() < get_srv_port())
    swap_requested = 1;
}

/* *************************************** */

void Flow::setJSONRiskInfo(char *r) {
  if(!r)
    return;

  if(riskInfo)
    free(riskInfo);

  // ntop->getTrace()->traceEvent(TRACE_INFO, "[%s]", r);

  riskInfo = strdup(r);
}

/* *************************************** */

char* Flow::getJSONRiskInfo() {
  return(riskInfo);
}
