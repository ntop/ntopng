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
  vlanId = _vlanId, protocol = _protocol, cli_port = _cli_port, srv_port = _srv_port;
  cli2srv_packets = 0, cli2srv_bytes = 0, cli2srv_goodput_bytes = 0,
    srv2cli_packets = 0, srv2cli_bytes = 0, srv2cli_goodput_bytes = 0,
    cli2srv_last_packets = 0, cli2srv_last_bytes = 0, srv2cli_last_packets = 0, srv2cli_last_bytes = 0,
    cli_host = srv_host = NULL, good_low_flow_detected = false,
    srv2cli_last_goodput_bytes = cli2srv_last_goodput_bytes = 0, good_ssl_hs = true,
    flow_alerted = flow_dropped_counts_increased = false, vrfId = 0;

  detection_completed = false;
  ndpiDetectedProtocol = ndpiUnknownProtocol;
  doNotExpireBefore = iface->getTimeLastPktRcvd() + DONT_NOT_EXPIRE_BEFORE_SEC;

#ifdef HAVE_NEDGE
  last_conntrack_update = 0;
  marker = MARKER_NO_ACTION;
#endif

  icmp_info = _icmp_info ? new (std::nothrow) ICMPinfo(*_icmp_info) : NULL;

  memset(&cli2srvStats, 0, sizeof(cli2srvStats)), memset(&srv2cliStats, 0, sizeof(srv2cliStats));

  ndpiFlow = NULL, cli_id = srv_id = NULL;
  cli_ebpf = srv_ebpf = NULL;
  json_info = strdup("{}"), cli2srv_direction = true, twh_over = twh_ok = false,
    dissect_next_http_packet = false,
    check_tor = false, host_server_name = NULL, diff_num_http_requests = 0,
    bt_hash = NULL, community_id_flow_hash = NULL;

  src2dst_tcp_flags = 0, dst2src_tcp_flags = 0, last_update_time.tv_sec = 0, last_update_time.tv_usec = 0,
    bytes_thpt = 0, goodput_bytes_thpt = 0, top_bytes_thpt = 0, top_pkts_thpt = 0;
  bytes_thpt_cli2srv  = 0, goodput_bytes_thpt_cli2srv = 0;
  bytes_thpt_srv2cli  = 0, goodput_bytes_thpt_srv2cli = 0;
  pkts_thpt = 0, pkts_thpt_cli2srv = 0, pkts_thpt_srv2cli = 0;
  cli2srv_last_bytes = 0, prev_cli2srv_last_bytes = 0, srv2cli_last_bytes = 0, prev_srv2cli_last_bytes = 0;
  cli2srv_last_packets = 0, prev_cli2srv_last_packets = 0, srv2cli_last_packets = 0, prev_srv2cli_last_packets = 0;
  top_bytes_thpt = 0, top_goodput_bytes_thpt = 0, applLatencyMsec = 0;

  last_db_dump.cli2srv_packets = 0, last_db_dump.srv2cli_packets = 0,
    last_db_dump.cli2srv_bytes = 0, last_db_dump.srv2cli_bytes = 0,
    last_db_dump.cli2srv_goodput_bytes = 0, last_db_dump.srv2cli_goodput_bytes = 0,
    last_db_dump.last_dump = 0;

  suricata_alert = NULL;

  memset(&protos, 0, sizeof(protos));
  memset(&flow_device, 0, sizeof(flow_device));

  PROFILING_SUB_SECTION_ENTER(iface, "Flow::Flow: iface->findFlowHosts", 7);
  iface->findFlowHosts(_vlanId, _cli_mac, _cli_ip, &cli_host, _srv_mac, _srv_ip, &srv_host);
  PROFILING_SUB_SECTION_EXIT(iface, 7);
  if(cli_host) { cli_host->incUses(); cli_host->incNumFlows(last_seen, true, srv_host);  }
  if(srv_host) { srv_host->incUses(); srv_host->incNumFlows(last_seen, false, cli_host); }
  
  if(icmp_info) {
    if(icmp_info->isPortUnreachable()) { //port unreachable icmpv6/icmpv4

      if(srv_host) srv_host->incNumUnreachableFlows(true  /* as server */);
      if(cli_host) cli_host->incNumUnreachableFlows(false /* as client */);
    } else if(icmp_info->isHostUnreachable(protocol)) {
      if(srv_host) srv_host->incNumHostUnreachableFlows(true  /* as server */);
      if(cli_host) cli_host->incNumHostUnreachableFlows(false /* as client */);
    }
  }
  
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
  memset(&tcp_stats_s2d, 0, sizeof(tcp_stats_s2d)), memset(&tcp_stats_d2s, 0, sizeof(tcp_stats_d2s));
  memset(&clientNwLatency, 0, sizeof(clientNwLatency)), memset(&serverNwLatency, 0, sizeof(serverNwLatency));

  if(!iface->isPacketInterface())
    last_update_time.tv_sec = (long)first_seen;

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  trafficProfile = NULL;
#else
  cli2srv_in = cli2srv_out = srv2cli_in = srv2cli_out = DEFAULT_SHAPER_ID;
  memset(&flowShaperIds, 0, sizeof(flowShaperIds));
  cli_quota_source = srv_quota_source = policy_source_default;
#endif
#endif

  switch(protocol) {
  case IPPROTO_TCP:
  case IPPROTO_UDP:
    if(iface->is_ndpi_enabled() && (!iface->isSampledTraffic()))
      allocDPIMemory();
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

  protos.ssl.dissect_certificate = true,
    protos.ssl.subject_alt_name_match = false;
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
  if(cli_host) cli_host->decNumFlows(last_seen, true, srv_host),  cli_host->decUses();
  if(srv_host) srv_host->decNumFlows(last_seen, false, cli_host), srv_host->decUses();

  if(json_info)        free(json_info);
  if(host_server_name) free(host_server_name);

  if(cli_ebpf) delete cli_ebpf;
  if(srv_ebpf) delete srv_ebpf;

  if(isHTTP()) {
    if(protos.http.last_method) free(protos.http.last_method);
    if(protos.http.last_url)    free(protos.http.last_url);
    if(protos.http.last_content_type) free(protos.http.last_content_type);
  } else if(isDNS()) {
    if(protos.dns.last_query)   free(protos.dns.last_query);
  } else if(isSSH()) {
    if(protos.ssh.client_signature)  free(protos.ssh.client_signature);
    if(protos.ssh.server_signature)  free(protos.ssh.server_signature);
  } else if(isSSL()) {
    if(protos.ssl.certificate)         free(protos.ssl.certificate);
    if(protos.ssl.server_certificate)  free(protos.ssl.server_certificate);
    if(protos.ssl.ja3.client_hash)     free(protos.ssl.ja3.client_hash);
    if(protos.ssl.ja3.server_hash)     free(protos.ssl.ja3.server_hash);
  }

  if(bt_hash)                free(bt_hash);
  if(community_id_flow_hash) free(community_id_flow_hash);

  freeDPIMemory();
  if(icmp_info)        delete(icmp_info);
  if(suricata_alert) json_object_put(suricata_alert); 
}

/* *************************************** */

bool Flow::triggerAlerts() const {
  /* If a flow involves at least a local endpoint,
     then that endpoint may have disabled alerts.
     When there's a local endpoint with alerts disabled,
     we do not generate flow alerts having it as an endpoint as one
     wants to explicitly silence them */

  bool cli_trigger_alerts, srv_trigger_alerts;

  /* client is either remote, or has alerts enabled... */
  cli_trigger_alerts = cli_host && (!cli_host->isLocalHost() || cli_host->triggerAlerts());
  /* server is either remote, or has alerts enabled.. */
  srv_trigger_alerts = srv_host && (!srv_host->isLocalHost() || srv_host->triggerAlerts());

  return cli_trigger_alerts && srv_trigger_alerts;
}

/* *************************************** */

void Flow::dumpFlowAlert() {
  time_t when = time(0);

  if(!triggerAlerts())
    return;

  FlowStatus status = getFlowStatus();

  if(!isFlowAlerted()) {
    bool do_dump = true;

    switch(status) {
    case status_normal:
      do_dump = false;
      break;

    case status_not_purged:
      do_dump = true;
      break;

    case status_web_mining_detected:
      do_dump = ntop->getPrefs()->are_mining_alerts_enabled();
      break;

    case status_blacklisted:
      do_dump = ntop->getPrefs()->are_malware_alerts_enabled();
      break;

    case status_slow_tcp_connection: /* 1 */
    case status_slow_application_header: /* 2 */
    case status_slow_data_exchange: /* 3 */
    case status_low_goodput: /* 4 */
    case status_tcp_connection_issues: /* 6 - i.e. too many retransmission ooo... or similar */
    case status_tcp_severe_connection_issues: /* 22 */
      /* Don't log them for the time being otherwise we'll have too many flows */
      do_dump = false;
      break;

    case status_suspicious_tcp_syn_probing: /* 5 */
    case status_suspicious_tcp_probing:     /* 7 */
    case status_tcp_connection_refused: /* 9 */
      do_dump = ntop->getPrefs()->are_probing_alerts_enabled();
      break;

    case status_flow_when_interface_alerted /* 8 */:
#if 0
      do_dump = ntop->getPrefs()->do_dump_flow_alerts_when_iface_alerted();
#endif
      break;

    case status_ssl_certificate_mismatch: /* 10 */
    case status_ssl_unsafe_ciphers:       /* 23 */
    case status_ssl_old_protocol_version: /* 24 */
      do_dump = ntop->getPrefs()->are_ssl_alerts_enabled();
      break;

    case status_dns_invalid_query:
      do_dump = ntop->getPrefs()->are_dns_alerts_enabled();
      break;

    case status_remote_to_remote:
      do_dump = ntop->getPrefs()->are_remote_to_remote_alerts_enabled();
      break;

    case status_blocked:
#ifdef HAVE_NEDGE
      do_dump = ntop->getPrefs()->are_dropped_flows_alerts_enabled();
#else
      do_dump = false;
#endif
      break;

    case status_device_protocol_not_allowed:
      do_dump = ntop->getPrefs()->are_device_protocols_alerts_enabled();
      break;

    case status_elephant_local_to_remote:
    case status_elephant_remote_to_local:
      do_dump = ntop->getPrefs()->are_elephant_flows_alerts_enabled();
      break;

    case status_longlived:
      do_dump = ntop->getPrefs()->are_longlived_flows_alerts_enabled();
      break;

    case status_data_exfiltration:
      do_dump = ntop->getPrefs()->are_exfiltration_alerts_enabled();
      break;

    case status_ids_alert:
      do_dump = ntop->getPrefs()->are_ids_alerts_enabled();
      break;

    case num_flow_status: /* nothing to do here */
      break;
    }

#ifdef HAVE_NEDGE
    /* NOTE: this must be explicitly re-checked as a more specific alert
       e.g. status_device_protocol_not_allowed may have set do_dump=false but
       we still want to generate the alert */
    if(!do_dump && !isPassVerdict())
      /* A side effect of this is that the generated alert will still have
         the original status rather then the status_blocked */
      do_dump = ntop->getPrefs()->are_dropped_flows_alerts_enabled();
#endif

    /* Check per-host thresholds */
    if((cli_host && cli_host->incFlowAlertHits(when))
         ||(srv_host && srv_host->incFlowAlertHits(when)))
      do_dump = false;

    if(do_dump) {
      iface->getAlertsManager()->storeFlowAlert(this);
    }
  }
}

/* *************************************** */

void Flow::processDetectedProtocol() {
  u_int16_t l7proto;

  if(protocol_processed || (ndpiFlow == NULL))
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
    if((ndpiFlow->protos.mdns.answer[0] != '\0') && cli_host) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "[MDNS] %s", ndpiFlow->protos.mdns.answer);
      cli_host->inlineSetMDNSInfo(ndpiFlow->protos.mdns.answer);
    }
    break;

  case NDPI_PROTOCOL_DNS:
    if(ndpiFlow->host_server_name[0] != '\0') {

      if(protos.dns.last_query) {
	free(protos.dns.last_query);
	protos.dns.invalid_query = false;
      }
      protos.dns.last_query = strdup((const char*)ndpiFlow->host_server_name);

      for(int i = 0; protos.dns.last_query[i] != '\0'; i++) {
	if(!isprint(protos.dns.last_query[i])) {
	  protos.dns.last_query[i] = '?';
	  protos.dns.invalid_query = true;
	}
      }

      if(!protos.dns.invalid_query)
	protos.dns.invalid_query = (strlen(protos.dns.last_query) > MAX_VALID_DNS_QUERY_LEN) ? true : false;
    }

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

  case NDPI_PROTOCOL_SSH:
    if(protos.ssh.client_signature)  free(protos.ssh.client_signature);
    if(protos.ssh.server_signature)  free(protos.ssh.server_signature);
    /*
      NOTE

      Signatures are swapped as the server observes the client signature
      and vice-versa
     */
    protos.ssh.server_signature = strdup(ndpiFlow->protos.ssh.client_signature);
    protos.ssh.client_signature = strdup(ndpiFlow->protos.ssh.server_signature);
    break;

  case NDPI_PROTOCOL_TOR:
  case NDPI_PROTOCOL_SSL:
    protos.ssl.ssl_version = ndpiFlow->protos.stun_ssl.ssl.ssl_version;
    
#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "-> [client: %s][server: %s]",
				 ndpiFlow->protos.stun_ssl.ssl.client_certificate,
				 ndpiFlow->protos.stun_ssl.ssl.server_certificate);
#endif

    if((protos.ssl.certificate == NULL)
       && (ndpiFlow->protos.stun_ssl.ssl.client_certificate[0] != '\0')) {
      protos.ssl.certificate = strdup(ndpiFlow->protos.stun_ssl.ssl.client_certificate);

      if(protos.ssl.certificate && (strncmp(protos.ssl.certificate, "www.", 4) == 0)) {
	if(ndpi_is_proto(ndpiDetectedProtocol, NDPI_PROTOCOL_TOR))
	  check_tor = true;
      }
    }

    if((protos.ssl.server_certificate == NULL)
       && (ndpiFlow->protos.stun_ssl.ssl.server_certificate[0] != '\0')) {
      protos.ssl.server_certificate = strdup(ndpiFlow->protos.stun_ssl.ssl.server_certificate);
    }

    if((protos.ssl.ja3.client_hash == NULL) && (ndpiFlow->protos.stun_ssl.ssl.ja3_client[0] != '\0')) {
      protos.ssl.ja3.client_hash = strdup(ndpiFlow->protos.stun_ssl.ssl.ja3_client);
      updateJA3();
    }
    
    if((protos.ssl.ja3.server_hash == NULL) && (ndpiFlow->protos.stun_ssl.ssl.ja3_server[0] != '\0')) {
      protos.ssl.ja3.server_hash = strdup(ndpiFlow->protos.stun_ssl.ssl.ja3_server);    
      protos.ssl.ja3.server_unsafe_cipher = ndpiFlow->protos.stun_ssl.ssl.server_unsafe_cipher;
      if(protos.ssl.ja3.server_unsafe_cipher != ndpi_cipher_safe) setFlowAlerted();
      protos.ssl.ja3.server_cipher = ndpiFlow->protos.stun_ssl.ssl.server_cipher;
    }
    
    if(check_tor) {
      char rsp[256];

      if(ntop->getRedis()->getAddress(protos.ssl.certificate, rsp, sizeof(rsp), false) == 0) {
	if(rsp[0] == '\0') /* Cached failed resolution */
	  ndpiDetectedProtocol.app_protocol = NDPI_PROTOCOL_TOR;

	check_tor = false; /* This is a valid host */
      } else {
	ntop->getRedis()->pushHostToResolve(protos.ssl.certificate, false, true /* Fake to resolve it ASAP */);
      }
    }

    if(protos.ssl.certificate
       && cli_host
       && cli_host->isLocalHost())
      cli_host->incrVisitedWebSite(protos.ssl.certificate);

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
	cli_host->inlineSetOS((char*)ndpiFlow->protos.http.detected_os);

      if(cli_host && cli_host->isLocalHost())
	cli_host->incrVisitedWebSite(host_server_name);
    }
    break;
  } /* switch */

  if(protocol_processed
     /* For DNS we delay the memory free so that we can let nDPI analyze all the packets of the flow */
     && (l7proto != NDPI_PROTOCOL_DNS))
    freeDPIMemory();
}

/* *************************************** */

void Flow::setDetectedProtocol(ndpi_protocol proto_id, bool forceDetection) {
  ndpi_flow_struct* ndpif;

  /* Let the client SSL certificate win over the server SSL certificate
     this addresses detection for youtube, e.g., when the client
     requests s.youtube.com but the server responds with google.com */
  if((!forceDetection)
     && (proto_id.master_protocol == NDPI_PROTOCOL_SSL)
     && (get_packets() < NDPI_MIN_NUM_PACKETS)
     && (ndpif = get_ndpi_flow())
     && ((ndpif->protos.stun_ssl.ssl.client_certificate[0] == '\0')
	 || (ndpif->protos.stun_ssl.ssl.server_certificate[0] == '\0'))) {
    ndpif->detected_protocol_stack[0] = NDPI_PROTOCOL_UNKNOWN;
    return;
  }
  
  if((proto_id.app_protocol != NDPI_PROTOCOL_UNKNOWN)
     || forceDetection
     || (get_packets() >= NDPI_MIN_NUM_PACKETS)
     || (!iface->is_ndpi_enabled())
     || iface->isSampledTraffic()) {
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

    processDetectedProtocol();
    detection_completed = true;

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

  if(detection_completed) {
#ifdef HAVE_NEDGE
    updateFlowShapers(true);
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

void Flow::setJSONInfo(const char *json) {
  if(json == NULL) return;

  if(json_info != NULL) free(json_info);
  json_info = strdup(json);
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

u_int64_t Flow::get_current_bytes_cli2srv() {
  int64_t diff = cli2srv_bytes - cli2srv_last_bytes;

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_bytes_srv2cli() {
  int64_t diff = srv2cli_bytes - srv2cli_last_bytes;

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_goodput_bytes_cli2srv() {
  int64_t diff = cli2srv_goodput_bytes - cli2srv_last_goodput_bytes;

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_goodput_bytes_srv2cli() {
  int64_t diff = srv2cli_goodput_bytes - srv2cli_last_goodput_bytes;

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_packets_cli2srv() {
  int64_t diff = cli2srv_packets - cli2srv_last_packets;

  /*
    We need to do this as due to concurrency issues,
    we might have a negative value
  */
  return((diff > 0) ? diff : 0);
};

/* *************************************** */

u_int64_t Flow::get_current_packets_srv2cli() {
  int64_t diff = srv2cli_packets - srv2cli_last_packets;

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

  if((cli_host == NULL) || (srv_host == NULL)) return(buf);

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

    if((tcp_stats_s2d.pktOOO+tcp_stats_d2s.pktOOO) > 0)
      len += snprintf(&tcp_buf[len], sizeof(tcp_buf)-len, "[OOO=%u/%u]",
		      tcp_stats_s2d.pktOOO, tcp_stats_d2s.pktOOO);

    if((tcp_stats_s2d.pktLost+tcp_stats_d2s.pktLost) > 0)
      len += snprintf(&tcp_buf[len], sizeof(tcp_buf)-len, "[Lost=%u/%u]",
		      tcp_stats_s2d.pktLost, tcp_stats_d2s.pktLost);

    if((tcp_stats_s2d.pktRetr+tcp_stats_d2s.pktRetr) > 0)
      len += snprintf(&tcp_buf[len], sizeof(tcp_buf)-len, "[Retr=%u/%u]",
		      tcp_stats_s2d.pktRetr, tcp_stats_d2s.pktRetr);

    if((tcp_stats_s2d.pktKeepAlive+tcp_stats_d2s.pktKeepAlive) > 0)
      len += snprintf(&tcp_buf[len], sizeof(tcp_buf)-len, "[KeepAlive=%u/%u]",
		      tcp_stats_s2d.pktKeepAlive, tcp_stats_d2s.pktKeepAlive);
  }

  snprintf(buf, buf_len,
	   "%s %s:%u &gt; %s:%u [first: %u][last: %u][proto: %u.%u/%s][cat: %u/%s][device: %u in: %u out:%u][%u/%u pkts][%llu/%llu bytes][src2dst: %s][dst2stc: %s]"
	   "%s%s%s"
#if defined(NTOPNG_PRO) && defined(SHAPER_DEBUG)
	   "%s"
#endif
	   ,
	   get_protocol_name(),
	   cli_host->get_ip()->print(buf1, sizeof(buf1)), ntohs(cli_port),
	   srv_host->get_ip()->print(buf2, sizeof(buf2)), ntohs(srv_port),
	   (u_int32_t)first_seen, (u_int32_t)last_seen,
	   ndpiDetectedProtocol.master_protocol, ndpiDetectedProtocol.app_protocol,
	   get_detected_protocol_name(pbuf, sizeof(pbuf)),
	   get_protocol_category(),
	   get_protocol_category_name(),
	   flow_device.device_ip, flow_device.in_index, flow_device.out_index,
	   cli2srv_packets, srv2cli_packets,
	   (long long unsigned) cli2srv_bytes, (long long unsigned) srv2cli_bytes,
	   printTCPflags(src2dst_tcp_flags, buf3, sizeof(buf3)),
	   printTCPflags(dst2src_tcp_flags, buf4, sizeof(buf4)),
	   (isSSL() && protos.ssl.certificate) ? "[" : "",
	   (isSSL() && protos.ssl.certificate) ? protos.ssl.certificate : "",
	   (isSSL() && protos.ssl.certificate) ? "]" : ""
#if defined(NTOPNG_PRO) && defined(SHAPER_DEBUG)
	   , shapers
#endif
	   );

return(buf);
}

/* *************************************** */

bool Flow::dumpFlow(bool dump_alert) {
  bool rc = false;

  if(dump_alert) {
    /* NOTE: this can be very time consuming */
    dumpFlowAlert();
  }

  if(((cli2srv_packets - last_db_dump.cli2srv_packets) == 0)
     && ((srv2cli_packets - last_db_dump.srv2cli_packets) == 0))
      return(rc);

  if(ntop->getPrefs()->do_dump_flows()
#ifndef HAVE_NEDGE
     || ntop->get_export_interface()
#endif
     ) {
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    if(!detection_completed || cli2srv_packets + srv2cli_packets <= NDPI_MIN_NUM_PACKETS)
      /* force profile detection even if the L7 Protocol has not been detected */
     updateProfile();
#endif
#endif

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
        time_t now = time(NULL);
      
      if(iface->getIfType() == interface_type_PCAP_DUMP
         || (now - get_first_seen()) < CONST_DB_DUMP_FREQUENCY
	 || (now - last_db_dump.last_dump) < CONST_DB_DUMP_FREQUENCY) {
	return(rc);
      }
    } else {
      /* flows idle, i.e., ready to be purged, are always dumped */
    }

#ifdef NTOPNG_PRO
    if(ntop->getPro()->has_valid_license() && ntop->getPrefs()->is_enterprise_edition())
      getInterface()->aggregatePartialFlow(this);
#endif

    getInterface()->dumpFlow(last_seen, this);

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

void Flow::update_hosts_stats(struct timeval *tv, bool dump_alert) {
  u_int64_t sent_packets, sent_bytes, sent_goodput_bytes, rcvd_packets, rcvd_bytes, rcvd_goodput_bytes;
  u_int64_t diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
    diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes;
  bool updated = false;
  bool cli_and_srv_in_same_subnet = false;
  bool cli_and_srv_in_same_country = false;
  int16_t cli_network_id, srv_network_id;
  int16_t stats_protocol; /* The protocol (among ndpi master_ and app_) that is chosen to increase stats */
  Vlan *vl;
  NetworkStats *cli_network_stats;

  if(isReadyToPurge()) {
    /* Marked as ready to be purged, will be purged by NetworkInterface::purgeIdleFlows */
    set_to_purge(tv->tv_sec);
  }

  if(check_tor && (ndpiDetectedProtocol.app_protocol == NDPI_PROTOCOL_SSL)) {
    char rsp[256];

    if(ntop->getRedis()->getAddress(protos.ssl.certificate, rsp, sizeof(rsp), false) == 0) {
      if(rsp[0] == '\0') /* Cached failed resolution */
	ndpiDetectedProtocol.app_protocol = NDPI_PROTOCOL_TOR;

      check_tor = false; /* This is a valid host */
    } else {
      if((tv->tv_sec - last_seen) > 30) {
	/* We give up */
	check_tor = false; /* This is a valid host */
      }
    }
  }

  if(ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN
      && !ndpi_is_subprotocol_informative(NULL, ndpiDetectedProtocol.master_protocol))
    stats_protocol = ndpiDetectedProtocol.app_protocol;
  else
    stats_protocol = ndpiDetectedProtocol.master_protocol;

  sent_packets = cli2srv_packets, sent_bytes = cli2srv_bytes, sent_goodput_bytes = cli2srv_goodput_bytes;
  diff_sent_packets = sent_packets - cli2srv_last_packets,
    diff_sent_bytes = sent_bytes - cli2srv_last_bytes, diff_sent_goodput_bytes = sent_goodput_bytes - cli2srv_last_goodput_bytes;
  prev_cli2srv_last_bytes = cli2srv_last_bytes, prev_cli2srv_last_goodput_bytes = cli2srv_last_goodput_bytes,
    prev_cli2srv_last_packets = cli2srv_last_packets;

  rcvd_packets = srv2cli_packets, rcvd_bytes = srv2cli_bytes, rcvd_goodput_bytes = srv2cli_goodput_bytes;
  diff_rcvd_packets = rcvd_packets - srv2cli_last_packets,
    diff_rcvd_bytes = rcvd_bytes - srv2cli_last_bytes, diff_rcvd_goodput_bytes = rcvd_goodput_bytes - srv2cli_last_goodput_bytes;
  prev_srv2cli_last_bytes = srv2cli_last_bytes, prev_srv2cli_last_goodput_bytes = srv2cli_last_goodput_bytes,
    prev_srv2cli_last_packets = srv2cli_last_packets;

  cli2srv_last_packets = sent_packets, cli2srv_last_bytes = sent_bytes,
    cli2srv_last_goodput_bytes = sent_goodput_bytes;
  srv2cli_last_packets = rcvd_packets, srv2cli_last_bytes = rcvd_bytes,
    srv2cli_last_goodput_bytes = rcvd_goodput_bytes;

  if(cli_host && srv_host) {
    cli_network_id = cli_host->get_local_network_id();
    srv_network_id = srv_host->get_local_network_id();

    if(cli_network_id >= 0 && (cli_network_id == srv_network_id))
      cli_and_srv_in_same_subnet = true;

    if(diff_sent_bytes || diff_rcvd_bytes) {
      /* Update L2 Device stats */

      if(srv_host->get_mac()) {
#ifdef HAVE_NEDGE
        srv_host->getMac()->incSentStats(tv->tv_sec, diff_rcvd_packets, diff_rcvd_bytes);
        srv_host->getMac()->incRcvdStats(tv->tv_sec, diff_sent_packets, diff_sent_bytes);
#endif

        if(ntop->getPrefs()->areMacNdpiStatsEnabled()) {
	  srv_host->getMac()->incnDPIStats(tv->tv_sec, stats_protocol,
					   diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes,
					   diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes);

        }
      }

      if(cli_host->getMac()) {
#ifdef HAVE_NEDGE
        cli_host->getMac()->incSentStats(tv->tv_sec, diff_sent_packets, diff_sent_bytes);
        cli_host->getMac()->incRcvdStats(tv->tv_sec, diff_rcvd_packets, diff_rcvd_bytes);
#endif

        if(ntop->getPrefs()->areMacNdpiStatsEnabled()) {
          cli_host->getMac()->incnDPIStats(tv->tv_sec, stats_protocol,
					   diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
					   diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes);
        }
      }

#ifdef NTOPNG_PRO
      if(ntop->getPro()->has_valid_license()) {

#ifndef HAVE_NEDGE
	if(trafficProfile)
	  trafficProfile->incBytes(diff_sent_bytes+diff_rcvd_bytes);
#endif

	update_pools_stats(tv, diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
      }
#endif
      if(iface && iface->hasSeenVlanTaggedPackets() && (vl = iface->getVlan(vlanId, false))) {
	/* Note: source and destination hosts have, by definition, the same VLAN so the increase is done only one time. */
	/* Note: vl will never be null as we're in a flow with that vlan. Hence, it is guaranteed that at least
	   two hosts exists for that vlan and that any purge attempt will be prevented. */
#ifdef VLAN_DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Increasing Vlan %u stats", vlanId);
#endif
	vl->incStats(tv->tv_sec, stats_protocol,
		     diff_sent_packets, diff_sent_bytes,
		     diff_rcvd_packets, diff_rcvd_bytes);
      }

      // Update network stats
      cli_network_stats = cli_host->getNetworkStats(cli_network_id);
      cli_host->incStats(tv->tv_sec, protocol, stats_protocol, custom_app,
			 diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes,
			 srv_host->get_ip()->isNonEmptyUnicastAddress());

      // update per-subnet byte counters
      if(cli_network_stats) { // only if the network is known and local
	if(!cli_and_srv_in_same_subnet) {
	  cli_network_stats->incEgress(tv->tv_sec, diff_sent_packets, diff_sent_bytes,
				       srv_host->get_ip()->isBroadcastAddress());
	  cli_network_stats->incIngress(tv->tv_sec, diff_rcvd_packets, diff_rcvd_bytes,
					cli_host->get_ip()->isBroadcastAddress());
	} else // client and server ARE in the same subnet
	  // need to update the inner counter (just one time, will intentionally skip this for srv_host)
	  cli_network_stats->incInner(tv->tv_sec, diff_sent_packets + diff_rcvd_packets,
				      diff_sent_bytes + diff_rcvd_bytes,
				      srv_host->get_ip()->isBroadcastAddress()
				      || cli_host->get_ip()->isBroadcastAddress());
      }

      NetworkStats *srv_network_stats;

      srv_network_stats = srv_host->getNetworkStats(srv_network_id);
      srv_host->incStats(tv->tv_sec, protocol, stats_protocol, custom_app,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes,
			 diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
			 cli_host->get_ip()->isNonEmptyUnicastAddress());

      if(srv_network_stats) {
	// local and known server network
	if(!cli_and_srv_in_same_subnet) {
	  srv_network_stats->incIngress(tv->tv_sec, diff_sent_packets, diff_sent_bytes,
					srv_host->get_ip()->isBroadcastAddress());
	  srv_network_stats->incEgress(tv->tv_sec, diff_rcvd_packets, diff_rcvd_bytes,
				       cli_host->get_ip()->isBroadcastAddress());
	}
      }

      if(cli_host->get_asn() != srv_host->get_asn()) {
        AutonomousSystem *cli_as = cli_host->get_as(), *srv_as = srv_host->get_as();
        if(cli_as)
          cli_as->incStats(tv->tv_sec, stats_protocol, diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
        if(srv_as)
          srv_as->incStats(tv->tv_sec, stats_protocol, diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
      }

      // Update Country stats
      Country *cli_country_stats = cli_host->getCountryStats();
      Country *srv_country_stats = srv_host->getCountryStats();

      if(cli_country_stats && srv_country_stats && cli_country_stats->equal(srv_country_stats))
	cli_and_srv_in_same_country = true;

      if(cli_country_stats) {
	if(!cli_and_srv_in_same_country) {
	  cli_country_stats->incEgress(tv->tv_sec, diff_sent_packets, diff_sent_bytes,
				       srv_host->get_ip()->isBroadcastAddress());
	  cli_country_stats->incIngress(tv->tv_sec, diff_rcvd_packets, diff_rcvd_bytes,
					cli_host->get_ip()->isBroadcastAddress());
	} else // client and server ARE in the same country
	  // need to update the inner counter (just one time, will intentionally skip this for srv_host)
	  cli_country_stats->incInner(tv->tv_sec, diff_sent_packets + diff_rcvd_packets,
				      diff_sent_bytes + diff_rcvd_bytes,
				      srv_host->get_ip()->isBroadcastAddress()
				      || cli_host->get_ip()->isBroadcastAddress());
      }

      if(srv_country_stats) {
	if(!cli_and_srv_in_same_country) {
	  srv_country_stats->incIngress(tv->tv_sec, diff_sent_packets, diff_sent_bytes,
					srv_host->get_ip()->isBroadcastAddress());
	  srv_country_stats->incEgress(tv->tv_sec, diff_rcvd_packets, diff_rcvd_bytes,
				       cli_host->get_ip()->isBroadcastAddress());
	}
      }

      if(host_server_name
	 && isThreeWayHandshakeOK()
	 && (ndpi_is_proto(ndpiDetectedProtocol, NDPI_PROTOCOL_HTTP)
	     || ndpi_is_proto(ndpiDetectedProtocol, NDPI_PROTOCOL_HTTP_PROXY))) {
	if(srv_host->getHTTPstats())
	  srv_host->getHTTPstats()->updateHTTPHostRequest(tv->tv_sec, host_server_name,
							  diff_num_http_requests,
							  diff_sent_bytes, diff_rcvd_bytes);
	diff_num_http_requests = 0; /*
				      As this is a difference it is reset
				      whenever we update the counters
				    */
      }
    }

    /* Check and possibly enqueue host remote-to-remote alerts */
    if(!cli_host->isLocalHost() && !srv_host->isLocalHost()
       && cli_host->get_ip()->isNonEmptyUnicastAddress()
       && srv_host->get_ip()->isNonEmptyUnicastAddress()
       && ntop->getPrefs()->are_remote_to_remote_alerts_enabled()
       && !cli_host->setRemoteToRemoteAlerts()) {
      json_object *jo;

      if((jo = json_object_new_object()) != NULL) {
	cli_host->serialize(jo, details_normal);
      	ntop->getRedis()->rpush(CONST_ALERT_HOST_REMOTE_TO_REMOTE, json_object_to_json_string(jo), CONST_REMOTE_TO_REMOTE_MAX_QUEUE);

      	json_object_put(jo);
      }
    }
  }

  if(last_update_time.tv_sec > 0) {
    float tdiff_msec = ((float)(tv->tv_sec-last_update_time.tv_sec)*1000)+((tv->tv_usec-last_update_time.tv_usec)/(float)1000);
    //float t_sec = (float)(tv->tv_sec)+(float)(tv->tv_usec)/1000;

#if 0
    /* Actually, the refresh interval is controlled with ntop->getPrefs()->get_housekeeping_frequency()
       so there is no need to set an a-priori minimum check interval */
    if((iface->getIfType() == interface_type_ZMQ)
       && (tdiff_msec < 5000)) {
      /* With ZMQ (if collecting sFlow) we might compute inaccurate
	 throughput when haveing one flow with a single sample so
	 we spread the traffic across at least 5 secs
      */
      ;
    } else
#endif
    if(tdiff_msec >= 1000 /* Do not update when less than 1 second (1000 msec) */) {
      // bps
      u_int64_t diff_bytes_cli2srv = cli2srv_last_bytes - prev_cli2srv_last_bytes;
      u_int64_t diff_bytes_srv2cli = srv2cli_last_bytes - prev_srv2cli_last_bytes;
      u_int64_t diff_bytes         = diff_bytes_cli2srv + diff_bytes_srv2cli;

      u_int64_t diff_goodput_bytes_cli2srv = cli2srv_last_goodput_bytes - prev_cli2srv_last_goodput_bytes;
      u_int64_t diff_goodput_bytes_srv2cli = srv2cli_last_goodput_bytes - prev_srv2cli_last_goodput_bytes;

      float bytes_msec_cli2srv         = ((float)(diff_bytes_cli2srv*1000))/tdiff_msec;
      float bytes_msec_srv2cli         = ((float)(diff_bytes_srv2cli*1000))/tdiff_msec;
      float bytes_msec                 = bytes_msec_cli2srv + bytes_msec_srv2cli;

      float goodput_bytes_msec_cli2srv = ((float)(diff_goodput_bytes_cli2srv*1000))/tdiff_msec;
      float goodput_bytes_msec_srv2cli = ((float)(diff_goodput_bytes_srv2cli*1000))/tdiff_msec;
      float goodput_bytes_msec         = goodput_bytes_msec_cli2srv + goodput_bytes_msec_srv2cli;

      if(isDetectionCompleted() && cli_host && srv_host) {
	iface->topProtocolsAdd(cli_host->get_host_pool(), stats_protocol, diff_bytes);

	if(cli_host->get_host_pool() != srv_host->get_host_pool())
	  iface->topProtocolsAdd(srv_host->get_host_pool(), stats_protocol, diff_bytes);

	if(cli_host->get_mac() && srv_host->getMac()) {
	  iface->topMacsAdd(cli_host->getMac(), stats_protocol, diff_bytes);
	  iface->topMacsAdd(srv_host->getMac(), stats_protocol, diff_bytes);
	}
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

	if(!idle() /* set_to_purge() deals with low goodput flows when they become idle */
	   && iface->getIfType() != interface_type_ZMQ
	   && protocol == IPPROTO_TCP
	   && get_goodput_bytes() > 0
	   && ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_SSH) {
	  if(isLowGoodput()) {
	    if(!good_low_flow_detected) {
	      if(cli_host) cli_host->incLowGoodputFlows(tv->tv_sec, true);
	      if(srv_host) srv_host->incLowGoodputFlows(tv->tv_sec, false);
	      good_low_flow_detected = true;
	    }
	  } else {
	    if(good_low_flow_detected) {
	      /* back to normal */
	      if(cli_host) cli_host->decLowGoodputFlows(tv->tv_sec, true);
	      if(srv_host) srv_host->decLowGoodputFlows(tv->tv_sec, false);
	      good_low_flow_detected = false;
	    }
	  }
	}

#ifdef NTOPNG_PRO
	throughputTrend.update(bytes_thpt), goodputTrend.update(goodput_bytes_thpt);
	thptRatioTrend.update(((double)(goodput_bytes_msec*100))/(double)bytes_msec);

#ifdef DEBUG_TREND
	if((cli2srv_goodput_bytes+srv2cli_goodput_bytes) > 0) {
	  char buf[256];

	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [Goodput long/mid/short %.3f/%.3f/%.3f][ratio: %s][goodput/thpt: %.3f]",
				       print(buf, sizeof(buf)),
				       goodputTrend.getLongTerm(), goodputTrend.getMidTerm(), goodputTrend.getShortTerm(),
				       goodputTrend.getTrendMsg(),
				       ((float)(100*(cli2srv_goodput_bytes+srv2cli_goodput_bytes)))/(float)(cli2srv_bytes+srv2cli_bytes));
	}
#endif
#endif

	// pps
	u_int64_t diff_pkts_cli2srv = cli2srv_last_packets - prev_cli2srv_last_packets;
	u_int64_t diff_pkts_srv2cli = srv2cli_last_packets - prev_srv2cli_last_packets;
	u_int64_t diff_pkts         = diff_pkts_cli2srv + diff_pkts_srv2cli;

	float pkts_msec_cli2srv     = ((float)(diff_pkts_cli2srv*1000))/tdiff_msec;
	float pkts_msec_srv2cli     = ((float)(diff_pkts_srv2cli*1000))/tdiff_msec;
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

	updated = true;
      }
    }
  } else
    updated = true;

  if(updated)
    memcpy(&last_update_time, tv, sizeof(struct timeval));

  if(dumpFlow(dump_alert)) {
    last_db_dump.cli2srv_packets = cli2srv_packets,
      last_db_dump.srv2cli_packets = srv2cli_packets,
      last_db_dump.cli2srv_bytes = cli2srv_bytes,
      last_db_dump.cli2srv_goodput_bytes = cli2srv_goodput_bytes,
      last_db_dump.srv2cli_bytes = srv2cli_bytes,
      last_db_dump.srv2cli_goodput_bytes = srv2cli_goodput_bytes,
      last_db_dump.last_dump = last_seen;
  }
}

/* *************************************** */

#ifdef NTOPNG_PRO

void Flow::update_pools_stats(const struct timeval *tv,
				u_int64_t diff_sent_packets, u_int64_t diff_sent_bytes,
				u_int64_t diff_rcvd_packets, u_int64_t diff_rcvd_bytes) {
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

      /* Per host quota-enforcement stats */
      if(hp->enforceQuotasPerPoolMember(cli_host_pool_id)) {
	cli_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.master_protocol,
					   diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
	cli_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.app_protocol,
					   diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
	cli_host->incQuotaEnforcementCategoryStats(tv->tv_sec, category_id, diff_sent_bytes, diff_rcvd_bytes);
      }
    }

    /* Server host */
    if(srv_host
#ifdef HAVE_NEDGE
      && srv_host->getMac() && (srv_host->getMac()->locate() == located_on_lan_interface)
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
      if(hp->enforceQuotasPerPoolMember(srv_host_pool_id)) {
	srv_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.master_protocol,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
	srv_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.app_protocol,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
	srv_host->incQuotaEnforcementCategoryStats(tv->tv_sec, category_id, diff_rcvd_bytes, diff_sent_bytes);
      }
    }
  }
}

#endif

/* *************************************** */

bool Flow::equal(IpAddress *_cli_ip, IpAddress *_srv_ip, u_int16_t _cli_port,
		 u_int16_t _srv_port, u_int16_t _vlanId, u_int8_t _protocol,
		 const ICMPinfo * const _icmp_info,
		 bool *src2srv_direction) {
  if((_vlanId != vlanId) && (vlanId != 0))
    return(false);

  if(_protocol != protocol) return(false);

  if(icmp_info && !icmp_info->equal(_icmp_info)) return(false);

  if(cli_host && cli_host->equal(_cli_ip)
     && srv_host && srv_host->equal(_srv_ip)
     && (_cli_port == cli_port) && (_srv_port == srv_port)) {
    *src2srv_direction = true;
    return(true);
  } else if(srv_host && srv_host->equal(_cli_ip)
	    && cli_host && cli_host->equal(_srv_ip)
	    && (_srv_port == cli_port) && (_cli_port == srv_port)) {
    *src2srv_direction = false;
    return(true);
  } else
    return(false);
}

/* *************************************** */

bool Flow::clientLessThanServer() const {
  if(cli_host && srv_host)
    return cli_host->get_ip()->compare(srv_host->get_ip()) < 0;
  else if(cli_host && !cli_host->get_ip()->isEmpty())
    return false; /* Assumes server is zero and cli_host > 0 */
  else if(srv_host && !srv_host->get_ip()->isEmpty())
    return true; /*  Assumes server is >0 and cli_host is zero */
  else
    return false;
}

/* *************************************** */

void Flow::processLua(lua_State* vm, const ParsedeBPF * const pe, bool client) {
  const ProcessInfo * proc;
  const ContainerInfo * cont;
  const TcpInfo * tcp;

  if(!pe) return;
  
  if(pe->process_info_set && (proc = &pe->process_info) && proc->pid > 0) {
    lua_newtable(vm);

    lua_push_uint64_table_entry(vm, "pid", proc->pid);
    lua_push_str_table_entry(vm, "name", proc->process_name);
    lua_push_uint64_table_entry(vm, "uid", proc->uid);
    lua_push_uint64_table_entry(vm, "gid", proc->gid);
    lua_push_uint64_table_entry(vm, "actual_memory", proc->actual_memory);
    lua_push_uint64_table_entry(vm, "peak_memory", proc->peak_memory);
    lua_push_str_table_entry(vm, "user_name", proc->uid_name);

    if(proc->father_pid > 0) {
      lua_push_uint64_table_entry(vm, "father_pid", proc->father_pid);
      lua_push_uint64_table_entry(vm, "father_uid", proc->father_uid);
      lua_push_uint64_table_entry(vm, "father_gid", proc->father_gid);
      lua_push_str_table_entry(vm, "father_name", proc->father_process_name);
      lua_push_uint64_table_entry(vm, "actual_memory", proc->actual_memory);
      lua_push_uint64_table_entry(vm, "peak_memory", proc->peak_memory);
      lua_push_str_table_entry(vm, "father_user_name", proc->father_uid_name);
    }

    lua_pushstring(vm, client ? "client_process" : "server_process");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  if(pe->container_info_set && (cont = &pe->container_info)) {
    Utils::containerInfoLua(vm, cont);

    lua_pushstring(vm, client ? "client_container" : "server_container");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  if(pe->tcp_info_set && (tcp = &pe->tcp_info)) {
    lua_newtable(vm);

    lua_push_float_table_entry(vm, "rtt", tcp->rtt);
    lua_push_float_table_entry(vm, "rtt_var", tcp->rtt_var);

    lua_pushstring(vm, client ? "client_tcp_info" : "server_tcp_info");
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

const char* Flow::cipher_weakness2str(ndpi_cipher_weakness w) {
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
  char buf[64];
  Host *src = get_cli_host(), *dst = get_srv_host();
  bool src_match = true, dst_match = true;
  bool mask_cli_host = true, mask_dst_host = true, mask_flow;

  if((src == NULL) || (dst == NULL)) return;

  if(ptree) {
    src_match = src->match(ptree), dst_match = dst->match(ptree);
    if((!src_match) && (!dst_match)) return;
  }

  if(!skipNewTable)
    lua_newtable(vm);

  if(src) {
    mask_cli_host = Utils::maskHost(src->isLocalHost());

    lua_push_str_table_entry(vm, "cli.ip",
			     src->get_ip()->printMask(buf, sizeof(buf),
						      src->isLocalHost()));
   if(src->get_vlan_id())
      lua_push_uint64_table_entry(vm, "cli.vlan", src->get_vlan_id());

    lua_push_uint64_table_entry(vm, "cli.key", mask_cli_host ? 0 : src->key());
  } else {
    lua_push_nil_table_entry(vm, "cli.ip");
    lua_push_nil_table_entry(vm, "cli.key");
  }
  lua_push_uint64_table_entry(vm, "cli.port", get_cli_port());

  if(dst) {
    mask_dst_host = Utils::maskHost(dst->isLocalHost());

    lua_push_str_table_entry(vm, "srv.ip",
			     dst->get_ip()->printMask(buf, sizeof(buf),
						      dst->isLocalHost()));

    if(dst->get_vlan_id())
      lua_push_uint64_table_entry(vm, "srv.vlan", dst->get_vlan_id());

    lua_push_uint64_table_entry(vm, "srv.key", mask_dst_host ? 0 : dst->key());
  } else {
    lua_push_nil_table_entry(vm, "srv.ip");
    lua_push_nil_table_entry(vm, "srv.key");
  }
  lua_push_uint64_table_entry(vm, "srv.port", get_srv_port());

  mask_flow = isMaskedFlow(); // mask_cli_host || mask_dst_host;

  lua_push_uint64_table_entry(vm, "bytes", cli2srv_bytes+srv2cli_bytes);
  lua_push_uint64_table_entry(vm, "goodput_bytes", cli2srv_goodput_bytes+srv2cli_goodput_bytes);

  if(details_level >= details_high) {
    if(src && !mask_cli_host) {
      lua_push_str_table_entry(vm, "cli.host", src->get_visual_name(buf, sizeof(buf)));
      lua_push_uint64_table_entry(vm, "cli.source_id", 0 /* was never set by src->getSourceId()*/ );
      lua_push_str_table_entry(vm, "cli.mac", Utils::formatMac(src->get_mac(), buf, sizeof(buf)));

      lua_push_bool_table_entry(vm, "cli.systemhost", src->isSystemHost());
      lua_push_bool_table_entry(vm, "cli.blacklisted", src->isBlacklisted());
      lua_push_bool_table_entry(vm, "cli.allowed_host", src_match);
      lua_push_int32_table_entry(vm, "cli.network_id", src->get_local_network_id());
      lua_push_uint64_table_entry(vm, "cli.pool_id", src->get_host_pool());
    } else {
      lua_push_nil_table_entry(vm, "cli.host");
    }

    if(dst && !mask_dst_host) {
      lua_push_str_table_entry(vm, "srv.host", dst->get_visual_name(buf, sizeof(buf)));
      lua_push_uint64_table_entry(vm, "srv.source_id", 0 /* was never set by src->getSourceId() */);
      lua_push_str_table_entry(vm, "srv.mac", Utils::formatMac(dst->get_mac(), buf, sizeof(buf)));
      lua_push_bool_table_entry(vm, "srv.systemhost", dst->isSystemHost());
      lua_push_bool_table_entry(vm, "srv.blacklisted", dst->isBlacklisted());
      lua_push_bool_table_entry(vm, "srv.allowed_host", dst_match);
      lua_push_int32_table_entry(vm, "srv.network_id", dst->get_local_network_id());
      lua_push_uint64_table_entry(vm, "srv.pool_id", dst->get_host_pool());
    } else {
      lua_push_nil_table_entry(vm, "srv.host");
    }

    if(vrfId) lua_push_uint64_table_entry(vm, "vrfId", vrfId);
    lua_push_uint64_table_entry(vm, "vlan", get_vlan_id());
    lua_push_str_table_entry(vm, "proto.l4", get_protocol_name());

    if(((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
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
    lua_push_str_table_entry(vm, "proto.ndpi_breed", get_protocol_breed_name());

    lua_push_uint64_table_entry(vm, "proto.ndpi_cat_id", get_protocol_category());
    lua_push_str_table_entry(vm, "proto.ndpi_cat", get_protocol_category_name());

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    if((!mask_flow) && trafficProfile && ntop->getPro()->has_valid_license())
      lua_push_str_table_entry(vm, "profile", trafficProfile->getName());
#endif
#endif

    lua_push_uint64_table_entry(vm, "bytes.last",
			     get_current_bytes_cli2srv() + get_current_bytes_srv2cli());
    lua_push_uint64_table_entry(vm, "goodput_bytes",
			     cli2srv_goodput_bytes+srv2cli_goodput_bytes);
    lua_push_uint64_table_entry(vm, "goodput_bytes.last",
			     get_current_goodput_bytes_cli2srv() + get_current_goodput_bytes_srv2cli());
    lua_push_uint64_table_entry(vm, "packets", cli2srv_packets+srv2cli_packets);
    lua_push_uint64_table_entry(vm, "packets.last",
			     get_current_packets_cli2srv() + get_current_packets_srv2cli());
    lua_push_uint64_table_entry(vm, "seen.first", get_first_seen());
    lua_push_uint64_table_entry(vm, "seen.last", get_last_seen());
    lua_push_uint64_table_entry(vm, "duration", get_duration());

    lua_push_uint64_table_entry(vm, "cli2srv.bytes", cli2srv_bytes);
    lua_push_uint64_table_entry(vm, "srv2cli.bytes", srv2cli_bytes);
    lua_push_uint64_table_entry(vm, "cli2srv.goodput_bytes", cli2srv_goodput_bytes);
    lua_push_uint64_table_entry(vm, "srv2cli.goodput_bytes", srv2cli_goodput_bytes);
    lua_push_uint64_table_entry(vm, "cli2srv.packets", cli2srv_packets);
    lua_push_uint64_table_entry(vm, "srv2cli.packets", srv2cli_packets);

    lua_push_uint64_table_entry(vm, "cli2srv.fragments", ip_stats_s2d.pktFrag);
    lua_push_uint64_table_entry(vm, "srv2cli.fragments", ip_stats_d2s.pktFrag);

    if(isICMP()) {
      lua_newtable(vm);
      lua_push_uint64_table_entry(vm, "type", protos.icmp.icmp_type);
      lua_push_uint64_table_entry(vm, "code", protos.icmp.icmp_code);

      if(icmp_info)
	icmp_info->lua(vm, ptree, iface, get_vlan_id());

      lua_pushstring(vm, "icmp");
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }

    lua_push_bool_table_entry(vm, "flow_goodput.low", isLowGoodput());

#ifdef HAVE_NEDGE
    if(iface->is_bridge_interface())
      lua_push_bool_table_entry(vm, "verdict.pass", isPassVerdict() ? (json_bool)1 : (json_bool)0);
#endif

    if(protocol == IPPROTO_TCP) {
      lua_push_bool_table_entry(vm, "tcp.seq_problems",
				(tcp_stats_s2d.pktRetr
				 | tcp_stats_s2d.pktOOO
				 | tcp_stats_s2d.pktLost
				 | tcp_stats_s2d.pktKeepAlive
				 | tcp_stats_d2s.pktRetr
				 | tcp_stats_d2s.pktOOO
				 | tcp_stats_d2s.pktLost
				 | tcp_stats_d2s.pktKeepAlive) ? true : false);

      lua_push_float_table_entry(vm, "tcp.nw_latency.client", toMs(&clientNwLatency));
      lua_push_float_table_entry(vm, "tcp.nw_latency.server", toMs(&serverNwLatency));
      lua_push_float_table_entry(vm, "tcp.appl_latency", applLatencyMsec);
      lua_push_float_table_entry(vm, "tcp.max_thpt.cli2srv", getCli2SrvMaxThpt());
      lua_push_float_table_entry(vm, "tcp.max_thpt.srv2cli", getSrv2CliMaxThpt());

      lua_push_uint64_table_entry(vm, "cli2srv.retransmissions", tcp_stats_s2d.pktRetr);
      lua_push_uint64_table_entry(vm, "cli2srv.out_of_order", tcp_stats_s2d.pktOOO);
      lua_push_uint64_table_entry(vm, "cli2srv.lost", tcp_stats_s2d.pktLost);
      lua_push_uint64_table_entry(vm, "cli2srv.keep_alive", tcp_stats_s2d.pktKeepAlive);
      lua_push_uint64_table_entry(vm, "srv2cli.retransmissions", tcp_stats_d2s.pktRetr);
      lua_push_uint64_table_entry(vm, "srv2cli.out_of_order", tcp_stats_d2s.pktOOO);
      lua_push_uint64_table_entry(vm, "srv2cli.lost", tcp_stats_d2s.pktLost);
      lua_push_uint64_table_entry(vm, "srv2cli.keep_alive", tcp_stats_d2s.pktKeepAlive);

      lua_push_uint64_table_entry(vm, "cli2srv.tcp_flags", src2dst_tcp_flags);
      lua_push_uint64_table_entry(vm, "srv2cli.tcp_flags", dst2src_tcp_flags);

      lua_push_bool_table_entry(vm, "tcp_established", isTCPEstablished());
      lua_push_bool_table_entry(vm, "tcp_connecting", isTCPConnecting());
      lua_push_bool_table_entry(vm, "tcp_closed", isTCPClosed());
      lua_push_bool_table_entry(vm, "tcp_reset", isTCPReset());
    }

    if(!mask_flow) {
      if(host_server_name) lua_push_str_table_entry(vm, "host_server_name", host_server_name);
      if(bt_hash)          lua_push_str_table_entry(vm, "bittorrent_hash", bt_hash);
      lua_push_str_table_entry(vm, "info", getFlowInfo() ? getFlowInfo() : (char*)"");
    }

    if(isHTTP() && protos.http.last_url) {
      lua_push_str_table_entry(vm, "protos.http.last_method", protos.http.last_method);
      lua_push_uint64_table_entry(vm, "protos.http.last_return_code", protos.http.last_return_code);
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
      if(isHTTP() && protos.http.last_url)
	lua_push_str_table_entry(vm, "protos.http.last_url", protos.http.last_url);

      if(isHTTP() && host_server_name && (!mask_flow))
	lua_push_str_table_entry(vm, "protos.http.server_name", host_server_name);

      if(isDNS() && protos.dns.last_query)
	lua_push_str_table_entry(vm, "protos.dns.last_query", protos.dns.last_query);

      if(isSSH()) {
	if(protos.ssh.client_signature) lua_push_str_table_entry(vm, "protos.ssh.client_signature", protos.ssh.client_signature);
	if(protos.ssh.server_signature) lua_push_str_table_entry(vm, "protos.ssh.server_signature", protos.ssh.server_signature);
      }

      if(isSSL()) {
	lua_push_int32_table_entry(vm, "protos.ssl_version", protos.ssl.ssl_version);
	
	if(protos.ssl.certificate)
	  lua_push_str_table_entry(vm, "protos.ssl.certificate", protos.ssl.certificate);

	if(protos.ssl.server_certificate)
	  lua_push_str_table_entry(vm, "protos.ssl.server_certificate", protos.ssl.server_certificate);

	if(protos.ssl.ja3.client_hash)
	  lua_push_str_table_entry(vm, "protos.ssl.ja3.client_hash", protos.ssl.ja3.client_hash);
	
	if(protos.ssl.ja3.server_hash) {
	  lua_push_str_table_entry(vm, "protos.ssl.ja3.server_hash", protos.ssl.ja3.server_hash);
	  lua_push_str_table_entry(vm, "protos.ssl.ja3.server_unsafe_cipher",
				   cipher_weakness2str(protos.ssl.ja3.server_unsafe_cipher));
	  lua_push_int32_table_entry(vm, "protos.ssl.ja3.server_cipher",
				     protos.ssl.ja3.server_cipher);
	}		  
      }
    }

    lua_push_str_table_entry(vm, "moreinfo.json", get_json_info());

    if(cli_ebpf) processLua(vm, cli_ebpf, true);
    if(srv_ebpf) processLua(vm, srv_ebpf, false);

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

    lua_push_uint64_table_entry(vm, "cli2srv.packets", cli2srv_packets);
    lua_push_uint64_table_entry(vm, "srv2cli.packets", srv2cli_packets);
    lua_push_uint64_table_entry(vm, "cli2srv.last", get_current_bytes_cli2srv());
    lua_push_uint64_table_entry(vm, "srv2cli.last", get_current_bytes_srv2cli());

    /* ********************* */
    dumpPacketStats(vm, true);
    dumpPacketStats(vm, false);

    if((!mask_flow) && (details_level >= details_higher)) {
      float latitude, longitude;
      char buf[32];

      lua_push_uint64_table_entry(vm, "cli2srv.goodput_bytes.last", get_current_goodput_bytes_cli2srv());
      lua_push_uint64_table_entry(vm, "srv2cli.goodput_bytes.last", get_current_goodput_bytes_srv2cli());

      get_cli_host()->get_geocoordinates(&latitude, &longitude);
      lua_push_float_table_entry(vm, "cli.latitude", latitude);
      lua_push_float_table_entry(vm, "cli.longitude", longitude);

      get_srv_host()->get_geocoordinates(&latitude, &longitude);
      lua_push_float_table_entry(vm, "srv.latitude", latitude);
      lua_push_float_table_entry(vm, "srv.longitude", longitude);

      if(details_level >= details_max) {
	lua_push_bool_table_entry(vm, "cli.private", get_cli_host()->get_ip()->isPrivateAddress()); // cli. */
	lua_push_str_table_entry(vm,  "cli.country", get_cli_host()->get_country(buf, sizeof(buf)));
	lua_push_str_table_entry(vm,  "cli.city", get_cli_host()->get_city(buf, sizeof(buf)));
	lua_push_bool_table_entry(vm, "srv.private", get_srv_host()->get_ip()->isPrivateAddress());
	lua_push_str_table_entry(vm,  "srv.country", get_srv_host()->get_country(buf, sizeof(buf)));
	lua_push_str_table_entry(vm,  "srv.city", get_srv_host()->get_city(buf, sizeof(buf)));
      }
    }

    json_object *status_info_json = flow2statusinfojson();
    if(status_info_json) {
      lua_push_str_table_entry(vm, "status_info", (char*)json_object_to_json_string(status_info_json));
      json_object_put(status_info_json);
    }
  }

  lua_push_bool_table_entry(vm, "flow.idle", idle());
  lua_push_uint64_table_entry(vm, "flow.status", getFlowStatus());

  // this is used to dynamicall update entries in the GUI
  lua_push_uint64_table_entry(vm, "ntopng.key", key()); // Key
}

/* *************************************** */

u_int32_t Flow::key() {
  u_int32_t k = cli_port + srv_port /* +vlanId */ + protocol;

  if(cli_host)  k += cli_host->key();
  if(srv_host)  k += srv_host->key();
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

bool Flow::isReadyToPurge() {
  if (ntop->getPrefs()->flushFlowsOnShutdown()
      && (ntop->getGlobals()->isShutdownRequested() || ntop->getGlobals()->isShutdown()))
    return(true);

  if(idle()) return(true);

#ifdef HAVE_NEDGE
  if(iface->getIfType() == interface_type_NETFILTER)
    return(isNetfilterIdleFlow());
#endif

  if(!iface->is_purge_idle_interface())
    return(false);

  if(protocol == IPPROTO_TCP) {
    u_int8_t tcp_flags = src2dst_tcp_flags | dst2src_tcp_flags;

    /* The flow is considered idle after a MAX_TCP_FLOW_IDLE
       when RST/FIN are set or when the TWH is not completed.
       This prevents finalized/reset flows, or flows with an imcomplete
       TWH from staying in memory for too long. */
    if((tcp_flags & TH_FIN
	|| tcp_flags & TH_RST
	|| (iface->isPacketInterface() && !isThreeWayHandshakeOK()))
       /* Flows won't expire if less than DONT_NOT_EXPIRE_BEFORE_SEC old */
       && iface->getTimeLastPktRcvd() > doNotExpireBefore
       && isIdle(MAX_TCP_FLOW_IDLE)) {
      /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "[TCP] Early flow expire"); */
      return(true);
    }
  }

  return(isIdle(ntop->getPrefs()->get_flow_max_idle()));
}

/* *************************************** */

bool Flow::isFlowPeer(char *numIP, u_int16_t vlanId) {
  char s_buf[32], *ret;

  if((!cli_host) || (!srv_host)) return(false);

  ret = cli_host->get_ip()->print(s_buf, sizeof(s_buf));
  if((strcmp(ret, numIP) == 0) &&
     (cli_host->get_vlan_id() == vlanId))return(true);

  ret = srv_host->get_ip()->print(s_buf, sizeof(s_buf));
  if((strcmp(ret, numIP) == 0) &&
     (cli_host->get_vlan_id() == vlanId))return(true);

  return(false);
}

/* *************************************** */

void Flow::sumStats(nDPIStats *stats, FlowStatusStats *status_stats) {
  FlowStatus status = getFlowStatus();

  stats->incStats(0, ndpiDetectedProtocol.app_protocol,
		  cli2srv_packets, cli2srv_bytes,
		  srv2cli_packets, srv2cli_bytes);

  status_stats->incStats(status);
}

/* *************************************** */

char* Flow::serialize(bool es_json) {
  json_object *my_object;
  char *rsp;

  if((cli_host == NULL) || (srv_host == NULL))
    return(NULL);

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

/* Returns a stripped-down JSON specifically used for providing more alert information */
json_object* Flow::flow2statusinfojson() {
  char buf[128];
  json_object *obj = json_object_new_object();
  if(!obj) return NULL;
  DeviceProtoStatus proto_status = device_proto_allowed;

  json_object_object_add(obj, "cli.devtype", json_object_new_int((cli_host && cli_host->getMac()) ? cli_host->getMac()->getDeviceType() : device_unknown));
  json_object_object_add(obj, "srv.devtype", json_object_new_int((srv_host && srv_host->getMac()) ? srv_host->getMac()->getDeviceType() : device_unknown));
  json_object_object_add(obj, "ntopng.key", json_object_new_int64(key()));

  if(cli_host && ((proto_status = cli_host->getDeviceAllowedProtocolStatus(ndpiDetectedProtocol, true /* client */)) != device_proto_allowed)) {
    json_object_object_add(obj, "devproto_forbidden_peer", json_object_new_string("cli"));
    json_object_object_add(obj, "devproto_forbidden_id", json_object_new_int(
      (proto_status == device_proto_forbidden_app) ? ndpiDetectedProtocol.app_protocol : ndpiDetectedProtocol.master_protocol));
  } else if(srv_host && ((proto_status = srv_host->getDeviceAllowedProtocolStatus(ndpiDetectedProtocol, false /* server */)) != device_proto_allowed)) {
    json_object_object_add(obj, "devproto_forbidden_peer", json_object_new_string("srv"));
    json_object_object_add(obj, "devproto_forbidden_id", json_object_new_int(
      (proto_status == device_proto_forbidden_app) ? ndpiDetectedProtocol.app_protocol : ndpiDetectedProtocol.master_protocol));
  }

  FlowStatus fs = getFlowStatus();
  if(fs == status_ids_alert) {
    json_object *json_alert = getSuricataAlert();
    if (json_alert)
      json_object_object_add(obj, "ids_alert", json_object_get(json_alert));
  } else if(fs == status_blacklisted) {
    if(cli_host && cli_host->isBlacklisted())
      json_object_object_add(obj, "blacklisted.cli", json_object_new_boolean(true));
    if(srv_host && srv_host->isBlacklisted())
      json_object_object_add(obj, "blacklisted.srv", json_object_new_boolean(true));
    if(get_protocol_category() == CUSTOM_CATEGORY_MALWARE)
      json_object_object_add(obj, "blacklisted.cat", json_object_new_boolean(true));
  } else if(fs == status_ssl_certificate_mismatch) {
    if(protos.ssl.certificate && protos.ssl.certificate[0] != '\0')
      json_object_object_add(obj, "ssl_crt.cli", json_object_new_string(protos.ssl.certificate));
    if(protos.ssl.server_certificate && protos.ssl.server_certificate[0] != '\0')
      json_object_object_add(obj, "ssl_crt.srv", json_object_new_string(protos.ssl.server_certificate));
  } else if(fs == status_elephant_local_to_remote)
    json_object_object_add(obj, "elephant.l2r_threshold",
			   json_object_new_int64(ntop->getPrefs()->get_elephant_flow_local_to_remote_bytes()));    
  else if(fs == status_elephant_remote_to_local)
    json_object_object_add(obj, "elephant.r2l_threshold",
			   json_object_new_int64(ntop->getPrefs()->get_elephant_flow_remote_to_local_bytes()));

  if(isICMP()) {
    json_object_object_add(obj, "icmp.icmp_type", json_object_new_int(protos.icmp.icmp_type)),
      json_object_object_add(obj, "icmp.icmp_code", json_object_new_int(protos.icmp.icmp_code));

    if(icmp_info) {
      unreachable_t *unreach = icmp_info->getUnreach();

      if(unreach)
	json_object_object_add(obj, "icmp.unreach.src_ip", json_object_new_string(unreach->src_ip.print(buf, sizeof(buf)))),
	  json_object_object_add(obj, "icmp.unreach.dst_ip", json_object_new_string(unreach->dst_ip.print(buf, sizeof(buf)))),
	  json_object_object_add(obj, "icmp.unreach.src_port", json_object_new_int(ntohs(unreach->src_port))),
	  json_object_object_add(obj, "icmp.unreach.dst_port", json_object_new_int(ntohs(unreach->dst_port))),
	  json_object_object_add(obj, "icmp.unreach.protocol", json_object_new_int(unreach->protocol));
    }
  }

  return obj;
}

/* *************************************** */

json_object* Flow::flow2json() {
  json_object *my_object;
  char buf[64], jsonbuf[64], *c;
  time_t t;

  if(((cli2srv_packets - last_db_dump.cli2srv_packets) == 0)
     && ((srv2cli_packets - last_db_dump.srv2cli_packets) == 0))
    return(NULL);

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
    json_object_object_add(my_object, Utils::jsonLabel(IN_SRC_MAC, "IN_SRC_MAC", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_string(Utils::formatMac(cli_host->get_mac(), buf, sizeof(buf))));
    json_object_object_add(my_object, Utils::jsonLabel(OUT_DST_MAC, "OUT_DST_MAC", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_string(Utils::formatMac(srv_host->get_mac(), buf, sizeof(buf))));
  }

  if(cli_host->get_ip()) {
    if(cli_host->get_ip()->isIPv4()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV4_SRC_ADDR, "IPV4_SRC_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(cli_host->get_string_key(buf, sizeof(buf))));
    } else if(cli_host->get_ip()->isIPv6()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV6_SRC_ADDR, "IPV6_SRC_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(cli_host->get_string_key(buf, sizeof(buf))));
    }
  }

  if(srv_host->get_ip()) {
    if(srv_host->get_ip()->isIPv4()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV4_DST_ADDR, "IPV4_DST_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(srv_host->get_string_key(buf, sizeof(buf))));
    } else if(srv_host->get_ip()->isIPv6()) {
      json_object_object_add(my_object, Utils::jsonLabel(IPV6_DST_ADDR, "IPV6_DST_ADDR", jsonbuf, sizeof(jsonbuf)),
			     json_object_new_string(srv_host->get_string_key(buf, sizeof(buf))));
    }
  }

  json_object_object_add(my_object, Utils::jsonLabel(L4_SRC_PORT, "L4_SRC_PORT", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(get_cli_port()));
  json_object_object_add(my_object, Utils::jsonLabel(L4_DST_PORT, "L4_DST_PORT", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(get_srv_port()));

  json_object_object_add(my_object, Utils::jsonLabel(PROTOCOL, "PROTOCOL", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(protocol));

  if(((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
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

  if(json_info && strcmp(json_info, "{}")) {
    json_object *o;
    enum json_tokener_error jerr = json_tokener_success;

    if((o = json_tokener_parse_verbose(json_info, &jerr)) != NULL) {
      json_object_object_add(my_object, "json", o);
    } else {
      ntop->getTrace()->traceEvent(TRACE_INFO,
				   "JSON Parse error [%s]: %s "
				   " adding as a plain string",
				   json_tokener_error_desc(jerr),
				   json_info);
      /* Experimental to attempt to fix https://github.com/ntop/ntopng/issues/522 */
      json_object_object_add(my_object, "json", json_object_new_string(json_info));
    }
  }

  if(vlanId > 0) json_object_object_add(my_object,
					Utils::jsonLabel(SRC_VLAN, "SRC_VLAN", jsonbuf, sizeof(jsonbuf)),
					json_object_new_int(vlanId));

  if(protocol == IPPROTO_TCP) {
    json_object_object_add(my_object, Utils::jsonLabel(CLIENT_NW_LATENCY_MS, "CLIENT_NW_LATENCY_MS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_double(toMs(&clientNwLatency)));
    json_object_object_add(my_object, Utils::jsonLabel(SERVER_NW_LATENCY_MS, "SERVER_NW_LATENCY_MS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_double(toMs(&serverNwLatency)));
  }

  c = cli_host->get_country(buf, sizeof(buf));
  if(c) {
    json_object *location = json_object_new_array();

    json_object_object_add(my_object, "SRC_IP_COUNTRY", json_object_new_string(c));
    if(location) {
      float latitude, longitude;

      cli_host->get_geocoordinates(&latitude, &longitude);
      json_object_array_add(location, json_object_new_double(longitude));
      json_object_array_add(location, json_object_new_double(latitude));
      json_object_object_add(my_object, "SRC_IP_LOCATION", location);
    }
  }

  c = srv_host->get_country(buf, sizeof(buf));
  if(c) {
    json_object *location = json_object_new_array();

    json_object_object_add(my_object, "DST_IP_COUNTRY", json_object_new_string(c));
    if(location) {
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

  if(isHTTP() && protos.http.last_url && protos.http.last_method) {
    if(host_server_name && (host_server_name[0] != '\0'))
      json_object_object_add(my_object, "HTTP_HOST", json_object_new_string(host_server_name));
    json_object_object_add(my_object, "HTTP_URL", json_object_new_string(protos.http.last_url));
    json_object_object_add(my_object, "HTTP_METHOD", json_object_new_string(protos.http.last_method));
    json_object_object_add(my_object, "HTTP_RET_CODE", json_object_new_int((u_int32_t)protos.http.last_return_code));
  }

  if(bt_hash)
    json_object_object_add(my_object, "BITTORRENT_HASH", json_object_new_string(bt_hash));

  if(isSSL() && protos.ssl.certificate)
    json_object_object_add(my_object, "SSL_SERVER_NAME", json_object_new_string(protos.ssl.certificate));

#ifdef HAVE_NEDGE
  if(iface && iface->is_bridge_interface())
    json_object_object_add(my_object, "verdict.pass",
			   json_object_new_boolean(isPassVerdict() ? (json_bool)1 : (json_bool)0));
#endif

  return(my_object);
}

/* *************************************** */

#ifdef HAVE_NEDGE

bool Flow::isNetfilterIdleFlow() {
  if(idle()) return(true);

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
    return(isIdle(ntop->getPrefs()->get_flow_max_idle()));
  }
}
#endif

/* *************************************** */

void Flow::housekeep(time_t t) {
#ifdef HAVE_NEDGE
  if(iface->getIfType() == interface_type_NETFILTER) {
    if(isNetfilterIdleFlow()) {
      set_to_purge(iface->getTimeLastPktRcvd());
    }
  }
#endif

  if((!isDetectionCompleted()) && ((t - get_last_seen()) > 5 /* sec */)
     && iface->get_ndpi_struct()
     && get_ndpi_flow()) {
    ndpi_protocol givenup_protocol = ndpi_detection_giveup(iface->get_ndpi_struct(), get_ndpi_flow(), 1);
    
    setDetectedProtocol(givenup_protocol, true);
  }
}

/* *************************************** */

void Flow::updatePacketStats(InterarrivalStats *stats, const struct timeval *when) {
  if(stats->lastTime.tv_sec != 0) {
    float deltaMS = (float)(Utils::timeval2usec((struct timeval*)when) - Utils::timeval2usec(&stats->lastTime))/(float)1000;

    if(deltaMS > 0) {
      if(stats->max_ms == 0)
	stats->min_ms = stats->max_ms = deltaMS;
      else {
	if(deltaMS > stats->max_ms) stats->max_ms = deltaMS;
	if(deltaMS < stats->min_ms) stats->min_ms = deltaMS;
      }

      stats->total_delta_ms += deltaMS;
    }
  }

  memcpy(&stats->lastTime, when, sizeof(struct timeval));
}

/* *************************************** */

void Flow::dumpPacketStats(lua_State* vm, bool cli2srv_direction) {
  lua_newtable(vm);

  lua_push_float_table_entry(vm, "min", cli2srv_direction ? getCli2SrvMinInterArrivalTime() : getSrv2CliMinInterArrivalTime());
  lua_push_float_table_entry(vm, "max", cli2srv_direction ? getCli2SrvMaxInterArrivalTime() : getSrv2CliMaxInterArrivalTime());
  lua_push_float_table_entry(vm, "avg", cli2srv_direction ? getCli2SrvAvgInterArrivalTime() : getSrv2CliAvgInterArrivalTime());

  lua_pushstring(vm, cli2srv_direction ? "interarrival.cli2srv" : "interarrival.srv2cli");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

bool Flow::isBlacklistedFlow() const {
  bool res = (cli_host && srv_host
	      && (cli_host->isBlacklisted()
		  || srv_host->isBlacklisted()
		  || (get_protocol_category() == CUSTOM_CATEGORY_MALWARE)));

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

bool Flow::isSSLProto() {
  u_int16_t lower = ndpi_get_lower_proto(ndpiDetectedProtocol);

  return(
    (lower == NDPI_PROTOCOL_SSL) ||
    (lower == NDPI_PROTOCOL_MAIL_IMAPS) ||
    (lower == NDPI_PROTOCOL_MAIL_SMTPS) ||
    (lower == NDPI_PROTOCOL_MAIL_POPS)
  );
}

/* *************************************** */

void Flow::incStats(bool cli2srv_direction, u_int pkt_len,
		    u_int8_t *payload, u_int payload_len, 
                    u_int8_t l4_proto, u_int8_t is_fragment,
		    const struct timeval *when) {
  payload_len *= iface->getScalingFactor();

  updateSeen();
  updatePacketStats(cli2srv_direction ? &cli2srvStats.pktTime : &srv2cliStats.pktTime, when);

  if((cli_host == NULL) || (srv_host == NULL)) return;

  if(cli2srv_direction) {
    cli2srv_packets++, cli2srv_bytes += pkt_len, cli2srv_goodput_bytes += payload_len;
      cli_host->incSentStats(pkt_len), srv_host->incRecvStats(pkt_len), ip_stats_s2d.pktFrag += is_fragment;
  } else {
    srv2cli_packets++, srv2cli_bytes += pkt_len, srv2cli_goodput_bytes += payload_len;
    cli_host->incRecvStats(pkt_len), srv_host->incSentStats(pkt_len), ip_stats_d2s.pktFrag += is_fragment;
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
  Host *to = src2dst_direction ? srv_host : cli_host;

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

  if(cli2srv_direction)
    cli2srv_packets += in_pkts, cli2srv_bytes += in_bytes, cli2srv_goodput_bytes += in_goodput_bytes,
      srv2cli_packets += out_pkts, srv2cli_bytes += out_bytes, srv2cli_goodput_bytes += out_goodput_bytes,
      ip_stats_s2d.pktFrag += in_fragments, ip_stats_d2s.pktFrag += out_fragments;
  else
    cli2srv_packets += out_pkts, cli2srv_bytes += out_bytes, cli2srv_goodput_bytes += out_goodput_bytes,
      srv2cli_packets += in_pkts, srv2cli_bytes += in_bytes, srv2cli_goodput_bytes += in_goodput_bytes,
      ip_stats_s2d.pktFrag += out_fragments, ip_stats_d2s.pktFrag += in_fragments;

  if(bytes_thpt == 0 && last_seen >= first_seen + 1) {
    /* Do a fist estimation while waiting for the periodic activities */
    bytes_thpt = (cli2srv_bytes + srv2cli_bytes) / (float)(last_seen - first_seen),
      pkts_thpt = (cli2srv_packets + srv2cli_packets) / (float)(last_seen - first_seen);
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
  if(!iface->isPacketInterface())
    return; /* Use setTcpFlags for non-packet interfaces */

  iface->incFlagsStats(flags);
  if(cli_host) cli_host->incFlagStats(src2dst_direction, flags);
  if(srv_host) srv_host->incFlagStats(!src2dst_direction, flags);

  if(flags == TH_SYN) {
    if(cli_host) cli_host->updateSynAlertsCounter(when->tv_sec, flags, this, true);
    if(srv_host) srv_host->updateSynAlertsCounter(when->tv_sec, flags, this, false);
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

      twh_over = true, iface->getTcpFlowStats()->incEstablished();
    } else
      twh_over = true, iface->getTcpFlowStats()->incEstablished();
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

char* Flow::getFlowInfo() {
  if(!isMaskedFlow()) {

    if(isDNS() && protos.dns.last_query)
      return protos.dns.last_query;

    else if(isHTTP() && protos.http.last_url)
      return protos.http.last_url;

    else if(isSSL() && protos.ssl.certificate)
      return protos.ssl.certificate;

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
			  u_int32_t ooo_pkts,
			  u_int32_t retr_pkts,
			  u_int32_t lost_pkts,
			  u_int32_t keep_alive_pkts) {
#ifdef HAVE_NEDGE
  return;
#endif

  TCPPacketStats * stats;
  int16_t cli_network_id = -1, srv_network_id = -1;
  u_int32_t cli_asn = (u_int32_t)-1, srv_asn = (u_int32_t)-1;
  AutonomousSystem *cli_as, *srv_as;
  NetworkStats *cli_network_stats = NULL, *srv_network_stats = NULL;
  bool cli_and_srv_in_same_subnet = false, cli_and_srv_in_same_as = false;

  if(src2dst_direction)
    stats = &tcp_stats_s2d;
  else
    stats = &tcp_stats_d2s;

  stats->pktKeepAlive += keep_alive_pkts;
  stats->pktRetr += retr_pkts;
  stats->pktOOO += ooo_pkts;
  stats->pktLost += lost_pkts;

  if(cli_host) {
    cli_network_id = cli_host->get_local_network_id();
    cli_network_stats = cli_host->getNetworkStats(cli_network_id);
    cli_asn = cli_host->get_asn();
    cli_as = cli_host->get_as();

    if(src2dst_direction)
      cli_host->incSentTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
    else
      cli_host->incRcvdTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
  }

  if(srv_host) {
    srv_network_id = srv_host->get_local_network_id();
    srv_network_stats = srv_host->getNetworkStats(srv_network_id);
    srv_asn = srv_host->get_asn();
    srv_as = srv_host->get_as();

    if(src2dst_direction)
      srv_host->incRcvdTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
    else
      srv_host->incSentTcp(ooo_pkts, retr_pkts, lost_pkts, keep_alive_pkts);
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

  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[act: %u][next: %u][next - act (in flight): %d][ack: %u]",
					 seq_num, next_seq_num,
					 next_seq_num - seq_num, 
					 ack_seq_num);

  if(src2dst_direction) {
    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst][last: %u][next: %u]", tcp_stats_s2d.last, tcp_stats_s2d.next);

    if(window > 0) srv2cli_window = window; /* Note the window is reverted */
    if(tcp_stats_s2d.next > 0) {
      if((tcp_stats_s2d.next != seq_num) /* If equal, seq_num is the expected seq_num as determined with prev. segment */
	 && (tcp_stats_s2d.next != (seq_num - 1))) {
	if((seq_num == tcp_stats_s2d.next - 1)
	   && (payload_Len == 0 || payload_Len == 1)
	   && ((flags & (TH_SYN|TH_FIN|TH_RST)) == 0)) {
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet KeepAlive");
	  cnt_keep_alive++;
	} else if(tcp_stats_s2d.last == seq_num) {
	  cnt_retx++;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet retransmission");
	} else if((tcp_stats_s2d.last > seq_num)
		  && (seq_num < tcp_stats_s2d.next)) {
	  cnt_lost++;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet lost [last: %u][act: %u]", tcp_stats_s2d.last, seq_num);
	} else {
	  cnt_ooo++;
	  update_last_seqnum = ((seq_num - 1) > tcp_stats_s2d.last) ? true : false;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet OOO [last: %u][act: %u]", tcp_stats_s2d.last, seq_num);
	}
      }
    }

    tcp_stats_s2d.next = next_seq_num;
    if(update_last_seqnum) tcp_stats_s2d.last = seq_num;
  } else {
    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src][last: %u][next: %u]", tcp_stats_d2s.last, tcp_stats_d2s.next);

    if(window > 0) cli2srv_window = window; /* Note the window is reverted */
    if(tcp_stats_d2s.next > 0) {
      if((tcp_stats_d2s.next != seq_num)
	 && (tcp_stats_d2s.next != (seq_num-1))) {
	if((seq_num == tcp_stats_d2s.next - 1)
	   && (payload_Len == 0 || payload_Len == 1)
	   && ((flags & (TH_SYN|TH_FIN|TH_RST)) == 0)) {
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet KeepAlive");
	  cnt_keep_alive++;
	} else if(tcp_stats_d2s.last == seq_num) {
	  cnt_retx++;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet retransmission");
	  // bytes
	} else if((tcp_stats_d2s.last > seq_num)
		  && (seq_num < tcp_stats_d2s.next)) {
	  cnt_lost++;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet lost [last: %u][act: %u]", tcp_stats_d2s.last, seq_num);
	} else {
	  cnt_ooo++;
	  update_last_seqnum = ((seq_num - 1) > tcp_stats_d2s.last) ? true : false;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] [last: %u][next: %u]", tcp_stats_d2s.last, tcp_stats_d2s.next);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet OOO [last: %u][act: %u]", tcp_stats_d2s.last, seq_num);
	}
      }
    }
 
    tcp_stats_d2s.next = next_seq_num;
    if(update_last_seqnum) tcp_stats_d2s.last = seq_num;
  }

  if(cnt_keep_alive || cnt_lost || cnt_ooo || cnt_retx)
    incTcpBadStats(src2dst_direction, cnt_ooo, cnt_retx, cnt_lost, cnt_keep_alive);
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
  if((cli_host && cli_host->match(ptree))
     || (srv_host && srv_host->match(ptree)))
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

void Flow::dissectHTTP(bool src2dst_direction, char *payload, u_int16_t payload_len) {
  HTTPstats *h;
  ssize_t host_server_name_len = host_server_name && host_server_name[0] != '\0' ? strlen(host_server_name) : 0;

  if(!isThreeWayHandshakeOK())
    ; /* Useless to compute http stats as client and server could be swapped */
  else if(src2dst_direction) {
    char *space;

    // payload[10]=0; ntop->getTrace()->traceEvent(TRACE_WARNING, "[len: %u][%s]", payload_len, payload);
    h = cli_host->getHTTPstats(); if(h) h->incRequestAsSender(payload); /* Sent */
    h = srv_host->getHTTPstats(); if(h) h->incRequestAsReceiver(payload); /* Rcvd */
    dissect_next_http_packet = true;

    /* use memchr to prevent possibly non-NULL terminated HTTP requests */
    if(payload && ((space = (char*)memchr(payload, ' ', payload_len-1)) != NULL)) {
      u_int l = space - payload;

      if((!strncmp(payload, "GET", 3))
	 || (!strncmp(payload, "POST", 4))
	 || (!strncmp(payload, "HEAD", 4))
	 || (!strncmp(payload, "PUT", 3))
	 ) {
	char *ua;

	diff_num_http_requests++; /* One new request found */

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

	  if(cli_host
	     && cli_host->getMac()
	     // && (cli_host->getMac()->getOperatingSystem() == os_unknown)
	     ) {
	    /*
	      https://en.wikipedia.org/wiki/User_agent

	      Most Web browsers use a User-Agent string value as follows:
	      Mozilla/[version] ([system and browser information]) [platform] ([platform details]) [extensions]
	    */

	    if((ua = strchr(buf, '(')) != NULL) {
	      char *end = strchr(buf, ')');

	      if(end) {
		OperatingSystem os = os_unknown;

		end[0] = '\0';
		ua++;

		if(strstr(ua, "iPad") || strstr(ua, "iPod") || strstr(ua, "iPhone"))
		  os = os_ios;
		else if(strstr(ua, "Android"))
		  os = os_android;
		else if(strstr(ua, "Airport"))
		  os = os_apple_airport;
		else if(strstr(ua, "Macintosh") || strstr(ua, "OS X"))
		  os = os_macos;
		else if(strstr(ua, "Windows"))
		  os = os_windows;
		else if(strcasestr(ua, "Linux") || strstr(ua, "Debian") || strstr(ua, "Ubuntu"))
		  os = os_linux;

		if(os != os_unknown) {
#ifdef DEBUG_UA
		  char mbuf[32];

		  ntop->getTrace()->traceEvent(TRACE_WARNING, "[UA] [%s][OS=%u][%s]", cli_host->getMac()->get_string_key(mbuf, sizeof(mbuf)), os, ua);
#endif

		  if(!(cli_host->get_ip()->isBroadcastAddress()
		       || cli_host->get_ip()->isMulticastAddress()))
		  cli_host->getMac()->setOperatingSystem(os);
		}
	      }
	    }
	  }
	}
      }
    }
  } else {
    if(dissect_next_http_packet) {
      char *space;

      // payload[10]=0; ntop->getTrace()->traceEvent(TRACE_WARNING, "[len: %u][%s]", payload_len, payload);
      h = cli_host->getHTTPstats(); if(h) h->incResponseAsReceiver(payload); /* Rcvd */
      h = srv_host->getHTTPstats(); if(h) h->incResponseAsSender(payload); /* Sent */
      dissect_next_http_packet = false;

      if((space = (char*)memchr(payload, ' ', payload_len)) != NULL) {
	u_int l = space - payload;

	payload_len -= (l + 1);
	payload = &space[1];
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

      if(cli_host)
	cli_host->inlineSetMDNSName(name); /* See (**) */

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

	      if(strncmp(txt_buf, "nm=", 3) == 0) {
		if(cli_host)
		  cli_host->inlineSetMDNSTXTName(&txt_buf[3]);
	      }

	      if(strncmp(txt_buf, "ssid=", 3) == 0) {
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
	if(cli_host) cli_host->inlineSetSSDPLocation(url);
	break;
      }
    }
  }
}

/* *************************************** */

#ifdef HAVE_NEDGE

bool Flow::isPassVerdict() {
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

/* *************************************** */

bool Flow::isLowGoodput() {
  if(iface->getIfType() == interface_type_ZMQ
     || iface->getIfType() == interface_type_NETFILTER
     || iface->getIfType() == interface_type_SYSLOG
     || protocol == IPPROTO_UDP)
    return(false);
  else
    return((get_duration() >= FLOW_GOODPUT_MIN_DURATION
	    && ((get_goodput_bytes()*100)/(get_bytes()+1 /* avoid zero divisions */)) < FLOW_GOODPUT_THRESHOLD) ? true : false);
}

/* ***************************************************** */

FlowStatus Flow::getFlowStatus() {
#ifndef HAVE_NEDGE
  u_int32_t issues_count;
#endif
  u_int16_t l7proto = ndpi_get_lower_proto(ndpiDetectedProtocol);

  /* NOTE: evaluation order is important here! */

  if(iface->isPacketInterface() && iface->is_purge_idle_interface() &&
      !is_ready_to_be_purged() && isIdle(5 * ntop->getPrefs()->get_flow_max_idle())) {
    /* Should've already been marked as idle and purged */
    return status_not_purged;
  }

  if(isBlacklistedFlow())
    return status_blacklisted;

  if(!isDeviceAllowedProtocol())
    return status_device_protocol_not_allowed;

  //if(get_protocol_category() == CUSTOM_CATEGORY_MINING)
  if(ndpiDetectedProtocol.category == CUSTOM_CATEGORY_MINING)
    return status_web_mining_detected;

  if(getSuricataAlert())
    return status_ids_alert;

#ifndef HAVE_NEDGE
  /* All flows */
  issues_count = tcp_stats_s2d.pktRetr + tcp_stats_s2d.pktOOO + tcp_stats_s2d.pktLost;
  if(issues_count > CONST_TCP_CHECK_ISSUES_THRESHOLD) {
    if(issues_count > (cli2srv_packets / CONST_TCP_CHECK_SEVERE_ISSUES_RATIO))
      return status_tcp_severe_connection_issues;
    else if(issues_count > (cli2srv_packets / CONST_TCP_CHECK_ISSUES_RATIO))
      return status_tcp_connection_issues;
  }

  issues_count = tcp_stats_d2s.pktRetr + tcp_stats_d2s.pktOOO + tcp_stats_d2s.pktLost;
  if(issues_count > CONST_TCP_CHECK_ISSUES_THRESHOLD) {
    if(issues_count > (srv2cli_packets / CONST_TCP_CHECK_SEVERE_ISSUES_RATIO))
      return status_tcp_severe_connection_issues;
    else if(issues_count > (srv2cli_packets / CONST_TCP_CHECK_ISSUES_RATIO))
      return status_tcp_connection_issues;
  }
#endif

  if(iface->getIfType() == interface_type_ZMQ) {
    /* ZMQ flows */
  } else {
    /* Packet flows */
    bool isIdle = idle();

#ifndef HAVE_NEDGE
    bool lowGoodput = isLowGoodput();
#endif

    if(protocol == IPPROTO_TCP) {
      if((srv2cli_packets == 0) && ((time(NULL)-last_seen) > CONST_ALERT_PROBING_TIME))
	return status_suspicious_tcp_probing;

      if(!twh_over) {
	if(isIdle)
	  return status_suspicious_tcp_syn_probing;
	else
	  return status_normal;
      } else {
	/* 3WH is over */
	switch(l7proto) {
	case NDPI_PROTOCOL_SSL:
	  /*
	    CNs are NOT case sensitive as per RFC 5280
	    so we use ...case... functions to do the comparisions
	  */
	  if(protos.ssl.certificate
	     && protos.ssl.server_certificate
	     && !protos.ssl.subject_alt_name_match) {
	    if(protos.ssl.server_certificate[0] == '*') {
	      if(!strcasestr(protos.ssl.certificate, &protos.ssl.server_certificate[1]))
		return status_ssl_certificate_mismatch;
	    } else if(strcasecmp(protos.ssl.certificate, protos.ssl.server_certificate))
	      return status_ssl_certificate_mismatch;
	  }
	  break;
 	}

#ifndef HAVE_NEDGE
	if(isIdle  && lowGoodput)  return status_slow_data_exchange;

	if(!isIdle && lowGoodput) {
	  if(isTCPReset())
	    return status_tcp_connection_refused;
	  else
	    return status_low_goodput;
	}
#endif
      }
    }

    /* If here is either UDP or TCP */
    switch(l7proto) {
    case NDPI_PROTOCOL_DNS:
      if(protos.dns.invalid_query)
	return status_dns_invalid_query;
    }
  }

  if(cli_host && srv_host
      && cli_host->get_ip()->isNonEmptyUnicastAddress()
      && srv_host->get_ip()->isNonEmptyUnicastAddress()) {

    if(! cli_host->isLocalHost() && 
       ! srv_host->isLocalHost())
      return status_remote_to_remote;

    if(get_duration() > ntop->getPrefs()->get_longlived_flow_duration())
      return status_longlived;
  }

  if(cli_host && srv_host
     /* Assumes elephant flows are normal when the category is data transfer */
     && get_protocol_category() != NDPI_PROTOCOL_CATEGORY_DATA_TRANSFER) {
    u_int64_t local_to_remote_bytes = 0, remote_to_local_bytes = 0;

    if(cli_host->isLocalHost() && ! srv_host->isLocalHost()) {
      local_to_remote_bytes = get_bytes_cli2srv();
      remote_to_local_bytes = get_bytes_srv2cli();
    } else if(srv_host->isLocalHost() && ! cli_host->isLocalHost()) {
      local_to_remote_bytes = get_bytes_srv2cli();
      remote_to_local_bytes = get_bytes_cli2srv();
    }

    if(local_to_remote_bytes > ntop->getPrefs()->get_elephant_flow_local_to_remote_bytes())
      return status_elephant_local_to_remote;
    if(remote_to_local_bytes > ntop->getPrefs()->get_elephant_flow_remote_to_local_bytes())
      return status_elephant_remote_to_local;
  }

  if(isICMP() && has_long_icmp_payload())
    return status_data_exfiltration;

#ifdef HAVE_NEDGE
  /* Leave this at the end. A more specific status should be returned above if avaialble. */
  if(!isPassVerdict())
    return status_blocked;
#endif

#if 0
  if(iface->getAlertLevel() > 0)
   return(status_flow_when_interface_alerted);
#endif

  if(protos.ssl.ssl_version && (protos.ssl.ssl_version < 0x303 /* TLSv1.2 */))
    return(status_ssl_old_protocol_version);
  else if(protos.ssl.ja3.server_unsafe_cipher != ndpi_cipher_safe)
    return(status_ssl_unsafe_ciphers);
  
  return(status_normal);
}

/* ***************************************************** */

bool Flow::isTiny() {
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
  nf_existing_flow = !(cli2srv_packets > s2d_pkts || cli2srv_bytes > s2d_bytes
		       || srv2cli_packets > d2s_pkts || srv2cli_bytes > d2s_bytes);

  updateSeen();

  /*
     We need to set last_conntrack_update even with 0 packtes/bytes
     as this function has been called only within netfilter through
     the conntrack handler, and thus the flow is still alive.
  */
  last_conntrack_update = now;

  iface->_incStats(isIngress2EgressDirection(), now, eth_proto, ndpiDetectedProtocol.app_protocol, protocol,
		   nf_existing_flow ? s2d_bytes - cli2srv_bytes : s2d_bytes,
		   nf_existing_flow ? s2d_pkts - cli2srv_packets : s2d_pkts,
		   overhead);

  iface->_incStats(!isIngress2EgressDirection(), now, eth_proto, ndpiDetectedProtocol.app_protocol, protocol,
		  nf_existing_flow ? d2s_bytes - srv2cli_bytes : d2s_bytes,
		  nf_existing_flow ? d2s_pkts - srv2cli_packets : d2s_pkts,
		  overhead);

  if(nf_existing_flow) {
    cli2srv_packets = s2d_pkts, cli2srv_bytes = s2d_bytes,
      srv2cli_packets = d2s_pkts, srv2cli_bytes = d2s_bytes;
  } else {
    cli2srv_packets += s2d_pkts, cli2srv_bytes += s2d_bytes,
      srv2cli_packets += d2s_pkts, srv2cli_bytes += d2s_bytes;
  }
}
#endif

/* ***************************************************** */

void Flow::setParsedeBPFInfo(const ParsedeBPF * const ebpf, bool src2dst_direction) {
  if(!ebpf)
    return;

  if(!iface->hasSeenEBPFEvents())
    iface->setSeenEBPFEvents();

  bool client_process;
  ParsedeBPF *cur = NULL;

  /* Try to guess if the process is the client or the server */
  if(ebpf->event_type == ebpf_event_type_tcp_accept)
    client_process = false;
  else if(ebpf->event_type == ebpf_event_type_tcp_connect)
    client_process = true;
  else if(get_srv_port() > get_cli_port())
    client_process = false;
  else
    client_process = true;

  if(!src2dst_direction)
    client_process = !client_process;

  if(client_process) {
    if(!cli_ebpf)
      cur = cli_ebpf = new (std::nothrow) ParsedeBPF(*ebpf);
    else
      cli_ebpf->update(ebpf);
  } else { /* server_process */
    if(!srv_ebpf)
      cur = srv_ebpf = new (std::nothrow) ParsedeBPF(*ebpf);
    else
      srv_ebpf->update(ebpf);
  }

  if(cur && cur->container_info_set) {
    if(!iface->hasSeenContainers())
      iface->setSeenContainers();

    if(cur->container_info.data_type == container_info_data_type_k8s
       && !iface->hasSeenPods()
       && cur->container_info.data.k8s.pod)
      iface->setSeenPods();
  }

  updateJA3();
}

/* ***************************************************** */

void Flow::updateJA3() {
  if(protos.ssl.ja3.client_hash)
    cli_host->getSSLFingerprint()->update(protos.ssl.ja3.client_hash,
					  cli_ebpf ? cli_ebpf->process_info.process_name : NULL);
}

/* ***************************************************** */

/* Called when a flow is set_to_purge */
void Flow::postFlowSetPurge(time_t t) {
  /* not called from the datapath for flows, so it is only
     safe to touch low goodput uses */
  if(good_low_flow_detected) {
    if(cli_host) cli_host->decLowGoodputFlows(t, true);
    if(srv_host) srv_host->decLowGoodputFlows(t, false);
  }

  FlowStatus status = getFlowStatus();

  if(status != status_normal) {
#if 0
  char buf[256];
  printf("%s status=%d\n", print(buf, sizeof(buf)), status);
#endif

    if(cli_host) cli_host->incNumAnomalousFlows(true);
    if(srv_host) srv_host->incNumAnomalousFlows(false);
  }
}

/* ***************************************************** */

void Flow::fillZmqFlowCategory() {
  struct ndpi_detection_module_struct *ndpi_struct = iface->get_ndpi_struct();
  char *srv_name = getFlowServerInfo();

  if(!cli_host || !srv_host)
    return;

  if(cli_host->get_ip()->isIPv4()) {
    if(ndpi_fill_ip_protocol_category(ndpi_struct, get_cli_ipv4(), get_srv_ipv4(), &ndpiDetectedProtocol))
      return;
  }

  if(srv_name && srv_name[0]) {
    unsigned long id;

    if(ndpi_match_custom_category(ndpi_struct, srv_name, &id) == 0) {
      ndpiDetectedProtocol.category = (ndpi_protocol_category_t)id;
      return;
    }
  }
}

/* ***************************************************** */

void Flow::dissectSSL(char *payload, u_int16_t payload_len) {
  if(protos.ssl.dissect_certificate) {
    u_int16_t _payload_len = payload_len + protos.ssl.certificate_leftover;
    u_char *_payload       = (u_char*)malloc(_payload_len);
    bool find_initial_pattern = true;

    if(!_payload)
      return;
    else {
      int i = 0;

      if(protos.ssl.certificate_leftover > 0) {
	memcpy(_payload, protos.ssl.certificate_buf_leftover, (i = protos.ssl.certificate_leftover));
	free(protos.ssl.certificate_buf_leftover);
	protos.ssl.certificate_buf_leftover = NULL, protos.ssl.certificate_leftover = 0;
	find_initial_pattern = false;
      }

      memcpy(&_payload[i], payload, payload_len);
    }

    if(_payload_len > 4) {
      for(int i = (find_initial_pattern ? 9 : 0); i < _payload_len - 4 && protos.ssl.dissect_certificate; i++) {

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

	      if(i < _payload_len - 1 && (len = _payload[i + 1]) && i + len + 2 < _payload_len) {
		i += 2;

		if(!isalpha(_payload[i]) && _payload[i] != '*') {
		  protos.ssl.dissect_certificate = false;
		  break;
		} else {
		  char buf[len + 1];

		  strncpy(buf, (const char*)&_payload[i], len);
		  buf[len] = '\0';

#if 0
		  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [Len %u][sizeof(buf): %u][ssl cert: %s]", buf, len, sizeof(buf), getSSLCertificate());
#endif

		  /*
		    CNs are NOT case sensitive as per RFC 5280
		  */
		  if(protos.ssl.certificate
		     && ((buf[0] != '*' && !strncasecmp(protos.ssl.certificate, buf, sizeof(buf)))
			 || (buf[0] == '*' && strcasestr(protos.ssl.certificate, &buf[1])))) {
		    protos.ssl.subject_alt_name_match = true;
		    protos.ssl.dissect_certificate = false;
		    break;
		  }
		}

		i += len;
	      } else {
#if 0
		ntop->getTrace()->traceEvent(TRACE_NORMAL, "Leftover %u bytes [%u len]", _payload_len - i, len);
#endif
		protos.ssl.certificate_leftover = _payload_len - i;

		if((protos.ssl.certificate_buf_leftover = (char*)malloc(protos.ssl.certificate_leftover)) != NULL)
		  memcpy(protos.ssl.certificate_buf_leftover, &_payload[i], protos.ssl.certificate_leftover);
		else
		  protos.ssl.certificate_leftover = 0;

		break;
	      }
	    } else {
	      protos.ssl.dissect_certificate = false;
	      break;
	    }
	  }
	}
      } /* for */
    }

    free(_payload);
  }
}
