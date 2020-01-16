/*
 *
 * (C) 2013-20 - ntop.org
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
NetworkInterface::NetworkInterface() : AlertableEntity(this, alert_entity_interface) {
  init();
}

/* **************************************************** */

NetworkInterface::NetworkInterface(const char *name,
				   const char *custom_interface_type) : AlertableEntity(this, alert_entity_interface) {
  char _ifname[MAX_INTERFACE_NAME_LEN], buf[MAX_INTERFACE_NAME_LEN];
  /* We need to do it as isView() is not yet initialized */
  char pcap_error_buffer[PCAP_ERRBUF_SIZE];

  init();
  customIftype = custom_interface_type, tsExporter = NULL;

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

  ifname = strdup(name);
  if(custom_interface_type)
    ifDescription = strdup(name);
  else
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
     || (strcmp(name, SYSTEM_INTERFACE_NAME) == 0)
#if !defined(__APPLE__) && !defined(WIN32)
     || (Utils::readIPv4((char*)name) == 0)
#endif
     || custom_interface_type
     ) {
    ; /* Don't setup MDNS on ZC or RSS interfaces */
  } else {
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

      if(discovery) {
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
    last_pkt_rcvd = last_pkt_rcvd_remote = 0, pollLoopCreated = false,
      bridge_interface = false;
    next_idle_flow_purge = next_idle_host_purge = next_idle_other_purge = 0;
    cpu_affinity = -1 /* no affinity */,
      has_vlan_packets = has_ebpf_events = false;

    running = false,
      inline_interface = false;

    checkIdle();
    ifSpeed = Utils::getMaxIfSpeed(name);
    ifMTU = Utils::getIfMTU(name), mtuWarningShown = false;
    reloadDhcpRanges();
  } else /* id < 0 */ {
    ifSpeed = 0;
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

  statsManager = NULL, alertsManager = NULL, alertsQueue = NULL;
  ndpiStats = NULL;

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
     && strcmp(ifname, SYSTEM_INTERFACE_NAME)
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
  updateDynIfaceTrafficPolicy();
  updateFlowDumpDisabled();
  updateLbdIdentifier();
  updateDiscardProbingTraffic();
}

/* **************************************************** */

void NetworkInterface::init() {
  ifname = NULL, bridge_lan_interface_id = bridge_wan_interface_id = 0;
    inline_interface = false,
    has_vlan_packets = false, has_ebpf_events = false,
    has_seen_dhcp_addresses = false,
    has_seen_containers = false, has_seen_pods = false,
    last_pkt_rcvd = last_pkt_rcvd_remote = 0,
    next_idle_flow_purge = next_idle_host_purge = 0,
    running = false, customIftype = NULL, 
    is_dynamic_interface = false, show_dynamic_interface_traffic = false,
    is_loopback = is_traffic_mirrored = false, lbd_serialize_by_mac = false,
    discard_probing_traffic = false;
    numSubInterfaces = 0, flowHashing = NULL,
    pcap_datalink_type = 0, mtuWarningShown = false,
    purge_idle_flows_hosts = true, id = (u_int8_t)-1,
    last_remote_pps = 0, last_remote_bps = 0,
    has_vlan_packets = false,
    cpu_affinity = -1 /* no affinity */,
    inline_interface = false, running = false, interfaceStats = NULL,
    has_too_many_hosts = has_too_many_flows = false,
    slow_stats_update = false, flow_dump_disabled = false,
    numL2Devices = 0, numHosts = 0, numLocalHosts = 0,
    arp_requests = arp_replies = 0,
    has_mac_addresses = false,
    checkpointPktCount = checkpointBytesCount = checkpointPktDropCount = 0,
    checkpointDiscardedProbingPktCount = checkpointDiscardedProbingBytesCount = 0,
    pollLoopCreated = false, bridge_interface = false,
    mdns = NULL, discovery = NULL, ifDescription = NULL,
    flowHashingMode = flowhashing_none;
    num_dropped_flow_scripts_calls = 0,
      num_new_flows = 0;

  flows_hash = NULL, hosts_hash = NULL;
  macs_hash = NULL, ases_hash = NULL, vlans_hash = NULL;
  countries_hash = NULL, arp_hash_matrix = NULL;

  reload_hosts_bcast_domain = false;
  hosts_bcast_domain_last_update = 0;

#ifdef NTOPNG_PRO
  aggregated_flows_dump_updates = aggregated_flows_dump_max_updates = 0;
#endif

  ip_addresses = "", networkStats = NULL,
    pcap_datalink_type = 0, cpu_affinity = -1;
  hide_from_top = hide_from_top_shadow = NULL;

  gettimeofday(&last_frequent_reset, NULL);
  memcpy(&last_periodic_stats_update, &last_frequent_reset, sizeof(last_periodic_stats_update));
  frequentMacs = new FrequentTrafficItems(5);
  frequentProtocols = new FrequentTrafficItems(5);
  num_live_captures = 0, num_dropped_alerts = 0;
  memset(live_captures, 0, sizeof(live_captures));
  memset(&num_alerts_engaged, 0, sizeof(num_alerts_engaged));
  num_active_alerted_flows = num_idle_alerted_flows = 0;
  has_stored_alerts = false;

  is_view = false;
  viewed_by = NULL;

  db = NULL;
#ifdef NTOPNG_PRO
  custom_app_stats = NULL;
  aggregated_flows_hash = NULL, flow_interfaces_stats = NULL;
  policer = NULL;
#endif
  ndpiStats = NULL;
  statsManager = NULL, alertsManager = NULL, ifSpeed = 0;
  host_pools = NULL;
  bcast_domains = NULL;
  checkIdle();
  ifMTU = CONST_DEFAULT_MAX_PACKET_SIZE, mtuWarningShown = false;
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  flow_profiles = shadow_flow_profiles = NULL;
  sub_interfaces = NULL;
#endif
#endif

  dhcp_ranges = dhcp_ranges_shadow = NULL;

  ts_ring = NULL;

  if(TimeseriesRing::isRingEnabled(this))
    ts_ring = new TimeseriesRing(this);

  if(bridge_interface
     || is_dynamic_interface
     || isView())
    ;
  else
    companionQueue = new (std::nothrow) ParsedFlow*[COMPANION_QUEUE_LEN]();
  next_compq_insert_idx = next_compq_remove_idx = 0;

  PROFILING_INIT();
}

/* **************************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::initL7Policer() {
  /* Instantiate the policer */
  policer = new L7Policer(this);
}

/* **************************************** */

void NetworkInterface::aggregatePartialFlow(const struct timeval *tv, Flow *flow) {
  if(flow && aggregated_flows_hash)
    aggregated_flows_hash->aggregatePartialFlow(tv, flow);
}

#endif

/* **************************************************** */

void NetworkInterface::checkDisaggregationMode() {
  char rkey[128], rsp[16];

  if(customIftype || isSubInterface()) 
    return;

  snprintf(rkey, sizeof(rkey), CONST_IFACE_DYN_IFACE_MODE_PREFS, id);

  if((!ntop->getRedis()->get(rkey, rsp, sizeof(rsp))) && (rsp[0] != '\0')) {
    if(getIfType() == interface_type_ZMQ) { /* ZMQ interface */
      if(!strcmp(rsp, DISAGGREGATION_PROBE_IP)) flowHashingMode = flowhashing_probe_ip;
      else if(!strcmp(rsp, DISAGGREGATION_IFACE_ID))         flowHashingMode = flowhashing_iface_idx;
      else if(!strcmp(rsp, DISAGGREGATION_INGRESS_IFACE_ID)) flowHashingMode = flowhashing_ingress_iface_idx;
      else if(!strcmp(rsp, DISAGGREGATION_INGRESS_VRF_ID))   flowHashingMode = flowhashing_vrfid;
      else if(!strcmp(rsp, DISAGGREGATION_VLAN))             flowHashingMode = flowhashing_vlan;
      else if(strcmp(rsp,  DISAGGREGATION_NONE))
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown aggregation value for interface %s [rsp: %s]",
				     get_type(), rsp);
    } else { /* non-ZMQ interface */
      if(!strcmp(rsp, DISAGGREGATION_VLAN)) flowHashingMode = flowhashing_vlan;
      else if(strcmp(rsp,  DISAGGREGATION_NONE))
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown aggregation value for interface %s [rsp: %s]",
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

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  if (flowHashingMode == flowhashing_none)
    sub_interfaces = ntop->getPro()->has_valid_enterprise_license() ? new SubInterfaces(this) : NULL;
#endif
#endif
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

bool NetworkInterface::isRunning() const {
  return running
    && !ntop->getGlobals()->isShutdownRequested()
    && !ntop->getGlobals()->isShutdown();
}

/* **************************************************** */

bool NetworkInterface::getInterfaceBooleanPref(const char *pref_key, bool default_pref_value) const {
  char pref_buf[CONST_MAX_LEN_REDIS_KEY], rsp[2] = { 0 };
  bool interface_pref = default_pref_value;

  if(ntop->getRedis()) {
    snprintf(pref_buf, sizeof(pref_buf), pref_key, get_id());
    if((ntop->getRedis()->get(pref_buf, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0')) {
      if(rsp[0] == '1')
	interface_pref = true;
      else if(rsp[0] == '0')
	interface_pref = false;
    }
  }

#if 0 
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading pref [%s][ifid: %i][rsp: %s][actual_value: %d]", pref_buf, get_id(), rsp, interface_pref ? 1 : 0);
#endif

  return interface_pref;
}

/* **************************************************** */

void NetworkInterface::updateTrafficMirrored() {
  is_traffic_mirrored = getInterfaceBooleanPref(CONST_MIRRORED_TRAFFIC_PREFS, CONST_DEFAULT_MIRRORED_TRAFFIC);
}

/* **************************************************** */

void NetworkInterface::updateDynIfaceTrafficPolicy() {
  show_dynamic_interface_traffic = getInterfaceBooleanPref(CONST_SHOW_DYN_IFACE_TRAFFIC_PREFS, CONST_DEFAULT_SHOW_DYN_IFACE_TRAFFIC);
}

/* **************************************************** */

void NetworkInterface::updateFlowDumpDisabled() {
  flow_dump_disabled = getInterfaceBooleanPref(CONST_DISABLED_FLOW_DUMP_PREFS, false);
}

/* **************************************** */

void NetworkInterface::updateLbdIdentifier() {
  lbd_serialize_by_mac = getInterfaceBooleanPref(CONST_LBD_SERIALIZATION_PREFS, CONST_DEFAULT_LBD_SERIALIZE_AS_MAC);
}

/* **************************************** */

void NetworkInterface::updateDiscardProbingTraffic() {
  discard_probing_traffic = getInterfaceBooleanPref(CONST_DISCARD_PROBING_TRAFFIC, CONST_DEFAULT_DISCARD_PROBING_TRAFFIC);
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

  if(companionQueue) {
    for(u_int16_t i = 0; i < COMPANION_QUEUE_LEN; i++)
      if(companionQueue[i])
	delete companionQueue[i];

    delete []companionQueue;
    companionQueue = NULL;
  }
}

/* **************************************************** */

NetworkInterface::~NetworkInterface() {
  std::map<std::pair<AlertEntity, std::string>, AlertableEntity*>::iterator it;

#ifdef PROFILING
  u_int64_t n = ethStats.getNumIngressPackets();
  if(isPacketInterface() && n > 0) {
    for (u_int i = 0; i < PROFILING_NUM_SECTIONS; i++) {
      if(PROFILING_SECTION_LABEL(i) != NULL)
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
  if(alertsQueue)    delete alertsQueue;
  if(ndpiStats)      delete ndpiStats;
  if(networkStats) {
    u_int8_t numNetworks = ntop->getNumLocalNetworks();

    for(u_int8_t i = 0; i < numNetworks; i++)
      delete networkStats[i];

    delete []networkStats;
  }
  if(interfaceStats) delete interfaceStats;

  for(it = external_alerts.begin(); it != external_alerts.end(); ++it)
    delete it->second;
  external_alerts.clear();

  if(flowHashing) {
    FlowHashing *current, *tmp;

    HASH_ITER(hh, flowHashing, current, tmp) {
      /* Interfaces are deleted by the main termination function */
      HASH_DEL(flowHashing, current);
      free(current);
    }

    flowHashing = NULL;
  }

  delete frequentProtocols;
  delete frequentMacs;

#ifdef NTOPNG_PRO
  if(policer)               delete(policer);
#ifndef HAVE_NEDGE
  if(flow_profiles)         delete(flow_profiles);
  if(shadow_flow_profiles)  delete(shadow_flow_profiles);
  if(sub_interfaces)        delete(sub_interfaces);
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

void NetworkInterface::dumpAggregatedFlows(const struct timeval *tv) {
  aggregated_flows_dump_updates = 0;  /* Reset */

  if(aggregated_flows_hash)
    aggregated_flows_hash->cleanup();

#ifdef AGGREGATED_FLOW_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Aggregated flows exported. "
			       "Aggregated flows hash cleared. [num_items: %i]",
			       aggregated_flows_hash->getNumEntries());
#endif
}

/* **************************************************** */

void NetworkInterface::inc_aggregated_flows_dump_updates() {
  /* Given a periodicStatsUpdateFrequency(), that is, the number of seconds between consecutive
     calls to NetworkInterface::periodicStatsUpdate and the FLOW_AGGREGATION_DURATION, we
     can compute the number of times NetworkInterface::periodicStatsUpdate has to be called before
     aggregated flows can actually be dumped.
     Need to re-evaluate as the update frequency can change. */
  aggregated_flows_dump_max_updates = FLOW_AGGREGATION_DURATION / periodicStatsUpdateFrequency();

  /* Every time a NetworkInterface::periodicStatsUpdate is called, this
     method should be called to keep track of the number of updates necessary
     before actually dumping aggregated flows to database. */
  aggregated_flows_dump_updates++;
}

/* **************************************************** */

bool NetworkInterface::is_aggregated_flows_dump_ready() const {
  return aggregated_flows_dump_updates >= aggregated_flows_dump_max_updates;
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
    ((LocalHost*)host)->serializeToRedis();
    *matched = true;
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

int NetworkInterface::dumpLocalHosts2redis(bool disable_purge) {
  int rc;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  rc = walker(&begin_slot, walk_all,  walker_hosts,
	      local_hosts_2_redis_walker, NULL) ? 0 : -1;

#ifdef NTOPNG_PRO
  if(getHostPools()) getHostPools()->dumpToRedis();
#endif

  return(rc);
}

/* **************************************************** */

u_int32_t NetworkInterface::getHostsHashSize() {
  return(hosts_hash ? hosts_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getASesHashSize() {
  return(ases_hash ? ases_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getCountriesHashSize() {
  return(countries_hash ? countries_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getVLANsHashSize() {
  return(vlans_hash ? vlans_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getFlowsHashSize() {
  return(flows_hash ? flows_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getMacsHashSize() {
  return(macs_hash ? macs_hash->getNumEntries() : 0);
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

  if(id == SYSTEM_INTERFACE_ID)
    return(false);

  switch(wtype) {
  case walker_hosts:
    ret = hosts_hash ? hosts_hash->walk(begin_slot, walk_all, walker, user_data) : false;
    break;

  case walker_flows:
    ret = flows_hash ? flows_hash->walk(begin_slot, walk_all, walker, user_data) : false;
    break;

  case walker_macs:
    ret = macs_hash ? macs_hash->walk(begin_slot, walk_all, walker, user_data) : false;
    break;

  case walker_ases:
    ret = ases_hash ? ases_hash->walk(begin_slot, walk_all, walker, user_data) : false;
    break;

  case walker_countries:
    ret = countries_hash ? countries_hash->walk(begin_slot, walk_all, walker, user_data) : false;
    break;

  case walker_vlans:
    ret = vlans_hash ? vlans_hash->walk(begin_slot, walk_all, walker, user_data) : false;
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
				u_int32_t len_on_wire,
				bool *new_flow, bool create_if_missing) {
  Flow *ret;
  Mac *primary_mac;
  Host *srcHost = NULL, *dstHost = NULL;

  if(!flows_hash)
    return(NULL);

  if(vlan_id != 0)
    setSeenVlanTaggedPackets();

  if((srcMac && Utils::macHash(srcMac->get_mac()) != 0)
     || (dstMac && Utils::macHash(dstMac->get_mac()) != 0))
    setSeenMacAddresses();

  PROFILING_SECTION_ENTER("NetworkInterface::getFlow: flows_hash->find", 1);
  ret = flows_hash->find(src_ip, dst_ip, src_port, dst_port,
			 vlan_id, l4_proto, icmp_info, src2dst_direction,
			 true /* Inline call */);
  PROFILING_SECTION_EXIT(1);

  if(ret == NULL) {
    if(!create_if_missing)
      return(NULL);

    *new_flow = true;
    num_new_flows++;

    if(!flows_hash->hasEmptyRoom()) {
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many flows");
      has_too_many_flows = true;
      return(NULL);
    }

    try {
      PROFILING_SECTION_ENTER("NetworkInterface::getFlow: new Flow", 2);
      ret = new Flow(this, vlan_id, l4_proto,
		     srcMac, src_ip, src_port,
		     dstMac, dst_ip, dst_port,
		     icmp_info,
		     first_seen, last_seen);
      PROFILING_SECTION_EXIT(2);
    } catch(std::bad_alloc& ba) {
      static bool oom_warning_sent = false;

      if(!oom_warning_sent) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
	oom_warning_sent = true;
      }

      has_too_many_flows = true;
      return(NULL);
    }

    if(flows_hash->add(ret, false /* Don't lock, we're inline with the purgeIdle */)) {
      *src2dst_direction = true;
    } else {
      /* Note: this should never happen as we are checking hasEmptyRoom() */
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

bool NetworkInterface::registerSubInterface(NetworkInterface *sub_iface, u_int32_t criteria) {
  FlowHashing *h = NULL;

  h = (FlowHashing*)malloc(sizeof(FlowHashing));

  if (h == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    delete sub_iface; /* Note: deleting here as ntop->registerInterface is also deleting it on failure */
    return false;
  }

  if (!ntop->registerInterface(sub_iface)) 
    return false;

  sub_iface->setSubInterface();
  sub_iface->allocateStructures();

  ntop->initInterface(sub_iface);

  sub_iface->startPacketPolling(); /* Won't actually start a thread, just mark this interface as running */

  h->criteria = criteria;
  h->iface = sub_iface;

  HASH_ADD_INT(flowHashing, criteria, h);

  numSubInterfaces++;
  ntop->getRedis()->set(CONST_STR_RELOAD_LISTS, (const char * const)"1");

  return true;
}

/* **************************************************** */

NetworkInterface* NetworkInterface::getDynInterface(u_int32_t criteria, bool parser_interface) {
  NetworkInterface *sub_iface = NULL;
#ifndef HAVE_NEDGE
  FlowHashing *h = NULL;

  HASH_FIND_INT(flowHashing, &criteria, h);

  if(h != NULL) {

    sub_iface = h->iface;

  } else {
    /* Interface not found */

    if(numSubInterfaces < MAX_NUM_VIRTUAL_INTERFACES) {
      char buf[64], buf1[48];
      const char *vIface_type;

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

      if(dynamic_cast<ZMQParserInterface*>(this))
        sub_iface = new ZMQParserInterface(buf, vIface_type);
      else if(dynamic_cast<SyslogParserInterface*>(this))
        sub_iface = new SyslogParserInterface(buf, vIface_type);
      else
        sub_iface = new NetworkInterface(buf, vIface_type);

      if(sub_iface) {
        if (!this->registerSubInterface(sub_iface, criteria)) {
          ntop->getTrace()->traceEvent(TRACE_WARNING, "Failure registering sub-interface");
          sub_iface = NULL;
        }
      } else {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Failure allocating interface: not enough memory?");
      }
    }
  }
#endif

  return(sub_iface);
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
				     u_int16_t ip_offset,
				     u_int32_t len_on_wire,
				     const struct pcap_pkthdr *h,
				     const u_char *packet,
				     u_int16_t *ndpiProtocol,
				     Host **srcHost, Host **dstHost,
				     Flow **hostFlow) {
  u_int16_t trusted_ip_len = max_val(0, (int)h->caplen - ip_offset);
  u_int16_t trusted_payload_len = 0;
  bool src2dst_direction;
  u_int8_t l4_proto;
  Flow *flow;
  Mac *srcMac = NULL, *dstMac = NULL;
  IpAddress src_ip, dst_ip;
  ICMPinfo icmp_info;
  u_int16_t src_port = 0, dst_port = 0;
  struct ndpi_tcphdr *tcph = NULL;
  struct ndpi_udphdr *udph = NULL;
  struct sctphdr *sctph    = NULL;
  u_int16_t trusted_l4_packet_len;
  u_int8_t *l4, tcp_flags = 0, *payload = NULL;
  u_int8_t *ip;
  bool is_fragment = false, new_flow;
  bool pass_verdict = true;
  u_int16_t l4_len = 0;
  *hostFlow = NULL;

  if(!isSubInterface()) {
    if(flowHashingMode == flowhashing_none) {
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
      /* Custom disaggregation */
      if(sub_interfaces && sub_interfaces->getNumSubInterfaces() > 0) {
        bool processed = sub_interfaces->processPacket(bridge_iface_idx,
						       ingressPacket, when, packet_time,
						       eth, vlan_id,
						       iph, ip6,
						       ip_offset,
						       len_on_wire,
						       h, packet, ndpiProtocol,
						       srcHost, dstHost, hostFlow);
     
        if(processed && !showDynamicInterfaceTraffic()) { 
          incStats(ingressPacket, when->tv_sec, ETHERTYPE_IP,
	           NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	           0,
	           len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);

          return(pass_verdict);
        }
      }
#endif
#endif
    } else {
      /* VLAN disaggregation */
      if(flowHashingMode == flowhashing_vlan && vlan_id > 0) {
        NetworkInterface *vIface;

        if((vIface = getDynInterface((u_int32_t)vlan_id, false)) != NULL) {
          bool ret;

          vIface->setTimeLastPktRcvd(h->ts.tv_sec);
          ret = vIface->processPacket(bridge_iface_idx,
				      ingressPacket, when, packet_time,
				      eth, vlan_id,
				      iph, ip6,
				      ip_offset,
				      len_on_wire,
				      h, packet, ndpiProtocol,
				      srcHost, dstHost, hostFlow);

          if (!showDynamicInterfaceTraffic()) {
            incStats(ingressPacket, when->tv_sec, ETHERTYPE_IP,
	             NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	             0,
	             len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);

            return(ret);
          }
        }
      }
    }
  }

  if((srcMac = getMac(eth->h_source, true /* Create if missing */, true /* Inline call */))) {
    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
    srcMac->incSentStats(getTimeLastPktRcvd(), 1, len_on_wire);
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

  if((dstMac = getMac(eth->h_dest, true /* Create if missing */, true /* Inline call */))) {
    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
    dstMac->incRcvdStats(getTimeLastPktRcvd(), 1, len_on_wire);
#endif
  }

  if(iph != NULL) {
    u_int16_t ip_len, ip_tot_len;

    /* IPv4 */
    if(trusted_ip_len < 20) {
      incStats(ingressPacket,
	       when->tv_sec, ETHERTYPE_IP,
	       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0,
	       len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }

    ip_len = iph->ihl * 4;
    ip_tot_len = ntohs(iph->tot_len);

    /* Use the actual h->len and not the h->caplen to determine
       whether a packet is fragmented. */
    if(ip_len > (int)h->len - ip_offset
       || (int)h->len - ip_offset < ip_tot_len
       || (iph->frag_off & htons(0x1FFF /* IP_OFFSET */))
       || (iph->frag_off & htons(0x2000 /* More Fragments: set */)))
      is_fragment = true;

    l4_proto = iph->protocol;
    l4 = ((u_int8_t *) iph + ip_len);
    l4_len = ip_tot_len - ip_len; /* use len from the ip header to compute sequence numbers */

    ip = (u_int8_t*)iph;
  } else {
    /* IPv6 */
    u_int ipv6_shift = sizeof(const struct ndpi_ipv6hdr);

    if(trusted_ip_len < sizeof(const struct ndpi_ipv6hdr)) {
      incStats(ingressPacket,
	       when->tv_sec, ETHERTYPE_IPV6,
	       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0,
	       len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }

    l4_proto = ip6->ip6_hdr.ip6_un1_nxt;

    if((l4_proto == 0x3C /* IPv6 destination option */) ||
	(l4_proto == 0x0 /* Hop-by-hop option */)) {
      u_int8_t *options = (u_int8_t*)ip6 + ipv6_shift;

      l4_proto = options[0];
      ipv6_shift += 8 * (options[1] + 1);

      if(trusted_ip_len < ipv6_shift) {
	incStats(ingressPacket,
		 when->tv_sec, ETHERTYPE_IPV6,
		 NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		 0,
		 len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	return(pass_verdict);
      }
    }

    l4 = (u_int8_t*)ip6 + ipv6_shift;
    l4_len = packet + h->len - l4;
    ip = (u_int8_t*)ip6;
  }

  trusted_l4_packet_len = packet + h->caplen - l4;

  if(l4_proto == IPPROTO_TCP) {
    if(trusted_l4_packet_len >= sizeof(struct ndpi_tcphdr)) {
      u_int tcp_len;

      /* TCP */
      tcph = (struct ndpi_tcphdr *)l4;
      src_port = tcph->source, dst_port = tcph->dest;
      tcp_flags = l4[13];
      tcp_len = min_val(4 * tcph->doff, trusted_l4_packet_len);
      payload = &l4[tcp_len];
      trusted_payload_len = trusted_l4_packet_len - tcp_len;
      // TODO: check if payload should be set to NULL when trusted_payload_len == 0
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid TCP packet received [%u bytes long]", trusted_l4_packet_len);
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }
  } else if(l4_proto == IPPROTO_UDP) {
    if(trusted_l4_packet_len >= sizeof(struct ndpi_udphdr)) {
      /* UDP */
      udph = (struct ndpi_udphdr *)l4;
      src_port = udph->source,  dst_port = udph->dest;
      payload = &l4[sizeof(struct ndpi_udphdr)];
      trusted_payload_len = trusted_l4_packet_len - sizeof(struct ndpi_udphdr);
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid UDP packet received [%u bytes long]", trusted_l4_packet_len);
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }
  } else if(l4_proto == IPPROTO_SCTP) {
    if(trusted_l4_packet_len >= sizeof(struct sctphdr)) {
      /* SCTP */
      sctph = (struct sctphdr *)l4;
      src_port = sctph->sport,  dst_port = sctph->dport;

      payload = &l4[sizeof(struct sctphdr)];
      trusted_payload_len = trusted_l4_packet_len - sizeof(struct sctphdr);
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(TRACE_INFO, "Invalid SCTP packet received [%u bytes long]", trusted_l4_packet_len);
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      return(pass_verdict);
    }
  } else if(l4_proto == IPPROTO_ICMP) {
    icmp_info.dissectICMP(trusted_l4_packet_len, l4);
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

  PROFILING_SECTION_ENTER("NetworkInterface::processPacket: getFlow", 0);
  /* Updating Flow */
  flow = getFlow(srcMac, dstMac, vlan_id, 0, 0, 0,
		 l4_proto == IPPROTO_ICMP ? &icmp_info : NULL,
		 &src_ip, &dst_ip, src_port, dst_port,
		 l4_proto, &src2dst_direction, last_pkt_rcvd, last_pkt_rcvd, len_on_wire, &new_flow, true);
  PROFILING_SECTION_EXIT(0);

  if(flow == NULL) {
    incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	     NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	     l4_proto, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
			    tcp_flags, l4_len - (4 * tcph->doff),
			    src2dst_direction);
      break;

    case IPPROTO_ICMP:
    case IPPROTO_ICMPV6:
      if(trusted_l4_packet_len > 2) {
	u_int8_t icmp_type = l4[0];
	u_int8_t icmp_code = l4[1];

        flow->setICMP(src2dst_direction, icmp_type, icmp_code, l4);
	flow->setICMPPayloadSize(trusted_l4_packet_len);
      }
      break;
    }

#ifndef HAVE_NEDGE
#ifdef __OpenBSD__
    struct timeval tv_ts;

    tv_ts.tv_sec  = h->ts.tv_sec;
    tv_ts.tv_usec = h->ts.tv_usec;

    flow->incStats(src2dst_direction, len_on_wire, payload,
		   trusted_payload_len, l4_proto, is_fragment,
		   tcp_flags, &tv_ts);
#else
    flow->incStats(src2dst_direction, len_on_wire, payload,
		   trusted_payload_len, l4_proto, is_fragment,
		   tcp_flags, &h->ts);
#endif
#endif
  }

  /* Protocol Detection */
  flow->updateInterfaceLocalStats(src2dst_direction, 1, len_on_wire);

  if(!flow->isDetectionCompleted() || flow->needsExtraDissection()) {
    if(!is_fragment) {
      /* NOTE: can be NULL */
      struct ndpi_flow_struct *ndpi_flow = flow->get_ndpi_flow();
      struct ndpi_id_struct *cli = (struct ndpi_id_struct*)flow->get_cli_id();
      struct ndpi_id_struct *srv = (struct ndpi_id_struct*)flow->get_srv_id();

      if(flow->hasDissectedTooManyPackets()) {
	u_int8_t proto_guessed;
	
	flow->setDetectedProtocol(ndpi_detection_giveup(get_ndpi_struct(), ndpi_flow, 1, &proto_guessed), false);
      } else {
	flow->setDetectedProtocol(ndpi_detection_process_packet(get_ndpi_struct(), ndpi_flow,
								ip, trusted_ip_len, (u_int32_t)packet_time,
								cli, srv), false);
      }
    } else {
      // FIX - only handle unfragmented packets
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "IP fragments are not handled yet!");
    }
  }

  if(flow->isDetectionCompleted()
     && (!isSampledTraffic())) {
    switch(ndpi_get_lower_proto(flow->get_detected_protocol())) {
    case NDPI_PROTOCOL_DHCP:
      if(*srcHost) {
	Mac *mac = (*srcHost)->getMac(), *payload_cli_mac;

	if(mac && (trusted_payload_len > 240)) {
	  struct dhcp_packet *dhcpp = (struct dhcp_packet*)payload;

	  if(dhcpp->msgType == 0x01) /* Request */
	    ;//mac->setDhcpHost();
	  else if(dhcpp->msgType == 0x02) { /* Reply */
	    checkMacIPAssociation(false, dhcpp->chaddr, dhcpp->yiaddr);
	    checkDhcpIPRange(mac, dhcpp, vlan_id);
	    setDHCPAddressesSeen();
	  }

	  for(u_int32_t i = 240; i<trusted_payload_len; ) {
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

	      if((payload_cli_mac = getMac(&payload[28], false /* Do not create if missing */, true /* Inline call */)))
		payload_cli_mac->inlineSetDHCPName(name);

#ifdef DHCP_DEBUG
	      ntop->getTrace()->traceEvent(TRACE_WARNING, "[DHCP] %s = '%s'", client_mac, name);
#endif
	    } else if((id == 55 /* Parameters List (Fingerprint) */) && flow->get_ndpi_flow()) {
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
      if(*srcHost && *dstHost){
	Mac *src_mac = (*srcHost)->getMac();
	Mac *dst_mac = (*dstHost)->getMac();

	if(src_mac && dst_mac
	   && (trusted_payload_len > 20)
	   && dst_mac->isMulticast())
	  ;//src_mac->setDhcpHost();
      }
      break;

    case NDPI_PROTOCOL_NETBIOS:
      flow->dissectNetBIOS(payload, trusted_payload_len);
      break;

    case NDPI_PROTOCOL_BITTORRENT:
      if((flow->getBitTorrentHash() == NULL)
	 && (l4_proto == IPPROTO_UDP)
	 && (flow->get_packets() < 8))
	flow->dissectBittorrent((char*)payload, trusted_payload_len);
      break;

    case NDPI_PROTOCOL_HTTP:
      if(trusted_payload_len > 0)
	flow->dissectHTTP(src2dst_direction, (char*)payload, trusted_payload_len);
      break;

    case NDPI_PROTOCOL_SSDP:
      if(trusted_payload_len > 0)
	flow->dissectSSDP(src2dst_direction, (char*)payload, trusted_payload_len);
      break;

    case NDPI_PROTOCOL_DNS:
      /*
	DNS-over-TCP flows may carry zero-payload TCP segments
	e.g., during three-way-handshake, or when acknowledging.
	Make sure only non-zero-payload segments are processed.
      */
      if((trusted_payload_len > 0) && payload) {
	flow->dissectDNS(src2dst_direction, (char*)payload, trusted_payload_len);
	/*
	  DNS-over-TCP has a 2-bytes field with DNS payload length
	  at the beginning. See RFC1035 section 4.2.2. TCP usage.
	*/
      }

      break;

    case NDPI_PROTOCOL_MDNS:
#ifdef MDNS_TEST
      extern void _dissectMDNS(u_char *buf, u_int buf_len, char *out, u_int out_len);
      char outbuf[1024];

      _dissectMDNS(payload, trusted_payload_len, outbuf, sizeof(outbuf));
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", outbuf);
#endif
      flow->dissectMDNS(payload, trusted_payload_len);

      if(discovery && iph)
	discovery->queueMDNSRespomse(iph->saddr, payload, trusted_payload_len);
      break;
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

  incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	   flow->getStatsProtocol(), flow->get_protocol_category(),
	   l4_proto, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);

  return(pass_verdict);
}

/* **************************************************** */

void NetworkInterface::purgeIdle(time_t when, bool force_idle) {
  if(purge_idle_flows_hosts) {
    u_int n, m, o;

    last_pkt_rcvd = when;

    if((n = purgeIdleFlows(force_idle)) > 0)
      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Purged %u/%u idle flows on %s",
				   n, getNumFlows(), ifname);

    if((m = purgeIdleHosts(force_idle)) > 0)
      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Purged %u/%u idle hosts on %s",
				   m, getNumHosts(), ifname);

    if((o = purgeIdleMacsASesCountriesVlansArpMatrix(force_idle)) > 0)      
      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Purged %u idle ASs, MAC, Countries, VLANs... on %s",
				   o, ifname);
  }

  if(flowHashing) {
    FlowHashing *current, *tmp;

    HASH_ITER(hh, flowHashing, current, tmp) {
      if(current->iface)
	current->iface->purgeIdle(when, force_idle);
    }
  }
}

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
  u_int32_t len_on_wire = h->len * scalingFactor;
  *flow = NULL;

  /* Note summy ethernet is always 0 unless sender_mac is set (Netfilter only) */
  memset(&dummy_ethernet, 0, sizeof(dummy_ethernet));

  pollQueuedeCompanionEvents();
  bcast_domains->inlineReloadBroadcastDomains();

  /* Netfilter interfaces don't report MAC addresses on packets */
  if(getIfType() == interface_type_NETFILTER)
    len_on_wire += sizeof(struct ndpi_ethhdr);

  if(h->len > ifMTU) {
    if(!mtuWarningShown) {
#ifdef __linux__
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Invalid packet received [len: %u][max len: %u].", h->len, ifMTU);
      if(!read_from_pcap_dump()) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "If you have TSO/GRO enabled, please disable it");
        if(strchr(ifname, ':') == NULL) /* print ethtool command for standard interfaces only */
          ntop->getTrace()->traceEvent(TRACE_WARNING, "Use sudo ethtool -K %s gro off gso off tso off", ifname);
      }
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
      incStats(ingressPacket, h->ts.tv_sec, 0,
	       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      goto dissect_packet_end; /* Any other non IP protocol */
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
      incStats(ingressPacket, h->ts.tv_sec, 0,
	       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      goto dissect_packet_end; /* Unknown IP protocol version */
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
    incStats(ingressPacket, h->ts.tv_sec, 0,
	     NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	     0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    goto dissect_packet_end;
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
	       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
      goto dissect_packet_end;
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
		 NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		 0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	goto dissect_packet_end;
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
      } else if(ntop->getGlobals()->decode_tunnels()
		&& iph->protocol == IPPROTO_IPV6
		&& h->caplen >= ip_offset + ip_len + sizeof(struct ndpi_ipv6hdr)) {
	/* Detunnel 6in4 tunnel */
	ip_offset += ip_len;
	eth_type = ETHERTYPE_IPV6;
	goto decode_packet_eth;
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
		       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      goto dissect_packet_end;
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
		incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6,
			 NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
			 0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
		goto dissect_packet_end;
	      } else {
		eth_offset = offset;
		goto datalink_check;
	      }
	    }
	  }
	} else if(dport == VXLAN_PORT) {
          eth_offset = ip_offset+ip_len+sizeof(struct ndpi_udphdr)+sizeof(struct ndpi_vxlanhdr);
          goto datalink_check;
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
	    incStats(ingressPacket, h->ts.tv_sec, 0,
		     NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		     0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    goto dissect_packet_end;
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
	    incStats(ingressPacket, h->ts.tv_sec, 0,
		     NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		     0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    goto dissect_packet_end;
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
	pass_verdict = processPacket(bridge_iface_idx,
				     ingressPacket, &h->ts, time,
				     ethernet,
				     vlan_id, iph,
				     ip6,
				     ip_offset,
				     len_on_wire,
				     h, packet, ndpiProtocol, srcHost, dstHost, flow);
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
	incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6,
		 NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		 0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	goto dissect_packet_end;
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
	    incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6,
		     NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		     0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    goto dissect_packet_end;
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
	      incStats(ingressPacket, h->ts.tv_sec, 0,
		       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      goto dissect_packet_end;
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
	      incStats(ingressPacket, h->ts.tv_sec, 0,
		       NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
		       0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      goto dissect_packet_end;
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
	  pass_verdict = processPacket(bridge_iface_idx,
				       ingressPacket, &h->ts, time,
				       ethernet,
				       vlan_id,
				       iph, ip6,
				       ip_offset,
				       len_on_wire,
				       h, packet, ndpiProtocol, srcHost, dstHost, flow);
	  
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

    Mac *srcMac = getMac(ethernet->h_source, true /* Create if missing */, true /* Inline call */);
    Mac *dstMac = getMac(ethernet->h_dest, true /* Create if missing */, true /* Inline call */);

    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
    if(srcMac) srcMac->incSentStats(h->ts.tv_sec, 1, len_on_wire);
    if(dstMac) dstMac->incRcvdStats(h->ts.tv_sec, 1, len_on_wire);
#endif

    if((eth_type == ETHERTYPE_ARP) && (h->caplen >= (sizeof(arp_header) + sizeof(struct ndpi_ethhdr)))) {
      struct arp_header *arpp = (struct arp_header*)&packet[ip_offset];
      u_int16_t arp_opcode = ntohs(arpp->ar_op);
      bool src2dst_element = false;
      ArpStatsMatrixElement* e;

      u_int32_t src = ntohl(arpp->arp_spa);
      u_int32_t dst = ntohl(arpp->arp_tpa);
      u_int32_t net = src & dst;
      u_int32_t diff;
      IpAddress cur_bcast_domain;

      if(src > dst) {
	u_int32_t r = src;
	src = dst;
	dst = r;
      }

      diff = dst - src;

      /*
	Following is an heuristic which tries to detect the broadcast domain
	with its size and network-part of the address. Detection is done by checking
	source and target protocol addresses found in arp.

	Link-local addresses are excluded, as well as arp Probes with a zero source IP.

	ARP Probes are defined in RFC 5227:
	In this document, the term 'ARP Probe' is used to refer to an ARP
	Request packet, broadcast on the local link, with an all-zero 'sender
	IP address'.  [...]  The 'target IP
	address' field MUST be set to the address being probed.  An ARP Probe
	conveys both a question ("Is anyone using this address?") and an
	implied statement ("This is the address I hope to use.").
      */

      if(diff
	 && src /* Not a zero source IP (ARP Probe) */
	 && (src & 0xFFFF0000) != 0xA9FE0000 /* Not a link-local IP */
	 && (dst & 0xFFFF0000) != 0xA9FE0000 /* Not a link-local IP */) {
	u_int32_t cur_mask;
	u_int8_t cur_cidr;

	for(cur_mask = 0xFFFFFFF0, cur_cidr = 28; cur_mask > 0x00000000; cur_mask <<= 1, cur_cidr--) {
	  if((diff & cur_mask) == 0) { /* diff < cur_mask */
	    net &= cur_mask;

	    if((src & cur_mask) != (dst & cur_mask)) {
	      cur_mask <<= 1, cur_cidr -= 1;
	      net = src & cur_mask;
	    }

	    cur_bcast_domain.set(htonl(net));

	    if(!checkBroadcastDomainTooLarge(cur_mask, vlan_id, ethernet->h_source, ethernet->h_dest, src, dst)) {
	      /* NOTE: call this also for existing domains in order to update the hits */
	      bcast_domains->inlineAddAddress(&cur_bcast_domain, cur_cidr);

#ifdef BROADCAST_DOMAINS_DEBUG
	      char buf1[32], buf2[32], buf3[32];
	      ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s <-> %s [%s - %u]",
					   Utils::intoaV4(src, buf1, sizeof(buf1)),
					   Utils::intoaV4(dst, buf2, sizeof(buf2)),
					   Utils::intoaV4(net, buf3, sizeof(buf3)),
					   cur_cidr);
#endif
	    }

	    break;
	  }
	}
      }

      if(srcMac && dstMac && (!srcMac->isNull() || !dstMac->isNull())) {
	setSeenMacAddresses();
	srcMac->setSourceMac();
	
	e = getArpHashMatrixElement(srcMac->get_mac(), dstMac->get_mac(),
				    src, dst,
				    &src2dst_element);

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

    incStats(ingressPacket, h->ts.tv_sec, eth_type,
	     NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	     0, len_on_wire, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    break;
  }

 dissect_packet_end:

  /* Live packet dump to mongoose */
  if(num_live_captures > 0)
    deliverLiveCapture(h, packet, *flow);

  return(pass_verdict);
}

/* **************************************************** */

void NetworkInterface::pollQueuedeCompanionEvents() {
  if(companionQueue) {
    ParsedFlow *dequeued = NULL;

    if(dequeueFlowFromCompanion(&dequeued)) {
      Flow *flow = NULL;
      bool src2dst_direction, new_flow;
 
      flow = getFlow(NULL /* srcMac */, NULL /* dstMac */,
		     0 /* vlan_id */,
		     0 /* deviceIP */,
		     0 /* inIndex */, 1 /* outIndex */,
		     NULL /* ICMPinfo */,
		     &dequeued->src_ip, &dequeued->dst_ip,
		     dequeued->src_port, dequeued->dst_port,
		     dequeued->l4_proto,
		     &src2dst_direction,
		     0, 0, 0, &new_flow,
		     true /* create_if_missing */);

      if(flow) {
#if 0
	char buf[128];
	flow->print(buf, sizeof(buf));
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Updating flow process info: [new flow: %u][src2dst_direction: %u] %s",
				     new_flow ? 1 : 0,
				     src2dst_direction ? 1 : 0, buf);
#endif

	if(new_flow)
	  flow->updateSeen();

        if(dequeued->getAdditionalFieldsJSON()) {
          flow->setJSONInfo(dequeued->getAdditionalFieldsJSON());
        }

        if(dequeued->external_alert) {
          /* Flow from SyslogParserInterface (Suricata) */
          enum json_tokener_error jerr = json_tokener_success;
          json_object *o = json_tokener_parse_verbose(dequeued->external_alert, &jerr);
          if(o) flow->setExternalAlert(o);
        }

        if(dequeued->process_info_set || 
           dequeued->container_info_set || 
           dequeued->tcp_info_set) {
          /* Flow from ZMQParserInterface (nProbe Agent) */
	  flow->setParsedeBPFInfo(dequeued, src2dst_direction);
        }
      }

      delete dequeued;
    }

    return;
  }
}

/* **************************************************** */

void NetworkInterface::startPacketPolling() {
  if(pollLoopCreated) {
    if((cpu_affinity != -1) && (ntop->getNumCPUs() > 1)) {
      if(Utils::setThreadAffinity(pollLoop, cpu_affinity))
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Couldn't set affinity of interface %s to core %d",
				     get_name(), cpu_affinity);
      else
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting affinity of interface %s to core %d",
				     get_name(), cpu_affinity);
    }

#ifdef __linux__
    char buf[16];
    snprintf(buf, sizeof(buf), "inline ifid %u", get_id());
    pthread_setname_np(pollLoop, buf);
#endif
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Started packet polling on interface %s [id: %u]...",
			       get_name(), get_id());

  running = true;
}

/* **************************************************** */

void NetworkInterface::shutdown() {
  void *res;

  if(running) {
    running = false;
    pthread_join(pollLoop, &res);
    /* purgeIdle one last time to make sure all entries will be marked as idle */
    purgeIdle(time(NULL), true);
  }
}

/* **************************************************** */

void NetworkInterface::cleanup() {
  next_idle_flow_purge = next_idle_host_purge = 0;
  cpu_affinity = -1,
    has_vlan_packets = false, has_ebpf_events = false, has_mac_addresses = false;
  has_seen_dhcp_addresses = false;
  running = false, inline_interface = false;
  has_seen_containers = false, has_seen_pods = false;

  getStats()->cleanup();
  if(flows_hash)      flows_hash->cleanup();
  if(hosts_hash)      hosts_hash->cleanup();
  if(ases_hash)       ases_hash->cleanup();
  if(countries_hash)  countries_hash->cleanup();
  if(vlans_hash)      vlans_hash->cleanup();
  if(macs_hash)       macs_hash->cleanup();
  if(arp_hash_matrix) arp_hash_matrix->cleanup();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Cleanup interface %s", get_name());
}

/* **************************************************** */

void NetworkInterface::findFlowHosts(u_int16_t vlanId,
				     Mac *src_mac, IpAddress *_src_ip, Host **src,
				     Mac *dst_mac, IpAddress *_dst_ip, Host **dst) {
  int16_t local_network_id;

  if(!hosts_hash) {
    *src = *dst = NULL;
    return;
  }

  PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: hosts_hash->get", 3);
  /* Do not look on sub interfaces, Flows are always created in the same interface of its hosts */
  (*src) = hosts_hash->get(vlanId, _src_ip, true /* Inline call */);
  PROFILING_SECTION_EXIT(3);

  if((*src) == NULL) {
    if(!hosts_hash->hasEmptyRoom()) {
      *src = *dst = NULL;
      has_too_many_hosts = true;
      return;
    }

    if(_src_ip && (_src_ip->isLocalHost(&local_network_id) || _src_ip->isLocalInterfaceAddress())) {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: new LocalHost", 4);
      (*src) = new (std::nothrow) LocalHost(this, src_mac, vlanId, _src_ip);
      PROFILING_SECTION_EXIT(4);
    } else {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: new RemoteHost", 5);
      (*src) = new (std::nothrow) RemoteHost(this, src_mac, vlanId, _src_ip);
      PROFILING_SECTION_EXIT(5);
    }

    if(*src) {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: hosts_hash->add", 6);
      bool add_res = hosts_hash->add(*src, false /* Don't lock, we're inline with the purgeIdle */);
      PROFILING_SECTION_EXIT(6);

      if(!add_res) {
	//ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
	delete *src;
	*src = *dst = NULL;
	has_too_many_hosts = true;
	return;
      }

      has_too_many_hosts = false;
    }
  }

  /* ***************************** */

  PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: hosts_hash->get", 3);
  (*dst) = hosts_hash->get(vlanId, _dst_ip, true /* Inline call */);
  PROFILING_SECTION_EXIT(3);

  if((*dst) == NULL) {
    if(!hosts_hash->hasEmptyRoom()) {
      *dst = NULL;
      has_too_many_hosts = true;
      return;
    }

    if(_dst_ip
       && (_dst_ip->isLocalHost(&local_network_id)
	   || _dst_ip->isLocalInterfaceAddress())) {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: new LocalHost", 4);
      (*dst) = new (std::nothrow) LocalHost(this, dst_mac, vlanId, _dst_ip);
      PROFILING_SECTION_EXIT(4);
    } else {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: new RemoteHost", 5);
      (*dst) = new (std::nothrow) RemoteHost(this, dst_mac, vlanId, _dst_ip);
      PROFILING_SECTION_EXIT(5);
    }

    if(*dst) {
      PROFILING_SECTION_ENTER("NetworkInterface::findFlowHosts: hosts_hash->add", 6);
      bool add_res = hosts_hash->add(*dst, false /* Don't lock, we're inline with the purgeIdle */);
      PROFILING_SECTION_EXIT(6);

      if(!add_res) {
	// ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
	delete *dst;
	*dst = NULL;
	has_too_many_hosts = true;
	return;
      }

      has_too_many_hosts = false;
    }
  }
}

/* **************************************************** */

static bool host_flow_update_stats(GenericHashEntry *node, void *user_data, bool *matched) {
  periodic_stats_update_user_data_t *periodic_stats_update_user_data = (periodic_stats_update_user_data_t*)user_data;

  node->periodic_stats_update(periodic_stats_update_user_data);

  *matched = true;

  return(false); /* false = keep on walking */
}

/* **************************************************** */

/* NOTE: mac is not a GenericTrafficElement */
static bool update_macs_stats(GenericHashEntry *node, void *user_data, bool *matched) {
  Mac *mac = (Mac*)node;
  periodic_stats_update_user_data_t *periodic_stats_update_user_data = (periodic_stats_update_user_data_t*)user_data;
  struct timeval *tv = periodic_stats_update_user_data->tv;

  mac->updateStats(tv);

  *matched = true;
 
  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool update_generic_element_stats(GenericHashEntry *node, void *user_data, bool *matched) {
  GenericTrafficElement *elem;
  periodic_stats_update_user_data_t *periodic_stats_update_user_data = (periodic_stats_update_user_data_t*)user_data;
  struct timeval *tv = periodic_stats_update_user_data->tv;

  if((elem = dynamic_cast<GenericTrafficElement*>(node))) {

    elem->updateStats(tv);
    *matched = true;
  } else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "update_generic_element_stats on non GenericTrafficElement");

  return(false); /* false = keep on walking */
}

/* **************************************************** */

bool NetworkInterface::checkPeriodicStatsUpdateTime(const struct timeval *tv) {
  float diff = Utils::msTimevalDiff(tv, &last_periodic_stats_update) / 1000;

  if(diff < 0 /* Need a reset */
     || diff >= periodicStatsUpdateFrequency()
     || read_from_pcap_dump_done()) {
    memcpy(&last_periodic_stats_update, tv, sizeof(last_periodic_stats_update));
    return true;
  }
    
  return false;
}

/* **************************************************** */

u_int32_t NetworkInterface::periodicStatsUpdateFrequency() const {
  return ntop->getPrefs()->get_housekeeping_frequency();
}

/* **************************************************** */

void NetworkInterface::periodicUpdateInitTime(struct timeval *tv) const {
  if(getIfType() != interface_type_PCAP_DUMP)
    gettimeofday(tv, NULL);
  else
    tv->tv_sec = last_pkt_rcvd, tv->tv_usec = 0;
}

/* **************************************************** */

u_int32_t NetworkInterface::getFlowMaxIdle() {
  return ntop->getPrefs()->get_pkt_ifaces_flow_max_idle();
}

/* **************************************************** */

void NetworkInterface::periodicStatsUpdate() {
#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][%s]", __FUNCTION__, get_name());
#endif

  u_int32_t begin_slot;
  periodic_stats_update_user_data_t periodic_stats_update_user_data;
  struct timeval tv;

  periodicUpdateInitTime(&tv);
  periodic_stats_update_user_data.tv = &tv;
    
  if(!checkPeriodicStatsUpdateTime(&tv))
    return; /* Not yet the time to perform an update */

#ifdef NTOPNG_PRO
  inc_aggregated_flows_dump_updates();
#endif

  /* View Interfaces don't have flows, they just walk flows of their 'viewed' peers */
  if((!isView()) && flows_hash) {
    begin_slot = 0;
    walker(&begin_slot, true, walker_flows, host_flow_update_stats, &periodic_stats_update_user_data);
  }

  if(hosts_hash) {
    begin_slot = 0;
    walker(&begin_slot, true, walker_hosts, host_flow_update_stats, &periodic_stats_update_user_data);
  }

  if(ases_hash) {
    begin_slot = 0;
    walker(&begin_slot, true, walker_ases, update_generic_element_stats, &periodic_stats_update_user_data);
  }

  if(countries_hash) {
    begin_slot = 0;
    walker(&begin_slot, true, walker_countries, update_generic_element_stats, &periodic_stats_update_user_data);
  }

  if(vlans_hash && hasSeenVlanTaggedPackets()) {
    begin_slot = 0;
    walker(&begin_slot, true, walker_vlans, update_generic_element_stats, &periodic_stats_update_user_data);
  }

  if(macs_hash) {
    begin_slot = 0;
    walker(&begin_slot, true, walker_macs, update_macs_stats, &periodic_stats_update_user_data);
  }

#ifdef NTOPNG_PRO
  if(getHostPools()) getHostPools()->checkPoolsStatsReset();
#endif

  updatePacketsStats();

  bytes_thpt.updateStats(&tv, getNumBytes());
  pkts_thpt.updateStats(&tv, getNumPackets());
  ethStats.updateStats(&tv);
  ndpiStats->updateStats(&tv);

  topItemsCommit(&tv);

#ifdef NTOPNG_PRO
  if(is_aggregated_flows_dump_ready()) 
    dumpAggregatedFlows(&tv);
#endif

  checkReloadHostsBroadcastDomain();

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

  if(host_pools)
    host_pools->updateStats(&tv);

  for(u_int8_t network_id = 0; network_id < ntop->getNumLocalNetworks(); network_id++) {
    if(NetworkStats *ns = getNetworkStats(network_id))
      ns->updateStats(&tv);
  }

  if(!ts_ring && TimeseriesRing::isRingEnabled(this))
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
     (time(NULL) - tv.tv_sec) > periodicStatsUpdateFrequency())
    slow_stats_update = true;
  else
    slow_stats_update = false;

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  gettimeofday(&tdebug, NULL);
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Stats update done [took: %d]", tdebug.tv_sec - tdebug_init.tv_sec);
#endif
}

/* **************************************************** */

bool NetworkInterface::generic_periodic_hash_entry_state_update(GenericHashEntry *node, void *user_data) {
  periodic_ht_state_update_user_data_t *periodic_ht_state_update_user_data = (periodic_ht_state_update_user_data_t*)user_data;
  NetworkInterface *iface = periodic_ht_state_update_user_data->iface;

  node->periodic_hash_entry_state_update(user_data);

  /* If this is a viewed interface, it is necessary to also call this method
     for the overlying view interface to make sure its counters (e.g., hosts, ases, vlans)
     are properly updated. There's no need to lock or syncronize as it is the view which
     triggers this call for every viewed interface sequentially. */
  if(iface->isViewed())
    iface->viewedBy()->generic_periodic_hash_entry_state_update(node, user_data);

  return false; // TODO: possibly need to rework this to the caller can ignore the return value
}

/* **************************************************** */

/* For viewed interfaces, this method is executed by the ViewInterface for each
   of its underlying viewed interfaces. */
void NetworkInterface::periodicHTStateUpdate(time_t deadline, lua_State* vm, bool skip_user_scripts) {
#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Updating hash tables [%s]", get_name());
#endif
  struct timeval tv;
  periodic_ht_state_update_user_data_t periodic_ht_state_update_user_data;
  GenericHash *ghs[] = {
			!isView() ? flows_hash : NULL, /* View Interfaces don't have flows, they just walk flows of their 'viewed' peers */
			hosts_hash,
			ases_hash,
			countries_hash,
			hasSeenVlanTaggedPackets() ? vlans_hash : NULL,
			arp_hash_matrix,
			macs_hash
  };
  time_t update_end;

  /* Always use the current time to update the hash tables states, also when processing pcap dumps. This
     is necessary as hash table states changes and periodic lua scripts call assume the time flows normally. */
  gettimeofday(&tv, NULL);

  periodic_ht_state_update_user_data.acle = NULL,
    periodic_ht_state_update_user_data.iface = this,
    periodic_ht_state_update_user_data.deadline = deadline,
    periodic_ht_state_update_user_data.tv = &tv;
    periodic_ht_state_update_user_data.skip_user_scripts = skip_user_scripts;
    periodic_ht_state_update_user_data.vm = vm;

  if(vm)
    lua_newtable(vm);

  for(u_int i = 0; i < sizeof(ghs) / sizeof(ghs[0]); i++) {
    if(ghs[i]) {
      ghs[i]->walkAllStates(generic_periodic_hash_entry_state_update, &periodic_ht_state_update_user_data);

      if(periodic_ht_state_update_user_data.acle) {
	periodic_ht_state_update_user_data.acle->lua_stats(ghs[i]->getName(), vm);
	delete periodic_ht_state_update_user_data.acle;
	periodic_ht_state_update_user_data.acle = NULL;
      }
    }
  }

  if((update_end = time(NULL)) > deadline) {
    char date_buf[32];
    struct tm deadline_tm;

    strftime(date_buf, sizeof(date_buf), "%H:%M:%S", localtime_r(&deadline, &deadline_tm));
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Deadline exceeded [%s][%s][expected: %s][off by: %u secs]",
				 __FUNCTION__, get_name(), date_buf, update_end - deadline);
  }
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

  if(hosts_hash) {
    begin_slot = 0;
    walker(&begin_slot, walk_all, walker_hosts, update_host_host_pool_l7policy, &update_host);
  }

  if(macs_hash) {
    begin_slot = 0;
    walker(&begin_slot, walk_all, walker_macs, update_l2_device_host_pool, NULL);
  }

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
  if(hosts_hash)
    walker(&begin_slot, walk_all, walker_hosts, update_host_host_pool_l7policy, &update_host);
}

/* **************************************************** */

void NetworkInterface::updateFlowsL7Policy() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(isView()) return;

  if(flows_hash)
    walker(&begin_slot, walk_all, walker_flows, update_flow_l7_policy, NULL);
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

struct country_find_info {
  const char *country_id;
  Country *country;
};

/* **************************************************** */

struct mac_find_info {
  u_int8_t mac[6];
  u_int16_t vlan_id;
  Mac *m;
  DeviceType dtype;
  lua_State *vm;
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

static bool find_country(GenericHashEntry *he, void *user_data, bool *matched) {
  struct country_find_info *info = (struct country_find_info*)user_data;
  Country *country = (Country*)he;

  if((info->country == NULL) && !strcmp(info->country_id, country->get_country_name())) {
    info->country = country;
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

/* NOTE: this is inteded to be called only by startup.lua */
bool NetworkInterface::restoreHost(char *host_ip, u_int16_t vlan_id) {
  Host *h;
  int16_t local_network_id;
  IpAddress ipa;

  if(!hosts_hash->hasEmptyRoom()) {
    //ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
    return(false);
  }

  ipa.set(host_ip);

  if(ipa.isLocalHost(&local_network_id))
    h = new LocalHost(this, host_ip, vlan_id);
  else
    h = new RemoteHost(this, host_ip, vlan_id);

  if(!h) return(false);

  if(!hosts_hash->add(h, false /* don't lock, we are in startup.lua */)) {
    /* Note: this should never happen as we are checking hasEmptyRoom() */
    //ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in interface %s", ifname);
    delete h;
    return(false);
  }

  return(true);
}

/* **************************************************** */

Host* NetworkInterface::getHost(char *host_ip, u_int16_t vlan_id, bool isInlineCall) {
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

      h = hosts_hash ? hosts_hash->get(vlan_id, ip, isInlineCall) : NULL;

      delete ip;
    }
  }

  return(h);
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

    if(flows_hash)
      walker(&begin_slot, walk_all, walker_flows, update_flow_profile, NULL);
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

  h = findHostByIP(allowed_hosts, host_ip, vlan_id);

  if(h) {
    h->lua(vm, allowed_hosts, true, true, true, false);
    ret = true;
  } else
    ret = false;

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

void NetworkInterface::checkPointHostTalker(lua_State* vm, char *host_ip, u_int16_t vlan_id) {
  Host *h;

  if(host_ip && (h = getHost(host_ip, vlan_id, false /* Not an inline call */)))
    h->checkpoint(vm);
  else
    lua_pushnil(vm);
}

/* **************************************************** */

Host* NetworkInterface::findHostByIP(AddressTree *allowed_hosts,
				      char *host_ip, u_int16_t vlan_id) {
  if(host_ip != NULL) {
    Host *h = getHost(host_ip, vlan_id, false /* Not an inline call */);

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
  const char *stringValue;
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
  bool blacklistedHosts;      /* Not used in flow_search_walker */
  bool anomalousOnly;         /* Not used in flow_search_walker */
  bool dhcpOnly;              /* Not used in flow_search_walker */
  bool hideTopHidden;         /* Not used in flow_search_walker */
  const AddressTree * cidr_filter; /* Not used in flow_search_walker */
  u_int16_t vlan_id;
  OperatingSystem osFilter;
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

  /* Used by getActiveFlowsStats */
  nDPIStats *ndpi_stats;
  FlowStats *stats;

  /* Paginator */
  Paginator *pag;
};

/* **************************************************** */

static bool flow_matches(Flow *f, struct flowHostRetriever *retriever) {
  int ndpi_proto, ndpi_cat;
  u_int16_t port;
  int16_t local_network_id;
  u_int16_t vlan_id = 0, pool_filter, flow_status_filter;
  u_int8_t ip_version;
  u_int8_t l4_protocol;
  u_int8_t *mac_filter;
  LocationPolicy client_policy;
  LocationPolicy server_policy;
  TcpFlowStateFilter tcp_flow_state_filter;
  bool unicast, unidirectional, alerted_flows, misbehaving_flows;
  u_int32_t asn_filter;
  char* username_filter;
  char* pidname_filter;
  u_int32_t deviceIP;
  u_int16_t inIndex, outIndex;
  u_int8_t icmp_type, icmp_code;
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  char *traffic_profile_filter;
#endif
#endif
  char *container_filter, *pod_filter;
#ifdef HAVE_NEDGE
  bool filtered_flows;
#endif
  FlowStatus status;

  if(f && (!f->idle())) {
    if(retriever->host) {
      if(!f->getInterface()->isViewed()) {
	/*
	  For non-viewed interfaces it is safe to just check on pointers equality.
	  Indeed, the retriever->host has been obtained with getHost(), which has returned
	  the same pointer also used by the flow to identify its client / server hosts.
	 */
	if(retriever->host != f->get_cli_host()
	   && retriever->host != f->get_srv_host())
	  return(false);
      } else {
	/*
	  In case of view interfaces, hosts are in the view interface whereas flows are in
	  the underlying viewed interfaces so in this case it is not possible to just check on
	  pointers equality. This need to use the retriever->host which comes from the view interface
	  to retrieve an IpAddress, and check it against the flow ip address, along with the vlan.
	  Indeed, flow ip addresses exist also when a flow doesn't have Host* as in the case of viewed interfaces.
	 */
	if(!(retriever->host->get_ip()->equal(f->get_cli_ip_addr()) && retriever->host->get_vlan_id() == f->get_vlan_id())
	   &&!(retriever->host->get_ip()->equal(f->get_srv_ip_addr()) && retriever->host->get_vlan_id() == f->get_vlan_id()))
	  return(false);
      }
    }

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
       && (((ip_version == 4) && (f->get_cli_ip_addr() && !f->get_cli_ip_addr()->isIPv4()))
	   || ((ip_version == 6) && (f->get_cli_ip_addr() && !f->get_cli_ip_addr()->isIPv6()))))
      return(false);

    if(retriever->pag
       && retriever->pag->L4Protocol(&l4_protocol)
       && l4_protocol
       && l4_protocol != f->get_protocol())
      return(false);

    if(retriever->pag
       && retriever->pag->deviceIpFilter(&deviceIP)) {
	if(f->getFlowDeviceIp() != deviceIP
	   || (retriever->pag->inIndexFilter(&inIndex) && f->getFlowDeviceInIndex() != inIndex)
	   || (retriever->pag->outIndexFilter(&outIndex) && f->getFlowDeviceOutIndex() != outIndex))
	  return(false);
    }

    if(retriever->pag
       && retriever->pag->containerFilter(&container_filter)) {
      const char *cli_container = f->getClientContainerInfo() ? f->getClientContainerInfo()->id : NULL;
      const char *srv_container = f->getServerContainerInfo() ? f->getServerContainerInfo()->id : NULL;

      if(!((cli_container && !strcmp(container_filter, cli_container))
	  || (srv_container && !strcmp(container_filter, srv_container))))
        return(false);
    }

    if(retriever->pag
       && retriever->pag->podFilter(&pod_filter)) {
      const ContainerInfo *cli_cont = f->getClientContainerInfo();
      const ContainerInfo *srv_cont = f->getServerContainerInfo();

      const char *cli_pod = cli_cont && cli_cont->data_type == container_info_data_type_k8s ? cli_cont->data.k8s.pod : NULL;
      const char *srv_pod = srv_cont && srv_cont->data_type == container_info_data_type_k8s ? srv_cont->data.k8s.pod : NULL;

      if(!((cli_pod && !strcmp(pod_filter, cli_pod))
	  || (srv_pod && !strcmp(pod_filter, srv_pod))))
        return(false);
    }

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    if(retriever->pag
       && retriever->pag->trafficProfileFilter(&traffic_profile_filter)
       && (f->isMaskedFlow() || strcmp(traffic_profile_filter, f->get_profile_name()))) {
      return(false);
    }
#endif
#endif

    if(retriever->pag
       && retriever->pag->asnFilter(&asn_filter)
       && f->get_cli_host() && f->get_srv_host()
       && f->get_cli_host()->get_asn() != asn_filter
       && f->get_srv_host()->get_asn() != asn_filter)
      return(false);

    if(retriever->pag
       && retriever->pag->usernameFilter(&username_filter)
       && (!f->get_user_name(true  /* client uid */) || strcmp(f->get_user_name(true  /* client uid */), username_filter))
       && (!f->get_user_name(false  /* server uid */) || strcmp(f->get_user_name(false  /* server uid */), username_filter)))
      return(false);

    if(retriever->pag
       && retriever->pag->pidnameFilter(&pidname_filter)
       && (!f->get_proc_name(true  /* client pid */) || strcmp(f->get_proc_name(true  /* client pid */), pidname_filter))
       && (!f->get_proc_name(false  /* server pid */) || strcmp(f->get_proc_name(false  /* server pid */), pidname_filter)))
      return(false);

    if(retriever->pag
       && retriever->pag->icmpValue(&icmp_type, &icmp_code)) {
      u_int8_t cur_type, cur_code;
      f->getICMP(&cur_code, &cur_type);

      if((!f->isICMP()) || (cur_type != icmp_type) || (cur_code != icmp_code))
        return(false);
     }

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

    status = f->getPredominantStatus();

    if(retriever->pag
       && retriever->pag->misbehavingFlows(&misbehaving_flows)
       && ((misbehaving_flows && status == status_normal)
	   || (!misbehaving_flows && status != status_normal)))
      return(false);

    if(retriever->pag
       && retriever->pag->alertedFlows(&alerted_flows)
       && ((alerted_flows && !f->isFlowAlerted())
	   || (!alerted_flows && f->isFlowAlerted())))
      return(false);

    /* Flow Status filter */
    if(retriever->pag
       && retriever->pag->flowStatusFilter(&flow_status_filter)
       && !f->getStatusBitmap().issetBit(flow_status_filter))
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
       && ((unidirectional && !f->isOneWay())
	   || (!unidirectional && f->isBidirectional())))
      return(false);

    /* Unicast: at least one between client and server is unicast address */
    if(retriever->pag
       && retriever->pag->unicastTraffic(&unicast)
       && ((unicast && ((f->get_cli_ip_addr()->isMulticastAddress()
			 || f->get_cli_ip_addr()->isBroadcastAddress()
			 || f->get_srv_ip_addr()->isMulticastAddress()
			 || f->get_srv_ip_addr()->isBroadcastAddress())))
	   || (!unicast && (!f->get_cli_ip_addr()->isMulticastAddress()
			    && !f->get_cli_ip_addr()->isBroadcastAddress()
			    && !f->get_srv_ip_addr()->isMulticastAddress()
			    && !f->get_srv_ip_addr()->isBroadcastAddress()))))
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
  const char *flow_info;
  const TcpInfo *tcp_info;

  if(retriever->actNumEntries >= retriever->maxNumEntries)
    return(true); /* Limit reached - stop iterating */

  if(flow_matches(f, retriever)) {
    retriever->elems[retriever->actNumEntries].flow = f;

    switch(retriever->sorter) {
      case column_client:
	if(f->getInterface()->isViewed())
	  retriever->elems[retriever->actNumEntries++].ipValue = (IpAddress*)f->get_cli_ip_addr();
	else
	  retriever->elems[retriever->actNumEntries++].hostValue = f->get_cli_host();
	break;
      case column_server:
	if(f->getInterface()->isViewed())
	  retriever->elems[retriever->actNumEntries++].ipValue = (IpAddress*)f->get_srv_ip_addr();
	else
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
      case column_client_rtt:
	if((tcp_info = f->getClientTcpInfo()))
	  retriever->elems[retriever->actNumEntries++].numericValue = (u_int64_t)(tcp_info->rtt * 1000);
	else
	  retriever->elems[retriever->actNumEntries++].numericValue = 0;
	break;
      case column_server_rtt:
	if((tcp_info = f->getServerTcpInfo()))
	  retriever->elems[retriever->actNumEntries++].numericValue = (u_int64_t)(tcp_info->rtt * 1000);
	else
	  retriever->elems[retriever->actNumEntries++].numericValue = 0;
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
     (r->osFilter != ((OperatingSystem)-1) && (h->getOS() != r->osFilter))     ||
     (r->blacklistedHosts && !h->isBlacklisted())     ||
     (r->anomalousOnly && !h->hasAnomalies())         ||
     (r->dhcpOnly && !h->isDhcpHost())                ||
     (r->cidr_filter && !h->match(r->cidr_filter))    ||
     (r->hideTopHidden && h->isHiddenFromTop())       ||
     (r->traffic_type == traffic_type_one_way && !h->isOneWayTraffic())         ||
     (r->traffic_type == traffic_type_bidirectional && !h->isTwoWaysTraffic())  ||
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
    r->elems[r->actNumEntries++].numericValue = h->getNumTriggeredAlerts();
    break;

  case column_name:
    r->elems[r->actNumEntries++].stringValue = strdup(h->get_visual_name(buf, sizeof(buf)));
    break;

  case column_country:
    r->elems[r->actNumEntries++].stringValue = strdup(h->get_country(buf, sizeof(buf)));
    break;

  case column_os:
    r->elems[r->actNumEntries++].numericValue = h->getOS();
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
  case column_total_num_misbehaving_flows_as_client:  r->elems[r->actNumEntries++].numericValue = h->getTotalNumMisbehavingOutgoingFlows(); break;
  case column_total_num_misbehaving_flows_as_server:  r->elems[r->actNumEntries++].numericValue = h->getTotalNumMisbehavingIncomingFlows(); break;
  case column_total_num_unreachable_flows_as_client:  r->elems[r->actNumEntries++].numericValue = h->getTotalNumUnreachableOutgoingFlows(); break;
  case column_total_num_unreachable_flows_as_server:  r->elems[r->actNumEntries++].numericValue = h->getTotalNumUnreachableIncomingFlows(); break;
  case column_total_alerts:    r->elems[r->actNumEntries++].numericValue = h->getTotalAlerts(); break;
  case column_score: r->elems[r->actNumEntries++].numericValue = h->getScore(); break;

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

  if(r->actNumEntries >= r->maxNumEntries)
    return(true); /* Limit reached */

  if(!m
     || m->idle()
     || (r->sourceMacsOnly && !m->isSourceMac())
     || ((r->devtypeFilter != (u_int8_t)-1) && (m->getDeviceType() != r->devtypeFilter))
     || ((r->locationFilter != (u_int8_t)-1) && (m->locate() != r->locationFilter))
     || ((r->poolFilter != (u_int16_t)-1) && (m->getInterface()->getHostPool(m) != r->poolFilter))
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

  case column_thpt:
    r->elems[r->actNumEntries++].numericValue = country->getBytesThpt();
    break;

  case column_traffic:
    r->elems[r->actNumEntries++].numericValue = country->getNumBytes();
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

  return(a->hostValue->compare(b->hostValue));
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

int ipSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList*)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList*)_b;

  if(!a || !b || !a->ipValue || !b->ipValue)
    return(true);

  return(a->ipValue->compare(b->ipValue));
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

  if(!strcmp(sortColumn, "column_client")) retriever->sorter = column_client, sorter = (isViewed() || isView()) ? ipSorter : hostSorter;
  else if(!strcmp(sortColumn, "column_vlan")) retriever->sorter = column_vlan, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_server")) retriever->sorter = column_server, sorter = isViewed() ? ipSorter : hostSorter;
  else if(!strcmp(sortColumn, "column_proto_l4")) retriever->sorter = column_proto_l4, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_ndpi")) retriever->sorter = column_ndpi, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_duration")) retriever->sorter = column_duration, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt")) retriever->sorter = column_thpt, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_client_rtt")) retriever->sorter = column_client_rtt, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_server_rtt")) retriever->sorter = column_server_rtt, sorter = numericSorter;
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

static bool flow_sum_stats(GenericHashEntry *flow, void *user_data, bool *matched) {
  flowHostRetriever *retriever = (flowHostRetriever*)user_data;
  nDPIStats *ndpi_stats = retriever->ndpi_stats;
  FlowStats *stats = retriever->stats;
  Flow *f = (Flow*)flow;

  if(flow_matches(f, retriever)) {
    f->sumStats(ndpi_stats, stats);
    *matched = true;
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getActiveFlowsStats(nDPIStats *ndpi_stats, FlowStats *stats,
					   AddressTree *allowed_hosts,
					   Host *h, Paginator *p) {
  flowHostRetriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&retriever, 0, sizeof(retriever));

  retriever.pag = p;
  retriever.host = h, retriever.location = location_all;
  retriever.ndpi_proto = -1;
  retriever.actNumEntries = 0, retriever.maxNumEntries = getFlowsHashSize();
  retriever.allowed_hosts = allowed_hosts;
  retriever.ndpi_stats = ndpi_stats;
  retriever.stats = stats;

  walker(&begin_slot, walk_all, walker_flows, flow_sum_stats, &retriever);
}

/* **************************************************** */

int NetworkInterface::getFlows(lua_State* vm,
			       u_int32_t *begin_slot,
			       bool walk_all,
			       AddressTree *allowed_hosts,
			       Host *host,
			       Paginator *p) {
  struct flowHostRetriever retriever;
  char sortColumn[32];
  DetailsLevel highDetails;

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

  if(sortFlows(begin_slot, walk_all, &retriever, allowed_hosts, host, p, sortColumn) < 0) {
    return -1;
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numFlows", retriever.actNumEntries);
  lua_push_uint64_table_entry(vm, "nextSlot", *begin_slot);

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

  if(sortFlows(&begin_slot, walk_all, &retriever, allowed_hosts, NULL, p, groupColumn) < 0) {
    return -1;
  }

  // build a new grouper that will help in aggregating stats
  if((gper = new(std::nothrow) FlowGrouper(retriever.sorter)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to allocate memory for a Grouper.");
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

  walker(&begin_slot, walk_all,  walker_flows, flow_drop_walker, (void*)&retriever);

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
				u_int16_t vlan_id, OperatingSystem osFilter,
				u_int32_t asnFilter, int16_t networkFilter,
				u_int16_t pool_filter, bool filtered_hosts,
				bool blacklisted_hosts, bool hide_top_hidden,
				bool anomalousOnly, bool dhcpOnly,
				const AddressTree * const cidr_filter,
				u_int8_t ipver_filter, int proto_filter,
				TrafficType traffic_type_filter,
				char *sortColumn) {
  u_int8_t macAddr[6];
  int (*sorter)(const void *_a, const void *_b);

  if(retriever == NULL)
    return -1;

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
    retriever->cidr_filter = cidr_filter,
    retriever->hideTopHidden = hide_top_hidden,
    retriever->ndpi_proto = proto_filter,
    retriever->traffic_type = traffic_type_filter,
    retriever->maxNumEntries = getHostsHashSize();
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
  else if(!strcmp(sortColumn, "column_os")) retriever->sorter = column_os, sorter = numericSorter;
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
  else if(!strcmp(sortColumn, "column_total_num_misbehaving_flows_as_client")) retriever->sorter = column_total_num_misbehaving_flows_as_client, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_total_num_misbehaving_flows_as_server")) retriever->sorter = column_total_num_misbehaving_flows_as_server, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_total_num_unreachable_flows_as_client")) retriever->sorter = column_total_num_unreachable_flows_as_client, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_total_num_unreachable_flows_as_server")) retriever->sorter = column_total_num_unreachable_flows_as_server, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_total_alerts")) retriever->sorter = column_total_alerts, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_score")) retriever->sorter = column_score, sorter = numericSorter;
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
  int (*sorter)(const void *_a, const void *_b);

  if(retriever == NULL)
    return -1;

  retriever->sourceMacsOnly = sourceMacsOnly,
    retriever->actNumEntries = 0,
    retriever->poolFilter = pool_filter,
    retriever->manufacturer = (char *)manufacturer,
    retriever->maxNumEntries = getMacsHashSize();
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
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(retriever == NULL)
    return -1;

  retriever->actNumEntries = 0,
    retriever->maxNumEntries = getASesHashSize();
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
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(retriever == NULL)
    return -1;

  retriever->actNumEntries = 0,
    retriever->maxNumEntries = getCountriesHashSize();
    retriever->elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if(retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if((!strcmp(sortColumn, "column_country")) || (!strcmp(sortColumn, "column_id")) || (!strcmp(sortColumn, "column_"))) retriever->sorter = column_country, sorter = stringSorter;
  else if(!strcmp(sortColumn, "column_since"))        retriever->sorter = column_since,        sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_hosts"))        retriever->sorter = column_num_hosts,    sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt"))         retriever->sorter = column_thpt, 	       sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic"))      retriever->sorter = column_traffic,      sorter = numericSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all,  walker_countries, country_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortVLANs(struct flowHostRetriever *retriever, char *sortColumn) {
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if(retriever == NULL)
    return -1;

  retriever->actNumEntries = 0,
    retriever->maxNumEntries = getVLANsHashSize();
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
					 u_int16_t vlan_id, OperatingSystem osFilter,
					 u_int32_t asnFilter, int16_t networkFilter,
					 u_int16_t pool_filter, bool filtered_hosts,
					 bool blacklisted_hosts, bool hide_top_hidden,
					 u_int8_t ipver_filter, int proto_filter,
					 TrafficType traffic_type_filter, bool tsLua,
					 bool anomalousOnly, bool dhcpOnly,
					 const AddressTree * const cidr_filter,
					 char *sortColumn, u_int32_t maxHits,
					 u_int32_t toSkip, bool a2zSortOrder) {
  struct flowHostRetriever retriever;

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
	       cidr_filter,
	       ipver_filter, proto_filter,
	       traffic_type_filter,
	       sortColumn) < 0) {
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

  // it's up to us to clean sorted data
  // make sure first to free elements in case a string sorter has been used
  if(retriever.sorter == column_name
     || retriever.sorter == column_country
     || retriever.sorter == column_os) {
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].stringValue)
	free((char*)retriever.elems[i].stringValue);
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
					  u_int16_t vlan_id, OperatingSystem osFilter,
					  u_int32_t asnFilter, int16_t networkFilter,
					  u_int16_t pool_filter, bool filtered_hosts,
					  u_int8_t ipver_filter,
					  char *groupColumn) {
  struct flowHostRetriever retriever;
  Grouper *gper;

  // sort hosts according to the grouping criterion
  if(sortHosts(begin_slot, walk_all,
	       &retriever, 0 /* bridge_iface_idx TODO */,
	       allowed_hosts, host_details, location,
	       countryFilter, NULL /* Mac */, vlan_id,
	       osFilter, asnFilter, networkFilter, pool_filter,
	       filtered_hosts, false /* no blacklisted hosts filter */, false, false, false,
	       NULL, /* no cidr filter */
	       ipver_filter, -1 /* no protocol filter */,
	       traffic_type_all /* no traffic type filter */,
	       groupColumn) < 0 ) {
    return -1;
  }

  // build a new grouper that will help in aggregating stats
  if((gper = new(std::nothrow) Grouper(retriever.sorter)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to allocate memory for a Grouper.");
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

  // it's up to us to clean sorted data
  // make sure first to free elements in case a string sorter has been used
  if((retriever.sorter == column_name)
     || (retriever.sorter == column_country)
     || (retriever.sorter == column_os)) {
    for(u_int i=0; i<retriever.maxNumEntries; i++)
      if(retriever.elems[i].stringValue)
	free((char*)retriever.elems[i].stringValue);
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

void NetworkInterface::getNetworkStats(lua_State* vm, u_int16_t network_id, AddressTree *allowed_hosts) const {
  NetworkStats *network_stats;

  if((network_stats = getNetworkStats(network_id))
     && network_stats->trafficSeen()
     && network_stats->match(allowed_hosts)) {
    lua_newtable(vm);

    network_stats->lua(vm);

    lua_push_int32_table_entry(vm, "network_id", network_id);
    lua_pushstring(vm, ntop->getLocalNetworkName(network_id));
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* **************************************************** */

void NetworkInterface::getNetworksStats(lua_State* vm, AddressTree *allowed_hosts) const {
  u_int8_t num_local_networks = ntop->getNumLocalNetworks();

  lua_newtable(vm);

  for(u_int8_t network_id = 0; network_id < num_local_networks; network_id++)
    getNetworkStats(vm, network_id, allowed_hosts);
}

/* **************************************************** */

u_int NetworkInterface::purgeIdleFlows(bool force_idle) {
  u_int n = 0;
  time_t last_packet_time = getTimeLastPktRcvd();

  pollQueuedeCompanionEvents();
  bcast_domains->inlineReloadBroadcastDomains();

  if(!purge_idle_flows_hosts) return(0);

  if(!force_idle && last_packet_time < next_idle_flow_purge)
    return(0); /* Too early */
  else {
    /* Time to purge flows */

#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Purging idle flows [ifname: %s] [ifid: %i] [current size: %i]",
				 ifname, id, flows_hash->getNumEntries());
#endif
    n = (flows_hash ? flows_hash->purgeIdle(force_idle) : 0);

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
  return(!isSubInterface() ? getNumDroppedPackets() : 0);
};

/* **************************************************** */

u_int64_t NetworkInterface::getNumNewFlows() {
  return(num_new_flows);
};

/* **************************************************** */

u_int64_t NetworkInterface::getNumDiscardedProbingPackets() const {
  return discardedProbingStats.getPkts();
}

/* **************************************************** */

u_int64_t NetworkInterface::getNumDiscardedProbingBytes() const {
  return discardedProbingStats.getBytes();
}

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

u_int NetworkInterface::purgeIdleHosts(bool force_idle) {
  time_t last_packet_time = getTimeLastPktRcvd();

  if(!purge_idle_flows_hosts) return(0);

  if(!force_idle && last_packet_time < next_idle_host_purge)
    return(0); /* Too early */
  else {
    /* Time to purge hosts */
    u_int n;
    /* If the interface is no longer running it is safe to force all entries as idle */
    
#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Purging idle hosts [ifname: %s] [ifid: %i] [current size: %i]",
				 ifname, id, hosts_hash->getNumEntries());
#endif
    
    // ntop->getTrace()->traceEvent(TRACE_INFO, "Purging idle hosts");
    n = (hosts_hash ? hosts_hash->purgeIdle(force_idle) : 0);
    
    next_idle_host_purge = last_packet_time + HOST_PURGE_FREQUENCY;
    return(n);
  }
}

/* **************************************************** */

u_int NetworkInterface::purgeIdleMacsASesCountriesVlansArpMatrix(bool force_idle) {
  time_t last_packet_time = getTimeLastPktRcvd();

  if(!force_idle && last_packet_time < next_idle_other_purge)
    return(0); /* Too early */
  else {
    /* Time to purge hosts */
    u_int n;
    /* If the interface is no longer running it is safe to force all entries as idle */

    n = (macs_hash ? macs_hash->purgeIdle(force_idle) : 0)
      + (ases_hash ? ases_hash->purgeIdle(force_idle) : 0)
      + (countries_hash ? countries_hash->purgeIdle(force_idle) : 0)
      + (vlans_hash ? vlans_hash->purgeIdle(force_idle) : 0)
      + (arp_hash_matrix ? arp_hash_matrix->purgeIdle(force_idle) : 0);

    next_idle_other_purge = last_packet_time + OTHER_PURGE_FREQUENCY;
    
    return(n);
  }
}

/* *************************************** */

static void guess_all_ndpi_protocols_walker(Flow *flow, NetworkInterface *iface) {
  if(iface->get_ndpi_struct() && flow->get_ndpi_flow()) {
    if(!flow->isDetectionCompleted()) {
      u_int8_t proto_guessed;
      
      flow->setDetectedProtocol(ndpi_detection_giveup(iface->get_ndpi_struct(), flow->get_ndpi_flow(), 1, &proto_guessed), true);
    }
    
    /* Ensure that the callbacks are called. Normally processFullyDissectedProtocol
     * sould not be called because the detection of the flow is not completed yet. */
    flow->processDetectedProtocol();
    flow->processFullyDissectedProtocol();
  }
}

static bool process_all_active_flows_walker(GenericHashEntry *node, void *user_data, bool *matched) {
  Flow *flow = (Flow*)node;
  NetworkInterface *iface = (NetworkInterface*)user_data;
  struct timeval tv;
  tv.tv_sec = time(NULL), tv.tv_usec = 0;

  guess_all_ndpi_protocols_walker(flow, iface);

  flow->postFlowSetIdle(&tv);

  return(false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::processAllActiveFlows() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  walker(&begin_slot, walk_all, walker_flows,
	 process_all_active_flows_walker, this);
}

/* *************************************** */

void NetworkInterface::guessAllBroadcastDomainHosts() {
  bcast_domains->inlineReloadBroadcastDomains(true);
}

/* **************************************************** */

void NetworkInterface::getnDPIProtocols(lua_State *vm, ndpi_protocol_category_t filter, bool skip_critical) {
  int i;
  u_int num_supported_protocols = ndpi_get_ndpi_num_supported_protocols(get_ndpi_struct());
  ndpi_proto_defaults_t* proto_defaults = ndpi_get_proto_defaults(get_ndpi_struct());

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
  u_int num_supported_protocols = ndpi_get_ndpi_num_supported_protocols(get_ndpi_struct());
  ndpi_proto_defaults_t* proto_defaults = ndpi_get_proto_defaults(get_ndpi_struct());

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
				TcpPacketStats *_tcpPacketStats,
				ProtoStats *_discardedProbingStats) const {
  tcpFlowStats.sum(_tcpFlowStats), ethStats.sum(_ethStats), localStats.sum(_localStats),
    pktStats.sum(_pktStats), tcpPacketStats.sum(_tcpPacketStats),
    discardedProbingStats.sum(_discardedProbingStats);

  if(ndpiStats)
    ndpiStats->sum(_ndpiStats);
}

/* *************************************** */

void NetworkInterface::lua(lua_State *vm) {
  TcpFlowStats _tcpFlowStats;
  EthStats _ethStats;
  LocalTrafficStats _localStats;
  nDPIStats _ndpiStats;
  PacketStats _pktStats;
  TcpPacketStats _tcpPacketStats;
  ProtoStats _discardedProbingStats;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "name", get_name());
  lua_push_str_table_entry(vm, "description", get_description());
  lua_push_uint64_table_entry(vm, "scalingFactor", scalingFactor);
  lua_push_int32_table_entry(vm,  "id", id);
  if(customIftype) lua_push_str_table_entry(vm, "customIftype", (char*)customIftype);
  lua_push_bool_table_entry(vm, "isView", isView()); /* View interface */
  lua_push_bool_table_entry(vm, "isViewed", isViewed()); /* Viewed interface */
  lua_push_bool_table_entry(vm, "isDynamic", isSubInterface()); /* An runtime-instantiated interface */
  lua_push_uint64_table_entry(vm, "seen.last", getTimeLastPktRcvd());
  lua_push_bool_table_entry(vm, "inline", get_inline_interface());
  lua_push_bool_table_entry(vm, "vlan",     hasSeenVlanTaggedPackets());
  lua_push_bool_table_entry(vm, "has_macs", hasSeenMacAddresses());
  lua_push_bool_table_entry(vm, "has_seen_dhcp_addresses", hasSeenDHCPAddresses());
  lua_push_bool_table_entry(vm, "has_traffic_directions", (areTrafficDirectionsSupported() && (!is_traffic_mirrored)));
  lua_push_bool_table_entry(vm, "has_seen_pods", hasSeenPods());
  lua_push_bool_table_entry(vm, "has_seen_containers", hasSeenContainers());
  lua_push_bool_table_entry(vm, "has_seen_ebpf_events", hasSeenEBPFEvents());
  lua_push_bool_table_entry(vm, "has_alerts", hasAlerts());
  lua_push_int32_table_entry(vm, "num_alerts_engaged", getNumEngagedAlerts());
  lua_push_int32_table_entry(vm, "num_alerted_flows", getNumActiveAlertedFlows());
  lua_push_int32_table_entry(vm, "num_dropped_alerts", num_dropped_alerts);
  lua_push_uint64_table_entry(vm, "periodic_stats_update_frequency_secs", periodicStatsUpdateFrequency());

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "packets",     getNumPackets());
  lua_push_uint64_table_entry(vm, "bytes",       getNumBytes());
  lua_push_uint64_table_entry(vm, "flows",       getNumFlows());
  lua_push_uint64_table_entry(vm, "hosts",       getNumHosts());
  lua_push_uint64_table_entry(vm, "local_hosts", getNumLocalHosts());
  lua_push_uint64_table_entry(vm, "http_hosts",  getNumHTTPHosts());
  lua_push_uint64_table_entry(vm, "drops",       getNumPacketDrops());
  lua_push_uint64_table_entry(vm, "new_flows",   getNumNewFlows());
  lua_push_uint64_table_entry(vm, "num_dropped_flow_scripts_calls", getNumDroppedFlowScriptsCalls());
  lua_push_uint64_table_entry(vm, "devices",     getNumL2Devices());
  lua_push_uint64_table_entry(vm, "current_macs",  getNumMacs());
  lua_push_uint64_table_entry(vm, "num_live_captures", num_live_captures);
  lua_push_float_table_entry(vm, "throughput_bps", bytes_thpt.getThpt());
  lua_push_uint64_table_entry(vm, "throughput_trend_bps", bytes_thpt.getTrend());
  lua_push_float_table_entry(vm, "throughput_pps", pkts_thpt.getThpt());
  lua_push_uint64_table_entry(vm, "throughput_trend_pps", pkts_thpt.getTrend());

  if(db) db->lua(vm, false /* Overall */);

  lua_pushstring(vm, "stats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "packets",     getNumPacketsSinceReset());
  lua_push_uint64_table_entry(vm, "bytes",       getNumBytesSinceReset());
  lua_push_uint64_table_entry(vm, "drops",       getNumPacketDropsSinceReset());

  if(db) db->lua(vm, true /* Since last checkpoint */);

  if(discardProbingTraffic()) {
    lua_push_uint64_table_entry(vm, "discarded_probing_packets", getNumDiscProbingPktsSinceReset());
    lua_push_uint64_table_entry(vm, "discarded_probing_bytes",   getNumDiscProbingBytesSinceReset());
  }

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
  lua_push_str_table_entry(vm, "ip_addresses", (char*)getLocalIPAddresses());
  bcast_domains->lua(vm);

  /* Anomalies */
  lua_newtable(vm);
  if(has_too_many_flows) lua_push_bool_table_entry(vm, "too_many_flows", true);
  if(has_too_many_hosts) lua_push_bool_table_entry(vm, "too_many_hosts", true);
  if(slow_stats_update) lua_push_bool_table_entry(vm, "slow_stats_update", true);
  lua_pushstring(vm, "anomalies");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  sumStats(&_tcpFlowStats, &_ethStats, &_localStats,
	   &_ndpiStats, &_pktStats, &_tcpPacketStats, &_discardedProbingStats);

  _tcpFlowStats.lua(vm, "tcpFlowStats");
  _ethStats.lua(vm);
  _localStats.lua(vm);
  _ndpiStats.lua(this, vm, true);
  _pktStats.lua(vm, "pktSizeDistribution");
  _tcpPacketStats.lua(vm, "tcpPacketStats");

  if(discardProbingTraffic())
    _discardedProbingStats.lua(vm, "discarded_probing_");

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

/* *************************************** */

void NetworkInterface::lua_hash_tables_stats(lua_State *vm) {
  /* Hash tables stats */
  GenericHash *gh[] = {flows_hash, hosts_hash, macs_hash,
		       vlans_hash, ases_hash, countries_hash,
		       arp_hash_matrix
#ifdef NTOPNG_PRO
		       ,aggregated_flows_hash
#endif
  };

  lua_newtable(vm);

  for (u_int i = 0; i < sizeof(gh) / sizeof(gh[0]); i++) {
    if(gh[i])
      gh[i]->lua(vm);
  }
}

/* *************************************** */

void NetworkInterface::lua_periodic_activities_stats(lua_State *vm) {
  lua_newtable(vm);

  /* Periodic activities stats */
  ntop->lua_periodic_activities_stats(this, vm);
}

/* **************************************************** */

void NetworkInterface::runHousekeepingTasks() {
}

/* **************************************************** */

void NetworkInterface::runShutdownTasks() {
  /* NOTE NOTE NOTE
     This task runs asynchronously with respect to the datapath
  */

  /* Run the periodic stats update one last time so certain tasks can be properly finalized,
     e.g., all hosts and all flows can be marked as idle */
  periodicStatsUpdate();

#ifdef NTOPNG_PRO
  flushFlowDump();
#endif
}

/* **************************************************** */

Mac* NetworkInterface::getMac(u_int8_t _mac[6], bool create_if_not_present, bool isInlineCall) {
  Mac *ret = NULL;

  if(!_mac || !macs_hash) return(NULL);

  ret = macs_hash->get(_mac, isInlineCall);

  if((ret == NULL) && create_if_not_present) {

    if(!macs_hash->hasEmptyRoom())
      return(NULL);

    try {
      if((ret = new Mac(this, _mac)) != NULL) {
	if(!macs_hash->add(ret,
			   !isInlineCall /* Lock only if not inline, if inline there's no need to lock as also the purgeIdle is done inline*/)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
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

ArpStatsMatrixElement* NetworkInterface::getArpHashMatrixElement(const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6],
								 const u_int32_t _src_ip, const u_int32_t _dst_ip,
								 bool * const src2dst) {
  ArpStatsMatrixElement *ret = NULL;

  if(arp_hash_matrix == NULL)
    return NULL;

  ret = arp_hash_matrix->get(_src_mac, _src_ip, _dst_ip, src2dst);

  if(ret == NULL) {

    if (!arp_hash_matrix->hasEmptyRoom())
      return(NULL);

    try{
      if((ret = new ArpStatsMatrixElement(this, _src_mac, _dst_mac, _src_ip, _dst_ip)) != NULL)

        if(!arp_hash_matrix->add(ret, false /* No need to lock, we're inline with the purgeIdle */)){
          /* Note: this should never happen as we are checking hasEmptyRoom() */
          delete ret;
          return(NULL);
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

Vlan* NetworkInterface::getVlan(u_int16_t vlanId, bool create_if_not_present, bool isInlineCall) {
  Vlan *ret = NULL;

  if(!vlans_hash) return(NULL);

  ret = vlans_hash->get(vlanId, isInlineCall);

  if((ret == NULL) && create_if_not_present) {
    
    if(!vlans_hash->hasEmptyRoom())
      return(NULL);

    try {

      if((ret = new Vlan(this, vlanId)) != NULL) {
	if(!vlans_hash->add(ret,
			    !isInlineCall /* Lock only if not inline, if inline there is no need to lock as we are sequential with the purgeIdle */)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
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

AutonomousSystem* NetworkInterface::getAS(IpAddress *ipa, bool create_if_not_present, bool is_inline_call) {
  AutonomousSystem *ret = NULL;

  if((!ipa) || (!ases_hash))
    return(NULL);

  ret = ases_hash->get(ipa, is_inline_call, create_if_not_present);

  if((ret == NULL) && create_if_not_present) {

    if(!ases_hash->hasEmptyRoom())
      return(NULL);

    try {
      if((ret = new AutonomousSystem(this, ipa)) != NULL) {
	ret->incUses();
	if(!ases_hash->add(ret,
			   !is_inline_call /* Lock only if not inline, if inline there is no need to lock as we are sequential with the purgeIdle */)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
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

Country* NetworkInterface::getCountry(const char *country_name, bool create_if_not_present, bool is_inline_call) {
  Country *ret = NULL;

  if((!countries_hash) || (!country_name) || (!country_name[0]))
    return(NULL);

  ret = countries_hash->get(country_name, is_inline_call);

  if((ret == NULL) && create_if_not_present) {

    if(!countries_hash->hasEmptyRoom())
      return(NULL);

    try {
      if((ret = new Country(this, country_name)) != NULL) {
	if(!countries_hash->add(ret, !is_inline_call /* Lock only if not inline, if inline there is no need to lock as we are sequential with the purgeIdle */)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
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

Flow* NetworkInterface::findFlowByKeyAndHashId(u_int32_t key, u_int hash_id, AddressTree *allowed_hosts) {
  Flow *f = NULL;

  if(!flows_hash)
    return NULL;

  f = flows_hash->findByKeyAndHashId(key, hash_id);

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

  if(!flows_hash)
    return NULL;

  f = (Flow*)flows_hash->find(src_ip, dst_ip, src_port, dst_port, vlan_id, l4_proto, NULL, &src2dst, false /* Not an inline call */);

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

void NetworkInterface::allocateStructures() {
  u_int8_t numNetworks = ntop->getNumLocalNetworks();
  char buf[16];

  try {
    if(get_id() >= 0) {
      u_int32_t num_hashes = max_val(4096, ntop->getPrefs()->get_max_num_flows()/4);

      flows_hash     = new FlowHash(this, num_hashes, ntop->getPrefs()->get_max_num_flows());

      if(!isViewed()) { /* Do not allocate HTs when the interface is viewed, HTs are allocated in the corresponding ViewInterface */
	num_hashes     = max_val(4096, ntop->getPrefs()->get_max_num_hosts() / 4);
	hosts_hash     = new HostHash(this, num_hashes, ntop->getPrefs()->get_max_num_hosts());
	/* The number of ASes cannot be greater than the number of hosts */
	ases_hash      = new AutonomousSystemHash(this, ndpi_min(num_hashes, 4096), 32768);
	countries_hash = new CountriesHash(this, ndpi_min(num_hashes, 1024), 32768);
	vlans_hash     = new VlanHash(this, 1024, 2048);
	macs_hash      = new MacHash(this, ndpi_min(num_hashes, 8192), 32768);

	if(ntop->getPrefs()->is_arp_matrix_generation_enabled())
	  arp_hash_matrix = new ArpStatsHashMatrix(this, ndpi_min(num_hashes, 32768), (ntop->getPrefs()->get_max_num_hosts() ^ 2) / 2);
      }
    }

    networkStats     = new NetworkStats*[numNetworks];
    statsManager     = new StatsManager(id, STATS_MANAGER_STORE_NAME);
    ndpiStats        = new nDPIStats(true /* Enable throughput calculation */);

    if(!isViewed()) {
      alertsManager = new AlertsManager(id, ALERTS_MANAGER_STORE_NAME);
      alertsQueue   = new AlertsQueue(this);
    }

    for(u_int8_t i = 0; i < numNetworks; i++)
      networkStats[i] = new NetworkStats(this, i);
  } catch(std::bad_alloc& ba) {
    static bool oom_warning_sent = false;

    if(!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      oom_warning_sent = true;
    }
  }

  snprintf(buf, sizeof(buf), "iface_%d", id);
  setEntityValue(buf);

  refreshHasAlerts();
}

/* **************************************** */

AlertsManager *NetworkInterface::getAlertsManager() const {
  if(isViewed())
    return viewedBy()->getAlertsManager();
  else
    return alertsManager;
}

/* **************************************** */

AlertsQueue *NetworkInterface::getAlertsQueue() const {
  if(isViewed())
    return viewedBy()->getAlertsQueue();
  else
    return alertsQueue;
}

/* **************************************** */

NetworkStats* NetworkInterface::getNetworkStats(u_int8_t networkId) const {
  if((networkStats == NULL) || (networkId >= ntop->getNumLocalNetworks()))
    return(NULL);
  else
    return(networkStats[networkId]);
}

/* **************************************** */

void NetworkInterface::checkPointCounters(bool drops_only) {
  if(!drops_only) {
    checkpointPktCount = getNumPackets(),
      checkpointBytesCount = getNumBytes();
  }
  checkpointPktDropCount = getNumPacketDrops();
  checkpointDiscardedProbingPktCount = getNumDiscardedProbingPackets();
  checkpointDiscardedProbingBytesCount = getNumDiscardedProbingBytes();

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

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointNumDiscardedProbingPackets() const {
  return checkpointDiscardedProbingPktCount;
}

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointNumDiscardedProbingBytes() const {
  return checkpointDiscardedProbingBytesCount;
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

    interfaceStats->set(stats);
  }
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

  if((new_tree = new VlanAddressTree) == NULL) {
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

  return(host->get_ip()->findAddress(vlan_addrtree->getAddressTree(host->get_vlan_id())));
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

  if(sortMacs(begin_slot, walk_all,
	      &retriever, bridge_iface_idx, sourceMacsOnly,
	      manufacturer, sortColumn,
	      pool_filter, devtype_filter, location_filter) < 0) {
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

  if(sortASes(&retriever, p->sortColumn()) < 0) {
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

  if(sortCountries(&retriever, p->sortColumn()) < 0) {
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

  if(sortVLANs(&retriever, sortColumn) < 0) {
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

  if(sortMacs(&begin_slot, walk_all,
	      &retriever, bridge_iface_idx, sourceMacsOnly,
	      NULL, (char*)"column_manufacturer",
	      (u_int16_t)-1, devtype_filter, location_filter) < 0) {
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

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************** */

static bool find_mac_hosts(GenericHashEntry *h, void *user_data, bool *matched) {
  struct mac_find_info *info = (struct mac_find_info*)user_data;
  Host *host = (Host*)h;

  if(host->getMac() == info->m)
    host->lua(info->vm, NULL /* Already checked */, false, false, false, true);

  return false; /* false = keep on walking */
}

/* **************************************** */

bool NetworkInterface::getActiveMacHosts(lua_State* vm, const char *mac) {
  struct mac_find_info info;
  bool res = false;
  u_int32_t begin_slot = 0;

  if(!macs_hash)
    return res;

  memset(&info, 0, sizeof(info));
  Utils::parseMac(info.mac, mac);
  info.vm = vm;

  info.m = macs_hash->get(info.mac, false /* Not an inline call */);

  if(!info.m
     || !info.m->getNumHosts() /* Avoid walking the hosts hash table when there are no hosts associated */)
    return res;

  walker(&begin_slot, true /* walk_all */, walker_hosts, find_mac_hosts, &info);

  return res;
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

  if(sortMacs(&begin_slot, walk_all,
	      &retriever, bridge_iface_idx, sourceMacsOnly,
	      manufacturer, (char*)"column_device_type",
	      (u_int16_t)-1, (u_int8_t)-1, location_filter) < 0) {
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

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************** */

bool NetworkInterface::getMacInfo(lua_State* vm, char *mac) {
  struct mac_find_info info;
  bool ret = false;

  if(!macs_hash)
    return ret;

  memset(&info, 0, sizeof(info));
  Utils::parseMac(info.mac, mac);

  info.m = macs_hash->get(info.mac, false /* Not an inline call */);

  if(info.m) {
    info.m->lua(vm, true, false);
    ret = true;
  }

  return ret;
}

/* **************************************** */

bool NetworkInterface::resetMacStats(lua_State* vm, char *mac, bool delete_data) {
  struct mac_find_info info;
  bool ret = false;

  if(!macs_hash)
    return ret;

  memset(&info, 0, sizeof(info));
  Utils::parseMac(info.mac, mac);

  info.m = macs_hash->get(info.mac, false /* Not an inline call */);

  if(info.m) {
    if(delete_data)
      info.m->requestDataReset();
    else
      info.m->requestStatsReset();
    ret = true;
  }

  return ret;
}

/* **************************************** */

bool NetworkInterface::setMacDeviceType(char *strmac,
					DeviceType dtype, bool alwaysOverwrite) {
  u_int8_t mac[6];
  Mac *m;
  DeviceType oldtype;

  Utils::parseMac(mac, strmac);

  ntop->getTrace()->traceEvent(TRACE_INFO, "setMacDeviceType(%s) = %d", strmac, (int)dtype);

  if((m = getMac(mac, false /* Don't create if missing */, false /* Not an inline call */))) {
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

  walker(&begin_slot, walk_all,  walker_ases, find_as_by_asn, (void*)&info);

  if(info.as) {
    info.as->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************** */

bool NetworkInterface::getCountryInfo(lua_State* vm, const char *country) {
  struct country_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  info.country_id = country;

  walker(&begin_slot, walk_all, walker_countries, find_country, (void*)&info);

  if(info.country) {
    info.country->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

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

  walker(&begin_slot, walk_all,  walker_vlans, find_vlan_by_vlan_id, (void*)&info);

  if(info.vl) {
    info.vl->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************** */

int NetworkInterface::updateHostTrafficPolicy(AddressTree* allowed_networks,
					      char *host_ip, u_int16_t host_vlan) {
  Host *h;
  int rv;

  if((h = findHostByIP(allowed_networks, host_ip, host_vlan)) != NULL) {
    h->updateHostTrafficPolicy(host_ip);
    rv = CONST_LUA_OK;
  } else
    rv = CONST_LUA_ERROR;

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
    u_char tmp[16];
    Utils::int2mac(it->second, tmp);

	  getAlertsQueue()->pushMacIpAssociationChangedAlert(ntohl(ipv4), tmp, _mac);

	  ip_mac[ipv4] = mac;
	}
      } else
	ip_mac[ipv4] = mac;
    }
  }
}

/* *************************************** */

void NetworkInterface::checkDhcpIPRange(Mac *sender_mac, struct dhcp_packet *dhcp_reply, u_int16_t vlan_id) {
  if(!hasConfiguredDhcpRanges())
    return;

  u_char *_mac = dhcp_reply->chaddr;
  u_int64_t mac = Utils::mac2int(_mac);
  u_int32_t ipv4 = dhcp_reply->yiaddr;

  if((ipv4 != 0) && (mac != 0) && (mac != 0xFFFFFFFFFFFF)) {
    IpAddress ip;
    ip.set(ipv4);

    if(!isInDhcpRange(&ip))
      getAlertsQueue()->pushOutsideDhcpRangeAlert(_mac, sender_mac, ntohl(ipv4), ntohl(dhcp_reply->siaddr), vlan_id);
  }
}

/* *************************************** */

bool NetworkInterface::checkBroadcastDomainTooLarge(u_int32_t bcast_mask, u_int16_t vlan_id, const u_int8_t *src_mac, const u_int8_t *dst_mac, u_int32_t spa, u_int32_t tpa) const {
  if(bcast_mask < 0xFFFF0000) {
    getAlertsQueue()->pushBroadcastDomainTooLargeAlert(src_mac, dst_mac, spa, tpa, vlan_id);
    return true; /* At most a /16 broadcast domain is acceptable */
  }

  return false;
}

/* *************************************** */

/*
  Put here all the code that is executed when the NIC initialization
  is succesful
 */
bool NetworkInterface::initFlowDump(u_int8_t num_dump_interfaces) {
  if(isFlowDumpDisabled())
    return(false);

#if defined(NTOPNG_PRO) && defined(HAVE_NINDEX)
  if(ntop->getPrefs()->do_dump_flows_on_nindex()) {
    if(num_dump_interfaces >= NINDEX_MAX_NUM_INTERFACES) {
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
	aggregated_flows_hash = new AggregatedFlowHash(this,
						       max_val(4096, ntop->getPrefs()->get_max_num_flows()/4) /* num buckets */,
						       ntop->getPrefs()->get_max_num_flows());

	ntop->getPrefs()->enable_flow_aggregation();
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
    else if(ntop->getPrefs()->do_dump_flows_on_es())
      db = new ElasticSearch(this);
    else if(ntop->getPrefs()->do_dump_flows_on_ls())
      db = new Logstash(this);
#endif
  }

  return(db != NULL);
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
  if(!luactx->live_capture.matching_host /* No host filter set */
     || (f && (luactx->live_capture.matching_host == f->get_cli_host()
	       || luactx->live_capture.matching_host == f->get_srv_host()))) {
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
  ProtoStats _discardedProbingStats;

  sumStats(&_tcpFlowStats, &_ethStats, &pt->local_stats,
	   &pt->ndpi, &pt->packetStats, &pt->tcpPacketStats, &_discardedProbingStats);

  pt->engaged_alerts = getNumEngagedAlerts();
  pt->hosts = getNumHosts();
  pt->local_hosts = getNumLocalHosts();
  pt->devices = getNumL2Devices();
  pt->flows = getNumFlows();
  pt->http_hosts = getNumHTTPHosts();
  pt->l4Stats = l4Stats;
}

/* *************************************** */

void NetworkInterface::tsLua(lua_State* vm) {
  if(!ts_ring || !TimeseriesRing::isRingEnabled(this)) {
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

bool NetworkInterface::isLocalBroadcastDomainHost(Host * const h, bool is_inline_call) {
  IpAddress *i = h->get_ip();

  return(bcast_domains->isLocalBroadcastDomainHost(h, is_inline_call)
	 || (ntop->getLoadInterfaceAddresses() && i->match(ntop->getLoadInterfaceAddresses())));
}

/* *************************************** */

typedef std::map<std::string, ContainerStats> PodsMap;

static bool flow_get_pods_stats(GenericHashEntry *entry, void *user_data, bool *matched) {
  PodsMap *pods_stats = (PodsMap*)user_data;
  Flow *flow = (Flow*)entry;
  const ContainerInfo *cli_cont, *srv_cont;
  const char *cli_pod = NULL, *srv_pod = NULL;

  if((cli_cont = flow->getClientContainerInfo()) && cli_cont->data_type == container_info_data_type_k8s)
    cli_pod = cli_cont->data.k8s.pod;
  if((srv_cont = flow->getServerContainerInfo()) && srv_cont->data_type == container_info_data_type_k8s)
    srv_pod = srv_cont->data.k8s.pod;

  if(cli_pod) {
    ContainerStats stats = (*pods_stats)[cli_pod]; /* get existing or create new */
    const TcpInfo *client_tcp = flow->getClientTcpInfo();

    stats.incNumFlowsAsClient();
    stats.accountLatency(client_tcp ? client_tcp->rtt : 0, client_tcp ? client_tcp->rtt_var : 0, true /* as_client */);
    if(cli_cont->id)
      stats.addContainer(cli_cont->id);

    /* Update */
    (*pods_stats)[cli_pod] = stats;
  }

  if(srv_pod) {
    ContainerStats stats = (*pods_stats)[srv_pod]; /* get existing or create new */
    const TcpInfo *server_tcp = flow->getServerTcpInfo();

    stats.incNumFlowsAsServer();
    stats.accountLatency(server_tcp ? server_tcp->rtt : 0, server_tcp ? server_tcp->rtt_var : 0, false /* as server */);
    if(srv_cont->id)
      stats.addContainer(srv_cont->id);

    /* Update */
    (*pods_stats)[srv_pod] = stats;
  }

  return(false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::getPodsStats(lua_State* vm) {
  PodsMap pods_stats;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  PodsMap::iterator it;

  walker(&begin_slot, walk_all, walker_flows, flow_get_pods_stats, (void*)&pods_stats);

  lua_newtable(vm);

  for(it = pods_stats.begin(); it != pods_stats.end(); ++it) {
    it->second.lua(vm);

    lua_pushstring(vm, it->first.c_str());
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

typedef struct {
  const ContainerInfo *info;
  ContainerStats stats;
} ContainerData;

typedef std::map<std::string, ContainerData> ContainersMap;

struct containerRetrieverData {
  ContainersMap containers;
  const char *pod_filter;
};

static bool flow_get_container_stats(GenericHashEntry *entry, void *user_data, bool *matched) {
  ContainersMap *containers_data = &((containerRetrieverData*)user_data)->containers;
  const char *pod_filter = ((containerRetrieverData*)user_data)->pod_filter;
  Flow *flow = (Flow*)entry;
  const ContainerInfo *cli_cont, *srv_cont;
  const char *cli_cont_id = NULL, *srv_cont_id = NULL;
  const char *cli_pod = NULL, *srv_pod = NULL;

  if((cli_cont = flow->getClientContainerInfo())) {
    cli_cont_id = cli_cont->id;
    if(cli_cont->data_type == container_info_data_type_k8s)
      cli_pod = cli_cont->data.k8s.pod;
  }
  if((srv_cont = flow->getServerContainerInfo())) {
    srv_cont_id = srv_cont->id;
    if(srv_cont->data_type == container_info_data_type_k8s)
      srv_pod = srv_cont->data.k8s.pod;
  }

  if(cli_cont_id &&
	 ((!pod_filter) || (cli_pod && !strcmp(pod_filter, cli_pod)))) {
    ContainerData data = (*containers_data)[cli_cont_id]; /* get existing or create new */
    const TcpInfo *client_tcp = flow->getClientTcpInfo();

    data.stats.incNumFlowsAsClient();
    data.stats.accountLatency(client_tcp ? client_tcp->rtt : 0, client_tcp ? client_tcp->rtt_var : 0, true /* as_client */);
    data.info = cli_cont;

    /* Update */
    (*containers_data)[cli_cont_id] = data;
  }

  if(srv_cont_id &&
	 ((!pod_filter) || (srv_pod && !strcmp(pod_filter, srv_pod)))) {
    ContainerData data = (*containers_data)[srv_cont_id]; /* get existing or create new */
    const TcpInfo *server_tcp = flow->getServerTcpInfo();

    data.stats.incNumFlowsAsServer();
    data.stats.accountLatency(server_tcp ? server_tcp->rtt : 0, server_tcp ? server_tcp->rtt_var : 0, false /* as server */);
    data.info = srv_cont;

    /* Update */
    (*containers_data)[srv_cont_id] = data;
  }

  return(false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::getContainersStats(lua_State* vm, const char *pod_filter) {
  containerRetrieverData user_data;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  ContainersMap::iterator it;

  user_data.pod_filter = pod_filter;
  walker(&begin_slot, walk_all, walker_flows, flow_get_container_stats, (void*)&user_data);

  lua_newtable(vm);

  for(it = user_data.containers.begin(); it != user_data.containers.end(); ++it) {
    it->second.stats.lua(vm);

    if(it->second.info) {
      Utils::containerInfoLua(vm, it->second.info);
      lua_pushstring(vm, "info");
      lua_insert(vm, -2);
      lua_settable(vm, -3);
    }

    lua_pushstring(vm, it->first.c_str());
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool NetworkInterface::enqueueFlowToCompanion(ParsedFlow * const pf, bool skip_loopback_traffic) {
  if(skip_loopback_traffic
     && (pf->src_ip.isLoopbackAddress() || pf->dst_ip.isLoopbackAddress()))
    return false;

  if(companionQueue[next_compq_insert_idx])
    return false;

  if((companionQueue[next_compq_insert_idx] = new (std::nothrow) ParsedFlow(*pf))) {
    next_compq_insert_idx = (next_compq_insert_idx + 1) % COMPANION_QUEUE_LEN;
    return true;
  }

  return false;
}

/* *************************************** */

void NetworkInterface::incNumAlertedFlows(Flow *f) {
  num_active_alerted_flows++;

#ifdef ALERTED_FLOWS_DEBUG
  if(f) {
    char buf[256];
    ntop->getTrace()->traceEvent(TRACE_WARNING, "[inc][num_active_alerted_flows: %u][num_idle_alerted_flows: %u] %s",
				 num_active_alerted_flows,
				 num_idle_alerted_flows,
				 f->print(buf, sizeof(buf)));
  }
#endif
}


/* *************************************** */

void NetworkInterface::decNumAlertedFlows(Flow *f){
  num_idle_alerted_flows++;

#ifdef ALERTED_FLOWS_DEBUG
  if(f) {
    char buf[256];
    ntop->getTrace()->traceEvent(TRACE_WARNING, "[dec][num_active_alerted_flows: %u][num_idle_alerted_flows: %u] %s",
				 num_active_alerted_flows,
				 num_idle_alerted_flows,
				 f->print(buf, sizeof(buf)));
  }
#endif
};

/* *************************************** */

u_int64_t NetworkInterface::getNumActiveAlertedFlows() const {
  if(num_active_alerted_flows >= num_idle_alerted_flows)
    return num_active_alerted_flows - num_idle_alerted_flows;
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error, active alerted flows less than idle alerted flows");
    return 0;
  }
};

/* *************************************** */

bool NetworkInterface::dequeueFlowFromCompanion(ParsedFlow **f) {
  if(!companionQueue[next_compq_remove_idx]) {
    *f = NULL;
    return false;
  }

  *f = companionQueue[next_compq_remove_idx];
  companionQueue[next_compq_remove_idx] = NULL;
  next_compq_remove_idx = (next_compq_remove_idx + 1) % COMPANION_QUEUE_LEN;

  return true;
}

/* *************************************** */

static void handle_entity_alerts(AlertCheckLuaEngine *acle, AlertableEntity *entity) {
  lua_State *L = acle->getState();

  lua_getglobal(L, USER_SCRIPTS_RUN_CALLBACK); /* Called function */
  lua_pushstring(L, acle->getGranularity());  /* push 1st argument */
  acle->pcall(1 /* num args */, 0);
}

/* *************************************** */

static bool host_alert_check(GenericHashEntry *h, void *user_data, bool *matched) {
  AlertCheckLuaEngine *acle = (AlertCheckLuaEngine*)user_data;
  Host *host = (Host*)h;

  acle->setHost(host);
  handle_entity_alerts(acle, host);

  host->housekeepAlerts(acle->getPeriodicity() /* periodicity */);

  /* Stop as soon as a shutdown is in progress or the process
     could hang for too long. */
  return ntop->getGlobals()->isShutdownRequested();
}

/* *************************************** */

void NetworkInterface::checkHostsAlerts(ScriptPeriodicity p) {
  u_int32_t begin_slot = 0;
  AlertCheckLuaEngine acle(alert_entity_host, p, this);

  /* ... then iterate all hosts */
  walker(&begin_slot, true /* walk_all */, walker_hosts, host_alert_check, &acle);
}

/* *************************************** */

void NetworkInterface::checkNetworksAlerts(ScriptPeriodicity p) {
  AlertCheckLuaEngine acle(alert_entity_network, p, this);

  /* ... then iterate all networks */
  u_int8_t num_local_networks = ntop->getNumLocalNetworks();

  for(u_int8_t network_id = 0; network_id < num_local_networks; network_id++) {
    NetworkStats *netstats = getNetworkStats(network_id);

    acle.setNetwork(netstats);
    handle_entity_alerts(&acle, netstats);

    netstats->housekeepAlerts(p);
  }
}

/* *************************************** */

void NetworkInterface::checkInterfaceAlerts(ScriptPeriodicity p) {
  AlertCheckLuaEngine acle(alert_entity_interface, p, this);

  handle_entity_alerts(&acle, this);
}

/* *************************************** */

u_int32_t NetworkInterface::getNumEngagedAlerts() {
  u_int32_t ctr = 0;

  for(u_int i = 0; i < MAX_NUM_PERIODIC_SCRIPTS; i++)
    ctr += num_alerts_engaged[i];

  return(ctr);
}

/* *************************************** */

struct alertable_walker_data {
  alertable_callback *callback;
  void *user_data;
};

static bool host_invoke_alertable_callback(GenericHashEntry *entity, void *user_data, bool *matched) {
  AlertableEntity *alertable = dynamic_cast<AlertableEntity*>(entity);
  struct alertable_walker_data *data = (struct alertable_walker_data *) user_data;

  data->callback(alertable, data->user_data);
  *matched = true;

  return(false); /* false = keep on walking */
}

/* *************************************** */

/* Walks alertable entities on this interface.
 * The user provided callback is called with the alertable_walker_data.user_data
 * parameter set to the provided user_data.
 */
void NetworkInterface::walkAlertables(int entity_type, const char *entity_value,
				      std::set<int> *entity_excludes,
				      alertable_callback *callback, void *user_data) {
  std::map<std::pair<AlertEntity, std::string>, AlertableEntity*>::iterator it;

  /* Hosts */
  if(((entity_type == alert_entity_none) || (entity_type == alert_entity_host)) &&
     (!entity_excludes || (!entity_excludes->count(alert_entity_host)))) {
    if(entity_value == NULL) {
      struct alertable_walker_data data;
      bool walk_all = true;
      u_int32_t begin_slot = 0;

      data.callback = callback;
      data.user_data = user_data;

      walker(&begin_slot, walk_all, walker_hosts, host_invoke_alertable_callback, &data);
    } else {
      /* Specific host */
      char *host_ip = NULL;
      u_int16_t vlan_id = 0;
      char buf[64];
      Host *host;

      get_host_vlan_info((char*)entity_value, &host_ip, &vlan_id, buf, sizeof(buf));

      if(host_ip && (host = getHost(host_ip, vlan_id, false /* not inline */)))
        callback(host, user_data);
    }
  }

  /* Interface */
  if(((entity_type == alert_entity_none) || (entity_type == alert_entity_interface)) &&
     (!entity_excludes || !entity_excludes->count(alert_entity_interface))) {
    if((entity_value != NULL) && (getEntityValue().compare(entity_value) != 0))
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Interface filter does not correspond[type=%u]: expected %s, found %s",
        entity_type, entity_value, getEntityValue().c_str());

    callback(this, user_data);
  }

  /* Networks */
  if(((entity_type == alert_entity_none) || (entity_type == alert_entity_network)) &&
    (!entity_excludes || !entity_excludes->count(alert_entity_network))) {
    u_int8_t num_local_networks = ntop->getNumLocalNetworks();

    for(u_int8_t network_id = 0; network_id < num_local_networks; network_id++) {
      NetworkStats *netstats = getNetworkStats(network_id);

      if((entity_value == NULL) || (netstats->getEntityValue().compare(entity_value) == 0))
        callback(netstats, user_data);
    }
  }

  /* External Alerts.
   * Must lock in order to avoid concurrency issues with insertions/updates */
  external_alerts_lock.lock(__FILE__, __LINE__);

  for(it = external_alerts.begin(); it != external_alerts.end(); ++it) {
    if(((entity_type == alert_entity_none) || (entity_type == it->second->getEntityType())) &&
       (!entity_excludes || !entity_excludes->count(it->second->getEntityType()))) {
      if((entity_value == NULL) || (it->second->getEntityValue().compare(entity_value) == 0)) {
        callback(it->second, user_data);
      }
    }
  }

  external_alerts_lock.unlock(__FILE__, __LINE__);
}

/* *************************************** */

static void count_alerts_callback(AlertableEntity *alertable, void *user_data) {
  grouped_alerts_counters *counters = (grouped_alerts_counters*) user_data;

  alertable->countAlerts(counters);
}

void NetworkInterface::getEngagedAlertsCount(lua_State *vm, int entity_type,
					     const char *entity_value, std::set<int> *entity_excludes) {
  grouped_alerts_counters counters;
  u_int32_t tot_alerts = 0;
  std::map<AlertType, u_int32_t>::iterator it;
  std::map<AlertLevel, u_int32_t>::iterator it2;

  walkAlertables(entity_type, entity_value, entity_excludes, count_alerts_callback, &counters);

  /* Results */
  lua_newtable(vm);

  /* Type counters */
  lua_newtable(vm);

  for(it = counters.types.begin(); it != counters.types.end(); ++it) {
    tot_alerts += it->second;

    lua_pushinteger(vm, it->second);
    lua_pushinteger(vm, it->first);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  lua_pushstring(vm, "type");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* Severity counters */
  lua_newtable(vm);

  for(it2 = counters.severities.begin(); it2 != counters.severities.end(); ++it2) {
    lua_pushinteger(vm, it2->second);
    lua_pushinteger(vm, it2->first);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }

  lua_pushstring(vm, "severities");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* Total */
  lua_push_int32_table_entry(vm, "num_alerts", tot_alerts);
}

/* *************************************** */

static bool host_release_engaged_alerts(GenericHashEntry *entity, void *user_data, bool *matched) {
  Host *host = (Host *) entity;
  AlertCheckLuaEngine *host_script = (AlertCheckLuaEngine *)user_data;

  if(host->getNumTriggeredAlerts()) {
    lua_getglobal(host_script->getState(), USER_SCRIPTS_RELEASE_ALERTS_CALLBACK);
    host_script->setHost(host);
    host_script->pcall(0, 0);
  }

  *matched = true;

  return(false); /* false = keep on walking */
}

/* *************************************** */

void NetworkInterface::releaseAllEngagedAlerts() {
  AlertCheckLuaEngine network_script(alert_entity_network, minute_script /* doesn't matter */, this);
  AlertCheckLuaEngine host_script(alert_entity_host, minute_script /* doesn't matter */, this);
  u_int8_t num_local_networks = ntop->getNumLocalNetworks();
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  /* Hosts */
  walker(&begin_slot, walk_all, walker_hosts, host_release_engaged_alerts, &host_script);

  /* Interface */
  if(getNumTriggeredAlerts()) {
    AlertCheckLuaEngine interface_script(alert_entity_interface, minute_script /* doesn't matter */, this);
    lua_getglobal(interface_script.getState(), USER_SCRIPTS_RELEASE_ALERTS_CALLBACK);
    interface_script.pcall(0, 0);
  }

  /* Networks */
  for(u_int8_t network_id = 0; network_id < num_local_networks; network_id++) {
    NetworkStats *stats = getNetworkStats(network_id);

    if(stats->getNumTriggeredAlerts()) {
      lua_getglobal(network_script.getState(), USER_SCRIPTS_RELEASE_ALERTS_CALLBACK);
      network_script.setNetwork(stats);
      network_script.pcall(0, 0);
    }
  }
}

/* *************************************** */

struct get_engaged_alerts_userdata {
  lua_State *vm;
  AlertType alert_type;
  AlertLevel alert_severity;
  u_int idx;
};

static void get_engaged_alerts_callback(AlertableEntity *alertable, void *user_data) {
  struct get_engaged_alerts_userdata *data = (struct get_engaged_alerts_userdata *)user_data;

  alertable->getAlerts(data->vm, no_periodicity, data->alert_type, data->alert_severity, &data->idx);
}

void NetworkInterface::getEngagedAlerts(lua_State *vm, int entity_type,
					const char *entity_value, AlertType alert_type,
					AlertLevel alert_severity, std::set<int> *entity_excludes) {
  struct get_engaged_alerts_userdata data;

  data.vm = vm;
  data.idx = 0;
  data.alert_type = alert_type;
  data.alert_severity = alert_severity;

  lua_newtable(vm);

  walkAlertables(entity_type, entity_value, entity_excludes, get_engaged_alerts_callback, &data);
}

/* *************************************** */

AlertableEntity* NetworkInterface::lockExternalAlertable(AlertEntity entity, const char *entity_val, bool create_if_missing) {
  std::map<std::pair<AlertEntity, std::string>, AlertableEntity*>::iterator it;
  std::pair<AlertEntity, std::string> key(entity, entity_val);
  AlertableEntity *alertable;

  external_alerts_lock.lock(__FILE__, __LINE__);

  if((it = external_alerts.find(key)) == external_alerts.end()) {
    if(!create_if_missing) {
      external_alerts_lock.unlock(__FILE__, __LINE__);
      return(NULL);
    }

    alertable = new AlertableEntity(this, entity);
    alertable->setEntityValue(entity_val);
    external_alerts[key] = alertable;
  } else
    alertable = it->second;

  return(alertable);
}

/* *************************************** */

void NetworkInterface::unlockExternalAlertable(AlertableEntity *alertable) {
  /* Must refresh before being able to read the updated count */
  alertable->refreshAlerts();

  if(alertable->getNumTriggeredAlerts() == 0) {
    std::pair<AlertEntity, std::string> key(alertable->getEntityType(), alertable->getEntityValue());

    external_alerts.erase(key);
    delete alertable;
  }

  external_alerts_lock.unlock(__FILE__, __LINE__);
}

/* *************************************** */

struct ndpi_detection_module_struct* NetworkInterface::get_ndpi_struct() const {
  return(ntop->get_ndpi_struct());
};

/* *************************************** */

static bool run_min_flows_tasks(GenericHashEntry *f, void *user_data, bool *matched) {
  Flow *flow = (Flow*)f;

  /* Update the peers score */
  if(flow->unsafeGetClient()) flow->unsafeGetClient()->incScore(flow->getCliScore());
  if(flow->unsafeGetServer()) flow->unsafeGetServer()->incScore(flow->getSrvScore());
  flow->setPeersScoreAccounted();

  *matched = true;
  return(false); /* false = keep on walking */
}

void NetworkInterface::runMinFlowsTasks() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  /* This function accesses shared host data via unsafeGetClient/unsafeGetServer
   * so cannot be called concurrently on subinterfaces. */
  if(isSubInterface())
    return;

  if(flows_hash)
    walker(&begin_slot, walk_all, walker_flows, run_min_flows_tasks, NULL);
}
