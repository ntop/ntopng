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

#ifdef __APPLE__
#include <uuid/uuid.h>
#endif

/* Lua.cpp */
extern int ntop_lua_cli_print(lua_State* vm);
extern int ntop_lua_check(lua_State* vm, const char* func, int pos, int expected_type);

static bool help_printed = false;

/* **************************************************** */

/* Method used for collateral activities */
NetworkInterface::NetworkInterface() {
  init();
}

/* **************************************************** */

NetworkInterface::NetworkInterface(const char *name,
				   const char *custom_interface_type) {
  NDPI_PROTOCOL_BITMASK all;
  char _ifname[MAX_INTERFACE_NAME_LEN], buf[MAX_INTERFACE_NAME_LEN];
  /* We need to do it as isView() is not yet initialized */
  char pcap_error_buffer[PCAP_ERRBUF_SIZE];

  init();
  customIftype = custom_interface_type, flowHashingMode = flowhashing_none, tsExporter = NULL;

#ifdef WIN32
  if(name == NULL) name = "1"; /* First available interface */
#endif

  scalingFactor = 1;
  if(strcmp(name, "-") == 0) name = "stdin";
  if(strcmp(name, "-") == 0) name = "stdin";

  if(ntop->getRedis())
    id = Utils::ifname2id(name);
  else
    id = -1;

  purge_idle_flows_hosts = true;

  if(name == NULL) {
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

  db = NULL;
  ifname = strdup(name);
  if(custom_interface_type) {
    ifDescription = strdup(name);
  } else
    ifDescription = strdup(Utils::getInterfaceDescription(ifname, buf, sizeof(buf)));

#ifdef NTOPNG_PRO
  aggregated_flows_hash = NULL;
#endif

    if(strchr(name, ':')
       || strchr(name, '@')
       || (!strcmp(name, "dummy"))
       || strchr(name, '/') /* file path */
       || strstr(name, ".pcap") /* pcap */
       || (strncmp(name, "lo", 2) == 0)
#if !defined(__APPLE__) && !defined(WIN32)
       || (Utils::readIPv4((char*)name) == 0)
#endif
       )
      ; /* Don't setup MDNS on ZC or RSS interfaces */
    else {
    ipv4_network = ipv4_network_mask = 0;
    if(pcap_lookupnet(ifname, &ipv4_network, &ipv4_network_mask, pcap_error_buffer) == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to read IPv4 address of %s: %s",
				   ifname, pcap_error_buffer);
    } else {
      try {
        discovery = new NetworkDiscovery(this);
      } catch (...) {
	discovery = NULL;
      }

      if (discovery) {
	try {
	  mdns = new MDNS(this);
	}
	catch (...) {
	  mdns = NULL;
	}
      }
    }
  }

  if(id >= 0) {
    ndpi_port_range d_port[MAX_DEFAULT_PORTS];
    u_int16_t no_master[2] = { NDPI_PROTOCOL_NO_MASTER_PROTO, NDPI_PROTOCOL_NO_MASTER_PROTO };

    num_hashes = max_val(4096, ntop->getPrefs()->get_max_num_flows()/4);
    flows_hash = new FlowHash(this, num_hashes, ntop->getPrefs()->get_max_num_flows());

    num_hashes = max_val(4096, ntop->getPrefs()->get_max_num_hosts() / 4);
    hosts_hash = new HostHash(this, num_hashes, ntop->getPrefs()->get_max_num_hosts());
    /* The number of ASes cannot be greater than the number of hosts */
    ases_hash = new AutonomousSystemHash(this, num_hashes,
					 ntop->getPrefs()->get_max_num_hosts());

    countries_hash = new CountriesHash(this, num_hashes,
					 ntop->getPrefs()->get_max_num_hosts());

    vlans_hash = new VlanHash(this, num_hashes,
			      max_val(ntop->getPrefs()->get_max_num_hosts() / 2,
				      (u_int16_t)-1));

    macs_hash = new MacHash(this, num_hashes, ntop->getPrefs()->get_max_num_hosts());

    if(ntop->getPrefs()->is_arp_matrix_generation_enabled())
      arp_hash_matrix = new (std::nothrow) ArpStatsHashMatrix(this, num_hashes,
							      (ntop->getPrefs()->get_max_num_hosts() ^ 2) / 2);
    else
      arp_hash_matrix = NULL;

    // init global detection structure
    ndpi_struct = ndpi_init_detection_module();
    if(ndpi_struct == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to initialize nDPI");
      exit(-1);
    }

    if(ntop->getCustomnDPIProtos() != NULL)
      ndpi_load_protocols_file(ndpi_struct, ntop->getCustomnDPIProtos());

    ndpi_set_detection_preferences(ndpi_struct, ndpi_pref_http_dont_dissect_response, 1);
    ndpi_set_detection_preferences(ndpi_struct, ndpi_pref_dns_dont_dissect_response,  1);
    ndpi_set_detection_preferences(ndpi_struct, ndpi_pref_enable_category_substring_match, 1);

    memset(d_port, 0, sizeof(d_port));
    ndpi_set_proto_defaults(ndpi_struct, NDPI_PROTOCOL_UNRATED, NTOPNG_NDPI_OS_PROTO_ID,
			    0, no_master, no_master, (char*)"Operating System",
			    NDPI_PROTOCOL_CATEGORY_SYSTEM_OS, d_port, d_port);

    // enable all protocols
    NDPI_BITMASK_SET_ALL(all);
    ndpi_set_protocol_detection_bitmask2(ndpi_struct, &all);

    last_pkt_rcvd = last_pkt_rcvd_remote = 0, pollLoopCreated = false,
      bridge_interface = false;
    next_idle_flow_purge = next_idle_host_purge = 0;
    cpu_affinity = -1 /* no affinity */,
      has_vlan_packets = has_ebpf_events = has_mac_addresses = false;
    arp_requests = arp_replies = 0;

    running = false,
      inline_interface = false, db = NULL;

    checkIdle();
    ifSpeed = Utils::getMaxIfSpeed(name);
    ifMTU = Utils::getIfMTU(name), mtuWarningShown = false;
  } else /* id < 0 */ {
    flows_hash = NULL, hosts_hash = NULL;
    macs_hash = NULL, ases_hash = NULL, vlans_hash = NULL;
    countries_hash = NULL, arp_hash_matrix = NULL;
    ndpi_struct = NULL, db = NULL, ifSpeed = 0;
  }

  networkStats = NULL;

#ifdef NTOPNG_PRO
  policer = NULL; /* possibly instantiated by subclass PacketBridge */
#ifndef HAVE_NEDGE
  flow_profiles = ntop->getPro()->has_valid_license() ? new FlowProfiles(id) : NULL;
  if(flow_profiles) flow_profiles->loadProfiles();
  shadow_flow_profiles = NULL;
#endif

  /* Lazy, instantiated on demand */
  custom_app_stats = NULL;
  flow_interfaces_stats = NULL;
#endif

  loadScalingFactorPrefs();
  loadPacketsDropsAlertPrefs();
  reloadDhcpRanges();

  statsManager = NULL, alertsManager = NULL;

  host_pools = new HostPools(this);
  bcast_domains = new BroadcastDomains(this);

#ifdef __linux__
  /*
    A bit aggressive but as people usually
    ignore warnings let's be proactive
  */
  if(ifname
     && (!isView())
     && (!strstr(ifname, ":"))
     && (!strstr(ifname, ".pcap"))
     && strcmp(ifname, "dummy")
     && strcmp(ifname, "any")
     && strcmp(ifname, "virbr")
     && strcmp(ifname, "wlan")
     && strncmp(ifname, "lo", 2)
     ) {
    char buf[64], ifaces[128], *tmp, *iface;

    snprintf(ifaces, sizeof(ifaces), "%s", ifname);
    iface = strtok_r(ifaces, ",", &tmp);

    while(iface != NULL) {
      snprintf(buf, sizeof(buf), "ethtool -K %s gro off gso off tso off 2>/dev/null", iface);
      system(buf);
      ntop->getTrace()->traceEvent(TRACE_INFO, "Executing %s", buf);
      iface = strtok_r(NULL, ",", &tmp);
    }
  }
#endif

  is_loopback = (strncmp(ifname, "lo", 2) == 0) ? true : false;

  reloadHideFromTop(false);
  updateTrafficMirrored();
}

/* **************************************************** */

void NetworkInterface::init() {
  ifname = NULL, flows_hash = NULL, hosts_hash = NULL,
    bridge_lan_interface_id = bridge_wan_interface_id = 0, ndpi_struct = NULL,
    inline_interface = false,
    has_vlan_packets = false, has_ebpf_events = false,
    last_pkt_rcvd = last_pkt_rcvd_remote = 0,
    next_idle_flow_purge = next_idle_host_purge = 0,
    running = false, customIftype = NULL, is_dynamic_interface = false,
    is_loopback = is_traffic_mirrored = false;
  numVirtualInterfaces = 0, flowHashing = NULL,
    pcap_datalink_type = 0, mtuWarningShown = false,
    purge_idle_flows_hosts = true, id = (u_int8_t)-1,
    last_remote_pps = 0, last_remote_bps = 0,
    has_vlan_packets = false,
    cpu_affinity = -1 /* no affinity */,
    inline_interface = false, running = false, interfaceStats = NULL,
    has_too_many_hosts = has_too_many_flows = too_many_drops = false,
    slow_stats_update = false,
    numL2Devices = 0, numHosts = 0, numLocalHosts = 0,
    checkpointPktCount = checkpointBytesCount = checkpointPktDropCount = 0,
    pollLoopCreated = false, bridge_interface = false,
    mdns = NULL, discovery = NULL, ifDescription = NULL,
    flowHashingMode = flowhashing_none;
  macs_hash = NULL, ases_hash = NULL, countries_hash = NULL, vlans_hash = NULL, 
    arp_hash_matrix = NULL;

  numSubInterfaces = 0;
  memset(subInterfaces, 0, sizeof(subInterfaces));
  reload_custom_categories = reload_hosts_blacklist = false;
  reload_hosts_bcast_domain = false;
  hosts_bcast_domain_last_update = 0;
    
  ip_addresses = "", networkStats = NULL,
    pcap_datalink_type = 0, cpu_affinity = -1;
  hide_from_top = hide_from_top_shadow = NULL;

  gettimeofday(&last_frequent_reset, NULL);
  frequentMacs = new FrequentTrafficItems(5);
  frequentProtocols = new FrequentTrafficItems(5);
  num_live_captures = 0;
  memset(live_captures, 0, sizeof(live_captures));

  db = NULL;
#ifdef NTOPNG_PRO
  custom_app_stats = NULL;
  aggregated_flows_hash = NULL, flow_interfaces_stats = NULL;
  policer = NULL;
#endif
  statsManager = NULL, alertsManager = NULL, ifSpeed = 0;
  host_pools = NULL;
  bcast_domains = NULL;
  checkIdle();
  ifMTU = CONST_DEFAULT_MAX_PACKET_SIZE, mtuWarningShown = false;
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  flow_profiles = shadow_flow_profiles = NULL;
#endif

#endif

  dhcp_ranges = dhcp_ranges_shadow = NULL;

  ts_ring = NULL;

  if(ntop->getPrefs()) {
    if(TimeseriesRing::isRingEnabled(ntop->getPrefs()))
      ts_ring = new TimeseriesRing(this);
  }

#ifdef HAVE_EBPF
  if(bridge_interface
     || is_dynamic_interface
     || is_traffic_mirrored
     || isView())
    ;
  else {
    ebpfEvents = (eBPFevent**)calloc(sizeof(eBPFevent*), EBPF_QUEUE_LEN);
    next_insert_idx = next_remove_idx = 0;
  }
#endif

  PROFILING_INIT();
}

/* **************************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::initL7Policer() {
  /* Instantiate the policer */
  policer = new L7Policer(this);
}

/* **************************************** */

void NetworkInterface::aggregatePartialFlow(Flow *flow) {
  if(flow && aggregated_flows_hash) {
    AggregatedFlow *aggregatedFlow = aggregated_flows_hash->find(flow);

    if(aggregatedFlow == NULL) {
      if(!aggregated_flows_hash->hasEmptyRoom()) {
	/* There is no more room in the hash table */
      } else if((!ntop->getPrefs()->is_aggregated_flows_export_limit_enabled())
		|| (aggregated_flows_hash->getNumEntries() < ntop->getPrefs()->get_max_num_aggregated_flows_per_export())) {
#ifdef AGGREGATED_FLOW_DEBUG
	char buf[256];
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "AggregatedFlow not found [%s]. Creating it.",
				     flow->print(buf, sizeof(buf)));
#endif

	try {
	  aggregatedFlow = new AggregatedFlow(this, flow);

	  if(aggregated_flows_hash->add(aggregatedFlow) == false) {
	    /* Too many flows, should never happen */
	    delete aggregatedFlow;
	    return;
	  } else {
#ifdef AGGREGATED_FLOW_DEBUG
	    char buf[256];

	    ntop->getTrace()->traceEvent(TRACE_NORMAL,
					 "New AggregatedFlow successfully created and added "
					 "to the hash table [%s]",
					 aggregatedFlow->print(buf, sizeof(buf)));
#endif
	  }
	} catch(std::bad_alloc& ba) {
	  return; /* Not enough memory */
	}
      } else {
	/* The maximum number of aggregates has been reached. Add here the logic to handle
	   this case. For example, make the maximum number adaptive depending on the number of hosts,
	   or keep only the top-X aggregates. */

#ifdef AGGREGATED_FLOW_DEBUG
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "Maximum reached [maximum: %d]", ntop->getPrefs()->get_max_num_aggregated_flows_per_export());
#endif
      }
    }

    if(aggregatedFlow) {
      aggregatedFlow->sumFlowStats(flow,
				   /* nextFlowAggregation will be decremented by one after the current periodic
				      flows walk (this method is called in the periodic flows walk)

				      Therefore, we can check nextFlowAggregation minus one to determine whether
				      a cleanup of the aggregated flows hash table is going to be performed
				      after this walk on the (normal, non-aggregated) flows table.
				   */
				   ((getIfType() == interface_type_DUMMY) || (nextFlowAggregation - 1 == 0)));

#ifdef AGGREGATED_FLOW_DEBUG
      char buf[256];
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Stats updated for AggregatedFlow [%s]",
				   aggregatedFlow->print(buf, sizeof(buf)));

      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Aggregated Flows hash table [num items: %i]",
				   aggregated_flows_hash->getCurrentSize());
#endif
    }
  }
}

#endif

/* **************************************************** */

void NetworkInterface::checkAggregationMode() {
  if(!customIftype) {
    char rsp[32];

    if((!ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_IFACE_FLOW_COLLECTION, rsp, sizeof(rsp)))
       && (rsp[0] != '\0')) {
      if(getIfType() == interface_type_ZMQ) { /* ZMQ interface */
	if(!strcmp(rsp, DISAGGREGATION_PROBE_IP)) flowHashingMode = flowhashing_probe_ip;
	else if(!strcmp(rsp, DISAGGREGATION_IFACE_ID))         flowHashingMode = flowhashing_iface_idx;
	else if(!strcmp(rsp, DISAGGREGATION_INGRESS_IFACE_ID)) flowHashingMode = flowhashing_ingress_iface_idx;
	else if(!strcmp(rsp, DISAGGREGATION_INGRESS_VRF_ID))   flowHashingMode = flowhashing_vrfid;
	else if(!strcmp(rsp, DISAGGREGATION_VLAN))             flowHashingMode = flowhashing_vlan;
	else if(strcmp(rsp,  DISAGGREGATION_NONE))
	  ntop->getTrace()->traceEvent(TRACE_ERROR,
				       "Unknown aggregation value for interface %s [rsp: %s]",
				       get_type(), rsp);
      } else { /* non-ZMQ interface */
	if(!strcmp(rsp, DISAGGREGATION_VLAN)) flowHashingMode = flowhashing_vlan;
	else if(strcmp(rsp,  DISAGGREGATION_NONE))
	  ntop->getTrace()->traceEvent(TRACE_ERROR,
				       "Unknown aggregation value for interface %s [rsp: %s]",
				       get_type(), rsp);

      }
    }

    /* Populate ignored interfaces */
    rsp[0] = '\0';
    if((!ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_IGNORED_INTERFACES, rsp, sizeof(rsp)))
       && (rsp[0] != '\0')) {
      char *token;
      char *rest = rsp;

      while((token = strtok_r(rest, ",", &rest)))
	flowHashingIgnoredInterfaces.insert(atoi(token));
    }
  }
}

/* **************************************************** */

void NetworkInterface::loadScalingFactorPrefs() {
  if(ntop->getRedis() != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), CONST_IFACE_SCALING_FACTOR_PREFS, id);

    if((ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0'))
      scalingFactor = atol(rsp);

    if(scalingFactor == 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "INTERNAL ERROR: scalingFactor can't be 0!");
      scalingFactor = 1;
    }
  }
}

/* **************************************************** */

void NetworkInterface::loadPacketsDropsAlertPrefs() {
  packet_drops_alert_perc = CONST_DEFAULT_PACKETS_DROP_PERCENTAGE_ALERT;

  if(ntop->getRedis() != NULL) {
    char rkey[128], rsp[8];

    snprintf(rkey, sizeof(rkey), CONST_IFACE_PACKET_DROPS_ALERT_PREFS, id);

    if((ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0'))
      packet_drops_alert_perc = atoi(rsp);
  }
}

/* **************************************************** */

void NetworkInterface::updateTrafficMirrored() {
  char key[CONST_MAX_LEN_REDIS_KEY], rsp[2] = { 0 };
  bool is_mirrored = CONST_DEFAULT_MIRRORED_TRAFFIC;

  if(!ntop->getRedis()) return;

  snprintf(key, sizeof(key), CONST_MIRRORED_TRAFFIC_PREFS, get_id());
  if((ntop->getRedis()->get(key, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0')) {
    if(rsp[0] == '1')
      is_mirrored = true;
    else if(rsp[0] == '0')
      is_mirrored = false;
  }

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Updating mirrored traffic [ifid: %i][rsp: %s][actual_value: %d]", get_id(), rsp, is_mirrored ? 1 : 0);

  is_traffic_mirrored = is_mirrored;
}

/* **************************************************** */

bool NetworkInterface::checkIdle() {
  is_idle = false;

  if(ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s_not_idle", ifname);
    if((ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0')) {
      int val = atoi(rsp);

      if(val == 0) is_idle = true;
    }
  }

  return(is_idle);
}

/* **************************************************** */

void NetworkInterface::deleteDataStructures() {
  if(flows_hash)            { delete(flows_hash); flows_hash = NULL; }
  if(hosts_hash)            { delete(hosts_hash); hosts_hash = NULL; }
  if(ases_hash)             { delete(ases_hash);  ases_hash = NULL;  }
  if(countries_hash)        { delete(countries_hash);  countries_hash = NULL;  }
  if(vlans_hash)            { delete(vlans_hash); vlans_hash = NULL; }
  if(macs_hash)             { delete(macs_hash);  macs_hash = NULL;  }
  if(arp_hash_matrix)       { delete(arp_hash_matrix); arp_hash_matrix = NULL; }
  
#ifdef NTOPNG_PRO
  if(aggregated_flows_hash) {
    aggregated_flows_hash->cleanup();
    delete(aggregated_flows_hash);
    aggregated_flows_hash = NULL;
  }
#endif

#ifdef HAVE_EBPF
  if(ebpfEvents) {
    for(u_int16_t i=0; i<EBPF_QUEUE_LEN; i++)
      if(ebpfEvents[i])
	free(ebpfEvents[i]);

    free(ebpfEvents);
  }
#endif
}

/* **************************************************** */

NetworkInterface::~NetworkInterface() {
#ifdef PROFILING
  u_int64_t n = ethStats.getNumIngressPackets();
  if (n > 0) {
    for (u_int i = 0; i < PROFILING_NUM_SECTIONS; i++) {
      if (PROFILING_SECTION_LABEL(i) != NULL)
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "[PROFILING] Section #%d '%s': AVG %llu ticks",
          i, PROFILING_SECTION_LABEL(i), PROFILING_SECTION_AVG(i, n));
    }
  }
#endif

  if(getNumPackets() > 0) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Flushing host contacts for interface %s",
				 get_name());
    cleanup();
  }

  deleteDataStructures();

  if(db) {
    /* note: keep this after deleteDataStructures to flush aggregated flows */
    db->shutdown();
    delete db;
  }
  if(host_pools)     delete host_pools;     /* note: this requires ndpi_struct */
  if(bcast_domains)  delete bcast_domains;
  if(ifDescription)  free(ifDescription);
  if(discovery)      delete discovery;
  if(statsManager)   delete statsManager;
  if(alertsManager)  delete alertsManager;
  if(networkStats)   delete []networkStats;
  if(interfaceStats) delete interfaceStats;

  if(flowHashing) {
    FlowHashing *current, *tmp;

    HASH_ITER(hh, flowHashing, current, tmp) {
      /* Interfaces are deleted by the main termination function */
      HASH_DEL(flowHashing, current);
      free(current);
    }

    flowHashing = NULL;
  }

  if(ndpi_struct) {
    ndpi_exit_detection_module(ndpi_struct);
    ndpi_struct = NULL;
  }

  delete frequentProtocols;
  delete frequentMacs;

#ifdef NTOPNG_PRO
  if(policer)               delete(policer);
#ifndef HAVE_NEDGE
  if(flow_profiles)         delete(flow_profiles);
  if(shadow_flow_profiles)  delete(shadow_flow_profiles);
#endif
  if(custom_app_stats)      delete custom_app_stats;
  if(flow_interfaces_stats) delete flow_interfaces_stats;
#endif
  if(hide_from_top)         delete(hide_from_top);
  if(hide_from_top_shadow)  delete(hide_from_top_shadow);
  if(tsExporter)            delete tsExporter;
  if(ts_ring)               delete ts_ring;
  if(mdns)                  delete mdns; /* Leave it at the end so the mdns resolved has time to initialize */
  if(dhcp_ranges)           delete[] dhcp_ranges;
  if(dhcp_ranges_shadow)    delete[] dhcp_ranges_shadow;

  if(ifname)                free(ifname);
}

/* **************************************************** */

int NetworkInterface::dumpFlow(time_t when, Flow *f) {
  int rc = -1;
  
#ifndef HAVE_NEDGE
  char *json;
  bool es_flow = ntop->getPrefs()->do_dump_flows_on_es() ||
    ntop->getPrefs()->do_dump_flows_on_ls();

  if(!db)
    return(-1);

  json = f->serialize(es_flow);

  if(json) {
    rc = db->dumpFlow(when, f, json);
    free(json);
  } else
    rc = -1;
#endif

  return(rc);
}

/* **************************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::dumpAggregatedFlow(time_t when, AggregatedFlow *f, bool is_top_aggregated_flow, bool is_top_cli, bool is_top_srv) {
  if(db
     && f && (f->get_packets() > 0)
     && ntop->getPrefs()->is_enterprise_edition()) {
#ifdef DUMP_AGGREGATED_FLOW_DEBUG
    char buf[256];
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Going to dump AggregatedFlow to database [%s][is_top: %u]",
				 f->print(buf, sizeof(buf)), is_top_aggregated_flow ? 1 : 0);
#endif

    if(!ntop->getPrefs()->is_tiny_flows_export_enabled() && f->isTiny()) {
#ifdef DUMP_AGGREGATED_FLOW_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Skipping tiny aggregated flow [flow: %s]",
				   f->print(buf, sizeof(buf)));
#endif
    } else {
      db->dumpAggregatedFlow(when, f, is_top_aggregated_flow, is_top_cli, is_top_srv);
    }
  }
}

/* **************************************************** */

void NetworkInterface::flushFlowDump() {
  if(db) db->flush();
}

#endif

/* **************************************************** */

static bool local_hosts_2_redis_walker(GenericHashEntry *h, void *user_data, bool *matched) {
  Host *host = (Host*)h;

  if(host && (host->isLocalHost() || host->isSystemHost())) {
    host->serialize2redis();
    *matched = true;
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

int NetworkInterface::dumpLocalHosts2redis(bool disable_purge) {
  int rc;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(disable_purge) disablePurge(false /* on hosts */);
  rc = walker(&begin_slot, walk_all,  walker_hosts,
	      local_hosts_2_redis_walker, NULL) ? 0 : -1;
  if(disable_purge) enablePurge(false /* on hosts */);

#ifdef NTOPNG_PRO
  if(getHostPools()) getHostPools()->dumpToRedis();
#endif

  return(rc);
}

/* **************************************************** */

u_int32_t NetworkInterface::getHostsHashSize() {
  return(hosts_hash->getNumEntries());
}

/* **************************************************** */

u_int32_t NetworkInterface::getASesHashSize() {
  return(ases_hash->getNumEntries());
}

/* **************************************************** */

u_int32_t NetworkInterface::getCountriesHashSize() {
  return(countries_hash->getNumEntries());
}

/* **************************************************** */

u_int32_t NetworkInterface::getVLANsHashSize() {
  return(vlans_hash->getNumEntries());
}

/* **************************************************** */

u_int32_t NetworkInterface::getFlowsHashSize() {
  return(flows_hash->getNumEntries());
}

/* **************************************************** */

u_int32_t NetworkInterface::getMacsHashSize() {
  return(macs_hash->getNumEntries());
}

/* **************************************************** */

u_int32_t NetworkInterface::getArpHashMatrixSize() {
  return(arp_hash_matrix ? arp_hash_matrix->getNumEntries() : 0);
}

/* **************************************************** */

bool NetworkInterface::walker(u_int32_t *begin_slot,
			      bool walk_all,
			      WalkerType wtype,
			      bool (*walker)(GenericHashEntry *h, void *user_data, bool *matched),
			      void *user_data) {
  bool ret = false;

  switch(wtype) {
  case walker_hosts:
    ret = hosts_hash->walk(begin_slot, walk_all, walker, user_data);
    break;

  case walker_flows:
    ret = flows_hash->walk(begin_slot, walk_all, walker, user_data);
    break;

  case walker_macs:
    ret = macs_hash->walk(begin_slot, walk_all, walker, user_data);
    break;

  case walker_ases:
    ret = ases_hash->walk(begin_slot, walk_all, walker, user_data);
    break;

  case walker_countries:
    ret = countries_hash->walk(begin_slot, walk_all, walker, user_data);
    break;

  case walker_vlans:
    ret = vlans_hash->walk(begin_slot, walk_all, walker, user_data);
    break;
  }

  return(ret);
}

/* **************************************************** */

Flow* NetworkInterface::getFlow(Mac *srcMac, Mac *dstMac,
				u_int16_t vlan_id,  u_int32_t deviceIP,
				u_int16_t inIndex,  u_int16_t outIndex,
				const ICMPinfo * const icmp_info,
  				IpAddress *src_ip,  IpAddress *dst_ip,
  				u_int16_t src_port, u_int16_t dst_port,
				u_int8_t l4_proto,
				bool *src2dst_direction,
				time_t first_seen, time_t last_seen,
				u_int32_t rawsize,
				bool *new_flow, bool create_if_missing) {
  Flow *ret;
  Mac *primary_mac;
  Host *srcHost = NULL, *dstHost = NULL;

  if(vlan_id != 0)
    setSeenVlanTaggedPackets();

  if((srcMac && Utils::macHash(srcMac->get_mac()) != 0)
     || (dstMac && Utils::macHash(dstMac->get_mac()) != 0))
    setSeenMacAddresses();

  PROFILING_SECTION_ENTER("NetworkInterface::getFlow: flows_hash->find", 5);
  ret = flows_hash->find(src_ip, dst_ip, src_port, dst_port,
			 vlan_id, l4_proto, icmp_info, src2dst_direction);
  PROFILING_SECTION_EXIT(5);

  if(ret == NULL) {
    if(!create_if_missing)
      return(NULL);

    *new_flow = true;

    try {
      PROFILING_SECTION_ENTER("NetworkInterface::getFlow: new Flow", 6);
      ret = new Flow(this, vlan_id, l4_proto,
		     srcMac, src_ip, src_port,
		     dstMac, dst_ip, dst_port,
		     icmp_info,
		     first_seen, last_seen);
      PROFILING_SECTION_EXIT(6);
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }

      has_too_many_flows = true;
      return(NULL);
    }

    if(flows_hash->add(ret)) {
      *src2dst_direction = true;
    } else {
      delete ret;
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many flows");
      has_too_many_flows = true;
      return(NULL);
    }
  } else {
    *new_flow = false;
    has_too_many_flows = false;
  }

  if(srcMac) {
    if((srcHost = (*src2dst_direction) ? ret->get_cli_host() : ret->get_srv_host())) {
      if((!srcMac->isSpecialMac()) && (primary_mac = srcHost->getMac()) && primary_mac != srcMac) {
#ifdef MAC_DEBUG
	char buf[32], bufm1[32], bufm2[32];
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "Detected mac address [%s] [host: %s][primary mac: %s]",
				     Utils::formatMac(srcMac->get_mac(), bufm1, sizeof(bufm1)),
				     srcHost->get_ip()->print(buf, sizeof(buf)),
				     Utils::formatMac(primary_mac->get_mac(), bufm2, sizeof(bufm2)));
#endif

	if(srcHost->getMac()->isSpecialMac()) {
	  if(getIfType() == interface_type_NETFILTER) {
	    /*
	      This is the first *reply* packet of a flow so we need to increment it
	      with the initial packet that was missed as NetFilter did not report
	      the (destination) MAC. From now on, all flow peers are known
	    */

	    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
	    if(ret->get_packets_cli2srv() == 1 /* first packet */)
	      srcMac->incRcvdStats(getTimeLastPktRcvd(), 1, ret->get_bytes_cli2srv() /* size of the last packet */);
#endif
	  }
	}

	srcHost->set_mac(srcMac);
	srcHost->updateHostPool(true /* Inline */);
      }
    }
  }

  if(dstMac) {
    if((dstHost = (*src2dst_direction) ? ret->get_srv_host() : ret->get_cli_host())) {
      if((!dstMac->isSpecialMac()) && (primary_mac = dstHost->getMac()) && primary_mac != dstMac) {
#ifdef MAC_DEBUG
	char buf[32], bufm1[32], bufm2[32];
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "Detected mac address [%s] [host: %s][primary mac: %s]",
				     Utils::formatMac(dstMac->get_mac(), bufm1, sizeof(bufm1)),
				     dstHost->get_ip()->print(buf, sizeof(buf)),
				     Utils::formatMac(primary_mac->get_mac(), bufm2, sizeof(bufm2)));
#endif
	dstHost->set_mac(dstMac);
	dstHost->updateHostPool(true /* Inline */);
      }
    }
  }

  return(ret);
}

/* **************************************************** */

NetworkInterface* NetworkInterface::getSubInterface(u_int32_t criteria, bool parser_interface) {
#ifndef HAVE_NEDGE
  FlowHashing *h = NULL;

  HASH_FIND_INT(flowHashing, &criteria, h);

  if(h == NULL) {
    /* Interface not found */

    if(numVirtualInterfaces < MAX_NUM_VIRTUAL_INTERFACES) {
      if((h = (FlowHashing*)malloc(sizeof(FlowHashing))) != NULL) {
	char buf[64], buf1[48];
	const char *vIface_type;

	h->criteria = criteria;

	switch(flowHashingMode) {
	case flowhashing_vlan:
	  vIface_type = CONST_INTERFACE_TYPE_VLAN;
	  snprintf(buf, sizeof(buf), "%s [VLAN Id: %u]", ifname, criteria);
	  // snprintf(buf, sizeof(buf), "VLAN Id %u", criteria);
	  break;

	case flowhashing_probe_ip:
	  vIface_type = CONST_INTERFACE_TYPE_FLOW;
	  snprintf(buf, sizeof(buf), "%s [Probe IP: %s]", ifname, Utils::intoaV4(criteria, buf1, sizeof(buf1)));
	  // snprintf(buf, sizeof(buf), "Probe IP %s", Utils::intoaV4(criteria, buf1, sizeof(buf1)));
	  break;

	case flowhashing_iface_idx:
	case flowhashing_ingress_iface_idx:
	  vIface_type = CONST_INTERFACE_TYPE_FLOW;
	  snprintf(buf, sizeof(buf), "%s [If Idx: %u]", ifname, criteria);
	  // snprintf(buf, sizeof(buf), "If Idx %u", criteria);
	  break;

	case flowhashing_vrfid:
	  vIface_type = CONST_INTERFACE_TYPE_FLOW;
	  snprintf(buf, sizeof(buf), "%s [VRF Id: %u]", ifname, criteria);
	  // snprintf(buf, sizeof(buf), "VRF Id %u", criteria);
	  break;

	default:
	  free(h);
	  return(NULL);
	  break;
	}

	if(parser_interface)
	  h->iface = new ParserInterface(buf, vIface_type);
	else
	  h->iface = new NetworkInterface(buf, vIface_type);

	if(h->iface) {
	  if (ntop->registerInterface(h->iface))
            ntop->initInterface(h->iface);
	  h->iface->allocateNetworkStats();
	  h->iface->setDynamicInterface();
	  HASH_ADD_INT(flowHashing, criteria, h);
	  numVirtualInterfaces++;
	  ntop->getRedis()->set(CONST_STR_RELOAD_LISTS, (const char * const)"1");
	}
      } else
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    }
  }

  if(h) return(h->iface);
#endif

  return(NULL);
}

/* **************************************************** */

void NetworkInterface::processFlow(ZMQ_Flow *zflow) {
  bool src2dst_direction, new_flow;
  Flow *flow;
  ndpi_protocol p;
  time_t now = time(NULL);
  Mac *srcMac = NULL, *dstMac = NULL;
  IpAddress srcIP, dstIP;

  memset(&p, 0, sizeof(p));

  if(last_pkt_rcvd_remote > 0) {
    int drift = now - last_pkt_rcvd_remote;

    if(drift >= 0)
      zflow->core.last_switched += drift, zflow->core.first_switched += drift;
    else {
      u_int32_t d = (u_int32_t)-drift;

      if(d < zflow->core.last_switched)  zflow->core.last_switched  += drift;
      if(d < zflow->core.first_switched) zflow->core.first_switched += drift;
    }

#ifdef DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "[first=%u][last=%u][duration: %u][drift: %d][now: %u][remote: %u]",
				 zflow->core.first_switched,  zflow->core.last_switched,
				 zflow->core.last_switched-zflow->core.first_switched, drift,
				 now, last_pkt_rcvd_remote);
#endif
  } else {
    /* Old nProbe */

    if((time_t)zflow->core.last_switched > (time_t)last_pkt_rcvd_remote)
      last_pkt_rcvd_remote = zflow->core.last_switched;

#ifdef DEBUG
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[first=%u][last=%u][duration: %u]",
				 zflow->core.first_switched,  zflow->core.last_switched,
				 zflow->core.last_switched- zflow->core.first_switched);
#endif
  }

  if((!isDynamicInterface()) && (flowHashingMode != flowhashing_none)) {
    NetworkInterface *vIface = NULL, *vIfaceEgress = NULL;

    switch(flowHashingMode) {
    case flowhashing_probe_ip:
      vIface = getSubInterface((u_int32_t)zflow->core.deviceIP, true);
      break;

    case flowhashing_iface_idx:
      if(flowHashingIgnoredInterfaces.find((u_int32_t)zflow->core.outIndex) == flowHashingIgnoredInterfaces.end())
	 vIfaceEgress = getSubInterface((u_int32_t)zflow->core.outIndex, true);
      /* No break HERE, want to get two interfaces, one for the ingress
         and one for the egress. */

    case flowhashing_ingress_iface_idx:
      if(flowHashingIgnoredInterfaces.find((u_int32_t)zflow->core.inIndex) == flowHashingIgnoredInterfaces.end())
	vIface = getSubInterface((u_int32_t)zflow->core.inIndex, true);
      break;

    case flowhashing_vrfid:
      vIface = getSubInterface((u_int32_t)zflow->core.vrfId, true);
      break;

    case flowhashing_vlan:
      vIface = getSubInterface((u_int32_t)zflow->core.vlan_id, true);
      break;

    default:
      break;
    }

    if(vIface)       vIface->processFlow(zflow);
    if(vIfaceEgress) vIfaceEgress->processFlow(zflow);

    return;
  }

  if(!ntop->getPrefs()->do_ignore_macs()) {
    srcMac = getMac((u_int8_t*)zflow->core.src_mac, true);
    dstMac = getMac((u_int8_t*)zflow->core.dst_mac, true);
  }

  srcIP.set(&zflow->core.src_ip), dstIP.set(&zflow->core.dst_ip);

  /* Updating Flow */
  flow = getFlow(srcMac, dstMac,
		 zflow->core.vlan_id,
		 zflow->core.deviceIP,
		 zflow->core.inIndex, zflow->core.outIndex,
		 NULL /* ICMPinfo */,
		 &srcIP, &dstIP,
		 zflow->core.src_port, zflow->core.dst_port,
		 zflow->core.l4_proto, &src2dst_direction,
		 zflow->core.first_switched,
		 zflow->core.last_switched,
		 0, &new_flow, true);

  if(flow == NULL)
    return;

  if(zflow->core.absolute_packet_octet_counters) {
    /* Ajdust bytes and packets counters if the zflow update contains absolute values.

       As flows may arrive out of sequence, special care is needed to avoid counting absolute values multiple times.

       http://www.cisco.com/c/en/us/td/docs/security/asa/special/netflow/guide/asa_netflow.html#pgfId-1331296
       Different events in the life of a flow may be issued in separate NetFlow packets and may arrive out-of-order
       at the collector. For example, the packet containing a flow teardown event may reach the collector before the packet
       containing a flow creation event. As a result, it is important that collector applications use the Event Time field
       to correlate events.
    */

    u_int64_t in_cur_pkts = src2dst_direction ? flow->get_packets_cli2srv() : flow->get_packets_srv2cli(),
      in_cur_bytes = src2dst_direction ? flow->get_bytes_cli2srv() : flow->get_bytes_srv2cli();
    u_int64_t out_cur_pkts = src2dst_direction ? flow->get_packets_srv2cli() : flow->get_packets_cli2srv(),
      out_cur_bytes = src2dst_direction ? flow->get_bytes_srv2cli() : flow->get_bytes_cli2srv();
    bool out_of_sequence = false;

    if(zflow->core.in_pkts) {
      if(zflow->core.in_pkts >= in_cur_pkts) zflow->core.in_pkts -= in_cur_pkts;
      else zflow->core.in_pkts = 0, out_of_sequence = true;
    }

    if(zflow->core.in_bytes) {
      if(zflow->core.in_bytes >= in_cur_bytes) zflow->core.in_bytes -= in_cur_bytes;
      else zflow->core.in_bytes = 0, out_of_sequence = true;
    }

    if(zflow->core.out_pkts) {
      if(zflow->core.out_pkts >= out_cur_pkts) zflow->core.out_pkts -= out_cur_pkts;
      else zflow->core.out_pkts = 0, out_of_sequence = true;
    }

    if(zflow->core.out_bytes) {
      if(zflow->core.out_bytes >= out_cur_bytes) zflow->core.out_bytes -= out_cur_bytes;
      else zflow->core.out_bytes = 0, out_of_sequence = true;
    }

    if(out_of_sequence) {
#ifdef ABSOLUTE_COUNTERS_DEBUG
      char flowbuf[265];
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "A flow received an update with absolute values smaller than the current values. "
				   "[in_bytes: %u][in_cur_bytes: %u][out_bytes: %u][out_cur_bytes: %u]"
				   "[in_pkts: %u][in_cur_pkts: %u][out_pkts: %u][out_cur_pkts: %u]\n"
				   "%s",
				   zflow->core.in_bytes, in_cur_bytes, zflow->core.out_bytes, out_cur_bytes,
				   zflow->core.in_pkts, in_cur_pkts, zflow->core.out_pkts, out_cur_pkts,
				   flow->print(flowbuf, sizeof(flowbuf)));
#endif
    }
  }

  /* Update flow device stats */
  if(!flow->setFlowDevice(zflow->core.deviceIP,
			  src2dst_direction ? zflow->core.inIndex  : zflow->core.outIndex,
			  src2dst_direction ? zflow->core.outIndex : zflow->core.inIndex)) {
    static bool flow_device_already_set = false;
    if(!flow_device_already_set) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "A flow has been seen from multiple exporters or from "
				   "multiple IN/OUT interfaces. Check exporters configuration.");
      flow_device_already_set = true;
    }
  }

#ifdef MAC_DEBUG
  char bufm1[32], bufm2[32];
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
      "Processing Flow [src mac: %s][dst mac: %s][src2dst: %i]",
      Utils::formatMac(srcMac->get_mac(), bufm1, sizeof(bufm1)),
      Utils::formatMac(dstMac->get_mac(), bufm2, sizeof(bufm2)),
      (src2dst_direction) ? 1 : 0);
#endif

  /* Update Mac stats
     Note: do not use src2dst_direction to inc the stats as
     in_bytes/in_pkts and out_bytes/out_pkts are already relative to the current
     source mac (srcMac) and destination mac (dstMac)
  */
  if(likely(srcMac != NULL)) {
    srcMac->incSentStats(getTimeLastPktRcvd(), zflow->core.pkt_sampling_rate * zflow->core.in_pkts,
			 zflow->core.pkt_sampling_rate * zflow->core.in_bytes);
    srcMac->incRcvdStats(getTimeLastPktRcvd(), zflow->core.pkt_sampling_rate * zflow->core.out_pkts,
			 zflow->core.pkt_sampling_rate * zflow->core.out_bytes);

    srcMac->setSourceMac();
  }

  if(likely(dstMac != NULL)) {
    dstMac->incSentStats(getTimeLastPktRcvd(), zflow->core.pkt_sampling_rate * zflow->core.out_pkts,
			 zflow->core.pkt_sampling_rate * zflow->core.out_bytes);
    dstMac->incRcvdStats(getTimeLastPktRcvd(), zflow->core.pkt_sampling_rate * zflow->core.in_pkts,
			 zflow->core.pkt_sampling_rate * zflow->core.in_bytes);
  }

  if(zflow->core.l4_proto == IPPROTO_TCP) {
    struct timeval when;

    when.tv_sec = (long)now, when.tv_usec = 0;
    flow->updateTcpFlags((const struct bpf_timeval*)&when,
			 zflow->core.tcp_flags, src2dst_direction);
    flow->incTcpBadStats(true,
			 zflow->core.tcp.ooo_in_pkts, zflow->core.tcp.retr_in_pkts,
			 zflow->core.tcp.lost_in_pkts);
    flow->incTcpBadStats(false,
			 zflow->core.tcp.ooo_out_pkts, zflow->core.tcp.retr_out_pkts,
			 zflow->core.tcp.lost_out_pkts);
  }

#ifdef NTOPNG_PRO
  if(zflow->core.deviceIP) {
    // if(ntop->getPrefs()->is_flow_device_port_rrd_creation_enabled() && ntop->getPro()->has_valid_license()) {
    if(!flow_interfaces_stats)
      flow_interfaces_stats = new FlowInterfacesStats();

    if(flow_interfaces_stats) {
      flow_interfaces_stats->incStats(now, zflow->core.deviceIP, zflow->core.inIndex,
				      zflow->core.out_bytes, zflow->core.in_bytes);
      /* If the SNMP device is actually an host with an SNMP agent, then traffic can enter and leave it
	 from the same interface (think to a management interface). For this reason it is important to check
	 the outIndex and increase its counters only if it is different from inIndex to avoid double counting. */
      if(zflow->core.outIndex != zflow->core.inIndex)
	flow_interfaces_stats->incStats(now, zflow->core.deviceIP, zflow->core.outIndex,
					zflow->core.in_bytes, zflow->core.out_bytes);
    }
  }
#endif

  flow->addFlowStats(src2dst_direction,
		     zflow->core.pkt_sampling_rate*zflow->core.in_pkts,
		     zflow->core.pkt_sampling_rate*zflow->core.in_bytes, 0,
		     zflow->core.pkt_sampling_rate*zflow->core.out_pkts,
		     zflow->core.pkt_sampling_rate*zflow->core.out_bytes, 0,
		     zflow->core.last_switched);
  p.app_protocol = zflow->core.l7_proto.app_protocol, p.master_protocol = zflow->core.l7_proto.master_protocol;
  p.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;
  flow->setDetectedProtocol(p, true);
  flow->setJSONInfo(json_object_to_json_string(zflow->additional_fields));

  flow->updateInterfaceLocalStats(src2dst_direction,
				  zflow->core.pkt_sampling_rate*(zflow->core.in_pkts+zflow->core.out_pkts),
				  zflow->core.pkt_sampling_rate*(zflow->core.in_bytes+zflow->core.out_bytes));

  if(zflow->dns_query && zflow->dns_query[0] != '\0') flow->setDNSQuery(zflow->dns_query);
  if(zflow->http_url && zflow->http_url[0] != '\0')   flow->setHTTPURL(zflow->http_url);
  if(zflow->http_site && zflow->http_site[0] != '\0') flow->setServerName(zflow->http_site);
  if(zflow->ssl_server_name && zflow->ssl_server_name[0] != '\0') flow->setServerName(zflow->ssl_server_name);
  if(zflow->bittorrent_hash && zflow->bittorrent_hash[0] != '\0') flow->setBTHash(zflow->bittorrent_hash);
  if(zflow->core.vrfId)      flow->setVRFid(zflow->core.vrfId);
#ifdef NTOPNG_PRO
  if(zflow->custom_app.pen) {
    flow->setCustomApp(zflow->custom_app);

    if(custom_app_stats || (custom_app_stats = new(std::nothrow) CustomAppStats(this))) {
      custom_app_stats->incStats(zflow->custom_app.remapped_app_id,
				 zflow->core.pkt_sampling_rate * (zflow->core.in_bytes + zflow->core.out_bytes));
    }
  }
#endif

  // NOTE: fill the category only after the server name is set
  flow->fillZmqFlowCategory();

  /* Do not put incStats before guessing the flow protocol */
  incStats(true /* ingressPacket */,
	   now, srcIP.isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	   flow->get_detected_protocol().app_protocol,
	   zflow->core.pkt_sampling_rate*(zflow->core.in_bytes + zflow->core.out_bytes),
	   zflow->core.pkt_sampling_rate*(zflow->core.in_pkts + zflow->core.out_pkts),
	   24 /* 8 Preamble + 4 CRC + 12 IFG */ + 14 /* Ethernet header */);


  /* purge is actually performed at most one time every FLOW_PURGE_FREQUENCY */
  // purgeIdle(zflow->core.last_switched);
}

/* **************************************************** */

bool NetworkInterface::processPacket(u_int32_t bridge_iface_idx,
				     bool ingressPacket,
				     const struct bpf_timeval *when,
				     const u_int64_t packet_time,
				     struct ndpi_ethhdr *eth,
				     u_int16_t vlan_id,
				     struct ndpi_iphdr *iph,
				     struct ndpi_ipv6hdr *ip6,
				     u_int16_t ipsize,
				     u_int32_t rawsize,
				     const struct pcap_pkthdr *h,
				     const u_char *packet,
				     u_int16_t *ndpiProtocol,
				     Host **srcHost, Host **dstHost,
				     Flow **hostFlow) {
  bool src2dst_direction, is_sent_packet = false; /* FIX */
  u_int8_t l4_proto;
  Flow *flow;
  Mac *srcMac = NULL, *dstMac = NULL;
  IpAddress src_ip, dst_ip;
  ICMPinfo icmp_info;
  u_int16_t src_port = 0, dst_port = 0, payload_len = 0;
  struct ndpi_tcphdr *tcph = NULL;
  struct ndpi_udphdr *udph = NULL;
  struct sctphdr *sctph    = NULL;
  u_int16_t l4_packet_len;
  u_int8_t *l4, tcp_flags = 0, *payload = NULL;
  u_int8_t *ip;
  bool is_fragment = false, new_flow;
  bool pass_verdict = true;

  /* VLAN disaggregation */
  if((!isDynamicInterface()) && (flowHashingMode == flowhashing_vlan) && (vlan_id > 0)) {
    NetworkInterface *vIface;

    if((vIface = getSubInterface((u_int32_t)vlan_id, false)) != NULL) {
      bool ret;

      vIface->setTimeLastPktRcvd(h->ts.tv_sec);
      ret = vIface->processPacket(bridge_iface_idx,
				  ingressPacket, when, packet_time,
				  eth, vlan_id,
				  iph, ip6, ipsize, rawsize,
				  h, packet, ndpiProtocol,
				  srcHost, dstHost, hostFlow);

      incStats(ingressPacket, when->tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN,
	       rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);

      return(ret);
    }
  }

  if((srcMac = getMac(eth->h_source, true))) {
    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
    srcMac->incSentStats(getTimeLastPktRcvd(), 1, rawsize);
#endif
    srcMac->setSeenIface(bridge_iface_idx);

#ifdef NTOPNG_PRO
    u_int16_t mac_pool = 0;
    char bufMac[24];
    char *mac_str;

    /* When captive portal is disabled, use the auto_assigned_pool_id as the default MAC pool */
    if(host_pools
       && (ntop->getPrefs()->get_auto_assigned_pool_id() != NO_HOST_POOL_ID)
       && (!ntop->getPrefs()->isCaptivePortalEnabled())
       && (srcMac->locate() == located_on_lan_interface)) {
      if(!host_pools->findMacPool(srcMac->get_mac(), &mac_pool) || (mac_pool == NO_HOST_POOL_ID)) {
        mac_str = Utils::formatMac(srcMac->get_mac(), bufMac, sizeof(bufMac));
        host_pools->addToPool(mac_str, ntop->getPrefs()->get_auto_assigned_pool_id(), 0);
      }
    }
#endif
  }

  if((dstMac = getMac(eth->h_dest, true))) {
    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
    dstMac->incRcvdStats(getTimeLastPktRcvd(), 1, rawsize);
#endif
  }

  if(iph != NULL) {
    /* IPv4 */
    if(ipsize < 20) {
      incStats(ingressPacket,
	       when->tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN,
	       rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }

    if(((iph->ihl * 4) > ipsize) || (ipsize < ntohs(iph->tot_len))
       || (iph->frag_off & htons(0x1FFF /* IP_OFFSET */)) != 0)
      is_fragment = true;    

    l4_packet_len = ntohs(iph->tot_len) - (iph->ihl * 4);
    l4_proto = iph->protocol;
    l4 = ((u_int8_t *) iph + iph->ihl * 4);
    ip = (u_int8_t*)iph;
  } else {
    /* IPv6 */
    u_int ipv6_shift = sizeof(const struct ndpi_ipv6hdr);

    if(ipsize < sizeof(const struct ndpi_ipv6hdr)) {
      incStats(ingressPacket,
	       when->tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize,
	       1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }

    l4_packet_len = ntohs(ip6->ip6_hdr.ip6_un1_plen);
    l4_proto = ip6->ip6_hdr.ip6_un1_nxt;

    if((l4_proto == 0x3C /* IPv6 destination option */) ||
	(l4_proto == 0x0 /* Hop-by-hop option */)) {
      u_int8_t *options = (u_int8_t*)ip6 + ipv6_shift;

      l4_proto = options[0];
      ipv6_shift += 8 * (options[1] + 1);

      if(ipsize < ipv6_shift) {
	incStats(ingressPacket,
		 when->tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
		 rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	       NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
	       rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }
  } else if(l4_proto == IPPROTO_SCTP) {
    if(l4_packet_len >= sizeof(struct sctphdr)) {
      /* SCTP */
      sctph = (struct sctphdr *)l4;
      src_port = sctph->sport,  dst_port = sctph->dport;

      payload = &l4[sizeof(struct sctphdr)];
      payload_len = max_val(0, l4_packet_len - sizeof(struct sctphdr));
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid SCTP packet received [%u bytes long]", l4_packet_len);
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
	       rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }
  } else if (l4_proto == IPPROTO_ICMP) {
    icmp_info.dissectICMP(l4_packet_len, l4);
  } else {
    /* non TCP/UDP protocols */
  }

  if(iph != NULL)
    src_ip.set(iph->saddr), dst_ip.set(iph->daddr);
  else
    src_ip.set(&ip6->ip6_src), dst_ip.set(&ip6->ip6_dst);

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

  PROFILING_SECTION_ENTER("NetworkInterface::processPacket: getFlow", 1);
  /* Updating Flow */
  flow = getFlow(srcMac, dstMac, vlan_id, 0, 0, 0,
		 l4_proto == IPPROTO_ICMP ? &icmp_info : NULL,
		 &src_ip, &dst_ip, src_port, dst_port,
		 l4_proto, &src2dst_direction, last_pkt_rcvd, last_pkt_rcvd, rawsize, &new_flow, true);
  PROFILING_SECTION_EXIT(1);

  if(flow == NULL) {
    incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
	     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    return(pass_verdict);
  } else {
#ifdef HAVE_NEDGE
    if(new_flow)
      flow->setIngress2EgressDirection(ingressPacket);
#endif
    *srcHost = src2dst_direction ? flow->get_cli_host() : flow->get_srv_host();
    *dstHost = src2dst_direction ? flow->get_srv_host() : flow->get_cli_host();
    *hostFlow = flow;

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

	if((flow->get_cli_host() && flow->get_cli_host()->isLocalHost())
	   && (flow->get_srv_host() && flow->get_srv_host()->isLocalHost())) {
	  /* Set correct direction in localhost ping */
	  if((icmp_type == ICMP_ECHO /* ICMP Echo [RFC792] */)
	     || (icmp_type == ICMP6_ECHO_REQUEST /* 128 - ICMPV6 Echo Request [RFC4443] */))
	    src2dst_direction = true;
	  else if((icmp_type == ICMP_ECHOREPLY /* ICMP Echo Reply [RFC792] */)
		  || (icmp_type == ICMP6_ECHO_REPLY /* 129 - ICMPV6 Echo Reply [RFC4443] */))
	    src2dst_direction = false;
	}

#if 0
	if(((icmp_type == ND_NEIGHBOR_ADVERT) || (icmp_type == ND_NEIGHBOR_SOLICIT))
	   && l4_packet_len >= 24) {
	  /*
	    Neighbor Solicitation and Neighbor Advertisement
	    have the Target Address at offset 8.
	    
	    https://tools.ietf.org/html/rfc2461#section-4.1
	  */
	  Host * target_address_h;
	  IpAddress target_address;
	  
	  target_address.set((ndpi_in6_addr*)&l4[8]);

	  char buf[64];
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "->> %s", target_address.print(buf, sizeof(buf)));
	  
	  if(target_address.isNonEmptyUnicastAddress()
	     && (target_address_h = getHost(&target_address, vlan_id))
	     && (!target_address_h->isBroadcastDomainHost()))
	    target_address_h->setBroadcastDomainHost();
	}
#endif
	
        flow->setICMP(src2dst_direction, icmp_type, icmp_code, l4);
	if(l4_proto == IPPROTO_ICMP)
	  icmp_v4.incStats(icmp_type, icmp_code, is_sent_packet, NULL);
	else
	  icmp_v6.incStats(icmp_type, icmp_code, is_sent_packet, NULL);

	if(l4_proto == IPPROTO_ICMP) {
	  ndpi_protocol icmp_proto = flow->get_detected_protocol();

	  if(icmp_proto.category == NDPI_PROTOCOL_CATEGORY_UNSPECIFIED) {
	    ndpi_fill_ip_protocol_category(ndpi_struct,
	      ((struct ndpi_iphdr*)ip)->saddr, ((struct ndpi_iphdr*)ip)->daddr, &icmp_proto);
	    flow->setDetectedProtocol(icmp_proto, false);
	  }
	}
      }
      break;
    }

#ifndef HAVE_NEDGE
#ifdef __OpenBSD__
    struct timeval tv_ts;
    tv_ts.tv_sec  = h->ts.tv_sec;
    tv_ts.tv_usec = h->ts.tv_usec;
    flow->incStats(src2dst_direction, rawsize, payload, payload_len, l4_proto, &tv_ts);
#else
    PROFILING_SECTION_ENTER("NetworkInterface::processPacket: flow->incStats", 2);
    flow->incStats(src2dst_direction, rawsize, payload, payload_len, l4_proto, &h->ts);
    PROFILING_SECTION_EXIT(2);
#endif
#endif
  }

  /* Protocol Detection */
  flow->updateInterfaceLocalStats(src2dst_direction, 1, rawsize);

  if(!flow->isDetectionCompleted()) {
    if(isSampledTraffic())
      flow->guessProtocol();
    else {
      if(!is_fragment) {
	struct ndpi_flow_struct *ndpi_flow = flow->get_ndpi_flow();
	struct ndpi_id_struct *cli = (struct ndpi_id_struct*)flow->get_cli_id();
	struct ndpi_id_struct *srv = (struct ndpi_id_struct*)flow->get_srv_id();

	if(flow->get_packets() >= NDPI_MIN_NUM_PACKETS) {
	  flow->setDetectedProtocol(ndpi_detection_giveup(ndpi_struct, ndpi_flow, 1), false);
	} else
	  flow->setDetectedProtocol(ndpi_detection_process_packet(ndpi_struct, ndpi_flow,
								  ip, ipsize, (u_int32_t)packet_time,
								  cli, srv), false);
      } else {
	// FIX - only handle unfragmented packets
	// ntop->getTrace()->traceEvent(TRACE_WARNING, "IP fragments are not handled yet!");
      }
    }
  }

  if(flow->isDetectionCompleted()
     && (!isSampledTraffic())
     && flow->get_cli_host() && flow->get_srv_host()) {
    struct ndpi_flow_struct *ndpi_flow;

    switch(ndpi_get_lower_proto(flow->get_detected_protocol())) {
    case NDPI_PROTOCOL_DHCP:
    {
      Mac *mac = (*srcHost)->getMac(), *payload_cli_mac;

      if(mac && (payload_len > 240)) {
	struct dhcp_packet *dhcpp = (struct dhcp_packet*)payload;

	if(dhcpp->msgType == 0x01) /* Request */
	  ;//mac->setDhcpHost();
	else if(dhcpp->msgType == 0x02) /* Reply */
	  checkMacIPAssociation(false, dhcpp->chaddr, dhcpp->yiaddr);

	for(int i = 240; i<payload_len; ) {
	  u_int8_t id  = payload[i], len = payload[i+1];

	  if(len == 0)
	    break;

#ifdef DHCP_DEBUG
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "[DHCP] [id=%u][len=%u]", id, len);
#endif

	  if(id == 12 /* Host Name */) {
	    char name[64], buf[24], *client_mac, key[64];
	    int j;

	    j = ndpi_min(len, sizeof(name)-1);
	    strncpy((char*)name, (char*)&payload[i+2], j);
	    name[j] = '\0';

	    client_mac = Utils::formatMac(&payload[28], buf, sizeof(buf));
	    ntop->getTrace()->traceEvent(TRACE_INFO, "[DHCP] %s = '%s'", client_mac, name);

	    snprintf(key, sizeof(key), DHCP_CACHE, get_id());
	    ntop->getRedis()->hashSet(key, client_mac, name);

	    if((payload_cli_mac = getMac(&payload[28], false)))
	       payload_cli_mac->inlineSetDHCPName(name);

#ifdef DHCP_DEBUG
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "[DHCP] %s = '%s'", client_mac, name);
#endif
	  } else if(id == 55 /* Parameters List (Fingerprint) */) {
	    char fingerprint[64], buf[32];
	    u_int idx, offset = 0;

	    len = ndpi_min(len, sizeof(buf)/2);

	    for(idx=0; idx<len; idx++) {
	      snprintf((char*)&fingerprint[offset], sizeof(fingerprint)-offset-1, "%02X",  payload[i+2+idx] & 0xFF);
	      offset += 2;
	    }

#ifdef DHCP_DEBUG
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "%s = %s", mac->print(buf, sizeof(buf)),fingerprint);
#endif
	    mac->inlineSetFingerprint((char*)flow->get_ndpi_flow()->protos.dhcp.fingerprint);
	  } else if(id == 0xFF)
	    break; /* End of options */

	  i += len + 2;
	}
      }
    }
    break;

    case NDPI_PROTOCOL_DHCPV6:
      {
	Mac *src_mac = (*srcHost)->getMac();
	Mac *dst_mac = (*dstHost)->getMac();

	if(src_mac && dst_mac
	   && (payload_len > 20)
	   && dst_mac->isMulticast())
	  ;//src_mac->setDhcpHost();
      }
      break;

    case NDPI_PROTOCOL_NETBIOS:
      if(*srcHost) {
	if(! (*srcHost)->is_label_set()) {
	  char name[64];

	  if(((payload[2] & 0x80) /* NetBIOS Response */ || ((payload[2] & 0x78) == 0x28 /* NetBIOS Registration */))
	     && (ndpi_netbios_name_interpret((char*)&payload[12], name, sizeof(name)) > 0)
	     && (!strstr(name, "__MSBROWSE__"))
	    ) {

	    if(name[0] == '*') {
	      int limit = min(payload_len-57, (int)sizeof(name)-1);
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
	      (*srcHost)->set_host_label(name, true);
	  }
	}
      }
      break;

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

    case NDPI_PROTOCOL_SSDP:
      if(payload_len > 0)
	flow->dissectSSDP(src2dst_direction, (char*)payload, payload_len);
      break;

    case NDPI_PROTOCOL_DNS:
      ndpi_flow = flow->get_ndpi_flow();

      /*
	DNS-over-TCP flows may carry zero-payload TCP segments
	e.g., during three-way-handshake, or when acknowledging.
	Make sure only non-zero-payload segments are processed.
      */
      if((payload_len > 0) && payload) {
	/*
	  DNS-over-TCP has a 2-bytes field with DNS payload length
	  at the beginning. See RFC1035 section 4.2.2. TCP usage.
	*/
	u_int8_t dns_offset = ((l4_proto == IPPROTO_TCP) && (payload_len > 1)) ? 2 : 0;
	struct ndpi_dns_packet_header *header = (struct ndpi_dns_packet_header*)(payload + dns_offset);
	u_int16_t dns_flags = ntohs(header->flags);
	bool is_query   = (dns_flags & 0x8000) ? 0 : 1;
	
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
				      ip, ipsize, (u_int32_t)packet_time,
				      src2dst_direction ? cli : srv,
				      src2dst_direction ? srv : cli);

	/*
	  We reset the nDPI flow so that it can decode new packets
	  of the same flow (e.g. the DNS response)
	*/
	ndpi_flow->detected_protocol_stack[0] = NDPI_PROTOCOL_UNKNOWN;
      }
      break;

    case NDPI_PROTOCOL_MDNS:
#ifdef MDNS_TEST
      extern void _dissectMDNS(u_char *buf, u_int buf_len, char *out, u_int out_len);
      char outbuf[1024];

      _dissectMDNS(payload, payload_len, outbuf, sizeof(outbuf));
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", outbuf);      
#endif
      flow->dissectMDNS(payload, payload_len);

      if(discovery && iph)
	discovery->queueMDNSRespomse(iph->saddr, payload, payload_len);
      break;

    case NDPI_PROTOCOL_DROPBOX:
      if((src_port == dst_port) && (dst_port == htons(17500)))
	flow->get_cli_host()->dissectDropbox((const char *)payload, payload_len);      
      break;
      
    default:
      if(flow->isSSLProto())
        flow->dissectSSL(payload, payload_len, when, src2dst_direction);
    }

    flow->processDetectedProtocol();

#ifdef HAVE_NEDGE
    if(is_bridge_interface()) {
      struct tm now;
      time_t t_now = time(NULL);
      localtime_r(&t_now, &now);
      pass_verdict = flow->checkPassVerdict(&now);

      if(pass_verdict) {
	TrafficShaper *shaper_ingress, *shaper_egress;
	char buf[64];

	flow->getFlowShapers(src2dst_direction, &shaper_ingress, &shaper_egress);
	ntop->getTrace()->traceEvent(TRACE_DEBUG, "[%s] %u / %u ",
				     flow->get_detected_protocol_name(buf, sizeof(buf)),
				     shaper_ingress, shaper_egress);
	pass_verdict = passShaperPacket(shaper_ingress, shaper_egress, (struct pcap_pkthdr*)h);
      } else {
	flow->incFlowDroppedCounters();
      }
    }
#endif
  }

#if 0
  if(new_flow)
    flow->updateCommunityIdFlowHash();
#endif

  /* Live packet dump to mongoose */
  if(num_live_captures > 0)
    deliverLiveCapture(h, packet, flow);

  PROFILING_SECTION_ENTER("NetworkInterface::processPacket: incStats", 4);
  incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	   flow->get_detected_protocol().app_protocol,
	   rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
  PROFILING_SECTION_EXIT(4);

  return(pass_verdict);
}

/* **************************************************** */

void NetworkInterface::purgeIdle(time_t when) {
  if(purge_idle_flows_hosts) {
    u_int n, m;

    last_pkt_rcvd = when;

    if((n = purgeIdleFlows()) > 0)
      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Purged %u/%u idle flows on %s",
				   n, getNumFlows(), ifname);

    if((m = purgeIdleHostsMacsASesVlans()) > 0)
      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Purged %u/%u idle hosts/macs on %s",
				   m, getNumHosts()+getNumMacs(), ifname);
  }

  if(flowHashing) {
    FlowHashing *current, *tmp;

    HASH_ITER(hh, flowHashing, current, tmp) {
      if(current->iface)
	current->iface->purgeIdle(when);
    }
  }
}

/* ***************************************************** */

#ifdef HAVE_EBPF

#ifdef EBPF_DEBUG

static void IPV4Handler(Flow *f, eBPFevent *e) {
  struct ipv4_kernel_data *event = &e->event.v4;
  char buf1[32], buf2[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "[%s][IPv4][%s][pid/tid: %u/%u (%s), uid/gid: %u/%u][father pid/tid: %u/%u (%s), uid/gid: %u/%u][addr: %s:%u <-> %s:%u][latency: %.2f msec]\n",
			       e->ifname, (event->net.proto == IPPROTO_TCP) ? "TCP" : "UDP",
			       e->proc.pid, e->proc.tid,
			       e->proc.full_task_path ? e->proc.full_task_path : e->proc.task,
			       e->proc.uid, e->proc.gid,
			       e->father.pid, e->father.tid,
			       e->father.full_task_path ? e->father.full_task_path : e->father.task,
			       e->father.uid, e->father.gid,
			       Utils::intoaV4(htonl(event->saddr), buf1, sizeof(buf1)), event->net.sport,
			       Utils::intoaV4(htonl(event->daddr), buf2, sizeof(buf2)), event->net.dport,
			       ((float)event->net.latency_usec)/(float)1000);
}

/* ***************************************************** */

static void IPV6Handler(Flow *f, eBPFevent *e) {
  struct ipv6_kernel_data *event = &e->event.v6;
  char buf1[32], buf2[32];
  struct ndpi_in6_addr saddr, daddr;

  memcpy(&saddr, &event->saddr, sizeof(saddr));
  memcpy(&daddr, &event->daddr, sizeof(daddr));

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "[%s][IPv6][%s][pid/tid: %u/%u (%s), uid/gid: %u/%u][father pid/tid: %u/%u (%s), uid/gid: %u/%u][addr: %s:%u <-> %s:%u][latency: %.2f msec]\n",
			       e->ifname, (event->net.proto == IPPROTO_TCP) ? "TCP" : "UDP",
			       e->proc.pid, e->proc.tid,
			       e->proc.full_task_path ? e->proc.full_task_path : e->proc.task,
			       e->proc.uid, e->proc.gid,
			       e->father.pid, e->father.tid,
			       e->father.full_task_path ? e->father.full_task_path : e->father.task,
			       e->father.uid, e->father.gid,
			       Utils::intoaV6(saddr, 128, buf1, sizeof(buf1)),
			       event->net.sport,
			       Utils::intoaV6(daddr, 128, buf2, sizeof(buf2)),
			       event->net.dport, ((float)event->net.latency_usec)/(float)1000);
}

#endif

#endif

/* **************************************************** */

bool NetworkInterface::dissectPacket(u_int32_t bridge_iface_idx,
				     bool ingressPacket,
				     u_int8_t *sender_mac,
				     const struct pcap_pkthdr *h,
				     const u_char *packet,
				     u_int16_t *ndpiProtocol,
				     Host **srcHost, Host **dstHost,
				     Flow **flow) {
  struct ndpi_ethhdr *ethernet, dummy_ethernet;
  u_int64_t time;
  u_int16_t eth_type, ip_offset, vlan_id = 0, eth_offset = 0;
  u_int32_t null_type;
  int pcap_datalink_type = get_datalink();
  bool pass_verdict = true;
  u_int32_t rawsize = h->len * scalingFactor;

  /* Note summy ethernet is always 0 unless sender_mac is set (Netfilter only) */
  memset(&dummy_ethernet, 0, sizeof(dummy_ethernet));

  pollQueuedeBPFEvents();
  reloadCustomCategories();
  bcast_domains->inlineReloadBroadcastDomains();

#if 0
  static u_int n = 0;

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%u %s", ++n, ingressPacket ? "RX" : "TX");
#endif

  /* Netfilter interfaces don't report MAC addresses on packets */
  if(getIfType() == interface_type_NETFILTER)
    rawsize += sizeof(struct ndpi_ethhdr);

  if(h->len > ifMTU) {
    if(!mtuWarningShown) {
#ifdef __linux__
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Invalid packet received [len: %u][max len: %u].", h->len, ifMTU);
      ntop->getTrace()->traceEvent(TRACE_WARNING, "If you have TSO/GRO enabled, please disable it");
      if (strchr(ifname, ':') == NULL) /* print ethtool command for standard interfaces only */
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Use sudo ethtool -K %s gro off gso off tso off", ifname);
#endif
      mtuWarningShown = true;
    }
  }

  setTimeLastPktRcvd(h->ts.tv_sec);
  purgeIdle(h->ts.tv_sec);

  time = ((uint64_t) h->ts.tv_sec) * 1000 + h->ts.tv_usec / 1000;

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
      incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict); /* Any other non IP protocol */
    }

    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    if(sender_mac) memcpy(&dummy_ethernet.h_source, sender_mac, 6);
    ip_offset = 4 + eth_offset;
  } else if(pcap_datalink_type == DLT_EN10MB) {
    ethernet = (struct ndpi_ethhdr *)&packet[eth_offset];
    ip_offset = sizeof(struct ndpi_ethhdr) + eth_offset;
    eth_type = ntohs(ethernet->h_proto);
  } else if(pcap_datalink_type == 113 /* Linux Cooked Capture */) {
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    if(sender_mac) memcpy(&dummy_ethernet.h_source, sender_mac, 6);
    eth_type = (packet[eth_offset+14] << 8) + packet[eth_offset+15];
    ip_offset = 16 + eth_offset;
#ifdef DLT_RAW
  } else if(pcap_datalink_type == DLT_RAW /* Linux TUN/TAP device in TUN mode; Raw IP capture */
	    || pcap_datalink_type == 14  /* raw IP DLT_RAW on OpenBSD captures */) {
    switch((packet[eth_offset] & 0xf0) >> 4) {
    case 4:
      eth_type = ETHERTYPE_IP;
      break;
    case 6:
      eth_type = ETHERTYPE_IPV6;
      break;
    default:
      incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict); /* Unknown IP protocol version */
    }

    if(sender_mac) memcpy(&dummy_ethernet.h_source, sender_mac, 6);
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    ip_offset = eth_offset;
#endif /* DLT_RAW */
  } else if(pcap_datalink_type == DLT_IPV4) {
    eth_type = ETHERTYPE_IP;
    if(sender_mac) memcpy(&dummy_ethernet.h_source, sender_mac, 6);
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    ip_offset = 0;
  } else {
    incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
    ip_offset += 6 /* PPPoE */;
    /* Now we need to skip the PPP header */
    if(packet[ip_offset] == 0x0)
      eth_type = packet[ip_offset+1], ip_offset += 2; /* 2 Byte protocol */
    else
      eth_type = packet[ip_offset], ip_offset += 1; /* 1 Byte protocol */

    switch(eth_type) {
    case 0x21:
      eth_type = ETHERTYPE_IP;
      break;

    case 0x57:
      eth_type = ETHERTYPE_IPV6;
      break;

    default:
      incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IP,
	       NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }
    goto decode_packet_eth;
    break;

  case ETHERTYPE_IP:
    if(h->caplen >= ip_offset + sizeof(struct ndpi_iphdr)) {
      u_int16_t frag_off;
      struct ndpi_iphdr *iph = (struct ndpi_iphdr *)&packet[ip_offset];
      u_short ip_len = ((u_short)iph->ihl * 4);
      struct ndpi_ipv6hdr *ip6 = NULL;

      if(iph->version != 4) {
	/* This is not IPv4 */
	incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IP,
		 NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	return(pass_verdict);
      } else
	frag_off = ntohs(iph->frag_off);

      if(ntop->getGlobals()->decode_tunnels() && (iph->protocol == IPPROTO_GRE)
	 && ((frag_off & 0x3FFF /* IP_MF | IP_OFFSET */ ) == 0)
	 && h->caplen >= ip_offset + ip_len + sizeof(struct grev1_header)) {
	struct grev1_header gre;
	u_int offset = ip_offset + ip_len +  sizeof(struct grev1_header);

	memcpy(&gre, &packet[ip_offset+ip_len], sizeof(struct grev1_header));
	gre.flags_and_version = ntohs(gre.flags_and_version);
	gre.proto = ntohs(gre.proto);

	if(gre.flags_and_version & (GRE_HEADER_CHECKSUM | GRE_HEADER_ROUTING)) offset += 4;
	if(gre.flags_and_version & GRE_HEADER_KEY)      offset += 4;
	if(gre.flags_and_version & GRE_HEADER_SEQ_NUM)  offset += 4;

	if(h->caplen >= offset) {
	  if(gre.proto == 0x6558 /* Transparent Ethernet Bridging */) {
	    eth_offset = offset;
	    goto datalink_check;
	  } else if(gre.proto == ETHERTYPE_IP) {
	    ip_offset = offset;
	    goto decode_packet_eth;
	  } else if(gre.proto == ETHERTYPE_IPV6) {
	    eth_type = ETHERTYPE_IPV6;
	    ip_offset = offset;
	    goto decode_packet_eth;
	  }
	}

	/* ERSPAN Type 2 has an 8-byte header
	   https://tools.ietf.org/html/draft-foschiano-erspan-00 */
	if(h->caplen >= offset + sizeof(struct ndpi_ethhdr) + 8) {
	  if(gre.proto == ETH_P_ERSPAN) {
	    offset += 8 /* ERSPAN Type 2 header */;
	    eth_offset = offset;
	    ethernet = (struct ndpi_ethhdr *)&packet[eth_offset];
	    ip_offset = eth_offset + sizeof(struct ndpi_ethhdr);
	    eth_type = ntohs(ethernet->h_proto);
	    goto decode_packet_eth;
	  } else if(gre.proto == ETH_P_ERSPAN2) {
	    ; /* TODO: support ERSPAN Type 3 */
	  } else {
	    /* Unknown encapsulation */
	  }
	}

      } else if(ntop->getGlobals()->decode_tunnels() && (iph->protocol == IPPROTO_UDP)
		&& ((frag_off & 0x3FFF /* IP_MF | IP_OFFSET */ ) == 0)) {
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
	      incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6,
		       NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
		incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
			 rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	    incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
		     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	    incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
		     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    return(pass_verdict);
	  }
	}
      }

      if(vlan_id && ntop->getPrefs()->do_ignore_vlans())
	vlan_id = 0;
      if((vlan_id == 0) && ntop->getPrefs()->do_simulate_vlans())
	vlan_id = (ip6 ? ip6->ip6_src.u6_addr.u6_addr8[15] +
		   ip6->ip6_dst.u6_addr.u6_addr8[15] : iph->saddr + iph->daddr) % 0xFF;

      if(ntop->getPrefs()->do_ignore_macs())
	ethernet = &dummy_ethernet;

      try {
        PROFILING_SECTION_ENTER("NetworkInterface::dissectPacket: processPacket", 0);
	pass_verdict = processPacket(bridge_iface_idx,
				     ingressPacket, &h->ts, time,
				     ethernet,
				     vlan_id, iph,
				     ip6, h->caplen - ip_offset, rawsize,
				     h, packet, ndpiProtocol, srcHost, dstHost, flow);
        PROFILING_SECTION_EXIT(0);
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
    if(h->caplen >= ip_offset + sizeof(struct ndpi_ipv6hdr)) {
      struct ndpi_iphdr *iph = NULL;
      struct ndpi_ipv6hdr *ip6 = (struct ndpi_ipv6hdr*)&packet[ip_offset];

      if((ntohl(ip6->ip6_hdr.ip6_un1_flow) & 0xF0000000) != 0x60000000) {
	/* This is not IPv6 */
	incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
		 rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	return(pass_verdict);
      } else {
	u_int ipv6_shift = sizeof(const struct ndpi_ipv6hdr);
	u_int8_t l4_proto = ip6->ip6_hdr.ip6_un1_nxt;

	if(l4_proto == 0x3C /* IPv6 destination option */) {
	  u_int8_t *options = (u_int8_t*)ip6 + ipv6_shift;
	  l4_proto = options[0];
	  ipv6_shift = 8 * (options[1] + 1);
	}

	if(ntop->getGlobals()->decode_tunnels() && (l4_proto == IPPROTO_GRE)
	   && h->caplen >= ip_offset + ipv6_shift + sizeof(struct grev1_header)) {
	  struct grev1_header gre;
	  u_int offset = ip_offset + ipv6_shift + sizeof(struct grev1_header);

	  memcpy(&gre, &packet[ip_offset + ipv6_shift], sizeof(struct grev1_header));
	  gre.flags_and_version = ntohs(gre.flags_and_version);
	  gre.proto = ntohs(gre.proto);

	  if(gre.flags_and_version & (GRE_HEADER_CHECKSUM | GRE_HEADER_ROUTING)) offset += 4;
	  if(gre.flags_and_version & GRE_HEADER_KEY)      offset += 4;
	  if(gre.flags_and_version & GRE_HEADER_SEQ_NUM)  offset += 4;

	  if(h->caplen >= offset) {
	    if(gre.proto == ETHERTYPE_IP) {
	      eth_type = ETHERTYPE_IP;
	      ip_offset = offset;
	      goto decode_packet_eth;
	    } else if(gre.proto == ETHERTYPE_IPV6) {
	      ip_offset = offset;
	      goto decode_packet_eth;
	    }
	  }

	  if(h->caplen >= offset + sizeof(struct ndpi_ethhdr) + 8  /* ERSPAN Type 2 header */) {
	    if(gre.proto == ETH_P_ERSPAN) {
	      offset += 8;
	      eth_offset = offset;
	      ethernet = (struct ndpi_ethhdr *)&packet[eth_offset];
	      ip_offset = eth_offset + sizeof(struct ndpi_ethhdr);
	      eth_type = ntohs(ethernet->h_proto);
	      goto decode_packet_eth;
	    } else if(gre.proto == ETH_P_ERSPAN2) {
	      ; /* TODO: support ERSPAN Type 3 */
	    } else {
	      /* Unknown encapsulation */
	    }
	  }

	} else if(ntop->getGlobals()->decode_tunnels() && (l4_proto == IPPROTO_UDP)) {
	  // ip_offset += ipv6_shift;
	  if((ip_offset + ipv6_shift) >= h->len) {
	    incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
		     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    return(pass_verdict);
	  }

	  struct ndpi_udphdr *udp = (struct ndpi_udphdr *)&packet[ip_offset + ipv6_shift];
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
	    ip_offset = ip_offset+ipv6_shift+sizeof(struct ndpi_udphdr);
	    u_int8_t capwap_header_len = ((*(u_int8_t*)&packet[ip_offset+1])>>3)*4;
	    ip_offset = ip_offset+capwap_header_len+24+8;

	    if(ip_offset >= h->len) {
	      incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
		       rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	      incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
		       rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      return(pass_verdict);
	    }
	  }
	}

	if(vlan_id && ntop->getPrefs()->do_ignore_vlans())
	  vlan_id = 0;
	if((vlan_id == 0) && ntop->getPrefs()->do_simulate_vlans())
	  vlan_id = (ip6 ? ip6->ip6_src.u6_addr.u6_addr8[15] + ip6->ip6_dst.u6_addr.u6_addr8[15] : iph->saddr + iph->daddr) % 0xFF;

	if(ntop->getPrefs()->do_ignore_macs())
	  ethernet = &dummy_ethernet;

	try {
          PROFILING_SECTION_ENTER("NetworkInterface::dissectPacket: processPacket", 0);
	  pass_verdict = processPacket(bridge_iface_idx,
				       ingressPacket, &h->ts, time,
				       ethernet,
				       vlan_id,
				       iph, ip6, h->len - ip_offset, rawsize,
				       h, packet, ndpiProtocol, srcHost, dstHost, flow);
          PROFILING_SECTION_EXIT(0);
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
    if(ntop->getPrefs()->do_ignore_macs())
      ethernet = &dummy_ethernet;

    Mac *srcMac = getMac(ethernet->h_source, true);
    Mac *dstMac = getMac(ethernet->h_dest, true);

    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
    if(srcMac) srcMac->incSentStats(h->ts.tv_sec, 1, rawsize);
    if(dstMac) dstMac->incRcvdStats(h->ts.tv_sec, 1, rawsize);
#endif

    if(srcMac && dstMac && (!srcMac->isNull() || !dstMac->isNull())) {
      setSeenMacAddresses();
      srcMac->setSourceMac();

      if((eth_type == ETHERTYPE_ARP) && (h->caplen >= (sizeof(arp_header)+sizeof(struct ndpi_ethhdr)))) {
	struct arp_header *arpp = (struct arp_header*)&packet[ip_offset];
	u_int16_t arp_opcode = ntohs(arpp->ar_op);
#if 0
	u_int32_t arp_spa;
	IpAddress arp_spa_ipa;
	Host *arp_spa_h;
#endif
	bool src2dst_element = false;
	ArpStatsMatrixElement* e;

#if 0
	arp_spa = arpp->arp_spa; /* Sender protocol address */
	arp_spa_ipa.set(arp_spa);

	if(arp_spa_ipa.isNonEmptyUnicastAddress()
	   && (arp_spa_h = getHost(&arp_spa_ipa, vlan_id))
	   && !arp_spa_h->isBroadcastDomainHost())
	  arp_spa_h->setBroadcastDomainHost();
#endif

#ifdef DEBUG
	char buf1[32], buf2[32], buf3[32];
#endif
	u_int32_t src = ntohl(arpp->arp_spa);
	u_int32_t dst = ntohl(arpp->arp_tpa);
	u_int32_t net = src & dst;
	u_int32_t diff;
	u_int8_t cidr;

	if(src > dst) {
	  u_int32_t r = src;
	  src = dst;
	  dst = r;
	}

	diff = dst-src;

	if(diff <= 1024) {
	  u_int32_t mask;
	  IpAddress cur_bcast_domain;

	  /* Ignore networks > /21 */

	  /* 131.114.2.22 <-> 131.114.3.2  */

	  if(diff <= 256) {
	    mask = 0xFFFFFF00, cidr = 24;
	    net &= mask, diff = 256;

	    if((src & mask) != (dst & mask)) {
	      mask <<= 1, cidr -= 1;
	      net = src & mask, diff = diff << 1;
	    }
	  } else if(diff <= 512) {
	    mask = 0xFFFFFE00, cidr = 23;
	    net &= mask, diff = 512;

	    if((src & mask) != (dst & mask)) {
	      mask <<= 1, cidr -= 1;
	      net = src & mask, diff = diff << 1;
	    }
	  } else if(diff <= 768) {
	    mask = 0xFFFFFC00, cidr = 22;
	    net &= mask, diff = 768;

	    if((src & mask) != (dst & mask)) {
	      mask <<= 1, cidr -= 1;
	      net = src & mask, diff = diff << 1;
	    }
	  } else {
	    net &= 0xFFFFF800, diff = 1024, cidr = 21;
	  }

#ifdef DEBUG
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s <-> %s [%s - %u/%u]",
				       Utils::intoaV4(src, buf1, sizeof(buf1)),
				       Utils::intoaV4(dst, buf2, sizeof(buf2)),
				       Utils::intoaV4(net, buf3, sizeof(buf3)),
				       diff, cidr);
#endif

	  cur_bcast_domain.set(htonl(net));
	  bcast_domains->inlineAddAddress(&cur_bcast_domain, cidr);
	}
	
	e  = getArpHashMatrixElement(srcMac->get_mac(), dstMac->get_mac(), &src2dst_element);

#if 0
	char buf1[32], buf2[32];
	Utils::formatMac(srcMac->get_mac(), buf1, sizeof(buf1));
	Utils::formatMac(dstMac->get_mac(), buf2, sizeof(buf2));

	if(!strcmp(buf1, "B4:75:0E:92:89:17") || !strcmp(buf2, "B4:75:0E:92:89:17")) {
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][%s][0x%x][src2dst: %u]",
				     buf1, buf2, arp_opcode, src2dst_element ? 1 : 0);
	}
#endif

	if(arp_opcode == 0x1 /* ARP request */) {
	  arp_requests++;
	  srcMac->incSentArpRequests();
	  dstMac->incRcvdArpRequests();

	  if(e) e->incArpRequests(src2dst_element);
	} else if(arp_opcode == 0x2 /* ARP reply */) {
	  arp_replies++;
	  srcMac->incSentArpReplies();
	  dstMac->incRcvdArpReplies();
	  if(e) e->incArpReplies(src2dst_element);

	  checkMacIPAssociation(true, arpp->arp_sha, arpp->arp_spa);
	  checkMacIPAssociation(true, arpp->arp_tha, arpp->arp_tpa);
	}
      }
    }

    incStats(ingressPacket, h->ts.tv_sec, eth_type, NDPI_PROTOCOL_UNKNOWN,
	     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    break;
  }

  return(pass_verdict);
}

/* **************************************************** */

void NetworkInterface::pollQueuedeBPFEvents() {
#ifdef HAVE_EBPF
  if(ebpfEvents) {
    eBPFevent *event;

    if(dequeueeBPFEvent(&event)) {
      Flow *flow = NULL;
      IpAddress src, dst;
      bool src2dst_direction, new_flow;
      u_int16_t proto, sport, dport;

      if(event->ip_version == 4) {
	src.set(event->event.v4.saddr), dst.set(event->event.v4.daddr),
	  sport = event->sport, dport = event->dport,
	  proto = event->proto;
      } else {
	src.set((struct ndpi_in6_addr*)&event->event.v6.saddr),
	  dst.set((struct ndpi_in6_addr*)&event->event.v6.daddr),
	  sport = event->sport, dport = event->dport,
	  proto = event->proto;
      }

      sport = htons(sport), dport = htons(dport);

      flow = getFlow(NULL /* srcMac */, NULL /* dstMac */,
		     0 /* vlan_id */,
		     0 /* deviceIP */,
		     0 /* inIndex */, 1 /* outIndex */,
		     NULL /* ICMPinfo */,
		     &src, &dst,
		     sport, dport,
		     proto,
		     &src2dst_direction,
		     0, 0, 0, &new_flow,
		     true /* create_if_missing */);


      if(flow) flow->setProcessInfo(event, src2dst_direction ? event->sent_packet : !event->sent_packet);

#ifdef EBPF_DEBUG
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new flow: %u][src2dst_direction: %u]", new_flow ? 1 : 0, src2dst_direction ? 1 : 0);

      if(event->ip_version == 4)
	IPV4Handler(flow, event);
      else
	IPV6Handler(flow, event);
#endif

      ebpf_free_event(event);
      free(event);
    }
  }
#endif
}

/* **************************************************** */

void NetworkInterface::reloadCustomCategories() {
  if(customCategoriesReloadRequested()) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Going to reload categories [iface: %s]", get_name());
    ndpi_enable_loaded_categories(ndpi_struct);
    reload_custom_categories = false;
    reload_hosts_blacklist = true;
  }
}

/* **************************************************** */

void NetworkInterface::startPacketPolling() {
  if((cpu_affinity != -1) && (ntop->getNumCPUs() > 1)) {
    if(Utils::setThreadAffinity(pollLoop, cpu_affinity))
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Couldn't set affinity of interface %s to core %d",
				   get_name(), cpu_affinity);
    else
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting affinity of interface %s to core %d",
				   get_name(), cpu_affinity);
  }

#ifdef __linux__
  pthread_setname_np(pollLoop, get_name());
#endif

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
  next_idle_flow_purge = next_idle_host_purge = 0;
  cpu_affinity = -1,
    has_vlan_packets = false, has_ebpf_events = false, has_mac_addresses = false;
  running = false, inline_interface = false;

  getStats()->cleanup();
  flows_hash->cleanup();
  hosts_hash->cleanup();
  ases_hash->cleanup();
  countries_hash->cleanup();
  vlans_hash->cleanup();
  macs_hash->cleanup();
  if(arp_hash_matrix) arp_hash_matrix->cleanup();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Cleanup interface %s", get_name());
}

/* **************************************************** */

void NetworkInterface::findFlowHosts(u_int16_t vlanId,
				     Mac *src_mac, IpAddress *_src_ip, Host **src,
				     Mac *dst_mac, IpAddress *_dst_ip, Host **dst) {
  int16_t local_network_id;

  PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: hosts_hash->get", 8);
  /* Do not look on sub interfaces, Flows are always created in the same interface of its hosts */
  (*src) = hosts_hash->get(vlanId, _src_ip);
  PROFILING_SECTION_EXIT(8);

  if((*src) == NULL) {
    if(!hosts_hash->hasEmptyRoom()) {
      *src = *dst = NULL;
      has_too_many_hosts = true;
      return;
    }

    if(_src_ip && (_src_ip->isLocalHost(&local_network_id) || _src_ip->isLocalInterfaceAddress())) {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: new LocalHost", 9);
      (*src) = new LocalHost(this, src_mac, vlanId, _src_ip);
      PROFILING_SECTION_EXIT(9);
    } else {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: new RemoteHost", 10);
      (*src) = new RemoteHost(this, src_mac, vlanId, _src_ip);
      PROFILING_SECTION_EXIT(10);
    }

    if(!hosts_hash->add(*src)) {
      //ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
      delete *src;
      *src = *dst = NULL;
      has_too_many_hosts = true;
      return;
    }

    (*src)->postHashAdd();
    has_too_many_hosts = false;

  }

  /* ***************************** */

  PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: hosts_hash->get", 8);
  (*dst) = hosts_hash->get(vlanId, _dst_ip);
  PROFILING_SECTION_EXIT(8);

  if((*dst) == NULL) {
    if(!hosts_hash->hasEmptyRoom()) {
      *dst = NULL;
      has_too_many_hosts = true;
      return;
    }

    if(_dst_ip
       && (_dst_ip->isLocalHost(&local_network_id)
	   || _dst_ip->isLocalInterfaceAddress())) {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: new LocalHost", 9);
      (*dst) = new LocalHost(this, dst_mac, vlanId, _dst_ip);
      PROFILING_SECTION_EXIT(9);
    } else {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: new RemoteHost", 10);
      (*dst) = new RemoteHost(this, dst_mac, vlanId, _dst_ip);
      PROFILING_SECTION_EXIT(10);
    }

    if(!hosts_hash->add(*dst)) {
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
      delete *dst;
      *dst = NULL;
      has_too_many_hosts = true;
      return;
    }

    (*dst)->postHashAdd();
    has_too_many_hosts = false;

  }
}

/* **************************************************** */

struct ndpiStatsRetrieverData {
  nDPIStats *stats;
  Host *host;
};

static bool flow_sum_protos(GenericHashEntry *flow, void *user_data, bool *matched) {
  ndpiStatsRetrieverData *retriever = (ndpiStatsRetrieverData*)user_data;
  nDPIStats *stats = retriever->stats;
  Flow *f = (Flow*)flow;

  if(retriever->host
     && (retriever->host != f->get_cli_host())
     && (retriever->host != f->get_srv_host()))
    return(false); /* false = keep on walking */

  f->sumStats(stats);
  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getnDPIStats(nDPIStats *stats, AddressTree *allowed_hosts,
				    const char *host_ip, u_int16_t vlan_id) {
  ndpiStatsRetrieverData retriever;
  Host *h = NULL;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(host_ip)
    h = findHostByIP(allowed_hosts, (char *)host_ip, vlan_id);

  retriever.stats = stats;
  retriever.host = h;
  walker(&begin_slot, walk_all, walker_flows, flow_sum_protos, (void*)&retriever);
}

/* **************************************************** */

static bool flow_update_hosts_stats(GenericHashEntry *node,
				    void *user_data, bool *matched) {
  Flow *flow = (Flow*)node;
  struct timeval *tv = (struct timeval*)user_data;
  bool dump_alert = ((time(NULL) - tv->tv_sec) < ntop->getPrefs()->get_housekeeping_frequency()) ? true : false;

  if(ntop->getGlobals()->isShutdownRequested() && !ntop->getPrefs()->flushFlowsOnShutdown())
    return(true); /* true = stop walking */

  flow->update_hosts_stats(tv, dump_alert);
  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool update_hosts_stats(GenericHashEntry *node, void *user_data, bool *matched) {
  Host *host = (Host*)node;
  struct timeval *tv = (struct timeval*)user_data;

  host->updateStats(tv);
  *matched = true;

  /*
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Updated: %s [%d]",
    ((StringHost*)node)->host_key(),
    host->getThptTrend());
  */

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool update_ases_stats(GenericHashEntry *node, void *user_data, bool *matched) {
  AutonomousSystem *as = (AutonomousSystem*)node;
  struct timeval *tv = (struct timeval*)user_data;

  as->updateStats(tv);
  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool update_vlans_stats(GenericHashEntry *node, void *user_data, bool *matched) {
  Vlan *vl = (Vlan*)node;
  struct timeval *tv = (struct timeval*)user_data;

  vl->updateStats(tv);
  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool update_macs_stats(GenericHashEntry *node, void *user_data, bool *matched) {
  Mac *mac = (Mac*)node;
  struct timeval *tv = (struct timeval*)user_data;

  mac->updateStats(tv);
  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

// #define PERIODIC_STATS_UPDATE_DEBUG_TIMING

void NetworkInterface::periodicStatsUpdate() {
  struct timeval tv;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  struct timeval tdebug;
#endif

  if(isView()) return;

  if(!read_from_pcap_dump())
    gettimeofday(&tv, NULL);
  else
    tv.tv_sec = last_pkt_rcvd, tv.tv_usec = 0;

#ifdef NTOPNG_PRO
  if(getHostPools()) getHostPools()->checkPoolsStatsReset();
#endif

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  gettimeofday(&tdebug, NULL);
#endif

  flows_hash->walk(&begin_slot, walk_all, flow_update_hosts_stats, (void*)&tv);
  topItemsCommit(&tv);

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "flows_hash->walk took %d seconds", time(NULL) - tdebug.tv_sec);
  gettimeofday(&tdebug, NULL);
#endif

  if(ntop->getGlobals()->isShutdownRequested())
    return;

  // if drop alerts enabled and have some significant packets
  if((packet_drops_alert_perc > 0) && (getNumPacketsSinceReset() > 100)) {
    float drop_perc = getNumPacketDropsSinceReset() * 100.f
      / (getNumPacketDropsSinceReset() + getNumPacketsSinceReset());
    too_many_drops = (drop_perc >= packet_drops_alert_perc) ? true : false;
  } else
    too_many_drops = false;

#ifdef NTOPNG_PRO
  if(aggregated_flows_hash) {
    if((getIfType() == interface_type_DUMMY) || (--nextFlowAggregation == 0)) {
      /* Start over */
      aggregated_flows_hash->cleanup();
      nextFlowAggregation = FLOW_AGGREGATION_DURATION;

#ifdef AGGREGATED_FLOW_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Aggregated flows exported. "
				   "Aggregated flows hash cleared. [num_items: %i]",
				   aggregated_flows_hash->getCurrentSize());
#endif
    } else
#ifdef AGGREGATED_FLOW_DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Aggregation in %i housekeeping cycles [housekeeping frequency: %i] [inter-aggregation housekeeping cycles: %i] ",
				   nextFlowAggregation, ntop->getPrefs()->get_housekeeping_frequency(), FLOW_AGGREGATION_DURATION,
				   aggregated_flows_hash->getCurrentSize());
#endif
    ;
  }
#endif

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "flows aggregation took %d seconds", time(NULL) - tdebug.tv_sec);
  gettimeofday(&tdebug, NULL);
#endif

  checkReloadHostsBroadcastDomain();

  begin_slot = 0;
  hosts_hash->walk(&begin_slot, walk_all, update_hosts_stats, (void*)&tv);

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "hosts_hash->walk took %d seconds", time(NULL) - tdebug.tv_sec);
  gettimeofday(&tdebug, NULL);
#endif

  begin_slot = 0;
  ases_hash->walk(&begin_slot, walk_all, update_ases_stats, (void*)&tv);

  if(hasSeenVlanTaggedPackets()) {
    begin_slot = 0;
    vlans_hash->walk(&begin_slot, walk_all, update_vlans_stats, (void*)&tv);
  }

  begin_slot = 0;
  macs_hash->walk(&begin_slot, walk_all, update_macs_stats, (void*)&tv);

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "asn/macs/vlan->walk took %d seconds", time(NULL) - tdebug.tv_sec);
  gettimeofday(&tdebug, NULL);
#endif

  if(ntop->getGlobals()->isShutdownRequested())
    return;

  if(db) {
    db->updateStats(&tv);
    db->flush();
  }

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "MySQL dump took %d seconds", time(NULL) - tdebug.tv_sec);
  gettimeofday(&tdebug, NULL);
#endif

#ifdef NTOPNG_PRO
  if(host_pools)
    host_pools->updateStats(&tv);
#endif

  if(!ts_ring && TimeseriesRing::isRingEnabled(ntop->getPrefs()))
    ts_ring = new TimeseriesRing(this);

  if(ts_ring && ts_ring->isTimeToInsert()) {
    NetworkInterfaceTsPoint *pt = new NetworkInterfaceTsPoint();
    makeTsPoint(pt);

    /* Ownership of the point is passed to the ring */
    ts_ring->insert(pt, tv.tv_sec);
  }

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Timeseries update took %d seconds", time(NULL) - tdebug.tv_sec);
  gettimeofday(&tdebug, NULL);
#endif

  if((!read_from_pcap_dump()) &&
      (time(NULL) - tv.tv_sec) > ntop->getPrefs()->get_housekeeping_frequency())
    slow_stats_update = true;
  else
    slow_stats_update = false;
}

/* **************************************************** */

struct update_host_pool_l7policy {
  bool update_pool_id;
  bool update_l7policy;
};

static bool update_host_host_pool_l7policy(GenericHashEntry *node, void *user_data, bool *matched) {
  Host *h = (Host*)node;
  update_host_pool_l7policy *up = (update_host_pool_l7policy*)user_data;
#ifdef HOST_POOLS_DEBUG
  char buf[128];
  u_int16_t cur_pool_id = h->get_host_pool();
#endif

  *matched = true;

  if(up->update_pool_id)
    h->updateHostPool(false /* Not inline with traffic processing */);

#ifdef NTOPNG_PRO
  if(up->update_l7policy)
    h->resetBlockedTrafficStatus();
#endif

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Going to refresh pool for %s "
			       "[refresh pool id: %i] "
			       "[refresh l7policy: %i] "
			       "[host pool id before refresh: %i] "
			       "[host pool id after refresh: %i] ",
			       h->get_ip()->print(buf, sizeof(buf)),
			       up->update_pool_id ? 1 : 0,
			       up->update_l7policy ? 1 : 0,
			       cur_pool_id,
			       h->get_host_pool());
#endif

  return(false); /* false = keep on walking */
}

static bool update_l2_device_host_pool(GenericHashEntry *node, void *user_data, bool *matched) {
  Mac *m = (Mac*)node;

#ifdef HOST_POOLS_DEBUG
  u_int16_t cur_pool_id = m->get_host_pool();
#endif

  *matched = true;
  m->updateHostPool(false /* Not inline with traffic processing */);

#ifdef HOST_POOLS_DEBUG
  char buf[24];
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Going to refresh pool for %s "
			       "[host pool id before refresh: %i] "
			       "[host pool id after refresh: %i] ",
			       Utils::formatMac(m->get_mac(), buf, sizeof(buf)),
			       cur_pool_id,
			       m->get_host_pool());
#endif

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::refreshHostPools() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(isView()) return;

  struct update_host_pool_l7policy update_host;
  update_host.update_pool_id = true;
  update_host.update_l7policy = false;

#ifdef NTOPNG_PRO
  if(is_bridge_interface() && getL7Policer()) {
    /*
      Every pool is associated with a set of L7 rules
      so a refresh must be triggered to seal this association
    */

    getL7Policer()->refreshL7Rules();

    /*
      Must refresh host l7policies as a change in the host pool id
      may determine an l7policy change for that host
    */
    update_host.update_l7policy = true;
  }
#endif

  hosts_hash->walk(&begin_slot, walk_all, update_host_host_pool_l7policy, &update_host);
  begin_slot = 0;
  macs_hash->walk(&begin_slot, walk_all, update_l2_device_host_pool, NULL);

#ifdef HAVE_NEDGE
  if(update_host.update_l7policy)
    updateFlowsL7Policy();
#endif
}

/* **************************************************** */

#ifdef HAVE_NEDGE

static bool update_flow_l7_policy(GenericHashEntry *node, void *user_data, bool *matched) {
  Flow *f = (Flow*)node;

  *matched = true;
  f->updateFlowShapers();
  return(false); /* false = keep on walking */
}


/* **************************************************** */

void NetworkInterface::updateHostsL7Policy(u_int16_t host_pool_id) {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(isView()) return;

  struct update_host_pool_l7policy update_host;
  update_host.update_pool_id = false;
  update_host.update_l7policy = true;

  /* Pool id didn't change here so there's no need to walk on the macs
   as policies are set on the hosts */
  hosts_hash->walk(&begin_slot, walk_all,
		   update_host_host_pool_l7policy, &update_host);
}

/* **************************************************** */

void NetworkInterface::updateFlowsL7Policy() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(isView()) return;

  flows_hash->walk(&begin_slot, walk_all, update_flow_l7_policy, NULL);
}

/* **************************************************** */

struct resetPoolsStatsData {
  struct tm *now;
  u_int16_t pool_filter;
};

static bool flow_recheck_quota_walker(GenericHashEntry *flow, void *user_data, bool *matched) {
  Flow *f = (Flow*)flow;
  struct tm *now = ((struct resetPoolsStatsData*)user_data)->now;

  *matched = true;
  f->recheckQuota(now);

  return(false); /* false = keep on walking */
}

static bool host_reset_quotas(GenericHashEntry *host, void *user_data, bool *matched) {
  Host *h = (Host*)host;
  u_int16_t pool_filter = ((struct resetPoolsStatsData*)user_data)->pool_filter;

  if((pool_filter == (u_int16_t)-1) || (h->get_host_pool() == pool_filter)) {
    *matched = true;
    h->resetQuotaStats();
    h->resetBlockedTrafficStatus();
  }

  return(false); /* false = keep on walking */
}

#endif

/* **************************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::resetPoolsStats(u_int16_t pool_filter) {
  struct tm now;
  time_t t_now = time(NULL);
  localtime_r(&t_now, &now);

  if(host_pools) {
    disablePurge(true);

    host_pools->resetPoolsStats(pool_filter);

#ifdef HAVE_NEDGE
    u_int32_t begin_slot = 0;
    bool walk_all = true;
    struct resetPoolsStatsData data;

    data.pool_filter = pool_filter;
    data.now = &now;

    walker(&begin_slot, walk_all,  walker_hosts, host_reset_quotas, &data);
    begin_slot = 0;
    walker(&begin_slot, walk_all,  walker_flows, flow_recheck_quota_walker, &data);
#endif

    enablePurge(true);
  }
}

#endif

/* **************************************************** */

struct host_find_info {
  char *host_to_find;
  u_int16_t vlan_id;
  Host *h;
};

/* **************************************************** */

struct as_find_info {
  u_int32_t asn;
  AutonomousSystem *as;
};

/* **************************************************** */

struct vlan_find_info {
  u_int16_t vlan_id;
  Vlan *vl;
};

/* **************************************************** */

struct mac_find_info {
  u_int8_t mac[6];
  u_int16_t vlan_id;
  Mac *m;
  DeviceType dtype;
};

/* **************************************************** */

struct arp_stats_element_find_info {
  u_int8_t src_mac[6];
  u_int8_t dst_mac[6];
  ArpStatsMatrixElement *elem;
};

/* **************************************************** */

static bool find_host_by_name(GenericHashEntry *h, void *user_data, bool *matched) {
  struct host_find_info *info = (struct host_find_info*)user_data;
  Host *host                  = (Host*)h;
  char ip_buf[32], name_buf[96];
  name_buf[0] = '\0';


#ifdef DEBUG
  char buf[64];
  ntop->getTrace()->traceEvent(TRACE_WARNING, "[%s][%s][%s]",
			       host->get_ip() ? host->get_ip()->print(buf, sizeof(buf)) : "",
			       host->get_name(), info->host_to_find);
#endif

  if((info->h == NULL) && (host->get_vlan_id() == info->vlan_id)) {
    host->get_name(name_buf, sizeof(name_buf), false);

    if(strlen(name_buf) == 0 && host->get_ip()) {
      char *ipaddr = host->get_ip()->print(ip_buf, sizeof(ip_buf));
      int rc = ntop->getRedis()->getAddress(ipaddr, name_buf, sizeof(name_buf),
					    false /* Don't resolve it if not known */);

      if(rc == 0 /* found */ && strcmp(ipaddr, name_buf))
	host->setResolvedName(name_buf);
      else
	name_buf[0] = '\0';
    }

    if(!strcmp(name_buf, info->host_to_find)) {
      info->h = host;
      *matched = true;
      return(true); /* found */
    }
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool find_mac_by_name(GenericHashEntry *h, void *user_data, bool *matched) {
  struct mac_find_info *info = (struct mac_find_info*)user_data;
  Mac *m = (Mac*)h;

  if((info->m == NULL) && (!memcmp(info->mac, m->get_mac(), 6))) {
    info->m = m;
    *matched = true;

    return(true); /* found */
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool find_as_by_asn(GenericHashEntry *he, void *user_data, bool *matched) {
  struct as_find_info *info = (struct as_find_info*)user_data;
  AutonomousSystem *as = (AutonomousSystem*)he;

  if((info->as == NULL) && info->asn == as->get_asn()) {
    info->as = as;
    *matched = true;
    return(true); /* found */
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool find_vlan_by_vlan_id(GenericHashEntry *he, void *user_data, bool *matched) {
  struct vlan_find_info *info = (struct vlan_find_info*)user_data;
  Vlan *vl = (Vlan*)he;

  if((info->vl == NULL) && info->vlan_id == vl->get_vlan_id()) {
    info->vl = vl;
    *matched = true;
    return(true); /* found */
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

bool NetworkInterface::restoreHost(char *host_ip, u_int16_t vlan_id) {
  Host *h;
  int16_t local_network_id;
  IpAddress ipa;

  ipa.set(host_ip);

  if(ipa.isLocalHost(&local_network_id))
    h = new LocalHost(this, host_ip, vlan_id);
  else
    h = new RemoteHost(this, host_ip, vlan_id);

  if(!h) return(false);

  if(!hosts_hash->add(h)) {
    //ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
    delete h;
    return(false);
  }

  h->postHashAdd();
  return(true);
}

/* **************************************************** */

Host* NetworkInterface::getHost(char *host_ip, u_int16_t vlan_id) {
  struct in_addr  a4;
  struct in6_addr a6;
  Host *h = NULL;

  if(!host_ip) return(NULL);

  /* Check if address is invalid */
  if((inet_pton(AF_INET, (const char*)host_ip, &a4) == 0)
     && (inet_pton(AF_INET6, (const char*)host_ip, &a6) == 0)) {
    /* Looks like a symbolic name */
    struct host_find_info info;
    u_int32_t begin_slot = 0;
    bool walk_all = true;

    memset(&info, 0, sizeof(info));
    info.host_to_find = host_ip, info.vlan_id = vlan_id;
    walker(&begin_slot, walk_all,  walker_hosts, find_host_by_name, (void*)&info);

    h = info.h;
  } else {
    IpAddress *ip = new IpAddress();

    if(ip) {
      ip->set(host_ip);

      h = hosts_hash->get(vlan_id, ip);

      delete ip;
    }
  }

  return(h);
}


/* **************************************************** */

Host* NetworkInterface::getHost(IpAddress * const host_ip, u_int16_t vlan_id) const {
  return(hosts_hash->get(vlan_id, host_ip));
}

/* **************************************************** */

#ifdef NTOPNG_PRO

#ifndef HAVE_NEDGE
static bool update_flow_profile(GenericHashEntry *h, void *user_data, bool *matched) {
  Flow *flow = (Flow*)h;

  flow->updateProfile();
  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::updateFlowProfiles() {
  if(isView()) return;

  if(ntop->getPro()->has_valid_license()) {
    FlowProfiles *newP;
    u_int32_t begin_slot = 0;
    bool walk_all = true;

    if(shadow_flow_profiles) {
      delete shadow_flow_profiles;
      shadow_flow_profiles = NULL;
    }

    flow_profiles->dumpCounters();
    shadow_flow_profiles = flow_profiles, newP = new FlowProfiles(id);

    newP->loadProfiles(); /* and reload */
    flow_profiles = newP; /* Overwrite the current profiles */

    flows_hash->walk(&begin_slot, walk_all, update_flow_profile, NULL);
  }
}
#endif

#endif

/* **************************************************** */

bool NetworkInterface::getHostInfo(lua_State* vm,
				   AddressTree *allowed_hosts,
				   char *host_ip, u_int16_t vlan_id) {
  Host *h;
  bool ret;

  disablePurge(false);

  h = findHostByIP(allowed_hosts, host_ip, vlan_id);

  if(h) {
    h->lua(vm, allowed_hosts, true, true, true, false);
    ret = true;
  } else
    ret = false;

  enablePurge(false);

  return ret;
}

/* **************************************************** */

void NetworkInterface::checkReloadHostsBroadcastDomain() {
  time_t bcast_domains_last_update = bcast_domains->getLastUpdate();

  if(hosts_bcast_domain_last_update < bcast_domains_last_update)
    reload_hosts_bcast_domain = true,
      hosts_bcast_domain_last_update = bcast_domains_last_update;
  else if(reload_hosts_bcast_domain)
    reload_hosts_bcast_domain = false;
}

/* **************************************************** */

bool NetworkInterface::checkPointHostCounters(lua_State* vm, u_int8_t checkpoint_id,
					      char *host_ip, u_int16_t vlan_id,
					      DetailsLevel details_level) {
  Host *h;
  bool ret = false;

  if(host_ip && (h = getHost(host_ip, vlan_id)))
    ret = h->checkpoint(vm, this, checkpoint_id, details_level);

  return ret;
}

/* **************************************************** */

bool NetworkInterface::checkPointNetworkCounters(lua_State* vm, u_int8_t checkpoint_id,
					      u_int8_t network_id,
					      DetailsLevel details_level) {
  NetworkStats *stats = getNetworkStats(network_id);

  if (stats == NULL)
    return false;

  return stats->checkpoint(vm, this, checkpoint_id, details_level);
}

/* **************************************************** */

bool NetworkInterface::checkPointHostTalker(lua_State* vm, char *host_ip, u_int16_t vlan_id, bool saveCheckpoint) {
  Host *h;
  bool ret = false;

  if(host_ip && (h = getHost(host_ip, vlan_id))) {
    h->checkPointHostTalker(vm, saveCheckpoint);
    ret = true;
  }

  return ret;
}

/* **************************************************** */

bool NetworkInterface::serializeCheckpoint(json_object *my_object, DetailsLevel details_level) {
  json_object *inner;

  if((inner = json_object_new_object()) == NULL) return false;

  json_object_object_add(my_object, "seen.last", json_object_new_int64(getTimeLastPktRcvd()));
  json_object_object_add(my_object, "ndpiStats", ndpiStats.getJSONObjectForCheckpoint(this));
  json_object_object_add(my_object, "local_hosts", json_object_new_int64(getNumLocalHosts()));
  json_object_object_add(inner, "bytes", json_object_new_int64(getNumBytes()));
  json_object_object_add(inner, "packets", json_object_new_int64(getNumPackets()));
  json_object_object_add(my_object, "stats", inner);

  return true;
}

/* **************************************************** */

Host* NetworkInterface::findHostByIP(AddressTree *allowed_hosts,
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
  Mac *macValue;
  Vlan *vlanValue;
  AutonomousSystem *asValue;
  Country *countryVal;
  u_int64_t numericValue;
  char *stringValue;
  IpAddress *ipValue;
};

struct flowHostRetriever {
  /* Search criteria */
  AddressTree *allowed_hosts;
  Host *host;
  u_int8_t *mac, bridge_iface_idx;
  char *manufacturer;
  bool sourceMacsOnly, dhcpHostsOnly;
  char *country;
  int ndpi_proto;             /* Not used in flow_search_walker */
  TrafficType traffic_type;   /* Not used in flow_search_walker */
  sortField sorter;
  TcpFlowStateFilter tcp_flow_state_filter;
  LocationPolicy location;    /* Not used in flow_search_walker */
  u_int8_t ipVersionFilter;   /* Not used in flow_search_walker */
  bool filteredHosts;         /* Not used in flow_search_walker */
  bool blacklistedHosts;     /* Not used in flow_search_walker */
  bool anomalousOnly;        /* Not used in flow_search_walker */
  bool dhcpOnly;             /* Not used in flow_search_walker */
  bool hideTopHidden;        /* Not used in flow_search_walker */
  u_int16_t vlan_id;
  char *osFilter;
  u_int32_t asnFilter;
  u_int32_t uidFilter;
  u_int32_t pidFilter;
  int16_t networkFilter;
  u_int16_t poolFilter;
  u_int8_t devtypeFilter;
  u_int8_t locationFilter;

  /* Return values */
  u_int32_t maxNumEntries, actNumEntries;
  struct flowHostRetrieveList *elems;

  /* Paginator */
  Paginator *pag;
};

/* **************************************************** */

static bool flow_matches(Flow *f, struct flowHostRetriever *retriever) {
  int ndpi_proto, ndpi_cat;
  u_int16_t port;
  int16_t local_network_id;
  u_int16_t vlan_id = 0, pool_filter;
  u_int8_t ip_version;
  u_int8_t *mac_filter;
  LocationPolicy client_policy;
  LocationPolicy server_policy;
  TcpFlowStateFilter tcp_flow_state_filter;
  bool unicast, unidirectional, alerted_flows;
  u_int32_t asn_filter;
  u_int32_t uid_filter;
  u_int32_t pid_filter;
  u_int32_t deviceIP;
  u_int16_t inIndex, outIndex;
#ifdef HAVE_NEDGE
  bool filtered_flows;
#endif

  if(f && (!f->idle())) {
    if(retriever->host
       && (retriever->host != f->get_cli_host())
       && (retriever->host != f->get_srv_host()))
      return(false);

    if(retriever->pag
       && retriever->pag->l7protoFilter(&ndpi_proto)
       && ((ndpi_proto == NDPI_PROTOCOL_UNKNOWN
	    && (f->get_detected_protocol().app_protocol != ndpi_proto
		|| f->get_detected_protocol().master_protocol != ndpi_proto))
	   ||
	   (ndpi_proto != NDPI_PROTOCOL_UNKNOWN
	    && (f->get_detected_protocol().app_protocol != ndpi_proto
		&& f->get_detected_protocol().master_protocol != ndpi_proto))))
      return(false);

    if(retriever->pag
       && retriever->pag->l7categoryFilter(&ndpi_cat)
       && f->get_protocol_category() != ndpi_cat)
      return(false);

    if(retriever->pag
       && retriever->pag->tcpFlowStateFilter(&tcp_flow_state_filter)
       && ((f->get_protocol() != IPPROTO_TCP)
	   || (tcp_flow_state_filter == tcp_flow_state_established && !f->isTCPEstablished())
	   || (tcp_flow_state_filter == tcp_flow_state_connecting && !f->isTCPConnecting())
	   || (tcp_flow_state_filter == tcp_flow_state_closed && !f->isTCPClosed())
	   || (tcp_flow_state_filter == tcp_flow_state_reset && !f->isTCPReset())))
      return(false);

    if(retriever->pag
       && retriever->pag->ipVersion(&ip_version)
       && (((ip_version == 4) && (f->get_cli_host() && !f->get_cli_host()->get_ip()->isIPv4()))
	   || ((ip_version == 6) && (f->get_cli_host() && !f->get_cli_host()->get_ip()->isIPv6()))))
      return(false);

    if(retriever->pag
       && retriever->pag->deviceIpFilter(&deviceIP)) {
	if(f->getFlowDeviceIp() != deviceIP
	   || (retriever->pag->inIndexFilter(&inIndex) && f->getFlowDeviceInIndex() != inIndex)
	   || (retriever->pag->outIndexFilter(&outIndex) && f->getFlowDeviceOutIndex() != outIndex))
	  return(false);
    }

    if(retriever->pag
       && retriever->pag->asnFilter(&asn_filter)
       && f->get_cli_host() && f->get_srv_host()
       && f->get_cli_host()->get_asn() != asn_filter
       && f->get_srv_host()->get_asn() != asn_filter)
      return(false);

    if(retriever->pag
       && retriever->pag->uidFilter(&uid_filter)
       && f->get_uid(true  /* client uid */) != uid_filter
       && f->get_uid(false /* server uid */) != uid_filter)
      return(false);

    if(retriever->pag
       && retriever->pag->pidFilter(&pid_filter)
       && f->get_pid(true  /* client pid */) != pid_filter
       && f->get_pid(false /* server pid */) != pid_filter)
      return(false);

    if(retriever->pag
       && retriever->pag->portFilter(&port)
       && f->get_cli_port() != port
       && f->get_srv_port() != port)
      return(false);

    if(retriever->pag
       && retriever->pag->localNetworkFilter(&local_network_id)
       && f->get_cli_host() && f->get_srv_host()
       && f->get_cli_host()->get_local_network_id() != local_network_id
       && f->get_srv_host()->get_local_network_id() != local_network_id)
      return(false);

    if(retriever->pag
       && retriever->pag->vlanIdFilter(&vlan_id)
       && f->get_vlan_id() != vlan_id)
      return(false);

    if(retriever->pag
       && retriever->pag->clientMode(&client_policy)
       && f->get_cli_host()
       && (((client_policy == location_local_only) && (!f->get_cli_host()->isLocalHost()))
	   || ((client_policy == location_remote_only) && (f->get_cli_host()->isLocalHost()))))
      return(false);

    if(retriever->pag
       && retriever->pag->serverMode(&server_policy)
       && (((server_policy == location_local_only) && (!f->get_srv_host()->isLocalHost()))
	   || ((server_policy == location_remote_only) && (f->get_srv_host()->isLocalHost()))))
      return(false);

    if(retriever->pag
       && retriever->pag->alertedFlows(&alerted_flows)
       && ((alerted_flows && f->getFlowStatus() == status_normal)
	   || (!alerted_flows && f->getFlowStatus() != status_normal)))
      return(false);

#ifdef HAVE_NEDGE
    if(retriever->pag
       && retriever->pag->filteredFlows(&filtered_flows)
       && ((filtered_flows && f->isPassVerdict())
       || (!filtered_flows && !f->isPassVerdict())))
      return(false);
#endif

    if(retriever->pag
       && retriever->pag->unidirectionalTraffic(&unidirectional)
       && ((unidirectional && (f->get_packets() > 0) && (f->get_packets_cli2srv() > 0) && (f->get_packets_srv2cli() > 0))
	   || (!unidirectional && (f->get_packets() > 0) && ((f->get_packets_cli2srv() == 0) || (f->get_packets_srv2cli() == 0)))))
      return(false);

    /* Unicast: at least one between client and server is unicast address */
    if(retriever->pag
       && retriever->pag->unicastTraffic(&unicast)
       && ((unicast && ((f->get_cli_host() && (f->get_cli_host()->get_ip()->isMulticastAddress() || f->get_cli_host()->get_ip()->isBroadcastAddress()))
			|| (f->get_srv_host() && (f->get_srv_host()->get_ip()->isMulticastAddress() || f->get_srv_host()->get_ip()->isBroadcastAddress()))))
	   || (!unicast && ((f->get_cli_host() && (!f->get_cli_host()->get_ip()->isMulticastAddress() && !f->get_cli_host()->get_ip()->isBroadcastAddress()))
			    && (f->get_srv_host() && (!f->get_srv_host()->get_ip()->isMulticastAddress() && !f->get_srv_host()->get_ip()->isBroadcastAddress()))))))
      return(false);

    /* Pool filter */
    if(retriever->pag
       && retriever->pag->poolFilter(&pool_filter)
       && !((f->get_cli_host() && f->get_cli_host()->get_host_pool() == pool_filter)
	      || (f->get_srv_host() && f->get_srv_host()->get_host_pool() == pool_filter)))
      return(false);

    /* Mac filter - NOTE: must stay below the vlan_id filter */
    if(retriever->pag
       && retriever->pag->macFilter(&mac_filter)
       && !((f->get_cli_host() && f->get_cli_host()->getMac() && f->get_cli_host()->getMac()->equal(mac_filter))
	      || (f->get_srv_host() && f->get_srv_host()->getMac() && f->get_srv_host()->getMac()->equal(mac_filter))))
      return(false);

    if(f->match(retriever->allowed_hosts))
      return(true); /* match */
  }

  return(false);
}

/* **************************************************** */

static bool flow_search_walker(GenericHashEntry *h, void *user_data, bool *matched) {
  struct flowHostRetriever *retriever = (struct flowHostRetriever*)user_data;
  Flow *f = (Flow*)h;
  char *flow_info;

  if(retriever->actNumEntries >= retriever->maxNumEntries)
    return(true); /* Limit reached - stop iterating */

  if(flow_matches(f, retriever)) {
    retriever->elems[retriever->actNumEntries].flow = f;

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
	retriever->elems[retriever->actNumEntries++].numericValue = f->get_detected_protocol().app_protocol;
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
	flow_info = f->getFlowInfo();
	retriever->elems[retriever->actNumEntries++].stringValue = flow_info ? flow_info : (char*)"";
	break;
      default:
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", retriever->sorter);
	break;
    }

    *matched = true;
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool host_search_walker(GenericHashEntry *he, void *user_data, bool *matched) {
  char buf[64];
  u_int8_t network_prefix = 0;
  IpAddress *ip_addr = NULL;
  struct flowHostRetriever *r = (struct flowHostRetriever*)user_data;
  Host *h = (Host*)he;

  if(r->actNumEntries >= r->maxNumEntries)
    return(true); /* Limit reached */

  if(!h || h->idle() || !h->match(r->allowed_hosts))
    return(false);

  if((r->location == location_local_only            && !h->isLocalHost())                 ||
     (r->location == location_remote_only           && h->isLocalHost())                  ||
     (r->location == location_broadcast_domain_only && !h->isBroadcastDomainHost())       ||
     ((r->vlan_id != ((u_int16_t)-1)) && (r->vlan_id != h->get_vlan_id()))                ||
     ((r->ndpi_proto != -1) && (h->get_ndpi_stats()->getProtoBytes(r->ndpi_proto) == 0))  ||
     ((r->asnFilter != (u_int32_t)-1)     && (r->asnFilter       != h->get_asn()))        ||
     ((r->networkFilter != -2) && (r->networkFilter != h->get_local_network_id()))        ||
     (r->mac           && ((!h->getMac()) || (!h->getMac()->equal(r->mac))))              ||
     ((r->poolFilter != (u_int16_t)-1)    && (r->poolFilter    != h->get_host_pool()))    ||
     (r->country  && strlen(r->country)  && strcmp(h->get_country(buf, sizeof(buf)), r->country)) ||
     (r->osFilter && strlen(r->osFilter) && strcmp(h->get_os(buf, sizeof(buf)), r->osFilter))     ||
     (r->blacklistedHosts && !h->isBlacklisted())     ||
     (r->anomalousOnly && !h->hasAnomalies())         ||
     (r->dhcpOnly && !h->isDhcpHost())                ||
     (r->hideTopHidden && h->isHiddenFromTop())       ||
     (r->traffic_type == traffic_type_one_way && !h->isOneWayTraffic())       ||
     (r->traffic_type == traffic_type_bidirectional && h->isOneWayTraffic())  ||
     (r->dhcpHostsOnly && (!h->isDhcpHost())) ||
#ifdef NTOPNG_PRO
     (r->filteredHosts && !h->hasBlockedTraffic()) ||
#endif
     (r->ipVersionFilter && (((r->ipVersionFilter == 4) && (!h->get_ip()->isIPv4()))
			     || ((r->ipVersionFilter == 6) && (!h->get_ip()->isIPv6())))))
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
    r->elems[r->actNumEntries++].stringValue = strdup(h->get_visual_name(buf, sizeof(buf)));
    break;

  case column_country:
    r->elems[r->actNumEntries++].stringValue = strdup(h->get_country(buf, sizeof(buf)));
    break;

  case column_os:
    r->elems[r->actNumEntries++].stringValue = strdup(h->get_os(buf, sizeof(buf)));
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

  case column_num_flows:
    r->elems[r->actNumEntries++].numericValue = h->getNumActiveFlows();
    break;

  case column_num_dropped_flows:
    r->elems[r->actNumEntries++].numericValue = h->getNumDroppedFlows();
    break;

  case column_traffic:
    r->elems[r->actNumEntries++].numericValue = h->getNumBytes();
    break;

  case column_local_network_id:
    r->elems[r->actNumEntries++].numericValue = h->get_local_network_id();
    break;

  case column_local_network:
    ntop->getLocalNetworkIp(h->get_local_network_id(), &ip_addr, &network_prefix);
    r->elems[r->actNumEntries].ipValue = ip_addr;
    r->elems[r->actNumEntries++].numericValue = network_prefix;
    break;

  case column_mac:
    r->elems[r->actNumEntries++].numericValue = Utils::macaddr_int(h->get_mac());
    break;

  case column_pool_id:
    r->elems[r->actNumEntries++].numericValue = h->get_host_pool();
    break;

    /* Criteria */
  case column_traffic_sent:    r->elems[r->actNumEntries++].numericValue = h->getNumBytesSent(); break;
  case column_traffic_rcvd:    r->elems[r->actNumEntries++].numericValue = h->getNumBytesRcvd(); break;
  case column_traffic_unknown: r->elems[r->actNumEntries++].numericValue = h->get_ndpi_stats()->getProtoBytes(NDPI_PROTOCOL_UNKNOWN); break;
  case column_num_flows_as_client:  r->elems[r->actNumEntries++].numericValue = h->getNumOutgoingFlows(); break;
  case column_num_flows_as_server:  r->elems[r->actNumEntries++].numericValue = h->getNumIncomingFlows(); break;
  case column_total_num_anomalous_flows_as_client:  r->elems[r->actNumEntries++].numericValue = h->getTotalNumAnomalousOutgoingFlows(); break;
  case column_total_num_anomalous_flows_as_server:  r->elems[r->actNumEntries++].numericValue = h->getTotalNumAnomalousIncomingFlows(); break;
  case column_total_alerts:    r->elems[r->actNumEntries++].numericValue = h->getTotalAlerts(); break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
    break;
  }

  *matched = true;
  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool mac_search_walker(GenericHashEntry *he, void *user_data, bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever*)user_data;
  Mac *m = (Mac*)he;
  u_int16_t pool_value;
  bool pool_found;

  if(r->actNumEntries >= r->maxNumEntries)
    return(true); /* Limit reached */

  if(!m
     || m->idle()
     || (r->sourceMacsOnly && !m->isSourceMac())
     || ((r->devtypeFilter != (u_int8_t)-1) && (m->getDeviceType() != r->devtypeFilter))
     || ((r->locationFilter != (u_int8_t)-1) && (m->locate() != r->locationFilter))
     || ((r->poolFilter != (u_int16_t)-1) && (
        (((pool_found = m->getInterface()->getHostPools()->findMacPool(m, &pool_value)) == false /* unassigned */) && r->poolFilter != 0)
        || ((pool_found == true) && (pool_value != r->poolFilter))))
     || (r->manufacturer && strcmp(r->manufacturer, m->get_manufacturer() ? m->get_manufacturer() : "") != 0))
    return(false); /* false = keep on walking */

  r->elems[r->actNumEntries].macValue = m;

  switch(r->sorter) {
  case column_mac:
    r->elems[r->actNumEntries++].numericValue = Utils::macaddr_int(m->get_mac());
    break;

  case column_since:
    r->elems[r->actNumEntries++].numericValue = m->get_first_seen();
    break;

  case column_thpt:
    r->elems[r->actNumEntries++].numericValue = m->getBytesThpt();
    break;

  case column_traffic:
    r->elems[r->actNumEntries++].numericValue = m->getNumBytes();
    break;

  case column_num_hosts:
    r->elems[r->actNumEntries++].numericValue = m->getNumHosts();
    break;

  case column_manufacturer:
    r->elems[r->actNumEntries++].stringValue = m->get_manufacturer() ? (char*)m->get_manufacturer() : (char*)"zzz";
    break;

  case column_device_type:
    r->elems[r->actNumEntries++].numericValue = m->getDeviceType();
    break;

  case column_arp_total:
    r->elems[r->actNumEntries++].numericValue = m->getNumSentArp() + m->getNumRcvdArp();
    break;

  case column_arp_sent:
    r->elems[r->actNumEntries++].numericValue = m->getNumSentArp();
    break;

  case column_arp_rcvd:
    r->elems[r->actNumEntries++].numericValue = m->getNumRcvdArp();
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
    break;
  }

  *matched = true;
  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool as_search_walker(GenericHashEntry *he, void *user_data, bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever*)user_data;
  AutonomousSystem *as = (AutonomousSystem*)he;

  if(r->actNumEntries >= r->maxNumEntries)
    return(true); /* Limit reached */

  if(!as || as->idle())
    return(false); /* false = keep on walking */

  r->elems[r->actNumEntries].asValue = as;

  switch(r->sorter) {

  case column_asn:
    r->elems[r->actNumEntries++].numericValue = as->get_asn();
    break;

  case column_asname:
    r->elems[r->actNumEntries++].stringValue = as->get_asname() ? as->get_asname() : (char*)"zzz";
    break;

  case column_since:
    r->elems[r->actNumEntries++].numericValue = as->get_first_seen();
    break;

  case column_thpt:
    r->elems[r->actNumEntries++].numericValue = as->getBytesThpt();
    break;

  case column_traffic:
    r->elems[r->actNumEntries++].numericValue = as->getNumBytes();
    break;

  case column_num_hosts:
    r->elems[r->actNumEntries++].numericValue = as->getNumHosts();
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
    break;
  }

  *matched = true;
  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool country_search_walker(GenericHashEntry *he, void *user_data, bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever*)user_data;
  Country *country = (Country*)he;

  if(r->actNumEntries >= r->maxNumEntries)
    return(true); /* Limit reached */

  if(!country || country->idle())
    return(false); /* false = keep on walking */

  r->elems[r->actNumEntries].countryVal = country;

  /* Note: we don't have throughput information into the countries */
  switch(r->sorter) {

  case column_country:
    r->elems[r->actNumEntries++].stringValue = country->get_country_name();
    break;

  case column_since:
    r->elems[r->actNumEntries++].numericValue = country->get_first_seen();
    break;

  case column_num_hosts:
    r->elems[r->actNumEntries++].numericValue = country->getNumHosts();
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
    break;
  }

  *matched = true;
  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool vlan_search_walker(GenericHashEntry *he, void *user_data, bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever*)user_data;
  Vlan *vl = (Vlan*)he;

  if(r->actNumEntries >= r->maxNumEntries)
    return(true); /* Limit reached */

  if(!vl || vl->idle())
    return(false); /* false = keep on walking */

  r->elems[r->actNumEntries].vlanValue = vl;

  switch(r->sorter) {

  case column_vlan:
    r->elems[r->actNumEntries++].numericValue = vl->get_vlan_id();
    break;

  case column_since:
    r->elems[r->actNumEntries++].numericValue = vl->get_first_seen();
    break;

  case column_thpt:
    r->elems[r->actNumEntries++].numericValue = vl->getBytesThpt();
    break;

  case column_traffic:
    r->elems[r->actNumEntries++].numericValue = vl->getNumBytes();
    break;

  case column_num_hosts:
    r->elems[r->actNumEntries++].numericValue = vl->getNumHosts();
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
    break;
  }

  *matched = true;
  return(false); /* false = keep on walking */
}

/* **************************************************** */

int hostSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList*)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList*)_b;

  return(a->hostValue->get_ip()->compare(b->hostValue->get_ip()));
}

int ipNetworkSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList*)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList*)_b;
  int rv;

  if(!a || !b || !a->ipValue || !b->ipValue)
    return(true);

  /* Compare network address first */
  rv = a->ipValue->compare(b->ipValue);
  if(rv != 0) return rv;

  /* If the address matches, compare netmasks */
  if(a->numericValue < b->numericValue)      return(-1);
  else if(a->numericValue > b->numericValue) return(1);
  else return(0);
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

void NetworkInterface::disablePurge(bool on_flows) {
  if(!isView()) {
    if(on_flows)
      flows_hash->disablePurge();
    else {
      hosts_hash->disablePurge();
      ases_hash->disablePurge();
      countries_hash->disablePurge();
      vlans_hash->disablePurge();
      macs_hash->disablePurge();
    }
  } else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if(on_flows)
	subInterfaces[s]->get_flows_hash()->disablePurge();
      else {
	subInterfaces[s]->get_hosts_hash()->disablePurge();
	subInterfaces[s]->get_ases_hash()->disablePurge();
	subInterfaces[s]->get_countries_hash()->disablePurge();
	subInterfaces[s]->get_vlans_hash()->disablePurge();
	subInterfaces[s]->get_macs_hash()->disablePurge();
      }
    }
  }
}

/* **************************************************** */

void NetworkInterface::enablePurge(bool on_flows) {
  if(!isView()) {
    if(on_flows)
      flows_hash->enablePurge();
    else {
      hosts_hash->enablePurge();
      ases_hash->enablePurge();
      countries_hash->enablePurge();
      vlans_hash->enablePurge();
      macs_hash->enablePurge();
    }
  } else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if(on_flows)
	subInterfaces[s]->get_flows_hash()->enablePurge();
      else {
	subInterfaces[s]->get_hosts_hash()->enablePurge();
	subInterfaces[s]->get_ases_hash()->enablePurge();
	subInterfaces[s]->get_countries_hash()->enablePurge();
	subInterfaces[s]->get_vlans_hash()->enablePurge();
	subInterfaces[s]->get_macs_hash()->enablePurge();
      }
    }
  }
}

/* **************************************************** */

int NetworkInterface::sortFlows(u_int32_t *begin_slot,
				bool walk_all,
				struct flowHostRetriever *retriever,
				AddressTree *allowed_hosts,
				Host *host,
				Paginator *p,
				const char *sortColumn) {
  int (*sorter)(const void *_a, const void *_b);

  if(retriever == NULL)
    return -1;

  retriever->pag = p;
  retriever->host = host, retriever->location = location_all;
  retriever->ndpi_proto = -1;
  retriever->actNumEntries = 0, retriever->maxNumEntries = getFlowsHashSize(), retriever->allowed_hosts = allowed_hosts;
  retriever->elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if(retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if(!strcmp(sortColumn, "column_client")) retriever->sorter = column_client, sorter = hostSorter;
  else if(!strcmp(sortColumn, "column_vlan")) retriever->sorter = column_vlan, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_server")) retriever->sorter = column_server, sorter = hostSorter;
  else if(!strcmp(sortColumn, "column_proto_l4")) retriever->sorter = column_proto_l4, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_ndpi")) retriever->sorter = column_ndpi, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_duration")) retriever->sorter = column_duration, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt")) retriever->sorter = column_thpt, sorter = numericSorter;
  else if((!strcmp(sortColumn, "column_bytes")) || (!strcmp(sortColumn, "column_") /* default */)) retriever->sorter = column_bytes, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_info")) retriever->sorter = column_info, sorter = stringSorter;
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn);
    retriever->sorter = column_bytes, sorter = numericSorter;
  }

  // make sure the caller has disabled the purge!!
  walker(begin_slot, walk_all,  walker_flows, flow_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getFlows(lua_State* vm,
			       AddressTree *allowed_hosts,
			       Host *host,
			       Paginator *p) {
  struct flowHostRetriever retriever;
  char sortColumn[32];
  DetailsLevel highDetails;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(p == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to return results with a NULL paginator");
    return(-1);
  }

  LocationPolicy client_mode = location_all;
  LocationPolicy server_mode = location_all;
  p->clientMode(&client_mode);
  p->serverMode(&server_mode);
  bool local_hosts = ((client_mode == location_local_only) && (server_mode == location_local_only));

  snprintf(sortColumn, sizeof(sortColumn), "%s", p->sortColumn());
  if(! p->getDetailsLevel(&highDetails))
    highDetails = p->detailedResults() ? details_high : (local_hosts || (p && p->maxHits() != CONST_MAX_NUM_HITS)) ? details_high : details_normal;

  disablePurge(true);

  if(sortFlows(&begin_slot, walk_all, &retriever, allowed_hosts, host, p, sortColumn) < 0) {
    enablePurge(true);
    return -1;
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numFlows", retriever.actNumEntries);

  lua_newtable(vm);

  if(p->a2zSortOrder()) {
    for(int i=p->toSkip(), num=0; i<(int)retriever.actNumEntries; i++) {
      lua_newtable(vm);

      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);

      lua_pushinteger(vm, num + 1);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if(++num >= (int)p->maxHits()) break;
    }
  } else {
    for(int i=(retriever.actNumEntries-1-p->toSkip()), num=0; i>=0; i--) {
      lua_newtable(vm);

      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);

      lua_pushinteger(vm, num + 1);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if(++num >= (int)p->maxHits()) break;
    }
  }

  lua_pushstring(vm, "flows");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  enablePurge(true);

  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getFlowsGroup(lua_State* vm,
			       AddressTree *allowed_hosts,
			       Paginator *p,
			       const char *groupColumn) {
  struct flowHostRetriever retriever;
  FlowGrouper *gper;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(p == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to return results with a NULL paginator");
    return(-1);
  }

  disablePurge(true);

  if(sortFlows(&begin_slot, walk_all, &retriever, allowed_hosts, NULL, p, groupColumn) < 0) {
    enablePurge(true);
    return -1;
  }

  // build a new grouper that will help in aggregating stats
  if((gper = new(std::nothrow) FlowGrouper(retriever.sorter)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to allocate memory for a Grouper.");
    enablePurge(true);
    return -1;
  }

  lua_newtable(vm);

  for(int i=0; i<(int)retriever.actNumEntries; i++) {
    Flow *flow = retriever.elems[i].flow;

    if(flow) {
      if(gper->inGroup(flow) == false) {
	if(gper->getNumEntries() > 0)
	  gper->lua(vm);
	gper->newGroup(flow);
      }

      gper->incStats(flow);
    }
  }

  if(gper->getNumEntries() > 0)
    gper->lua(vm);

  delete gper;
  enablePurge(true);

  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

static bool flow_drop_walker(GenericHashEntry *h, void *user_data, bool *matched) {
  struct flowHostRetriever *retriever = (struct flowHostRetriever*)user_data;
  Flow *f = (Flow*)h;

  if(flow_matches(f, retriever)) {
    f->setDropVerdict();
    *matched = true;
  }

  return(false); /* Keep on walking */
}

/* **************************************************** */

int NetworkInterface::dropFlowsTraffic(AddressTree *allowed_hosts, Paginator *p) {
  struct flowHostRetriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&retriever, 0, sizeof(retriever));

  retriever.allowed_hosts = allowed_hosts;
  retriever.pag = p;

  disablePurge(true);

  walker(&begin_slot, walk_all,  walker_flows, flow_drop_walker, (void*)&retriever);

  enablePurge(true);

  return(0);
}

/* **************************************************** */

int NetworkInterface::sortHosts(u_int32_t *begin_slot,
				bool walk_all,
				struct flowHostRetriever *retriever,
				u_int8_t bridge_iface_idx,
				AddressTree *allowed_hosts,
				bool host_details,
				LocationPolicy location,
				char *countryFilter, char *mac_filter,
				u_int16_t vlan_id, char *osFilter,
				u_int32_t asnFilter, int16_t networkFilter,
				u_int16_t pool_filter, bool filtered_hosts,
				bool blacklisted_hosts, bool hide_top_hidden,
				bool anomalousOnly, bool dhcpOnly,
				u_int8_t ipver_filter, int proto_filter,
				TrafficType traffic_type_filter,
				char *sortColumn) {
  u_int32_t maxHits;
  u_int8_t macAddr[6];
  int (*sorter)(const void *_a, const void *_b);

  if(retriever == NULL)
    return -1;

  maxHits = getHostsHashSize();
  if((maxHits > CONST_MAX_NUM_HITS) || (maxHits == 0))
    maxHits = CONST_MAX_NUM_HITS;

  memset(retriever, 0, sizeof(struct flowHostRetriever));

  if(mac_filter) {
    Utils::parseMac(macAddr, mac_filter);
    retriever->mac = macAddr;
  } else {
    retriever->mac = NULL;
  }

  retriever->allowed_hosts = allowed_hosts, retriever->location = location,
    retriever->country = countryFilter, retriever->vlan_id = vlan_id,
    retriever->osFilter = osFilter, retriever->asnFilter = asnFilter,
    retriever->networkFilter = networkFilter, retriever->actNumEntries = 0,
    retriever->poolFilter = pool_filter, retriever->bridge_iface_idx = 0,
    retriever->ipVersionFilter = ipver_filter,
    retriever->filteredHosts = filtered_hosts,
    retriever->blacklistedHosts = blacklisted_hosts,
    retriever->anomalousOnly = anomalousOnly,
    retriever->dhcpOnly = dhcpOnly,
    retriever->hideTopHidden = hide_top_hidden,
    retriever->ndpi_proto = proto_filter,
    retriever->traffic_type = traffic_type_filter,
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
  else if(!strcmp(sortColumn, "column_num_flows")) retriever->sorter = column_num_flows, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_num_dropped_flows")) retriever->sorter = column_num_dropped_flows, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic")) retriever->sorter = column_traffic, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_local_network_id")) retriever->sorter = column_local_network_id, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_local_network")) retriever->sorter = column_local_network, sorter = ipNetworkSorter;
  else if(!strcmp(sortColumn, "column_mac")) retriever->sorter = column_mac, sorter = numericSorter;
  /* criteria (datatype sortField in ntop_typedefs.h / see also host_search_walker:NetworkInterface.cpp) */
  else if(!strcmp(sortColumn, "column_traffic_sent"))    retriever->sorter = column_traffic_sent, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic_rcvd"))    retriever->sorter = column_traffic_rcvd, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic_unknown")) retriever->sorter = column_traffic_unknown, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_num_flows_as_client")) retriever->sorter = column_num_flows_as_client, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_num_flows_as_server")) retriever->sorter = column_num_flows_as_server, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_total_num_anomalous_flows_as_client")) retriever->sorter = column_total_num_anomalous_flows_as_client, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_total_num_anomalous_flows_as_server")) retriever->sorter = column_total_num_anomalous_flows_as_server, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_total_alerts")) retriever->sorter = column_total_alerts, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_pool_id")) retriever->sorter = column_pool_id, sorter = numericSorter;
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn);
    retriever->sorter = column_traffic, sorter = numericSorter;
  }

  // make sure the caller has disabled the purge!!
  walker(begin_slot, walk_all, walker_hosts, host_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortMacs(u_int32_t *begin_slot,
			       bool walk_all,
			       struct flowHostRetriever *retriever,
			       u_int8_t bridge_iface_idx,
			       bool sourceMacsOnly,
			       const char *manufacturer,
			       char *sortColumn, u_int16_t pool_filter,
			       u_int8_t devtype_filter, u_int8_t location_filter) {
  u_int32_t maxHits;
  int (*sorter)(const void *_a, const void *_b);

  if(retriever == NULL)
    return -1;

  maxHits = getMacsHashSize();
  if((maxHits > CONST_MAX_NUM_HITS) || (maxHits == 0))
    maxHits = CONST_MAX_NUM_HITS;

  retriever->sourceMacsOnly = sourceMacsOnly,
    retriever->actNumEntries = 0,
    retriever->poolFilter = pool_filter,
    retriever->manufacturer = (char *)manufacturer,
    retriever->maxNumEntries = maxHits,
    retriever->devtypeFilter = devtype_filter,
    retriever->locationFilter = location_filter,
    retriever->ndpi_proto = -1,
    retriever->elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if(retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if((!strcmp(sortColumn, "column_mac")) || (!strcmp(sortColumn, "column_"))) retriever->sorter = column_mac, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_since"))        retriever->sorter = column_since,        sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt"))         retriever->sorter = column_thpt,         sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic"))      retriever->sorter = column_traffic,      sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_hosts"))        retriever->sorter = column_num_hosts,    sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_manufacturer")) retriever->sorter = column_manufacturer, sorter = stringSorter;
  else if(!strcmp(sortColumn, "column_device_type"))  retriever->sorter = column_device_type, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_arp_total"))    retriever->sorter = column_arp_total, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_arp_sent"))     retriever->sorter = column_arp_sent,  sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_arp_rcvd"))     retriever->sorter = column_arp_rcvd,  sorter = numericSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(begin_slot, walk_all, walker_macs, mac_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortASes(struct flowHostRetriever *retriever, char *sortColumn) {
  u_int32_t maxHits;
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(retriever == NULL)
    return -1;

  maxHits = getASesHashSize();
  if((maxHits > CONST_MAX_NUM_HITS) || (maxHits == 0))
    maxHits = CONST_MAX_NUM_HITS;

  retriever->actNumEntries = 0,
    retriever->maxNumEntries = maxHits,
    retriever->elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if(retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if((!strcmp(sortColumn, "column_asn")) || (!strcmp(sortColumn, "column_"))) retriever->sorter = column_asn, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_asname"))       retriever->sorter = column_asname,       sorter = stringSorter;
  else if(!strcmp(sortColumn, "column_since"))        retriever->sorter = column_since,        sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt"))         retriever->sorter = column_thpt,         sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic"))      retriever->sorter = column_traffic,      sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_hosts"))        retriever->sorter = column_num_hosts,    sorter = numericSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all,  walker_ases, as_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortCountries(struct flowHostRetriever *retriever,
	       char *sortColumn) {
  u_int32_t maxHits;
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(retriever == NULL)
    return -1;

  maxHits = getCountriesHashSize();
  if((maxHits > CONST_MAX_NUM_HITS) || (maxHits == 0))
    maxHits = CONST_MAX_NUM_HITS;

  retriever->actNumEntries = 0,
    retriever->maxNumEntries = maxHits,
    retriever->elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if(retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if((!strcmp(sortColumn, "column_country")) || (!strcmp(sortColumn, "column_"))) retriever->sorter = column_country, sorter = stringSorter;
  else if(!strcmp(sortColumn, "column_since"))        retriever->sorter = column_since,        sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_hosts"))        retriever->sorter = column_num_hosts,    sorter = numericSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all,  walker_countries, country_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortVLANs(struct flowHostRetriever *retriever, char *sortColumn) {
  u_int32_t maxHits;
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(retriever == NULL)
    return -1;

  maxHits = getVLANsHashSize();
  if((maxHits > CONST_MAX_NUM_HITS) || (maxHits == 0))
    maxHits = CONST_MAX_NUM_HITS;

  retriever->actNumEntries = 0,
    retriever->maxNumEntries = maxHits,
    retriever->elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if(retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if((!strcmp(sortColumn, "column_vlan")) || (!strcmp(sortColumn, "column_"))) retriever->sorter = column_vlan, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_since"))        retriever->sorter = column_since,        sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt"))         retriever->sorter = column_thpt,         sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic"))      retriever->sorter = column_traffic,      sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_hosts"))        retriever->sorter = column_num_hosts,    sorter = numericSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all,  walker_vlans, vlan_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getActiveHostsList(lua_State* vm,
					 u_int32_t *begin_slot,
					 bool walk_all,
					 u_int8_t bridge_iface_idx,
					 AddressTree *allowed_hosts,
					 bool host_details, LocationPolicy location,
					 char *countryFilter, char *mac_filter,
					 u_int16_t vlan_id, char *osFilter,
					 u_int32_t asnFilter, int16_t networkFilter,
					 u_int16_t pool_filter, bool filtered_hosts,
					 bool blacklisted_hosts, bool hide_top_hidden,
					 u_int8_t ipver_filter, int proto_filter,
					 TrafficType traffic_type_filter, bool tsLua,
					 bool anomalousOnly, bool dhcpOnly,
					 char *sortColumn, u_int32_t maxHits,
					 u_int32_t toSkip, bool a2zSortOrder) {
  struct flowHostRetriever retriever;

  disablePurge(false);

#if DEBUG
  if(!walk_all)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[BEGIN] %s(begin_slot=%u, walk_all=%u)",
				 __FUNCTION__, *begin_slot, walk_all);
#endif

  if(sortHosts(begin_slot, walk_all,
	       &retriever, bridge_iface_idx,
	       allowed_hosts, host_details, location,
	       countryFilter, mac_filter, vlan_id, osFilter,
	       asnFilter, networkFilter, pool_filter, filtered_hosts, blacklisted_hosts, hide_top_hidden,
	       anomalousOnly, dhcpOnly,
	       ipver_filter, proto_filter,
	       traffic_type_filter,
	       sortColumn) < 0) {
    enablePurge(false);
    return -1;
  }

#if DEBUG
  if(!walk_all)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[END] %s(end_slot=%u, numHosts=%u)",
				 __FUNCTION__, *begin_slot, retriever.actNumEntries);
#endif

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numHosts", retriever.actNumEntries);
  lua_push_uint64_table_entry(vm, "nextSlot", *begin_slot);

  lua_newtable(vm);

  if(a2zSortOrder) {
    for(int i = toSkip, num=0; i<(int)retriever.actNumEntries && num < (int)maxHits; i++, num++) {
      Host *h = retriever.elems[i].hostValue;

      if(!tsLua)
	h->lua(vm, NULL /* Already checked */, host_details, false, false, true);
      else
	h->tsLua(vm);
    }
  } else {
    for(int i = (retriever.actNumEntries-1-toSkip), num=0; i >= 0 && num < (int)maxHits; i--, num++) {
      Host *h = retriever.elems[i].hostValue;

      if(!tsLua)
	h->lua(vm, NULL /* Already checked */, host_details, false, false, true);
      else
	h->tsLua(vm);
    }
  }

  lua_pushstring(vm, "hosts");
  lua_insert(vm, -2);
  lua_settable(vm, -3);


  enablePurge(false);

  // it's up to us to clean sorted data
  // make sure first to free elements in case a string sorter has been used
  if(retriever.sorter == column_name
     || retriever.sorter == column_country
     || retriever.sorter == column_os) {
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].stringValue)
	free(retriever.elems[i].stringValue);
  } else if(retriever.sorter == column_local_network)
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].ipValue)
	delete retriever.elems[i].ipValue;

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

struct hosts_get_macs_retriever {
  lua_State *vm;
  int idx;
};

static bool hosts_get_macs(GenericHashEntry *he, void *user_data, bool *matched) {
  struct hosts_get_macs_retriever *r = (struct hosts_get_macs_retriever *) user_data;
  Host *host = (Host *)he;
  Mac *mac = host->getMac();
  char mac_buf[32], *mac_ptr;
  char ip_buf[64];

  if(mac && !mac->isSpecialMac() && host->get_ip()) {
    mac_ptr = Utils::formatMac(mac->get_mac(), mac_buf, sizeof(mac_buf));
    lua_getfield(r->vm, r->idx, mac_ptr);

    if(lua_type(r->vm, -1) == LUA_TTABLE) {
      lua_getfield(r->vm, -1, "ip");

      if(lua_type(r->vm, -1) == LUA_TNIL) {
        /* First assignment - create table */
        lua_pop(r->vm, 1);
        lua_pushstring(r->vm, "ip");
        lua_newtable(r->vm);
        lua_settable(r->vm, -3);
        lua_getfield(r->vm, -1, "ip");
      }

      if(lua_type(r->vm, -1) == LUA_TTABLE) {
        /* Add the ip address to the table */
        lua_push_uint64_table_entry(r->vm, host->get_hostkey(ip_buf, sizeof(ip_buf)), host->get_ip()->isIPv4() ? 4 : 6);
      }

      lua_pop(r->vm, 1);
    }

    lua_pop(r->vm, 1);
    *matched = true;
  }

  /* keep on iterating */
  return (false);
}

/* **************************************************** */

int NetworkInterface::getMacsIpAddresses(lua_State *vm, int idx) {
  struct hosts_get_macs_retriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  retriever.vm = vm;
  retriever.idx = idx;

  walker(&begin_slot, walk_all,  walker_hosts, hosts_get_macs, (void*)&retriever);
  return 0;
}

/* **************************************************** */

int NetworkInterface::getActiveHostsGroup(lua_State* vm,
					  u_int32_t *begin_slot,
					  bool walk_all,
					  AddressTree *allowed_hosts,
					  bool host_details, LocationPolicy location,
					  char *countryFilter,
					  u_int16_t vlan_id, char *osFilter,
					  u_int32_t asnFilter, int16_t networkFilter,
					  u_int16_t pool_filter, bool filtered_hosts,
					  u_int8_t ipver_filter,
					  char *groupColumn) {
  struct flowHostRetriever retriever;
  Grouper *gper;

  disablePurge(false);

  // sort hosts according to the grouping criterion
  if(sortHosts(begin_slot, walk_all,
	       &retriever, 0 /* bridge_iface_idx TODO */,
	       allowed_hosts, host_details, location,
	       countryFilter, NULL /* Mac */, vlan_id,
	       osFilter, asnFilter, networkFilter, pool_filter,
	       filtered_hosts, false /* no blacklisted hosts filter */, false, false, false,
	       ipver_filter, -1 /* no protocol filter */,
	       traffic_type_all /* no traffic type filter */,
	       groupColumn) < 0 ) {
    enablePurge(false);
    return -1;
  }

  // build a new grouper that will help in aggregating stats
  if((gper = new(std::nothrow) Grouper(retriever.sorter)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to allocate memory for a Grouper.");
    enablePurge(false);
    return -1;
  }

  lua_newtable(vm);

  for(int i = 0; i < (int)retriever.actNumEntries; i++) {
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

  enablePurge(false);

  // it's up to us to clean sorted data
  // make sure first to free elements in case a string sorter has been used
  if((retriever.sorter == column_name)
     || (retriever.sorter == column_country)
     || (retriever.sorter == column_os)) {
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].stringValue)
	free(retriever.elems[i].stringValue);
  } else if(retriever.sorter == column_local_network)
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].ipValue)
	delete retriever.elems[i].ipValue;

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

static bool flow_stats_walker(GenericHashEntry *h, void *user_data, bool *matched) {
  struct active_flow_stats *stats = (struct active_flow_stats*)user_data;
  Flow *flow = (Flow*)h;

  stats->num_flows++,
    stats->ndpi_bytes[flow->get_detected_protocol().app_protocol] += (u_int32_t)flow->get_bytes(),
    stats->breeds_bytes[flow->get_protocol_breed()] += (u_int32_t)flow->get_bytes();

  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getFlowsStats(lua_State* vm) {
  struct active_flow_stats stats;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&stats, 0, sizeof(stats));
  walker(&begin_slot, walk_all,  walker_flows, flow_stats_walker, (void*)&stats);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "num_flows", stats.num_flows);

  lua_newtable(vm);
  for(int i=0; i<NDPI_MAX_SUPPORTED_PROTOCOLS+NDPI_MAX_NUM_CUSTOM_PROTOCOLS; i++) {
    if(stats.ndpi_bytes[i] > 0)
      lua_push_uint64_table_entry(vm,
			       ndpi_get_proto_name(get_ndpi_struct(), i),
			       stats.ndpi_bytes[i]);
  }

  lua_pushstring(vm, "protos");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  for(int i=0; i<NUM_BREEDS; i++) {
    if(stats.breeds_bytes[i] > 0)
      lua_push_uint64_table_entry(vm,
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
  for(u_int8_t network_id = 0; network_id < num_local_networks; network_id++) {
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

u_int NetworkInterface::purgeIdleFlows() {
  u_int n = 0;
  time_t last_packet_time = getTimeLastPktRcvd();

  pollQueuedeBPFEvents();
  reloadCustomCategories();
  bcast_domains->inlineReloadBroadcastDomains();

  if(!purge_idle_flows_hosts) return(0);

  if(next_idle_flow_purge == 0) {
    next_idle_flow_purge = last_packet_time + FLOW_PURGE_FREQUENCY;
    return(0);
  } else if(last_packet_time < next_idle_flow_purge)
    return(0); /* Too early */
  else {
    /* Time to purge flows */

    ntop->getTrace()->traceEvent(TRACE_INFO,
				 "Purging idle flows [ifname: %s] [ifid: %i] [current size: %i]",
				 ifname, id, flows_hash->getCurrentSize());
    n = flows_hash->purgeIdle();

    next_idle_flow_purge = last_packet_time + FLOW_PURGE_FREQUENCY;
    return(n);
  }
}

/* **************************************************** */

u_int64_t NetworkInterface::getNumPackets() {
  return(ethStats.getNumPackets());
};

/* **************************************************** */

u_int64_t NetworkInterface::getNumBytes() {
  return(ethStats.getNumBytes());
}

/* **************************************************** */

u_int32_t NetworkInterface::getNumPacketDrops() {
  return(!isDynamicInterface() ? getNumDroppedPackets() : 0);
};

/* **************************************************** */

u_int NetworkInterface::getNumFlows() {
  return(flows_hash ? flows_hash->getNumEntries() : 0);
};

/* **************************************************** */

u_int NetworkInterface::getNumL2Devices() {
  return(numL2Devices);
};

/* **************************************************** */

u_int NetworkInterface::getNumHosts() {
  return(numHosts);
};

/* **************************************************** */

u_int NetworkInterface::getNumLocalHosts() {
  return(numLocalHosts);
};

/* **************************************************** */

u_int NetworkInterface::getNumHTTPHosts() {
  return(hosts_hash ? hosts_hash->getNumHTTPEntries() : 0);
};

/* **************************************************** */

u_int NetworkInterface::getNumMacs() {
  return(macs_hash ? macs_hash->getNumEntries() : 0);
};

/* **************************************************** */

u_int NetworkInterface::getNumArpStatsMatrixElements() {
  return(arp_hash_matrix ? arp_hash_matrix->getNumEntries() : 0);
};

/* **************************************************** */

u_int NetworkInterface::purgeIdleHostsMacsASesVlans() {
  time_t last_packet_time = getTimeLastPktRcvd();

  if(!purge_idle_flows_hosts) return(0);

  if(next_idle_host_purge == 0) {
    next_idle_host_purge = last_packet_time + HOST_PURGE_FREQUENCY;
    return(0);
  } else if(last_packet_time < next_idle_host_purge)
    return(0); /* Too early */
  else {
    /* Time to purge hosts */
    u_int n;

    // ntop->getTrace()->traceEvent(TRACE_INFO, "Purging idle hosts");
    n = hosts_hash->purgeIdle()
      + macs_hash->purgeIdle()
      + ases_hash->purgeIdle()
      + countries_hash->purgeIdle()
      + vlans_hash->purgeIdle();

    if(arp_hash_matrix)
      n += arp_hash_matrix->purgeIdle();

    next_idle_host_purge = last_packet_time + HOST_PURGE_FREQUENCY;
    return(n);
  }
}

/* *************************************** */

void NetworkInterface::setnDPIProtocolCategory(u_int16_t protoId, ndpi_protocol_category_t protoCategory) {
  ndpi_set_proto_category(ndpi_struct, protoId, protoCategory);
}

/* *************************************** */

static bool guess_all_ndpi_protocols_walker(GenericHashEntry *node, void *user_data, bool *matched) {
  Flow *flow = (Flow*)node;
  NetworkInterface *iface = (NetworkInterface*)user_data;

  if(!flow->isDetectionCompleted() && iface->get_ndpi_struct() && flow->get_ndpi_flow())
    flow->setDetectedProtocol(ndpi_detection_giveup(iface->get_ndpi_struct(), flow->get_ndpi_flow(), 1), true);

  return(false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::guessAllnDPIProtocols() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  walker(&begin_slot, walk_all, walker_flows,
	 guess_all_ndpi_protocols_walker, this);
}
/* *************************************** */

void NetworkInterface::guessAllBroadcastDomainHosts() {
  bcast_domains->inlineReloadBroadcastDomains(true);
}

/* **************************************************** */

void NetworkInterface::getnDPIProtocols(lua_State *vm, ndpi_protocol_category_t filter, bool skip_critical) {
  int i;
  u_int num_supported_protocols = ndpi_get_ndpi_num_supported_protocols(ndpi_struct);
  ndpi_proto_defaults_t* proto_defaults = ndpi_get_proto_defaults(ndpi_struct);

  lua_newtable(vm);

  for(i=0; i<(int)num_supported_protocols; i++) {
    char buf[8];

    if((((u_int8_t)filter == (u_int8_t)-1)
	|| proto_defaults[i].protoCategory == filter) &&
	(!skip_critical || !Utils::isCriticalNetworkProtocol(i))) {
      snprintf(buf, sizeof(buf), "%d", i);
      if(!proto_defaults[i].protoName)
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "NULL protoname for index %d!!", i);
      else
	lua_push_str_table_entry(vm, proto_defaults[i].protoName, buf);
    }
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

static bool num_flows_state_walker(GenericHashEntry *node, void *user_data, bool *matched) {
  Flow *flow = (Flow*)node;
  u_int32_t *num_flows = (u_int32_t*)user_data;

  if(flow->get_protocol() == IPPROTO_TCP) {
    if(flow->isTCPEstablished())
      num_flows[2]++;
    else if(flow->isTCPConnecting())
      num_flows[1]++;
    else if(flow->isTCPReset())
      num_flows[0]++;
    else if(flow->isTCPClosed())
      num_flows[3]++;
  }

  *matched = true;

  return(false /* keep walking */);
}

/* *************************************** */

static bool num_flows_walker(GenericHashEntry *node, void *user_data, bool *matched) {
  Flow *flow = (Flow*)node;
  u_int32_t *num_flows = (u_int32_t*)user_data;

  num_flows[flow->get_detected_protocol().app_protocol]++;
  *matched = true;

  return(false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::getFlowsStatus(lua_State *vm) {
  u_int32_t num_flows[NUM_TCP_STATES] = { 0 };
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  walker(&begin_slot, walk_all,  walker_flows, num_flows_state_walker, num_flows);

  lua_push_uint64_table_entry(vm, "RST", num_flows[0]);
  lua_push_uint64_table_entry(vm, "SYN", num_flows[1]);
  lua_push_uint64_table_entry(vm, "Established", num_flows[2]);
  lua_push_uint64_table_entry(vm, "FIN", num_flows[3]);
}

/* *************************************** */

void NetworkInterface::getnDPIFlowsCount(lua_State *vm) {
  u_int32_t *num_flows;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  u_int num_supported_protocols = ndpi_get_ndpi_num_supported_protocols(ndpi_struct);
  ndpi_proto_defaults_t* proto_defaults = ndpi_get_proto_defaults(ndpi_struct);

  num_flows = (u_int32_t*)calloc(num_supported_protocols, sizeof(u_int32_t));

  if(num_flows) {
    walker(&begin_slot, walk_all,  walker_flows, num_flows_walker, num_flows);

    for(int i=0; i<(int)num_supported_protocols; i++) {
      if(num_flows[i] > 0)
	lua_push_uint64_table_entry(vm, proto_defaults[i].protoName,
				 num_flows[i]);
    }

    free(num_flows);
  }
}

/* *************************************** */

void NetworkInterface::sumStats(TcpFlowStats *_tcpFlowStats,
				EthStats *_ethStats,
				LocalTrafficStats *_localStats,
				nDPIStats *_ndpiStats,
				PacketStats *_pktStats,
				TcpPacketStats *_tcpPacketStats) {
  tcpFlowStats.sum(_tcpFlowStats), ethStats.sum(_ethStats), localStats.sum(_localStats),
    ndpiStats.sum(_ndpiStats), pktStats.sum(_pktStats), tcpPacketStats.sum(_tcpPacketStats);
}

/* *************************************** */

void NetworkInterface::lua(lua_State *vm) {
  TcpFlowStats _tcpFlowStats;
  EthStats _ethStats;
  LocalTrafficStats _localStats;
  nDPIStats _ndpiStats;
  PacketStats _pktStats;
  TcpPacketStats _tcpPacketStats;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "name", get_name());
  lua_push_str_table_entry(vm, "description", get_description());
  lua_push_uint64_table_entry(vm, "scalingFactor", scalingFactor);
  lua_push_uint64_table_entry(vm,  "id", id);
  if(customIftype) lua_push_str_table_entry(vm, "customIftype", (char*)customIftype);
  lua_push_bool_table_entry(vm, "isView", isView()); /* View interface */
  lua_push_bool_table_entry(vm, "isDynamic", isDynamicInterface()); /* An runtime-instantiated interface */
  lua_push_uint64_table_entry(vm, "seen.last", getTimeLastPktRcvd());
  lua_push_bool_table_entry(vm, "inline", get_inline_interface());
  lua_push_bool_table_entry(vm, "vlan",     hasSeenVlanTaggedPackets());
  lua_push_bool_table_entry(vm, "has_macs", hasSeenMacAddresses());
  lua_push_bool_table_entry(vm, "has_traffic_directions", (areTrafficDirectionsSupported() && (!is_traffic_mirrored)));

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "packets",     getNumPackets());
  lua_push_uint64_table_entry(vm, "bytes",       getNumBytes());
  lua_push_uint64_table_entry(vm, "flows",       getNumFlows());
  lua_push_uint64_table_entry(vm, "hosts",       getNumHosts());
  lua_push_uint64_table_entry(vm, "local_hosts", getNumLocalHosts());
  lua_push_uint64_table_entry(vm, "http_hosts",  getNumHTTPHosts());
  lua_push_uint64_table_entry(vm, "drops",       getNumPacketDrops());
  lua_push_uint64_table_entry(vm, "devices",     getNumL2Devices());
  lua_push_uint64_table_entry(vm, "current_macs",  getNumMacs());
  lua_push_uint64_table_entry(vm, "num_live_captures", num_live_captures);

  if(db) db->lua(vm, false /* Overall */);

  lua_pushstring(vm, "stats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "packets",     getNumPacketsSinceReset());
  lua_push_uint64_table_entry(vm, "bytes",       getNumBytesSinceReset());
  lua_push_uint64_table_entry(vm, "drops",       getNumPacketDropsSinceReset());

  if(db) db->lua(vm, true /* Since last checkpoint */);

  lua_pushstring(vm, "stats_since_reset");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_push_uint64_table_entry(vm, "remote_pps", last_remote_pps);
  lua_push_uint64_table_entry(vm, "remote_bps", last_remote_bps);
  icmp_v4.lua(true, vm);
  icmp_v6.lua(false, vm);
  lua_push_uint64_table_entry(vm, "arp.requests", arp_requests);
  lua_push_uint64_table_entry(vm, "arp.replies", arp_replies);
  lua_push_str_table_entry(vm, "type", (char*)get_type());
  lua_push_uint64_table_entry(vm, "speed", ifSpeed);
  lua_push_uint64_table_entry(vm, "mtu", ifMTU);
  lua_push_uint64_table_entry(vm, "alertLevel", alertLevel);
  lua_push_str_table_entry(vm, "ip_addresses", (char*)getLocalIPAddresses());
  bcast_domains->lua(vm);

  /* Anomalies */
  lua_newtable(vm);
  if(has_too_many_flows) lua_push_bool_table_entry(vm, "too_many_flows", true);
  if(has_too_many_hosts) lua_push_bool_table_entry(vm, "too_many_hosts", true);
  if(too_many_drops) lua_push_bool_table_entry(vm, "too_many_drops", true);
  if(slow_stats_update) lua_push_bool_table_entry(vm, "slow_stats_update", true);
  lua_pushstring(vm, "anomalies");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  sumStats(&_tcpFlowStats, &_ethStats, &_localStats,
	   &_ndpiStats, &_pktStats, &_tcpPacketStats);

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    subInterfaces[s]->sumStats(&_tcpFlowStats, &_ethStats,
			       &_localStats, &_ndpiStats, &_pktStats, &_tcpPacketStats);

  _tcpFlowStats.lua(vm, "tcpFlowStats");
  _ethStats.lua(vm);
  _localStats.lua(vm);
  _ndpiStats.lua(this, vm, true);
  _pktStats.lua(vm, "pktSizeDistribution");
  _tcpPacketStats.lua(vm, "tcpPacketStats");

  if(!isView()) {
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    if(flow_profiles) flow_profiles->lua(vm);
#endif
#endif
  }

  if(host_pools)
    host_pools->lua(vm);

#ifdef NTOPNG_PRO
  if(custom_app_stats)
    custom_app_stats->lua(vm);
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

  periodicStatsUpdate();
}

/* **************************************************** */

void NetworkInterface::runShutdownTasks() {
  /* NOTE NOTE NOTE
     This task runs asynchronously with respect to the datapath
  */

  if (ntop->getPrefs()->flushFlowsOnShutdown()) {
    /* Setting all flows as "ready to purge" (see isReadyToPurge) and dump them to the DB */
    periodicStatsUpdate();

#ifdef NTOPNG_PRO
    flushFlowDump();
#endif
  }
}

/* **************************************************** */

Mac* NetworkInterface::getMac(u_int8_t _mac[6], bool createIfNotPresent) {
  Mac *ret = NULL;

  if(_mac == NULL) return(NULL);

  ret = macs_hash->get(_mac);

  if((ret == NULL) && createIfNotPresent) {
    try {
      if((ret = new Mac(this, _mac)) != NULL) {
	if(!macs_hash->add(ret)) {
	  delete ret;
	  return(NULL);
	}
      }
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }

      return(NULL);
    }
  }

  return(ret);
}

/* **************************************************** */

ArpStatsMatrixElement* NetworkInterface::getArpHashMatrixElement(u_int8_t _src_mac[6], 
								 u_int8_t _dst_mac[6],
								 bool * const src2dst){
  ArpStatsMatrixElement *ret = NULL;

  if(_src_mac == NULL || _dst_mac == NULL || arp_hash_matrix == NULL)
    return NULL;

  ret = arp_hash_matrix->get(_src_mac, _dst_mac, src2dst);
  
  if(ret == NULL) {
    try{ 
      if((ret = new ArpStatsMatrixElement(this, _src_mac, _dst_mac, src2dst)) != NULL)
        if(!arp_hash_matrix->add(ret)){
          delete ret;
          ret = NULL;
        }
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	      oom_warning_sent = true;
      }
      return(NULL);
    }
  }
  
  return ret;
}

/* **************************************************** */

bool NetworkInterface::getArpStatsMatrixInfo(lua_State* vm){  
  if(getNumArpStatsMatrixElements() > 0) {
    lua_newtable(vm);
    arp_hash_matrix->lua(vm);
    return true;
  } else
    return false;
}

/* **************************************************** */

Vlan* NetworkInterface::getVlan(u_int16_t vlanId,
				bool createIfNotPresent) {
  Vlan *ret = NULL;

  if(!isView())
    ret = vlans_hash->get(vlanId);
  else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if((ret = subInterfaces[s]->get_vlans_hash()->get(vlanId)) != NULL)
	break;
    }
  }

  if((ret == NULL) && createIfNotPresent) {
    try {
      if((ret = new Vlan(this, vlanId)) != NULL) {
	if(!vlans_hash->add(ret)) {
	  delete ret;
	  return(NULL);
	}
      }
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }

      return(NULL);
    }
  }

  return(ret);
}

/* **************************************************** */

AutonomousSystem* NetworkInterface::getAS(IpAddress *ipa,
					  bool createIfNotPresent) {
  AutonomousSystem *ret = NULL;

  if(ipa == NULL) return(NULL);

  if(!isView())
    ret = ases_hash->get(ipa);
  else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if((ret = subInterfaces[s]->get_ases_hash()->get(ipa)) != NULL)
	break;
    }
  }

  if((ret == NULL) && createIfNotPresent) {
    try {
      if((ret = new AutonomousSystem(this, ipa)) != NULL) {
	if(!ases_hash->add(ret)) {
	  delete ret;
	  return(NULL);
	}
      }
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }

      return(NULL);
    }
  }

  return(ret);
}

/* **************************************************** */

Country* NetworkInterface::getCountry(const char *country_name,
					  bool createIfNotPresent) {
  Country *ret = NULL;

  if(!country_name || !country_name[0]) return(NULL);

  if(!isView())
    ret = countries_hash->get(country_name);
  else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if((ret = subInterfaces[s]->get_countries_hash()->get(country_name)) != NULL)
	break;
    }
  }

  if((ret == NULL) && createIfNotPresent) {
    try {
      if((ret = new Country(this, country_name)) != NULL) {
	if(!countries_hash->add(ret)) {
	  delete ret;
	  return(NULL);
	}
      }
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }

      return(NULL);
    }
  }

  return(ret);
}

/* **************************************************** */

Flow* NetworkInterface::findFlowByKey(u_int32_t key,
				      AddressTree *allowed_hosts) {
  Flow *f = NULL;

  f = (Flow*)(flows_hash->findByKey(key));

  if(f && (!f->match(allowed_hosts))) f = NULL;

  return(f);
}

/* **************************************************** */

Flow* NetworkInterface::findFlowByTuple(u_int16_t vlan_id,
					IpAddress *src_ip,  IpAddress *dst_ip,
					u_int16_t src_port, u_int16_t dst_port,
					u_int8_t l4_proto,
					AddressTree *allowed_hosts) const {
  bool src2dst;
  Flow *f = NULL;

  f = (Flow*)flows_hash->find(src_ip, dst_ip, src_port, dst_port, vlan_id, l4_proto, NULL, &src2dst);

  if(f && (!f->match(allowed_hosts))) f = NULL;

  return(f);
}

/* **************************************************** */

struct search_host_info {
  lua_State *vm;
  char *host_name_or_ip;
  u_int num_matches;
  AddressTree *allowed_hosts;
};

/* **************************************************** */

static bool hosts_search_walker(GenericHashEntry *h, void *user_data, bool *matched) {
  Host *host = (Host*)h;
  struct search_host_info *info = (struct search_host_info*)user_data;

  if(host->addIfMatching(info->vm, info->allowed_hosts, info->host_name_or_ip)) {
    info->num_matches++;
    *matched = true;
  }

  /* Stop after CONST_MAX_NUM_FIND_HITS matches */
  return((info->num_matches > CONST_MAX_NUM_FIND_HITS) ? true /* stop */ : false /* keep walking */);
}

/* **************************************************** */

struct search_mac_info {
  lua_State *vm;
  u_int8_t *mac;
  u_int num_matches;
};

/* **************************************************** */

static bool macs_search_walker(GenericHashEntry *h, void *user_data, bool *matched) {
  Host *host = (Host*)h;
  struct search_mac_info *info = (struct search_mac_info*)user_data;

  if(host->addIfMatching(info->vm, info->mac)) {
    info->num_matches++;
    *matched = true;
  }

  /* Stop after CONST_MAX_NUM_FIND_HITS matches */
  return((info->num_matches > CONST_MAX_NUM_FIND_HITS) ? true /* stop */ : false /* keep walking */);
}

/* *************************************** */

bool NetworkInterface::findHostsByMac(lua_State* vm, u_int8_t *mac) {
  struct search_mac_info info;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  info.vm = vm, info.mac = mac, info.num_matches = 0;

  lua_newtable(vm);
  walker(&begin_slot, walk_all,  walker_hosts, macs_search_walker, (void*)&info);
  return(info.num_matches > 0);
}

/* **************************************************** */

bool NetworkInterface::findHostsByName(lua_State* vm,
				       AddressTree *allowed_hosts,
				       char *key) {
  struct search_host_info info;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  info.vm = vm, info.host_name_or_ip = key, info.num_matches = 0,
    info.allowed_hosts = allowed_hosts;

  lua_newtable(vm);
  walker(&begin_slot, walk_all,  walker_hosts, hosts_search_walker, (void*)&info);
  return(info.num_matches > 0);
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
      if(Utils::validInterface(devpointer->description)) {
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

    pcap_freealldevs(devpointer);
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

struct proc_name_flows {
  lua_State* vm;
  char *proc_name;
};

static bool proc_name_finder_walker(GenericHashEntry *node, void *user_data, bool *matched) {
  Flow *f = (Flow*)node;
  struct proc_name_flows *info = (struct proc_name_flows*)user_data;
  char *name = f->get_proc_name(true);

  if(name && (strcmp(name, info->proc_name) == 0)) {
    f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
    lua_pushinteger(info->vm, f->key()); // Key
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
  } else {
    name = f->get_proc_name(false);

    if(name && (strcmp(name, info->proc_name) == 0)) {
      f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
      lua_pushinteger(info->vm, f->key()); // Key
      lua_insert(info->vm, -2);
      lua_settable(info->vm, -3);
    }
  }
  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::findProcNameFlows(lua_State *vm, char *proc_name) {
  struct proc_name_flows u;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  u.vm = vm, u.proc_name = proc_name;

  lua_newtable(vm);
  walker(&begin_slot, walk_all,  walker_flows, proc_name_finder_walker, &u);
}

/* **************************************************** */

struct pid_flows {
  lua_State* vm;
  u_int32_t pid;
};

static bool pidfinder_walker(GenericHashEntry *node, void *pid_data, bool *matched) {
  Flow *f = (Flow*)node;
  struct pid_flows *info = (struct pid_flows*)pid_data;

  if((f->getPid(true) == info->pid) || (f->getPid(false) == info->pid)) {
    f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
    lua_pushinteger(info->vm, f->key()); // Key
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
    *matched = true;
  }

  return(false); /* false = keep on walking */
}

/* **************************************** */

void NetworkInterface::findPidFlows(lua_State *vm, u_int32_t pid) {
  struct pid_flows u;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  u.vm = vm, u.pid = pid;

  lua_newtable(vm);
  walker(&begin_slot, walk_all,  walker_flows, pidfinder_walker, &u);
}

/* **************************************** */

struct virtual_host_valk_info {
  lua_State *vm;
  char *key;
  u_int32_t num;
};

/* **************************************** */

static bool virtual_http_hosts_walker(GenericHashEntry *node, void *data, bool *matched) {
  Host *h = (Host*)node;
  struct virtual_host_valk_info *info = (struct virtual_host_valk_info*)data;
  HTTPstats *s = h->getHTTPstats();

  if(s) {
    info->num += s->luaVirtualHosts(info->vm, info->key, h);
    *matched = true;
  }

  return(false); /* false = keep on walking */
}

/* **************************************** */

void NetworkInterface::listHTTPHosts(lua_State *vm, char *key) {
  struct virtual_host_valk_info info;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  lua_newtable(vm);

  info.vm = vm, info.key = key, info.num = 0;
  walker(&begin_slot, walk_all,  walker_hosts, virtual_http_hosts_walker, &info);
}

/* **************************************** */

void NetworkInterface::addAllAvailableInterfaces() {
  char ebuf[256] = { '\0' };
  pcap_if_t *devpointer;

  if(pcap_findalldevs(&devpointer, ebuf) < 0) {
    ;
  } else {
    for(int i = 0; devpointer != 0; i++) {
      if(Utils::validInterface(devpointer->description)
	 && (strncmp(devpointer->name, "virbr", 5) != 0) /* Ignore virtual interfaces */
	 && Utils::isInterfaceUp(devpointer->name)
	 ) {
	ntop->getPrefs()->add_network_interface(devpointer->name,
						devpointer->description);
      } else
	ntop->getTrace()->traceEvent(TRACE_INFO,
				     "Interface [%s][%s] not valid or down: discarded",
				     devpointer->name, devpointer->description);

      devpointer = devpointer->next;
    } /* for */
    pcap_freealldevs(devpointer);
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

void NetworkInterface::addInterfaceAddress(char * const addr) {
  if(ip_addresses.size() == 0)
    ip_addresses = addr;
  else {
    string s = addr;

    ip_addresses = ip_addresses + "," + s;
  }
}

/* **************************************** */

void NetworkInterface::addInterfaceNetwork(char * const net) {
  interface_networks.addAddress(net);
}

/* **************************************** */

bool NetworkInterface::isInterfaceNetwork(const IpAddress * const ipa, int network_bits) const {
  return interface_networks.match(ipa, network_bits);
}

/* **************************************** */

void NetworkInterface::allocateNetworkStats() {
  u_int8_t numNetworks = ntop->getNumLocalNetworks();

  try {
    networkStats = new NetworkStats[numNetworks];
    statsManager  = new StatsManager(id, STATS_MANAGER_STORE_NAME);
    alertsManager = new AlertsManager(id, ALERTS_MANAGER_STORE_NAME);
  } catch(std::bad_alloc& ba) {
    static bool oom_warning_sent = false;

    if(!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      oom_warning_sent = true;
    }
  }

  if(alertsManager)
    alertLevel = alertsManager->getNumAlerts(true);
  else
    alertLevel = 0;
}

/* **************************************** */

NetworkStats* NetworkInterface::getNetworkStats(u_int8_t networkId) {
  if((networkStats == NULL) || (networkId >= ntop->getNumLocalNetworks()))
    return(NULL);
  else
    return(&networkStats[networkId]);
}

/* **************************************** */

void NetworkInterface::checkPointCounters(bool drops_only) {
  if(!drops_only) {
    checkpointPktCount = getNumPackets(),
      checkpointBytesCount = getNumBytes();
  }
  checkpointPktDropCount = getNumPacketDrops();

  if(db) db->checkPointCounters(drops_only);
}

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointNumPackets() {
  return(checkpointPktCount);
};

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointNumBytes() {
  return(checkpointBytesCount);
}

/* **************************************************** */

u_int32_t NetworkInterface::getCheckPointNumPacketDrops() {
  return(checkpointPktDropCount);
};

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

ndpi_protocol_category_t NetworkInterface::get_ndpi_proto_category(u_int protoid) {
  ndpi_protocol proto;

  proto.app_protocol = NDPI_PROTOCOL_UNKNOWN;
  proto.master_protocol = protoid;
  proto.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;
  return get_ndpi_proto_category(proto);
}

/* **************************************** */

static bool host_reload_hide_from_top(GenericHashEntry *host, void *user_data, bool *matched) {
  Host *h = (Host*)host;

  h->reloadHideFromTop();

  return(false); /* false = keep on walking */
}

void NetworkInterface::reloadHideFromTop(bool refreshHosts) {
  char kname[64];
  char **networks = NULL;
  VlanAddressTree *new_tree;

  if(!ntop->getRedis()) return;


  if ((new_tree = new VlanAddressTree) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Not enough memory");
    return;
  }

  snprintf(kname, sizeof(kname), CONST_IFACE_HIDE_FROM_TOP_PREFS, id);

  int num_nets = ntop->getRedis()->smembers(kname, &networks);
  char *at;
  u_int16_t vlan_id;

  for(int i=0; i<num_nets; i++) {
    char *net = networks[i];
    if(!net) continue;

    if((at = strchr(net, '@'))) {
      vlan_id = atoi(at + 1);
      *at = '\0';
    } else
      vlan_id = 0;

    new_tree->addAddress(vlan_id, net, 1);
    free(net);
  }

  if(networks) free(networks);

  if(hide_from_top_shadow) delete(hide_from_top_shadow);
  hide_from_top_shadow = hide_from_top;
  hide_from_top = new_tree;

  if(refreshHosts) {
    /* Reload existing hosts */
    u_int32_t begin_slot = 0;
    bool walk_all = true;
    walker(&begin_slot, walk_all,  walker_hosts, host_reload_hide_from_top, NULL);
  }
}

/* **************************************** */

bool NetworkInterface::isHiddenFromTop(Host *host) {
  VlanAddressTree *vlan_addrtree = hide_from_top;
  
  if(!vlan_addrtree) return false;

  return(host->get_ip()->findAddress(vlan_addrtree->getAddressTree(host->getVlanId())));
}

/* **************************************** */

int NetworkInterface::getActiveMacList(lua_State* vm,
				       u_int32_t *begin_slot,
				       bool walk_all,
				       u_int8_t bridge_iface_idx,
				       bool sourceMacsOnly,
				       const char *manufacturer,
				       char *sortColumn, u_int32_t maxHits,
				       u_int32_t toSkip, bool a2zSortOrder,
				       u_int16_t pool_filter, u_int8_t devtype_filter,
				       u_int8_t location_filter) {
  struct flowHostRetriever retriever;
  bool show_details = true;

  disablePurge(false);

  if(sortMacs(begin_slot, walk_all,
	      &retriever, bridge_iface_idx, sourceMacsOnly,
	      manufacturer, sortColumn,
	      pool_filter, devtype_filter, location_filter) < 0) {
    enablePurge(false);
    return -1;
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numMacs", retriever.actNumEntries);
  lua_push_uint64_table_entry(vm, "nextSlot", *begin_slot);

  lua_newtable(vm);

  if(a2zSortOrder) {
    for(int i = toSkip, num=0; i<(int)retriever.actNumEntries && num < (int)maxHits; i++, num++) {
      Mac *m = retriever.elems[i].macValue;

      m->lua(vm, show_details, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and iterate inorder with ipairs */
    }
  } else {
    for(int i = (retriever.actNumEntries-1-toSkip), num=0; i >= 0 && num < (int)maxHits; i--, num++) {
      Mac *m = retriever.elems[i].macValue;

      m->lua(vm, show_details, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "macs");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  enablePurge(false);

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveASList(lua_State* vm, const Paginator *p) {
  struct flowHostRetriever retriever;
  DetailsLevel details_level;

  if(!p)
    return -1;

  disablePurge(false);

  if(sortASes(&retriever, p->sortColumn()) < 0) {
    enablePurge(false);
    return -1;
  }

  if(!p->getDetailsLevel(&details_level))
    details_level = details_normal;

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numASes", retriever.actNumEntries);

  lua_newtable(vm);

  if(p->a2zSortOrder()) {
    for(int i = p->toSkip(), num = 0; i < (int)retriever.actNumEntries && num < (int)p->maxHits(); i++, num++) {
      AutonomousSystem *as = retriever.elems[i].asValue;

      as->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and iterate inorder with ipairs */
    }
  } else {
    for(int i = (retriever.actNumEntries - 1 - p->toSkip()), num = 0; i >= 0 && num < (int)p->maxHits(); i--, num++) {
      AutonomousSystem *as = retriever.elems[i].asValue;

      as->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "ASes");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  enablePurge(false);

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}


/* **************************************** */

int NetworkInterface::getActiveCountriesList(lua_State* vm, const Paginator *p) {
  struct flowHostRetriever retriever;
  DetailsLevel details_level;

  if(!p)
    return -1;

  disablePurge(false);

  if(sortCountries(&retriever, p->sortColumn()) < 0) {
    enablePurge(false);
    return -1;
  }

  if(!p->getDetailsLevel(&details_level))
    details_level = details_normal;

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numCountries", retriever.actNumEntries);

  lua_newtable(vm);

  if(p->a2zSortOrder()) {
    for(int i = p->toSkip(), num = 0; i < (int)retriever.actNumEntries && num < (int)p->maxHits(); i++, num++) {
      Country *country = retriever.elems[i].countryVal;

      country->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and iterate inorder with ipairs */
    }
  } else {
    for(int i = (retriever.actNumEntries - 1 - p->toSkip()), num = 0; i >= 0 && num < (int)p->maxHits(); i--, num++) {
      Country *country = retriever.elems[i].countryVal;

      country->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "Countries");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  enablePurge(false);

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveVLANList(lua_State* vm,
					char *sortColumn, u_int32_t maxHits,
					u_int32_t toSkip, bool a2zSortOrder,
					DetailsLevel details_level) {
  struct flowHostRetriever retriever;

  if(! hasSeenVlanTaggedPackets()) {
    /* VLAN statistics are calculated only if VLAN tagged traffic has been seen */
    lua_pushnil(vm);
    return 0;
  }

  disablePurge(false);

  if(sortVLANs(&retriever, sortColumn) < 0) {
    enablePurge(false);
    return -1;
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numVLANs", retriever.actNumEntries);

  lua_newtable(vm);

  if(a2zSortOrder) {
    for(int i = toSkip, num = 0; i<(int)retriever.actNumEntries && num < (int)maxHits; i++, num++) {
      Vlan *vl = retriever.elems[i].vlanValue;

      vl->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and iterate inorder with ipairs */
    }
  } else {
    for(int i = (retriever.actNumEntries-1-toSkip), num = 0; i >= 0 && num < (int)maxHits; i--, num++) {
      Vlan *vl = retriever.elems[i].vlanValue;

      vl->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "VLANs");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  enablePurge(false);

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveMacManufacturers(lua_State* vm,
						u_int8_t bridge_iface_idx,
						bool sourceMacsOnly,
						u_int32_t maxHits,
						u_int8_t devtype_filter, u_int8_t location_filter) {
  struct flowHostRetriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  disablePurge(false);

  if(sortMacs(&begin_slot, walk_all,
	      &retriever, bridge_iface_idx, sourceMacsOnly,
	      NULL, (char*)"column_manufacturer",
	      (u_int16_t)-1, devtype_filter, location_filter) < 0) {
    enablePurge(false);
    return -1;
  }

  lua_newtable(vm);

  const char *cur_manuf = NULL;
  u_int32_t cur_count = 0;
  int k = 0;

  for(int i = 0; i<(int)retriever.actNumEntries && k < (int)maxHits; i++) {
    Mac *m = retriever.elems[i].macValue;

    const char *manufacturer = m->get_manufacturer();
    if(manufacturer != NULL) {
      if(!cur_manuf || (strcmp(cur_manuf, manufacturer) != 0)) {
	if(cur_manuf != NULL)
	  lua_push_int32_table_entry(vm, cur_manuf, cur_count);

	cur_manuf = manufacturer;
	cur_count = 1;
	k++;
      } else {
	cur_count++;
      }
    }
  }
  if(cur_manuf != NULL)
    lua_push_int32_table_entry(vm, cur_manuf, cur_count);

  enablePurge(false);

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveDeviceTypes(lua_State* vm,
					   u_int8_t bridge_iface_idx,
					   bool sourceMacsOnly,
					   u_int32_t maxHits,
					   const char *manufacturer, u_int8_t location_filter) {
  struct flowHostRetriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  disablePurge(false);

  if(sortMacs(&begin_slot, walk_all,
	      &retriever, bridge_iface_idx, sourceMacsOnly,
	      manufacturer, (char*)"column_device_type",
	      (u_int16_t)-1, (u_int8_t)-1, location_filter) < 0) {
    enablePurge(false);
    return -1;
  }

  lua_newtable(vm);

  u_int8_t cur_devtype = 0;
  u_int32_t cur_count = 0;
  int k = 0;

  for(int i = 0; i<(int)retriever.actNumEntries && k < (int)maxHits; i++) {
    Mac *m = retriever.elems[i].macValue;

    if(m->getDeviceType() != cur_devtype) {
      if(cur_count) {
        lua_pushinteger(vm, cur_devtype);
        lua_pushinteger(vm, cur_count);
        lua_settable(vm, -3);
      }

      cur_devtype = m->getDeviceType();
      cur_count = 1;
      k++;
    } else {
      cur_count++;
    }
  }

  if(cur_count) {
    lua_pushinteger(vm, cur_devtype);
    lua_pushinteger(vm, cur_count);
    lua_settable(vm, -3);
  }

  enablePurge(false);

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************** */

bool NetworkInterface::getMacInfo(lua_State* vm, char *mac) {
  struct mac_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  Utils::parseMac(info.mac, mac);

  disablePurge(false);

  walker(&begin_slot, walk_all,  walker_macs, find_mac_by_name, (void*)&info);

  if(info.m) {
    info.m->lua(vm, true, false);
    ret = true;
  } else
    ret = false;

  enablePurge(false);

  return ret;
}

/* **************************************** */

bool NetworkInterface::resetMacStats(lua_State* vm, char *mac, bool delete_data) {
  struct mac_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  Utils::parseMac(info.mac, mac);

  disablePurge(false);

  walker(&begin_slot, walk_all,  walker_macs, find_mac_by_name, (void*)&info);

  if(info.m) {
    if(delete_data)
      info.m->requestDataReset();
    else
      info.m->requestStatsReset();
    ret = true;
  } else
    ret = false;

  enablePurge(false);

  return ret;
}

/* **************************************** */

bool NetworkInterface::setMacOperatingSystem(lua_State* vm, char *strmac, OperatingSystem os) {
  u_int8_t mac[6];
  Mac *m;

  Utils::parseMac(mac, strmac);

  if((m = getMac(mac, false /* Don't create if missing */))) {
    m->setOperatingSystem(os);
    return(true);
  } else
    return(false);
}

/* **************************************** */

bool NetworkInterface::setMacDeviceType(char *strmac,
					DeviceType dtype, bool alwaysOverwrite) {
  u_int8_t mac[6];
  Mac *m;
  DeviceType oldtype;

  Utils::parseMac(mac, strmac);

  ntop->getTrace()->traceEvent(TRACE_INFO, "setMacDeviceType(%s) = %d", strmac, (int)dtype);

  if((m = getMac(mac, false /* Don't create if missing */))) {
    oldtype = m->getDeviceType();

    if(alwaysOverwrite || (oldtype == device_unknown)) {
      m->forceDeviceType(dtype);

      if(alwaysOverwrite && (oldtype != device_unknown) && (oldtype != dtype))
        ntop->getTrace()->traceEvent(TRACE_INFO, "Device %s type changed from %d to %d\n",
				strmac, oldtype, dtype);
    }
    return(true);
  } else
    return(false);
}

/* **************************************** */

bool NetworkInterface::getASInfo(lua_State* vm, u_int32_t asn) {
  struct as_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  info.asn = asn;

  disablePurge(false);

  walker(&begin_slot, walk_all,  walker_ases, find_as_by_asn, (void*)&info);

  if(info.as) {
    info.as->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  enablePurge(false);

  return ret;
}

/* **************************************** */

bool NetworkInterface::getVLANInfo(lua_State* vm, u_int16_t vlan_id) {
  struct vlan_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  info.vlan_id = vlan_id;

  disablePurge(false);

  walker(&begin_slot, walk_all,  walker_vlans, find_vlan_by_vlan_id, (void*)&info);

  if(info.vl) {
    info.vl->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  enablePurge(false);

  return ret;
}

/* **************************************** */

static bool host_reload_alert_prefs(GenericHashEntry *host, void *user_data, bool *matched) {
  bool full_refresh = (user_data != NULL) ? true : false;
  Host *h = (Host*)host;

  h->refreshHostAlertPrefs();
  *matched = true;

  if(full_refresh)
    h->loadAlertsCounter();
  return(false); /* false = keep on walking */
}

/* **************************************** */

void NetworkInterface::refreshHostsAlertPrefs(bool full_refresh) {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  /* Read the new configuration */
  ntop->getPrefs()->refreshHostsAlertsPrefs();

  disablePurge(false);

  /* Update the hosts */
  walker(&begin_slot, walk_all,  walker_hosts,
	 host_reload_alert_prefs, (void *)full_refresh);

  enablePurge(false);
};

/* **************************************** */

int NetworkInterface::updateHostTrafficPolicy(AddressTree* allowed_networks,
					      char *host_ip, u_int16_t host_vlan) {
  Host *h;
  int rv;
  disablePurge(false);

  if((h = findHostByIP(allowed_networks, host_ip, host_vlan)) != NULL) {
    h->updateHostTrafficPolicy(host_ip);
    rv = CONST_LUA_OK;
  } else
    rv = CONST_LUA_ERROR;

  enablePurge(false);
  return rv;
}

/* *************************************** */

void NetworkInterface::topItemsCommit(const struct timeval *tv) {
  float tdiff_msec = ((float)(tv->tv_sec-last_frequent_reset.tv_sec)*1000)+((tv->tv_usec-last_frequent_reset.tv_usec)/(float)1000);

  frequentProtocols->reset(tdiff_msec);
  frequentMacs->reset(tdiff_msec);

  last_frequent_reset = *tv;
}

/* *************************************** */

void NetworkInterface::topProtocolsAdd(u_int16_t pool_id, u_int16_t protocol, u_int32_t bytes) {
  if((bytes > 0) && (pool_id != 0)) {
    // frequentProtocols->addPoolProtocol(pool_id, proto->master_protocol, bytes);
    frequentProtocols->addPoolProtocol(pool_id, protocol, bytes);
  }
}

/* *************************************** */

void NetworkInterface::topMacsAdd(Mac *mac, u_int16_t protocol, u_int32_t bytes) {
  if((bytes > 0) && (! mac->isSpecialMac()) && (mac->locate() == located_on_lan_interface)) {
    // frequentProtocols->addPoolProtocol(pool_id, proto->master_protocol, bytes);
    frequentMacs->addMacProtocol(mac->get_mac(), protocol, bytes);
  }
}

/* *************************************** */

#ifdef HAVE_NINDEX
NIndexFlowDB* NetworkInterface::getNindex() {
  return(ntop->getPrefs()->do_dump_flows_on_nindex() ? (NIndexFlowDB*)db : NULL);
}
#endif

/* *************************************** */

void NetworkInterface::checkMacIPAssociation(bool triggerEvent, u_char *_mac, u_int32_t ipv4) {
  if(!ntop->getPrefs()->are_ip_reassignment_alerts_enabled())
    return;

  u_int64_t mac = Utils::mac2int(_mac);

  if((ipv4 != 0) && (mac != 0) && (mac != 0xFFFFFFFFFFFF)) {
    std::map<u_int32_t, u_int64_t>::iterator it;

    if(!triggerEvent)
      ip_mac[ipv4] = mac;
    else {
      if((it = ip_mac.find(ipv4)) != ip_mac.end()) {
	/* Found entry */
	if(it->second != mac) {
	  char oldmac[32], newmac[32], ipbuf[32], *ipa;
	  u_char tmp[6];
	  json_object *jobject;

	  Utils::int2mac(it->second, tmp);
	  Utils::formatMac(tmp, oldmac, sizeof(oldmac));
	  Utils::formatMac(_mac, newmac, sizeof(newmac));
	  ipa = Utils::intoaV4(ntohl(ipv4), ipbuf, sizeof(ipbuf));

	  ntop->getTrace()->traceEvent(TRACE_INFO, "IP %s: modified MAC association %s -> %s",
				       ipa, oldmac, newmac);

	  if((jobject = json_object_new_object()) != NULL) {
	    json_object_object_add(jobject, "ifname", json_object_new_string(get_name()));
	    json_object_object_add(jobject, "ifid", json_object_new_int(id));
	    json_object_object_add(jobject, "ip", json_object_new_string(ipa));
	    json_object_object_add(jobject, "old_mac", json_object_new_string(oldmac));
	    json_object_object_add(jobject, "new_mac", json_object_new_string(newmac));

	    ntop->getRedis()->rpush(CONST_ALERT_MAC_IP_QUEUE, (char *)json_object_to_json_string(jobject), 0 /* No trim */);

	    /* Free Memory */
	    json_object_put(jobject);
	  } else
	    ntop->getTrace()->traceEvent(TRACE_ERROR, "json_object_new_object: Not enough memory");

	  ip_mac[ipv4] = mac;
	}
      } else
	ip_mac[ipv4] = mac;
    }
  }
}

/* *************************************** */

/*
  Put here all the code that is executed when the NIC initialization
  is succesful
 */
void NetworkInterface::finishInitialization(u_int8_t num_defined_interfaces) {
  if(!isView()) {
#if defined(NTOPNG_PRO) && defined(HAVE_NINDEX)
    if(ntop->getPrefs()->do_dump_flows_on_nindex()) {
      if(num_defined_interfaces + 1 >= NINDEX_MAX_NUM_INTERFACES) {
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "nIndex cannot be enabled for %s.", get_name());
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "The maximum number of interfaces that can be used with nIndex is %d.",
				     NINDEX_MAX_NUM_INTERFACES);
	ntop->getTrace()->traceEvent(TRACE_ERROR,
				     "Interface will continue to work without nIndex support.");
      } else {
	db = new NIndexFlowDB(this);
	goto enable_aggregation;
      }
    }
#endif

    if(db == NULL) {
	if(ntop->getPrefs()->do_dump_flows_on_mysql()
	     || ntop->getPrefs()->do_read_flows_from_nprobe_mysql()) {
#ifdef NTOPNG_PRO
	if(ntop->getPrefs()->is_enterprise_edition()
	   && !ntop->getPrefs()->do_read_flows_from_nprobe_mysql()) {
#ifdef HAVE_MYSQL
	  db = new BatchedMySQLDB(this);
#endif

#if defined(NTOPNG_PRO) && defined(HAVE_NINDEX)
	enable_aggregation:
#endif
	  aggregated_flows_hash = new AggregatedFlowHash(this, num_hashes,
							 ntop->getPrefs()->get_max_num_flows());

	  ntop->getPrefs()->enable_flow_aggregation();
	  nextFlowAggregation = FLOW_AGGREGATION_DURATION;
	} else
	  aggregated_flows_hash = NULL;
#endif

#ifdef HAVE_MYSQL
	if(db == NULL)
	  db = new (std::nothrow) MySQLDB(this);
#endif

	if(!db) throw "Not enough memory";
      }
#ifndef HAVE_NEDGE
	else if (ntop->getPrefs()->do_dump_flows_on_es())
	  db = new ElasticSearch(this);
	else if (ntop->getPrefs()->do_dump_flows_on_ls())
	  db = new Logstash(this);
#endif
    }
  }
}

/* *************************************** */

bool NetworkInterface::registerLiveCapture(struct ntopngLuaContext * const luactx, int *id) {
  bool ret = false;

  *id = -1;
  active_captures_lock.lock(__FILE__, __LINE__);

  if(num_live_captures < MAX_NUM_PCAP_CAPTURES) {
    for(int i=0; i<MAX_NUM_PCAP_CAPTURES; i++) {
      if(live_captures[i] == NULL) {
	live_captures[i] = luactx, num_live_captures++;
	ret = true, *id = i;
	break;
      }
    }
  }

  active_captures_lock.unlock(__FILE__, __LINE__);

  return(ret);
}

/* *************************************** */

bool NetworkInterface::deregisterLiveCapture(struct ntopngLuaContext * const luactx) {
  bool ret = false;

  active_captures_lock.lock(__FILE__, __LINE__);

  for(int i=0; i<MAX_NUM_PCAP_CAPTURES; i++) {
    if(live_captures[i] == luactx) {
      struct ntopngLuaContext *c = (struct ntopngLuaContext *)live_captures[i];

      c->live_capture.stopped = true;
      live_captures[i] = NULL, num_live_captures--;
      ret = true;
      break;
    }
  }

  active_captures_lock.unlock(__FILE__, __LINE__);

  return(ret);
}

/* *************************************** */

bool NetworkInterface::matchLiveCapture(struct ntopngLuaContext * const luactx,
					const struct pcap_pkthdr * const h,
					const u_char * const packet,
					Flow * const f) {
  if((luactx->live_capture.matching_host == NULL)
     || (luactx->live_capture.matching_host == f->get_cli_host())
     || (luactx->live_capture.matching_host == f->get_srv_host())) {
    if(luactx->live_capture.bpfFilterSet) {
      if(!bpf_filter(luactx->live_capture.fcode.bf_insns,
		     (const u_char*)packet, h->caplen, h->caplen)) {
	return(false);
      }
    }

    return(true);
  }

  return false;
}

/* *************************************** */

void NetworkInterface::deliverLiveCapture(const struct pcap_pkthdr * const h,
					  const u_char * const packet, Flow * const f) {
  int res;

  for(u_int i=0, num_found = 0; (i<MAX_NUM_PCAP_CAPTURES)
	&& (num_found < num_live_captures); i++) {
    if(live_captures[i] != NULL) {
      struct ntopngLuaContext *c = (struct ntopngLuaContext *)live_captures[i];
      bool http_client_disconnected = false;

      num_found++;

      if(c->live_capture.capture_until < h->ts.tv_sec || c->live_capture.stopped)
	http_client_disconnected = true;

      /* The header is always sent even when there is never a match with matchLiveCapture,
         as otherwise some browsers may end up in hangning. Hanging has been
         verified with Safari Version 12.0 (13606.2.11)
	 but not with Chrome Version 68.0.3440.106 (Official Build) (64-bit) */
      if(!http_client_disconnected
	 && c->conn
	 && !c->live_capture.pcaphdr_sent) {
	struct pcap_file_header pcaphdr;

	Utils::init_pcap_header(&pcaphdr, this);

	if((res = mg_write_async(c->conn, &pcaphdr, sizeof(pcaphdr))) < (int)sizeof(pcaphdr))
	  http_client_disconnected = true;

	c->live_capture.pcaphdr_sent = true;
      }

      if(!http_client_disconnected
	 && c->conn
	 && matchLiveCapture(c, h, packet, f)) {
	struct pcap_disk_pkthdr pkthdr; /* Cannot use h as the format on disk differs */

	pkthdr.ts.tv_sec = h->ts.tv_sec, pkthdr.ts.tv_usec = h->ts.tv_usec,
	  pkthdr.caplen = h->caplen, pkthdr.len = h->len;

	if(
	   ((res = mg_write_async(c->conn, &pkthdr, sizeof(pkthdr))) < (int)sizeof(pkthdr))
	   || ((res = mg_write_async(c->conn, packet, h->caplen)) < (int)h->caplen)
	   )
	  http_client_disconnected = true;
	else {
	  c->live_capture.num_captured_packets++;

	  if((c->live_capture.capture_max_pkts != 0)
	     && (c->live_capture.num_captured_packets == c->live_capture.capture_max_pkts))
	    http_client_disconnected = true;
	}
      }

      if(http_client_disconnected)
	deregisterLiveCapture(c); /* (*) */
    }
  }
}

/* *************************************** */

void NetworkInterface::dumpLiveCaptures(lua_State* vm) {
  /* Administrative privileges checked by the caller */

  active_captures_lock.lock(__FILE__, __LINE__);

  lua_newtable(vm);

  for(int i = 0, capture_id = 0; i < MAX_NUM_PCAP_CAPTURES; i++) {
    if(live_captures[i] != NULL
       && !live_captures[i]->live_capture.stopped) {
      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "id", i);
      lua_push_uint64_table_entry(vm, "capture_until",
			       live_captures[i]->live_capture.capture_until);
      lua_push_uint64_table_entry(vm, "capture_max_pkts",
			       live_captures[i]->live_capture.capture_max_pkts);
      lua_push_uint64_table_entry(vm, "num_captured_packets",
			       live_captures[i]->live_capture.num_captured_packets);

      if(live_captures[i]->live_capture.matching_host != NULL) {
	Host *h = (Host*)live_captures[i]->live_capture.matching_host;
	char buf[64];

	lua_push_str_table_entry(vm, "host",
				 h->get_ip()->print(buf, sizeof(buf)));
      }

      lua_pushinteger(vm, ++capture_id);
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }
  }


  active_captures_lock.unlock(__FILE__, __LINE__);
}

/* *************************************** */

bool NetworkInterface::stopLiveCapture(int capture_id) {
  /* Administrative privileges checked by the caller */

  bool rc = false;

  if((capture_id >= 0) && (capture_id < MAX_NUM_PCAP_CAPTURES)) {
    active_captures_lock.lock(__FILE__, __LINE__);

    if(live_captures[capture_id] != NULL) {
      struct ntopngLuaContext *c = (struct ntopngLuaContext *)live_captures[capture_id];

      c->live_capture.stopped = true, rc = true;
      if(c->live_capture.bpfFilterSet)
	pcap_freecode(&c->live_capture.fcode);
      /* live_captures[capture_id] = NULL; */ /* <-- not necessary as mongoose will clean it */
    }

    active_captures_lock.unlock(__FILE__, __LINE__);
  }

  return(rc);
}

/* *************************************** */

void NetworkInterface::makeTsPoint(NetworkInterfaceTsPoint *pt) {
  /* unused */
  TcpFlowStats _tcpFlowStats;
  EthStats _ethStats;

  sumStats(&_tcpFlowStats, &_ethStats, &pt->local_stats,
	   &pt->ndpi, &pt->packetStats, &pt->tcpPacketStats);

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    subInterfaces[s]->sumStats(&_tcpFlowStats, &_ethStats,
			       &pt->local_stats, &pt->ndpi, &pt->packetStats, &pt->tcpPacketStats);

  pt->hosts = getNumHosts();
  pt->local_hosts = getNumLocalHosts();
  pt->devices = getNumL2Devices();
  pt->flows = getNumFlows();
  pt->http_hosts = getNumHTTPHosts();
}

/* *************************************** */

void NetworkInterface::tsLua(lua_State* vm) {
  if(!ts_ring || !TimeseriesRing::isRingEnabled(ntop->getPrefs())) {
    /* Use real time data */
    NetworkInterfaceTsPoint pt;

    makeTsPoint(&pt);
    TimeseriesRing::luaSinglePoint(vm, this, &pt);
  } else
    ts_ring->lua(vm);
}

/* *************************************** */

static bool host_reload_blacklist(GenericHashEntry *host, void *user_data, bool *matched) {
  Host *h = (Host*)host;

  h->reloadHostBlacklist();
  *matched = true;

  return(false); /* false = keep on walking */
}

/* *************************************** */

void NetworkInterface::reloadHostsBlacklist() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  /* Update the hosts */
  walker(&begin_slot, walk_all,  walker_hosts, host_reload_blacklist, NULL);
}

/* **************************************************** */

static bool local_hosts_2_dropbox_walker(GenericHashEntry *h, void *user_data, bool *matched) {
  Host *host = (Host*)h;

  if(host && (host->getNumDropboxPeers() > 0)) {
    lua_State *vm = (lua_State*)user_data;
    
    host->dumpDropbox(vm);
    *matched = true;
  }

  return(false); /* false = keep on walking */
}

/* *************************************** */

int NetworkInterface::dumpDropboxHosts(lua_State *vm) {
  int rc;
  u_int32_t begin_slot = 0;

  lua_newtable(vm);
    
  disablePurge(false /* on hosts */);
  rc = walker(&begin_slot, true /* walk_all */, walker_hosts,
	      local_hosts_2_dropbox_walker, vm) ? 0 : -1;
  enablePurge(false /* on hosts */);

  return(rc);
}

/* *************************************** */

static bool host_reload_dhcp_host(GenericHashEntry *host, void *user_data, bool *matched) {
  Host *h = (Host*)host;

  h->reloadDhcpHost();
  *matched = true;

  return(false); /* false = keep on walking */
}

/* *************************************** */

void NetworkInterface::reloadDhcpRanges() {
  char redis_key[CONST_MAX_LEN_REDIS_KEY], *rsp = NULL;
  dhcp_range *new_ranges = NULL;
  u_int num_ranges = 0;
  u_int len;

  if(!ntop->getRedis())
    return;

  snprintf(redis_key, sizeof(redis_key), IFACE_DHCP_RANGE_KEY, get_id());

  if((rsp = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE))
     && !ntop->getRedis()->get(redis_key, rsp, CONST_MAX_LEN_REDIS_VALUE)
     && (len = strlen(rsp))) {
    u_int i;
    num_ranges = 1;

    for(i=0; i<len; i++) {
      if(rsp[i] == ',')
	num_ranges++;
    }

    // +1 for final zero IP, which is used to indicate array termination
    new_ranges = new dhcp_range[num_ranges+1];

    if(new_ranges) {
      char *cur_pos = rsp;

      /* E.g. 192.168.1.2-192.168.1.150,10.0.0.50-10.0.0.60 */
      for(i=0; i<num_ranges; i++) {
	char *end = strchr(cur_pos, ',');
	char *delim = strchr(cur_pos, '-');

	if(!end)
	  end = cur_pos + strlen(cur_pos);

	if(delim) {
	  *delim = 0;
	  *end = 0;

	  new_ranges[i].first_ip.set(cur_pos);
	  new_ranges[i].last_ip.set(delim+1);
	}

	cur_pos = end + 1;
      }
    }
  }

  if(dhcp_ranges_shadow)
    delete[] (dhcp_ranges_shadow);

  dhcp_ranges_shadow = dhcp_ranges;
  dhcp_ranges = new_ranges;

  if(rsp)
    free(rsp);

  /* Reload existing hosts */
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  walker(&begin_slot, walk_all,  walker_hosts, host_reload_dhcp_host, NULL);
}

/* *************************************** */

bool NetworkInterface::isInDhcpRange(IpAddress *ip) {
  // Important: cache it as it may change
  dhcp_range *ranges = dhcp_ranges;

  if(!ranges)
    return(false);

  while(!ranges->last_ip.isEmpty()) {
    if((ranges->first_ip.compare(ip) <= 0) &&
	(ranges->last_ip.compare(ip) >= 0))
      return true;

    ranges++;
  }

  return false;
}

/* *************************************** */

bool NetworkInterface::isLocalBroadcastDomainHost(Host * const h, bool isInlineCall) {
  IpAddress *i = h->get_ip();
    
  return(bcast_domains->isLocalBroadcastDomainHost(h, isInlineCall)
	 || (ntop->getLoadInterfaceAddresses() && i->match(ntop->getLoadInterfaceAddresses())));
}

/* *************************************** */

#ifdef HAVE_EBPF

bool NetworkInterface::enqueueeBPFEvent(eBPFevent *event) {
#ifdef EBPF_DEBUG
  // ntop->getTrace()->traceEvent(TRACE_ERROR, "[%s] %s(%d/%d)", ifname, __FUNCTION__, next_insert_idx, next_remove_idx);
#endif

  if(ebpfEvents[next_insert_idx] != (eBPFevent*)NULL)
    return(false);

  ebpf_preprocess_event(event, true /* speak with docker */);

  ebpfEvents[next_insert_idx] = event;
  next_insert_idx = (next_insert_idx + 1) % EBPF_QUEUE_LEN;
  return(true);
}

/* *************************************** */

bool NetworkInterface::dequeueeBPFEvent(eBPFevent **event) {
  if(ebpfEvents[next_remove_idx] == (eBPFevent*)NULL) {
    *event = NULL;
    return(false);
  }

#ifdef EBPF_DEBUG
  // ntop->getTrace()->traceEvent(TRACE_ERROR, "[%s] %s(%d/%d)", ifname, __FUNCTION__, next_insert_idx, next_remove_idx);
#endif

  *event = ebpfEvents[next_remove_idx];
  ebpfEvents[next_remove_idx] = NULL;
  next_remove_idx = (next_remove_idx + 1) % EBPF_QUEUE_LEN;
  return(true);
}

/* *************************************** */

void NetworkInterface::delivereBPFEvent(eBPFevent *event) {
  eBPFevent *tmp;

  if(ebpfEvents == NULL)
    return; /* No events */
  else if((event->ifname[0] != '\0') && strcmp(event->ifname, ifname))
    return; /* Not for this interface */

  if((tmp = (eBPFevent*)malloc(sizeof(eBPFevent))) != NULL) {
    memcpy(tmp, event, sizeof(eBPFevent));

    // ntop->getTrace()->traceEvent(TRACE_ERROR, "%s()", __FUNCTION__);

    if(!enqueueeBPFEvent(tmp))
      free(tmp); /* Not enough space */
    else if(!hasSeenEBPFEvents())
      setSeenEBPFEvents();
  }
}

#endif // HAVE_EBPF
