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

/* Lua.cpp */
extern int ntop_lua_cli_print(lua_State* vm);
extern int ntop_lua_check(lua_State* vm, const char* func, int pos, int expected_type);

static bool help_printed = false;

/* **************************************************** */

/* Method used for collateral activities */
NetworkInterface::NetworkInterface() { init(); }

/* **************************************************** */

static const char * activity_names [] = {
  "None",
  "Other",
  "Web",
  "Media",
  "VPN",
  "MailSync",
  "MailSend",
  "FileSharing"
};
COMPILE_TIME_ASSERT (COUNT_OF(activity_names) == UserActivitiesN);

/* **************************************************** */

NetworkInterface::NetworkInterface(const char *name) {
  NDPI_PROTOCOL_BITMASK all;
  char _ifname[64];

  init();
#ifdef WIN32
  if(name == NULL) name = "1"; /* First available interface */
#endif

  remoteIfname = remoteIfIPaddr = remoteProbeIPaddr = remoteProbePublicIPaddr = NULL;
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

  pkt_dumper_tap = NULL, lastSecUpdate = 0;
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
    ndpi_struct = ndpi_init_detection_module();
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

    last_pkt_rcvd = last_pkt_rcvd_remote = 0, pollLoopCreated = false, bridge_interface = false;
    next_idle_flow_purge = next_idle_host_purge = 0;
    cpu_affinity = -1 /* no affinity */, has_vlan_packets = false, pkt_dumper = NULL;
    if(ntop->getPrefs()->are_taps_enabled())
      pkt_dumper_tap = new PacketDumperTuntap(this);

    running = false, sprobe_interface = false, inline_interface = false;

    if(ntop->getPrefs()->do_dump_flows_on_mysql())
      db = new MySQLDB(this);

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

  statsManager  = new StatsManager(id, STATS_MANAGER_STORE_NAME);
  alertsManager = new AlertsManager(id, ALERTS_MANAGER_STORE_NAME);
}

/* **************************************************** */

void NetworkInterface::init() {
  ifname = remoteIfname = remoteIfIPaddr = remoteProbeIPaddr = NULL,
    remoteProbePublicIPaddr = NULL, flows_hash = NULL, hosts_hash = NULL,
    ndpi_struct = NULL, zmq_initial_bytes = 0, zmq_initial_pkts = 0;
    sprobe_interface = inline_interface = false,has_vlan_packets = false,
      last_pkt_rcvd = last_pkt_rcvd_remote = 0, next_idle_flow_purge = next_idle_host_purge = 0,
      running = false, 
    pcap_datalink_type = 0, mtuWarningShown = false, lastSecUpdate = 0;
    purge_idle_flows_hosts = true, id = (u_int8_t)-1, last_remote_pps = 0, last_remote_bps = 0;
    sprobe_interface = false, has_vlan_packets = false,
    pcap_datalink_type = 0, cpu_affinity = -1 /* no affinity */,
      inline_interface = false, running = false, interfaceStats = NULL,
      tooManyFlowsAlertTriggered = tooManyHostsAlertTriggered = false,
      pkt_dumper = NULL;
  pollLoopCreated = false, bridge_interface = false;
  if(ntop && ntop->getPrefs() && ntop->getPrefs()->are_taps_enabled())
    pkt_dumper_tap = new PacketDumperTuntap(this);
  else
    pkt_dumper_tap = NULL;

    ip_addresses = "", networkStats = NULL,
    pcap_datalink_type = 0, cpu_affinity = -1,
      pkt_dumper = NULL;

  tcpPacketStats.pktRetr = tcpPacketStats.pktOOO = tcpPacketStats.pktLost = 0;
  memset(lastMinuteTraffic, 0, sizeof(lastMinuteTraffic));
  resetSecondTraffic();

  reloadLuaInterpreter = true, L_flow_create = L_flow_delete = L_flow_update = NULL;

  db = NULL;
#ifdef NTOPNG_PRO
  policer = NULL;
#endif
  statsManager = NULL, alertsManager = NULL, ifSpeed = 0;
  checkIdle();
  dump_all_traffic = dump_to_disk = dump_unknown_traffic
    = dump_security_packets = dump_to_tap = false;
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
    ndpi_exit_detection_module(ndpi_struct);
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

  if(remoteIfname)      free(remoteIfname);
  if(remoteIfIPaddr)    free(remoteIfIPaddr);
  if(remoteProbeIPaddr) free(remoteProbeIPaddr);
  if(remoteProbePublicIPaddr) free(remoteProbePublicIPaddr);
  if(db) delete db;
  if(statsManager) delete statsManager;
  if(alertsManager) delete alertsManager;
  if(networkStats) delete []networkStats;
  if(pkt_dumper)   delete pkt_dumper;
  if(pkt_dumper_tap) delete pkt_dumper_tap;
  if(interfaceStats) delete interfaceStats;

#ifdef NTOPNG_PRO
  if(policer)  delete(policer);
  if(flow_profiles) delete(flow_profiles);
#endif

  termLuaInterpreter();
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
    rc = ntop->getElasticSearch()->sendToES(json);
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

#ifdef NOTUSED
static bool node_proto_guess_walker(GenericHashEntry *node, void *user_data) {
  Flow *flow = (Flow*)node;
  char buf[512];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", flow->print(buf, sizeof(buf)));

  return(false); /* false = keep on walking */
}
#endif

/* **************************************************** */

#ifdef NOTUSED
void NetworkInterface::dumpFlows() {
  /* NOTUSED */
  flows_hash->walk(node_proto_guess_walker, NULL);
}
#endif

/* **************************************************** */

Flow* NetworkInterface::getFlow(u_int8_t *src_eth, u_int8_t *dst_eth,
				u_int16_t vlan_id,
				u_int32_t deviceIP, u_int16_t inIndex, u_int16_t outIndex,
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

      triggerTooManyFlowsAlert();
      return(NULL);
    }

    if(flows_hash->add(ret)) {
      *src2dst_direction = true;
      if(inIndex && ret->get_cli_host()) ret->get_cli_host()->setDeviceIfIdx(deviceIP, inIndex);
      /*
	We have decided to set only ingress traffic to make sure we do not mix truth with invalid data
	if(outIndex && ret->get_srv_host()) ret->get_srv_host()->setDeviceIfIdx(deviceIP, outIndex);
      */
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

void NetworkInterface::triggerTooManyFlowsAlert() {
  if(!tooManyFlowsAlertTriggered) {
    char alert_msg[512];

    snprintf(alert_msg, sizeof(alert_msg),
	     "Interface <A HREF='%s/lua/if_stats.lua?id=%d'>%s</A> has too many flows. Please extend the --max-num-flows/-X command line option",
	     ntop->getPrefs()->get_http_prefix(),
	     id, get_name());

    alertsManager->queueAlert(alert_level_error, alert_on, alert_app_misconfiguration, alert_msg);
    tooManyFlowsAlertTriggered = true;
  }
}

/* **************************************************** */

void NetworkInterface::triggerTooManyHostsAlert() {
  if(!tooManyHostsAlertTriggered) {
    char alert_msg[512];

    snprintf(alert_msg, sizeof(alert_msg),
	     "Interface <A HREF='%s/lua/if_stats.lua?id=%d'>%s</A> has too many hosts. Please extend the --max-num-hosts/-x command line option",
	     ntop->getPrefs()->get_http_prefix(),
	     id, get_name());

    alertsManager->queueAlert(alert_level_error, alert_on, alert_app_misconfiguration, alert_msg);
    tooManyHostsAlertTriggered = true;
  }
}

/* **************************************************** */

void NetworkInterface::processFlow(ZMQ_Flow *zflow) {
  bool src2dst_direction, new_flow;
  Flow *flow;
  ndpi_protocol p;
  time_t now = time(NULL);

  if(last_pkt_rcvd_remote > 0) {
    int drift = now - last_pkt_rcvd_remote;

    if(drift >= 0)
      zflow->last_switched += drift, zflow->first_switched += drift;
    else {
      u_int32_t d = (u_int32_t)-drift;

      if(d < zflow->last_switched)  zflow->last_switched  += drift;
      if(d < zflow->first_switched) zflow->first_switched += drift;
    }

#ifdef DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[first=%u][last=%u][duration: %u][drift: %d][now: %u][remote: %u]",
				 zflow->first_switched,  zflow->last_switched,
				 zflow->last_switched-zflow->first_switched, drift,
				 now, last_pkt_rcvd_remote);
#endif
  } else {
    /* Old nProbe */

    if((time_t)zflow->last_switched > (time_t)last_pkt_rcvd_remote)
      last_pkt_rcvd_remote = zflow->last_switched;

#ifdef DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[first=%u][last=%u][duration: %u]",
				 zflow->first_switched,  zflow->last_switched,
				 zflow->last_switched- zflow->first_switched);
#endif
  }

  /* Updating Flow */
  flow = getFlow((u_int8_t*)zflow->src_mac, (u_int8_t*)zflow->dst_mac, zflow->vlan_id,
		 zflow->deviceIP, zflow->inIndex, zflow->outIndex,
		 &zflow->src_ip, &zflow->dst_ip,
		 zflow->src_port, zflow->dst_port,
		 zflow->l4_proto, &src2dst_direction,
		 zflow->first_switched,
		 zflow->last_switched, &new_flow);

  if(flow == NULL) return;

  if(zflow->l4_proto == IPPROTO_TCP) {
    struct timeval when;

    when.tv_sec = (long)now, when.tv_usec = 0;
    flow->updateTcpFlags((const struct bpf_timeval*)&when,
			 zflow->tcp_flags, src2dst_direction);
  }

  flow->addFlowStats(src2dst_direction,
		     zflow->pkt_sampling_rate*zflow->in_pkts,
		     zflow->pkt_sampling_rate*zflow->in_bytes, 0,
		     zflow->pkt_sampling_rate*zflow->out_pkts, 0,
		     zflow->pkt_sampling_rate*zflow->out_bytes,
		     zflow->last_switched);
  p.protocol = zflow->l7_proto, p.master_protocol = NDPI_PROTOCOL_UNKNOWN;
  flow->setDetectedProtocol(p, true);
  flow->setJSONInfo(json_object_to_json_string(zflow->additional_fields));
  flow->updateActivities();

  flow->updateInterfaceLocalStats(src2dst_direction,
			     zflow->pkt_sampling_rate*(zflow->in_pkts+zflow->out_pkts),
			     zflow->pkt_sampling_rate*(zflow->in_bytes+zflow->out_bytes));

  incStats(now, zflow->src_ip.isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
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

  if(zflow->dns_query) flow->setDNSQuery(zflow->dns_query);
  if(zflow->http_url)  flow->setHTTPURL(zflow->http_url);
  if(zflow->http_site) flow->setServerName(zflow->http_site);
  if(zflow->ssl_server_name) flow->setServerName(zflow->ssl_server_name);
  if(zflow->bittorrent_hash) flow->setBTHash(zflow->bittorrent_hash);

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

bool NetworkInterface::processPacket(const struct bpf_timeval *when,
				     const u_int64_t time,
				     struct ndpi_ethhdr *eth,
				     u_int16_t vlan_id,
				     struct ndpi_iphdr *iph,
				     struct ndpi_ipv6hdr *ip6,
				     u_int16_t ipsize,
				     u_int16_t rawsize,
				     const struct pcap_pkthdr *h,
				     const u_char *packet,
				     bool *shaped,
				     u_int16_t *ndpiProtocol) {
  bool src2dst_direction;
  u_int8_t l4_proto;
  Flow *flow;
  u_int8_t *eth_src = eth->h_source, *eth_dst = eth->h_dest;
  IpAddress src_ip, dst_ip;
  u_int16_t src_port = 0, dst_port = 0, payload_len = 0;
  struct ndpi_tcphdr *tcph = NULL;
  struct ndpi_udphdr *udph = NULL;
  u_int16_t l4_packet_len;
  u_int8_t *l4, tcp_flags = 0, *payload = NULL;
  u_int8_t *ip;
  bool is_fragment = false, new_flow;
  bool pass_verdict = true;
  int a_shaper_id = DEFAULT_SHAPER_ID, b_shaper_id = DEFAULT_SHAPER_ID; /* Default */

 decode_ip:
  if(iph != NULL) {
    /* IPv4 */
    if(ipsize < 20) {
      incStats(when->tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN,
	       rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
      // TODO: check if payload should be set to NULL when payload_len == 0
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
  } else if(l4_proto == IPPROTO_GRE) {
    struct grev1_header gre;
    int offset = sizeof(struct grev1_header);

    memcpy(&gre, l4, sizeof(struct grev1_header));
    gre.flags_and_version = ntohs(gre.flags_and_version);
    gre.proto = ntohs(gre.proto);

    if(gre.flags_and_version & (GRE_HEADER_CHECKSUM | GRE_HEADER_ROUTING)) offset += 4;
    if(gre.flags_and_version & GRE_HEADER_KEY)      offset += 4;
    if(gre.flags_and_version & GRE_HEADER_SEQ_NUM)  offset += 4;

    if(gre.proto == ETHERTYPE_IP) {
      iph = (struct ndpi_iphdr*)(l4 + offset), ip6 = NULL;
      goto decode_ip;
    } else if(gre.proto == ETHERTYPE_IPV6) {
      iph = (struct ndpi_iphdr*)(l4 + offset), ip6 = NULL;
      goto decode_ip;
    } else {
      /* Unknown encapsulation */
    }
  } else {
    /* non TCP/UDP protocols */
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
  flow = getFlow(eth_src, eth_dst, vlan_id, 0, 0, 0, &src_ip, &dst_ip, src_port, dst_port,
		 l4_proto, &src2dst_direction, last_pkt_rcvd_remote, last_pkt_rcvd_remote, &new_flow);

  if(flow == NULL) {
    incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
	     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    return(pass_verdict);
  } else {
    flow->incStats(src2dst_direction, h->len, payload, payload_len, l4_proto, &h->ts);

    switch(l4_proto) {
    case IPPROTO_TCP:
      flow->updateTcpFlags(when, tcp_flags, src2dst_direction);
      flow->updateTcpSeqNum(when, ntohl(tcph->seq), ntohl(tcph->ack_seq), ntohs(tcph->window),
			    tcp_flags, l4_packet_len - (4 * tcph->doff),
			    src2dst_direction);
      break;

    case IPPROTO_ICMP:
    case IPPROTO_ICMPV6:
      if(l4_packet_len > 2) {
	u_int8_t icmp_type = l4[0];
	u_int8_t icmp_code = l4[1];

	flow->setICMP(icmp_type, icmp_code);
      }
      break;
    }
  }

  /* Protocol Detection */
  flow->updateActivities();
  flow->updateInterfaceLocalStats(src2dst_direction, 1, h->len);

  if(!flow->isDetectionCompleted()) {
    if(!is_fragment) {
      struct ndpi_flow_struct *ndpi_flow = flow->get_ndpi_flow();
      struct ndpi_id_struct *cli = (struct ndpi_id_struct*)flow->get_cli_id();
      struct ndpi_id_struct *srv = (struct ndpi_id_struct*)flow->get_srv_id();

      if(flow->get_packets() >= NDPI_MIN_NUM_PACKETS)
	flow->setDetectedProtocol(ndpi_detection_giveup(ndpi_struct, ndpi_flow), false);
      else
	flow->setDetectedProtocol(ndpi_detection_process_packet(ndpi_struct, ndpi_flow,
								ip, ipsize, (u_int32_t)time,
								cli, srv), false);
    } else {
      // FIX - only handle unfragmented packets
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "IP fragments are not handled yet!");
    }
  }

  if(flow->isDetectionCompleted()
     && flow->get_cli_host()
     && flow->get_srv_host()) {
    struct ndpi_flow_struct *ndpi_flow;

    switch(ndpi_get_lower_proto(flow->get_detected_protocol())) {
    case NDPI_PROTOCOL_BITTORRENT:
      if((flow->getBitTorrentHash() == NULL)
	 && (l4_proto == IPPROTO_UDP)
	 && (flow->get_packets() < 8))
	flow->dissectBittorrent((char*)payload, payload_len);
      break;

    case NDPI_PROTOCOL_HTTP:
      if(payload_len > 0)
	flow->dissectHTTP(src2dst_direction, (char*)payload, payload_len);
      break;

    case NDPI_PROTOCOL_DNS:
      ndpi_flow = flow->get_ndpi_flow();

      /*
      DNS-over-TCP flows may carry zero-payload TCP segments
      e.g., during three-way-handshake, or when acknowledging.
      Make sure only non-zero-payload segments are processed.
      */
      if(payload_len > 0 && payload) {
	/*
	DNS-over-TCP has a 2-bytes field with DNS payload length
	at the beginning. See RFC1035 section 4.2.2. TCP usage.
	*/
	u_int8_t dns_offset = l4_proto == IPPROTO_TCP && payload_len > 1 ? 2 : 0;

	struct ndpi_dns_packet_header *header = (struct ndpi_dns_packet_header*)(payload + dns_offset);
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
	    u_int8_t ret_code = (dns_flags & 0x000F);

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

    default:
      if (flow->isSSLProto())
        flow->dissectSSL(payload, payload_len, when);
    }

#if 0
    if (flow->isSSLData())
      ; // TODO use SSL data
#endif

    flow->processDetectedProtocol(), *shaped = false;
    pass_verdict = flow->isPassVerdict();
    flow->getFlowShapers(src2dst_direction, &a_shaper_id, &b_shaper_id, ndpiProtocol);

#ifdef NTOPNG_PRO
    if(pass_verdict) {
      pass_verdict = passShaperPacket(a_shaper_id, b_shaper_id, (struct pcap_pkthdr*)h);
      if(!pass_verdict) *shaped = true;
    }
#endif

    if(pass_verdict)
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

  } else
    incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	     flow->get_detected_protocol().protocol,
	     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);

  // Detect user activities
  UserActivityID activity = flow->getActivityId();
  u_int64_t up=0, down=0, backgr=0, bytes=payload_len;
  if (activity != user_activity_none) {
    Host *cli = flow->get_cli_host();
    Host *srv = flow->get_srv_host();

    if (!flow->isSSLHandshake() && flow->invokeActivityFilter(when, src2dst_direction, payload_len)) {
      if (src2dst_direction)
        up = bytes;
      else
        down = bytes;
    } else {
      backgr = bytes;
    }

    if (cli->isLocalHost())
      cli->incActivityBytes(activity, up, down, backgr);
    if (srv->isLocalHost())
      srv->incActivityBytes(activity, down, up, backgr);
  }

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
				     const u_char *packet, bool *shaped,
				     u_int16_t *ndpiProtocol) {
  struct ndpi_ethhdr *ethernet, dummy_ethernet;
  u_int64_t time;
  static u_int64_t lasttime = 0;
  u_int16_t eth_type, ip_offset, vlan_id = 0, eth_offset = 0;
  u_int32_t null_type;
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

  time = ((uint64_t) h->ts.tv_sec) * 1000 + h->ts.tv_usec / 1000;
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

	  if(ip_offset >= h->len) {
	    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    return(pass_verdict);
	  }
	  eth_type = ntohs(*(u_int16_t*)&packet[ip_offset-2]);

	  switch(eth_type) {
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
	pass_verdict = processPacket(&h->ts, time, ethernet, vlan_id, iph,
				     ip6, h->caplen - ip_offset, h->len,
				     h, packet, shaped, ndpiProtocol);
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

	if(ntop->getGlobals()->decode_tunnels() && (l4_proto == IPPROTO_UDP)) {
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

	    if(ip_offset >= h->len) {
	      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, h->len, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      return(pass_verdict);
	    }
	    eth_type = ntohs(*(u_int16_t*)&packet[ip_offset-2]);

	    switch(eth_type) {
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
	  pass_verdict = processPacket(&h->ts, time, ethernet, vlan_id,
				       iph, ip6, h->len - ip_offset, h->len,
				       h, packet, shaped, ndpiProtocol);
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
      srcHost->incStats(0, NO_NDPI_PROTOCOL, NULL, 1, h->len, h->len-ip_offset, 0, 0, 0);
      srcHost->updateActivities();
    }

    if(dstHost) {
      dstHost->incStats(0, NO_NDPI_PROTOCOL, NULL, 0, 0, 0, 1, h->len, h->len-ip_offset);
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
      triggerTooManyHostsAlert();
      return;
    }

    (*src) = new Host(this, src_mac, vlanId, _src_ip);
    if(!hosts_hash->add(*src)) {
      //ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
      delete *src;
      *src = *dst = NULL;
      triggerTooManyHostsAlert();
      return;
    }
  }

  /* ***************************** */

  (*dst) = hosts_hash->get(vlanId, _dst_ip);

  if((*dst) == NULL) {
    if(!hosts_hash->hasEmptyRoom()) {
      *dst = NULL;
      triggerTooManyHostsAlert();
      return;
    }

    (*dst) = new Host(this, dst_mac, vlanId, _dst_ip);
    if(!hosts_hash->add(*dst)) {
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
      delete *dst;
      *dst = NULL;
      triggerTooManyHostsAlert();
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

  flow->update_hosts_stats(tv, false);
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
  Host *h = (Host*)node;
  patricia_tree_t *ptree = (patricia_tree_t*)user_data;

  if((ptree == NULL) || h->match(ptree))
    ((Host*)node)->updateHostL7Policy();

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::updateHostsL7Policy(patricia_tree_t *ptree) {
  hosts_hash->walk(update_host_l7_policy, ptree);
}

/* **************************************************** */

static bool update_flow_l7_policy(GenericHashEntry *node, void *user_data) {
  patricia_tree_t *ptree = (patricia_tree_t*)user_data;
  Flow *f = (Flow*)node;

  if((ptree == NULL)
     || (f->get_cli_host() && f->get_cli_host()->match(ptree))
     || (f->get_srv_host() && f->get_srv_host()->match(ptree)))
    ((Flow*)node)->makeVerdict(true);

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::updateFlowsL7Policy(patricia_tree_t *ptree) {
  flows_hash->walk(update_flow_l7_policy, ptree);
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

/* **************************************************** */

void NetworkInterface::updateFlowProfiles(char *old_profile, char *new_profile) {
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
    h->lua(vm, allowed_hosts, true, true, true, false, false);
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


struct flowHostRetrieveList {
  Flow *flow;
  /* Value */
  Host *hostValue;
  u_int64_t numericValue;
  char *stringValue;
};

struct flowHostRetriever {
  /* Search criteria */
  patricia_tree_t *allowed_hosts;
  Host *host;
  char *country;
  int ndpi_proto;
  sortField sorter;
  LocationPolicy location;
  u_int16_t *vlan_id;
  char *osFilter;
  u_int32_t *asnFilter;
  int16_t *networkFilter;

  /* Return values */
  u_int32_t maxNumEntries, actNumEntries;
  struct flowHostRetrieveList *elems;

  /* Paginator */
  Paginator *pag;
};

/* **************************************************** */

static bool flow_search_walker(GenericHashEntry *h, void *user_data) {
  struct flowHostRetriever *retriever = (struct flowHostRetriever*)user_data;
  Flow *f = (Flow*)h;
  int ndpi_proto;
  u_int16_t port;
  int16_t local_network_id;

  if(f && (!f->idle())) {
    if(retriever->host
       && (retriever->host != f->get_cli_host())
       && (retriever->host != f->get_srv_host()))
    return(false); /* false = keep on walking */

    if(retriever->pag
       && retriever->pag->l7protoFilter(&ndpi_proto)
       && ndpi_proto != -1
       && (f->get_detected_protocol().protocol != ndpi_proto)
       && (f->get_detected_protocol().master_protocol != ndpi_proto))
      return(false); /* false = keep on walking */

    if(retriever->pag
       && retriever->pag->portFilter(&port)
       && f->get_cli_port() != port
       && f->get_srv_port() != port)
      return(false); /* false = keep on walking */

    if(retriever->pag
       && retriever->pag->localNetworkFilter(&local_network_id)
       && f->get_cli_host()->get_local_network_id() != local_network_id
       && f->get_srv_host()->get_local_network_id() != local_network_id)
      return(false); /* false = keep on walking */

    if(retriever->location == location_local_only) {
      if((!f->get_cli_host()->isLocalHost())
	 || (!f->get_srv_host()->isLocalHost()))
	return(false); /* false = keep on walking */
    } else if(retriever->location == location_remote_only) {
      if((f->get_cli_host()->isLocalHost())
	 || (f->get_srv_host()->isLocalHost()))
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
      case column_vlan:
	retriever->elems[retriever->actNumEntries++].numericValue = f->get_vlan_id();
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
	if(f->getDNSQuery())            retriever->elems[retriever->actNumEntries++].stringValue = f->getDNSQuery();
	else if(f->getHTTPURL())        retriever->elems[retriever->actNumEntries++].stringValue = f->getHTTPURL();
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
  char buf[64];
  struct flowHostRetriever *r = (struct flowHostRetriever*)user_data;
  Host *h = (Host*)he;

  if(!h || h->idle() || !h->match(r->allowed_hosts))
    return(false);

  if((r->location == location_local_only      && !h->isLocalHost())         ||
     (r->location == location_remote_only     && h->isLocalHost())          ||
     (r->vlan_id       && *(r->vlan_id)       != h->get_vlan_id())          ||
     (r->asnFilter     && *(r->asnFilter)     != h->get_asn())              ||
     (r->networkFilter && *(r->networkFilter) != h->get_local_network_id()) ||
     (r->country  && strlen(r->country)  && (!h->get_country() || strcmp(h->get_country(), r->country))) ||
     (r->osFilter && strlen(r->osFilter) && (!h->get_os()      || strcmp(h->get_os(), r->osFilter))))
    return(false); /* false = keep on walking */

  r->elems[r->actNumEntries].hostValue = h;

  switch(r->sorter) {
  case column_ip:
    r->elems[r->actNumEntries++].hostValue = h; /* hostValue was already set */
    break;
  case column_alerts:
    r->elems[r->actNumEntries++].numericValue = h->getNumAlerts();
    break;
  case column_name:
    {
      r->elems[r->actNumEntries++].stringValue = strdup(h->get_name(buf, sizeof(buf), false));
    }
    break;
  case column_country:
    {
      r->elems[r->actNumEntries++].stringValue = strdup(h->get_country() ? h->get_country() : (char*)"");
    }
    break;
  case column_os:
    {
      r->elems[r->actNumEntries++].stringValue = strdup(h->get_os() ? h->get_os() : (char*)"");
    }
    break;
  case column_vlan:
    r->elems[r->actNumEntries++].numericValue = h->get_vlan_id();
    break;
  case column_since:
    r->elems[r->actNumEntries++].numericValue = h->get_first_seen();
    break;
  case column_asn:
    r->elems[r->actNumEntries++].numericValue = h->get_asn();
    break;
  case column_thpt:
    r->elems[r->actNumEntries++].numericValue = h->getBytesThpt();
    break;
  case column_traffic:
    r->elems[r->actNumEntries++].numericValue = h->getNumBytes();
    break;
  case column_local_network_id:
    r->elems[r->actNumEntries++].numericValue = h->get_local_network_id();
    break;
  case column_mac:
    r->elems[r->actNumEntries++].numericValue = Utils::macaddr_int(h->get_mac());
    break;
  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
    break;
  }

  if(r->actNumEntries == r->maxNumEntries)
    return(true); /* Limit reached */
  else
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
			       Host *host, int ndpi_proto,
			       LocationPolicy location,
			       char *sortColumn,
			       u_int32_t maxHits,
			       u_int32_t toSkip,
			       bool a2zSortOrder) {
  struct flowHostRetriever retriever;
  int (*sorter)(const void *_a, const void *_b);
  bool highDetails = (location == location_local_only || (maxHits != CONST_MAX_NUM_HITS)) ? true : false;

  if(maxHits > CONST_MAX_NUM_HITS) maxHits = CONST_MAX_NUM_HITS;
  retriever.pag = NULL;
  retriever.host = host, retriever.ndpi_proto = ndpi_proto, retriever.location = location;
  retriever.actNumEntries = 0, retriever.maxNumEntries = flows_hash->getNumEntries(), retriever.allowed_hosts = allowed_hosts;
  retriever.elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever.maxNumEntries);

  if(retriever.elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if(!strcmp(sortColumn, "column_client")) retriever.sorter = column_client, sorter = hostSorter;
  else if(!strcmp(sortColumn, "column_vlan")) retriever.sorter = column_vlan, sorter = numericSorter;
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

  if(a2zSortOrder) {
    for(int i=toSkip, num=0; i<(int)retriever.actNumEntries; i++) {
      lua_newtable(vm);

      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);

      lua_pushnumber(vm, num + 1);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if(++num >= (int)maxHits) break;

    }
  } else {
    for(int i=(retriever.actNumEntries-1-toSkip), num=0; i>=0; i--) {
      lua_newtable(vm);

      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);

      lua_pushnumber(vm, num + 1);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if(++num >= (int)maxHits) break;
    }
  }

  flows_hash->enablePurge();
  free(retriever.elems);

  return(retriever.actNumEntries);
}
/* **************************************************** */

int NetworkInterface::getFlows(lua_State* vm,
			       patricia_tree_t *allowed_hosts,
			       LocationPolicy location, Host *host,
			       Paginator *p) {
  struct flowHostRetriever retriever;
  int (*sorter)(const void *_a, const void *_b);
  char sortColumn[32];
  bool highDetails;

  if(p == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to return results with a NULL paginator");
    return(-1);
  }

  highDetails = p->detailedResults() ? true : (location == location_local_only || (p && p->maxHits() != CONST_MAX_NUM_HITS)) ? true : false;

  retriever.pag = p;
  retriever.host = host, retriever.location = location;
  retriever.actNumEntries = 0, retriever.maxNumEntries = flows_hash->getNumEntries(), retriever.allowed_hosts = allowed_hosts;
  retriever.elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever.maxNumEntries);

  if(retriever.elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  snprintf(sortColumn, sizeof(sortColumn), "%s", p->sortColumn());
  if(!strcmp(sortColumn, "column_client")) retriever.sorter = column_client, sorter = hostSorter;
  else if(!strcmp(sortColumn, "column_vlan")) retriever.sorter = column_vlan, sorter = numericSorter;
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

  if(p->a2zSortOrder()) {
    for(int i=p->toSkip(), num=0; i<(int)retriever.actNumEntries; i++) {
      lua_newtable(vm);

      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);

      lua_pushnumber(vm, num + 1);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if(++num >= (int)p->maxHits()) break;

    }
  } else {
    for(int i=(retriever.actNumEntries-1-p->toSkip()), num=0; i>=0; i--) {
      lua_newtable(vm);

      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);

      lua_pushnumber(vm, num + 1);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if(++num >= (int)p->maxHits()) break;
    }
  }

  flows_hash->enablePurge();
  free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getLatestActivityHostsList(lua_State* vm, patricia_tree_t *allowed_hosts) {
  struct flowHostRetriever retriever;

  memset(&retriever, 0, sizeof(retriever));

  // there's not even the need to use the retriever or to sort results here
  // we use the retriever just to leverage on the exising code.
  retriever.allowed_hosts = allowed_hosts, retriever.location = location_all;
  retriever.actNumEntries = 0, retriever.maxNumEntries = hosts_hash->getNumEntries();
  retriever.sorter = column_vlan; // just a placeholder, we don't care as we won't sort
  retriever.elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever.maxNumEntries);

  if(retriever.elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  hosts_hash->disablePurge();
  hosts_hash->walk(host_search_walker, (void*)&retriever);

  lua_newtable(vm);

  if(retriever.actNumEntries > 0) {
    for(int i=0; i<(int)retriever.actNumEntries; i++) {
      Host *h = retriever.elems[i].hostValue;

      if(i < CONST_MAX_NUM_HITS)
	h->lua(vm, NULL /* Already checked */,
	       false /* host details */,
	       false /* verbose */,
	       false /* return host */,
	       true  /* as list element*/,
	       true  /* exclude deserialized bytes */);
    }
  }

  hosts_hash->enablePurge();
  free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortHosts(struct flowHostRetriever *retriever,
				patricia_tree_t *allowed_hosts,
				bool host_details,
				LocationPolicy location,
				char *countryFilter,
				u_int16_t *vlan_id, char *osFilter,
				u_int32_t *asnFilter, int16_t *networkFilter,
				char *sortColumn, u_int32_t maxHits) {
  int (*sorter)(const void *_a, const void *_b);

  if(retriever == NULL)
    return -1;

  if(maxHits > CONST_MAX_NUM_HITS)
    maxHits = CONST_MAX_NUM_HITS;

  retriever->allowed_hosts = allowed_hosts;
  retriever->location = location;
  retriever->country = countryFilter;
  retriever->vlan_id = vlan_id;
  retriever->osFilter = osFilter;
  retriever->asnFilter = asnFilter;
  retriever->networkFilter = networkFilter;
  retriever->actNumEntries = 0;
  retriever->maxNumEntries = maxHits;
  retriever->elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if(retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if((!strcmp(sortColumn, "column_ip")) || (!strcmp(sortColumn, "column_"))) retriever->sorter = column_ip, sorter = hostSorter;
  else if(!strcmp(sortColumn, "column_vlan")) retriever->sorter = column_vlan, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_alerts")) retriever->sorter = column_alerts, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_name")) retriever->sorter = column_name, sorter = stringSorter;
  else if(!strcmp(sortColumn, "column_country")) retriever->sorter = column_country, sorter = stringSorter;
  else if(!strcmp(sortColumn, "column_os")) retriever->sorter = column_os, sorter = stringSorter;
  else if(!strcmp(sortColumn, "column_since")) retriever->sorter = column_since, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_asn")) retriever->sorter = column_asn, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt")) retriever->sorter = column_thpt, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic")) retriever->sorter = column_traffic, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_local_network_id")) retriever->sorter = column_local_network_id, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_mac")) retriever->sorter = column_mac, sorter = numericSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  hosts_hash->walk(host_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}
/* **************************************************** */

int NetworkInterface::getActiveHostsList(lua_State* vm, patricia_tree_t *allowed_hosts,
					 bool host_details, LocationPolicy location,
					 char *countryFilter,
					 u_int16_t *vlan_id, char *osFilter,
					 u_int32_t *asnFilter, int16_t *networkFilter,
					 char *sortColumn, u_int32_t maxHits,
					 u_int32_t toSkip, bool a2zSortOrder) {
  struct flowHostRetriever retriever;

  hosts_hash->disablePurge();

  if(sortHosts(&retriever, allowed_hosts, host_details, location,
	       countryFilter, vlan_id, osFilter, asnFilter, networkFilter,
	       sortColumn, hosts_hash->getCurrentSize()) < 0) {
    hosts_hash->enablePurge();
    return -1;
  }

  lua_newtable(vm);

  if(a2zSortOrder) {
    for(int i = toSkip, num=0; i<(int)retriever.actNumEntries && num < (int)maxHits; i++, num++) {
      Host *h = retriever.elems[i].hostValue;
      h->lua(vm, NULL /* Already checked */, host_details, false, false, true, false);
    }
  } else {
    for(int i = (retriever.actNumEntries-1-toSkip), num=0; i >= 0 && num < (int)maxHits; i--, num++) {
      Host *h = retriever.elems[i].hostValue;
      h->lua(vm, NULL /* Already checked */, host_details, false, false, true, false);
    }
  }

  hosts_hash->enablePurge();

  // it's up to us to clean sorted data
  // make sure first to free elements in case a string sorter has been used
  if(retriever.sorter == column_name
     || retriever.sorter == column_country
     || retriever.sorter == column_os) {
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].stringValue)
	free(retriever.elems[i].stringValue);
  }

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}
/* **************************************************** */

int NetworkInterface::getActiveHostsGroup(lua_State* vm, patricia_tree_t *allowed_hosts,
					  bool host_details, LocationPolicy location,
					  char *countryFilter,
					  u_int16_t *vlan_id, char *osFilter,
					  u_int32_t *asnFilter, int16_t *networkFilter,
					  char *groupColumn) {
  struct flowHostRetriever retriever;
  Grouper *gper;

  hosts_hash->disablePurge();

  // sort hosts according to the grouping criterion
  if(sortHosts(&retriever, allowed_hosts, host_details, location,
	       countryFilter, vlan_id, osFilter, asnFilter, networkFilter,
	       groupColumn, hosts_hash->getCurrentSize()) < 0 ) {
    hosts_hash->enablePurge();
    return -1;
  }

  // build a new grouper that will help in aggregating stats
  if((gper = new(std::nothrow) Grouper(retriever.sorter)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to allocate memory for a Grouper.");
    hosts_hash->enablePurge();
    return -1;
  }

  lua_newtable(vm);

  for(int i=0; i<(int)retriever.actNumEntries; i++) {
    Host *h = retriever.elems[i].hostValue;

    if(h) {
      if(gper->inGroup(h) == false) {
	if(gper->getNumEntries() > 0)
	  gper->lua(vm);
	gper->newGroup(h);
      }

      gper->incStats(h);
    }
  }

  if(gper->getNumEntries() > 0)
    gper->lua(vm);

 delete gper;
  gper = NULL;

  hosts_hash->enablePurge();

  // it's up to us to clean sorted data
  // make sure first to free elements in case a string sorter has been used
  if((retriever.sorter == column_name)
     || (retriever.sorter == column_country)
     || (retriever.sorter == column_os)) {
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].stringValue)
	free(retriever.elems[i].stringValue);
  }

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

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

  if((info->numIP == NULL) || flow->isFlowPeer(info->numIP, info->vlanId)) {
    flow->print_peers(info->vm, info->allowed_hosts,
		      (info->numIP == NULL) ? false : true);
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getFlowPeersList(lua_State* vm,
					patricia_tree_t *allowed_hosts,
					char *numIP, u_int16_t vlanId) {
  struct flow_peers_info info;

  lua_newtable(vm);

  info.vm = vm, info.numIP = numIP, info.vlanId = vlanId, info.allowed_hosts = allowed_hosts;
  flows_hash->walk(flow_peers_walker, (void*)&info);
}

/* **************************************************** */

class HostActivityRetriever {
public:
  IpAddress search;
  bool found;
  UserActivityCounter counters[UserActivitiesN];

  HostActivityRetriever(const char * ip) : search((char *)ip) { found = false; };
};

/* **************************************************** */

static bool host_activity_walker(GenericHashEntry *he, void *user_data) {
  HostActivityRetriever * r = (HostActivityRetriever *)user_data;
  Host *h = (Host*)he;
  int i;

  if(!h || !h->equal(&r->search))
    return (false); /* false = keep on walking */

  r->found = true;
  for (i=0; i<UserActivitiesN; i++)
    r->counters[i] = *h->getActivityBytes((UserActivityID) i);
  return true; /* found, stop walking */
}

/* **************************************************** */

void NetworkInterface::getLocalHostActivity(lua_State* vm, const char * host) {
  HostActivityRetriever retriever(host);
  int i;

  hosts_hash->disablePurge();
  hosts_hash->walk(host_activity_walker, &retriever);
  hosts_hash->enablePurge();

  if (retriever.found) {
    lua_newtable(vm);
    // 0:user_activity_none -> skip
    for (i=1; i<UserActivitiesN; i++) {
      lua_newtable(vm);

      lua_push_int_table_entry(vm, "up", retriever.counters[i].up);
      lua_push_int_table_entry(vm, "down", retriever.counters[i].down);
      lua_push_int_table_entry(vm, "background", retriever.counters[i].background);

      lua_pushstring(vm, activity_names[i]);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  } else
    lua_pushnil(vm);
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

  lua_newtable(vm);

  for(i=0; i<(int)ndpi_struct->ndpi_num_supported_protocols; i++) {
    char buf[8];

    snprintf(buf, sizeof(buf), "%d", i);
    lua_push_str_table_entry(vm, ndpi_struct->proto_defaults[i].protoName, buf);
  }
}

/* **************************************************** */

#define NUM_TCP_STATES      4
/*
  0 = RST
  1 = SYN
  2 = Established
  3 = FIN
*/

static bool num_flows_state_walker(GenericHashEntry *node, void *user_data) {
  Flow *flow = (Flow*)node;
  u_int32_t *num_flows = (u_int32_t*)user_data;

  switch(flow->getFlowState()) {
  case flow_state_syn:
    num_flows[1]++;
    break;
  case flow_state_established:
    num_flows[2]++;
    break;
  case flow_state_rst:
    num_flows[0]++;
    break;
  case flow_state_fin:
    num_flows[3]++;
    break;
  default:
    /* UDP... */
    break;
  }

  return(false /* keep walking */);
}

/* *************************************** */

static bool num_flows_walker(GenericHashEntry *node, void *user_data) {
  Flow *flow = (Flow*)node;
  u_int32_t *num_flows = (u_int32_t*)user_data;

  num_flows[flow->get_detected_protocol().protocol]++;

  return(false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::getFlowsStatus(lua_State *vm) {
  u_int32_t num_flows[NUM_TCP_STATES] = { 0 };

  flows_hash->walk(num_flows_state_walker, num_flows);

  lua_push_int_table_entry(vm, "RST", num_flows[0]);
  lua_push_int_table_entry(vm, "SYN", num_flows[1]);
  lua_push_int_table_entry(vm, "Established", num_flows[2]);
  lua_push_int_table_entry(vm, "FIN", num_flows[3]);
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
  if(remoteIfname) lua_push_str_table_entry(vm, "remote.name",   remoteIfname);
  if(remoteIfIPaddr) lua_push_str_table_entry(vm, "remote.if_addr",   remoteIfIPaddr);
  if(remoteProbeIPaddr) lua_push_str_table_entry(vm, "probe.ip", remoteProbeIPaddr);
  if(remoteProbePublicIPaddr) lua_push_str_table_entry(vm, "probe.public_ip", remoteProbePublicIPaddr);
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

  lua_push_int_table_entry(vm, "remote_pps", last_remote_pps);
  lua_push_int_table_entry(vm, "remote_bps", last_remote_bps);

  lua_push_str_table_entry(vm, "type", (char*)get_type());
  lua_push_int_table_entry(vm, "speed", ifSpeed);
  lua_push_int_table_entry(vm, "mtu", ifMTU);
  lua_push_str_table_entry(vm, "ip_addresses", (char*)getLocalIPAddresses());

  tcpFlowStats.lua(vm, "tcpFlowStats");
  ethStats.lua(vm);
  localStats.lua(vm);
  ndpiStats.lua(this, vm);
  pktStats.lua(vm, "pktSizeDistribution");

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "retransmissions", tcpPacketStats.pktRetr);
  lua_push_int_table_entry(vm, "out_of_order", tcpPacketStats.pktOOO);
  lua_push_int_table_entry(vm, "lost", tcpPacketStats.pktLost);
  lua_pushstring(vm, "tcpPacketStats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

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

  if(user && (strcmp(user, info->username) == 0)) {
    f->lua(info->vm, NULL, false /* Minimum details */, false);
    lua_pushnumber(info->vm, f->key()); // Key
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
  }
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

  if(name && (strcmp(name, info->proc_name) == 0)) {
      f->lua(info->vm, NULL, false /* Minimum details */, false);
      lua_pushnumber(info->vm, f->key()); // Key
      lua_insert(info->vm, -2);
      lua_settable(info->vm, -3);
  } else {
    name = f->get_proc_name(false);

    if(name && (strcmp(name, info->proc_name) == 0)) {
        f->lua(info->vm, NULL, false /* Minimum details */, false);
        lua_pushnumber(info->vm, f->key()); // Key
        lua_insert(info->vm, -2);
        lua_settable(info->vm, -3);
    }
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

  if((f->getPid(true) == info->pid) || (f->getPid(false) == info->pid)) {
    f->lua(info->vm, NULL, false /* Minimum details */, false);
    lua_pushnumber(info->vm, f->key()); // Key
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
  }

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

  if((f->getFatherPid(true) == info->pid) || (f->getFatherPid(false) == info->pid)) {
    f->lua(info->vm, NULL, false /* Minimum details */, false);
    lua_pushnumber(info->vm, f->key()); // Key
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
  }

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
  HTTPstats *s = h->getHTTPstats();

  if(s)
    info->num += s->luaVirtualHosts(info->vm, info->key, h);

  return(false); /* false = keep on walking */
}

/* **************************************** */

void NetworkInterface::listHTTPHosts(lua_State *vm, char *key) {
  struct virtual_host_valk_info info;

  lua_newtable(vm);

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
    pcap_freealldevs(devpointer);
  }
}

/* **************************************** */

#ifdef NTOPNG_PRO
void NetworkInterface::refreshL7Rules(patricia_tree_t *ptree) {
  if(ntop->getPro()->has_valid_license() && policer)
    policer->refreshL7Rules(ptree);
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

/* **************************************** */

void NetworkInterface::setRemoteStats(char *name, char *address, u_int32_t speedMbit,
				      char *remoteProbeAddress, char *remoteProbePublicAddress,
				      u_int64_t remBytes, u_int64_t remPkts,
				      u_int32_t remTime, u_int32_t last_pps, u_int32_t last_bps) {
  if(name)               setRemoteIfname(name);
  if(address)            setRemoteIfIPaddr(address);
  if(remoteProbeAddress) setRemoteProbeAddr(remoteProbeAddress);
  if(remoteProbePublicAddress) setRemoteProbePublicAddr(remoteProbePublicAddress);
  ifSpeed = speedMbit, last_pkt_rcvd_remote = remTime, last_remote_pps = last_pps, last_remote_bps = last_bps;

  if((zmq_initial_pkts == 0) /* ntopng has been restarted */
     || (remBytes < zmq_initial_bytes) /* nProbe has been restarted */
     ) {
    /* Start over */
    zmq_initial_bytes = remBytes, zmq_initial_pkts = remPkts;
  } else {
    remBytes -= zmq_initial_bytes, remPkts -= zmq_initial_pkts;

    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s][bytes=%u/%u (%d)][pkts=%u/%u (%d)]",
				 ifname, remBytes, ethStats.getNumBytes(), remBytes-ethStats.getNumBytes(),
				 remPkts, ethStats.getNumPackets(), remPkts-ethStats.getNumPackets());
    ethStats.setNumBytes(remBytes), ethStats.setNumPackets(remPkts);
  }
}

/* **************************************** */

void NetworkInterface::processInterfaceStats(sFlowInterfaceStats *stats) {
  if(interfaceStats == NULL)
    interfaceStats = new InterfaceStatsHash(NUM_IFACE_STATS_HASH);

  if(interfaceStats) {
    char a[64];

    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s][ifIndex=%u]",
				 Utils::intoaV4(stats->deviceIP, a, sizeof(a)),
				 stats->ifIndex);

    interfaceStats->set(stats->deviceIP, stats->ifIndex, stats);
  }
}

/* **************************************** */

static int lua_flow_get_ndpi_proto(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, f->get_detected_protocol_name());
  return(CONST_LUA_OK);
}

/* **************************************** */

static int lua_flow_get_ndpi_proto_id(lua_State* vm) {
  Flow *f;
  ndpi_protocol p;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR); else p = f->get_detected_protocol();

  lua_pushnumber(vm, (p.protocol != NDPI_PROTOCOL_UNKNOWN) ? p.protocol : p.master_protocol);
  return(CONST_LUA_OK);
}

/* **************************************** */

static int lua_flow_get_first_seen(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  lua_pushnumber(vm, f->get_first_seen());
  return(CONST_LUA_OK);
}

/* **************************************** */

static int lua_flow_get_last_seen(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  lua_pushnumber(vm, f->get_last_seen());
  return(CONST_LUA_OK);
}

/* **************************************** */

static int lua_flow_get_server_name(lua_State* vm) {
  Flow *f;
  char buf[64];
  const char *srv;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  srv = f->getFlowServerInfo();
  if(!srv && f->get_srv_host())
    srv = f->get_srv_host()->get_name(buf, sizeof(buf), false);
  if(!srv) srv = "";

  lua_pushstring(vm, srv);
  return(CONST_LUA_OK);
}

/* **************************************** */

static int lua_flow_get_http_url(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, f->getHTTPURL());
  return(CONST_LUA_OK);
}

/* **************************************** */

static int lua_flow_dump(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  f->lua(vm, NULL, true, false);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/*
 * lua params:
 *    activityID  - ID of the activity to apply for filtered bytes
 *    filterID    - ID of the filter to apply to the flow for activity recording
 *    *parametes  - parameters to pass to the filter - See below
 *
 * None filter params:
 *
 * RollingMean filter params:
 *    edge         - rolling mean edge to trigger activity
 *    samples      - number of samples to keep
 *    minsamples   - minimum number of samples for activity detection
 *
 * CommandSequence filter params:
 *    mustwait     - if true, activity trigger requires server to wait after command request
 *    minbytes     - minimum number of bytes to trigger activity
 *    maxinterval  - maximum milliseconds difference between interactions
 *    minflips     - minimum number of server interactions to trigger activity
 *
 * Web filter params:
 */
static int lua_flow_set_activity_filter(lua_State* vm) {
  UserActivityID activityID;
  ActivityFilterID filterID;
  Flow *f;
  activity_filter_t *fun;
  activity_filter_config config = {};
  u_int8_t params = 0;
  bool hasparams;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, params+1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  activityID = (UserActivityID)lua_tonumber(vm, ++params);
  if (activityID >= UserActivitiesN) return(CONST_LUA_ERROR);

  if(lua_type(vm, params+1) == LUA_TNUMBER) {
    filterID = (ActivityFilterID)lua_tonumber(vm, ++params);
    hasparams = true;
  } else {
    filterID = activity_filter_none;
    hasparams = false;
  }

  // filter specific parameters
  switch(filterID) {
    case activity_filter_none:
      fun = &activity_filter_fun_none;
      break;

    case activity_filter_web:
      fun = &activity_filter_fun_web;
      break;

    case activity_filter_rolling_mean:
      if(hasparams && lua_type(vm, params+1) == LUA_TNUMBER) {
        config.rolling_mean.edge = lua_tonumber(vm, ++params);

        if (lua_type(vm, params+1) == LUA_TNUMBER) {
          config.rolling_mean.samples = lua_tonumber(vm, ++params);

          if (lua_type(vm, params+1) == LUA_TNUMBER)
            config.rolling_mean.minsamples = lua_tonumber(vm, ++params);
        }
      }

      // defaults
      switch (params) {
        case 2+0: config.rolling_mean.edge = 0;
        case 2+1: config.rolling_mean.samples = 10;
        case 2+2: config.rolling_mean.minsamples = config.rolling_mean.samples;
      }
      fun = &activity_filter_fun_rolling_mean;
      break;

    case activity_filter_command_sequence:
      if(hasparams && lua_type(vm, params+1) == LUA_TBOOLEAN) {
        config.command_sequence.mustwait = lua_toboolean(vm, ++params);

        if(lua_type(vm, params+1) == LUA_TNUMBER) {
          config.command_sequence.minbytes = lua_tonumber(vm, ++params);

          if (lua_type(vm, params+1) == LUA_TNUMBER) {
            config.command_sequence.maxinterval = lua_tonumber(vm, ++params);

            if (lua_type(vm, params+1) == LUA_TNUMBER)
              config.command_sequence.minflips = lua_tonumber(vm, ++params);
          }
        }
      }

      switch (params) {
        case 2+0: config.command_sequence.mustwait = false;
        case 2+1: config.command_sequence.minbytes = 0;
        case 2+2: config.command_sequence.maxinterval = 3000;
        case 2+3: config.command_sequence.minflips = 1;
      }
      fun = &activity_filter_fun_command_sequence;
      break;

    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid activity filter (%d)", filterID);
      return (CONST_LUA_ERROR);
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Flow %p setActivityFilter: filter=%d activity=%d", f, filterID, activityID);
  f->setActivityFilter(fun, &config);
  f->setActivityId(activityID);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static const luaL_Reg flow_reg[] = {
  { "getNdpiProto",      lua_flow_get_ndpi_proto },
  { "getNdpiProtoId",    lua_flow_get_ndpi_proto_id },
  { "getFirstSeen",      lua_flow_get_first_seen },
  { "getLastSeen",       lua_flow_get_last_seen },
  { "getServerName",     lua_flow_get_server_name },
  { "getHTTPUrl",        lua_flow_get_http_url },
  { "dump",              lua_flow_dump },
  { "setActivityFilter", lua_flow_set_activity_filter },
  { NULL,         NULL }
};

ntop_class_reg ntop_lua_reg[] = {
  { "flow",   flow_reg  },
  {NULL,      NULL}
};

lua_State* NetworkInterface::initLuaInterpreter(const char *lua_file) {
  static const luaL_Reg _meta[] = { { NULL, NULL } };
  int i;
  char script_path[256];
  lua_State *L;

  L = luaL_newstate();

  if(!L) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to initialize lua interpreter");
    return(NULL);
  }

  snprintf(script_path, sizeof(script_path), "%s/%s",
	   ntop->getPrefs()->get_callbacks_dir(),
	   lua_file);

  /* ******************************************** */

  luaL_openlibs(L); /* Load base libraries */

  for(i=0; ntop_lua_reg[i].class_name != NULL; i++) {
    int lib_id, meta_id;

    /* newclass = {} */
    lua_createtable(L, 0, 0);
    lib_id = lua_gettop(L);

    /* metatable = {} */
    luaL_newmetatable(L, ntop_lua_reg[i].class_name);
    meta_id = lua_gettop(L);
    luaL_register(L, NULL, _meta);

    /* metatable.__index = class_methods */
    lua_newtable(L), luaL_register(L, NULL, ntop_lua_reg[i].class_methods);
    lua_setfield(L, meta_id, "__index");

    /* class.__metatable = metatable */
    lua_setmetatable(L, lib_id);

    /* _G["Foo"] = newclass */
    lua_setglobal(L, ntop_lua_reg[i].class_name);
  }

  lua_register(L, "print", ntop_lua_cli_print);

  if(luaL_loadfile(L, script_path) || lua_pcall(L, 0, 0, 0)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Cannot run lua file %s: %s",
				 script_path, lua_tostring(L, -1));
    lua_close(L);
    L = NULL;
  } else {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Successfully interpreted %s", script_path);

    lua_pushlightuserdata(L, NULL);
    lua_setglobal(L, CONST_USERACTIVITY_FLOW);
  }

  // Activity profiles - see ntop_typedefs.h
  lua_newtable(L);
  lua_push_int_table_entry(L, activity_names[user_activity_none], user_activity_none);
  lua_push_int_table_entry(L, activity_names[user_activity_other], user_activity_other);
  lua_push_int_table_entry(L, activity_names[user_activity_web], user_activity_web);
  lua_push_int_table_entry(L, activity_names[user_activity_media], user_activity_media);
  lua_push_int_table_entry(L, activity_names[user_activity_vpn], user_activity_vpn);
  lua_push_int_table_entry(L, activity_names[user_activity_mail_sync], user_activity_mail_sync);
  lua_push_int_table_entry(L, activity_names[user_activity_mail_send], user_activity_mail_send);
  lua_push_int_table_entry(L, activity_names[user_activity_file_sharing], user_activity_file_sharing);
  lua_setglobal(L, CONST_USERACTIVITY_PROFILES);

  // Activity filters
  lua_newtable(L);
  lua_push_int_table_entry(L, "None", activity_filter_none);
  lua_push_int_table_entry(L, "RollingMean", activity_filter_rolling_mean);
  lua_push_int_table_entry(L, "CommandSequence", activity_filter_command_sequence);
  lua_push_int_table_entry(L, "Web", activity_filter_web);
  lua_setglobal(L, CONST_USERACTIVITY_FILTERS);

  return(L);
}

/* **************************************** */

void NetworkInterface::termLuaInterpreter() {
  if(L_flow_create) { lua_close(L_flow_create); L_flow_create = NULL; }
  if(L_flow_delete) { lua_close(L_flow_delete); L_flow_delete = NULL; }
  if(L_flow_update) { lua_close(L_flow_update); L_flow_update = NULL; }
}

/* **************************************** */

int NetworkInterface::luaEvalFlow(Flow *f, const LuaCallback cb) {
  int rc;
  lua_State *L;
  const char *luaFunction;

  if(reloadLuaInterpreter) {
    if(L_flow_create || L_flow_delete || L_flow_update) termLuaInterpreter();
    L_flow_create = initLuaInterpreter(CONST_FLOWACTIVITY_SCRIPT);
    L_flow_delete = initLuaInterpreter(CONST_FLOWACTIVITY_SCRIPT);
    L_flow_update = initLuaInterpreter(CONST_FLOWACTIVITY_SCRIPT);
    reloadLuaInterpreter = false;
  }

  switch(cb) {
  case callback_flow_create:
    L = L_flow_create, luaFunction = CONST_LUA_FLOW_CREATE;
    break;

  case callback_flow_delete:
    L = L_flow_delete, luaFunction = CONST_LUA_FLOW_DELETE;
    break;

  case callback_flow_update:
    L = L_flow_update, luaFunction = CONST_LUA_FLOW_UPDATE;
    break;

  case callback_flow_ndpi_detect:
    L = L_flow_create, luaFunction = CONST_LUA_FLOW_NDPI_DETECT;
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid lua callback (%d)", cb);
    return(-1);
  }

  lua_pushlightuserdata(L, f);
  lua_setglobal(L, CONST_USERACTIVITY_FLOW);

  lua_getglobal(L, luaFunction); /* function to be called */
  if((rc = lua_pcall(L, 0 /* 0 parameters */, 0 /* no return values */, 0)) != 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Error while executing %s [rc=%d][%s]", luaFunction, rc, lua_tostring(L, -1));
  }

  return(rc);
}

/* ******************************************* */

const char * getActivityName(UserActivityID id) {
  return ((id < UserActivitiesN) ? activity_names[id] : NULL);
};

/* ******************************************* */

UserActivityID getActivityId(const char * name) {
  if (name) {
    for (int i=0; i<UserActivitiesN; i++)
      if (strcmp(activity_names[i], name) == 0)
        return ((UserActivityID) i);
  }
  return user_activity_none;
}
