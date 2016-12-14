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

Flow::Flow(NetworkInterface *_iface,
	   u_int16_t _vlanId, u_int8_t _protocol,
	   u_int8_t cli_mac[6], IpAddress *_cli_ip, u_int16_t _cli_port,
	   u_int8_t srv_mac[6], IpAddress *_srv_ip, u_int16_t _srv_port,
	   time_t _first_seen, time_t _last_seen) : GenericHashEntry(_iface) {
  vlanId = _vlanId, protocol = _protocol, cli_port = _cli_port, srv_port = _srv_port;
  cli2srv_packets = 0, cli2srv_bytes = 0, cli2srv_goodput_bytes = 0,
    srv2cli_packets = 0, srv2cli_bytes = 0, srv2cli_goodput_bytes = 0,
    cli2srv_last_packets = 0, cli2srv_last_bytes = 0, srv2cli_last_packets = 0, srv2cli_last_bytes = 0,
    cli_host = srv_host = NULL, badFlow = false, good_low_flow_detected = false, state = flow_state_other,
    srv2cli_last_goodput_bytes = cli2srv_last_goodput_bytes = 0, good_ssl_hs = true,
    flow_alerted = false;

  l7_protocol_guessed = detection_completed = false;
  dump_flow_traffic = false,
    ndpiDetectedProtocol.protocol = NDPI_PROTOCOL_UNKNOWN,
    ndpiDetectedProtocol.master_protocol = NDPI_PROTOCOL_UNKNOWN,
    doNotExpireBefore = iface->getTimeLastPktRcvd() + 30 /* sec */;

  memset(&cli2srvStats, 0, sizeof(cli2srvStats)), memset(&srv2cliStats, 0, sizeof(srv2cliStats));

  if(ntop->getPrefs()->is_flow_activity_enabled()){
    if((activityDetection = (FlowActivityDetection*)calloc(1, sizeof(FlowActivityDetection))) == NULL)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory for flow activity detection");
  } else {
    activityDetection = NULL;
  }

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
  top_bytes_thpt = 0, top_goodput_bytes_thpt = 0, applLatencyMsec = 0;

  last_db_dump.cli2srv_packets = 0, last_db_dump.srv2cli_packets = 0,
    last_db_dump.cli2srv_bytes = 0, last_db_dump.srv2cli_bytes = 0,
    last_db_dump.cli2srv_goodput_bytes = 0, last_db_dump.srv2cli_goodput_bytes = 0,
    last_db_dump.last_dump = 0;

  memset(&protos, 0, sizeof(protos));

  iface->findFlowHosts(_vlanId, cli_mac, _cli_ip, &cli_host, srv_mac, _srv_ip, &srv_host);
  if(cli_host) { cli_host->incUses(); cli_host->incNumFlows(true); }
  if(srv_host) { srv_host->incUses(); srv_host->incNumFlows(false); }
  passVerdict = true, categorization.categorized_requested = false;
  if(_first_seen > _last_seen) _first_seen = _last_seen;
  first_seen = _first_seen, last_seen = _last_seen;
  memset(&categorization.category, 0, sizeof(categorization.category));
  bytes_thpt_trend = trend_unknown, pkts_thpt_trend = trend_unknown;
  //bytes_rate = new TimeSeries<float>(4096);
  protocol_processed = false, blacklist_alarm_emitted = false;

  synTime.tv_sec = synTime.tv_usec = 0,
    ackTime.tv_sec = ackTime.tv_usec = 0,
    synAckTime.tv_sec = synAckTime.tv_usec = 0,
    rttSec = 0, cli2srv_window= srv2cli_window = 0,
    c2sFirstGoodputTime.tv_sec = c2sFirstGoodputTime.tv_usec = 0;
  memset(&tcp_stats_s2d, 0, sizeof(tcp_stats_s2d)), memset(&tcp_stats_d2s, 0, sizeof(tcp_stats_d2s));
  memset(&clientNwLatency, 0, sizeof(clientNwLatency)), memset(&serverNwLatency, 0, sizeof(serverNwLatency));

  if(!iface->isPacketInterface())
    last_update_time.tv_sec = (long)first_seen;

#ifdef NTOPNG_PRO
  trafficProfile = NULL;
  flowShaperIds.cli2srv.ingress = flowShaperIds.cli2srv.egress = flowShaperIds.srv2cli.ingress = flowShaperIds.srv2cli.egress = DEFAULT_SHAPER_ID;
#endif

  iface->luaEvalFlow(this, callback_flow_create);

  switch(protocol) {
  case IPPROTO_TCP:
  case IPPROTO_UDP:
    if(iface->is_ndpi_enabled() && (!iface->isSampledTraffic()))
      allocDPIMemory();
    break;

  case IPPROTO_ICMP:
    ndpiDetectedProtocol.protocol = NDPI_PROTOCOL_IP_ICMP,
      ndpiDetectedProtocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;
    setDetectedProtocol(ndpiDetectedProtocol, true);
    break;

  case IPPROTO_ICMPV6:
    ndpiDetectedProtocol.protocol = NDPI_PROTOCOL_IP_ICMPV6,
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

void Flow::categorizeFlow() {
  bool toRequest = false, toQuery = false;
  char *what;

  switch(ndpi_get_lower_proto(ndpiDetectedProtocol)) {
    /* case NDPI_PROTOCOL_DNS: */
  case NDPI_PROTOCOL_SSL:
  case NDPI_PROTOCOL_HTTP:
  case NDPI_PROTOCOL_HTTP_PROXY:
    break;

  default:
    return;
  }

  what = (isSSL() && protos.ssl.certificate) ? protos.ssl.certificate : host_server_name;

  if((what == NULL)
     || (what[0] == '\0')
     || (!strchr(what, '.'))
     || strstr(what, ".arpa")
     || (strlen(what) < 4)
     )
    return;

  if(!categorization.categorized_requested)
    categorization.categorized_requested = true, toRequest = true, toQuery = true;
  else if(categorization.category.categories[0] == NTOP_UNKNOWN_CATEGORY_ID)
    toRequest = true;

  if(toRequest) {
    if(ntop->get_flashstart()->findCategory(Utils::get2ndLevelDomain(what),
					    &categorization.category,
					    toQuery))
      checkFlowCategory();
  }
}

/* *************************************** */

Flow::~Flow() {
  struct timeval tv = { 0, 0 };
 
  if(good_low_flow_detected) {
    if(cli_host) cli_host->decLowGoodputFlows(true);
    if(srv_host) srv_host->decLowGoodputFlows(false);
  }

  checkBlacklistedFlow();
  update_hosts_stats(&tv, true);
  dumpFlow(true /* Dump only the last part of the flow */);

  iface->luaEvalFlow(this, callback_flow_delete);

  if(cli_host)         { cli_host->decUses(); cli_host->decNumFlows(true);  }
  if(srv_host)         { srv_host->decUses(); srv_host->decNumFlows(false); }
  if(json_info)        free(json_info);
  if(client_proc)      delete(client_proc);
  if(server_proc)      delete(server_proc);
  if(host_server_name) free(host_server_name);
  if(activityDetection)free(activityDetection);

  if(isHTTP()) {
    if(protos.http.last_method) free(protos.http.last_method);
    if(protos.http.last_url)    free(protos.http.last_url);
    if(protos.http.last_content_type) free(protos.http.last_content_type);
  } else if(isDNS()) {
    if(protos.dns.last_query)   free(protos.dns.last_query);
  } else if(isSSL()) {
    if(protos.ssl.certificate)  free(protos.ssl.certificate);
  }

  if(bt_hash)          free(bt_hash);

  freeDPIMemory();
}

/* *************************************** */

void Flow::dumpFlowAlert(bool partial_dump) {
    FlowStatus status = getFlowStatus();
  
    if(status != status_normal) {
	char buf[128], *f;

	f = print(buf, sizeof(buf));

	ntop->getTrace()->traceEvent(TRACE_INFO, "[%s] %s",
				     Utils::flowstatus2str(status), f);

	if(ntop->getRuntimePrefs()->are_probing_alerts_enabled()
	   && cli_host && srv_host) {
	    switch(status) {
	    case status_suspicious_tcp_probing:
	    case status_suspicious_tcp_syn_probing:
		char c_buf[256], s_buf[256], *c, *s, fbuf[256], alert_msg[1024];

		c = cli_host->get_ip()->print(c_buf, sizeof(c_buf));
		if(c && cli_host->get_vlan_id())
		    sprintf(&c[strlen(c)], "@%i", cli_host->get_vlan_id());

		s = srv_host->get_ip()->print(s_buf, sizeof(s_buf));
		if(s && srv_host->get_vlan_id())
		    sprintf(&s[strlen(s)], "@%i", srv_host->get_vlan_id());

		snprintf(alert_msg, sizeof(alert_msg),
			 "%s: <A HREF='%s/lua/host_details.lua?host=%s&ifname=%s&page=alerts'>%s</A> &gt; "
			 "<A HREF='%s/lua/host_details.lua?host=%s&ifname=%s&page=alerts'>%s</A> [%s]",
			 "Probing or server down",
			 ntop->getPrefs()->get_http_prefix(),
			 c, iface->get_name(),
			 cli_host->get_name() ? cli_host->get_name() : c,
			 ntop->getPrefs()->get_http_prefix(),
			 s, iface->get_name(),
			 srv_host->get_name() ? srv_host->get_name() : s,
			 print(fbuf, sizeof(fbuf)));

		iface->getAlertsManager()->storeFlowAlert(this,
							  alert_suspicious_activity,
							  alert_level_warning,
							  alert_msg);
		break;

	    default:
		/* Nothing to do */
		break;
	    }
	}
    }
}
    
/* *************************************** */

void Flow::checkBlacklistedFlow() {
  if(!blacklist_alarm_emitted) {
    if(cli_host
       && srv_host
       && (cli_host->is_blacklisted()
	   || srv_host->is_blacklisted())) {
      char c_buf[64], s_buf[64], *c, *s, fbuf[256], alert_msg[1024];

      c = cli_host->get_ip()->print(c_buf, sizeof(c_buf));
      if(c && cli_host->get_vlan_id())
	sprintf(&c[strlen(c)], "@%i", cli_host->get_vlan_id());

      s = srv_host->get_ip()->print(s_buf, sizeof(s_buf));
      if(s && srv_host->get_vlan_id())
	sprintf(&s[strlen(s)], "@%i", srv_host->get_vlan_id());

      snprintf(alert_msg, sizeof(alert_msg),
	       "%s <A HREF='%s/lua/host_details.lua?host=%s&ifname=%s&page=alerts'>%s</A> contacted %s host "
	       "<A HREF='%s/lua/host_details.lua?host=%s&ifname=%s&page=alerts'>%s</A> [%s]",
	       ntop->getPrefs()->get_http_prefix(),
	       cli_host->is_blacklisted() ? "Blacklisted host" : "Host",
	       c, iface->get_name(),
	       cli_host->get_name() ? cli_host->get_name() : c,
	       srv_host->is_blacklisted() ? "blacklisted" : "",
	       ntop->getPrefs()->get_http_prefix(),
	       s, iface->get_name(),
	       srv_host->get_name() ? srv_host->get_name() : s,
	       print(fbuf, sizeof(fbuf)));

      /* force the vlan in the alert source and target */
      if(!strstr(c, "@")) sprintf(&c[strlen(c)], "@%i", cli_host->get_vlan_id());
      if(!strstr(s, "@")) sprintf(&s[strlen(s)], "@%i", srv_host->get_vlan_id());

      iface->getAlertsManager()->storeFlowAlert(this, alert_dangerous_host,
						alert_level_warning, alert_msg);
    }

    blacklist_alarm_emitted = true;
  }
}

/* *************************************** */

void Flow::processDetectedProtocol() {
  u_int16_t l7proto;

  if(protocol_processed || (ndpiFlow == NULL)) {
    return;
  }

  if((ndpiFlow->host_server_name[0] != '\0')
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
    categorizeFlow();
  }

  l7proto = ndpi_get_lower_proto(ndpiDetectedProtocol);

  switch(l7proto) {
  case NDPI_PROTOCOL_BITTORRENT:
    if(bt_hash == NULL) {
      setBittorrentHash((char*)ndpiFlow->bittorent_hash);
      protocol_processed = true;
    }
    break;

  case NDPI_PROTOCOL_DNS:
    if(ndpiFlow->host_server_name[0] != '\0') {
      if(protos.dns.last_query) free(protos.dns.last_query);
      protos.dns.last_query = strdup((const char*)ndpiFlow->host_server_name);
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
		ntop->getRedis()->setResolvedAddress(name, (char*)ndpiFlow->host_server_name);

		if(ntop->get_flashstart()) /* Cache category */
		  ntop->get_flashstart()->findCategory((char*)ndpiFlow->host_server_name,
						       &categorization.category,
						       true);
	      }
	    }
	  }
	}
      }
    }
    break;

  case NDPI_PROTOCOL_NETBIOS:
    if(ndpiFlow->host_server_name[0] != '\0') {
      get_cli_host()->set_host_label((char*)ndpiFlow->host_server_name);
      protocol_processed = true;
    }
    break;

  case NDPI_PROTOCOL_TOR:
  case NDPI_PROTOCOL_SSL:
#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "-> [%s][%s]",
				 ndpiFlow->protos.ssl.client_certificate,
				 ndpiFlow->protos.ssl.server_certificate);
#endif

    if((protos.ssl.certificate == NULL)
       && (ndpiFlow->protos.ssl.client_certificate[0] != '\0')) {
      protos.ssl.certificate = strdup(ndpiFlow->protos.ssl.client_certificate);

      if(protos.ssl.certificate && (strncmp(protos.ssl.certificate, "www.", 4) == 0)) {
	if(ndpi_is_proto(ndpiDetectedProtocol, NDPI_PROTOCOL_TOR))
	  check_tor = true;
      }
    } else if((protos.ssl.certificate == NULL)
	      && (ndpiFlow->protos.ssl.server_certificate[0] != '\0')) {
      protos.ssl.certificate = strdup(ndpiFlow->protos.ssl.server_certificate);

      if(protos.ssl.certificate && (strncmp(protos.ssl.certificate, "www.", 4) == 0)) {
	if(ndpi_is_proto(ndpiDetectedProtocol, NDPI_PROTOCOL_TOR))
	  check_tor = true;
      }
    }

    if(check_tor) {
      char rsp[256];

      if(ntop->getRedis()->getAddress(protos.ssl.certificate, rsp, sizeof(rsp), false) == 0) {
	if(rsp[0] == '\0') /* Cached failed resolution */
	  ndpiDetectedProtocol.protocol = NDPI_PROTOCOL_TOR;

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

      if(srv_host && (ndpiFlow->detected_os[0] != '\0') && cli_host)
	cli_host->setOS((char*)ndpiFlow->detected_os);

      if(cli_host && cli_host->isLocalHost())
	cli_host->incrVisitedWebSite(host_server_name);
    }
    break;
  } /* switch */

#ifdef NTOPNG_PRO
  if((ndpiDetectedProtocol.protocol == NDPI_PROTOCOL_UNKNOWN) && (!l7_protocol_guessed))
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
  if(proto_id.protocol != NDPI_PROTOCOL_UNKNOWN) {
    ndpiDetectedProtocol = proto_id;
    processDetectedProtocol();
    detection_completed = true;
  } else if(forceDetection
	    || (((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
		&& (cli_host != NULL) && (srv_host != NULL))
	    || (!iface->is_ndpi_enabled())
	    || iface->isSampledTraffic()
	    ) {
    guessProtocol();
    detection_completed = true;
  }

  if(detection_completed) {
#ifdef NTOPNG_PRO
    updateFlowShapers();
#endif
    iface->luaEvalFlow(this, callback_flow_proto_callback);
  }

#ifdef NTOPNG_PRO
  // Update the profile even if the detection is not yet completed.
  // Indeed, even if the L7 detection is not yet completed
  // the flow already carries information on all the other fields,
  // e.g., IP src and DST, vlan, L4 proto, etc
  updateProfile();
#endif
}

/* *************************************** */

void Flow::setJSONInfo(const char *json) {
  if(json == NULL) return;

  if(json_info != NULL) free(json_info);
  json_info = strdup(json);
}

/* *************************************** */

int Flow::compare(Flow *fb) {
  int c;

  if((cli_host == NULL) || (srv_host == NULL)) return(-1);

  if(vlanId < fb->vlanId) return(-1); else { if(vlanId > fb->vlanId) return(1); }
  c = cli_host->compare(fb->get_cli_host()); if(c < 0) return(-1); else { if(c > 0) return(1); }
  if(cli_port < fb->cli_port) return(-1); else { if(cli_port > fb->cli_port) return(1); }
  c = srv_host->compare(fb->get_srv_host()); if(c < 0) return(-1); else { if(c > 0) return(1); }
  if(srv_port < fb->srv_port) return(-1); else { if(srv_port > fb->srv_port) return(1); }
  if(protocol < fb->protocol) return(-1); else { if(protocol > fb->protocol) return(1); }

  return(0);
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
  char buf1[32], buf2[32], buf3[32], pbuf[32];
#ifdef NTOPNG_PRO
  char shapers[64];

  snprintf(shapers, sizeof(shapers), "[shapers: cli2srv=%u/%u, srv2cli=%u/%u]",
	   flowShaperIds.cli2srv.ingress, flowShaperIds.cli2srv.egress,
	   flowShaperIds.srv2cli.ingress, flowShaperIds.srv2cli.egress);
#endif

  buf[0] = '\0';

  if((cli_host == NULL) || (srv_host == NULL)) return(buf);

  snprintf(buf, buf_len,
	   "%s %s:%u > %s:%u [proto: %u/%s][%u/%u pkts][%llu/%llu bytes][%s]%s%s%s"
#ifdef NTOPNG_PRO
	   "%s"
#endif
	   ,
	   get_protocol_name(),
	   cli_host->get_ip()->print(buf1, sizeof(buf1)), ntohs(cli_port),
	   srv_host->get_ip()->print(buf2, sizeof(buf2)), ntohs(srv_port),
	   ndpiDetectedProtocol.protocol, get_detected_protocol_name(pbuf, sizeof(pbuf)),
	   cli2srv_packets, srv2cli_packets,
	   (long long unsigned) cli2srv_bytes, (long long unsigned) srv2cli_bytes,
	   printTCPflags(getTcpFlags(), buf3, sizeof(buf3)),
	   (isSSL() && protos.ssl.certificate) ? "[" : "",
	   (isSSL() && protos.ssl.certificate) ? protos.ssl.certificate : "",
	   (isSSL() && protos.ssl.certificate) ? "]" : ""
#ifdef NTOPNG_PRO
	   , shapers
#endif
	   );

  return(buf);
}

/* *************************************** */

bool Flow::dumpFlow(bool partial_dump) {
  bool rc = false;

  dumpFlowAlert(partial_dump);
  
  if(((cli2srv_packets - last_db_dump.cli2srv_packets) == 0)
     && ((srv2cli_packets - last_db_dump.srv2cli_packets) == 0))
      return(rc);

  if(ntop->getPrefs()->do_dump_flows_on_mysql()
     || ntop->getPrefs()->do_dump_flows_on_es()
     || ntop->get_export_interface()) {

#ifdef NTOPNG_PRO
    if(!detection_completed || cli2srv_packets + srv2cli_packets <= NDPI_MIN_NUM_PACKETS)
      // force profile detection even if the L7 Protocol has not been detected
      updateProfile();
#endif

    if(partial_dump) {
      time_t now = time(NULL);

      if((now - last_db_dump.last_dump) < CONST_DB_DUMP_FREQUENCY)
	return(rc);
    }

    if(cli_host) {
      if(ntop->getPrefs()->do_dump_flows_on_mysql())
	cli_host->getInterface()->dumpDBFlow(last_seen, partial_dump, this);
      else if(ntop->getPrefs()->do_dump_flows_on_es())
	cli_host->getInterface()->dumpEsFlow(last_seen, partial_dump, this);
    }

    if(ntop->get_export_interface()) {
      char *json = serialize(partial_dump, false);

      if(json) {
	ntop->get_export_interface()->export_data(json);
	free(json);
      }
    }

    rc = true;
  }

  return(rc);
}

/* *************************************** */

void Flow::update_hosts_stats(struct timeval *tv, bool inDeleteMethod) {
  u_int64_t sent_packets, sent_bytes, sent_goodput_bytes, rcvd_packets, rcvd_bytes, rcvd_goodput_bytes;
  u_int64_t diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
    diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes;
  bool updated = false;
  bool cli_and_srv_in_same_subnet = false;
  int16_t cli_network_id;
  int16_t srv_network_id;

  if(check_tor && (ndpiDetectedProtocol.protocol == NDPI_PROTOCOL_SSL)) {
    char rsp[256];

    if(ntop->getRedis()->getAddress(protos.ssl.certificate, rsp, sizeof(rsp), false) == 0) {
      if(rsp[0] == '\0') /* Cached failed resolution */
	ndpiDetectedProtocol.protocol = NDPI_PROTOCOL_TOR;

      check_tor = false; /* This is a valid host */
    } else {
      if((tv->tv_sec - last_seen) > 30) {
	/* We give up */
	check_tor = false; /* This is a valid host */
      }
    }
  }

  sent_packets = cli2srv_packets, sent_bytes = cli2srv_bytes, sent_goodput_bytes = cli2srv_goodput_bytes;
  diff_sent_packets = sent_packets - cli2srv_last_packets,
    diff_sent_bytes = sent_bytes - cli2srv_last_bytes, diff_sent_goodput_bytes = sent_goodput_bytes - cli2srv_last_goodput_bytes;
  prev_cli2srv_last_bytes = cli2srv_last_bytes, prev_cli2srv_last_goodput_bytes = cli2srv_last_goodput_bytes,
    prev_cli2srv_last_packets = cli2srv_last_packets;
  cli2srv_last_packets = sent_packets, cli2srv_last_bytes = sent_bytes,
    cli2srv_last_goodput_bytes = sent_goodput_bytes;

  rcvd_packets = srv2cli_packets, rcvd_bytes = srv2cli_bytes, rcvd_goodput_bytes = srv2cli_goodput_bytes;
  diff_rcvd_packets = rcvd_packets - srv2cli_last_packets,
    diff_rcvd_bytes = rcvd_bytes - srv2cli_last_bytes, diff_rcvd_goodput_bytes = rcvd_goodput_bytes - srv2cli_last_goodput_bytes;
  prev_srv2cli_last_bytes = srv2cli_last_bytes, prev_srv2cli_last_goodput_bytes = srv2cli_last_goodput_bytes,
    prev_srv2cli_last_packets = srv2cli_last_packets;
  srv2cli_last_packets = rcvd_packets, srv2cli_last_bytes = rcvd_bytes, srv2cli_last_goodput_bytes = rcvd_goodput_bytes;

  if(cli_host && srv_host) {
    cli_network_id = cli_host->get_local_network_id();
    srv_network_id = srv_host->get_local_network_id();
    if(cli_network_id >= 0 && (cli_network_id == srv_network_id))
      cli_and_srv_in_same_subnet = true;

    if(diff_sent_packets || diff_rcvd_packets) {
#ifdef NTOPNG_PRO
      if(trafficProfile && ntop->getPro()->has_valid_license()) trafficProfile->incBytes(diff_sent_bytes+diff_rcvd_bytes);
#endif

      if(cli_host) {
	NetworkStats *cli_network_stats;

	cli_network_stats = cli_host->getNetworkStats(cli_network_id);
	cli_host->incStats(protocol,
			   ndpiDetectedProtocol.protocol,
			   &categorization.category,
			   diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes,
			   diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes);

	// update per-subnet byte counters
	if(cli_network_stats) { // only if the network is known and local
	  if(!cli_and_srv_in_same_subnet) {
	    cli_network_stats->incEgress(diff_sent_bytes);
	    cli_network_stats->incIngress(diff_rcvd_bytes);
	  } else // client and server ARE in the same subnet
	    // need to update the inner counter (just one time, will intentionally skip this for srv_host)
	    cli_network_stats->incInner(diff_sent_bytes + diff_rcvd_bytes);
	}

#ifdef NOTUSED
	if(srv_host && cli_host->isLocalHost()) {
	  cli_host->incHitter(srv_host, diff_sent_bytes, diff_rcvd_bytes);
	}
#endif
      }

      if(srv_host) {
	NetworkStats *srv_network_stats;

	srv_network_stats = srv_host->getNetworkStats(srv_network_id);
	srv_host->incStats(protocol, ndpiDetectedProtocol.protocol,
			   NULL, diff_rcvd_packets, diff_rcvd_bytes, diff_rcvd_goodput_bytes,
			   diff_sent_packets, diff_sent_bytes, diff_sent_goodput_bytes);

	if(srv_network_stats) {
	  // local and known server network
	  if(!cli_and_srv_in_same_subnet) {
	    srv_network_stats->incIngress(diff_sent_bytes);
	    srv_network_stats->incEgress(diff_rcvd_bytes);
	  }
	}

#ifdef NOTUSED
	if(cli_host && srv_host->isLocalHost())
	  srv_host->incHitter(cli_host, diff_rcvd_bytes, diff_sent_bytes);
#endif

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
  }

  if(last_update_time.tv_sec > 0) {
    float tdiff_msec = ((float)(tv->tv_sec-last_update_time.tv_sec)*1000)+((tv->tv_usec-last_update_time.tv_usec)/(float)1000);
    //float t_sec = (float)(tv->tv_sec)+(float)(tv->tv_usec)/1000;

    if(tdiff_msec >= 1000 /* Do not updated when less than 1 second (1000 msec) */) {
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

	// update the old values with the newely calculated ones
	bytes_thpt_cli2srv         = bytes_msec_cli2srv;
	bytes_thpt_srv2cli         = bytes_msec_srv2cli;
	goodput_bytes_thpt_cli2srv = goodput_bytes_msec_cli2srv;
	goodput_bytes_thpt_srv2cli = goodput_bytes_msec_srv2cli;

	bytes_thpt = bytes_msec, goodput_bytes_thpt = goodput_bytes_msec;
	if(top_bytes_thpt < bytes_thpt) top_bytes_thpt = bytes_thpt;
	if(top_goodput_bytes_thpt < goodput_bytes_thpt) top_goodput_bytes_thpt = goodput_bytes_thpt;

	if(strcmp(iface->get_type(), CONST_INTERFACE_TYPE_ZMQ)
	   && (protocol == IPPROTO_TCP)
	   && (get_goodput_bytes() > 0)
	   && (ndpiDetectedProtocol.protocol != NDPI_PROTOCOL_SSH)) {
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

	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s [Goodpt long/mid/short %.3f/%.3f/%.3f][ratio: %s][goodput/thpt: %.3f]",
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

  if(dumpFlow(true)) {
    last_db_dump.cli2srv_packets = cli2srv_packets,
      last_db_dump.srv2cli_packets = srv2cli_packets, last_db_dump.cli2srv_bytes = cli2srv_bytes,
      last_db_dump.cli2srv_goodput_bytes = cli2srv_goodput_bytes,
      last_db_dump.srv2cli_bytes = srv2cli_bytes,
      last_db_dump.srv2cli_goodput_bytes = srv2cli_goodput_bytes,
      last_db_dump.last_dump = last_seen;
  }

  checkBlacklistedFlow();

  /*
    No need to call the method below as
    the delete callback will be called in a moment
  */
  if(!inDeleteMethod)
    iface->luaEvalFlow(this, callback_flow_update);
}

/* *************************************** */

bool Flow::equal(IpAddress *_cli_ip, IpAddress *_srv_ip, u_int16_t _cli_port,
		 u_int16_t _srv_port, u_int16_t _vlanId, u_int8_t _protocol,
		 bool *src2srv_direction) {
  if((_vlanId != vlanId) || (_protocol != protocol)) return(false);

  if(cli_host && cli_host->equal(_cli_ip) && srv_host && srv_host->equal(_srv_ip)
     && (_cli_port == cli_port) && (_srv_port == srv_port)) {
    *src2srv_direction = true;
    return(true);
  } else if(srv_host && srv_host->equal(_cli_ip) && cli_host && cli_host->equal(_srv_ip)
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

void Flow::lua(lua_State* vm, patricia_tree_t * ptree,
	       DetailsLevel details_level, bool skipNewTable) {
  char buf[64];
  Host *src = get_cli_host(), *dst = get_srv_host();
  bool src_match, dst_match;

  if((src == NULL) || (dst == NULL)) return;

  if(ptree) {
    src_match = src->match(ptree), dst_match = dst->match(ptree);
    if((!src_match) && (!dst_match)) return;
  }

  if(!skipNewTable)
    lua_newtable(vm);

  if(src) {
    lua_push_str_table_entry(vm, "cli.ip", src->get_ip()->print(buf, sizeof(buf)));
    lua_push_int_table_entry(vm, "cli.key", src->key());
  } else {
    lua_push_nil_table_entry(vm, "cli.ip");
    lua_push_nil_table_entry(vm, "cli.key");
  }
  lua_push_int_table_entry(vm, "cli.port", get_cli_port());

  if(dst) {
    lua_push_str_table_entry(vm, "srv.ip", dst->get_ip()->print(buf, sizeof(buf)));
    lua_push_int_table_entry(vm, "srv.key", dst->key());
  } else {
    lua_push_nil_table_entry(vm, "srv.ip");
    lua_push_nil_table_entry(vm, "srv.key");
  }
  lua_push_int_table_entry(vm, "srv.port", get_srv_port());

  lua_push_int_table_entry(vm, "bytes", cli2srv_bytes+srv2cli_bytes);
  lua_push_int_table_entry(vm, "goodput_bytes", cli2srv_goodput_bytes+srv2cli_goodput_bytes);

  if(details_level >= details_high) {

    if(src) {
      lua_push_str_table_entry(vm, "cli.host", src->get_name(buf, sizeof(buf), false));
      lua_push_int_table_entry(vm, "cli.source_id", src->getSourceId());
      lua_push_str_table_entry(vm, "cli.mac", Utils::formatMac(src->get_mac(), buf, sizeof(buf)));

      lua_push_bool_table_entry(vm, "cli.systemhost", src->isSystemHost());
      lua_push_bool_table_entry(vm, "cli.allowed_host", src_match);
      lua_push_int32_table_entry(vm, "cli.network_id", src->get_local_network_id());
    } else {
      lua_push_nil_table_entry(vm, "cli.host");
    }

    if(dst) {
      lua_push_str_table_entry(vm, "srv.host", dst->get_name(buf, sizeof(buf), false));
      lua_push_int_table_entry(vm, "srv.source_id", src->getSourceId());
      lua_push_str_table_entry(vm, "srv.mac", Utils::formatMac(dst->get_mac(), buf, sizeof(buf)));
      lua_push_bool_table_entry(vm, "srv.systemhost", dst->isSystemHost());
      lua_push_bool_table_entry(vm, "srv.allowed_host", dst_match);
      lua_push_int32_table_entry(vm, "srv.network_id", dst->get_local_network_id());
    } else {
      lua_push_nil_table_entry(vm, "srv.host");
    }

    lua_push_int_table_entry(vm, "vlan", get_vlan_id());
    lua_push_str_table_entry(vm, "proto.l4", get_protocol_name());

    if(((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
       || (ndpiDetectedProtocol.protocol != NDPI_PROTOCOL_UNKNOWN)
       || iface->is_ndpi_enabled()
       || iface->isSampledTraffic()
       || iface->is_sprobe_interface()
       || (!strcmp(iface->get_type(), CONST_INTERFACE_TYPE_ZMQ))
       || (!strcmp(iface->get_type(), CONST_INTERFACE_TYPE_ZC_FLOW))) {
      lua_push_str_table_entry(vm, "proto.ndpi", get_detected_protocol_name(buf, sizeof(buf)));
    } else
      lua_push_str_table_entry(vm, "proto.ndpi", (char*)CONST_TOO_EARLY);

    lua_push_int_table_entry(vm, "proto.ndpi_id", ndpiDetectedProtocol.protocol);
    lua_push_str_table_entry(vm, "proto.ndpi_breed", get_protocol_breed_name());

    if(ntop->get_flashstart()) {
      categorizeFlow();
      ntop->get_flashstart()->dumpCategories(vm, &categorization.category);
    }

#ifdef NTOPNG_PRO
    if(trafficProfile && ntop->getPro()->has_valid_license())
      lua_push_str_table_entry(vm, "profile", trafficProfile->getName());
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

    lua_push_bool_table_entry(vm, "verdict.pass", isPassVerdict());
    lua_push_bool_table_entry(vm, "dump.disk", getDumpFlowTraffic());

    if(protocol == IPPROTO_TCP) {
      lua_push_bool_table_entry(vm, "tcp.seq_problems",
				(tcp_stats_s2d.pktRetr
				 | tcp_stats_s2d.pktOOO
				 | tcp_stats_s2d.pktLost
				 | tcp_stats_d2s.pktRetr
				 | tcp_stats_d2s.pktOOO
				 | tcp_stats_d2s.pktLost) ? true : false);

      lua_push_float_table_entry(vm, "tcp.nw_latency.client", toMs(&clientNwLatency));
      lua_push_float_table_entry(vm, "tcp.nw_latency.server", toMs(&serverNwLatency));
      lua_push_float_table_entry(vm, "tcp.appl_latency", applLatencyMsec);
      lua_push_float_table_entry(vm, "tcp.max_thpt.cli2srv", getCli2SrvMaxThpt());
      lua_push_float_table_entry(vm, "tcp.max_thpt.srv2cli", getSrv2CliMaxThpt());

      lua_push_int_table_entry(vm, "cli2srv.retransmissions", tcp_stats_s2d.pktRetr);
      lua_push_int_table_entry(vm, "cli2srv.out_of_order", tcp_stats_s2d.pktOOO);
      lua_push_int_table_entry(vm, "cli2srv.lost", tcp_stats_s2d.pktLost);
      lua_push_int_table_entry(vm, "srv2cli.retransmissions", tcp_stats_d2s.pktRetr);
      lua_push_int_table_entry(vm, "srv2cli.out_of_order", tcp_stats_d2s.pktOOO);
      lua_push_int_table_entry(vm, "srv2cli.lost", tcp_stats_d2s.pktLost);

      lua_push_int_table_entry(vm, "cli2srv.tcp_flags", src2dst_tcp_flags);
      lua_push_int_table_entry(vm, "srv2cli.tcp_flags", dst2src_tcp_flags);

      lua_push_bool_table_entry(vm, "tcp_established", isEstablished());
    }

    if(host_server_name) lua_push_str_table_entry(vm, "host_server_name", host_server_name);
    if(bt_hash)          lua_push_str_table_entry(vm, "bittorrent_hash", bt_hash);

    if(isHTTP() && protos.http.last_method && protos.http.last_url) {
      lua_push_str_table_entry(vm, "protos.http.last_method", protos.http.last_method);
      lua_push_int_table_entry(vm, "protos.http.last_return_code", protos.http.last_return_code);
    }

#ifdef NTOPNG_PRO
    /* Shapers */
    if(cli_host && srv_host) {
      lua_push_int_table_entry(vm, "shaper.cli2srv_ingress", flowShaperIds.cli2srv.ingress);
      lua_push_int_table_entry(vm, "shaper.cli2srv_egress", flowShaperIds.cli2srv.egress);
      lua_push_int_table_entry(vm, "shaper.srv2cli_ingress", flowShaperIds.srv2cli.ingress);
      lua_push_int_table_entry(vm, "shaper.srv2cli_egress", flowShaperIds.srv2cli.egress);
    }
#endif

    if(isHTTP() && protos.http.last_method && protos.http.last_url)
      lua_push_str_table_entry(vm, "protos.http.last_url", protos.http.last_url);

    if(host_server_name)
      lua_push_str_table_entry(vm, "protos.http.server_name", host_server_name);

    if(isDNS() && protos.dns.last_query)
      lua_push_str_table_entry(vm, "protos.dns.last_query", protos.dns.last_query);

    if(isSSL() && protos.ssl.certificate)
      lua_push_str_table_entry(vm, "protos.ssl.certificate", protos.ssl.certificate);

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

    // thoughut stats cli2srv and srv2cli breakdown
    lua_push_float_table_entry(vm, "throughput_cli2srv_bps", bytes_thpt_cli2srv);
    lua_push_float_table_entry(vm, "throughput_srv2cli_bps", bytes_thpt_srv2cli);
    lua_push_float_table_entry(vm, "throughput_cli2srv_pps", pkts_thpt_cli2srv);
    lua_push_float_table_entry(vm, "throughput_srv2cli_pps", pkts_thpt_srv2cli);

    lua_push_int_table_entry(vm, "cli2srv.packets", cli2srv_packets);
    lua_push_int_table_entry(vm, "srv2cli.packets", srv2cli_packets);

    /* ********************* */
    dumpPacketStats(vm, true);
    dumpPacketStats(vm, false);

    if(details_level >= details_higher) {
      lua_push_int_table_entry(vm, "cli2srv.last", get_current_bytes_cli2srv());
      lua_push_int_table_entry(vm, "srv2cli.last", get_current_bytes_srv2cli());

      lua_push_int_table_entry(vm, "cli2srv.goodput_bytes.last", get_current_goodput_bytes_cli2srv());
      lua_push_int_table_entry(vm, "srv2cli.goodput_bytes.last", get_current_goodput_bytes_srv2cli());

      lua_push_float_table_entry(vm, "cli.latitude", get_cli_host()->get_latitude());
      lua_push_float_table_entry(vm, "cli.longitude", get_cli_host()->get_longitude());
      lua_push_float_table_entry(vm, "srv.latitude", get_srv_host()->get_latitude());
      lua_push_float_table_entry(vm, "srv.longitude", get_srv_host()->get_longitude());

      if(details_level >= details_max) {
	lua_push_bool_table_entry(vm, "cli.private", get_cli_host()->get_ip()->isPrivateAddress()); // cli. */
	lua_push_str_table_entry(vm,  "cli.country", get_cli_host()->get_country() ? get_cli_host()->get_country() : (char*)"");
	lua_push_str_table_entry(vm,  "cli.city", get_cli_host()->get_city() ? get_cli_host()->get_city() : (char*)"");
	lua_push_bool_table_entry(vm, "srv.private", get_srv_host()->get_ip()->isPrivateAddress());
	lua_push_str_table_entry(vm,  "srv.country", get_srv_host()->get_country() ? get_srv_host()->get_country() : (char*)"");
	lua_push_str_table_entry(vm,  "srv.city", get_srv_host()->get_city() ? get_srv_host()->get_city() : (char*)"");
      }
    }
  }

  lua_push_bool_table_entry(vm, "flow.idle", isIdleFlow());
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

bool Flow::idle() {
  u_int8_t tcp_flags;

  if(!iface->is_purge_idle_interface()) return(false);

  tcp_flags = src2dst_tcp_flags | dst2src_tcp_flags;

  /* If this flow is idle for at least MAX_TCP_FLOW_IDLE */
  if((protocol == IPPROTO_TCP)
     && ((tcp_flags & TH_FIN) || (tcp_flags & TH_RST))
     && (doNotExpireBefore >= iface->getTimeLastPktRcvd())
     && isIdle(MAX_TCP_FLOW_IDLE /* sec */)) {
    /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "[TCP] Early flow expire"); */
    return(true);
  }

  return(isIdle(ntop->getPrefs()->get_flow_max_idle()));
};

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

#ifdef NOTUSED
struct site_categories* Flow::getFlowCategory(bool force_categorization) {
  if(!categorization.categorized_requested) {
    if(ndpiFlow == NULL)
      categorization.categorized_requested = true;
    else if(host_server_name && (host_server_name[0] != '\0')) {
      if(!Utils::isGoodNameToCategorize(host_server_name))
	categorization.categorized_requested = true;
      else
	categorizeFlow();
    }
  }

  return(&categorization.category);
}
#endif

/* *************************************** */

void Flow::sumStats(nDPIStats *stats) {
  stats->incStats(ndpiDetectedProtocol.protocol,
		  cli2srv_packets, cli2srv_bytes,
		  srv2cli_packets, srv2cli_bytes);
}

/* *************************************** */

char* Flow::serialize(bool partial_dump, bool es_json) {
  json_object *my_object;
  char *rsp;

  if((cli_host == NULL) || (srv_host == NULL))
    return(NULL);

  if(es_json) {
    ntop->getPrefs()->set_json_symbolic_labels_format(true);
    if((my_object = flow2json(partial_dump)) != NULL) {

      /* JSON string */
      rsp = strdup(json_object_to_json_string(my_object));

      /* Free memory */
      json_object_put(my_object);
    } else
      rsp = NULL;
  } else {
    /* JSON string */
    ntop->getPrefs()->set_json_symbolic_labels_format(false);
    my_object = flow2json(partial_dump);
    rsp = strdup(json_object_to_json_string(my_object));
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Emitting Flow: %s", rsp);

    /* Free memory */
    json_object_put(my_object);
  }

  return(rsp);
}

/* *************************************** */

#ifdef NOTUSED
json_object* Flow::flow2es(json_object *flow_object) {
  char buf[64];
  struct tm* tm_info;
  time_t t;

  t = last_seen;
  tm_info = gmtime(&t);

  strftime(buf, sizeof(buf), "%FT%T.0Z", tm_info);
  json_object_object_add(flow_object, "@timestamp", json_object_new_string(buf));
  json_object_object_add(flow_object, "@version", json_object_new_int(1));

  json_object_object_add(flow_object, "type", json_object_new_string(ntop->getPrefs()->get_es_type()));

#if 0
  es_object = json_object_new_object();
  json_object_object_add(es_object, "_type", json_object_new_string("ntopng"));

  snprintf(buf, sizeof(buf), "%u%u%lu", (unsigned int)tv.tv_sec, tv.tv_usec, (unsigned long)this);
  json_object_object_add(es_object, "_id", json_object_new_string(buf));

  strftime(buf, sizeof(buf), "ntopng-%Y.%m.%d", tm_info);
  json_object_object_add(es_object, "_index", json_object_new_string(buf));
  json_object_object_add(es_object, "_score", NULL);
  json_object_object_add(es_object, "_source", flow_object);
#endif

  return(flow_object);
}
#endif

/* *************************************** */

json_object* Flow::flow2json(bool partial_dump) {
  json_object *my_object;
  char buf[64], jsonbuf[64], *c;
  time_t t;

  if(((cli2srv_packets - last_db_dump.cli2srv_packets) == 0)
     && ((srv2cli_packets - last_db_dump.srv2cli_packets) == 0))
    return(NULL);

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  if(ntop->getPrefs()->do_dump_flows_on_es()) {
    struct tm* tm_info;

    t = last_seen;
    tm_info = gmtime(&t);

    strftime(buf, sizeof(buf), "%FT%T.0Z", tm_info);
    json_object_object_add(my_object, "@timestamp", json_object_new_string(buf));
    /* json_object_object_add(my_object, "@version", json_object_new_int(1)); */
    json_object_object_add(my_object, "type", json_object_new_string(ntop->getPrefs()->get_es_type()));

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
     || (ndpiDetectedProtocol.protocol != NDPI_PROTOCOL_UNKNOWN)) {
    json_object_object_add(my_object, Utils::jsonLabel(L7_PROTO, "L7_PROTO", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int(ndpiDetectedProtocol.protocol));
    json_object_object_add(my_object, Utils::jsonLabel(L7_PROTO_NAME, "L7_PROTO_NAME", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_string(get_detected_protocol_name(buf, sizeof(buf))));
  }

  if(protocol == IPPROTO_TCP)
    json_object_object_add(my_object, Utils::jsonLabel(TCP_FLAGS, "TCP_FLAGS", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int(src2dst_tcp_flags | dst2src_tcp_flags));

  json_object_object_add(my_object, Utils::jsonLabel(IN_PKTS, "IN_PKTS", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(partial_dump ? (cli2srv_packets - last_db_dump.cli2srv_packets) : cli2srv_packets));
  json_object_object_add(my_object, Utils::jsonLabel(IN_BYTES, "IN_BYTES", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(partial_dump ? (cli2srv_bytes - last_db_dump.cli2srv_bytes) : cli2srv_bytes));

  json_object_object_add(my_object, Utils::jsonLabel(OUT_PKTS, "OUT_PKTS", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(partial_dump ? (srv2cli_packets - last_db_dump.srv2cli_packets) : srv2cli_packets));
  json_object_object_add(my_object, Utils::jsonLabel(OUT_BYTES, "OUT_BYTES", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int64(partial_dump ? (srv2cli_bytes - last_db_dump.srv2cli_bytes) : srv2cli_bytes));

  json_object_object_add(my_object, Utils::jsonLabel(FIRST_SWITCHED, "FIRST_SWITCHED", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int((u_int32_t)(partial_dump && last_db_dump.last_dump) ? last_db_dump.last_dump : first_seen));
  json_object_object_add(my_object, Utils::jsonLabel(LAST_SWITCHED, "LAST_SWITCHED", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int((u_int32_t)last_seen));

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

  c = cli_host->get_country() ? cli_host->get_country() : NULL;
  if(c) {
    json_object *location = json_object_new_array();

    json_object_object_add(my_object, "SRC_IP_COUNTRY", json_object_new_string(c));
    if(location) {
      json_object_array_add(location, json_object_new_double(cli_host->get_longitude()));
      json_object_array_add(location, json_object_new_double(cli_host->get_latitude()));
      json_object_object_add(my_object, "SRC_IP_LOCATION", location);
    }
  }

  c = srv_host->get_country() ? srv_host->get_country() : NULL;
  if(c) {
    json_object *location = json_object_new_array();

    json_object_object_add(my_object, "DST_IP_COUNTRY", json_object_new_string(c));

    if(location) {
      json_object_array_add(location, json_object_new_double(srv_host->get_longitude()));
      json_object_array_add(location, json_object_new_double(srv_host->get_latitude()));
      json_object_object_add(my_object, "DST_IP_LOCATION", location);
    }
  }

  if(categorization.categorized_requested
     && (categorization.category.categories[0] != NTOP_UNKNOWN_CATEGORY_ID)) {
    char buf[64];

    ntop->get_flashstart()->dumpCategories(&categorization.category, buf, sizeof(buf));
    json_object_object_add(my_object, "category", json_object_new_string(buf));
  }

#ifdef NTOPNG_PRO
  // Traffic profile information, if any
  if(trafficProfile && trafficProfile->getName())
    json_object_object_add(my_object, "PROFILE", json_object_new_string(trafficProfile->getName()));
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

  json_object_object_add(my_object, "PASS_VERDICT", json_object_new_boolean(passVerdict ? (json_bool)1 : (json_bool)0));

  return(my_object);
}

/* *************************************** */

/* https://blogs.akamai.com/2013/09/slow-dos-on-the-rise.html */
bool Flow::isIdleFlow() {
  time_t now = iface->getTimeLastPktRcvd();

  if(strcmp(iface->get_type(), CONST_INTERFACE_TYPE_ZMQ)) {
    u_int32_t threshold_ms = CONST_MAX_IDLE_INTERARRIVAL_TIME;

    if(protocol == IPPROTO_TCP) {
      if(!twh_over) {
	if((synAckTime.tv_sec > 0) /* We have seen SYN|ACK but 3WH is NOT over */
	   && ((now - synAckTime.tv_sec) > CONST_MAX_IDLE_INTERARRIVAL_TIME_NO_TWH_SYN_ACK))
	  return(true); /* The client has not completed the 3WH within the expected time */

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
	  return(true);  /* Connection established and no data exchanged yet */

	else if((getCli2SrvCurrentInterArrivalTime(now) > CONST_MAX_IDLE_INTERARRIVAL_TIME)
		|| ((srv2cli_packets > 0) && (getSrv2CliCurrentInterArrivalTime(now) > CONST_MAX_IDLE_INTERARRIVAL_TIME)))
	  return(true);
	else {
	  switch(ndpi_get_lower_proto(ndpiDetectedProtocol)) {
	  case NDPI_PROTOCOL_SSL:
	    if((protos.ssl.hs_delta_time > CONST_SSL_MAX_DELTA)
	       || (protos.ssl.delta_firstData > CONST_SSL_MAX_DELTA)
	       || (protos.ssl.deltaTime_data > CONST_MAX_SSL_IDLE_TIME)
	       || (getCli2SrvCurrentInterArrivalTime(now) > CONST_MAX_SSL_IDLE_TIME)
	       || ((srv2cli_packets > 0) && getSrv2CliCurrentInterArrivalTime(now) > CONST_MAX_SSL_IDLE_TIME)) {
	      return(true);
	    }
            break;
	  }
	}
      }
    }

    /* Check if there is no traffic for a long time on this flow */
    if((getCli2SrvCurrentInterArrivalTime(now) > threshold_ms)
       || ((srv2cli_packets > 0) && (getSrv2CliCurrentInterArrivalTime(now) > threshold_ms)))
      return(true);
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
    cli_host->incMacStats(true, pkt_len), srv_host->incMacStats(false, pkt_len),
      cli_host->get_sent_stats()->incStats(pkt_len), srv_host->get_recv_stats()->incStats(pkt_len);
  } else {
    srv2cli_packets++, srv2cli_bytes += pkt_len, srv2cli_goodput_bytes += payload_len;
    cli_host->incMacStats(false, pkt_len), srv_host->incMacStats(true, pkt_len),
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

void Flow::updateActivities() {
  if(cli_host) cli_host->updateActivities();
  if(srv_host) srv_host->updateActivities();
}

/* *************************************** */

void Flow::addFlowStats(bool cli2srv_direction,
			u_int in_pkts, u_int in_bytes, u_int in_goodput_bytes,
			u_int out_pkts, u_int out_bytes, u_int out_goodput_bytes,
			time_t last_seen) {
  updateSeen(last_seen);

  if(cli2srv_direction)
    cli2srv_packets += in_pkts, cli2srv_bytes += in_bytes, cli2srv_goodput_bytes += in_goodput_bytes,
      srv2cli_packets += out_pkts, srv2cli_bytes += out_bytes, srv2cli_goodput_bytes += out_goodput_bytes;
  else
    cli2srv_packets += out_pkts, cli2srv_bytes += out_bytes, cli2srv_goodput_bytes += out_goodput_bytes,
      srv2cli_packets += in_pkts, srv2cli_bytes += in_bytes, srv2cli_goodput_bytes += in_goodput_bytes;

  updateActivities();
}

/* *************************************** */

void Flow::updateTcpFlags(const struct bpf_timeval *when,
			  u_int8_t flags, bool src2dst_direction) {
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
	if(serverNwLatency.tv_sec > 5) memset(&serverNwLatency, 0, sizeof(serverNwLatency));
      }
    } else if(flags == TH_ACK) {
      if((ackTime.tv_sec == 0) && (synAckTime.tv_sec > 0)) {
	memcpy(&ackTime, when, sizeof(struct timeval));
	timeval_diff(&synAckTime, (struct timeval*)when, &clientNwLatency, 1);

	/* Sanity check */
	if(clientNwLatency.tv_sec > 5) memset(&clientNwLatency, 0, sizeof(clientNwLatency));

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

    if(divide_by_two)
      result->tv_sec /= 2, result->tv_usec /= 2;
  } else
    result->tv_sec = 0, result->tv_usec = 0;
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

  next_seq_num = getNextTcpSeq(flags, seq_num, payload_Len);

  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[act: %u][ack: %u]", seq_num, ack_seq_num);

  if(src2dst_direction) {
    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[last: %u][next: %u]", tcp_stats_s2d.last, tcp_stats_s2d.next);

    if(window > 0) srv2cli_window = window; /* Note the window is reverted */
    if(tcp_stats_s2d.next > 0) {
      if((tcp_stats_s2d.next != seq_num)
	 && (tcp_stats_s2d.next != (seq_num-1))) {
	if(tcp_stats_s2d.last == seq_num) {
	  tcp_stats_s2d.pktRetr++, cli_host->incRetransmittedPkts(1), iface->incRetransmittedPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet retransmission");
	} else if((tcp_stats_s2d.last > seq_num)
		  && (seq_num < tcp_stats_s2d.next)) {
	  tcp_stats_s2d.pktLost++, cli_host->incLostPkts(1), iface->incLostPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet lost [last: %u][act: %u]", tcp_stats_s2d.last, seq_num);
	} else {
	  tcp_stats_s2d.pktOOO++, cli_host->incOOOPkts(1), iface->incOOOPkts(1);

	  update_last_seqnum = ((seq_num - 1) > tcp_stats_s2d.last) ? true : false;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet OOO [last: %u][act: %u]", tcp_stats_s2d.last, seq_num);
	}
      }
    }

    tcp_stats_s2d.next = next_seq_num;
    if(update_last_seqnum) tcp_stats_s2d.last = seq_num;
  } else {
    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[last: %u][next: %u]", tcp_stats_d2s.last, tcp_stats_d2s.next);

    if(window > 0) cli2srv_window = window; /* Note the window is reverted */
    if(tcp_stats_d2s.next > 0) {
      if((tcp_stats_d2s.next != seq_num)
	 && (tcp_stats_d2s.next != (seq_num-1))) {
	if(tcp_stats_d2s.last == seq_num) {
	  tcp_stats_d2s.pktRetr++, srv_host->incRetransmittedPkts(1), iface->incRetransmittedPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet retransmission");
	  // bytes
	} else if((tcp_stats_d2s.last > seq_num)
		  && (seq_num < tcp_stats_d2s.next)) {
	  tcp_stats_d2s.pktLost++, srv_host->incLostPkts(1), iface->incLostPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet lost [last: %u][act: %u]", tcp_stats_d2s.last, seq_num);
	} else {
	  tcp_stats_d2s.pktOOO++, srv_host->incOOOPkts(1), iface->incOOOPkts(1);
	  update_last_seqnum = ((seq_num - 1) > tcp_stats_d2s.last) ? true : false;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[last: %u][next: %u]", tcp_stats_d2s.last, tcp_stats_d2s.next);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet OOO [last: %u][act: %u]", tcp_stats_d2s.last, seq_num);
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

bool Flow::match(patricia_tree_t *ptree) {
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
    char *bt_proto = ndpi_strnstr((const char *)&payload[20], "BitTorrent protocol", payload_len-20);

    if(bt_proto) {
      setBittorrentHash(&bt_proto[27]);
      iface->luaEvalFlow(this, callback_flow_proto_callback);
    }
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

    if(payload && ((space = strchr(payload, ' ')) != NULL)) {
      u_int l = space-payload;

      if((!strncmp(payload, "GET", 3))
	 || (!strncmp(payload, "POST", 4))
	 || (!strncmp(payload, "HEAD", 4))
	 || (!strncmp(payload, "PUT", 3))
	 ) {
	diff_num_http_requests++; /* One new request found */

	if(protos.http.last_method) free(protos.http.last_method);
	if((protos.http.last_method = (char*)malloc(l+1)) != NULL) {
	  strncpy(protos.http.last_method, payload, l);
	  protos.http.last_method[l] = '\0';
	}

	payload = &space[1];
	if((space = strchr(payload, ' ')) != NULL) {
	  u_int l = min_val(space-payload, 512); /* Avoid jumbo URLs */

	  /* Stop at the first non-printable char of the HTTP URL */
	  for(u_int i=0; i<l; i++) {
	    if(!isprint(payload[i])) {
	      l = i;
	      break;
	    }
	  }

	  if(protos.http.last_url) free(protos.http.last_url);
	  if((protos.http.last_url = (char*)malloc(l+1)) != NULL) {
	    strncpy(protos.http.last_url, payload, l);
	    protos.http.last_url[l] = '\0';
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

      if((space = strchr(payload, ' ')) != NULL) {
	payload = &space[1];
	if((space = strchr(payload, ' ')) != NULL) {
	  char tmp[32];
	  int l = min_val((int)(space-payload), (int)(sizeof(tmp)-1));

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
	    iface->luaEvalFlow(this, callback_flow_proto_callback);
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

bool Flow::isPassVerdict() {
  if(!passVerdict) return(passVerdict);

  /* TODO: isAboveQuota() must be checked periodically */
  if(cli_host && srv_host)
    return((!(cli_host->isAboveQuota() || srv_host->isAboveQuota()))
	   && (!(cli_host->dropAllTraffic() || srv_host->dropAllTraffic())));
  else
    return(true);
}

/* *************************************** */

bool Flow::dumpFlowTraffic() {
  if(dump_flow_traffic) return true;
  if(cli_host && srv_host)
    return(cli_host->dumpHostTraffic() || srv_host->dumpHostTraffic());
  return(false);
}

/* *************************************** */

void Flow::checkFlowCategory() {
  if(categorization.category.categories[0] == NTOP_UNKNOWN_CATEGORY_ID)
    return;

  /* TODO: use category to emit verdict */
#if 0
  {
    char c_buf[64], s_buf[64], *c, *s, alert_msg[1024];

    /* Emit alarm */
    c = cli_host->get_ip()->print(c_buf, sizeof(c_buf));
    s = srv_host->get_ip()->print(s_buf, sizeof(s_buf));

    snprintf(alert_msg, sizeof(alert_msg),
	     "Flow <A HREF='%s/lua/host_details.lua?host=%s&ifname=%s'>%s</A>:%u &lt;-&gt; "
	     "<A HREF='%s/lua/host_details.lua?host=%s&ifname=%s'>%s</A>:%u"
	     " accessed malware site <A HREF=http://google.com/safebrowsing/diagnostic?site=%s&hl=en-us>%s</A>",
	     ntop->getPrefs()->get_http_prefix(),
	     c, iface->get_name(), c, cli_port,
	     ntop->getPrefs()->get_http_prefix(),
	     s, iface->get_name(), s, srv_port,
	     host_server_name, host_server_name);

    /* TODO: see if it is meaningful to add source and target to the alert */
    iface->getAlertsManager()->storeFlowAlert(this, alert_malware_detection,
					      alert_level_warning, alert_msg);
    badFlow = true, setDropVerdict();
  }
#endif
}

/* *************************************** */

#ifdef NTOPNG_PRO

void Flow::updateDirectionShapers(bool src2dst_direction, u_int8_t *a_shaper_id, u_int8_t *b_shaper_id) {
  if(cli_host && srv_host) {
    TrafficShaper *sa, *sb;
    L7Policer *p = getInterface()->getL7Policer();
    
    if(src2dst_direction) {
      *a_shaper_id = cli_host->get_egress_shaper_id(ndpiDetectedProtocol),
	*b_shaper_id = srv_host->get_ingress_shaper_id(ndpiDetectedProtocol);
    } else {
      *a_shaper_id = cli_host->get_ingress_shaper_id(ndpiDetectedProtocol),
	*b_shaper_id = srv_host->get_egress_shaper_id(ndpiDetectedProtocol);
    }

    if(p) {
      sa = p->getShaper(*a_shaper_id), sb = p->getShaper(*b_shaper_id);
      
      passVerdict = ((sa && (sa->get_max_rate_kbit_sec() == 0))
		     || (sb && (sb->get_max_rate_kbit_sec() == 0))) ? false : true;
    }
  } else
    *a_shaper_id = *b_shaper_id = PASS_ALL_SHAPER_ID;
}

/* *************************************** */

#ifdef NTOPNG_PRO

void Flow::updateFlowShapers() {
  updateDirectionShapers(true, &flowShaperIds.cli2srv.ingress, &flowShaperIds.cli2srv.egress),
    updateDirectionShapers(false, &flowShaperIds.srv2cli.ingress, &flowShaperIds.srv2cli.egress);

#ifdef SHAPER_DEBUG
  {
    char buf[512];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[SHAPERS] %s", print(buf, sizeof(buf)));
  }
#endif
}
#endif

#endif

/* *************************************** */

bool Flow::isSuspiciousFlowThpt() {
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

  return(false);
}

/* *************************************** */

bool Flow::isLowGoodput() {
  if(protocol == IPPROTO_UDP)
    return(false);
  else
    return((((get_goodput_bytes()*100)/(get_bytes()+1 /* avoid zero divisions */)) < FLOW_GOODPUT_THRESHOLD) ? true : false);
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
	// iface->luaEvalFlow(this, callback_flow_proto_callback);
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
  if(!strcmp(iface->get_type(), CONST_INTERFACE_TYPE_ZMQ)) {
    if(getTcpFlags() & TH_RST)
      return status_connection_reset;
  } else {
    bool isIdle = isIdleFlow();
    bool lowGoodput = isLowGoodput();

    if(protocol == IPPROTO_TCP) {
      u_int16_t l7proto = ndpi_get_lower_proto(ndpiDetectedProtocol);

      if((srv2cli_packets == 0) && ((time(NULL)-last_seen) > 2 /* sec */))
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
	  if(!protos.ssl.firstdata_seen && isIdle)
	    return status_slow_application_header;
	  break;

	case NDPI_PROTOCOL_HTTP:
	  if(/* !header_HTTP_completed &&*/isIdle)
	    return status_slow_application_header;
	  break;
	}

	if(getTcpFlags() & TH_RST) return status_connection_reset;
	if(isIdle  && lowGoodput)  return status_slow_data_exchange;
	if(isIdle  && !lowGoodput) return status_slow_tcp_connection;
	if(!isIdle && lowGoodput)  return status_low_goodput;
      }
    }
  }

  if(iface->getAlertLevel() > 0)
   return(status_flow_when_interface_alerted);

  return status_normal;
}

/* ***************************************************** */

void Flow::setActivityFilter(ActivityFilterID fid,
			     const activity_filter_config * config) {
  if(activityDetection == NULL)
    return /* detection disabled */;

  if(activityDetection && (fid < ActivityFiltersN) && config) {
    activityDetection->filterId = fid;
    activityDetection->filterSet = true;
    activityDetection->config = *config;
    memset(&activityDetection->status, 0, sizeof(activityDetection->status));
  } else {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "[%s] Invalid activity filter ID: %u", this, fid);
  }
}

/* ***************************************************** */

bool Flow::invokeActivityFilter(const struct timeval *when,
				bool cli2srv, u_int16_t payload_len) {
  if(activityDetection == NULL)
    return false /* detection disabled */;

  if(activityDetection->filterSet)
    return(activity_filter_funcs[activityDetection->filterId])(&activityDetection->config,
							       &activityDetection->status, this,
							       when, cli2srv, payload_len);
  return(false);
}

/* ***************************************************** */
