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

Flow::Flow(NetworkInterface *_iface,
	   u_int16_t _vlanId, u_int8_t _protocol,
	   u_int8_t cli_mac[6], IpAddress *_cli_ip, u_int16_t _cli_port,
	   u_int8_t srv_mac[6], IpAddress *_srv_ip, u_int16_t _srv_port,
	   time_t _first_seen, time_t _last_seen) : GenericHashEntry(_iface) {
  vlanId = _vlanId, protocol = _protocol, cli_port = _cli_port, srv_port = _srv_port;
  cli2srv_packets = 0, cli2srv_bytes = 0, srv2cli_packets = 0, srv2cli_bytes = 0, cli2srv_last_packets = 0,
    cli2srv_last_bytes = 0, srv2cli_last_packets = 0, srv2cli_last_bytes = 0,
    cli_host = srv_host = NULL, ndpi_flow = NULL, badFlow = false, profileId = -1;

  l7_protocol_guessed = detection_completed = false;
  dump_flow_traffic = false, ndpi_proto_name = NULL,
    ndpi_detected_protocol.protocol = NDPI_PROTOCOL_UNKNOWN,
    ndpi_detected_protocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;

  switch(protocol) {
  case IPPROTO_ICMP:
    ndpi_detected_protocol.protocol = NDPI_PROTOCOL_IP_ICMP,
      ndpi_detected_protocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;
    break;

  case IPPROTO_ICMPV6:
    ndpi_detected_protocol.protocol = NDPI_PROTOCOL_IP_ICMPV6,
      ndpi_detected_protocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;
    break;

  default:
    ndpi_detected_protocol.protocol = ndpi_detected_protocol.master_protocol = NDPI_PROTOCOL_UNKNOWN;
    break;
  }

  ndpi_flow = NULL, cli_id = srv_id = NULL, client_proc = server_proc = NULL;
  json_info = strdup("{}"), cli2srv_direction = true, twh_over = false,
    dissect_next_http_packet = false,
    check_tor = false, host_server_name = NULL, diff_num_http_requests = 0,
    ssl.certificate = NULL;

  src2dst_tcp_flags = dst2src_tcp_flags = 0, last_update_time.tv_sec = 0, last_update_time.tv_usec = 0,
    bytes_thpt = top_bytes_thpt = pkts_thpt = top_pkts_thpt = 0;
  cli2srv_last_bytes = prev_cli2srv_last_bytes = 0, srv2cli_last_bytes = prev_srv2cli_last_bytes = 0;
  cli2srv_last_packets = prev_cli2srv_last_packets = 0, srv2cli_last_packets = prev_srv2cli_last_packets = 0;

  last_db_dump.cli2srv_packets = 0, last_db_dump.srv2cli_packets = 0,
    last_db_dump.cli2srv_bytes = 0, last_db_dump.srv2cli_bytes = 0, last_db_dump.last_dump = 0;

  iface->findFlowHosts(_vlanId, cli_mac, _cli_ip, &cli_host, srv_mac, _srv_ip, &srv_host);
  if(cli_host) { cli_host->incUses(); cli_host->incNumFlows(true); }
  if(srv_host) { srv_host->incUses(); srv_host->incNumFlows(false); }
  passVerdict = true;
  first_seen = _first_seen, last_seen = _last_seen;
  categorization.category[0] = '\0', categorization.categorized_requested = false;
  bytes_thpt_trend = trend_unknown;
  pkts_thpt_trend = trend_unknown;
  protocol_processed = false, blacklist_alarm_emitted = false;

  synTime.tv_sec = synTime.tv_usec = 0,
    ackTime.tv_sec = ackTime.tv_usec = 0,
    synAckTime.tv_sec = synAckTime.tv_usec = 0;
  memset(&http, 0, sizeof(http)), memset(&dns, 0, sizeof(dns));
  memset(&tcp_stats_s2d, 0, sizeof(tcp_stats_s2d)), memset(&tcp_stats_d2s, 0, sizeof(tcp_stats_d2s));
  memset(&clientNwLatency, 0, sizeof(clientNwLatency)), memset(&serverNwLatency, 0, sizeof(serverNwLatency));

  switch(protocol) {
  case IPPROTO_TCP:
  case IPPROTO_UDP:
    if(iface->is_ndpi_enabled())
      allocFlowMemory();
    break;

  default:
    ndpi_detected_protocol = ndpi_guess_undetected_protocol(iface->get_ndpi_struct(),
							    protocol, 0, 0, 0, 0);
    break;
  }

  if(!iface->is_packet_interface())
    last_update_time.tv_sec = (long)first_seen;

  // refresh_process();
}

/* *************************************** */

Flow::Flow(NetworkInterface *_iface,
	   u_int16_t _vlanId, u_int8_t _protocol,
	   u_int8_t cli_mac[6], IpAddress *_cli_ip, u_int16_t _cli_port,
	   u_int8_t srv_mac[6], IpAddress *_srv_ip, u_int16_t _srv_port) : GenericHashEntry(_iface) {
  time_t now = iface->getTimeLastPktRcvd();

  Flow(_iface, _vlanId, _protocol, cli_mac, _cli_ip, _cli_port,
       srv_mac, _srv_ip, _srv_port, now, now);
}

/* *************************************** */

void Flow::allocFlowMemory() {
  if((ndpi_flow = (ndpi_flow_struct*)calloc(1, iface->get_flow_size())) == NULL)
    throw "Not enough memory";

  if((cli_id = calloc(1, iface->get_size_id())) == NULL)
    throw "Not enough memory";

  if((srv_id = calloc(1, iface->get_size_id())) == NULL)
    throw "Not enough memory";
}

/* *************************************** */

void Flow::deleteFlowMemory() {
  if(ndpi_flow) { ndpi_free_flow(ndpi_flow); ndpi_flow = NULL; }
  if(cli_id)    { free(cli_id);    cli_id = NULL;    }
  if(srv_id)    { free(srv_id);    srv_id = NULL;    }
}

/* *************************************** */

void Flow::categorizeFlow() {
  if((host_server_name == NULL) || (host_server_name[0] == '\0'))
    return;

  if(!categorization.categorized_requested) {
    categorization.categorized_requested = true;

    if(ntop->get_categorization()->findCategory(Utils::get2ndLevelDomain(host_server_name),
						categorization.category, sizeof(categorization.category),
						true) != NULL) {
      checkFlowCategory();
    }
  } else if(categorization.category[0] == '\0') {
    ntop->getRedis()->getFlowCategory(Utils::get2ndLevelDomain(host_server_name),
				      categorization.category,
				      sizeof(categorization.category), false);

    if(categorization.category[0] != '\0')
      checkFlowCategory();
  }
}

/* *************************************** */

Flow::~Flow() {
  struct timeval tv = { 0, 0 };

  checkBlacklistedFlow();
  update_hosts_stats(&tv);
  dumpFlow(true /* Dump only the last part of the flow */);

  if(cli_host)         { cli_host->decUses(); cli_host->decNumFlows(true);  }
  if(srv_host)         { srv_host->decUses(); srv_host->decNumFlows(false); }
  if(json_info)        free(json_info);
  if(client_proc)      delete(client_proc);
  if(server_proc)      delete(server_proc);
  if(host_server_name) free(host_server_name);
  if(http.last_method) free(http.last_method);
  if(http.last_url)    free(http.last_url);
  if(dns.last_query)   free(dns.last_query);
  if(ssl.certificate)  free(ssl.certificate);
  if(ndpi_proto_name)  free(ndpi_proto_name);

  deleteFlowMemory();
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
      s = srv_host->get_ip()->print(s_buf, sizeof(s_buf));

      snprintf(alert_msg, sizeof(alert_msg),
	       "%s <A HREF='/lua/host_details.lua?host=%s&ifname=%s'>%s</A> contacted %s host <A HREF='/lua/host_details.lua?host=%s&ifname=%s'>%s</A> [%s]",
	       cli_host->is_blacklisted() ? "Blacklisted host" : "Host",
	       c, iface->get_name(), cli_host->get_name() ? cli_host->get_name() : c,
	       srv_host->is_blacklisted() ? "blacklisted" : "",
	       s, iface->get_name(), srv_host->get_name() ? srv_host->get_name() : s,
	       print(fbuf, sizeof(fbuf)));

      ntop->getRedis()->queueAlert(alert_level_warning, alert_dangerous_host, alert_msg);
      badFlow = true, setDropVerdict();
    }

    blacklist_alarm_emitted = true;
  }
}

/* *************************************** */

void Flow::processDetectedProtocol() {
  u_int16_t l7proto;

  if(protocol_processed || (ndpi_flow == NULL)) return;

  if((ndpi_flow->host_server_name[0] != '\0')
     && (host_server_name == NULL)) {
    Utils::sanitizeHostName((char*)ndpi_flow->host_server_name);

    if(ndpi_is_proto(ndpi_detected_protocol, NDPI_PROTOCOL_HTTP)) {
      char *double_column = strrchr((char*)ndpi_flow->host_server_name, ':');

      if(double_column) double_column[0] = '\0';
    }

    host_server_name = strdup((char*)ndpi_flow->host_server_name);
    categorizeFlow();
  }

  l7proto = ndpi_get_lower_proto(ndpi_detected_protocol);

  switch(l7proto) {
  case NDPI_PROTOCOL_DNS:
    if(ndpi_flow->host_server_name[0] != '\0') {
      if(dns.last_query) free(dns.last_query);
      dns.last_query = strdup((const char*)ndpi_flow->host_server_name);
    }

    if(ntop->getPrefs()->decode_dns_responses()) {
      if(ndpi_flow->host_server_name[0] != '\0') {
	char delimiter = '@', *name = NULL;
	char *at = (char*)strchr((const char*)ndpi_flow->host_server_name, delimiter);

	/* Consider only positive DNS replies */
	if(at != NULL)
	  name = &at[1], at[0] = '\0';
	else if((!strstr((const char*)ndpi_flow->host_server_name, ".in-addr.arpa"))
		&& (!strstr((const char*)ndpi_flow->host_server_name, ".ip6.arpa")))
	  name = (char*)ndpi_flow->host_server_name;

	if(name) {
	  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[DNS] %s", (char*)ndpi_flow->host_server_name);

	  if(ndpi_flow->protos.dns.ret_code == 0) {
	    if(ndpi_flow->protos.dns.num_answers > 0) {
	      protocol_processed = true;

	      if(at != NULL)
		ntop->getRedis()->setResolvedAddress(name, (char*)ndpi_flow->host_server_name);
	    }
	  }
	}
      }
    }
    break;

  case NDPI_PROTOCOL_NETBIOS:
    if(ndpi_flow->host_server_name[0] != '\0') {
      get_cli_host()->set_host_label((char*)ndpi_flow->host_server_name);
      protocol_processed = true;
    }
    break;

  case NDPI_PROTOCOL_TOR:
  case NDPI_PROTOCOL_SSL:
#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "-> [%s][%s]",
     				 ndpi_flow->protos.ssl.client_certificate,
     				 ndpi_flow->protos.ssl.server_certificate);
#endif

    if((ssl.certificate == NULL)
       && (ndpi_flow->protos.ssl.client_certificate[0] != '\0')) {
      ssl.certificate = strdup(ndpi_flow->protos.ssl.client_certificate);

      if(ssl.certificate && (strncmp(ssl.certificate, "www.", 4) == 0)) {
	if(ndpi_is_proto(ndpi_detected_protocol, NDPI_PROTOCOL_TOR))
	  check_tor = true;
      }
    } else if((ssl.certificate == NULL)
	      && (ndpi_flow->protos.ssl.server_certificate[0] != '\0')) {
      ssl.certificate = strdup(ndpi_flow->protos.ssl.server_certificate);

      if(ssl.certificate && (strncmp(ssl.certificate, "www.", 4) == 0)) {
	if(ndpi_is_proto(ndpi_detected_protocol, NDPI_PROTOCOL_TOR))
	  check_tor = true;
      }
    }

    if(check_tor) {
      char rsp[256];

      if(ntop->getRedis()->getAddress(ssl.certificate, rsp, sizeof(rsp), false) == 0) {
	if(rsp[0] == '\0') /* Cached failed resolution */
	  ndpi_detected_protocol.protocol = NDPI_PROTOCOL_TOR;

	check_tor = false; /* This is a valid host */
      } else {
	ntop->getRedis()->pushHostToResolve(ssl.certificate, false, true /* Fake to resolve it ASAP */);
      }
    }
    break;

    /* No break here !*/
  case NDPI_PROTOCOL_HTTP:
  case NDPI_PROTOCOL_HTTP_PROXY:
    if(ndpi_flow->host_server_name[0] != '\0') {
      char *doublecol, delimiter = ':';

      protocol_processed = true;

      /* If <host>:<port> we need to remove ':' */
      if((doublecol = (char*)strchr((const char*)ndpi_flow->host_server_name, delimiter)) != NULL)
	doublecol[0] = '\0';

      if(srv_host && (ndpi_flow->detected_os[0] != '\0') && cli_host)
	cli_host->setOS((char*)ndpi_flow->detected_os);
    }
    break;
  } /* switch */

  if(protocol_processed
     /* For DNS we delay the memory free so that we can let nDPI analyze all the packets of the flow */
     && (l7proto != NDPI_PROTOCOL_DNS))
    deleteFlowMemory();

  makeVerdict();

#ifdef NTOPNG_PRO
  if(!l7_protocol_guessed)
    ntop->getFlowChecker()->flowCheck(this);
#endif
}

/* *************************************** */

/* This method is used to decide whether this flow must pass or not */

void Flow::makeVerdict() {
#ifdef NTOPNG_PRO
  if(ntop->getPro()->has_valid_license() && get_cli_host() && get_srv_host()) {
    if(get_cli_host()->doDropProtocol(ndpi_detected_protocol)
       || get_srv_host()->doDropProtocol(ndpi_detected_protocol))
      setDropVerdict();
  }
#endif
}

/* *************************************** */

void Flow::guessProtocol() {
  detection_completed = true; /* We give up */

  if((protocol == IPPROTO_TCP) || (protocol == IPPROTO_UDP)) {
    if(cli_host && srv_host) {
      /* We can guess the protocol */
      ndpi_detected_protocol = ndpi_guess_undetected_protocol(iface->get_ndpi_struct(), protocol,
							      ntohl(cli_host->get_ip()->get_ipv4()),
							      ntohs(cli_port),
							      ntohl(srv_host->get_ip()->get_ipv4()),
							      ntohs(srv_port));
    }

    l7_protocol_guessed = true;
  }
}

/* *************************************** */

void Flow::setDetectedProtocol(ndpi_protocol proto_id) {
  if((ndpi_flow != NULL)
     || (!iface->is_ndpi_enabled())) {
    if(proto_id.protocol != NDPI_PROTOCOL_UNKNOWN) {
      ndpi_detected_protocol = proto_id;
      processDetectedProtocol();
    } else if((((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
	       && (cli_host != NULL)
	       && (srv_host != NULL))
	      || (!iface->is_ndpi_enabled())) {
      guessProtocol();
    }

    detection_completed = true;
    
#ifdef NTOPNG_PRO
    updateProfile();
#endif
  }
}

/* *************************************** */

#ifdef NTOPNG_PRO
void Flow::updateProfile() {
  profileId = ntop->getPrefs()->getFlowProfile(this);
}
#endif

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


/* *************************************** */

void Flow::print_peers(lua_State* vm, patricia_tree_t * ptree, bool verbose) {
  char buf1[64], buf2[64], buf[256];
  Host *src = get_cli_host(), *dst = get_srv_host();

  if((src == NULL) || (dst == NULL)) return;

  if((!src->match(ptree)) && (!dst->match(ptree)))
    return;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "client", get_cli_host()->get_ip()->print(buf, sizeof(buf)));
  lua_push_int_table_entry(vm, "client.vlan", get_cli_host()->get_vlan_id());
  lua_push_str_table_entry(vm, "server", get_srv_host()->get_ip()->print(buf, sizeof(buf)));
  lua_push_int_table_entry(vm, "server.vlan", get_srv_host()->get_vlan_id());
  lua_push_int_table_entry(vm, "sent", cli2srv_bytes);
  lua_push_int_table_entry(vm, "rcvd", srv2cli_bytes);
  lua_push_int_table_entry(vm, "sent.last", get_current_bytes_cli2srv());
  lua_push_int_table_entry(vm, "rcvd.last", get_current_bytes_srv2cli());
  lua_push_int_table_entry(vm, "duration", get_duration());


  lua_push_float_table_entry(vm, "client.latitude", get_cli_host()->get_latitude());
  lua_push_float_table_entry(vm, "client.longitude", get_cli_host()->get_longitude());
  lua_push_float_table_entry(vm, "server.latitude", get_srv_host()->get_latitude());
  lua_push_float_table_entry(vm, "server.longitude", get_srv_host()->get_longitude());

  if(verbose) {
    lua_push_bool_table_entry(vm, "client.private", get_cli_host()->get_ip()->isPrivateAddress());
    lua_push_str_table_entry(vm,  "client.country", get_cli_host()->get_country() ? get_cli_host()->get_country() : (char*)"");
    lua_push_bool_table_entry(vm, "server.private", get_srv_host()->get_ip()->isPrivateAddress());
    lua_push_str_table_entry(vm,  "server.country", get_srv_host()->get_country() ? get_srv_host()->get_country() : (char*)"");
    lua_push_str_table_entry(vm,  "client.city", get_cli_host()->get_city() ? get_cli_host()->get_city() : (char*)"");
    lua_push_str_table_entry(vm,  "server.city", get_srv_host()->get_city() ? get_srv_host()->get_city() : (char*)"");

    if(verbose) {
      if(((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
	 || (ndpi_detected_protocol.protocol != NDPI_PROTOCOL_UNKNOWN)
	 || iface->is_ndpi_enabled()
	 || iface->is_sprobe_interface())
	lua_push_str_table_entry(vm, "proto.ndpi", get_detected_protocol_name());
      else
	lua_push_str_table_entry(vm, "proto.ndpi", (char*)CONST_TOO_EARLY);
    }
  }

  // Key
  /* Too slow */
#if 0
  snprintf(buf, sizeof(buf), "%s %s",
	   src->Host::get_name(buf1, sizeof(buf1), false),
	   dst->Host::get_name(buf2, sizeof(buf2), false));
#else
  /*Use the ip@vlan_id as a key only in case of multi vlan_id, otherwise use only the ip as a key*/
  if((get_cli_host()->get_vlan_id() == 0) && (get_srv_host()->get_vlan_id() == 0)) {
    snprintf(buf, sizeof(buf), "%s %s",
	     intoaV4(ntohl(get_cli_ipv4()), buf1, sizeof(buf1)),
	     intoaV4(ntohl(get_srv_ipv4()), buf2, sizeof(buf2)));
  } else {
    snprintf(buf, sizeof(buf), "%s@%d %s@%d",
	     intoaV4(ntohl(get_cli_ipv4()), buf1, sizeof(buf1)),
	     get_cli_host()->get_vlan_id(),
	     intoaV4(ntohl(get_srv_ipv4()), buf2, sizeof(buf2)),
	     get_srv_host()->get_vlan_id());
  }
#endif

  lua_pushstring(vm, buf);
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

char* Flow::print(char *buf, u_int buf_len) {
  char buf1[32], buf2[32];

  buf[0] = '\0';

  if((cli_host == NULL) || (srv_host == NULL)) return(buf);

  snprintf(buf, buf_len,
	   "%s %s:%u > %s:%u [proto: %u/%s][%u/%u pkts][%llu/%llu bytes]\n",
	   get_protocol_name(),
	   cli_host->get_ip()->print(buf1, sizeof(buf1)), ntohs(cli_port),
	   srv_host->get_ip()->print(buf2, sizeof(buf2)), ntohs(srv_port),
	   ndpi_detected_protocol.protocol, get_detected_protocol_name(),
	   cli2srv_packets, srv2cli_packets,
	   (long long unsigned) cli2srv_bytes, (long long unsigned) srv2cli_bytes);

  return(buf);
}

/* *************************************** */

bool Flow::dumpFlow(bool partial_dump) {
  bool rc = false;

  if(ntop->getPrefs()->do_dump_flows_on_mysql()
     || ntop->getPrefs()->do_dump_flows_on_es()
     || ntop->get_export_interface()) {

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

void Flow::update_hosts_stats(struct timeval *tv) {
  u_int64_t sent_packets, sent_bytes, rcvd_packets, rcvd_bytes;
  u_int64_t diff_sent_packets, diff_sent_bytes, diff_rcvd_packets, diff_rcvd_bytes;
  bool updated = false;
  bool cli_and_srv_in_same_subnet = false;
  u_int16_t cli_network_id;
  u_int16_t srv_network_id;
  NetworkStats *cli_network_stats;
  NetworkStats *srv_network_stats;

  if(check_tor) {
    char rsp[256];

    if(ntop->getRedis()->getAddress(ssl.certificate, rsp, sizeof(rsp), false) == 0) {
      if(rsp[0] == '\0') /* Cached failed resolution */
	ndpi_detected_protocol.protocol = NDPI_PROTOCOL_TOR;

      check_tor = false; /* This is a valid host */
    } else {
      if((tv->tv_sec - last_seen) > 30) {
	/* We give up */
	check_tor = false; /* This is a valid host */
      }
    }
  }
  sent_packets = cli2srv_packets, sent_bytes = cli2srv_bytes;
  diff_sent_packets = sent_packets - cli2srv_last_packets, diff_sent_bytes = sent_bytes - cli2srv_last_bytes;
  prev_cli2srv_last_bytes = cli2srv_last_bytes, prev_cli2srv_last_packets = cli2srv_last_packets;
  cli2srv_last_packets = sent_packets, cli2srv_last_bytes = sent_bytes;

  rcvd_packets = srv2cli_packets, rcvd_bytes = srv2cli_bytes;
  diff_rcvd_packets = rcvd_packets - srv2cli_last_packets, diff_rcvd_bytes = rcvd_bytes - srv2cli_last_bytes;
  prev_srv2cli_last_bytes = srv2cli_last_bytes, prev_srv2cli_last_packets = srv2cli_last_packets;
  srv2cli_last_packets = rcvd_packets, srv2cli_last_bytes = rcvd_bytes;

  if(cli_network_id >= 0 && (cli_network_id == cli_network_id))
    cli_and_srv_in_same_subnet = true;

  if(diff_sent_packets || diff_rcvd_packets) {
    if(cli_host) {
      cli_network_id = cli_host->get_local_network_id();
      cli_network_stats = cli_host->getNetworkStats(cli_network_id);
      cli_host->incStats(protocol, ndpi_detected_protocol.protocol,
			 diff_sent_packets, diff_sent_bytes,
			 diff_rcvd_packets, diff_rcvd_bytes);
      // update per-subnet byte counters
      if(cli_network_stats){ // only if the network is known and local
        if(!cli_and_srv_in_same_subnet){
            cli_network_stats->incEgress(diff_sent_bytes);
            cli_network_stats->incIngress(diff_rcvd_bytes);
        } else // client and server ARE in the same subnet
            // need to update the inner counter (just one time, will intentionally skip this for srv_host)
            cli_network_stats->incInner(diff_sent_bytes + diff_rcvd_bytes);
      }
      if(srv_host && cli_host->isLocalHost()){
        cli_host->incHitter(srv_host, diff_sent_bytes, diff_rcvd_bytes);
      }
      if(srv_host && cli_host->isLocalHost())
	cli_host->incHitter(srv_host, diff_sent_bytes, diff_rcvd_bytes);
    }

    if(srv_host) {
      srv_network_id = srv_host->get_local_network_id();
      srv_network_stats = srv_host->getNetworkStats(srv_network_id);
      srv_host->incStats(protocol, ndpi_detected_protocol.protocol,
			 diff_rcvd_packets, diff_rcvd_bytes,
			 diff_sent_packets, diff_sent_bytes);
      if(srv_network_stats){ // local and known server network
          if(!cli_and_srv_in_same_subnet){
              srv_network_stats->incIngress(diff_sent_bytes);
              srv_network_stats->incEgress(diff_rcvd_bytes);
          }
      }

      if(cli_host && srv_host->isLocalHost())
	srv_host->incHitter(cli_host, diff_rcvd_bytes, diff_sent_bytes);

      if(host_server_name
	 && (ndpi_is_proto(ndpi_detected_protocol, NDPI_PROTOCOL_HTTP)
	     || ndpi_is_proto(ndpi_detected_protocol, NDPI_PROTOCOL_HTTP_PROXY))) {
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

    if(tdiff_msec >= 1000 /* Do not updated when less than 1 second (1000 msec) */) {
      // bps
      u_int64_t diff_bytes = cli2srv_last_bytes+srv2cli_last_bytes-prev_cli2srv_last_bytes-prev_srv2cli_last_bytes;
      float bytes_msec = ((float)(diff_bytes*1000))/tdiff_msec;

      if(bytes_msec < 0) bytes_msec = 0; /* Just to be safe */

      if((bytes_msec > 0) || iface->is_packet_interface()) {
	if(bytes_thpt < bytes_msec)      bytes_thpt_trend = trend_up;
	else if(bytes_thpt > bytes_msec) bytes_thpt_trend = trend_down;
	else                             bytes_thpt_trend = trend_stable;

	if(false)
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[msec: %.1f][bytes: %lu][bits_thpt: %.4f Mbps]",
				       bytes_msec, diff_bytes, (bytes_thpt*8)/((float)(1024*1024)));

	bytes_thpt = bytes_msec;
	if(top_bytes_thpt < bytes_thpt) top_bytes_thpt = bytes_thpt;

	// pps
	u_int64_t diff_pkts = cli2srv_last_packets+srv2cli_last_packets-prev_cli2srv_last_packets-prev_srv2cli_last_packets;
	float pkts_msec = ((float)(diff_pkts*1000))/tdiff_msec;

	if(pkts_msec < 0) pkts_msec = 0; /* Just to be safe */

	if(pkts_thpt < pkts_msec)      pkts_thpt_trend = trend_up;
	else if(pkts_thpt > pkts_msec) pkts_thpt_trend = trend_down;
	else                           pkts_thpt_trend = trend_stable;

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
      last_db_dump.srv2cli_bytes = srv2cli_bytes, last_db_dump.last_dump = last_seen;
  }

  checkBlacklistedFlow();
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

void Flow::lua(lua_State* vm, patricia_tree_t * ptree, bool detailed_dump,
               enum flowsSelector selector) {
  char buf[64];
  Host *src = get_cli_host(), *dst = get_srv_host();
  bool src_match, dst_match;
  u_int32_t k;

  if((src == NULL) || (dst == NULL)) return;

  src_match = src->match(ptree), dst_match = dst->match(ptree);
  if((!src_match) && (!dst_match))return;

  lua_newtable(vm);

  switch(selector) {
  case FS_PORTS:
    if(src) {
      lua_push_str_table_entry(vm, "cli.ip", get_cli_host()->get_ip()->print(buf, sizeof(buf)));
      lua_push_int_table_entry(vm, "cli.key", get_cli_host()->key());
    } else {
      lua_push_nil_table_entry(vm, "cli.ip");
      lua_push_nil_table_entry(vm, "cli.key");
    }
    lua_push_int_table_entry(vm, "cli.port", get_cli_port());

    if (dst) {
      lua_push_str_table_entry(vm, "srv.ip", get_srv_host()->get_ip()->print(buf, sizeof(buf)));
      lua_push_int_table_entry(vm, "srv.key", get_srv_host()->key());
    } else {
      lua_push_nil_table_entry(vm, "srv.ip");
      lua_push_nil_table_entry(vm, "srv.key");
    }

    lua_push_int_table_entry(vm, "srv.port", get_srv_port());
    lua_push_int_table_entry(vm, "bytes", cli2srv_bytes+srv2cli_bytes);

    k = key();
    lua_pushnumber(vm, k); // Index
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    break;
  case FS_ALL:
    if(src) {
      if(detailed_dump) lua_push_str_table_entry(vm, "cli.host", get_cli_host()->get_name(buf, sizeof(buf), false));
      lua_push_int_table_entry(vm, "cli.source_id", get_cli_host()->getSourceId());
      lua_push_str_table_entry(vm, "cli.ip", get_cli_host()->get_ip()->print(buf, sizeof(buf)));
      lua_push_int_table_entry(vm, "cli.key", get_cli_host()->key());

      lua_push_bool_table_entry(vm, "cli.systemhost", get_cli_host()->isSystemHost());
      lua_push_bool_table_entry(vm, "cli.allowed_host", src_match);
      lua_push_int32_table_entry(vm, "cli.network_id", get_cli_host()->get_local_network_id());
    } else {
      lua_push_nil_table_entry(vm, "cli.host");
      lua_push_nil_table_entry(vm, "cli.ip");
      lua_push_nil_table_entry(vm, "cli.key");
    }

    lua_push_int_table_entry(vm, "cli.port", get_cli_port());

    if(dst) {
      if(detailed_dump) lua_push_str_table_entry(vm, "srv.host", get_srv_host()->get_name(buf, sizeof(buf), false));
      lua_push_int_table_entry(vm, "srv.source_id", get_cli_host()->getSourceId());
      lua_push_str_table_entry(vm, "srv.ip", get_srv_host()->get_ip()->print(buf, sizeof(buf)));
      lua_push_int_table_entry(vm, "srv.key", get_srv_host()->key());
      lua_push_bool_table_entry(vm, "srv.systemhost", get_srv_host()->isSystemHost());
      lua_push_bool_table_entry(vm, "srv.allowed_host", dst_match);
      lua_push_int32_table_entry(vm, "srv.network_id", get_srv_host()->get_local_network_id());
    } else {
      lua_push_nil_table_entry(vm, "srv.host");
      lua_push_nil_table_entry(vm, "srv.ip");
    }

    lua_push_int_table_entry(vm, "srv.port", get_srv_port());
    lua_push_int_table_entry(vm, "vlan", get_vlan_id());
    lua_push_str_table_entry(vm, "proto.l4", get_protocol_name());

    if(((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
       || (ndpi_detected_protocol.protocol != NDPI_PROTOCOL_UNKNOWN)
       || iface->is_ndpi_enabled()
       || iface->is_sprobe_interface()) {
      lua_push_str_table_entry(vm, "proto.ndpi", get_detected_protocol_name());
    } else {
      lua_push_str_table_entry(vm, "proto.ndpi", (char*)CONST_TOO_EARLY);
    }
    lua_push_str_table_entry(vm, "proto.ndpi_breed", get_protocol_breed_name());

    if(detailed_dump && ntop->get_categorization()) {
      categorizeFlow();
      if(categorization.category[0] != '\0')
	lua_push_str_table_entry(vm, "category", categorization.category);
    }

#ifdef NTOPNG_PRO
    if(profileId != -1) lua_push_str_table_entry(vm, "profile", ntop->getPrefs()->getProfileName(profileId, buf, sizeof(buf)));
#endif

    lua_push_int_table_entry(vm, "bytes", cli2srv_bytes+srv2cli_bytes);
    lua_push_int_table_entry(vm, "bytes.last", get_current_bytes_cli2srv() + get_current_bytes_srv2cli());
    lua_push_int_table_entry(vm, "packets", cli2srv_packets+srv2cli_packets);
    lua_push_int_table_entry(vm, "packets.last", get_current_packets_cli2srv() + get_current_packets_srv2cli());
    lua_push_int_table_entry(vm, "seen.first", get_first_seen());
    lua_push_int_table_entry(vm, "seen.last", get_last_seen());
    lua_push_int_table_entry(vm, "duration", get_duration());

    lua_push_int_table_entry(vm, "cli2srv.bytes", cli2srv_bytes);
    lua_push_int_table_entry(vm, "srv2cli.bytes", srv2cli_bytes);

    lua_push_int_table_entry(vm, "cli2srv.packets", cli2srv_packets);
    lua_push_int_table_entry(vm, "srv2cli.packets", srv2cli_packets);
    lua_push_bool_table_entry(vm, "verdict.pass", isPassVerdict());
    lua_push_bool_table_entry(vm, "dump.disk", getDumpFlowTraffic());

    if(detailed_dump) {
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
      }

      if(host_server_name) lua_push_str_table_entry(vm, "host_server_name", host_server_name);
      lua_push_int_table_entry(vm, "tcp_flags", getTcpFlags());

      if(protocol == IPPROTO_TCP) {
        lua_push_int_table_entry(vm, "cli2srv.retransmissions", tcp_stats_s2d.pktRetr);
        lua_push_int_table_entry(vm, "cli2srv.out_of_order", tcp_stats_s2d.pktOOO);
        lua_push_int_table_entry(vm, "cli2srv.lost", tcp_stats_s2d.pktLost);
        lua_push_int_table_entry(vm, "srv2cli.retransmissions", tcp_stats_d2s.pktRetr);
        lua_push_int_table_entry(vm, "srv2cli.out_of_order", tcp_stats_d2s.pktOOO);
        lua_push_int_table_entry(vm, "srv2cli.lost", tcp_stats_d2s.pktLost);
      }

      if(http.last_method && http.last_url) {
        lua_push_str_table_entry(vm, "http.last_method", http.last_method);
        lua_push_int_table_entry(vm, "http.last_return_code", http.last_return_code);
      }

      /* Shapers */
      if(cli_host && srv_host) {
	int a, b;

	getFlowShapers(true, &a, &b);
	lua_push_int_table_entry(vm, "shaper.cli2srv_a", a);
	lua_push_int_table_entry(vm, "shaper.cli2srv_b", b);

	getFlowShapers(false, &a, &b);
	lua_push_int_table_entry(vm, "shaper.srv2cli_a", a);
	lua_push_int_table_entry(vm, "shaper.srv2cli_b", b);
      }
    }

    if(http.last_method && http.last_url)
      lua_push_str_table_entry(vm, "http.last_url", http.last_url);

    if(host_server_name)
      lua_push_str_table_entry(vm, "http.server_name", host_server_name);

    if(dns.last_query)
      lua_push_str_table_entry(vm, "dns.last_query", dns.last_query);

    if(ssl.certificate)
      lua_push_str_table_entry(vm, "ssl.certificate", ssl.certificate);

    lua_push_str_table_entry(vm, "moreinfo.json", get_json_info());

    if(client_proc) processLua(vm, client_proc, true);
    if(server_proc) processLua(vm, server_proc, false);

    lua_push_float_table_entry(vm, "top_throughput_bps", top_bytes_thpt);
    lua_push_float_table_entry(vm, "throughput_bps", bytes_thpt);
    lua_push_int_table_entry(vm, "throughput_trend_bps", bytes_thpt_trend);
    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[bytes_thpt: %.2f] [bytes_thpt_trend: %d]", bytes_thpt,bytes_thpt_trend);

    lua_push_float_table_entry(vm, "top_throughput_pps", top_pkts_thpt);
    lua_push_float_table_entry(vm, "throughput_pps", pkts_thpt);
    lua_push_int_table_entry(vm, "throughput_trend_pps", pkts_thpt_trend);
    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[pkts_thpt: %.2f] [pkts_thpt_trend: %d]", pkts_thpt,pkts_thpt_trend);

    if(!detailed_dump) {
      k = key();

      lua_pushnumber(vm, k); // Index
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    } else {
      lua_push_int_table_entry(vm, "cli2srv.packets", cli2srv_packets);
      lua_push_int_table_entry(vm, "srv2cli.packets", srv2cli_packets);
    }
    break;
  default:
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Bad selector to flow lua()");
  }
}

/* *************************************** */

u_int32_t Flow::key() {
  u_int32_t k = cli_port+srv_port+vlanId+protocol;

  if(cli_host) k += cli_host->key();
  if(srv_host) k += srv_host->key();

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

char* Flow::getFlowCategory(bool force_categorization) {
  if(!categorization.categorized_requested) {
    if(ndpi_flow == NULL)
      categorization.categorized_requested = true;
    else if(host_server_name && (host_server_name[0] != '\0')) {
      if(!Utils::isGoodNameToCategorize(host_server_name))
	categorization.categorized_requested = true;
      else
	categorizeFlow();
    }
  }

  return(categorization.category);
}

/* *************************************** */

void Flow::sumStats(nDPIStats *stats) {
  stats->incStats(ndpi_detected_protocol.protocol,
		  cli2srv_packets, cli2srv_bytes,
		  srv2cli_packets, srv2cli_bytes);
}

/* *************************************** */

char* Flow::serialize(bool partial_dump, bool es_json) {
  json_object *my_object;
  char *rsp;

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

/* *************************************** */

json_object* Flow::flow2json(bool partial_dump) {
  json_object *my_object;
  char buf[64], jsonbuf[64], *c;
  struct tm* tm_info;
  time_t t;

  if(((cli2srv_packets - last_db_dump.cli2srv_packets) == 0)
     && ((srv2cli_packets - last_db_dump.srv2cli_packets) == 0))
    return(NULL);

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  if (ntop->getPrefs()->do_dump_flows_on_es()) {
    t = last_seen;
    tm_info = gmtime(&t);

    strftime(buf, sizeof(buf), "%FT%T.0Z", tm_info);
    json_object_object_add(my_object, "@timestamp", json_object_new_string(buf));
    /* json_object_object_add(my_object, "@version", json_object_new_int(1)); */
    json_object_object_add(my_object, "type", json_object_new_string(ntop->getPrefs()->get_es_type()));
  }

  json_object_object_add(my_object, Utils::jsonLabel(IPV4_SRC_ADDR, "IPV4_SRC_ADDR", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_string(cli_host->get_string_key(buf, sizeof(buf))));
  json_object_object_add(my_object, Utils::jsonLabel(L4_SRC_PORT, "L4_SRC_PORT", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(get_cli_port()));

  json_object_object_add(my_object, Utils::jsonLabel(IPV4_DST_ADDR, "IPV4_DST_ADDR", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_string(srv_host->get_string_key(buf, sizeof(buf))));
  json_object_object_add(my_object, Utils::jsonLabel(L4_DST_PORT, "L4_DST_PORT", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(get_srv_port()));

  json_object_object_add(my_object, Utils::jsonLabel(PROTOCOL, "PROTOCOL", jsonbuf, sizeof(jsonbuf)),
			 json_object_new_int(protocol));

  if(((cli2srv_packets+srv2cli_packets) > NDPI_MIN_NUM_PACKETS)
     || (ndpi_detected_protocol.protocol != NDPI_PROTOCOL_UNKNOWN)) {
    json_object_object_add(my_object, Utils::jsonLabel(L7_PROTO, "L7_PROTO", jsonbuf, sizeof(jsonbuf)),
			   json_object_new_int(ndpi_detected_protocol.protocol));
    json_object_object_add(my_object, Utils::jsonLabel(L7_PROTO_NAME, "L7_PROTO_NAME", jsonbuf, sizeof(jsonbuf)),
                           json_object_new_string(get_detected_protocol_name()));
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

    if((o = json_tokener_parse(json_info)) != NULL)
      json_object_object_add(my_object, "json", o);
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error: %s", json_info);
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

  if(categorization.categorized_requested && (categorization.category[0] != '\0'))
    json_object_object_add(my_object, "category", json_object_new_string(categorization.category));

  if(dns.last_query) json_object_object_add(my_object, "DNS_QUERY", json_object_new_string(dns.last_query));

  if(http.last_url && http.last_method) {
    if(host_server_name && (host_server_name[0] != '\0'))
      json_object_object_add(my_object, "HTTP_HOST", json_object_new_string(host_server_name));
    json_object_object_add(my_object, "HTTP_URL", json_object_new_string(http.last_url));
    json_object_object_add(my_object, "HTTP_METHOD", json_object_new_string(http.last_method));
    json_object_object_add(my_object, "HTTP_RET_CODE", json_object_new_int((u_int32_t)http.last_return_code));
  }

  if(ssl.certificate)
    json_object_object_add(my_object, "SSL_CERTIFICATE", json_object_new_string(ssl.certificate));

  json_object_object_add(my_object, "PASS_VERDICT", json_object_new_boolean(passVerdict ? (json_bool)1 : (json_bool)0));

  return(my_object);
}

/* *************************************** */

void Flow::incStats(bool cli2srv_direction, u_int pkt_len) {
  updateSeen();

  if((cli_host == NULL) || (srv_host == NULL)) return;

  if(cli2srv_direction) {
    cli2srv_packets++, cli2srv_bytes += pkt_len;
    cli_host->get_sent_stats()->incStats(pkt_len), srv_host->get_recv_stats()->incStats(pkt_len);
  } else {
    srv2cli_packets++, srv2cli_bytes += pkt_len;
    cli_host->get_recv_stats()->incStats(pkt_len), srv_host->get_sent_stats()->incStats(pkt_len);
  }
};

/* *************************************** */

void Flow::updateInterfaceStats(bool src2dst_direction, u_int num_pkts, u_int pkt_len) {
  Host *from = src2dst_direction ? cli_host : srv_host;
  Host *to = src2dst_direction ? srv_host : cli_host;

  iface->updateLocalStats(num_pkts, pkt_len,
			  from ? from->isLocalHost() : false,
			  to ? to->isLocalHost() : false);
}

/* *************************************** */

void Flow::updateActivities() {
  if(cli_host) cli_host->updateActivities();
  if(srv_host) srv_host->updateActivities();
}

/* *************************************** */

void Flow::addFlowStats(bool cli2srv_direction, u_int in_pkts, u_int in_bytes,
			u_int out_pkts, u_int out_bytes, time_t last_seen) {
  updateSeen(last_seen);

  if(cli2srv_direction)
    cli2srv_packets += in_pkts, cli2srv_bytes += in_bytes, srv2cli_packets += out_pkts, srv2cli_bytes += out_bytes;
  else
    cli2srv_packets += out_pkts, cli2srv_bytes += out_bytes, srv2cli_packets += in_pkts, srv2cli_bytes += in_bytes;

  updateActivities();
}

/* *************************************** */

void Flow::updateTcpFlags(

#ifdef __OpenBSD__
			  const struct bpf_timeval *when,
#else
			  const struct timeval *when,
#endif
			  u_int8_t flags, bool src2dst_direction) {

#if 0
  if((flags == TH_SYN)
     && ((src2dst_tcp_flags | dst2src_tcp_flags) == TH_SYN) /* SYN was already received */
     && (cli2srv_packets > 2 /* We tolerate two SYN at the beginning of the connection */)
     && ((last_seen-first_seen) < 2 /* (sec) SYN flood must be quick */)
     && cli_host)
    cli_host->updateSynFlags(when->tv_sec, flags, this, true);
#else
  if(flags == TH_SYN) {
    if(cli_host) cli_host->updateSynFlags(when->tv_sec, flags, this, true);
    if(srv_host) srv_host->updateSynFlags(when->tv_sec, flags, this, false);
  }
#endif

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
	if(synTime.tv_sec > 0) {
	  timeval_diff(&synTime, (struct timeval*)when, &serverNwLatency, 1);

	  /* Sanity check */
	  if(serverNwLatency.tv_sec > 5) memset(&serverNwLatency, 0, sizeof(serverNwLatency));
	}
      }
    } else if(flags == TH_ACK) {
      if((ackTime.tv_sec == 0) && (synAckTime.tv_sec > 0)) {
	memcpy(&ackTime, when, sizeof(struct timeval));
	if(synAckTime.tv_sec > 0) {
	  timeval_diff(&synAckTime, (struct timeval*)when, &clientNwLatency, 1);

	  /* Sanity check */
	  if(clientNwLatency.tv_sec > 5) memset(&clientNwLatency, 0, sizeof(clientNwLatency));
	}
      }
    } else
      twh_over = true;
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

void Flow::updateTcpSeqNum(
#ifdef __OpenBSD__
			   const struct bpf_timeval *when,
#else
			   const struct timeval *when,
#endif
			   u_int32_t seq_num,
			   u_int32_t ack_seq_num, u_int8_t flags,
			   u_int16_t payload_Len, bool src2dst_direction) {
  u_int32_t next_seq_num;
  bool update_last_seqnum = true;
  bool debug = false;

  next_seq_num = getNextTcpSeq(flags, seq_num, payload_Len);

  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[act: %u][ack: %u]", seq_num, ack_seq_num);

  if(src2dst_direction == true) {
    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[last: %u][next: %u]", tcp_stats_s2d.last, tcp_stats_s2d.next);

    if(tcp_stats_s2d.next > 0) {
      if((tcp_stats_s2d.next != seq_num)
	 && (tcp_stats_s2d.next != (seq_num-1))) {
	if(tcp_stats_s2d.last == seq_num) {
	  tcp_stats_s2d.pktRetr++, cli_host->incRetransmittedPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet retransmission");
	} else if((tcp_stats_s2d.last > seq_num)
		  && (seq_num < tcp_stats_s2d.next)) {
	  tcp_stats_s2d.pktLost++, cli_host->incLostPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet lost [last: %u][act: %u]", tcp_stats_s2d.last, seq_num);
	} else {
	  tcp_stats_s2d.pktOOO++, cli_host->incOOOPkts(1);

	  update_last_seqnum = ((seq_num - 1) > tcp_stats_s2d.last) ? true : false;
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet OOO [last: %u][act: %u]", tcp_stats_s2d.last, seq_num);
	}
      }
    }

    tcp_stats_s2d.next = next_seq_num;
    if(update_last_seqnum) tcp_stats_s2d.last = seq_num;
  } else {
    if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "[last: %u][next: %u]", tcp_stats_d2s.last, tcp_stats_d2s.next);

    if(tcp_stats_d2s.next > 0) {
      if((tcp_stats_d2s.next != seq_num)
	 && (tcp_stats_d2s.next != (seq_num-1))) {
	if(tcp_stats_d2s.last == seq_num) {
	  tcp_stats_d2s.pktRetr++, srv_host->incRetransmittedPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet retransmission");
	  // bytes
	} else if((tcp_stats_d2s.last > seq_num)
		  && (seq_num < tcp_stats_d2s.next)) {
	  tcp_stats_d2s.pktLost++, srv_host->incLostPkts(1);
	  if(debug) ntop->getTrace()->traceEvent(TRACE_WARNING, "Packet lost [last: %u][act: %u]", tcp_stats_d2s.last, seq_num);
	} else {
	  tcp_stats_d2s.pktOOO++, srv_host->incOOOPkts(1);
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

void Flow::dissectHTTP(bool src2dst_direction, char *payload, u_int16_t payload_len) {
  HTTPStats *h;

  if(src2dst_direction) {
    char *space;

    // payload[10]=0; ntop->getTrace()->traceEvent(TRACE_WARNING, "[len: %u][%s]", payload_len, payload);
    h = cli_host->getHTTPStats(); if(h) h->incRequest(payload); /* Sent */
    h = srv_host->getHTTPStats(); if(h) h->incRequest(payload); /* Rcvd */
    dissect_next_http_packet = true;

    if(payload && ((space = strchr(payload, ' ')) != NULL)) {
      u_int l = space-payload;

      if((!strncmp(payload, "GET", 3))
	 || (!strncmp(payload, "POST", 4))
	 || (!strncmp(payload, "HEAD", 4))
	 || (!strncmp(payload, "PUT", 3))
	 ) {
	diff_num_http_requests++; /* One new request found */

	if(http.last_method) free(http.last_method);
	if((http.last_method = (char*)malloc(l+1)) != NULL) {
	  strncpy(http.last_method, payload, l);
	  http.last_method[l] = '\0';
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

	  if(http.last_url) free(http.last_url);
	  if((http.last_url = (char*)malloc(l+1)) != NULL) {
	    strncpy(http.last_url, payload, l);
	    http.last_url[l] = '\0';
	  }
	}
      }
    }
  } else {
    if(dissect_next_http_packet) {
      char *space;

      // payload[10]=0; ntop->getTrace()->traceEvent(TRACE_WARNING, "[len: %u][%s]", payload_len, payload);
      h = cli_host->getHTTPStats(); if(h) h->incResponse(payload); /* Rcvd */
      h = srv_host->getHTTPStats(); if(h) h->incResponse(payload); /* Sent */
      dissect_next_http_packet = false;

      if((space = strchr(payload, ' ')) != NULL) {
	payload = &space[1];
	if((space = strchr(payload, ' ')) != NULL) {
	  char tmp[32];
	  int l = min_val((int)(space-payload), (int)(sizeof(tmp)-1));

	  strncpy(tmp, payload, l);
	  tmp[l] = 0;
	  http.last_return_code = atoi(tmp);
	}
      }
    }
  }
}

/* *************************************** */

bool Flow::isPassVerdict() {
  if(!passVerdict) return(passVerdict);

  /* TODO: isAboveQuota() must be checked periodically */
  if(cli_host && srv_host)
    return(!(cli_host->isAboveQuota() || srv_host->isAboveQuota()) &&
           !(cli_host->dropAllTraffic() || srv_host->dropAllTraffic()));
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
  if((categorization.category[0] == '\0')
     || (!strcmp(categorization.category, CATEGORIZATION_SAFE_SITE)))
    return;
  else {
    char c_buf[64], s_buf[64], *c, *s, alert_msg[1024];

    /* Emit alarm */
    c = cli_host->get_ip()->print(c_buf, sizeof(c_buf));
    s = srv_host->get_ip()->print(s_buf, sizeof(s_buf));

    snprintf(alert_msg, sizeof(alert_msg),
	     "Flow <A HREF='/lua/host_details.lua?host=%s&ifname=%s'>%s</A>:%u &lt;-&gt; "
	     "<A HREF='/lua/host_details.lua?host=%s&ifname=%s'>%s</A>:%u"
	     " accessed malware site <A HREF=http://google.com/safebrowsing/diagnostic?site=%s&hl=en-us>%s</A>",
	     c, iface->get_name(), c, cli_port,
	     s, iface->get_name(), s, srv_port,
	     host_server_name, host_server_name);

    ntop->getRedis()->queueAlert(alert_level_warning, alert_malware_detection, alert_msg);
    badFlow = true, setDropVerdict();
  }
}

/* *************************************** */

char* Flow::get_detected_protocol_name() {
  if(!ndpi_proto_name) {
    char buf[64];

    ndpi_proto_name = strdup(ndpi_protocol2name(iface->get_ndpi_struct(),
						ndpi_detected_protocol,
						buf, sizeof(buf)));
  }

  return(ndpi_proto_name);
}

/* *************************************** */

void Flow::getFlowShapers(bool src2dst_direction,
			  int *a_shaper_id, int *b_shaper_id) {
  if(cli_host && srv_host) {
    if(src2dst_direction)
      *a_shaper_id = cli_host->get_egress_shaper_id(), *b_shaper_id = srv_host->get_ingress_shaper_id();
    else
      *a_shaper_id = srv_host->get_egress_shaper_id(), *b_shaper_id = cli_host->get_ingress_shaper_id();
  } else
    *a_shaper_id = *b_shaper_id = 0;
}
