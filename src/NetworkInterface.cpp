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

#ifdef __APPLE__
#include <uuid/uuid.h>
#endif

static bool help_printed = false;

/* **************************************** */

static void debug_printf(u_int32_t protocol, void *id_struct,
			 ndpi_log_level_t log_level,
			 const char *format, ...) {
}

/* **************************************** */

static void *malloc_wrapper(size_t size) { return malloc(size); }
static void free_wrapper(void *freeable) { free(freeable);      }

/* **************************************************** */

/* Method used for collateral activities */
NetworkInterface::NetworkInterface() {
  ifname = NULL, flows_hash = NULL, hosts_hash = NULL,
    ndpi_struct = NULL,
    purge_idle_flows_hosts = true, id = (u_int8_t)-1,
    sprobe_interface = false, has_vlan_packets = false,
    pcap_datalink_type = 0, cpu_affinity = -1 /* no affinity */,
    inline_interface = false, running = false,
    has_mesh_networks_traffic = false, pkt_dumper = NULL;
  pollLoopCreated = false, bridge_interface = false;
  if(ntop->getPrefs()->are_taps_enabled())
    pkt_dumper_tap = new PacketDumperTuntap(this);
  else
    pkt_dumper_tap = NULL;

  has_mesh_networks_traffic = false,
    ip_addresses = "", networkStats = NULL,
    pcap_datalink_type = 0, cpu_affinity = -1,
    pkt_dumper = NULL, antenna_mac = NULL;

  memset(lastMinuteTraffic, 0, sizeof(lastMinuteTraffic));
  resetSecondTraffic();

  if(ntop->getPrefs()->do_dump_flows_on_mysql())
    db = new MySQLDB(this);
  else
    db = NULL;

#ifdef NTOPNG_PRO
  policer = NULL;
#endif

  statsManager = NULL, ifSpeed = 0;
  checkIdle();
  dump_all_traffic = dump_to_disk = dump_unknown_traffic = dump_security_packets = dump_to_tap = false;
  dump_sampling_rate = CONST_DUMP_SAMPLING_RATE;
  dump_max_pkts_file = CONST_MAX_NUM_PACKETS_PER_DUMP;
  dump_max_duration = CONST_MAX_DUMP_DURATION;
  dump_max_files = CONST_MAX_DUMP;
  ifMTU = CONST_DEFAULT_MTU, mtuWarningShown = false;
#ifdef NTOPNG_PRO
  flow_profiles = NULL;
#endif
}

/* **************************************************** */

NetworkInterface::NetworkInterface(const char *name) {
  NDPI_PROTOCOL_BITMASK all;
  char _ifname[64];

#ifdef WIN32
  if(name == NULL) name = "1"; /* First available interface */
#endif

  if(strcmp(name, "-") == 0) name = "stdin";

  if(ntop->getRedis())
    id = Utils::ifname2id(name);
  else
    id = -1;

  purge_idle_flows_hosts = true;

  if(name == NULL) {
    char pcap_error_buffer[PCAP_ERRBUF_SIZE];

    if(!help_printed)
      ntop->getTrace()->traceEvent(TRACE_WARNING, "No capture interface specified");

    printAvailableInterfaces(false, 0, NULL, 0);

    name = pcap_lookupdev(pcap_error_buffer);

    if(name == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to locate default interface (%s)\n",
				   pcap_error_buffer);
      exit(0);
    }
  } else {
    if(isNumber(name)) {
      /* We need to convert this numeric index into an interface name */
      int id = atoi(name);

      _ifname[0] = '\0';
      printAvailableInterfaces(false, id, _ifname, sizeof(_ifname));

      if(_ifname[0] == '\0') {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to locate interface Id %d", id);
	printAvailableInterfaces(false, 0, NULL, 0);
	exit(0);
      }
      name = _ifname;
    }
  }

  pkt_dumper_tap = NULL;
  ifname = strdup(name);

  if(id >= 0) {
    u_int32_t num_hashes;
    ndpi_port_range d_port[MAX_DEFAULT_PORTS];
    u_int16_t no_master[2] = { NDPI_PROTOCOL_NO_MASTER_PROTO, NDPI_PROTOCOL_NO_MASTER_PROTO };

    num_hashes = max_val(4096, ntop->getPrefs()->get_max_num_flows()/4);
    flows_hash = new FlowHash(this, num_hashes, ntop->getPrefs()->get_max_num_flows());

    num_hashes = max_val(4096, ntop->getPrefs()->get_max_num_hosts()/4);
    hosts_hash = new HostHash(this, num_hashes, ntop->getPrefs()->get_max_num_hosts());

    // init global detection structure
    ndpi_struct = ndpi_init_detection_module(ntop->getGlobals()->get_detection_tick_resolution(),
					     malloc_wrapper, free_wrapper, debug_printf);
    if(ndpi_struct == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Global structure initialization failed");
      exit(-1);
    }

    if(ntop->getCustomnDPIProtos() != NULL)
      ndpi_load_protocols_file(ndpi_struct, ntop->getCustomnDPIProtos());

    ndpi_struct->http_dont_dissect_response = 1;

    memset(d_port, 0, sizeof(d_port));
    ndpi_set_proto_defaults(ndpi_struct, NDPI_PROTOCOL_UNRATED, NTOPNG_NDPI_OS_PROTO_ID,
			    no_master, no_master,
			    (char*)"Operating System", d_port, d_port);

    // enable all protocols
    NDPI_BITMASK_SET_ALL(all);
    ndpi_set_protocol_detection_bitmask2(ndpi_struct, &all);

    last_pkt_rcvd = 0, pollLoopCreated = false, bridge_interface = false;
    next_idle_flow_purge = next_idle_host_purge = 0, antenna_mac = NULL;
    cpu_affinity = -1 /* no affinity */, has_vlan_packets = false, pkt_dumper = NULL;
    if(ntop->getPrefs()->are_taps_enabled())
      pkt_dumper_tap = new PacketDumperTuntap(this);

    running = false, sprobe_interface = false, inline_interface = false;

    if(ntop->getPrefs()->do_dump_flows_on_mysql())
      db = new MySQLDB(this);
    else
      db = NULL;

    checkIdle();
    ifSpeed = Utils::getMaxIfSpeed(name);
    ifMTU = Utils::getIfMTU(name), mtuWarningShown = false;
  } else {
    flows_hash = NULL, hosts_hash = NULL;
    ndpi_struct = NULL, db = NULL, ifSpeed = 0;
    pkt_dumper = NULL, pkt_dumper_tap = NULL;
  }

  networkStats = NULL,

#ifdef NTOPNG_PRO
  policer  = new L7Policer(this);
  flow_profiles = ntop->getPro()->has_valid_license() ? new FlowProfiles() : NULL;
  if(flow_profiles) flow_profiles->loadProfiles();
#endif

  loadDumpPrefs();

  statsManager = new StatsManager(id, "top_talkers.db");
}

/* **************************************************** */

void NetworkInterface::loadDumpPrefs() {
  if(ntop->getRedis() != NULL) {
    updateDumpAllTrafficPolicy();
    updateDumpTrafficDiskPolicy();
    updateDumpTrafficTapPolicy();
    updateDumpTrafficSamplingRate();
    updateDumpTrafficMaxPktsPerFile();
    updateDumpTrafficMaxSecPerFile();
    updateDumpTrafficMaxFiles();
  }
}

/* **************************************************** */

bool NetworkInterface::updateDumpTrafficTapPolicy(void) {
  bool retval = false;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_tap", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = !strncmp(rsp, "true", 5);
    else
      retval = false;
  }

  dump_to_tap = retval;
  return retval;
}

/* **************************************************** */

bool NetworkInterface::updateDumpAllTrafficPolicy(void) {
  bool retval = false;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_all_traffic", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = !strncmp(rsp, "true", 5);
  }

  dump_all_traffic = retval;
  return retval;
}

/* **************************************************** */

bool NetworkInterface::updateDumpTrafficDiskPolicy(void) {
  bool retval = false, retval_u = false, retval_s = false;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_disk", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = !strncmp(rsp, "true", 5);
    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_unknown_disk", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval_u = !strncmp(rsp, "true", 5);
    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_security_disk", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval_s = !strncmp(rsp, "true", 5);
  }

  dump_to_disk = retval;
  dump_unknown_traffic = retval_u;
  dump_security_packets = retval_s;
  return retval;
}

/* **************************************************** */

int NetworkInterface::updateDumpTrafficSamplingRate(void) {
  int retval = 1;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_sampling_rate", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = atoi(rsp);
  }

  dump_sampling_rate = retval;
  return retval;
}

/* **************************************************** */

int NetworkInterface::updateDumpTrafficMaxPktsPerFile(void) {
  int retval = 0;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_max_pkts_file", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = atoi(rsp);
  }

  retval = retval > 0 ? retval : CONST_MAX_NUM_PACKETS_PER_DUMP;

  dump_max_pkts_file = retval;
  return retval;
}

/* **************************************************** */

int NetworkInterface::updateDumpTrafficMaxSecPerFile(void) {
  int retval = 0;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_max_sec_file", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = atoi(rsp);
  }

  retval = retval > 0 ? retval : CONST_MAX_DUMP_DURATION;

  dump_max_duration = retval;

  return retval;
}

/* **************************************************** */

int NetworkInterface::updateDumpTrafficMaxFiles(void) {
  int retval = 0;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s.dump_max_files", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0)
      retval = atoi(rsp);
  }

  retval = retval > 0 ? retval : CONST_MAX_DUMP;

  dump_max_files = retval;

  return retval;
}

/* **************************************************** */

bool NetworkInterface::checkIdle() {
  is_idle = false;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s_not_idle", ifname);
    if(ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) {
      int val = atoi(rsp);

      if(val == 0) is_idle = true;
    }
  }

  return(is_idle);
}

/* **************************************************** */

void NetworkInterface::deleteDataStructures() {

  if(flows_hash)   { delete(flows_hash); flows_hash = NULL;     }
  if(hosts_hash)   { delete(hosts_hash); hosts_hash = NULL;     }

  if(ndpi_struct) {
    ndpi_exit_detection_module(ndpi_struct, free_wrapper);
    ndpi_struct = NULL;
  }

  if(ifname) {
    //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Interface %s shutdown", ifname);
    free(ifname);
    ifname = NULL;
  }

}

/* **************************************************** */

NetworkInterface::~NetworkInterface() {
  if(getNumPackets() > 0) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Flushing host contacts for interface %s",
				 get_name());
    cleanup();
  }

  deleteDataStructures();

  if(db) delete db;
  if(statsManager) delete statsManager;
  if(networkStats) delete []networkStats;
  if(pkt_dumper)   delete pkt_dumper;
  if(pkt_dumper_tap) delete pkt_dumper_tap;

#ifdef NTOPNG_PRO
  if(policer)  delete(policer);
  if(flow_profiles) delete(flow_profiles);
#endif
}

/* **************************************************** */

int NetworkInterface::dumpFlow(time_t when, bool partial_dump, Flow *f) {
  if(ntop->getPrefs()->do_dump_flows_on_mysql()) {
    return(dumpDBFlow(when, partial_dump, f));
  } else if(ntop->getPrefs()->do_dump_flows_on_es())
    return(dumpEsFlow(when, partial_dump, f));
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
    return(-1);
  }
}

/* **************************************************** */

int NetworkInterface::dumpEsFlow(time_t when, bool partial_dump, Flow *f) {
  char *json = f->serialize(partial_dump, true);
  int rc;

  if(json) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "[ES] %s", json);

    rc = ntop->getRedis()->lpush(CONST_ES_QUEUE_NAME, (char*)json, CONST_MAX_ES_MSG_QUEUE_LEN);
    free(json);
  } else
    rc = -1;

  return(rc);
}

/* **************************************************** */

int NetworkInterface::dumpDBFlow(time_t when, bool partial_dump, Flow *f) {
  char *json = f->serialize(partial_dump, false);
  int rc;

  if(json) {
    rc = db->dumpFlow(when, partial_dump, f, json);
    free(json);
  } else
    rc = -1;

  return(rc);
}

/* **************************************************** */

static bool node_proto_guess_walker(GenericHashEntry *node, void *user_data) {
  Flow *flow = (Flow*)node;
  char buf[512];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", flow->print(buf, sizeof(buf)));

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::dumpFlows() {
  /* NOTUSED */
  flows_hash->walk(node_proto_guess_walker, NULL);
}

/* **************************************************** */

Flow* NetworkInterface::getFlow(u_int8_t *src_eth, u_int8_t *dst_eth,
				u_int16_t vlan_id,
  				IpAddress *src_ip, IpAddress *dst_ip,
  				u_int16_t src_port, u_int16_t dst_port,
				u_int8_t l4_proto,
				bool *src2dst_direction,
				time_t first_seen, time_t last_seen,
				bool *new_flow) {
  Flow *ret;

  if(vlan_id != 0) setSeenVlanTaggedPackets();

  ret = flows_hash->find(src_ip, dst_ip, src_port, dst_port,
			 vlan_id, l4_proto, src2dst_direction);

  if(ret == NULL) {
    *new_flow = true;

    try {
      ret = new Flow(this, vlan_id, l4_proto,
		     src_eth, src_ip, src_port,
		     dst_eth, dst_ip, dst_port,
		     first_seen, last_seen);
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }

      return(NULL);
    }
    if(flows_hash->add(ret)) {
      *src2dst_direction = true;
      return(ret);
    } else {
      delete ret;
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many flows");
      return(NULL);
    }
  } else {
    *new_flow = false;
    return(ret);
  }
}

/* **************************************************** */

void NetworkInterface::flow_processing(ZMQ_Flow *zflow) {
  bool src2dst_direction, new_flow;
  Flow *flow;
  ndpi_protocol p;

  if((time_t)zflow->last_switched > (time_t)last_pkt_rcvd)
    last_pkt_rcvd = zflow->last_switched;

  /* Updating Flow */
  flow = getFlow(zflow->src_mac, zflow->dst_mac,
		 zflow->vlan_id,
		 &zflow->src_ip, &zflow->dst_ip,
		 zflow->src_port, zflow->dst_port,
		 zflow->l4_proto, &src2dst_direction,
		 zflow->first_switched,
		 zflow->last_switched, &new_flow);

  if(flow == NULL) return;

  if(zflow->l4_proto == IPPROTO_TCP) {
    struct timeval when;

    when.tv_sec = (long)last_pkt_rcvd, when.tv_usec = 0;
    flow->updateTcpFlags((const struct bpf_timeval*)&when,
			 zflow->tcp_flags, src2dst_direction);
  }

  flow->addFlowStats(src2dst_direction,
		     zflow->pkt_sampling_rate*zflow->in_pkts,
		     zflow->pkt_sampling_rate*zflow->in_bytes,
		     zflow->pkt_sampling_rate*zflow->out_pkts,
		     zflow->pkt_sampling_rate*zflow->out_bytes,
		     zflow->last_switched);
  p.protocol = zflow->l7_proto, p.master_protocol = NDPI_PROTOCOL_UNKNOWN;
  flow->setDetectedProtocol(p);
  flow->setJSONInfo(json_object_to_json_string(zflow->additional_fields));
  flow->updateActivities();
  flow->updateInterfaceStats(src2dst_direction,
			     zflow->pkt_sampling_rate*(zflow->in_pkts+zflow->out_pkts),
			     zflow->pkt_sampling_rate*(zflow->in_bytes+zflow->out_bytes));
  incStats(last_pkt_rcvd, zflow->src_ip.isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	   flow->get_detected_protocol().protocol,
	   zflow->pkt_sampling_rate*(zflow->in_bytes + zflow->out_bytes),
	   zflow->pkt_sampling_rate*(zflow->in_pkts + zflow->out_pkts),
	   24 /* 8 Preamble + 4 CRC + 12 IFG */ + 14 /* Ethernet header */);

  if(zflow->src_process.pid || zflow->dst_process.pid) {
    if(zflow->src_process.pid) flow->handle_process(&zflow->src_process, src2dst_direction ? true : false);
    if(zflow->dst_process.pid) flow->handle_process(&zflow->dst_process, src2dst_direction ? false : true);

    if(zflow->l7_proto == NDPI_PROTOCOL_UNKNOWN)
      flow->guessProtocol();
  }

#if 0
  if(!is_packet_interface()) {
    struct timeval tv, *last_update;

    tv.tv_sec = zflow->last_switched, tv.tv_usec = 0;

    flow->update_hosts_stats(&tv);
  }
#endif

  purgeIdle(zflow->last_switched);
}

/* **************************************************** */

void NetworkInterface::dumpPacketDisk(const struct pcap_pkthdr *h, const u_char *packet,
                                      dump_reason reason) {
  if(pkt_dumper == NULL)
    pkt_dumper = new PacketDumper(this);
  if(pkt_dumper)
    pkt_dumper->dumpPacket(h, packet, reason, getDumpTrafficSamplingRate(),
                           getDumpTrafficMaxPktsPerFile(),
                           getDumpTrafficMaxSecPerFile());
}

/* **************************************************** */

void NetworkInterface::dumpPacketTap(const struct pcap_pkthdr *h, const u_char *packet,
                                     dump_reason reason) {
  if(pkt_dumper_tap)
    pkt_dumper_tap->writeTap((unsigned char *)packet, h->len, reason,
                             getDumpTrafficSamplingRate());
}

/* **************************************************** */

bool NetworkInterface::packetProcessing(const struct bpf_timeval *when,
					const u_int64_t time,
					struct ndpi_ethhdr *eth,
					u_int16_t vlan_id,
					struct ndpi_iphdr *iph,
					struct ndpi_ipv6hdr *ip6,
					u_int16_t ipsize,
					u_int16_t rawsize,
					const struct pcap_pkthdr *h,
					const u_char *packet,
					int *a_shaper_id,
					int *b_shaper_id,
					u_int16_t *ndpiProtocol) {
  bool src2dst_direction;
  u_int8_t l4_proto;
  Flow *flow;
  u_int8_t *eth_src = eth->h_source, *eth_dst = eth->h_dest;
  IpAddress src_ip, dst_ip;
  u_int16_t src_port, dst_port, payload_len;
  struct ndpi_tcphdr *tcph = NULL;
  struct ndpi_udphdr *udph = NULL;
  u_int16_t l4_packet_len;
  u_int8_t *l4, tcp_flags = 0, *payload;
  u_int8_t *ip;
  bool is_fragment = false, new_flow;
  bool pass_verdict = true;

  if(iph != NULL) {
    /* IPv4 */
    if(ipsize < 20) {
      incStats(when->tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }

    if((iph->ihl * 4) > ipsize || ipsize < ntohs(iph->tot_len)
       || (iph->frag_off & htons(0x1FFF /* IP_OFFSET */)) != 0) {
      is_fragment = true;
    }

    l4_packet_len = ntohs(iph->tot_len) - (iph->ihl * 4);
    l4_proto = iph->protocol;
    l4 = ((u_int8_t *) iph + iph->ihl * 4);
    ip = (u_int8_t*)iph;
  } else {
    /* IPv6 */
    u_int ipv6_shift = sizeof(const struct ndpi_ipv6hdr);

    if(ipsize < sizeof(const struct ndpi_ipv6hdr)) {
      incStats(when->tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize,
	       1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }

    l4_packet_len = ntohs(ip6->ip6_ctlun.ip6_un1.ip6_un1_plen);
    l4_proto = ip6->ip6_ctlun.ip6_un1.ip6_un1_nxt;

    if(l4_proto == 0x3C /* IPv6 destination option */) {
      u_int8_t *options = (u_int8_t*)ip6 + ipv6_shift;

      l4_proto = options[0];
      ipv6_shift = 8 * (options[1] + 1);

      if(ipsize < ipv6_shift) {
	incStats(when->tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	return(pass_verdict);
      }
    }

    l4 = (u_int8_t*)ip6 + ipv6_shift;
    ip = (u_int8_t*)ip6;
  }

  if(l4_proto == IPPROTO_TCP) {
    if(l4_packet_len >= sizeof(struct ndpi_tcphdr)) {
      u_int tcp_len;

      /* TCP */
      tcph = (struct ndpi_tcphdr *)l4;
      src_port = tcph->source, dst_port = tcph->dest;
      tcp_flags = l4[13];
      tcp_len = min_val(4*tcph->doff, l4_packet_len);
      payload = &l4[tcp_len];
      payload_len = max_val(0, l4_packet_len-4*tcph->doff);
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid TCP packet received [%u bytes long]", l4_packet_len);
      incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }
  } else if(l4_proto == IPPROTO_UDP) {
    if(l4_packet_len >= sizeof(struct ndpi_udphdr)) {
      /* UDP */
      udph = (struct ndpi_udphdr *)l4;
      src_port = udph->source,  dst_port = udph->dest;
      payload = &l4[sizeof(struct ndpi_udphdr)];
      payload_len = max_val(0, l4_packet_len-sizeof(struct ndpi_udphdr));
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid UDP packet received [%u bytes long]", l4_packet_len);
      incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }
  } else {
    /* non TCP/UDP protocols */

    src_port = dst_port = 0;
    payload = NULL, payload_len = 0;
  }

  if(iph != NULL) {
    src_ip.set_ipv4(iph->saddr);
    dst_ip.set_ipv4(iph->daddr);
  } else {
    src_ip.set_ipv6(&ip6->ip6_src);
    dst_ip.set_ipv6(&ip6->ip6_dst);
  }

#if defined(WIN32) && defined(DEMO_WIN32)
  if(this->ethStats.getNumPackets() > MAX_NUM_PACKETS) {
    static bool showMsg = false;

    if(!showMsg) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "-----------------------------------------------------------");
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "WARNING: this demo application is a limited ntopng version able to");
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "capture up to %d packets. If you are interested", MAX_NUM_PACKETS);
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "in the full version please have a look at the ntop");
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "home page http://www.ntop.org/.");
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "-----------------------------------------------------------");
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "");
      showMsg = true;
    }

    return(pass_verdict);
  }
#endif

  /* Updating Flow */
  flow = getFlow(eth_src, eth_dst, vlan_id, &src_ip, &dst_ip, src_port, dst_port,
		 l4_proto, &src2dst_direction, last_pkt_rcvd, last_pkt_rcvd, &new_flow);

  if(flow == NULL) {
    incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
	     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    return(pass_verdict);
  } else {
    flow->incStats(src2dst_direction, h->len, payload_len, &h->ts);

    if(l4_proto == IPPROTO_TCP) {
      flow->updateTcpFlags(when, tcp_flags, src2dst_direction);
      flow->updateTcpSeqNum(when, ntohl(tcph->seq), ntohl(tcph->ack_seq), ntohs(tcph->window),
			    tcp_flags, l4_packet_len - (4 * tcph->doff),
			    src2dst_direction);
    }
  }

  /* Protocol Detection */
  flow->updateActivities();
  flow->updateInterfaceStats(src2dst_direction, 1, h->len);

  if(!flow->isDetectionCompleted()) {
    if(!is_fragment) {
      struct ndpi_flow_struct *ndpi_flow = flow->get_ndpi_flow();
      struct ndpi_id_struct *cli = (struct ndpi_id_struct*)flow->get_cli_id();
      struct ndpi_id_struct *srv = (struct ndpi_id_struct*)flow->get_srv_id();

      flow->setDetectedProtocol(ndpi_detection_process_packet(ndpi_struct, ndpi_flow,
							      ip, ipsize, (u_int32_t)time,
							      cli, srv));
    } else {
      // FIX - only handle unfragmented packets
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "IP fragments are not handled yet!");
    }
  }

  if(flow->isDetectionCompleted()
     && flow->get_cli_host()
     && flow->get_srv_host()) {
    switch(ndpi_get_lower_proto(flow->get_detected_protocol())) {
    case NDPI_PROTOCOL_HTTP:
      if(payload_len > 0)
	flow->dissectHTTP(src2dst_direction, (char*)payload, payload_len);
      break;

    case NDPI_PROTOCOL_DNS:
      struct ndpi_flow_struct *ndpi_flow = flow->get_ndpi_flow();

      if(payload) {
	struct ndpi_dns_packet_header *header = (struct ndpi_dns_packet_header*)payload;
	u_int16_t dns_flags = ntohs(header->flags);
	bool is_query   = ((dns_flags & 0x8000) == 0x8000) ? false : true;

	if(flow->get_cli_host() && flow->get_srv_host()) {
	  Host *client = src2dst_direction ? flow->get_cli_host() : flow->get_srv_host();
	  Host *server = src2dst_direction ? flow->get_srv_host() : flow->get_cli_host();

	  /*
	    Inside the DNS packet it is possible to have multiple queries
	    and mix query types. In general this is not a practice followed
	    by applications.
	  */

	  if(is_query) {
	    u_int16_t query_type = ndpi_flow ? ndpi_flow->protos.dns.query_type : 0;

	    client->incNumDNSQueriesSent(query_type), server->incNumDNSQueriesRcvd(query_type);
	  } else {
	    u_int8_t ret_code = is_query ? 0 : (dns_flags & 0x0F);

	    client->incNumDNSResponsesSent(ret_code), server->incNumDNSResponsesRcvd(ret_code);
	  }
	}
      }

      if(ndpi_flow) {
	struct ndpi_id_struct *cli = (struct ndpi_id_struct*)flow->get_cli_id();
	struct ndpi_id_struct *srv = (struct ndpi_id_struct*)flow->get_srv_id();

	memset(&ndpi_flow->detected_protocol_stack,
	       0, sizeof(ndpi_flow->detected_protocol_stack));

	ndpi_detection_process_packet(ndpi_struct, ndpi_flow,
				      ip, ipsize, (u_int32_t)time,
				      src2dst_direction ? cli : srv,
				      src2dst_direction ? srv : cli);

	/*
	  We reset the nDPI flow so that it can decode new packets
	  of the same flow (e.g. the DNS response)
	*/
	ndpi_flow->detected_protocol_stack[0] = NDPI_PROTOCOL_UNKNOWN;
      }
      break;
    }

    flow->processDetectedProtocol();

    /* For DNS we delay the memory free so that we can let nDPI analyze all the packets of the flow */
    if(ndpi_is_proto(flow->get_detected_protocol(), NDPI_PROTOCOL_DNS))
      flow->deleteFlowMemory();

    incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	     flow->get_detected_protocol().protocol,
	     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);

    bool dump_is_unknown = dump_unknown_traffic
      && (!flow->isDetectionCompleted() ||
	  flow->get_detected_protocol().protocol == NDPI_PROTOCOL_UNKNOWN);

    if(dump_is_unknown
       || dump_all_traffic
       || dump_security_packets
       || flow->dumpFlowTraffic()) {
      if(dump_to_disk) dumpPacketDisk(h, packet, dump_is_unknown ? UNKNOWN : GUI);
      if(dump_to_tap)  dumpPacketTap(h, packet, GUI);
    }

    pass_verdict = flow->isPassVerdict();

    flow->getFlowShapers(src2dst_direction, a_shaper_id, b_shaper_id, ndpiProtocol);
  } else
    incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	     flow->get_detected_protocol().protocol,
	     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);

  return(pass_verdict);
}

/* **************************************************** */

void NetworkInterface::purgeIdle(time_t when) {
  if(purge_idle_flows_hosts) {
    u_int n;

    last_pkt_rcvd = when;

    if((n = purgeIdleFlows()) > 0)
      ntop->getTrace()->traceEvent(TRACE_INFO, "Purged %u/%u idle flows on %s",
				   n, getNumFlows(), ifname);

    if((n = purgeIdleHosts()) > 0)
      ntop->getTrace()->traceEvent(TRACE_INFO, "Purged %u/%u idle hosts on %s",
				   n, getNumHosts(), ifname);
  }

  if(pkt_dumper) pkt_dumper->idle(when);
  updateSecondTraffic(when);
}

/* **************************************************** */

bool NetworkInterface::dissectPacket(const struct pcap_pkthdr *h,
				     const u_char *packet,
				     int *a_shaper_id, int *b_shaper_id,
				     u_int16_t *ndpiProtocol) {
  struct ndpi_ethhdr *ethernet, dummy_ethernet;
  u_int64_t time;
  static u_int64_t lasttime = 0;
  u_int16_t eth_type, ip_offset, vlan_id = 0, eth_offset = 0;
  u_int32_t res = ntop->getGlobals()->get_detection_tick_resolution(), null_type;
  int pcap_datalink_type = get_datalink();
  bool pass_verdict = true;

  if(h->len > ifMTU) {
    if(!mtuWarningShown) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Invalid packet received [len: %u][MTU: %u].", h->len, ifMTU);
      ntop->getTrace()->traceEvent(TRACE_WARNING, "If you have TSO/GRO enabled, please disable it");
#ifdef linux
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Use: sudo ethtool -K %s gro off gso off tso off", ifname);
#endif
      mtuWarningShown = true;
    }

#if 0
    incStats(when->tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len /* ifMTU */, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    return(pass_verdict);
#endif
  }

  setTimeLastPktRcvd(h->ts.tv_sec);

  time = ((uint64_t) h->ts.tv_sec) * res + h->ts.tv_usec / (1000000 / res);
  if(lasttime > time) time = lasttime;

  lasttime = time;

 datalink_check:
  if(pcap_datalink_type == DLT_NULL) {
    memcpy(&null_type, &packet[eth_offset], sizeof(u_int32_t));

    switch(null_type) {
    case BSD_AF_INET:
      eth_type = ETHERTYPE_IP;
      break;
    case BSD_AF_INET6_BSD:
    case BSD_AF_INET6_FREEBSD:
    case BSD_AF_INET6_DARWIN:
      eth_type = ETHERTYPE_IPV6;
      break;
    default:
      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict); /* Any other non IP protocol */
    }

    memset(&dummy_ethernet, 0, sizeof(dummy_ethernet));
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    ip_offset = 4 + eth_offset;
  } else if(pcap_datalink_type == DLT_EN10MB) {
    ethernet = (struct ndpi_ethhdr *)&packet[eth_offset];
    ip_offset = sizeof(struct ndpi_ethhdr) + eth_offset;
    eth_type = ntohs(ethernet->h_proto);
  } else if(pcap_datalink_type == 113 /* Linux Cooked Capture */) {
    memset(&dummy_ethernet, 0, sizeof(dummy_ethernet));
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    eth_type = (packet[eth_offset+14] << 8) + packet[eth_offset+15];
    ip_offset = 16 + eth_offset;
    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
#ifdef DLT_RAW
  } else if(pcap_datalink_type == DLT_RAW /* Linux TUN/TAP device in TUN mode; Raw IP capture */) {
    switch((packet[eth_offset] & 0xf0) >> 4) {
    case 4:
      eth_type = ETHERTYPE_IP;
      break;
    case 6:
      eth_type = ETHERTYPE_IPV6;
      break;
    default:
      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict); /* Unknown IP protocol version */
    }
    memset(&dummy_ethernet, 0, sizeof(dummy_ethernet));
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    ip_offset = eth_offset;
#endif /* DLT_RAW */
  } else if(pcap_datalink_type == DLT_IPV4) {
    eth_type = ETHERTYPE_IP;
    memset(&dummy_ethernet, 0, sizeof(dummy_ethernet));
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    ip_offset = 0;
  } else {
    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    return(pass_verdict);
  }

  while(true) {
    if(eth_type == 0x8100 /* VLAN */) {
      Ether80211q *qType = (Ether80211q*)&packet[ip_offset];

      vlan_id = ntohs(qType->vlanId) & 0xFFF;
      eth_type = (packet[ip_offset+2] << 8) + packet[ip_offset+3];
      ip_offset += 4;
    } else if(eth_type == 0x8847 /* MPLS */) {
      u_int8_t bos; /* bottom_of_stack */

      bos = (((u_int8_t)packet[ip_offset+2]) & 0x1), ip_offset += 4;
      if(bos) {
	eth_type = ETHERTYPE_IP;
	break;
      }
    } else
      break;
  }

 decode_packet_eth:

  if(eth_type == ETHERTYPE_BATMAN) {
    /* ethernet now contains the L2 layer of the antennas */

    u_char orig_dest[6], orig_src[6];

    u_int8_t bp_type = (u_int8_t) (packet[ip_offset]);
    u_int8_t version = (u_int8_t) (packet[ip_offset+1]);

    if(version == BATADV_COMPAT_VERSION_15){
      switch(bp_type){
      case BATADV15_IV_OGM:
	ip_offset += 24;
	break;
      case BATADV15_BCAST:
	orig_src[0] = packet[ip_offset+8];
	orig_src[1] = packet[ip_offset+9];
	orig_src[2] = packet[ip_offset+10];
	orig_src[3] = packet[ip_offset+11];
	orig_src[4] = packet[ip_offset+12];
	orig_src[5] = packet[ip_offset+13];
	ip_offset += 14;
	break;
      case BATADV15_CODED:
	ip_offset += 46;
	break;
      case BATADV15_UNICAST:
	orig_dest[0] = packet[ip_offset+4];
	orig_dest[1] = packet[ip_offset+5];
	orig_dest[2] = packet[ip_offset+6];
	orig_dest[3] = packet[ip_offset+7];
	orig_dest[4] = packet[ip_offset+8];
	orig_dest[5] = packet[ip_offset+9];
	ip_offset += 10;
	break;
      case BATADV15_UNICAST_FRAG:
	ip_offset += 20;
	break;
      case BATADV15_UNICAST_4ADDR:
	ip_offset += 18;
	break;
      case BATADV15_ICMP:
	ip_offset += 20;
	break;
      case BATADV15_UNICAST_TVLV:
	ip_offset += 20;
	break;
      default:
	fprintf(stderr,"Unknown packet type for batman-adv 2014");
	exit(EXIT_FAILURE);
	break;
      }
    }else if(version == BATADV_COMPAT_VERSION_14){
      switch(bp_type){
      case BATADV14_IV_OGM:
	ip_offset += 26;
	break;
      case BATADV14_ICMP:
	ip_offset += 20;
	break;
      case BATADV14_UNICAST:
	orig_dest[0] = packet[ip_offset+4];
	orig_dest[1] = packet[ip_offset+5];
	orig_dest[2] = packet[ip_offset+6];
	orig_dest[3] = packet[ip_offset+7];
	orig_dest[4] = packet[ip_offset+8];
	orig_dest[5] = packet[ip_offset+9];
	ip_offset += 10;
	break;
      case BATADV14_BCAST:
	orig_src[0] = packet[ip_offset+8];
	orig_src[1] = packet[ip_offset+9];
	orig_src[2] = packet[ip_offset+10];
	orig_src[3] = packet[ip_offset+11];
	orig_src[4] = packet[ip_offset+12];
	orig_src[5] = packet[ip_offset+13];
	ip_offset += 14;
	break;
      case BATADV14_VIS:
	ip_offset += 28;
	break;
      case BATADV14_UNICAST_FRAG:
	ip_offset += 20;
	break;
      case BATADV14_TT_QUERY:
	ip_offset += 19;
	break;
      case BATADV14_ROAM_ADV:
	ip_offset += 22;
	break;
      case BATADV14_UNICAST_4ADDR:
	ip_offset += 18;
	break;
      case BATADV14_CODED:
	ip_offset += 46;
	break;
      default:
	fprintf(stderr,"Unknown packet type for batman-adv 2013");
	exit(EXIT_FAILURE);
	break;
      }
    } else {
      fprintf(stderr,"ntopng supports only batman-adv version 2013 and 2014");
      exit(EXIT_FAILURE);
    }

    ethernet = (struct ndpi_ethhdr *) &packet[ip_offset];
    eth_type = (packet[ip_offset + 12] << 8) + packet[ip_offset + 13];
    ip_offset += sizeof(struct ndpi_ethhdr);

    if(((bp_type == BATADV14_BCAST) || (bp_type == BATADV15_BCAST))
       && memcmp(orig_src,ethernet->h_source,6) != 0)
      antenna_mac = orig_src;

    if(((bp_type == BATADV14_UNICAST) || (bp_type == BATADV15_UNICAST))
       &&  memcmp(orig_dest,ethernet->h_dest,6) != 0)
      antenna_mac = orig_dest;

    has_mesh_networks_traffic = true;
  } else
    antenna_mac = NULL;

  switch(eth_type) {
  case ETHERTYPE_PPOE:
    eth_type = ETHERTYPE_IP;
    ip_offset += 8;
    goto decode_packet_eth;
    break;

  case ETHERTYPE_IP:
    if(h->caplen >= ip_offset) {
      u_int16_t frag_off;
      struct ndpi_iphdr *iph = (struct ndpi_iphdr *) &packet[ip_offset];
      struct ndpi_ipv6hdr *ip6 = NULL;

      if(iph->version != 4) {
	/* This is not IPv4 */
	incStats(h->ts.tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	return(pass_verdict);
      } else
	frag_off = ntohs(iph->frag_off);

      if(ntop->getGlobals()->decode_tunnels() && (iph->protocol == IPPROTO_UDP)
	 && ((frag_off & 0x3FFF /* IP_MF | IP_OFFSET */ ) == 0)) {
	u_short ip_len = ((u_short)iph->ihl * 4);
	struct ndpi_udphdr *udp = (struct ndpi_udphdr *)&packet[ip_offset+ip_len];
	u_int16_t sport = ntohs(udp->source), dport = ntohs(udp->dest);

	if((sport == GTP_U_V1_PORT) || (dport == GTP_U_V1_PORT)) {
	  /* Check if it's GTPv1 */
	  u_int offset = (u_int)(ip_offset+ip_len+sizeof(struct ndpi_udphdr));
	  u_int8_t flags = packet[offset];
	  u_int8_t message_type = packet[offset+1];

	  if((((flags & 0xE0) >> 5) == 1 /* GTPv1 */) && (message_type == 0xFF /* T-PDU */)) {
	    ip_offset = ip_offset+ip_len+sizeof(struct ndpi_udphdr)+8 /* GTPv1 header len */;

	    if(flags & 0x04) ip_offset += 1; /* next_ext_header is present */
	    if(flags & 0x02) ip_offset += 4; /* sequence_number is present (it also includes next_ext_header and pdu_number) */
	    if(flags & 0x01) ip_offset += 1; /* pdu_number is present */

	    iph = (struct ndpi_iphdr *) &packet[ip_offset];

	    if(iph->version != 4) {
	      /* FIX - Add IPv6 support */
	      incStats(h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      return(pass_verdict);
	    }
	  }
	} else if((sport == TZSP_PORT) || (dport == TZSP_PORT)) {
	  /* https://en.wikipedia.org/wiki/TZSP */
	  u_int offset = ip_offset+ip_len+sizeof(struct ndpi_udphdr);
	  u_int8_t version = packet[offset];
	  u_int8_t type    = packet[offset+1];
	  u_int16_t encapsulates = ntohs(*((u_int16_t*)&packet[offset+2]));

	  if((version == 1) && (type == 0) && (encapsulates == 1)) {
	    u_int8_t stop = 0;

	    offset += 4;

	    while((!stop) && (offset < h->caplen)) {
	      u_int8_t tag_type = packet[offset];
	      u_int8_t tag_len;

	      switch(tag_type) {
	      case 0: /* PADDING Tag */
		tag_len = 1;
		break;
	      case 1: /* END Tag */
		tag_len = 1, stop = 1;
		break;
	      default:
		tag_len = packet[offset+1];
		break;
	      }

	      offset += tag_len;

	      if(offset >= h->caplen) {
		incStats(h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
		return(pass_verdict);
	      } else {
		eth_offset = offset;
		goto datalink_check;
	      }
	    }
	  }
	}

	if((sport == CAPWAP_DATA_PORT) || (dport == CAPWAP_DATA_PORT)) {
	  /*
	    Control And Provisioning of Wireless Access Points

	    https://www.rfc-editor.org/rfc/rfc5415.txt

	    CAPWAP Header          - variable length (5 MSB of byte 2 of header)
	    IEEE 802.11 Data Flags - 24 bytes
	    Logical-Link Control   - 8  bytes

	    Total = CAPWAP_header_length + 24 + 8
	  */
	  u_short eth_type;
	  ip_offset = ip_offset+ip_len+sizeof(struct ndpi_udphdr);
	  u_int8_t capwap_header_len = ((*(u_int8_t*)&packet[ip_offset+1])>>3)*4;
	  ip_offset = ip_offset+capwap_header_len+24+8;

	  if(ip_offset >= h->len){
	    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    return(pass_verdict);
	  }
	  eth_type = ntohs(*(u_int16_t*)&packet[ip_offset-2]);

	  switch(eth_type){
	  case ETHERTYPE_IP:
	    iph = (struct ndpi_iphdr *) &packet[ip_offset];
	    break;
	  case ETHERTYPE_IPV6:
	    iph = NULL;
	    ip6 = (struct ndpi_ipv6hdr*)&packet[ip_offset];
	    break;
	  default:
	    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    return(pass_verdict);
	  }
	}
      }

      try {
	pass_verdict = packetProcessing(&h->ts, time, ethernet, vlan_id, iph,
					ip6, h->caplen - ip_offset, h->len,
					h, packet, a_shaper_id, b_shaper_id,
					ndpiProtocol);
      } catch(std::bad_alloc& ba) {
	static bool oom_warning_sent = false;

	if(!oom_warning_sent) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	  oom_warning_sent = true;
	}
      }
    }
    break;

  case ETHERTYPE_IPV6:
    if(h->caplen >= ip_offset) {
      struct ndpi_iphdr *iph = NULL;
      struct ndpi_ipv6hdr *ip6 = (struct ndpi_ipv6hdr*)&packet[ip_offset];

      if((ntohl(ip6->ip6_ctlun.ip6_un1.ip6_un1_flow) & 0xF0000000) != 0x60000000) {
	/* This is not IPv6 */
	incStats(h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	return(pass_verdict);
      } else {
	u_int ipv6_shift = sizeof(const struct ndpi_ipv6hdr);
	u_int8_t l4_proto = ip6->ip6_ctlun.ip6_un1.ip6_un1_nxt;

	if(l4_proto == 0x3C /* IPv6 destination option */) {
	  u_int8_t *options = (u_int8_t*)ip6 + ipv6_shift;
	  l4_proto = options[0];
	  ipv6_shift = 8 * (options[1] + 1);
	}

	if(ntop->getGlobals()->decode_tunnels() && (l4_proto == IPPROTO_UDP)){
	  ip_offset += ipv6_shift;
	  if(ip_offset >= h->len) {
	    incStats(h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    return(pass_verdict);
	  }

	  struct ndpi_udphdr *udp = (struct ndpi_udphdr *)&packet[ip_offset];
	  u_int16_t sport = udp->source,  dport = udp->dest;

	  if((sport == CAPWAP_DATA_PORT) || (dport == CAPWAP_DATA_PORT)) {
	    /*
	      Control And Provisioning of Wireless Access Points

	      https://www.rfc-editor.org/rfc/rfc5415.txt

	      CAPWAP Header          - variable length (5 MSB of byte 2 of header)
	      IEEE 802.11 Data Flags - 24 bytes
	      Logical-Link Control   - 8  bytes

	      Total = CAPWAP_header_length + 24 + 8
	    */

	    u_short eth_type;
	    ip_offset = ip_offset+sizeof(struct ndpi_udphdr);
	    u_int8_t capwap_header_len = ((*(u_int8_t*)&packet[ip_offset+1])>>3)*4;
	    ip_offset = ip_offset+capwap_header_len+24+8;

	    if(ip_offset >= h->len){
	      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      return(pass_verdict);
	    }
	    eth_type = ntohs(*(u_int16_t*)&packet[ip_offset-2]);

	    switch(eth_type){
	    case ETHERTYPE_IP:
	      iph = (struct ndpi_iphdr *) &packet[ip_offset];
	      ip6 = NULL;
	      break;
	    case ETHERTYPE_IPV6:
	      ip6 = (struct ndpi_ipv6hdr*)&packet[ip_offset];
	      break;
	    default:
	      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      return(pass_verdict);
	    }
	  }
	}
	try {
	  pass_verdict = packetProcessing(&h->ts, time, ethernet, vlan_id,
					  iph, ip6, h->len - ip_offset, h->len,
					  h, packet, a_shaper_id, b_shaper_id,
					  ndpiProtocol);
	} catch(std::bad_alloc& ba) {
	  static bool oom_warning_sent = false;

	  if(!oom_warning_sent) {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	    oom_warning_sent = true;
	  }
	}
      }
    }
    break;

  default: /* No IPv4 nor IPv6 */
    Host *srcHost = findHostByMac(ethernet->h_source, vlan_id, true);
    Host *dstHost = findHostByMac(ethernet->h_dest, vlan_id, true);

    if(srcHost) {
      srcHost->incStats(0, NO_NDPI_PROTOCOL, NULL, 1, h->len, 0, 0);
      srcHost->updateActivities();
    }

    if(dstHost) {
      dstHost->incStats(0, NO_NDPI_PROTOCOL, NULL, 0, 0, 1, h->len);
      dstHost->updateActivities();
    }

    incStats(h->ts.tv_sec, eth_type, NDPI_PROTOCOL_UNKNOWN, h->len,
	     1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    break;
  }

  purgeIdle(last_pkt_rcvd);

  return(pass_verdict);
}

/* **************************************************** */

void NetworkInterface::startPacketPolling() {
  if((cpu_affinity != -1) && (ntop->getNumCPUs() > 1)) {
    if(Utils::setThreadAffinity(pollLoop, cpu_affinity))
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Could not set affinity of interface %s to core %d",
				   get_name(), cpu_affinity);
    else
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting affinity of interface %s to core %d",
				   get_name(), cpu_affinity);
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Started packet polling on interface %s [id: %u]...",
			       get_name(), get_id());
  running = true;
}

/* **************************************************** */

void NetworkInterface::shutdown() {
  running = false;
}

/* **************************************************** */

void NetworkInterface::cleanup() {
  last_pkt_rcvd = 0;
  next_idle_flow_purge = next_idle_host_purge = 0;
  cpu_affinity = -1, has_vlan_packets = false;
  running = false, sprobe_interface = false, inline_interface = false;

  getStats()->cleanup();

  flows_hash->cleanup();
  hosts_hash->cleanup();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Cleanup interface %s", get_name());
}

/* **************************************************** */

void NetworkInterface::findFlowHosts(u_int16_t vlanId,
				     u_int8_t src_mac[6], IpAddress *_src_ip, Host **src,
				     u_int8_t dst_mac[6], IpAddress *_dst_ip, Host **dst) {

  (*src) = hosts_hash->get(vlanId, _src_ip);

  if((*src) == NULL) {
    if(!hosts_hash->hasEmptyRoom()) {
      *src = *dst = NULL;
      return;
    }

    (*src) = new Host(this, src_mac, vlanId, _src_ip);
    if(!hosts_hash->add(*src)) {
      //ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
      delete *src;
      *src = *dst = NULL;
      return;
    }
  }

  /* ***************************** */

  (*dst) = hosts_hash->get(vlanId, _dst_ip);

  if((*dst) == NULL) {
    if(!hosts_hash->hasEmptyRoom()) {
      *dst = NULL;
      return;
    }

    (*dst) = new Host(this, dst_mac, vlanId, _dst_ip);
    if(!hosts_hash->add(*dst)) {
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
      delete *dst;
      *dst = NULL;
      return;
    }
  }
}

/* **************************************************** */

static bool flow_sum_protos(GenericHashEntry *f, void *user_data) {
  nDPIStats *stats = (nDPIStats*)user_data;
  Flow *flow = (Flow*)f;

  flow->sumStats(stats);
  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getnDPIStats(nDPIStats *stats) {
  flows_hash->walk(flow_sum_protos, (void*)stats);
}

/* **************************************************** */

static bool flow_update_hosts_stats(GenericHashEntry *node, void *user_data) {
  Flow *flow = (Flow*)node;
  struct timeval *tv = (struct timeval*)user_data;

  flow->update_hosts_stats(tv);
  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool update_hosts_stats(GenericHashEntry *node, void *user_data) {
  Host *host = (Host*)node;
  struct timeval *tv = (struct timeval*)user_data;

  host->updateStats(tv);
  /*
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Updated: %s [%d]",
    ((StringHost*)node)->host_key(),
    host->getThptTrend());
  */

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::updateHostStats() {
  struct timeval tv;

  gettimeofday(&tv, NULL);

  flows_hash->walk(flow_update_hosts_stats, (void*)&tv);
  hosts_hash->walk(update_hosts_stats, (void*)&tv);
}

/* **************************************************** */

static bool update_host_l7_policy(GenericHashEntry *node, void *user_data) {
  ((Host*)node)->updateHostL7Policy();
  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::updateHostsL7Policy() {
  hosts_hash->walk(update_host_l7_policy, NULL);
}

/* **************************************************** */

static bool update_flow_l7_policy(GenericHashEntry *node, void *user_data) {
  ((Flow*)node)->makeVerdict();
  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::updateFlowsL7Policy() {
  flows_hash->walk(update_flow_l7_policy, NULL);
}

/* **************************************************** */

struct host_find_info {
  char *host_to_find;
  u_int16_t vlan_id;
  Host *h;
};

/* **************************************************** */

static bool find_host_by_name(GenericHashEntry *h, void *user_data) {
  struct host_find_info *info = (struct host_find_info*)user_data;
  Host *host                  = (Host*)h;

#ifdef DEBUG
  char buf[64];
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%s][%s][%s]",
			       host->get_ip() ? host->get_ip()->print(buf, sizeof(buf)) : "",
			       host->get_name(), info->host_to_find);
#endif

  if((info->h == NULL) && (host->get_vlan_id() == info->vlan_id)) {
    if((host->get_name() == NULL) && host->get_ip()) {
      char ip_buf[32], name_buf[96];
      char *ipaddr = host->get_ip()->print(ip_buf, sizeof(ip_buf));
      int rc = ntop->getRedis()->getAddress(ipaddr, name_buf, sizeof(name_buf),
					    false /* Don't resolve it if not known */);

      if(rc == 0 /* found */) host->setName(name_buf);
    }

    if(host->get_name() && (!strcmp(host->get_name(), info->host_to_find))) {
      info->h = host;
      return(true); /* found */
    }
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

bool NetworkInterface::restoreHost(char *host_ip) {
  Host *h = new Host(this, host_ip);

  if(!h) return(false);

  if(!hosts_hash->add(h)) {
    //ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
    delete h;
    return(false);
  }

  return(true);
}

/* **************************************************** */

Host* NetworkInterface::getHost(char *host_ip, u_int16_t vlan_id) {
  struct in_addr  a4;
  struct in6_addr a6;
  Host *h = NULL;

  /* Check if address is invalid */
  if((inet_pton(AF_INET, (const char*)host_ip, &a4) == 0)
     && (inet_pton(AF_INET6, (const char*)host_ip, &a6) == 0)) {
    /* Looks like a symbolic name */
    struct host_find_info info;

    memset(&info, 0, sizeof(info));
    info.host_to_find = host_ip, info.vlan_id = vlan_id;
    hosts_hash->walk(find_host_by_name, (void*)&info);

    h = info.h;
  } else {
    IpAddress *ip = new IpAddress(host_ip);

    if(ip) {
      h = hosts_hash->get(vlan_id, ip);
      delete ip;
    }
  }

  return(h);
}

/* **************************************************** */

#ifdef NTOPNG_PRO

static bool update_flow_profile(GenericHashEntry *h, void *user_data) {
  Flow *flow = (Flow*)h;

  flow->updateProfile();
  return(false); /* false = keep on walking */
}

void NetworkInterface::updateFlowProfiles() {
  if(ntop->getPro()->has_valid_license()) {
    FlowProfiles *oldP = flow_profiles, *newP = new FlowProfiles();

    flow_profiles = newP; /* Overwrite the current profiles */
    flow_profiles->loadProfiles();/* and reload */

    flows_hash->walk(update_flow_profile, NULL);

    sleep(1);    /* Relax a bit... */
    delete oldP; /* Finally free the old memory */
  }
}

#endif

/* **************************************************** */

bool NetworkInterface::getHostInfo(lua_State* vm,
				   patricia_tree_t *allowed_hosts,
				   char *host_ip, u_int16_t vlan_id) {
  Host *h = findHostsByIP(allowed_hosts, host_ip, vlan_id);

  if(h) {
    h->lua(vm, allowed_hosts, true, true, true, false);
    return(true);
  } else
    return(false);
}

/* **************************************************** */

bool NetworkInterface::loadHostAlertPrefs(lua_State* vm,
				          patricia_tree_t *allowed_hosts,
				          char *host_ip, u_int16_t vlan_id) {
  Host *h = findHostsByIP(allowed_hosts, host_ip, vlan_id);

  if(h) {
    h->loadAlertPrefs();
    return(true);
  }
  return(false);
}

/* **************************************************** */

Host* NetworkInterface::findHostsByIP(patricia_tree_t *allowed_hosts,
				      char *host_ip, u_int16_t vlan_id) {
  if(host_ip != NULL) {
    Host *h = getHost(host_ip, vlan_id);

    if(h && h->match(allowed_hosts))
      return(h);
  }

  return(NULL);
}

/* **************************************************** */

enum flowSortField {
  /* Flows */
  column_client = 0,
  column_server,
  column_proto_l4,
  column_ndpi,
  column_duration,
  column_thpt,
  column_bytes,
  column_info,
  /* Hosts */
  column_ip,
  column_alerts,
  column_name,
  column_since,
  column_asn,
  /* column_thpt, */
  column_traffic
};

struct flowHostRetrieveList {
  Flow *flow;
  /* Value */
  Host *hostValue;
  u_int32_t numericValue;
  char *stringValue;
};

struct flowHostRetriever {
  /* Search criteria */
  patricia_tree_t *allowed_hosts;
  Host *host;
  enum flowSortField sorter;
  bool local_only;

  /* Return values */
  u_int32_t maxNumEntries, actNumEntries;
  struct flowHostRetrieveList *elems;
};

/* **************************************************** */
/* **************************************************** */

static bool flow_search_walker(GenericHashEntry *h, void *user_data) {
  struct flowHostRetriever *retriever = (struct flowHostRetriever*)user_data;
  Flow *f = (Flow*)h;

  if(f && (!f->idle())) {
    if(retriever->host
       && (retriever->host != f->get_cli_host())
       && (retriever->host != f->get_srv_host()))
    return(false); /* false = keep on walking */

    if(retriever->local_only) {
      if((!f->get_cli_host()->isLocalHost())
	 || (!f->get_srv_host()->isLocalHost()))
	return(false); /* false = keep on walking */
    }
    
    retriever->elems[retriever->actNumEntries].flow = f;

    if(f->match(retriever->allowed_hosts)) {
      switch(retriever->sorter) {
      case column_client:
	retriever->elems[retriever->actNumEntries++].hostValue = f->get_cli_host();
	break;
      case column_server:
	retriever->elems[retriever->actNumEntries++].hostValue = f->get_srv_host();
	break;
      case column_proto_l4:
	retriever->elems[retriever->actNumEntries++].numericValue = f->get_protocol();
	break;
      case column_ndpi:
	retriever->elems[retriever->actNumEntries++].numericValue = f->get_detected_protocol().protocol;
	break;
      case column_duration:
	retriever->elems[retriever->actNumEntries++].numericValue = f->get_duration();
	break;
      case column_thpt:
	retriever->elems[retriever->actNumEntries++].numericValue = f->get_bytes_thpt();
	break;
      case column_bytes:
	retriever->elems[retriever->actNumEntries++].numericValue = f->get_bytes();
	break;
      case column_info:
	if(f->getDnsLastQuery())        retriever->elems[retriever->actNumEntries++].stringValue = f->getDnsLastQuery();
	else if(f->getHTTPLastURL())    retriever->elems[retriever->actNumEntries++].stringValue = f->getHTTPLastURL();
	else if(f->getSSLCertificate()) retriever->elems[retriever->actNumEntries++].stringValue = f->getSSLCertificate();
	else retriever->elems[retriever->actNumEntries++].stringValue = (char*)"";
	break;
      default:
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", retriever->sorter);
	break;
    }
  }

  if(retriever->actNumEntries == retriever->maxNumEntries)
    return(true); /* Limit reached */
  else
    return(false); /* false = keep on walking */
  } else
    return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool host_search_walker(GenericHashEntry *he, void *user_data) {
  struct flowHostRetriever *retriever = (struct flowHostRetriever*)user_data;
  Host *h = (Host*)he;

  if(h && (!h->idle()) && h->match(retriever->allowed_hosts)) {
    if(retriever->local_only && (!h->isLocalHost()))
      return(false); /* false = keep on walking */

    retriever->elems[retriever->actNumEntries].hostValue = h;

    if(h->match(retriever->allowed_hosts)) {
      switch(retriever->sorter) {
      case column_ip:
	retriever->elems[retriever->actNumEntries++].hostValue = h;
	break;
      case column_alerts:
	retriever->elems[retriever->actNumEntries++].numericValue = h->getNumAlerts();
	break;
      case column_name:
	{
	  char buf[64];

	  retriever->elems[retriever->actNumEntries++].stringValue = strdup(h->get_name(buf, sizeof(buf), false));
	}
	break;
      case column_since:
	retriever->elems[retriever->actNumEntries++].numericValue = h->get_first_seen();
	break;
      case column_asn:
	retriever->elems[retriever->actNumEntries++].numericValue = h->get_asn();
	break;
      case column_thpt:
	retriever->elems[retriever->actNumEntries++].numericValue = h->getBytesThpt();
	break;
      case column_traffic:
	retriever->elems[retriever->actNumEntries++].numericValue = h->getNumBytes();
	break;
      default:
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", retriever->sorter);
	break;
      }
    }

    if(retriever->actNumEntries == retriever->maxNumEntries)
      return(true); /* Limit reached */
    else
      return(false); /* false = keep on walking */
  } else
    return(false); /* false = keep on walking */
}

/* **************************************************** */

int hostSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList*)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList*)_b;

  return(a->hostValue->get_ip()->compare(b->hostValue->get_ip()));
}

int numericSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList*)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList*)_b;

  if(a->numericValue < b->numericValue)      return(-1);
  else if(a->numericValue > b->numericValue) return(1);
  else return(0);
}

int stringSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList*)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList*)_b;

  return(strcmp(a->stringValue, b->stringValue));
}

/* **************************************************** */

int NetworkInterface::getFlows(lua_State* vm,
			       patricia_tree_t *allowed_hosts,
			       Host *host, bool local_only,
			       char *sortColumn,
			       u_int32_t maxHits,
			       u_int32_t toSkip,
			       bool a2zSortOrder) {
  struct flowHostRetriever retriever;
  int (*sorter)(const void *_a, const void *_b);
  bool highDetails = (local_only || (maxHits != CONST_MAX_NUM_HITS)) ? true : false;

  retriever.host = host, retriever.local_only = local_only;
  retriever.actNumEntries = 0, retriever.maxNumEntries = flows_hash->getNumEntries(), retriever.allowed_hosts = allowed_hosts;
  retriever.elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever.maxNumEntries);

  if(retriever.elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if(!strcmp(sortColumn, "column_client")) retriever.sorter = column_client, sorter = hostSorter;
  else if(!strcmp(sortColumn, "column_server")) retriever.sorter = column_server, sorter = hostSorter;
  else if(!strcmp(sortColumn, "column_proto_l4")) retriever.sorter = column_proto_l4, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_ndpi")) retriever.sorter = column_ndpi, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_duration")) retriever.sorter = column_duration, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt")) retriever.sorter = column_thpt, sorter = numericSorter;
  else if((!strcmp(sortColumn, "column_bytes")) || (!strcmp(sortColumn, "column_") /* default */)) retriever.sorter = column_bytes, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_info")) retriever.sorter = column_info, sorter = stringSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  /* ******************************* */

  flows_hash->disablePurge();
  flows_hash->walk(flow_search_walker, (void*)&retriever);

  qsort(retriever.elems, retriever.actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "numFlows", retriever.actNumEntries);

  lua_newtable(vm);

  if(a2zSortOrder) {
    for(int i=toSkip, num=0; i<(int)retriever.actNumEntries; i++) {
      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);
      if(++num >= (int)maxHits) break;
    }
  } else {
    for(int i=(retriever.actNumEntries-1-toSkip), num=0; i>=0; i--) {
      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);
      if(++num >= (int)maxHits) break;
    }
  }

  lua_pushstring(vm, "flows"); // Key
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  flows_hash->enablePurge();
  free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getActiveHostsList(lua_State* vm, patricia_tree_t *allowed_hosts,
					 bool host_details, bool local_only,
					 char *sortColumn, u_int32_t maxHits,
					 u_int32_t toSkip, bool a2zSortOrder) {

  struct flowHostRetriever retriever;
  int (*sorter)(const void *_a, const void *_b);
  
  retriever.allowed_hosts = allowed_hosts, retriever.local_only = local_only;
  retriever.actNumEntries = 0, retriever.maxNumEntries = hosts_hash->getNumEntries();
  retriever.elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever.maxNumEntries);

  if(retriever.elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if((!strcmp(sortColumn, "column_ip")) || (!strcmp(sortColumn, "column_"))) retriever.sorter = column_ip, sorter = hostSorter;
  else if(!strcmp(sortColumn, "column_alerts")) retriever.sorter = column_alerts, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_name")) retriever.sorter = column_name, sorter = stringSorter;
  else if(!strcmp(sortColumn, "column_since")) retriever.sorter = column_since, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_asn")) retriever.sorter = column_asn, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt")) retriever.sorter = column_thpt, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic")) retriever.sorter = column_traffic, sorter = numericSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  /* ******************************* */

  hosts_hash->disablePurge();
  hosts_hash->walk(host_search_walker, (void*)&retriever);

  qsort(retriever.elems, retriever.actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "numHosts", retriever.actNumEntries);

  lua_newtable(vm);

  if(a2zSortOrder) {
    for(int i=toSkip, num=0; i<(int)retriever.actNumEntries; i++) {
      retriever.elems[i].hostValue->lua(vm, NULL /* Already checked */, 
					host_details, false, false, true);
      if(++num >= (int)maxHits) break;
    }
  } else {
    for(int i=(retriever.actNumEntries-1-toSkip), num=0; i>=0; i--) {
      retriever.elems[i].hostValue->lua(vm, NULL /* Already checked */,
					host_details, false, false, true);
      if(++num >= (int)maxHits) break;
    }
  }

  lua_pushstring(vm, "hosts"); // Key
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  hosts_hash->enablePurge();

  if(sorter == stringSorter) {
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].stringValue) 
	free(retriever.elems[i].stringValue);
  }

  free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

static bool flow_stats_walker(GenericHashEntry *h, void *user_data) {
  struct active_flow_stats *stats = (struct active_flow_stats*)user_data;
  Flow *flow = (Flow*)h;

  stats->num_flows++,
    stats->ndpi_bytes[flow->get_detected_protocol().protocol] += (u_int32_t)flow->get_bytes(),
    stats->breeds_bytes[flow->get_protocol_breed()] += (u_int32_t)flow->get_bytes();

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getFlowsStats(lua_State* vm) {
  struct active_flow_stats stats;

  memset(&stats, 0, sizeof(stats));
  flows_hash->walk(flow_stats_walker, (void*)&stats);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "num_flows", stats.num_flows);

  lua_newtable(vm);
  for(int i=0; i<NDPI_MAX_SUPPORTED_PROTOCOLS+NDPI_MAX_NUM_CUSTOM_PROTOCOLS; i++) {
    if(stats.ndpi_bytes[i] > 0)
      lua_push_int_table_entry(vm,
			       ndpi_get_proto_name(get_ndpi_struct(), i),
			       stats.ndpi_bytes[i]);
  }

  lua_pushstring(vm, "protos");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  for(int i=0; i<NUM_BREEDS; i++) {
    if(stats.breeds_bytes[i] > 0)
      lua_push_int_table_entry(vm,
			       ndpi_get_proto_breed_name(get_ndpi_struct(),
							 (ndpi_protocol_breed_t)i),
			       stats.breeds_bytes[i]);
  }

  lua_pushstring(vm, "breeds");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}
/* **************************************************** */

void NetworkInterface::getNetworksStats(lua_State* vm) {
  NetworkStats *network_stats;
  u_int8_t num_local_networks = ntop->getNumLocalNetworks();

  lua_newtable(vm);
  for (u_int8_t network_id = 0; network_id < num_local_networks; network_id++) {
    network_stats = getNetworkStats(network_id);
    // do not add stats of networks that have not generated any traffic
    if(!network_stats || !network_stats->trafficSeen())
      continue;
    lua_newtable(vm);
    network_stats->lua(vm);
    lua_push_int32_table_entry(vm, "network_id", network_id);
    lua_pushstring(vm, ntop->getLocalNetworkName(network_id));
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* **************************************************** */

struct flow_peers_info {
  lua_State *vm;
  char *numIP;
  u_int16_t vlanId;
  patricia_tree_t *allowed_hosts;
};

static bool flow_peers_walker(GenericHashEntry *h, void *user_data) {
  Flow *flow = (Flow*)h;
  struct flow_peers_info *info = (struct flow_peers_info*)user_data;

  if((info->numIP == NULL) || flow->isFlowPeer(info->numIP, info->vlanId))
    flow->print_peers(info->vm, info->allowed_hosts,
		      (info->numIP == NULL) ? false : true);

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getFlowPeersList(lua_State* vm,
					patricia_tree_t *allowed_hosts,
					char *numIP, u_int16_t vlanId) {
  struct flow_peers_info info;

  info.vm = vm, info.numIP = numIP, info.vlanId = vlanId, info.allowed_hosts = allowed_hosts;
  flows_hash->walk(flow_peers_walker, (void*)&info);
}

/* **************************************************** */

u_int NetworkInterface::purgeIdleFlows() {
  if(!purge_idle_flows_hosts) return(0);

  if(next_idle_flow_purge == 0) {
    next_idle_flow_purge = last_pkt_rcvd + FLOW_PURGE_FREQUENCY;
    return(0);
  } else if(last_pkt_rcvd < next_idle_flow_purge)
    return(0); /* Too early */
  else {
    /* Time to purge flows */
    u_int n;

    // ntop->getTrace()->traceEvent(TRACE_INFO, "Purging idle flows");
    n = flows_hash->purgeIdle();
    next_idle_flow_purge = last_pkt_rcvd + FLOW_PURGE_FREQUENCY;
    return(n);
  }
}

/* **************************************************** */

u_int NetworkInterface::getNumFlows()        { return(flows_hash ? flows_hash->getNumEntries() : 0);   };
u_int NetworkInterface::getNumHosts()        { return(hosts_hash ? hosts_hash->getNumEntries() : 0);   };
u_int NetworkInterface::getNumHTTPHosts()    { return(hosts_hash ? hosts_hash->getNumHTTPEntries() : 0);   };

/* **************************************************** */

u_int NetworkInterface::purgeIdleHosts() {
  if(!purge_idle_flows_hosts) return(0);

  if(next_idle_host_purge == 0) {
    next_idle_host_purge = last_pkt_rcvd + HOST_PURGE_FREQUENCY;
    return(0);
  } else if(last_pkt_rcvd < next_idle_host_purge)
    return(0); /* Too early */
  else {
    /* Time to purge hosts */
    u_int n;

    // ntop->getTrace()->traceEvent(TRACE_INFO, "Purging idle hosts");
    n = hosts_hash->purgeIdle();
    next_idle_host_purge = last_pkt_rcvd + HOST_PURGE_FREQUENCY;
    return(n);
  }
}

/* *************************************** */

void NetworkInterface::getnDPIProtocols(lua_State *vm) {
  int i;

  for(i=0; i<(int)ndpi_struct->ndpi_num_supported_protocols; i++) {
    char buf[8];

    snprintf(buf, sizeof(buf), "%d", i);
    lua_push_str_table_entry(vm, ndpi_struct->proto_defaults[i].protoName, buf);
  }
}

/* **************************************************** */

static bool num_flows_walker(GenericHashEntry *node, void *user_data) {
  Flow *flow = (Flow*)node;
  u_int32_t *num_flows = (u_int32_t*)user_data;

  num_flows[flow->get_detected_protocol().protocol]++;

  return(false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::getnDPIFlowsCount(lua_State *vm) {
  u_int32_t *num_flows;

  num_flows = (u_int32_t*)calloc(ndpi_struct->ndpi_num_supported_protocols, sizeof(u_int32_t));

  if(num_flows) {
    flows_hash->walk(num_flows_walker, num_flows);

    for(int i=0; i<(int)ndpi_struct->ndpi_num_supported_protocols; i++) {
      if(num_flows[i] > 0)
	lua_push_int_table_entry(vm, ndpi_struct->proto_defaults[i].protoName, num_flows[i]);
    }

    free(num_flows);
  }
}

/* *************************************** */

void NetworkInterface::lua(lua_State *vm) {
  lua_newtable(vm);

  lua_push_str_table_entry(vm, "name", ifname);
  lua_push_int_table_entry(vm,  "id", id);
  lua_push_bool_table_entry(vm, "sprobe", get_sprobe_interface());
  lua_push_bool_table_entry(vm, "inline", get_inline_interface());
  lua_push_bool_table_entry(vm, "vlan", get_has_vlan_packets());

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "packets", getNumPackets());
  lua_push_int_table_entry(vm, "bytes",   getNumBytes());
  lua_push_int_table_entry(vm, "flows",   getNumFlows());
  lua_push_int_table_entry(vm, "hosts",   getNumHosts());
  lua_push_int_table_entry(vm, "http_hosts",  getNumHTTPHosts());
  lua_push_int_table_entry(vm, "drops",   getNumDroppedPackets());
  lua_pushstring(vm, "stats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_push_str_table_entry(vm, "type", (char*)get_type());
  lua_push_int_table_entry(vm, "speed", ifSpeed);
  lua_push_int_table_entry(vm, "mtu", ifMTU);
  lua_push_bool_table_entry(vm, "has_mesh_networks_traffic", has_mesh_networks_traffic);
  lua_push_str_table_entry(vm, "ip_addresses", (char*)getLocalIPAddresses());

  ethStats.lua(vm);
  localStats.lua(vm);
  ndpiStats.lua(this, vm);
  pktStats.lua(vm, "pktSizeDistribution");

  if(pkt_dumper) pkt_dumper->lua(vm);
#ifdef NTOPNG_PRO
  if(flow_profiles)   flow_profiles->lua(vm);
#endif
}

/* **************************************************** */

void NetworkInterface::runHousekeepingTasks() {
  /* NOTE NOTE NOTE

     This task runs asynchronously with respect to ntopng
     so if you need to allocate memory you must LOCK

     Example HTTPStats::updateHTTPHostRequest() is called
     by both this function and the main thread
  */
  updateHostStats();
}

/* **************************************************** */

Host* NetworkInterface::findHostByMac(u_int8_t mac[6], u_int16_t vlanId,
				      bool createIfNotPresent) {
  Host *ret = hosts_hash->get(vlanId, mac);

  if((ret == NULL) && createIfNotPresent) {
    try {
      if((ret = new Host(this, mac, vlanId)) != NULL)
	hosts_hash->add(ret);
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }

      return(NULL);
    }
  } else
    ret->updateLocal();

  return(ret);
}

/* **************************************************** */

Flow* NetworkInterface::findFlowByKey(u_int32_t key,
				      patricia_tree_t *allowed_hosts) {
  Flow *f = (Flow*)(flows_hash->findByKey(key));

  if(f && (!f->match(allowed_hosts))) f = NULL;
  return(f);
}

/* **************************************************** */

struct search_host_info {
  lua_State *vm;
  char *host_name_or_ip;
  u_int num_matches;
  patricia_tree_t *allowed_hosts;
};

/* **************************************************** */

static bool hosts_search_walker(GenericHashEntry *h, void *user_data) {
  Host *host = (Host*)h;
  struct search_host_info *info = (struct search_host_info*)user_data;

  if(host->addIfMatching(info->vm, info->allowed_hosts, info->host_name_or_ip))
    info->num_matches++;

  /* Stop after CONST_MAX_NUM_FIND_HITS matches */
  return((info->num_matches > CONST_MAX_NUM_FIND_HITS) ? true /* stop */ : false /* keep walking */);
}

/* **************************************************** */

void NetworkInterface::findHostsByName(lua_State* vm,
				       patricia_tree_t *allowed_hosts,
				       char *key) {
  struct search_host_info info;

  info.vm = vm, info.host_name_or_ip = key, info.num_matches = 0, info.allowed_hosts = allowed_hosts;

  hosts_hash->walk(hosts_search_walker, (void*)&info);
}

/* **************************************************** */

bool NetworkInterface::validInterface(char *name) {
  if(name &&
     (strstr(name, "PPP")            /* Avoid to use the PPP interface              */
      || strstr(name, "dialup")      /* Avoid to use the dialup interface           */
      || strstr(name, "ICSHARE")     /* Avoid to use the internet sharing interface */
      || strstr(name, "NdisWan"))) { /* Avoid to use the internet sharing interface */
    return(false);
  }

  return(true);
}

/* **************************************************** */

u_int NetworkInterface::printAvailableInterfaces(bool printHelp, int idx,
						 char *ifname, u_int ifname_len) {
  char ebuf[256];
  int numInterfaces = 0;
  pcap_if_t *devpointer;

  if(printHelp && help_printed)
    return(0);

  ebuf[0] = '\0';

  if(pcap_findalldevs(&devpointer, ebuf) < 0) {
    ;
  } else {
    if(ifname == NULL) {
      if(printHelp)
	printf("Available interfaces (-i <interface index>):\n");
      else if(!help_printed)
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "Available interfaces (-i <interface index>):");
    }

    for(int i = 0; devpointer != NULL; i++) {
      if(validInterface(devpointer->description)) {
	numInterfaces++;

	if(ifname == NULL) {
	  if(printHelp) {
#ifdef WIN32
	    printf("   %d. %s\n"
		   "\t%s\n", numInterfaces,
		   devpointer->description ? devpointer->description : "",
		   devpointer->name);
#else
	    printf("   %d. %s\n", numInterfaces, devpointer->name);
#endif
	  } else if(!help_printed)
	    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%d. %s (%s)\n",
					 numInterfaces, devpointer->name,
					 devpointer->description ? devpointer->description : devpointer->name);
	} else if(numInterfaces == idx) {
	  snprintf(ifname, ifname_len, "%s", devpointer->name);
	  break;
	}
      }

      devpointer = devpointer->next;
    } /* for */
  } /* else */

  if(numInterfaces == 0) {
#ifdef WIN32
    ntop->getTrace()->traceEvent(TRACE_WARNING, "No interfaces available! This application cannot work");
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Make sure that winpcap is installed properly,");
    ntop->getTrace()->traceEvent(TRACE_WARNING, "that you have administrative rights,");
    ntop->getTrace()->traceEvent(TRACE_WARNING, "and that you have network interfaces installed.");
#else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "No interfaces available: are you superuser?");
#endif
  }

  help_printed = true;

  return(numInterfaces);
}

/* **************************************************** */

bool NetworkInterface::isNumber(const char *str) {
  while(*str) {
    if(!isdigit(*str))
      return(false);

    str++;
  }

  return(true);
}

/* **************************************************** */

struct correlator_host_info {
  lua_State* vm;
  Host *h;
  activity_bitmap x;
};

static bool correlator_walker(GenericHashEntry *node, void *user_data) {
  Host *h = (Host*)node;
  struct correlator_host_info *info = (struct correlator_host_info*)user_data;

  if(h
     // && h->isLocalHost() /* Consider only local hosts */
     && h->get_ip()
     && (h != info->h)) {
    char buf[32], *name = h->get_ip()->print(buf, sizeof(buf));
    activity_bitmap y;
    double pearson;

    h->getActivityStats()->extractPoints(&y);

    pearson = Utils::pearsonValueCorrelation(&(info->x), &y);

    /* ntop->getTrace()->traceEvent(TRACE_WARNING, "%s: %f", name, pearson); */
    lua_push_float_table_entry(info->vm, name, (float)pearson);
  }

  return(false); /* false = keep on walking */
}

static bool similarity_walker(GenericHashEntry *node, void *user_data) {
  Host *h = (Host*)node;
  struct correlator_host_info *info = (struct correlator_host_info*)user_data;

  if(h
     // && h->isLocalHost() /* Consider only local hosts */
     && h->get_ip()
     && (h != info->h)) {
    char buf[32], name[64];

    if(h->get_vlan_id() == 0) {
      sprintf(name, "%s",h->get_ip()->print(buf, sizeof(buf)));
    } else {
      sprintf(name, "%s@%d",h->get_ip()->print(buf, sizeof(buf)),h->get_vlan_id());
    }

    activity_bitmap y;
    double jaccard;

    h->getActivityStats()->extractPoints(&y);

    jaccard = Utils::JaccardSimilarity(&(info->x), &y);

    /* ntop->getTrace()->traceEvent(TRACE_WARNING, "%s: %f", name, pearson); */
    lua_push_float_table_entry(info->vm, name, (float)jaccard);
  }

  return(false); /* false = keep on walking */
}


/* **************************************************** */

bool NetworkInterface::correlateHostActivity(lua_State* vm,
					     patricia_tree_t *allowed_hosts,
					     char *host_ip, u_int16_t vlan_id) {
  Host *h = getHost(host_ip, vlan_id);

  if(h) {
    struct correlator_host_info info;

    memset(&info, 0, sizeof(info));

    info.vm = vm, info.h = h;
    h->getActivityStats()->extractPoints(&info.x);
    hosts_hash->walk(correlator_walker, &info);
    return(true);
  } else
    return(false);
}

/* **************************************************** */

bool NetworkInterface::similarHostActivity(lua_State* vm,
					   patricia_tree_t *allowed_hosts,
					   char *host_ip, u_int16_t vlan_id) {
  Host *h = getHost(host_ip, vlan_id);

  if(h) {
    struct correlator_host_info info;

    memset(&info, 0, sizeof(info));

    info.vm = vm, info.h = h;
    h->getActivityStats()->extractPoints(&info.x);
    hosts_hash->walk(similarity_walker, &info);
    return(true);
  } else
    return(false);
}

/* **************************************************** */

struct user_flows {
  lua_State* vm;
  char *username;
};

static bool userfinder_walker(GenericHashEntry *node, void *user_data) {
  Flow *f = (Flow*)node;
  struct user_flows *info = (struct user_flows*)user_data;
  char *user = f->get_username(true);

  if(user == NULL)
    user = f->get_username(false);

  if(user && (strcmp(user, info->username) == 0))
    f->lua(info->vm, NULL, false /* Minimum details */, true);

  return(false); /* false = keep on walking */
}

void NetworkInterface::findUserFlows(lua_State *vm, char *username) {
  struct user_flows u;

  u.vm = vm, u.username = username;
  flows_hash->walk(userfinder_walker, &u);
}

/* **************************************************** */

struct proc_name_flows {
  lua_State* vm;
  char *proc_name;
};

static bool proc_name_finder_walker(GenericHashEntry *node, void *user_data) {
  Flow *f = (Flow*)node;
  struct proc_name_flows *info = (struct proc_name_flows*)user_data;
  char *name = f->get_proc_name(true);

  if(name && (strcmp(name, info->proc_name) == 0))
    f->lua(info->vm, NULL, false /* Minimum details */, true);
  else {
    name = f->get_proc_name(false);

    if(name && (strcmp(name, info->proc_name) == 0))
      f->lua(info->vm, NULL, false /* Minimum details */, true);
  }

  return(false); /* false = keep on walking */
}

void NetworkInterface::findProcNameFlows(lua_State *vm, char *proc_name) {
  struct proc_name_flows u;

  u.vm = vm, u.proc_name = proc_name;
  flows_hash->walk(proc_name_finder_walker, &u);
}

/* **************************************************** */

struct pid_flows {
  lua_State* vm;
  u_int32_t pid;
};

static bool pidfinder_walker(GenericHashEntry *node, void *pid_data) {
  Flow *f = (Flow*)node;
  struct pid_flows *info = (struct pid_flows*)pid_data;

  if((f->getPid(true) == info->pid) || (f->getPid(false) == info->pid))
    f->lua(info->vm, NULL, false /* Minimum details */, true);

  return(false); /* false = keep on walking */
}

/* **************************************** */

void NetworkInterface::findPidFlows(lua_State *vm, u_int32_t pid) {
  struct pid_flows u;

  u.vm = vm, u.pid = pid;
  flows_hash->walk(pidfinder_walker, &u);
}

/* **************************************** */

static bool father_pidfinder_walker(GenericHashEntry *node, void *father_pid_data) {
  Flow *f = (Flow*)node;
  struct pid_flows *info = (struct pid_flows*)father_pid_data;

  if((f->getFatherPid(true) == info->pid) || (f->getFatherPid(false) == info->pid))
    f->lua(info->vm, NULL, false /* Minimum details */, true);

  return(false); /* false = keep on walking */
}

/* **************************************** */

void NetworkInterface::findFatherPidFlows(lua_State *vm, u_int32_t father_pid) {
  struct pid_flows u;

  u.vm = vm, u.pid = father_pid;
  flows_hash->walk(father_pidfinder_walker, &u);
}

/* **************************************** */

struct virtual_host_valk_info {
  lua_State *vm;
  char *key;
  u_int32_t num;
};

static bool virtual_http_hosts_walker(GenericHashEntry *node, void *data) {
  Host *h = (Host*)node;
  struct virtual_host_valk_info *info = (struct virtual_host_valk_info*)data;
  HTTPStats *s = h->getHTTPStats();

  if(s)
    info->num += s->luaVirtualHosts(info->vm, info->key, h);

  return(false); /* false = keep on walking */
}

/* **************************************** */

void NetworkInterface::listHTTPHosts(lua_State *vm, char *key) {
  struct virtual_host_valk_info info;

  info.vm = vm, info.key = key, info.num = 0;
  hosts_hash->walk(virtual_http_hosts_walker, &info);
}

/* **************************************** */

bool NetworkInterface::isInterfaceUp(char *name) {
#ifdef WIN32
  return(true);
#else
  struct ifreq ifr;
  int sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);

  memset(&ifr, 0, sizeof(ifr));
  strcpy(ifr.ifr_name, name);
  if(ioctl(sock, SIOCGIFFLAGS, &ifr) < 0) {
    closesocket(sock);
    return(false);
  }
  closesocket(sock);
  return(!!(ifr.ifr_flags & IFF_UP));
#endif
}

/* **************************************** */

void NetworkInterface::addAllAvailableInterfaces() {
  char ebuf[256] = { '\0' };
  pcap_if_t *devpointer;

  if(pcap_findalldevs(&devpointer, ebuf) < 0) {
    ;
  } else {
    for(int i = 0; devpointer != 0; i++) {
      if(validInterface(devpointer->description)
	 && isInterfaceUp(devpointer->name)) {
	ntop->getPrefs()->add_network_interface(devpointer->name,
						devpointer->description);
      } else
	ntop->getTrace()->traceEvent(TRACE_INFO, "Interface [%s][%s] not valid or down: discarded",
				     devpointer->name, devpointer->description);

      devpointer = devpointer->next;
    } /* for */
  }
}

/* **************************************** */

#ifdef NTOPNG_PRO
void NetworkInterface::refreshL7Rules() {
  if(ntop->getPro()->has_valid_license() && policer)
    policer->refreshL7Rules();
}
#endif

/* **************************************** */

#ifdef NTOPNG_PRO
void NetworkInterface::refreshShapers() {
  if(ntop->getPro()->has_valid_license() && policer)
    policer->refreshShapers();
}
#endif

/* **************************************** */

void NetworkInterface::addInterfaceAddress(char *addr) {
  if(ip_addresses.size() == 0)
    ip_addresses = addr;
  else {
    string s = addr;

    ip_addresses = ip_addresses + "," + s;
  }
}

/* **************************************** */

void NetworkInterface::allocateNetworkStats() {
  u_int8_t numNetworks = ntop->getNumLocalNetworks();

  try {
    networkStats = new NetworkStats[numNetworks];
  } catch(std::bad_alloc& ba) {
    static bool oom_warning_sent = false;

    if(!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      oom_warning_sent = true;
    }

    networkStats = NULL;
  }
}

/* **************************************** */

NetworkStats* NetworkInterface::getNetworkStats(u_int8_t networkId) {
  if((networkStats == NULL) || (networkId >= ntop->getNumLocalNetworks()))
    return(NULL);
  else
    return(&networkStats[networkId]);
}

/* **************************************** */

void NetworkInterface::updateSecondTraffic(time_t when) {
  u_int64_t bytes = ethStats.getNumBytes();
  u_int16_t sec = when % 60;

  if(sec == 0) {
    /* Beginning of a new minute */
    memcpy(lastMinuteTraffic, currentMinuteTraffic, sizeof(currentMinuteTraffic));
    resetSecondTraffic();
  }

  currentMinuteTraffic[sec] = max_val(0, bytes-lastSecTraffic);
  lastSecTraffic = bytes;
};
