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

//#define DEBUG_DISCOVERY
//#define DEBUG_UA

/* *************************************** */

Flow::Flow(NetworkInterface *_iface,
	   u_int16_t _vlanId, u_int8_t _protocol,
	   Mac *_cli_mac, IpAddress *_cli_ip, u_int16_t _cli_port,
	   Mac *_srv_mac, IpAddress *_srv_ip, u_int16_t _srv_port,
	   time_t _first_seen, time_t _last_seen) : GenericHashEntry(_iface) {
  vlanId = _vlanId, protocol = _protocol, cli_port = _cli_port, srv_port = _srv_port;
  cli2srv_packets = 0, cli2srv_bytes = 0, cli2srv_goodput_bytes = 0,
    srv2cli_packets = 0, srv2cli_bytes = 0, srv2cli_goodput_bytes = 0,
    cli2srv_last_packets = 0, cli2srv_last_bytes = 0, srv2cli_last_packets = 0, srv2cli_last_bytes = 0,
    cli_host = srv_host = NULL, good_low_flow_detected = false, state = flow_state_other,
    srv2cli_last_goodput_bytes = cli2srv_last_goodput_bytes = 0, good_ssl_hs = true,
    flow_alerted = flow_dropped_counts_increased = false, vrfId = 0;

  l7_protocol_guessed = detection_completed = false,
    flow_packets_head = flow_packets_tail = NULL,
    dump_flow_traffic = false,
    memset(&ndpiDetectedProtocol, 0, sizeof(ndpiDetectedProtocol));
  doNotExpireBefore = iface->getTimeLastPktRcvd() + DONT_NOT_EXPIRE_BEFORE_SEC;
#ifdef HAVE_NEDGE
  last_conntrack_update = 0;
#endif

  memset(&cli2srvStats, 0, sizeof(cli2srvStats)), memset(&srv2cliStats, 0, sizeof(srv2cliStats));

  ndpiFlow = NULL, cli_id = srv_id = NULL, client_proc = server_proc = NULL;
  json_info = strdup("{}"), cli2srv_direction = true, twh_over = false,
    dissect_next_http_packet = false,
    check_tor = false, host_server_name = NULL, diff_num_http_requests = 0,
    bt_hash = NULL;

  src2dst_tcp_flags = 0, dst2src_tcp_flags = 0, last_update_time.tv_sec = 0, last_update_time.tv_usec = 0,
    bytes_thpt = 0, goodput_bytes_thpt = 0, top_bytes_thpt = 0, top_pkts_thpt = 0;
  bytes_thpt_cli2srv  = 0, goodput_bytes_thpt_cli2srv = 0;
  bytes_thpt_srv2cli  = 0, goodput_bytes_thpt_srv2cli = 0;
  pkts_thpt = 0, pkts_thpt_cli2srv = 0, pkts_thpt_srv2cli = 0;
  cli2srv_last_bytes = 0, prev_cli2srv_last_bytes = 0, srv2cli_last_bytes = 0, prev_srv2cli_last_bytes = 0;
  cli2srv_last_packets = 0, prev_cli2srv_last_packets = 0, srv2cli_last_packets = 0, prev_srv2cli_last_packets = 0;
  top_bytes_thpt = 0, top_goodput_bytes_thpt = 0, applLatencyMsec = 0, idle_flow = false;

  last_db_dump.cli2srv_packets = 0, last_db_dump.srv2cli_packets = 0,
    last_db_dump.cli2srv_bytes = 0, last_db_dump.srv2cli_bytes = 0,
    last_db_dump.cli2srv_goodput_bytes = 0, last_db_dump.srv2cli_goodput_bytes = 0,
    last_db_dump.last_dump = 0;

  memset(&protos, 0, sizeof(protos));
  memset(&flow_device, 0, sizeof(flow_device));

  iface->findFlowHosts(_vlanId, _cli_mac, _cli_ip, &cli_host, _srv_mac, _srv_ip, &srv_host);
  if(cli_host) { cli_host->incUses(); cli_host->incNumFlows(true);  }
  if(srv_host) { srv_host->incUses(); srv_host->incNumFlows(false); }

#ifdef NTOPNG_PRO
  HostPools *hp = iface->getHostPools();

  routing_table_id = DEFAULT_ROUTING_TABLE_ID;

  if(hp) {
    if(cli_host) routing_table_id = hp->getRoutingPolicy(cli_host->get_host_pool());
    if(srv_host) routing_table_id = max_val(routing_table_id, hp->getRoutingPolicy(srv_host->get_host_pool()));
  }
#endif

  passVerdict = true, quota_exceeded = false;
  cli_quota_app_proto = cli_quota_is_category = srv_quota_app_proto = srv_quota_is_category = false;
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
							  protocol, 0, 0, 0, 0);
    setDetectedProtocol(ndpiDetectedProtocol, true);
    break;
  }
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
  if(flow_packets_head)
    flushBufferedPackets();

  if(cli_host) cli_host->decNumFlows(true),  cli_host->decUses();
  if(srv_host) srv_host->decNumFlows(false), srv_host->decUses();

  if(json_info)        free(json_info);
  if(client_proc)      delete(client_proc);
  if(server_proc)      delete(server_proc);
  if(host_server_name) free(host_server_name);

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
  }

  if(bt_hash)          free(bt_hash);

  freeDPIMemory();
}

/* *************************************** */

void Flow::dumpFlowAlert() {
  FlowStatus status = getFlowStatus();

  if(!isFlowAlerted() && status != status_normal) {
    bool do_dump = true;

    switch(status) {
    case status_normal:
      do_dump = false;
      break;

    case status_web_mining_detected:
      do_dump = ntop->getPrefs()->are_mining_alerts_enabled();
      break;

    case status_blacklisted:
      do_dump = true;
      break;

    case status_slow_tcp_connection: /* 1 */
    case status_slow_application_header: /* 2 */
    case status_slow_data_exchange: /* 3 */
    case status_low_goodput: /* 4 */
    case status_tcp_connection_issues: /* 6 - i.e. too many retransmission ooo... or similar */
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
    }

    if(do_dump)
      iface->getAlertsManager()->storeFlowAlert(this);
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
      The statement below can craete issues sometimes as devices publish
      themselves with varisous names depending on the context (**)
    */
    if((ndpiFlow->protos.mdns.answer[0] != '\0') && cli_host) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "[MDNS] %s", ndpiFlow->protos.mdns.answer);
      cli_host->setMDSNInfo(ndpiFlow->protos.mdns.answer);
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
	cli_host->setOS((char*)ndpiFlow->protos.http.detected_os);

      if(cli_host && cli_host->isLocalHost())
	cli_host->incrVisitedWebSite(host_server_name);
    }
    break;
  } /* switch */

#ifdef NTOPNG_PRO
  if((ndpiDetectedProtocol.app_protocol == NDPI_PROTOCOL_UNKNOWN) && (!l7_protocol_guessed))
    ntop->getFlowChecker()->flowCheck(this);
#endif

  if(protocol_processed
     /* For DNS we delay the memory free so that we can let nDPI analyze all the packets of the flow */
     && (l7proto != NDPI_PROTOCOL_DNS))
    freeDPIMemory();
}

/* *************************************** */

void Flow::guessProtocol() {
  detection_completed = true; /* We give up */

  if((protocol == IPPROTO_TCP) || (protocol == IPPROTO_UDP)) {
    if(cli_host && srv_host) {
      /* We can guess the protocol */
      IpAddress *cli_ip = cli_host->get_ip(), *srv_ip = srv_host->get_ip();
      ndpiDetectedProtocol = ndpi_guess_undetected_protocol(iface->get_ndpi_struct(), protocol,
							    ntohl(cli_ip ? cli_ip->get_ipv4() : 0),
							    ntohs(cli_port),
							    ntohl(srv_ip ? srv_ip->get_ipv4() : 0),
							    ntohs(srv_port));
    }

    l7_protocol_guessed = true;
  }
}

/* *************************************** */

void Flow::setDetectedProtocol(ndpi_protocol proto_id, bool forceDetection) {
  if(proto_id.app_protocol != NDPI_PROTOCOL_UNKNOWN) {
    ndpiDetectedProtocol = proto_id;

    /* Let the client SSL certificate win over the server SSL certificate
       this addresses detection for youtube, e.g., when the client
       requests s.youtube.com but the server responds with google.com */
    if((proto_id.master_protocol == NDPI_PROTOCOL_SSL)
       && (get_packets() < NDPI_MIN_NUM_PACKETS)
       && (ndpiFlow->protos.stun_ssl.ssl.client_certificate[0] == '\0')
       && (ndpiFlow->protos.stun_ssl.ssl.server_certificate[0] == '\0')) {
      get_ndpi_flow()->detected_protocol_stack[0] = NDPI_PROTOCOL_UNKNOWN;
      return;
    }

    processDetectedProtocol();
    detection_completed = true;
  } else if(forceDetection
	    || (get_packets() >= NDPI_MIN_NUM_PACKETS)
	    || (!iface->is_ndpi_enabled())
	    || iface->isSampledTraffic()
	    ) {
    guessProtocol();
    detection_completed = true;
  }

  if(detection_completed) {
#ifdef HAVE_NEDGE
    updateFlowShapers(true);
#endif
    flushBufferedPackets();
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

char* Flow::printTCPflags(u_int8_t flags, char *buf, u_int buf_len) {
  snprintf(buf, buf_len, "%s%s%s%s%s",
	   (flags & TH_SYN) ? " SYN" : "",
	   (flags & TH_ACK) ? " ACK" : "",
	   (flags & TH_FIN) ? " FIN" : "",
	   (flags & TH_RST) ? " RST" : "",
	   (flags & TH_PUSH) ? " PUSH" : "");
  if(buf[0] == ' ')
    return(&buf[1]);
  else
    return(buf);
}
/* *************************************** */

char* Flow::print(char *buf, u_int buf_len) {
  char buf1[32], buf2[32], buf3[32], pbuf[32], tcp_buf[64];
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
	   "%s %s:%u &gt; %s:%u [first: %u][last: %u][proto: %u.%u/%s][device: %u in: %u out:%u][%u/%u pkts][%llu/%llu bytes][%s]"
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
	   flow_device.device_ip, flow_device.in_index, flow_device.out_index,
	   cli2srv_packets, srv2cli_packets,
	   (long long unsigned) cli2srv_bytes, (long long unsigned) srv2cli_bytes,
	   printTCPflags(getTcpFlags(), buf3, sizeof(buf3)),
	   (isSSL() && protos.ssl.certificate) ? "[" : "",
	   (isSSL() && protos.ssl.certificate) ? protos.ssl.certificate : "",
	   (isSSL() && protos.ssl.certificate) ? "]" : ""
#if defined(NTOPNG_PRO) && defined(SHAPER_DEBUG)
	   , shapers
#endif
	   );

  if(getFlowStatus() == status_dns_invalid_query && protos.dns.last_query)
    snprintf(&buf[strlen(buf)], buf_len - strlen(buf), "[query: %s]", protos.dns.last_query);

return(buf);
}

/* *************************************** */

bool Flow::dumpFlow() {
  bool rc = false;
  time_t now;

  dumpFlowAlert();

  if(((cli2srv_packets - last_db_dump.cli2srv_packets) == 0)
     && ((srv2cli_packets - last_db_dump.srv2cli_packets) == 0))
      return(rc);

  if(ntop->getPrefs()->do_dump_flows_on_mysql()
     || ntop->getPrefs()->do_dump_flows_on_es()
     || ntop->getPrefs()->do_dump_flows_on_ls()
#if defined(HAVE_NINDEX) && defined(NTOPNG_PRO)
     || ntop->getPrefs()->do_dump_flows_on_nindex()
#endif
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

    now = time(NULL);

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

    if(!idle_flow) {
      if((now - get_first_seen()) < CONST_DB_DUMP_FREQUENCY
	 || (now - last_db_dump.last_dump) < CONST_DB_DUMP_FREQUENCY)
	return(rc);
    } else {
      /* idle flows always dumped */
    }

    if(cli_host) {
      if(ntop->getPrefs()->do_dump_flows_on_mysql())
	cli_host->getInterface()->dumpDBFlow(last_seen, this);
      else if(ntop->getPrefs()->do_dump_flows_on_es())
	cli_host->getInterface()->dumpEsFlow(last_seen, this);
      else if(ntop->getPrefs()->do_dump_flows_on_ls())
        cli_host->getInterface()->dumpLsFlow(last_seen, this);
#if defined(HAVE_NINDEX) && defined(NTOPNG_PRO)
      else if(ntop->getPrefs()->do_dump_flows_on_nindex())
        cli_host->getInterface()->dumpnIndexFlow(last_seen, this);
#endif
    }

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

void Flow::update_hosts_stats(struct timeval *tv) {
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

  if((!isDetectionCompleted()) && ((tv->tv_sec - get_last_seen()) > 5 /* sec */)) {
    /* If we have not found out the protocol until now we can give up at this point */
    ndpi_protocol proto_id = { NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_UNKNOWN };
    setDetectedProtocol(proto_id, true);
  }

  if((idle_flow |= isReadyToPurge())) {
    /* Marked as ready to be purged, will be purged by NetworkInterface::purgeIdleFlows */
    set_to_purge();
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

  if (ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN
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

#ifdef NTOPNG_PRO
  if(ntop->getPro()->has_valid_license() && ntop->getPrefs()->is_enterprise_edition())
    iface->aggregatePartialFlow(this); /* must go before updating _last_ updates as it uses them */
#endif

  cli2srv_last_packets = sent_packets, cli2srv_last_bytes = sent_bytes,
    cli2srv_last_goodput_bytes = sent_goodput_bytes;
  srv2cli_last_packets = rcvd_packets, srv2cli_last_bytes = rcvd_bytes,
    srv2cli_last_goodput_bytes = rcvd_goodput_bytes;

  if(cli_host && srv_host) {
    cli_network_id = cli_host->get_local_network_id();
    srv_network_id = srv_host->get_local_network_id();

    if(cli_network_id >= 0 && (cli_network_id == srv_network_id))
      cli_and_srv_in_same_subnet = true;

    if(diff_sent_packets || diff_rcvd_packets) {
      /* Update L2 Device stats */

      if(srv_host->get_mac()) {
#ifdef HAVE_NEDGE
        srv_host->getMac()->incSentStats(diff_rcvd_packets, diff_rcvd_bytes);
        srv_host->getMac()->incRcvdStats(diff_sent_packets, diff_sent_bytes);
#endif

        if(ntop->getPrefs()->areMacNdpiStatsEnabled()) {
	  srv_host->getMac()->incnDPIStats(tv->tv_sec, stats_protocol,
					   diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes,
					   diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes);

        }
      }

      if(cli_host->getMac()) {
#ifdef HAVE_NEDGE
        cli_host->getMac()->incSentStats(diff_sent_packets, diff_sent_bytes);
        cli_host->getMac()->incRcvdStats(diff_rcvd_packets, diff_rcvd_bytes);
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
      cli_host->incStats(tv->tv_sec, protocol, stats_protocol,
			 diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes);

      // update per-subnet byte counters
      if(cli_network_stats) { // only if the network is known and local
	if(!cli_and_srv_in_same_subnet) {
	  cli_network_stats->incEgress(diff_sent_packets, diff_sent_bytes,
				       srv_host->get_ip()->isBroadcastAddress());
	  cli_network_stats->incIngress(diff_rcvd_packets, diff_rcvd_bytes,
					cli_host->get_ip()->isBroadcastAddress());
	} else // client and server ARE in the same subnet
	  // need to update the inner counter (just one time, will intentionally skip this for srv_host)
	  cli_network_stats->incInner(diff_sent_packets + diff_rcvd_packets,
				      diff_sent_bytes + diff_rcvd_bytes,
				      srv_host->get_ip()->isBroadcastAddress()
				      || cli_host->get_ip()->isBroadcastAddress());
      }

      NetworkStats *srv_network_stats;

      srv_network_stats = srv_host->getNetworkStats(srv_network_id);
      srv_host->incStats(tv->tv_sec, protocol, stats_protocol,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes,
			 diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes);

      if(srv_network_stats) {
	// local and known server network
	if(!cli_and_srv_in_same_subnet) {
	  srv_network_stats->incIngress(diff_sent_packets, diff_sent_bytes,
					srv_host->get_ip()->isBroadcastAddress());
	  srv_network_stats->incEgress(diff_rcvd_packets, diff_rcvd_bytes,
				       cli_host->get_ip()->isBroadcastAddress());
	}
      }

      // Update Country stats
      Country *cli_country_stats = cli_host->getCountryStats();
      Country *srv_country_stats = srv_host->getCountryStats();

      if(cli_country_stats && srv_country_stats && cli_country_stats->equal(srv_country_stats))
	cli_and_srv_in_same_country = true;

      if(cli_country_stats) {
	if(!cli_and_srv_in_same_country) {
	  cli_country_stats->incEgress(diff_sent_packets, diff_sent_bytes,
				       srv_host->get_ip()->isBroadcastAddress());
	  cli_country_stats->incIngress(diff_rcvd_packets, diff_rcvd_bytes,
					cli_host->get_ip()->isBroadcastAddress());
	} else // client and server ARE in the same country
	  // need to update the inner counter (just one time, will intentionally skip this for srv_host)
	  cli_country_stats->incInner(diff_sent_packets + diff_rcvd_packets,
				      diff_sent_bytes + diff_rcvd_bytes,
				      srv_host->get_ip()->isBroadcastAddress()
				      || cli_host->get_ip()->isBroadcastAddress());
      }

      if(srv_country_stats) {
	if(!cli_and_srv_in_same_country) {
	  srv_country_stats->incIngress(diff_sent_packets, diff_sent_bytes,
					srv_host->get_ip()->isBroadcastAddress());
	  srv_country_stats->incEgress(diff_rcvd_packets, diff_rcvd_bytes,
				       cli_host->get_ip()->isBroadcastAddress());
	}
      }

      if(host_server_name
	 && (ndpi_is_proto(ndpiDetectedProtocol, NDPI_PROTOCOL_HTTP)
	     || ndpi_is_proto(ndpiDetectedProtocol, NDPI_PROTOCOL_HTTP_PROXY))) {
	srv_host->updateHTTPHostRequest(host_server_name,
					diff_num_http_requests,
					diff_sent_bytes, diff_rcvd_bytes);
	diff_num_http_requests = 0; /*
				      As this is a difference it is reset
				      whenever we update the counters
				    */
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

	if (cli_host->get_host_pool() != srv_host->get_host_pool())
	  iface->topProtocolsAdd(srv_host->get_host_pool(), stats_protocol, diff_bytes);

	if (cli_host->get_mac() && srv_host->getMac()) {
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

	if(!idle_flow /* set_to_purge() deals with low goodput flows when they become idle */
	   && iface->getIfType() != interface_type_ZMQ
	   && protocol == IPPROTO_TCP
	   && get_goodput_bytes() > 0
	   && ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_SSH) {
	  if(isLowGoodput()) {
	    if(!good_low_flow_detected) {
	      if(cli_host) cli_host->incLowGoodputFlows(true);
	      if(srv_host) srv_host->incLowGoodputFlows(false);
	      good_low_flow_detected = true;
	    }
	  } else {
	    if(good_low_flow_detected) {
	      /* back to normal */
	      if(cli_host) cli_host->decLowGoodputFlows(true);
	      if(srv_host) srv_host->decLowGoodputFlows(false);
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

  if(dumpFlow()) {
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
  if(!diff_sent_packets && !diff_rcvd_packets)
    return; /* Nothing to update */

  HostPools *hp;
  u_int16_t cli_host_pool_id, srv_host_pool_id;
  ndpi_protocol_category_t master_category_id = getInterface()->get_ndpi_proto_category(ndpiDetectedProtocol.master_protocol);
  ndpi_protocol_category_t app_category_id = getInterface()->get_ndpi_proto_category(ndpiDetectedProtocol.app_protocol);

  hp = iface->getHostPools();
  if(hp) {
    /* Client host */
    if(cli_host) {
      cli_host_pool_id = cli_host->get_host_pool();

      /* Overall host pool stats */
      if (ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN
	  && !ndpi_is_subprotocol_informative(NULL, ndpiDetectedProtocol.master_protocol))
	hp->incPoolStats(tv->tv_sec, cli_host_pool_id, ndpiDetectedProtocol.app_protocol, app_category_id,
		       diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
      else
	hp->incPoolStats(tv->tv_sec, cli_host_pool_id, ndpiDetectedProtocol.master_protocol, master_category_id,
		       diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);

      /* Per host quota-enforcement stats */
      if(hp->enforceQuotasPerPoolMember(cli_host_pool_id)) {
	cli_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.master_protocol, master_category_id,
					   diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
	cli_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.app_protocol, app_category_id,
					   diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes);
      }
    }

    /* Server host */
    if(srv_host) {
      srv_host_pool_id = srv_host->get_host_pool();

      /* Update server pool stats only if the pool is not equal to the client pool */
      if(!cli_host || srv_host_pool_id != cli_host_pool_id) {
	if (ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN
	    && !ndpi_is_subprotocol_informative(NULL, ndpiDetectedProtocol.master_protocol))
	  hp->incPoolStats(tv->tv_sec, srv_host_pool_id, ndpiDetectedProtocol.app_protocol, app_category_id,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
	else
	  hp->incPoolStats(tv->tv_sec, srv_host_pool_id, ndpiDetectedProtocol.master_protocol, master_category_id,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
      }

      /* When quotas have to be enforced per pool member, stats must be increased even if cli and srv are on the same pool */
      if(hp->enforceQuotasPerPoolMember(srv_host_pool_id)) {
	srv_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.master_protocol, master_category_id,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
	srv_host->incQuotaEnforcementStats(tv->tv_sec, ndpiDetectedProtocol.app_protocol, app_category_id,
			 diff_rcvd_packets, diff_rcvd_bytes, diff_sent_packets, diff_sent_bytes);
      }
    }
  }
}

#endif

/* *************************************** */

bool Flow::equal(IpAddress *_cli_ip, IpAddress *_srv_ip, u_int16_t _cli_port,
		 u_int16_t _srv_port, u_int16_t _vlanId, u_int8_t _protocol,
		 bool *src2srv_direction) {
  if((_vlanId != vlanId) || (_protocol != protocol)) return(false);

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

void Flow::processJson(bool is_src,
		       json_object *my_object,
		       ProcessInfo *proc) {
  u_int num_id;
  const char *str_id;
  char jsonbuf[64];

  num_id = is_src ? SRC_PROC_PID : DST_PROC_PID;
  str_id = is_src ? "SRC_PROC_PID" : "DST_PROC_PID";
  json_object_object_add(my_object, Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(proc->pid));

  num_id = is_src ? SRC_FATHER_PROC_PID : DST_FATHER_PROC_PID;
  str_id = is_src ? "SRC_FATHER_PROC_PID" : "DST_FATHER_PROC_PID";
  json_object_object_add(my_object, Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(proc->father_pid));

  num_id = is_src ? SRC_PROC_NAME : DST_PROC_NAME;
  str_id = is_src ? "SRC_PROC_NAME" : "DST_PROC_NAME";
  json_object_object_add(my_object, Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_string(proc->name));

  num_id = is_src ? SRC_FATHER_PROC_NAME : DST_FATHER_PROC_NAME;
  str_id = is_src ? "SRC_FATHER_PROC_NAME" : "DST_FATHER_PROC_NAME";
  json_object_object_add(my_object, Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_string(proc->father_name));

  num_id = is_src ? SRC_PROC_USER_NAME : DST_PROC_USER_NAME;
  str_id = is_src ? "SRC_PROC_USER_NAME" : "DST_PROC_USER_NAME";
  json_object_object_add(my_object, Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_string(proc->user_name));

  num_id = is_src ? SRC_PROC_ACTUAL_MEMORY : DST_PROC_ACTUAL_MEMORY;
  str_id = is_src ? "SRC_PROC_ACTUAL_MEMORY" : "DST_PROC_ACTUAL_MEMORY";
  json_object_object_add(my_object, Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(proc->actual_memory));

  num_id = is_src ? SRC_PROC_PEAK_MEMORY : DST_PROC_PEAK_MEMORY;
  str_id = is_src ? "SRC_PROC_PEAK_MEMORY" : "DST_PROC_PEAK_MEMORY";
  json_object_object_add(my_object,
			 Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(proc->peak_memory));

  num_id = is_src ? SRC_PROC_AVERAGE_CPU_LOAD : DST_PROC_AVERAGE_CPU_LOAD;
  str_id = is_src ? "SRC_PROC_AVERAGE_CPU_LOAD" : "DST_PROC_AVERAGE_CPU_LOAD";
  json_object_object_add(my_object, Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_double(proc->average_cpu_load));

  num_id = is_src ? SRC_PROC_NUM_PAGE_FAULTS : DST_PROC_NUM_PAGE_FAULTS;
  str_id = is_src ? "SRC_PROC_NUM_PAGE_FAULTS" : "DST_PROC_NUM_PAGE_FAULTS";
  json_object_object_add(my_object,
			 Utils::jsonLabel(num_id, str_id, jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(proc->num_vm_page_faults));
}

/* *************************************** */

void Flow::processLua(lua_State* vm, ProcessInfo *proc, bool client) {
  Host *src = get_cli_host(), *dst = get_srv_host();

  if((src == NULL) || (dst == NULL)) return;

  lua_newtable(vm);

  lua_push_int_table_entry(vm, "pid", proc->pid);
  lua_push_int_table_entry(vm, "father_pid", proc->father_pid);
  lua_push_str_table_entry(vm, "name", proc->name);
  lua_push_str_table_entry(vm, "father_name", proc->father_name);
  lua_push_str_table_entry(vm, "user_name", proc->user_name);
  lua_push_int_table_entry(vm, "actual_memory", proc->actual_memory);
  lua_push_int_table_entry(vm, "peak_memory", proc->peak_memory);
  lua_push_float_table_entry(vm, "average_cpu_load", proc->average_cpu_load);
  lua_push_float_table_entry(vm, "percentage_iowait_time", proc->percentage_iowait_time);
  lua_push_int_table_entry(vm, "num_vm_page_faults", proc->num_vm_page_faults);

  lua_pushstring(vm, client ? "client_process" : "server_process");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
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
      lua_push_int_table_entry(vm, "cli.vlan", src->get_vlan_id());

    lua_push_int_table_entry(vm, "cli.key", mask_cli_host ? 0 : src->key());
  } else {
    lua_push_nil_table_entry(vm, "cli.ip");
    lua_push_nil_table_entry(vm, "cli.key");
  }
  lua_push_int_table_entry(vm, "cli.port", get_cli_port());

  if(dst) {
    mask_dst_host = Utils::maskHost(dst->isLocalHost());

    lua_push_str_table_entry(vm, "srv.ip",
			     dst->get_ip()->printMask(buf, sizeof(buf),
						      dst->isLocalHost()));

    if(dst->get_vlan_id())
      lua_push_int_table_entry(vm, "srv.vlan", dst->get_vlan_id());

    lua_push_int_table_entry(vm, "srv.key", mask_dst_host ? 0 : dst->key());
  } else {
    lua_push_nil_table_entry(vm, "srv.ip");
    lua_push_nil_table_entry(vm, "srv.key");
  }
  lua_push_int_table_entry(vm, "srv.port", get_srv_port());

  mask_flow = isMaskedFlow(); // mask_cli_host || mask_dst_host;

  lua_push_int_table_entry(vm, "bytes", cli2srv_bytes+srv2cli_bytes);
  lua_push_int_table_entry(vm, "goodput_bytes", cli2srv_goodput_bytes+srv2cli_goodput_bytes);

  if(details_level >= details_high) {
    if(src && !mask_cli_host) {
      lua_push_str_table_entry(vm, "cli.host", src->get_visual_name(buf, sizeof(buf)));
      lua_push_int_table_entry(vm, "cli.source_id", 0 /* was never set by src->getSourceId()*/ );
      lua_push_str_table_entry(vm, "cli.mac", Utils::formatMac(src->get_mac(), buf, sizeof(buf)));

      lua_push_bool_table_entry(vm, "cli.systemhost", src->isSystemHost());
      lua_push_bool_table_entry(vm, "cli.blacklisted", src->isBlacklisted());
      lua_push_bool_table_entry(vm, "cli.allowed_host", src_match);
      lua_push_int32_table_entry(vm, "cli.network_id", src->get_local_network_id());
      lua_push_int_table_entry(vm, "cli.pool_id", src->get_host_pool());
    } else {
      lua_push_nil_table_entry(vm, "cli.host");
    }

    if(dst && !mask_dst_host) {
      lua_push_str_table_entry(vm, "srv.host", dst->get_visual_name(buf, sizeof(buf)));
      lua_push_int_table_entry(vm, "srv.source_id", 0 /* was never set by src->getSourceId() */);
      lua_push_str_table_entry(vm, "srv.mac", Utils::formatMac(dst->get_mac(), buf, sizeof(buf)));
      lua_push_bool_table_entry(vm, "srv.systemhost", dst->isSystemHost());
      lua_push_bool_table_entry(vm, "srv.blacklisted", dst->isBlacklisted());
      lua_push_bool_table_entry(vm, "srv.allowed_host", dst_match);
      lua_push_int32_table_entry(vm, "srv.network_id", dst->get_local_network_id());
      lua_push_int_table_entry(vm, "srv.pool_id", dst->get_host_pool());
    } else {
      lua_push_nil_table_entry(vm, "srv.host");
    }

    if(vrfId) lua_push_int_table_entry(vm, "vrfId", vrfId);
    lua_push_int_table_entry(vm, "vlan", get_vlan_id());
    lua_push_str_table_entry(vm, "proto.l4", get_protocol_name());

    if(((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
       || (ndpiDetectedProtocol.app_protocol != NDPI_PROTOCOL_UNKNOWN)
       || iface->is_ndpi_enabled()
       || iface->isSampledTraffic()
       || iface->is_sprobe_interface()
       || (iface->getIfType() == interface_type_ZMQ)
       || (iface->getIfType() == interface_type_ZC_FLOW)) {
      lua_push_str_table_entry(vm, "proto.ndpi", get_detected_protocol_name(buf, sizeof(buf)));
    } else
      lua_push_str_table_entry(vm, "proto.ndpi", (char*)CONST_TOO_EARLY);

    lua_push_int_table_entry(vm, "proto.ndpi_id", ndpiDetectedProtocol.app_protocol);
    lua_push_str_table_entry(vm, "proto.ndpi_breed", get_protocol_breed_name());

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    if((!mask_flow) && trafficProfile && ntop->getPro()->has_valid_license())
      lua_push_str_table_entry(vm, "profile", trafficProfile->getName());
#endif
#endif

    lua_push_int_table_entry(vm, "bytes.last",
			     get_current_bytes_cli2srv() + get_current_bytes_srv2cli());
    lua_push_int_table_entry(vm, "goodput_bytes",
			     cli2srv_goodput_bytes+srv2cli_goodput_bytes);
    lua_push_int_table_entry(vm, "goodput_bytes.last",
			     get_current_goodput_bytes_cli2srv() + get_current_goodput_bytes_srv2cli());
    lua_push_int_table_entry(vm, "packets", cli2srv_packets+srv2cli_packets);
    lua_push_int_table_entry(vm, "packets.last",
			     get_current_packets_cli2srv() + get_current_packets_srv2cli());
    lua_push_int_table_entry(vm, "seen.first", get_first_seen());
    lua_push_int_table_entry(vm, "seen.last", get_last_seen());
    lua_push_int_table_entry(vm, "duration", get_duration());

    lua_push_int_table_entry(vm, "cli2srv.bytes", cli2srv_bytes);
    lua_push_int_table_entry(vm, "srv2cli.bytes", srv2cli_bytes);
    lua_push_int_table_entry(vm, "cli2srv.goodput_bytes", cli2srv_goodput_bytes);
    lua_push_int_table_entry(vm, "srv2cli.goodput_bytes", srv2cli_goodput_bytes);
    lua_push_int_table_entry(vm, "cli2srv.packets", cli2srv_packets);
    lua_push_int_table_entry(vm, "srv2cli.packets", srv2cli_packets);

    if(isICMP()) {
      lua_newtable(vm);
      lua_push_int_table_entry(vm, "type", protos.icmp.icmp_type);
      lua_push_int_table_entry(vm, "code", protos.icmp.icmp_code);

      lua_pushstring(vm, "icmp");
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }

    lua_push_bool_table_entry(vm, "flow_goodput.low", isLowGoodput());

#ifdef HAVE_NEDGE
    if(iface->is_bridge_interface())
      lua_push_bool_table_entry(vm, "verdict.pass", isPassVerdict() ? (json_bool)1 : (json_bool)0);
#endif

    lua_push_bool_table_entry(vm, "dump.disk", getDumpFlowTraffic());

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

      lua_push_int_table_entry(vm, "cli2srv.retransmissions", tcp_stats_s2d.pktRetr);
      lua_push_int_table_entry(vm, "cli2srv.out_of_order", tcp_stats_s2d.pktOOO);
      lua_push_int_table_entry(vm, "cli2srv.lost", tcp_stats_s2d.pktLost);
      lua_push_int_table_entry(vm, "cli2srv.keep_alive", tcp_stats_s2d.pktKeepAlive);
      lua_push_int_table_entry(vm, "srv2cli.retransmissions", tcp_stats_d2s.pktRetr);
      lua_push_int_table_entry(vm, "srv2cli.out_of_order", tcp_stats_d2s.pktOOO);
      lua_push_int_table_entry(vm, "srv2cli.lost", tcp_stats_d2s.pktLost);
      lua_push_int_table_entry(vm, "srv2cli.keep_alive", tcp_stats_d2s.pktKeepAlive);

      lua_push_int_table_entry(vm, "cli2srv.tcp_flags", src2dst_tcp_flags);
      lua_push_int_table_entry(vm, "srv2cli.tcp_flags", dst2src_tcp_flags);

      lua_push_bool_table_entry(vm, "tcp_established", isEstablished());
    }

    if(!mask_flow) {
      if(host_server_name) lua_push_str_table_entry(vm, "host_server_name", host_server_name);
      if(bt_hash)          lua_push_str_table_entry(vm, "bittorrent_hash", bt_hash);
      lua_push_str_table_entry(vm, "info", getFlowInfo() ? getFlowInfo() : (char*)"");
    }

    if(isHTTP() && protos.http.last_url) {
      lua_push_str_table_entry(vm, "protos.http.last_method", protos.http.last_method);
      lua_push_int_table_entry(vm, "protos.http.last_return_code", protos.http.last_return_code);
    }

#ifdef HAVE_NEDGE
    if(cli_host && srv_host) {
      /* Shapers */
      lua_push_int_table_entry(vm,
			       "shaper.cli2srv_ingress",
			       flowShaperIds.cli2srv.ingress ? flowShaperIds.cli2srv.ingress->get_shaper_id() : DEFAULT_SHAPER_ID);
      lua_push_int_table_entry(vm,
			       "shaper.cli2srv_egress",
			       flowShaperIds.cli2srv.egress ? flowShaperIds.cli2srv.egress->get_shaper_id() : DEFAULT_SHAPER_ID);
      lua_push_int_table_entry(vm,
			       "shaper.srv2cli_ingress",
			       flowShaperIds.srv2cli.ingress ? flowShaperIds.srv2cli.ingress->get_shaper_id() : DEFAULT_SHAPER_ID);
      lua_push_int_table_entry(vm,
			       "shaper.srv2cli_egress",
			       flowShaperIds.srv2cli.egress ? flowShaperIds.srv2cli.egress->get_shaper_id() : DEFAULT_SHAPER_ID);

      /* Quota */
      lua_push_str_table_entry(vm, "cli.quota_applied_proto", (char *)(cli_quota_app_proto ? "app" : "master"));
      lua_push_bool_table_entry(vm, "cli.quota_is_category", cli_quota_is_category);
      lua_push_str_table_entry(vm, "srv.quota_applied_proto", (char *)(srv_quota_app_proto ? "app" : "master"));
      lua_push_bool_table_entry(vm, "srv.quota_is_category", srv_quota_is_category);
    }
#endif

    if(!mask_flow) {
      if(isHTTP() && protos.http.last_url)
	lua_push_str_table_entry(vm, "protos.http.last_url", protos.http.last_url);

      if(host_server_name && (!mask_flow))
	lua_push_str_table_entry(vm, "protos.http.server_name", host_server_name);

      if(isDNS() && protos.dns.last_query)
	lua_push_str_table_entry(vm, "protos.dns.last_query", protos.dns.last_query);

      if(isSSH()) {
	if(protos.ssh.client_signature) lua_push_str_table_entry(vm, "protos.ssh.client_signature", protos.ssh.client_signature);
	if(protos.ssh.server_signature) lua_push_str_table_entry(vm, "protos.ssh.server_signature", protos.ssh.server_signature);
      }

      if(isSSL()) {
	if(protos.ssl.certificate)
	  lua_push_str_table_entry(vm, "protos.ssl.certificate", protos.ssl.certificate);

	if(protos.ssl.server_certificate)
	  lua_push_str_table_entry(vm, "protos.ssl.server_certificate", protos.ssl.server_certificate);
      }
    }

    lua_push_str_table_entry(vm, "moreinfo.json", get_json_info());

    if(client_proc) processLua(vm, client_proc, true);
    if(server_proc) processLua(vm, server_proc, false);

    // overall throughput stats
    lua_push_float_table_entry(vm, "top_throughput_bps",   top_bytes_thpt);
    lua_push_float_table_entry(vm, "throughput_bps",       bytes_thpt);
    lua_push_int_table_entry(vm,   "throughput_trend_bps", bytes_thpt_trend);
    lua_push_float_table_entry(vm, "top_throughput_pps",   top_pkts_thpt);
    lua_push_float_table_entry(vm, "throughput_pps",       pkts_thpt);
    lua_push_int_table_entry(vm,   "throughput_trend_pps", pkts_thpt_trend);

    // throughput stats cli2srv and srv2cli breakdown
    lua_push_float_table_entry(vm, "throughput_cli2srv_bps", bytes_thpt_cli2srv);
    lua_push_float_table_entry(vm, "throughput_srv2cli_bps", bytes_thpt_srv2cli);
    lua_push_float_table_entry(vm, "throughput_cli2srv_pps", pkts_thpt_cli2srv);
    lua_push_float_table_entry(vm, "throughput_srv2cli_pps", pkts_thpt_srv2cli);

    lua_push_int_table_entry(vm, "cli2srv.packets", cli2srv_packets);
    lua_push_int_table_entry(vm, "srv2cli.packets", srv2cli_packets);
    lua_push_int_table_entry(vm, "cli2srv.last", get_current_bytes_cli2srv());
    lua_push_int_table_entry(vm, "srv2cli.last", get_current_bytes_srv2cli());

    /* ********************* */
    dumpPacketStats(vm, true);
    dumpPacketStats(vm, false);

    if((!mask_flow) && (details_level >= details_higher)) {
      float latitude, longitude;
      char buf[32];

      lua_push_int_table_entry(vm, "cli2srv.goodput_bytes.last", get_current_goodput_bytes_cli2srv());
      lua_push_int_table_entry(vm, "srv2cli.goodput_bytes.last", get_current_goodput_bytes_srv2cli());

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
  }

  lua_push_bool_table_entry(vm, "flow.idle", idle_flow);
  lua_push_int_table_entry(vm, "flow.status", getFlowStatus());

  // this is used to dynamicall update entries in the GUI
  lua_push_int_table_entry(vm, "ntopng.key", key()); // Key
}

/* *************************************** */

u_int32_t Flow::key() {
  u_int32_t k = cli_port+srv_port+vlanId+protocol;

  if(cli_host) k += cli_host->key();
  if(srv_host) k += srv_host->key();

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
  if(idle_flow) return(idle_flow);

#ifdef HAVE_NEDGE
  if(iface->getIfType() == interface_type_NETFILTER) {
    if(isNetfilterIdleFlow())
      return(idle_flow = true);
  } else
#endif
    {
      if(!iface->is_purge_idle_interface())
	return(false);

      if(protocol == IPPROTO_TCP) {
	u_int8_t tcp_flags = src2dst_tcp_flags | dst2src_tcp_flags;

	/* If this flow is idle for at least MAX_TCP_FLOW_IDLE */
	if(((tcp_flags & TH_FIN) || (tcp_flags & TH_RST))
	   /* Flows won't expire if less than DONT_NOT_EXPIRE_BEFORE_SEC old */
	   && (doNotExpireBefore >= iface->getTimeLastPktRcvd())
	   && isIdle(MAX_TCP_FLOW_IDLE /* sec */)) {
	  /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "[TCP] Early flow expire"); */
	  return(idle_flow = true);
	}
      }
    }

  return(idle_flow |= isIdle(ntop->getPrefs()->get_flow_max_idle()));
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

void Flow::sumStats(nDPIStats *stats) {
  stats->incStats(0, ndpiDetectedProtocol.app_protocol,
		  cli2srv_packets, cli2srv_bytes,
		  srv2cli_packets, srv2cli_bytes);
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

    if(ntop->getPrefs()->do_dump_flows_on_ls()){
      /*  Add current timestamp differently for Logstash, in case of delay
       *  Note: Logstash generates it's own @timestamp field on input
       */
      json_object_object_add(my_object,"ntop_timestamp",json_object_new_string(buf));
    }

    if(ntop->getPrefs()->do_dump_flows_on_es()){
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

  if(client_proc != NULL) processJson(true, my_object, client_proc);
  if(server_proc != NULL) processJson(false, my_object, server_proc);

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
  if(idle_flow) return(idle_flow);

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
    if(iface->getTimeLastPktRcvd() > (last_conntrack_update+(3*MIN_CONNTRACK_UPDATE)))
      return(idle_flow = true);
  }

  return(false);
}
#endif

/* *************************************** */

void Flow::housekeep() {
#ifdef HAVE_NEDGE
  if(iface->getIfType() == interface_type_NETFILTER) {
    if(isNetfilterIdleFlow()) {
      set_to_purge();
    }
  }
#endif
}

/* *************************************** */

/* https://blogs.akamai.com/2013/09/slow-dos-on-the-rise.html */
bool Flow::isIdleFlow() {
  if(idle_flow) return(idle_flow);

#ifdef HAVE_NEDGE
  if(iface->getIfType() == interface_type_NETFILTER)
    return(isNetfilterIdleFlow());
#endif

  if(iface->getIfType() != interface_type_ZMQ) {
    u_int32_t threshold_ms = CONST_MAX_IDLE_INTERARRIVAL_TIME;
    time_t now = iface->getTimeLastPktRcvd();
    
    if(protocol == IPPROTO_TCP) {
      if(!twh_over) {
	if((synAckTime.tv_sec > 0) /* We have seen SYN|ACK but 3WH is NOT over */
	   && ((now - synAckTime.tv_sec) > CONST_MAX_IDLE_INTERARRIVAL_TIME_NO_TWH_SYN_ACK))
	  return(idle_flow = true); /* The client has not completed the 3WH within the expected time */

	if(synTime.tv_sec > 0) {
	  /* We have seen the beginning of the flow */
	  threshold_ms = CONST_MAX_IDLE_INTERARRIVAL_TIME_NO_TWH;
	  /* We are checking if the 3WH process takes too long and thus if this is a possible attack */
	}
      } else {
	/* The 3WH has been completed */
	if((applLatencyMsec == 0) /* The client has not yet completed the request or
				     the connection is idle after its setup */
	   && (ackTime.tv_sec > 0)
	   && ((now - ackTime.tv_sec) > CONST_MAX_IDLE_NO_DATA_AFTER_ACK))
	  return(idle_flow = true);  /* Connection established and no data exchanged yet */

	else if((getCli2SrvCurrentInterArrivalTime(now) > CONST_MAX_IDLE_INTERARRIVAL_TIME)
		|| ((srv2cli_packets > 0) && (getSrv2CliCurrentInterArrivalTime(now) > CONST_MAX_IDLE_INTERARRIVAL_TIME)))
	  return(idle_flow = true);
	else {
	  switch(ndpi_get_lower_proto(ndpiDetectedProtocol)) {
	  case NDPI_PROTOCOL_SSL:
	    if((protos.ssl.hs_delta_time > CONST_SSL_MAX_DELTA)
	       || (protos.ssl.delta_firstData > CONST_SSL_MAX_DELTA)
	       || (protos.ssl.deltaTime_data > CONST_MAX_SSL_IDLE_TIME)
	       || (getCli2SrvCurrentInterArrivalTime(now) > CONST_MAX_SSL_IDLE_TIME)
	       || ((srv2cli_packets > 0) && getSrv2CliCurrentInterArrivalTime(now) > CONST_MAX_SSL_IDLE_TIME)) {
	      return(idle_flow = true);
	    }
            break;
	  }
	}
      }
    }

    /* Check if there is no traffic for a long time on this flow */
    if((getCli2SrvCurrentInterArrivalTime(now) > threshold_ms)
       || ((srv2cli_packets > 0) && (getSrv2CliCurrentInterArrivalTime(now) > threshold_ms)))
      return(idle_flow = true);
  }

  return(false); /* Not idle */
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
		    u_int8_t *payload, u_int payload_len, u_int8_t l4_proto,
		    const struct timeval *when) {
  payload_len *= iface->getScalingFactor();

  updateSeen();
  updatePacketStats(cli2srv_direction ? &cli2srvStats.pktTime : &srv2cliStats.pktTime, when);

  if((cli_host == NULL) || (srv_host == NULL)) return;

  if(cli2srv_direction) {
    cli2srv_packets++, cli2srv_bytes += pkt_len, cli2srv_goodput_bytes += payload_len;
      cli_host->get_sent_stats()->incStats(pkt_len), srv_host->get_recv_stats()->incStats(pkt_len);
  } else {
    srv2cli_packets++, srv2cli_bytes += pkt_len, srv2cli_goodput_bytes += payload_len;
    cli_host->get_recv_stats()->incStats(pkt_len), srv_host->get_sent_stats()->incStats(pkt_len);
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
			time_t last_seen) {

  /* Don't update seen if no traffic has been observed */
  if((in_pkts == 0) && (out_pkts == 0)) return;

  updateSeen(last_seen);

  if(cli2srv_direction)
    cli2srv_packets += in_pkts, cli2srv_bytes += in_bytes, cli2srv_goodput_bytes += in_goodput_bytes,
      srv2cli_packets += out_pkts, srv2cli_bytes += out_bytes, srv2cli_goodput_bytes += out_goodput_bytes;
  else
    cli2srv_packets += out_pkts, cli2srv_bytes += out_bytes, cli2srv_goodput_bytes += out_goodput_bytes,
      srv2cli_packets += in_pkts, srv2cli_bytes += in_bytes, srv2cli_goodput_bytes += in_goodput_bytes;

  if(bytes_thpt == 0 && last_seen >= first_seen + 1) {
    /* Do a fist estimation while waiting for the periodic activities */
    bytes_thpt = (cli2srv_bytes + srv2cli_bytes) / (float)(last_seen - first_seen),
      pkts_thpt = (cli2srv_packets + srv2cli_packets) / (float)(last_seen - first_seen);
  }
}

/* *************************************** */

void Flow::updateTcpFlags(const struct bpf_timeval *when,
			  u_int8_t flags, bool src2dst_direction) {
  iface->incFlagsStats(flags);
  if(cli_host) cli_host->incFlagStats(src2dst_direction, flags);
  if(srv_host) srv_host->incFlagStats(!src2dst_direction, flags);

  if(flags == TH_SYN) {
    if(cli_host) cli_host->updateSynFlags(when->tv_sec, flags, this, true);
    if(srv_host) srv_host->updateSynFlags(when->tv_sec, flags, this, false);
    state = flow_state_syn;
  } else if(flags & TH_RST)
    state = flow_state_rst;
  else if(flags & TH_FIN)
    state = flow_state_fin;
  else
    state = flow_state_established;

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

	rttSec = ((float)(serverNwLatency.tv_sec+clientNwLatency.tv_sec))
	  +((float)(serverNwLatency.tv_usec+clientNwLatency.tv_usec))/(float)1000000;
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
				u_int32_t lost_pkts) {
#ifdef HAVE_NEDGE
  return;
#endif

  TCPPacketStats * stats;
  /*Host * host;*/

  if(src2dst_direction) {
    stats = &tcp_stats_s2d;
    /*host = cli_host;*/
  } else {
    stats = &tcp_stats_d2s;
    /*host = srv_host;*/
  }

  stats->pktRetr += retr_pkts;
  stats->pktOOO += ooo_pkts;
  stats->pktLost += lost_pkts;

  /*host->incRetransmittedPkts(retr_pkts);
  host->incOOOPkts(ooo_pkts);
  host->incLostPkts(lost_pkts);

  iface->incRetransmittedPkts(retr_pkts);
  iface->incOOOPkts(ooo_pkts);
  iface->incLostPkts(lost_pkts);*/
}

/* *************************************** */

void Flow::updateTcpSeqNum(const struct bpf_timeval *when,
			   u_int32_t seq_num, u_int32_t ack_seq_num,
			   u_int16_t window, u_int8_t flags,
			   u_int16_t payload_Len, bool src2dst_direction) {
  u_int32_t next_seq_num;
  bool update_last_seqnum = true;
  bool debug = false;

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
	  tcp_stats_s2d.pktKeepAlive++, cli_host->incKeepAlivePkts(1);
	} else if(tcp_stats_s2d.last == seq_num) {
	  tcp_stats_s2d.pktRetr++, cli_host->incRetransmittedPkts(1), iface->incRetransmittedPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet retransmission");
	} else if((tcp_stats_s2d.last > seq_num)
		  && (seq_num < tcp_stats_s2d.next)) {
	  tcp_stats_s2d.pktLost++, cli_host->incLostPkts(1), iface->incLostPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[src2dst] Packet lost [last: %u][act: %u]", tcp_stats_s2d.last, seq_num);
	} else {
	  tcp_stats_s2d.pktOOO++, cli_host->incOOOPkts(1), iface->incOOOPkts(1);

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
	  tcp_stats_d2s.pktKeepAlive++, srv_host->incKeepAlivePkts(1);
	} else if(tcp_stats_d2s.last == seq_num) {
	  tcp_stats_d2s.pktRetr++, srv_host->incRetransmittedPkts(1), iface->incRetransmittedPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet retransmission");
	  // bytes
	} else if((tcp_stats_d2s.last > seq_num)
		  && (seq_num < tcp_stats_d2s.next)) {
	  tcp_stats_d2s.pktLost++, srv_host->incLostPkts(1), iface->incLostPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet lost [last: %u][act: %u]", tcp_stats_d2s.last, seq_num);
	} else {
	  tcp_stats_d2s.pktOOO++, srv_host->incOOOPkts(1), iface->incOOOPkts(1);
	  update_last_seqnum = ((seq_num - 1) > tcp_stats_d2s.last) ? true : false;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] [last: %u][next: %u]", tcp_stats_d2s.last, tcp_stats_d2s.next);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[dst2src] Packet OOO [last: %u][act: %u]", tcp_stats_d2s.last, seq_num);
	}
      }
    }

    tcp_stats_d2s.next = next_seq_num;
    if(update_last_seqnum) tcp_stats_d2s.last = seq_num;
  }
}

/* *************************************** */

void Flow::handle_process(ProcessInfo *pinfo, bool client_process) {
  ProcessInfo *proc;

  if(pinfo->pid == 0) return;

  if(client_process) {
    if(client_proc)
      memcpy(client_proc, pinfo, sizeof(ProcessInfo));
    else {
      if((proc = new ProcessInfo) == NULL) return;
      memcpy(proc, pinfo, sizeof(ProcessInfo));
      client_proc = proc, cli_host->setSystemHost(); /* Outgoing */
    }
  } else {
    if(server_proc)
      memcpy(server_proc, pinfo, sizeof(ProcessInfo));
    else {
      if((proc = new ProcessInfo) == NULL) return;
      memcpy(proc, pinfo, sizeof(ProcessInfo));
      server_proc = proc, srv_host->setSystemHost();  /* Incoming */
    }
  }
}

/* *************************************** */

u_int32_t Flow::getPid(bool client) {
  ProcessInfo *proc = client ? client_proc : server_proc;

  return((proc == NULL) ? 0 : proc->pid);
};

/* *************************************** */

u_int32_t Flow::getFatherPid(bool client) {
  ProcessInfo *proc = client ? client_proc : server_proc;

  return((proc == NULL) ? 0 : proc->father_pid);
};

/* *************************************** */

char* Flow::get_username(bool client) {
  ProcessInfo *proc = client ? client_proc : server_proc;

  return((proc == NULL) ? NULL : proc->user_name);
};

/* *************************************** */

char* Flow::get_proc_name(bool client) {
  ProcessInfo *proc = client ? client_proc : server_proc;

  return((proc == NULL) ? NULL : proc->name);
};

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

  if(src2dst_direction) {
    char *space;

    // payload[10]=0; ntop->getTrace()->traceEvent(TRACE_WARNING, "[len: %u][%s]", payload_len, payload);
    h = cli_host->getHTTPstats(); if(h) h->incRequestAsSender(payload); /* Sent */
    h = srv_host->getHTTPstats(); if(h) h->incRequestAsReceiver(payload); /* Rcvd */
    dissect_next_http_packet = true;

    /* use memchr to prevent possibly non-NULL terminated HTTP requests */
    if(payload && ((space = (char*)memchr(payload, ' ', payload_len)) != NULL)) {
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
	  if((protos.http.last_url = (char*)malloc(l + 1)) != NULL) {
	    strncpy(protos.http.last_url, payload, l);
	    protos.http.last_url[l] = '\0';
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
    bool device_info = false;
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
	  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "===>>> [%d] %s", i, &payload[i-12]);
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
      device_info = true;
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
	cli_host->setName(name); /* See (**) */

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
		  if(device_info) {
		    /* Overrite only if model is empty */
		    if(mac->getModel() == NULL)
		      mac->setModel((char*)model);
		  } else
		    mac->setModel((char*)model);
		}
	      }

	      if(strncmp(txt_buf, "nm=", 3) == 0) {
		if(cli_host) cli_host->setName(&txt_buf[3]);
	      }

	      if(strncmp(txt_buf, "ssid=", 3) == 0) {
		if(cli_host && cli_host->getMac())
		  cli_host->getMac()->setSSID(&txt_buf[5]);
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
	if(cli_host) cli_host->setSSDPLocation(url);
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

bool Flow::dumpFlowTraffic() {
  if(dump_flow_traffic) return true;
  if(cli_host && srv_host)
    return(cli_host->dumpHostTraffic() || srv_host->dumpHostTraffic());
  return(false);
}

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
  u_int16_t old_cli2srv_in = cli2srv_in,
    old_cli2srv_out = cli2srv_out,
    old_srv2cli_in = srv2cli_in,
    old_srv2cli_out = srv2cli_out;

  /* Check if this application protocol is allowd for the specified device type */
  if(cli_host && srv_host && cli_host->getMac() && srv_host->getMac()) {
    DeviceProtocolBitmask *cli = ntop->getDeviceAllowedProtocols(cli_host->getMac()->getDeviceType());
    DeviceProtocolBitmask *srv = ntop->getDeviceAllowedProtocols(srv_host->getMac()->getDeviceType());

    if(
       ((ndpiDetectedProtocol.master_protocol != NDPI_PROTOCOL_UNKNOWN)
	&& ((!NDPI_ISSET(&cli->clientAllowed, ndpiDetectedProtocol.master_protocol))
	    || (!NDPI_ISSET(&srv->serverAllowed, ndpiDetectedProtocol.master_protocol))))
       ||
       /* We consider NDPI_PROTOCOL_UNKNOWN as a protocol to be allowed */
       (((!NDPI_ISSET(&cli->clientAllowed, ndpiDetectedProtocol.app_protocol))
	 || (!NDPI_ISSET(&srv->serverAllowed, ndpiDetectedProtocol.app_protocol))))
       )
      passVerdict = false;
  }

  /* Re-compute the verdict */
  cli2srv_verdict = updateDirectionShapers(true, &flowShaperIds.cli2srv.ingress, &flowShaperIds.cli2srv.egress);
  srv2cli_verdict = updateDirectionShapers(false, &flowShaperIds.srv2cli.ingress, &flowShaperIds.srv2cli.egress);
  passVerdict = (cli2srv_verdict && srv2cli_verdict);

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
    /* Make sure the overall cross-application quota is not crossed */
    if((above_quota = cli_host->checkCrossApplicationQuota()))
      cli_quota_app_proto = true; /* TODO: make this more invormative, possibly use a struct */
    else if((above_quota = srv_host->checkCrossApplicationQuota()))
      srv_quota_app_proto = true;
    /* Now it is time to check */
    else if((above_quota = cli_host->checkQuota(ndpiDetectedProtocol.app_protocol, &cli_quota_is_category, now)))
      cli_quota_app_proto = true;
    else if((above_quota = cli_host->checkQuota(ndpiDetectedProtocol.master_protocol, &cli_quota_is_category, now)))
      cli_quota_app_proto = false;
    else if((above_quota = srv_host->checkQuota(ndpiDetectedProtocol.app_protocol, &srv_quota_is_category, now)))
      srv_quota_app_proto = true;
    else if((above_quota = srv_host->checkQuota(ndpiDetectedProtocol.master_protocol, &srv_quota_is_category, now)))
      srv_quota_app_proto = false;
  }

#ifdef SHAPER_DEBUG
  char buf[256];
  if(above_quota) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "AFTER: [cli_quota_app_proto: %u][srv_quota_app_proto: %u] %s",
				 cli_quota_app_proto ? 1 : 0,
				 srv_quota_app_proto  ? 1 : 0,
				 print(buf, sizeof(buf)));
  }
#endif

  quota_exceeded = above_quota;
}

#endif

/* *************************************** */

bool Flow::isSuspiciousFlowThpt() {
#ifndef HAVE_NEDGE
  if(protocol == IPPROTO_TCP) {
    float compareTime = Utils::timeval2ms(&clientNwLatency)*1.5;

    if(cli2srv_direction && isLowGoodput()) {
      if((cli2srvStats.pktTime.min_ms > compareTime)
	 || ((ndpi_get_lower_proto(ndpiDetectedProtocol) == NDPI_PROTOCOL_HTTP)
	     && (cli2srvStats.pktTime.min_ms > CONST_MAX_IDLE_PKT_TIME))
	 || (cli2srvStats.pktTime.min_ms > CONST_MAX_IDLE_FLOW_TIME)
	 )
	return(true);
    }
  }
#endif // HAVE_NEDGE

  return(false);
}

/* *************************************** */

bool Flow::isLowGoodput() {
#ifdef HAVE_NEDGE
  return(false);
#else
  if(protocol == IPPROTO_UDP)
    return(false);
  else
    return((((get_goodput_bytes()*100)/(get_bytes()+1 /* avoid zero divisions */)) < FLOW_GOODPUT_THRESHOLD) ? true : false);
#endif // HAVE_NEDGE
}

/* *************************************** */

void Flow::dissectSSL(u_int8_t *payload, u_int16_t payload_len, const struct bpf_timeval *when, bool cli2srv) {
  uint16_t skiphello;
  bool hs_now_end = false;

  if(good_ssl_hs && twh_over && payload_len >= SSL_MIN_PACKET_SIZE) {
    if((cli2srv && (getSSLEncryptionStatus() & SSL_ENCRYPTION_CLIENT)) ||
       (!cli2srv && (getSSLEncryptionStatus() & SSL_ENCRYPTION_SERVER)) ) {
      protos.ssl.is_data = true;

      if(!protos.ssl.firstdata_seen) {
	if(getSSLEncryptionStatus() == SSL_ENCRYPTION_BOTH) {
	  memcpy(&protos.ssl.lastdata_time, when, sizeof(struct timeval));
	  protos.ssl.delta_firstData = ((float)(Utils::timeval2usec(&protos.ssl.lastdata_time)
						- Utils::timeval2usec(&protos.ssl.hs_end_time)))/1000;
	  ntop->getTrace()->traceEvent(TRACE_DEBUG, "[%p][%u.%u] SSL first (full) data: %u",
				       this, when->tv_sec, when->tv_usec, payload_len);
	  protos.ssl.firstdata_seen = true;
	}
      } else {
	protos.ssl.deltaTime_data = ((float)(Utils::timeval2usec((struct timeval*)when)
					     - Utils::timeval2usec(&protos.ssl.lastdata_time)))/1000;
	memcpy(&protos.ssl.lastdata_time, when, sizeof(struct timeval));
      }
    } else {
      protos.ssl.is_data = false;

      if(payload[0] == SSL_HANDSHAKE_PACKET) {
	if(payload[5] == SSL_CLIENT_HELLO) {
	  if(protos.ssl.cli_stage == SSL_STAGE_UNKNOWN) {
	    memcpy(&protos.ssl.clienthello_time, when, sizeof(struct timeval));
	    protos.ssl.cli_stage = SSL_STAGE_HELLO;
	  }
	} else if((payload[5] == SSL_SERVER_HELLO)
		  && (protos.ssl.srv_stage == SSL_STAGE_UNKNOWN)
		  && (protos.ssl.cli_stage == SSL_STAGE_HELLO)) {
	  skiphello = 5 + 4 + ntohs(get_u_int16_t(payload, 7));

	  if((payload_len > skiphello)
	     && (payload[skiphello] == SSL_SERVER_CHANGE_CIPHER_SPEC)) {
	      protos.ssl.srv_stage = SSL_STAGE_CCS;
	      // here client encryption is still plain
	    } else {
	      protos.ssl.srv_stage = SSL_STAGE_HELLO;
	    }
	} else if((payload[5] == SSL_CLIENT_KEY_EXCHANGE)
		  && (protos.ssl.cli_stage == SSL_STAGE_HELLO)) {
	  protos.ssl.cli_stage = SSL_STAGE_CCS;

	  if(getSSLEncryptionStatus() == SSL_ENCRYPTION_BOTH)
	    hs_now_end = true;
	} else if((payload[5] == SSL_NEW_SESSION_TICKET)
		  && (protos.ssl.srv_stage == SSL_STAGE_HELLO)) {
	  protos.ssl.srv_stage = SSL_STAGE_CCS;

	  if(getSSLEncryptionStatus() == SSL_ENCRYPTION_BOTH)
	    hs_now_end = true;
	}
      } else if((payload[0] == SSL_SERVER_CHANGE_CIPHER_SPEC)
		&& (protos.ssl.srv_stage == SSL_STAGE_HELLO)) {
	protos.ssl.srv_stage = SSL_STAGE_CCS;
	if(getSSLEncryptionStatus() == SSL_ENCRYPTION_BOTH)
	    hs_now_end = true;
      }

      if(hs_now_end) {
	// both client and server CCS appeared here
	memcpy(&protos.ssl.hs_end_time, when, sizeof(struct timeval));
	protos.ssl.hs_delta_time = ((float)(Utils::timeval2usec(&protos.ssl.hs_end_time)
					    - Utils::timeval2usec(&protos.ssl.clienthello_time)))/1000;
      }

      protos.ssl.hs_packets++;
      good_ssl_hs &= protos.ssl.hs_packets <= SSL_MAX_HANDSHAKE_PCKS;
    }
  }
}

/* ***************************************************** */

FlowSSLEncryptionStatus Flow::getSSLEncryptionStatus() {
  if(isSSLProto()) {
    return(FlowSSLEncryptionStatus)(
				    ((protos.ssl.srv_stage == SSL_STAGE_CCS) << 0) |
				    ((protos.ssl.cli_stage == SSL_STAGE_CCS) << 1)
				    );
  }

  return SSL_ENCRYPTION_PLAIN;
}

/* ***************************************************** */

FlowStatus Flow::getFlowStatus() {
#ifndef HAVE_NEDGE
  u_int32_t threshold;
#endif
  u_int16_t l7proto = ndpi_get_lower_proto(ndpiDetectedProtocol);

#ifdef HAVE_NEDGE
  if(iface->is_bridge_interface() && !isPassVerdict())
    return status_blocked;
#endif

  if(isBlacklistedFlow())
    return status_blacklisted;

  if(ndpiDetectedProtocol.category == CUSTOM_CATEGORY_MINING)
    return status_web_mining_detected;

#ifndef HAVE_NEDGE
  /* All flows */
  threshold = cli2srv_packets / CONST_TCP_CHECK_ISSUES_RATIO;
  if((tcp_stats_s2d.pktRetr + tcp_stats_s2d.pktOOO + tcp_stats_s2d.pktLost) > threshold)
    return status_tcp_connection_issues;

  threshold = srv2cli_packets / CONST_TCP_CHECK_ISSUES_RATIO;
  if((tcp_stats_d2s.pktRetr + tcp_stats_d2s.pktOOO + tcp_stats_d2s.pktLost) > threshold)
    return status_tcp_connection_issues;
#endif

  if(iface->getIfType() == interface_type_ZMQ) {
    /* ZMQ flows */
  } else {
    /* Packet flows */
    bool isIdle = isIdleFlow();

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
#ifndef HAVE_NEDGE
	  if(!protos.ssl.firstdata_seen && isIdle)
	    return status_slow_application_header;
#endif

	  if(protos.ssl.certificate && protos.ssl.server_certificate) {
	    if(protos.ssl.server_certificate[0] == '*') {
	      if(!strstr(protos.ssl.certificate, &protos.ssl.server_certificate[1]))
		return status_ssl_certificate_mismatch;
	    } else if(strcmp(protos.ssl.certificate, protos.ssl.server_certificate))
	      return status_ssl_certificate_mismatch;
	  }
	  break;

#ifndef HAVE_NEDGE
	case NDPI_PROTOCOL_HTTP:
	  if(/* !header_HTTP_completed &&*/isIdle)
	    return status_slow_application_header;
	  break;
	}

	if(isIdle  && lowGoodput)  return status_slow_data_exchange;
	if(isIdle  && !lowGoodput) return status_slow_tcp_connection;

	if(!isIdle && lowGoodput) {
	  if((src2dst_tcp_flags & TH_SYN) && (dst2src_tcp_flags & TH_RST))
	    return status_tcp_connection_refused;
	  else
	    return status_low_goodput;
	}
#else
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

  if(cli_host && ! cli_host->isLocalHost() && srv_host && ! srv_host->isLocalHost()
     && ! cli_host->get_ip()->isBroadcastAddress()
     && ! srv_host->get_ip()->isBroadcastAddress()
     && ! cli_host->get_ip()->isMulticastAddress()
     && ! srv_host->get_ip()->isMulticastAddress())
    return status_remote_to_remote;

#if 0
  if(iface->getAlertLevel() > 0)
   return(status_flow_when_interface_alerted);
#endif

  return status_normal;
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

void Flow::fixAggregatedFlowFields() {
  ndpiDetectedProtocol.master_protocol = ntohs(cli_port),
    ndpiDetectedProtocol.app_protocol = ntohs(srv_port);
  cli_port = srv_port = 0;
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

  iface->_incStats(isIngress2EgressDirection(), now, eth_proto, ndpiDetectedProtocol.app_protocol,
		   nf_existing_flow ? s2d_bytes - cli2srv_bytes : s2d_bytes,
		   nf_existing_flow ? s2d_pkts - cli2srv_packets : s2d_pkts,
		   overhead);

  iface->_incStats(!isIngress2EgressDirection(), now, eth_proto, ndpiDetectedProtocol.app_protocol,
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

void Flow::addPacketToDump(const struct pcap_pkthdr *h, const u_char *packet) {
  BufferedPacket *b = (BufferedPacket*)malloc(sizeof(BufferedPacket));

  if(b) {
    memcpy((void*)&b->h, (void*)h, sizeof(struct pcap_pkthdr));
    b->packet = (u_char*)malloc(h->caplen);

    if(!b->packet) {
      free(b);
      return;
    }

    memcpy(b->packet, packet, h->caplen);
    b->next = NULL;

    if(flow_packets_tail == NULL) {
      flow_packets_head = flow_packets_tail = b;
    } else {
      flow_packets_tail->next = b;
      flow_packets_tail = b;
    }
  }
}

/* ***************************************************** */

/* NOTE: only for unknown protocol flows */
void Flow::flushBufferedPackets() {
  if(iface->do_dump_unknown_traffic()
     && flow_packets_head
     && (get_detected_protocol().app_protocol == NDPI_PROTOCOL_UNKNOWN)
    ) {
    bool do_dump_to_disk = true;

    if(protocol == IPPROTO_TCP) {
      u_int8_t mask = TH_SYN | TH_ACK | TH_PUSH;

      /* Initial bytes are in and some data is present */
      if((getTcpFlags() & mask) == mask)
	do_dump_to_disk = true;
      else
	do_dump_to_disk = false; /* Initial flow bytes are missing */
    } else
      do_dump_to_disk = true;

    if(do_dump_to_disk) {
      char pcap_path[MAX_PATH], hour_path[64];
      time_t when = flow_packets_head->h.ts.tv_sec;
      pcap_dumper_t *dumper;
      char buf1[32], buf2[32];

      when -= when % 3600; /* Hourly directories */
      strftime(hour_path, sizeof(hour_path), "%Y/%m/%d/%H", localtime(&when));
      snprintf(pcap_path, sizeof(pcap_path), "%s/%d/pcap/ndpi_unknown/%s/",
	       ntop->get_working_dir(), iface->get_id(), hour_path);
      ntop->fixPath(pcap_path);
      Utils::mkdir_tree(pcap_path);

      snprintf(pcap_path, sizeof(pcap_path), "%s/%d/pcap/ndpi_unknown/%s/%s:%u_%s:%u_%u.pcap",
	       ntop->get_working_dir(), iface->get_id(), hour_path,
	       cli_host->get_ip()->print(buf1, sizeof(buf1)), ntohs(cli_port),
	       srv_host->get_ip()->print(buf2, sizeof(buf2)), ntohs(srv_port),
	       (unsigned int)flow_packets_head->h.ts.tv_sec
	);

      if((dumper = pcap_dump_open(pcap_open_dead(iface->get_datalink(),
						 16384 /* MTU */), pcap_path)) == NULL)
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create pcap file %s", pcap_path);
      else {
	u_int num_pkts = 0;
	PacketDumper *pkt_dumper;

	while(flow_packets_head) {
	  struct buffered_packet *tmp;

	  pcap_dump((u_char*)dumper, &(flow_packets_head->h), flow_packets_head->packet);
	  free(flow_packets_head->packet);
	  tmp = flow_packets_head;
	  flow_packets_head = flow_packets_head->next;
	  free(tmp);
	  num_pkts++;
	}

	pcap_dump_close(dumper);
	ntop->getTrace()->traceEvent(TRACE_INFO, "Dumped %u packets onto file %s", num_pkts, pcap_path);

	pkt_dumper = iface->getPacketDumper();
	if(pkt_dumper) pkt_dumper->incUnknownPacketDump(num_pkts);
      }
    }
  }

  /* Even if we do not dump this flow, packets needs to be freed */
  while(flow_packets_head) {
    struct buffered_packet *tmp;

    free(flow_packets_head->packet);
    tmp = flow_packets_head;
    flow_packets_head = flow_packets_head->next;
    free(tmp);
  }
}
