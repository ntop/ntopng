/*
 *
 * (C) 2013-23 - ntop.org
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
extern int ntop_lua_cli_print(lua_State *vm);
extern int ntop_lua_check(lua_State *vm, const char *func, int pos,
                          int expected_type);

static bool help_printed = false;

// #define DEBUG_FLOW_CHECKS 1

#define IMPLEMENT_SMART_FRAGMENTS

/* **************************************************** */

/* Method used for collateral activities */
NetworkInterface::NetworkInterface()
    : NetworkInterfaceAlertableEntity(this, alert_entity_interface) {
  init(NULL);
}

/* **************************************************** */

NetworkInterface::NetworkInterface(const char *name,
                                   const char *custom_interface_type)
    : NetworkInterfaceAlertableEntity(this, alert_entity_interface) {
  char _ifname[MAX_INTERFACE_NAME_LEN], buf[MAX_INTERFACE_NAME_LEN];
  /* We need to do it as isView() is not yet initialized */
  char pcap_error_buffer[PCAP_ERRBUF_SIZE];

  if (name == NULL) {
    if (!help_printed)
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "No capture interface specified");

    printAvailableInterfaces(false, 0, NULL, 0);

    name = Utils::ntop_lookupdev(_ifname, sizeof(_ifname));

    if (name == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Unable to locate default interface (%s)\n",
                                   pcap_error_buffer);
      exit(0);
    }
  } else {
    if (isNumber(name)) {
      /* We need to convert this numeric index into an interface name */
      int id = atoi(name);

      _ifname[0] = '\0';
      printAvailableInterfaces(false, id, _ifname, sizeof(_ifname));

      if (_ifname[0] == '\0') {
        ntop->getTrace()->traceEvent(TRACE_WARNING,
                                     "Unable to locate interface Id %d", id);
        printAvailableInterfaces(false, 0, NULL, 0);
        exit(0);
      }

      name = _ifname;
    }
  }

  init(name);

  customIftype = custom_interface_type;
  influxdb_ts_exporter = rrd_ts_exporter = NULL;
  flow_checks_executor = prev_flow_checks_executor = NULL;
  host_checks_executor = prev_host_checks_executor = NULL;
  flows_dump_json = true; /* JSON dump enabled by default, possibly disabled in
                             NetworkInterface::startFlowDumping */
  flows_dump_json_use_labels =
      false; /* Dump of JSON labels disabled by default, possibly enabled in
                NetworkInterface::startFlowDumping */
  memset(ifMac, 0, sizeof(ifMac));

#ifdef WIN32
  if (name == NULL) name = "1"; /* First available interface */
#endif

  scalingFactor = 1;
  if (strcmp(name, "-") == 0) name = "stdin";
  if (strcmp(name, "-") == 0) name = "stdin";

  id = Utils::ifname2id(name);

  purge_idle_flows_hosts = true;

  if (custom_interface_type)
    ifDescription = strdup(name);
  else
    ifDescription =
        strdup(Utils::getInterfaceDescription(ifname, buf, sizeof(buf)));

  if (strchr(name, ':') || strchr(name, '@') || (!strcmp(name, "dummy")) ||
      strchr(name, '/')        /* file path */
      || strstr(name, ".pcap") /* pcap */
      || (strncmp(name, "lo", 2) == 0) ||
      (strcmp(name, SYSTEM_INTERFACE_NAME) == 0)
#if !defined(__APPLE__) && !defined(WIN32)
      || (Utils::readIPv4((char *)name) == 0)
#endif
      || custom_interface_type) {
    ; /* Don't setup MDNS on ZC or RSS interfaces */
  } else {
    ipv4_network = ipv4_network_mask = 0;
    if (pcap_lookupnet(ifname, &ipv4_network, &ipv4_network_mask,
                       pcap_error_buffer) == -1) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to read IPv4 address of %s: %s",
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
        } catch (...) {
          mdns = NULL;
        }
      }
    }
  }

#if defined(NTOPNG_PRO)
  pMap = NULL, sMap = NULL;
#endif

  if (id >= 0) {
    last_pkt_rcvd = last_pkt_rcvd_remote = 0, pollLoopCreated = false,
    flowDumpLoopCreated = false,
    hostAlertsDequeueLoopCreated = flowAlertsDequeueLoopCreated = false,
    bridge_interface = false;
    next_idle_flow_purge = next_idle_host_purge = next_idle_other_purge = 0;
    cpu_affinity = -1 /* no affinity */,
    has_vlan_packets = has_ebpf_events = false;
    running = false, inline_interface = false;

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
  flow_profiles = ntop->getPro()->has_valid_license() ? new (std::nothrow)
                                                            FlowProfiles(id)
                                                      : NULL;
  if (flow_profiles) flow_profiles->loadProfiles();
  shadow_flow_profiles = NULL;
#endif

  /* Lazy, instantiated on demand */
  custom_app_stats = NULL;
  flow_interfaces_stats = NULL;
#endif

  loadScalingFactorPrefs();

  statsManager = NULL, alertStore = NULL, alertsQueue = NULL;
  ndpiStats = NULL;
  dscpStats = NULL;

  host_pools = new (std::nothrow) HostPools(this);
  bcast_domains = new (std::nothrow) BroadcastDomains(this);

#ifdef __linux__
  /*
    A bit aggressive but as people usually
    ignore warnings let's be proactive
  */
  if (ifname && (!isView()) && (!strstr(ifname, ":")) &&
      (!strstr(ifname, ".pcap")) && strcmp(ifname, "dummy") &&
      strcmp(ifname, "any") && strcmp(ifname, "virbr") &&
      strcmp(ifname, "wlan") && strncmp(ifname, "lo", 2) &&
      strcmp(ifname, SYSTEM_INTERFACE_NAME)) {
    char ifaces[MAX_INTERFACE_NAME_LEN], *tmp, *iface;

    snprintf(ifaces, sizeof(ifaces), "%s", ifname);
    iface = strtok_r(ifaces, ",", &tmp);

    while (iface != NULL) {
      Utils::disableOffloads(iface);
      iface = strtok_r(NULL, ",", &tmp);
    }
  }
#endif

  is_loopback = (strncmp(ifname, "lo", 2) == 0) ? true : false;

  updateTrafficMirrored();
  updateSmartRecording();
  updateDynIfaceTrafficPolicy();
  updateFlowDumpDisabled();
  updateLbdIdentifier();
  updateDiscardProbingTraffic();
  updateFlowsOnlyInterface();
}

/* **************************************************** */

void NetworkInterface::init(const char *interface_name) {
  ifname = interface_name ? strdup(interface_name) : NULL;
  inline_interface = false, has_vlan_packets = false, has_ebpf_events = false,
  has_seen_dhcp_addresses = false, has_seen_containers = false,
  has_seen_pods = false, has_external_alerts = false,
  last_pkt_rcvd = last_pkt_rcvd_remote = 0,
  next_idle_flow_purge = next_idle_host_purge = 0, running = false,
  shutting_down = false, customIftype = NULL,
  is_loopback = is_traffic_mirrored = false, lbd_serialize_by_mac = false,
  is_smart_recording_enabled = false;
  smart_recording_instance_name = NULL;
  discard_probing_traffic = false;
  flows_only_interface = false;
  numSubInterfaces = 0;
  ip_reassignment_alerts_enabled = false;
  pcap_datalink_type = 0, mtuWarningShown = false,
  purge_idle_flows_hosts = true, id = (u_int8_t)-1, last_remote_pps = 0,
  last_remote_bps = 0, has_vlan_packets = false,
  cpu_affinity = -1 /* no affinity */, 
  interfaceStats = NULL, has_too_many_hosts = has_too_many_flows = false,
  flow_dump_disabled = false, numL2Devices = 0,
  totalNumHosts = numTotalRxOnlyHosts = numLocalHosts = numLocalRxOnlyHosts = 0,
  arp_requests = arp_replies = 0, has_mac_addresses = false,
  checkpointPktCount = checkpointBytesCount = checkpointPktDropCount =
      checkpointDroppedAlertsCount = 0,
  checkpointDiscardedProbingPktCount = checkpointDiscardedProbingBytesCount = 0,
  pollLoopCreated = false, bridge_interface = false, mdns = NULL,
  discovery = NULL, ifDescription = NULL, flowHashingMode = flowhashing_none;
  num_new_flows = 0;
  last_obs_point_id = 0;

  flows_hash = NULL, hosts_hash = NULL;
  macs_hash = NULL, ases_hash = NULL, oses_hash = NULL, vlans_hash = NULL,
  obs_hash = NULL;
  countries_hash = NULL;
  gw_macs = NULL;

  is_dynamic_interface = false;
  dynamic_interface_master = NULL;
  dynamic_interface_criteria = 0;
  dynamic_interface_mode = flowhashing_none;
  show_dynamic_interface_traffic = false;

  top_sites = NULL;
  top_os = NULL;

  reload_hosts_bcast_domain = false;
  hosts_bcast_domain_last_update = 0;
  hosts_to_restore = new (std::nothrow) StringFifoQueue(64);

  ip_addresses = "", networkStats = NULL, pcap_datalink_type = 0,
  cpu_affinity = -1;

  gettimeofday(&last_periodic_stats_update, NULL);
  num_live_captures = 0;
  num_host_dropped_alerts = num_flow_dropped_alerts = num_other_dropped_alerts =
      0;
  num_written_alerts = num_alerts_queries = 0;
  score_as_cli = score_as_srv = 0;
  memset(live_captures, 0, sizeof(live_captures));
  memset(&num_alerts_engaged_notice, 0, sizeof(num_alerts_engaged_notice)),
      memset(&num_alerts_engaged_warning, 0,
             sizeof(num_alerts_engaged_warning)),
      memset(&num_alerts_engaged_error, 0, sizeof(num_alerts_engaged_error)),
      memset(&num_alerts_engaged_critical, 0,
             sizeof(num_alerts_engaged_critical)),
      memset(&num_alerts_engaged_emergency, 0,
             sizeof(num_alerts_engaged_emergency));
  tot_num_anomalies.local_hosts = tot_num_anomalies.remote_hosts = 0;
  num_active_alerted_flows_notice = 0, num_active_alerted_flows_warning = 0,
  num_active_alerted_flows_error = 0;

  is_view = false;
  viewed_by = NULL;
  viewed_interface_id = 0;
  download_stats = upload_stats = NULL;

  db = NULL;
#ifdef NTOPNG_PRO
  custom_app_stats = NULL;
  flow_interfaces_stats = NULL;
  policer = NULL;

  /* Behavior init variables */
  nextMinPeriodicUpdate = 0;
  score_behavior = new BehaviorAnalysis();
  traffic_tx_behavior =
      new BehaviorAnalysis(0.9 /* Alpha parameter */, 0.1 /* Beta parameter */,
                           0.05 /* Significance */, true /* Counter */);
  traffic_rx_behavior =
      new BehaviorAnalysis(0.9 /* Alpha parameter */, 0.1 /* Beta parameter */,
                           0.05 /* Significance */, true /* Counter */);
#endif
  ndpiStats = NULL;
  dscpStats = NULL;
  statsManager = NULL, alertStore = NULL, ifSpeed = 0;
  host_pools = NULL;
  bcast_domains = NULL;
  ifMTU = CONST_DEFAULT_MAX_PACKET_SIZE, mtuWarningShown = false;
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  flow_profiles = shadow_flow_profiles = NULL;
  sub_interfaces = NULL;
#endif
#endif
#ifdef NTOPNG_PRO
  dhcp_last_sec_pkts = 0, last_sec_epoch = 0;
#endif

  dhcp_ranges = dhcp_ranges_shadow = NULL;

  if (bridge_interface || is_dynamic_interface || isView())
    ;
  else
    companionQueue = new (std::nothrow) ParsedFlow *[COMPANION_QUEUE_LEN]();
  next_compq_insert_idx = next_compq_remove_idx = 0;
  last_purge_idle = 0;
  idleFlowsToDump = activeFlowsToDump = NULL;
  flowAlertsQueue = new (std::nothrow)
      SPSCQueue<FlowAlert *>(MAX_FLOW_CHECKS_QUEUE_LEN, "flowAlertsQueue");
  hostAlertsQueue = new (std::nothrow) SPSCQueue<HostAlertReleasedPair>(
      MAX_HOST_CHECKS_QUEUE_LEN, "hostAlertsQueue");
  flow_serial = 0;

  /* nDPI handling */
  ndpi_cleanup_needed = false;
  last_ndpi_reload = 0;
  ndpiReloadInProgress = false;
  ndpi_struct_shadow = NULL;
  ndpi_struct = initnDPIStruct();
  ndpi_finalize_initialization(ndpi_struct);

#if defined(HAVE_KAFKA) && defined(NTOPNG_PRO)
  kafka = NULL;
#endif
  customFlowLuaScript_proto = customFlowLuaScript_periodic =
      customFlowLuaScript_end = NULL;
  customHostLuaScript = NULL;

  INTERFACE_PROFILING_INIT();
}

/* **************************************************** */

void NetworkInterface::cleanShadownDPI() {
  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%p)", __FUNCTION__,
                               ndpi_struct_shadow);

  ndpi_exit_detection_module(ndpi_struct_shadow);
  ndpi_struct_shadow = NULL;
}

/* ******************** */

u_int16_t NetworkInterface::getnDPIProtoByName(const char *name) {
  return (ndpi_get_proto_by_name(get_ndpi_struct(), name));
}

/* ********************** */

struct ndpi_detection_module_struct *NetworkInterface::initnDPIStruct() {
  struct ndpi_detection_module_struct *ndpi_s =
      ndpi_init_detection_module(ndpi_track_flow_payload);
  ndpi_port_range d_port[MAX_DEFAULT_PORTS];
  NDPI_PROTOCOL_BITMASK all;

  if (ndpi_s == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to initialize nDPI");
    exit(-1);
  }

  // enable all protocols
  NDPI_BITMASK_SET_ALL(all);
  ndpi_set_protocol_detection_bitmask2(ndpi_s, &all);

  if (ntop->getCustomnDPIProtos() != NULL)
    ndpi_load_protocols_file(ndpi_s, ntop->getCustomnDPIProtos());

  memset(d_port, 0, sizeof(d_port));
  ndpi_set_proto_defaults(ndpi_s, 0, 0, NDPI_PROTOCOL_UNRATED,
                          NTOPNG_NDPI_OS_PROTO_ID, (char *)"Operating System",
                          NDPI_PROTOCOL_CATEGORY_SYSTEM_OS, d_port, d_port);

  // load custom protocols
  loadProtocolsAssociations(ndpi_s);

#ifdef NTOPNG_PRO
  if (ifname && strcmp(ifname, SYSTEM_INTERFACE_NAME)) {
    AlertExclusions *excl = ntop->getAlertExclusions();

    if (excl) excl->loadnDPIExclusions(ndpi_s);
  }
#endif

  return (ndpi_s);
}

/* **************************************************** */

/* Operations are performed in the followinf order:
 *
 * 1. initnDPIReload()
 * 2. ... nDPILoadIPCategory/nDPILoadHostnameCategory() ...
 * 3. finalizenDPIReload()
 * 4. cleanShadownDPI()
 */
bool NetworkInterface::initnDPIReload() {
  ntop->getTrace()->traceEvent(TRACE_INFO, "Started nDPI reload %s",
                               ndpiReloadInProgress ? "[IN PROGRESS]" : "");

  if (ndpiReloadInProgress) {
    /*
      Do not display this alert for subinterfaces as they might have been
      created on the fly and thus trigger this alert
    */
    if (!isSubInterface())
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Internal error: nested nDPI category reload");

    return (false);
  }

  ndpiReloadInProgress = true;
  cleanShadownDPI();

  /* No need to dedicate another variable for the reload, we can use the shadow
   * itself */
  ndpi_struct_shadow = initnDPIStruct();
  return (true);
}

/* **************************************************** */

void NetworkInterface::finalizenDPIReload() {
  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%p)", __FUNCTION__,
                               ndpi_struct_shadow);

  if (!ndpiReloadInProgress) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Internal error: nested nDPI category reload");
    return;
  }

  if (ndpi_struct_shadow) {
    struct ndpi_detection_module_struct *old_struct;

    ntop->getTrace()->traceEvent(TRACE_INFO,
                                 "Going to reload custom categories");

    /* The new categories were loaded on the current ndpi_struct_shadow */
    ndpi_enable_loaded_categories(ndpi_struct_shadow);
    ndpi_finalize_initialization(ndpi_struct_shadow);

    ntop->getTrace()->traceEvent(TRACE_INFO, "nDPI finalizing reload...");

    old_struct = ndpi_struct;
    ndpi_struct = ndpi_struct_shadow;
    ndpi_struct_shadow = old_struct;

    reloadHostsBlacklist();

    ntop->getTrace()->traceEvent(TRACE_INFO, "nDPI reload completed");
    ndpiReloadInProgress = false;
  }
}

/* ******************************************* */

void NetworkInterface::loadProtocolsAssociations(
    struct ndpi_detection_module_struct *ndpi_str) {
  char **keys, **values;
  Redis *redis = ntop->getRedis();
  int rc;

  if (!redis) return;

  rc = redis->hashGetAll(CUSTOM_NDPI_PROTOCOLS_ASSOCIATIONS_HASH, &keys,
                         &values);

  if (rc > 0) {
    for (int i = 0; i < rc; i++) {
      u_int16_t protoId;
      ndpi_protocol_category_t protoCategory;

      if (keys[i] && values[i]) {
        protoId = atoi(keys[i]);
        protoCategory = (ndpi_protocol_category_t)atoi(values[i]);

        ntop->getTrace()->traceEvent(
            TRACE_INFO, "Loading protocol association: ID %d -> category %d",
            protoId, protoCategory);
        ndpi_set_proto_category(ndpi_str, protoId, protoCategory);
      }

      if (values[i]) free(values[i]);
      if (keys[i]) free(keys[i]);
    }

    free(keys);
    free(values);
  }
}

/* *************************************** */

bool NetworkInterface::nDPILoadIPCategory(char *what,
                                          ndpi_protocol_category_t id,
                                          char *list_name) {
  bool success = true;

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p) [%s]", __FUNCTION__,
  // ndpi_struct_shadow, what);

  if (what && ndpi_struct_shadow)
    success = (ndpi_load_ip_category(ndpi_struct_shadow, what, id,
                                     (void *)list_name) == 0);

  return success;
}

/* *************************************** */

bool NetworkInterface::nDPILoadHostnameCategory(
    char *what, ndpi_protocol_category_t id, char *list_name /* NOT used */) {
  bool success = true;

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p) [%s]", __FUNCTION__,
  // ndpi_struct_shadow, what);

  if (what && ndpi_struct_shadow)
    success = (ndpi_load_hostname_category(ndpi_struct_shadow, what, id) == 0);

  return success;
}

/* *************************************** */

int NetworkInterface::nDPILoadMaliciousJA3Signatures(const char *file_path) {
  int n = 0;

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p) [%s]", __FUNCTION__,
  // ndpi_struct_shadow, what);

  if (file_path && ndpi_struct_shadow)
    n = ndpi_load_malicious_ja3_file(ndpi_struct_shadow, file_path);

  return n;
}

/* *************************************** */

ndpi_protocol_category_t NetworkInterface::get_ndpi_proto_category(
    u_int protoid) {
  ndpi_protocol proto;

  proto.app_protocol = NDPI_PROTOCOL_UNKNOWN;
  proto.master_protocol = protoid;
  proto.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;

  return (get_ndpi_proto_category(proto));
}

/* *************************************** */

void NetworkInterface::setnDPIProtocolCategory(
    u_int16_t protoId, ndpi_protocol_category_t protoCategory) {
  ndpi_set_proto_category(get_ndpi_struct(), protoId, protoCategory);
}

/* **************************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::initL7Policer() {
  /* Instantiate the policer */
  policer = new (std::nothrow) L7Policer(this);
}

#endif

/* **************************************************** */

void NetworkInterface::checkDisaggregationMode() {
  char rkey[128], rsp[64];

  if (customIftype || isSubInterface()) return;

  snprintf(rkey, sizeof(rkey), CONST_IFACE_DYN_IFACE_MODE_PREFS, id);

  if ((!ntop->getRedis()->get(rkey, rsp, sizeof(rsp))) && (rsp[0] != '\0')) {
    if (getIfType() == interface_type_ZMQ) { /* ZMQ interface */
      if (!strcmp(rsp, DISAGGREGATION_PROBE_IP))
        flowHashingMode = flowhashing_probe_ip;
      else if (!strcmp(rsp, DISAGGREGATION_IFACE_ID))
        flowHashingMode = flowhashing_iface_idx;
      else if (!strcmp(rsp, DISAGGREGATION_INGRESS_IFACE_ID))
        flowHashingMode = flowhashing_ingress_iface_idx;
      else if (!strcmp(rsp, DISAGGREGATION_INGRESS_PROBE_IP_AND_IFACE_ID))
        flowHashingMode = flowhashing_probe_ip_and_ingress_iface_idx;
      else if (!strcmp(rsp, DISAGGREGATION_INGRESS_VRF_ID))
        flowHashingMode = flowhashing_vrfid;
      else if (!strcmp(rsp, DISAGGREGATION_VLAN))
        flowHashingMode = flowhashing_vlan;
      else if (strcmp(rsp, DISAGGREGATION_NONE))
        ntop->getTrace()->traceEvent(
            TRACE_ERROR, "Unknown aggregation value for interface %s [rsp: %s]",
            get_type(), rsp);
    } else { /* non-ZMQ interface */
      if (!strcmp(rsp, DISAGGREGATION_VLAN))
        flowHashingMode = flowhashing_vlan;
      else if (strcmp(rsp, DISAGGREGATION_NONE))
        ntop->getTrace()->traceEvent(
            TRACE_ERROR, "Unknown aggregation value for interface %s [rsp: %s]",
            get_type(), rsp);
    }
  }

  /* Populate ignored interfaces */
  rsp[0] = '\0';
  if ((!ntop->getRedis()->get((char *)CONST_RUNTIME_PREFS_IGNORED_INTERFACES,
                              rsp, sizeof(rsp))) &&
      (rsp[0] != '\0')) {
    char *token;
    char *rest = rsp;

    while ((token = strtok_r(rest, ",", &rest)))
      flowHashingIgnoredInterfaces.insert(atoi(token));
  }

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  sub_interfaces = ntop->getPrefs()->is_enterprise_m_edition()
                       ? new (std::nothrow) SubInterfaces(this)
                       : NULL;
#endif
#endif
}

/* **************************************************** */

void NetworkInterface::loadScalingFactorPrefs() {
  if (ntop->getRedis() != NULL) {
    char rkey[128], rsp[16];
    u_int32_t scaling_factor = 0;

    snprintf(rkey, sizeof(rkey), CONST_IFACE_SCALING_FACTOR_PREFS, id);

    if ((ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) &&
        (rsp[0] != '\0'))
      scaling_factor = atol(rsp);

    if (scaling_factor > 0) setScalingFactor(scaling_factor);
  }
}

/* **************************************************** */

/* Whether the initialization procedure is completed for this interface */
bool NetworkInterface::isStartingUp() const {
  return !running && !ntop->getGlobals()->isShutdownRequested() &&
         !ntop->getGlobals()->isShutdown();
}

/* **************************************************** */

/* Whether the interface is running and ntopng is not shutting down */
bool NetworkInterface::isRunning() const {
  return running && !ntop->getGlobals()->isShutdownRequested() &&
         !ntop->getGlobals()->isShutdown();
}

/* **************************************************** */

/* Whether the interface is running and shutting down (flows/hosts purge already
 * completed) */
bool NetworkInterface::isShuttingDown() const {
  return !running && shutting_down;
}

/* **************************************************** */

bool NetworkInterface::getInterfaceBooleanPref(const char *pref_key,
                                               bool default_pref_value) const {
  char pref_buf[CONST_MAX_LEN_REDIS_KEY], rsp[2] = {0};
  bool interface_pref = default_pref_value;

  if (ntop->getRedis()) {
    snprintf(pref_buf, sizeof(pref_buf), pref_key, get_id());
    if ((ntop->getRedis()->get(pref_buf, rsp, sizeof(rsp)) == 0) &&
        (rsp[0] != '\0')) {
      if (rsp[0] == '1')
        interface_pref = true;
      else if (rsp[0] == '0')
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
  is_traffic_mirrored = getInterfaceBooleanPref(CONST_MIRRORED_TRAFFIC_PREFS,
                                                CONST_DEFAULT_MIRRORED_TRAFFIC);
}

/* **************************************************** */

void NetworkInterface::updateSmartRecording() {
  char redis_key[CONST_MAX_LEN_REDIS_KEY];
  char redis_val[CONST_MAX_LEN_REDIS_VALUE];
  char *instance = NULL, *prev_instance;
  bool enable = false;

  if (!ntop->getRedis()) return;

  enable = getInterfaceBooleanPref(CONST_SMART_RECORDING_PREFS,
                                   CONST_DEFAULT_SMART_RECORDING);

  if (enable) {
    snprintf(redis_key, sizeof(redis_key), CONST_SMART_RECORDING_INSTANCE_PREFS,
             get_id());
    redis_val[0] = '\0';
    if (ntop->getRedis()->get(redis_key, redis_val,
                              CONST_MAX_LEN_REDIS_VALUE) == 0 &&
        strlen(redis_val) > 0) {
      instance = strdup(redis_val);
    } else {
      enable = false; /* missing instance name (required) */
    }
  }

  /* Update instance name */
  prev_instance = smart_recording_instance_name;
  smart_recording_instance_name = instance;
  if (prev_instance) {
    usleep(100);
    free(prev_instance);
  }

  /* Toggle smart recording */
  is_smart_recording_enabled = enable;
}

/* **************************************************** */

void NetworkInterface::updateDynIfaceTrafficPolicy() {
  show_dynamic_interface_traffic = getInterfaceBooleanPref(
      CONST_SHOW_DYN_IFACE_TRAFFIC_PREFS, CONST_DEFAULT_SHOW_DYN_IFACE_TRAFFIC);
}

/* **************************************************** */

void NetworkInterface::updateFlowDumpDisabled() {
  flow_dump_disabled =
      getInterfaceBooleanPref(CONST_DISABLED_FLOW_DUMP_PREFS, false);
}

/* **************************************** */

void NetworkInterface::updateLbdIdentifier() {
  lbd_serialize_by_mac = getInterfaceBooleanPref(
      CONST_LBD_SERIALIZATION_PREFS, CONST_DEFAULT_LBD_SERIALIZE_AS_MAC);
}

/* **************************************** */

void NetworkInterface::updateDiscardProbingTraffic() {
  discard_probing_traffic = getInterfaceBooleanPref(
      CONST_DISCARD_PROBING_TRAFFIC, CONST_DEFAULT_DISCARD_PROBING_TRAFFIC);
}

/* **************************************** */

void NetworkInterface::updateFlowsOnlyInterface() {
  flows_only_interface = getInterfaceBooleanPref(
      CONST_FLOWS_ONLY_INTERFACE, CONST_DEFAULT_FLOWS_ONLY_INTERFACE);
}

/* **************************************************** */

bool NetworkInterface::checkIdle() {
  is_idle = false;

  if (ifname != NULL) {
    char rkey[128], rsp[16];

    snprintf(rkey, sizeof(rkey), "ntopng.prefs.%s_not_idle", ifname);
    if ((ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) &&
        (rsp[0] != '\0')) {
      int val = atoi(rsp);

      if (val == 0) is_idle = true;
    }
  }

  return (is_idle);
}

/* **************************************************** */

void NetworkInterface::deleteDataStructures() {
  if (flows_hash) {
    delete (flows_hash);
    flows_hash = NULL;
  }
  if (hosts_hash) {
    delete (hosts_hash);
    hosts_hash = NULL;
  }
  if (ases_hash) {
    delete (ases_hash);
    ases_hash = NULL;
  }
  if (obs_hash) {
    delete (obs_hash);
    obs_hash = NULL;
  }
  if (oses_hash) {
    delete (oses_hash);
    oses_hash = NULL;
  }
  if (countries_hash) {
    delete (countries_hash);
    countries_hash = NULL;
  }
  if (vlans_hash) {
    delete (vlans_hash);
    vlans_hash = NULL;
  }
  if (macs_hash) {
    delete (macs_hash);
    macs_hash = NULL;
  }
  if (gw_macs) {
    delete (gw_macs);
    gw_macs = NULL;
  }
  if (download_stats) {
    delete (download_stats);
    download_stats = NULL;
  }
  if (upload_stats) {
    delete (upload_stats);
    upload_stats = NULL;
  }

  if (companionQueue) {
    for (u_int16_t i = 0; i < COMPANION_QUEUE_LEN; i++)
      if (companionQueue[i]) delete companionQueue[i];

    delete[] companionQueue;
    companionQueue = NULL;
  }
}

/* **************************************************** */

NetworkInterface::~NetworkInterface() {
  std::map<std::pair<AlertEntity, std::string>,
           InterfaceMemberAlertableEntity *>::iterator it;
  std::map<u_int16_t /* observationPointId */,
           ObservationPointIdTrafficStats *>::iterator it_o;

#ifdef INTERFACE_PROFILING
  u_int64_t n = ethStats.getNumIngressPackets();
  if (isPacketInterface() && n > 0) {
    for (u_int i = 0; i < INTERFACE_PROFILING_NUM_SECTIONS; i++) {
      if (INTERFACE_PROFILING_SECTION_LABEL(i) != NULL)
        ntop->getTrace()->traceEvent(
            TRACE_NORMAL, "[PROFILING] Section #%d '%s': AVG %llu ticks", i,
            INTERFACE_PROFILING_SECTION_LABEL(i),
            INTERFACE_PROFILING_SECTION_AVG(i, n));
    }
  }
#endif

  cleanup();

  deleteDataStructures();

  if (idleFlowsToDump) delete idleFlowsToDump;
  if (activeFlowsToDump) delete activeFlowsToDump;

  if (db) {
    db->shutdown();
    delete db;
  }

  if (host_pools) delete host_pools; /* note: this requires ndpi_struct */
  if (bcast_domains) delete bcast_domains;
  if (ifDescription) free(ifDescription);
  if (discovery) delete discovery;
  if (statsManager) delete statsManager;
  if (alertStore) delete alertStore;
  if (alertsQueue) delete alertsQueue;
  if (ndpiStats) delete ndpiStats;
  if (dscpStats) delete dscpStats;
  if (hosts_to_restore) delete hosts_to_restore;
  if (networkStats) {
    u_int16_t numNetworks = ntop->getNumLocalNetworks();

    for (u_int16_t i = 0; i < numNetworks; i++) delete networkStats[i];

    delete[] networkStats;
  }
  if (interfaceStats) delete interfaceStats;

  if (customFlowLuaScript_proto) delete customFlowLuaScript_proto;
  if (customFlowLuaScript_periodic) delete customFlowLuaScript_periodic;
  if (customFlowLuaScript_end) delete customFlowLuaScript_end;

  if (customHostLuaScript) delete customHostLuaScript;

#if defined(NTOPNG_PRO)
  if (pMap) delete pMap;
  if (sMap) delete sMap;

  if (score_behavior) delete (score_behavior);
  if (traffic_tx_behavior) delete (traffic_tx_behavior);
  if (traffic_rx_behavior) delete (traffic_rx_behavior);
#endif

  for (it = external_alerts.begin(); it != external_alerts.end(); ++it)
    delete it->second;
  external_alerts.clear();

#ifdef NTOPNG_PRO
  if (policer) delete (policer);
#ifndef HAVE_NEDGE
  if (flow_profiles) delete (flow_profiles);
  if (shadow_flow_profiles) delete (shadow_flow_profiles);
  if (sub_interfaces) delete (sub_interfaces);
#endif
  if (custom_app_stats) delete custom_app_stats;
  if (flow_interfaces_stats) delete flow_interfaces_stats;
#endif
  if (influxdb_ts_exporter) delete influxdb_ts_exporter;
  if (rrd_ts_exporter) delete rrd_ts_exporter;
  if (dhcp_ranges) delete[] dhcp_ranges;
  if (dhcp_ranges_shadow) delete[] dhcp_ranges_shadow;
  if (mdns)
    delete mdns; /* Leave it at the end so the mdns resolver has time to
                    initialize */
  if (ifname) free(ifname);

  if (flowAlertsQueue) delete flowAlertsQueue;
  if (hostAlertsQueue) delete hostAlertsQueue;

  addRedisSitesKey();
  if (top_sites) delete top_sites;
  if (top_os) delete top_os;

  if (prev_flow_checks_executor) delete prev_flow_checks_executor;
  if (flow_checks_executor) delete flow_checks_executor;

  if (prev_host_checks_executor) delete prev_host_checks_executor;
  if (host_checks_executor) delete host_checks_executor;

  /* Note do not need to delete kafka as it's shared with db */

  if (ndpi_struct) {
    ndpi_exit_detection_module(ndpi_struct);
    ndpi_struct = NULL;
  }

  cleanShadownDPI();

  if (smart_recording_instance_name) free(smart_recording_instance_name);
}

/* **************************************************** */

/* Enqueue flow alert to a queue for processing and later delivery to recipients
 */
bool NetworkInterface::enqueueFlowAlert(FlowAlert *alert) {
  Flow *f = alert->getFlow();
  bool ret = false;

  /* Perform the actual enqueue */
  if (flowAlertsQueue && flowAlertsQueue->enqueue(alert, true)) {
    /*
      If enqueue was successful, increase the flow reference counter.
      Reference counter will be deleted when doing the dequeue.
    */
    f->incUses();

    /*
      Signal the waiter on the condition variable
    */
    flow_checks_condvar.signal();

    ret = true;
  } else {
    delete alert;
  }

  return ret;
}

/* **************************************************** */

/* Enqueue host alert to a queue for processing and later delivery to recipients
 */
bool NetworkInterface::enqueueHostAlert(HostAlert *alert) {
  HostAlertReleasedPair alert_info(alert, alert->isReleased());
  Host *h = alert->getHost();
  bool ret = false;

  if (!ntop->getPrefs()->dontEmitHostAlerts() && hostAlertsQueue &&
      hostAlertsQueue->enqueue(alert_info, true)) {
    /*
      If enqueue was successful, increase the host reference counter.
      Reference counter will be deleted when doing the dequeue.
    */
    h->incUses();

    /*
      Signal the waiter on the condition variable
    */
    host_checks_condvar.signal();

    ret = true;
  } else {
    if (alert->isReleased()) delete alert;
  }

  return ret;
}

/* **************************************************** */

int NetworkInterface::dumpFlow(time_t when, Flow *f) {
  int rc = -1;
#ifndef HAVE_NEDGE

  /* Asynchronous dump via a thread */
  if (f->get_state() == hash_entry_state_idle) {
    /* Last flow dump before delete
     * Note: this never happens in 'direct' mode */
    if (idleFlowsToDump && idleFlowsToDump->enqueue(f, true)) {
      f->incUses(), f->set_dump_in_progress();

      /*
        Signal there's work to do.
        Don't signal for view interfaces, they use sleep.
      */
#ifndef WIN32
      if (!isViewed()) dump_condition.signal();
#endif

#if DEBUG_FLOW_DUMP
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL, "[%s] Queueing flow to dump [IDLE]", __FUNCTION__);
#endif
    } else {
      incNumQueueDroppedFlows(1);
    }
  } else {
    /* Partial dump if active flows */
    if (activeFlowsToDump && activeFlowsToDump->enqueue(f, true)) {
      f->incUses(), f->set_dump_in_progress();

      /*
        Signal there's work to do.
      */
#ifndef WIN32
      if (!isViewed()) dump_condition.signal();
#endif

#if DEBUG_FLOW_DUMP
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL, "[%s] Queueing flow to dump [ACTIVE]", __FUNCTION__);
#endif
    } else {
      incNumQueueDroppedFlows(1);
    }
  }
#endif

  return (rc);
}

/* **************************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::flushFlowDump() {
  if (db) db->flush();
}

#endif

/* **************************************************** */

static bool local_hosts_2_redis_walker(GenericHashEntry *h, void *user_data,
                                       bool *matched) {
  Host *host = (Host *)h;

  if (host && (host->isLocalHost() || host->isSystemHost())) *matched = true;

  return (false); /* false = keep on walking */
}

/* **************************************************** */

u_int32_t NetworkInterface::getHostsHashSize() {
  return (hosts_hash ? hosts_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getASesHashSize() {
  return (ases_hash ? ases_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getObsHashSize() {
  return (obs_hash ? obs_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getOSesHashSize() {
  return (oses_hash ? oses_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getCountriesHashSize() {
  return (countries_hash ? countries_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getVLANsHashSize() {
  return (vlans_hash ? vlans_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getFlowsHashSize() {
  return (flows_hash ? flows_hash->getNumEntries() : 0);
}

/* **************************************************** */

u_int32_t NetworkInterface::getMacsHashSize() {
  return (macs_hash ? macs_hash->getNumEntries() : 0);
}

/* **************************************************** */

bool NetworkInterface::walker(u_int32_t *begin_slot, bool walk_all,
                              WalkerType wtype,
                              bool (*walker)(GenericHashEntry *h,
                                             void *user_data, bool *matched),
                              void *user_data) {
  bool ret = false;

  if (id == SYSTEM_INTERFACE_ID) return (false);

  switch (wtype) {
    case walker_hosts:
      ret = hosts_hash
                ? hosts_hash->walk(begin_slot, walk_all, walker, user_data)
                : false;
      break;

    case walker_flows:
      ret = flows_hash
                ? flows_hash->walk(begin_slot, walk_all, walker, user_data)
                : false;
      break;

    case walker_macs:
      ret = macs_hash ? macs_hash->walk(begin_slot, walk_all, walker, user_data)
                      : false;
      break;

    case walker_ases:
      ret = ases_hash ? ases_hash->walk(begin_slot, walk_all, walker, user_data)
                      : false;
      break;

    case walker_obs:
      ret = obs_hash ? obs_hash->walk(begin_slot, walk_all, walker, user_data)
                     : false;
      break;

    case walker_oses:
      ret = oses_hash ? oses_hash->walk(begin_slot, walk_all, walker, user_data)
                      : false;
      break;

    case walker_countries:
      ret = countries_hash
                ? countries_hash->walk(begin_slot, walk_all, walker, user_data)
                : false;
      break;

    case walker_vlans:
      ret = vlans_hash
                ? vlans_hash->walk(begin_slot, walk_all, walker, user_data)
                : false;
      break;
  }

  return (ret);
}

/* **************************************************** */

Flow *NetworkInterface::getFlow(
    Mac *src_mac, Mac *dst_mac, u_int16_t vlan_id,
    u_int16_t observation_domain_id, u_int32_t private_flow_id,
    u_int32_t deviceIP, u_int32_t inIndex, u_int32_t outIndex,
    const ICMPinfo *const icmp_info, IpAddress *src_ip, IpAddress *dst_ip,
    u_int16_t src_port, u_int16_t dst_port, u_int8_t l4_proto,
    bool *src2dst_direction, time_t first_seen, time_t last_seen,
    u_int32_t len_on_wire, bool *new_flow, bool create_if_missing,
    u_int8_t *view_cli_mac, u_int8_t *view_srv_mac) {
  Flow *ret, *unswapped_flow;
  Mac *primary_mac;
  Host *srcHost = NULL, *dstHost = NULL;

  if (!flows_hash) return (NULL);

  if (vlan_id != 0) setSeenVLANTaggedPackets();

  if (!hasSeenMacAddresses()) {
    if ((src_mac && Utils::macHash(src_mac->get_mac()) != 0) ||
        (dst_mac && Utils::macHash(dst_mac->get_mac()) != 0))
      setSeenMacAddresses();
  }

  INTERFACE_PROFILING_SECTION_ENTER(
      "NetworkInterface::getFlow: flows_hash->find", 1);
  ret = flows_hash->find(src_mac, dst_mac, src_ip, dst_ip, src_port, dst_port,
                         vlan_id, observation_domain_id, private_flow_id,
                         l4_proto, icmp_info, src2dst_direction,
                         true /* Inline call */, &unswapped_flow);
  INTERFACE_PROFILING_SECTION_EXIT(1);

  if ((ret == NULL) && (unswapped_flow != NULL)) {
    /*
      We have found this flow but with the wrong direction
      and we're waiting it to be swapped.
    */

    ret = unswapped_flow;      /* 1 - Use the new flow */
    ret->swap();               /* 2 - Swap flow keys   */
    *src2dst_direction = true; /* Don't forget to reverse the direction ! */
  }

  if (ret == NULL) {
    if (!create_if_missing) return (NULL);

    *new_flow = true;
    num_new_flows++;

    if (!flows_hash->hasEmptyRoom()) {
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many flows");
      has_too_many_flows = true;
      return (NULL);
    }

    try {
      INTERFACE_PROFILING_SECTION_ENTER("NetworkInterface::getFlow: new Flow",
                                        2);
      ret = new (std::nothrow)
          Flow(this, vlan_id, observation_domain_id, private_flow_id, l4_proto,
               src_mac, src_ip, src_port, dst_mac, dst_ip, dst_port, icmp_info,
               first_seen, last_seen, view_cli_mac, view_srv_mac);
      INTERFACE_PROFILING_SECTION_EXIT(2);
    } catch (std::bad_alloc &ba) {
      static bool oom_warning_sent = false;

      if (!oom_warning_sent) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
        oom_warning_sent = true;
      }

      has_too_many_flows = true;
      return (NULL);
    }

    if (flows_hash->add(
            ret, false /* Don't lock, we're inline with the purgeIdle */)) {
      *src2dst_direction = true;
    } else {
      /* Note: this should never happen as we are checking hasEmptyRoom() */
      delete ret;
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many flows");
      has_too_many_flows = true;
      return (NULL);
    }
  } else {
    *new_flow = false;
    has_too_many_flows = false;
  }

  if (src_mac) {
    if ((srcHost = (*src2dst_direction) ? ret->get_cli_host()
                                        : ret->get_srv_host())) {
      if ((!src_mac->isSpecialMac()) && (primary_mac = srcHost->getMac()) &&
          primary_mac != src_mac) {
#ifdef MAC_DEBUG
        char buf[32], bufm1[32], bufm2[32];

        ntop->getTrace()->traceEvent(
            TRACE_NORMAL,
            "Detected mac address [new MAC: %s] [old host: %s/primary mac: "
            "%s][pkts: %u]",
            Utils::formatMac(src_mac->get_mac(), bufm1, sizeof(bufm1)),
            srcHost->get_ip()->print(buf, sizeof(buf)),
            Utils::formatMac(primary_mac->get_mac(), bufm2, sizeof(bufm2)),
            getNumPackets());
#endif

        if (srcHost->getMac()->isSpecialMac()) {
          if (getIfType() == interface_type_NETFILTER) {
            /*
              This is the first *reply* packet of a flow so we need to increment
              it with the initial packet that was missed as NetFilter did not
              report the (destination) MAC. From now on, all flow peers are
              known
            */

            /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats
             */
#ifndef HAVE_NEDGE
            if (ret->get_packets_cli2srv() == 1 /* first packet */)
              src_mac->incRcvdStats(
                  getTimeLastPktRcvd(), 1,
                  ret->get_bytes_cli2srv() /* size of the last packet */);
#endif
          }
        }

        srcHost->set_mac(src_mac);
        srcHost->updateHostPool(true /* Inline */);
      }
    }
  }

  if (dst_mac) {
    if ((dstHost = (*src2dst_direction) ? ret->get_srv_host()
                                        : ret->get_cli_host())) {
      if ((!dst_mac->isSpecialMac()) && (primary_mac = dstHost->getMac()) &&
          primary_mac != dst_mac) {
#ifdef MAC_DEBUG
        char buf[32], bufm1[32], bufm2[32];

        ntop->getTrace()->traceEvent(
            TRACE_NORMAL,
            "Detected mac address [new MAC: %s] [old host: %s/primary mac: %s]",
            Utils::formatMac(dst_mac->get_mac(), bufm1, sizeof(bufm1)),
            dstHost->get_ip()->print(buf, sizeof(buf)),
            Utils::formatMac(primary_mac->get_mac(), bufm2, sizeof(bufm2)));
#endif

        dstHost->set_mac(dst_mac);
        dstHost->updateHostPool(true /* Inline */);
      }
    }
  }

  return (ret);
}

/* **************************************************** */

void NetworkInterface::setSubInterface(NetworkInterface *master_iface,
                                       FlowHashingEnum mode,
                                       u_int64_t criteria) {
  dynamic_interface_mode = mode;
  dynamic_interface_criteria = criteria;
  dynamic_interface_master = master_iface;
  is_dynamic_interface = true;
};

/* **************************************************** */

/* NOTE: the interface is deleted when this method returns false */
bool NetworkInterface::registerSubInterface(NetworkInterface *sub_iface,
                                            u_int64_t criteria) {
  /* registerInterface deletes the interface on failure */
  if (!ntop->registerInterface(sub_iface)) return false;

  sub_iface->setSubInterface(this, flowHashingMode, criteria);

  /* allocateStructures must be called after registering the interface.
   * This is needed because StoreManager calles ntop->getInterfaceById. */
  sub_iface->allocateStructures();

  ntop->initInterface(sub_iface);

  sub_iface->startPacketPolling(); /* Won't actually start a thread, just mark
                                      this interface as running */

  flowHashing[criteria] = sub_iface; /* Add it to the hash */

  numSubInterfaces++;
  ntop->getRedis()->set(CONST_STR_RELOAD_LISTS, (const char *)"1");

  return true;
}

/* **************************************************** */

NetworkInterface *NetworkInterface::getDynInterface(u_int64_t criteria,
                                                    bool parser_interface) {
  NetworkInterface *sub_iface = NULL;
#ifndef HAVE_NEDGE
  std::map<u_int64_t, NetworkInterface *>::iterator subIface =
      flowHashing.find(criteria);
  char buf[64], buf1[48];
  const char *vIface_type;

  if (subIface != flowHashing.end()) {
    sub_iface = subIface->second;
    return sub_iface;
  }

  /* Interface not found */

  if ((numSubInterfaces >= MAX_NUM_VIRTUAL_INTERFACES) ||
      (ntop->get_num_interfaces() >= MAX_NUM_DEFINED_INTERFACES)) {
    static bool too_many_interfaces_error = false;

    if (!too_many_interfaces_error) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Too many subinterfaces defined");
      too_many_interfaces_error = true;
    }

    return (NULL);
  }

  switch (flowHashingMode) {
    case flowhashing_vlan:
      vIface_type = CONST_INTERFACE_TYPE_VLAN;
      snprintf(buf, sizeof(buf), "%s [VLAN Id: %u]", ifname,
               (unsigned int)criteria);
      break;

    case flowhashing_probe_ip:
      vIface_type = CONST_INTERFACE_TYPE_FLOW;
      snprintf(buf, sizeof(buf), "%s [Probe IP: %s]", ifname,
               Utils::intoaV4((unsigned int)criteria, buf1, sizeof(buf1)));
      break;

    case flowhashing_iface_idx:
      vIface_type = CONST_INTERFACE_TYPE_FLOW;
      snprintf(buf, sizeof(buf), "%s [IfIdx: %u]", ifname,
               (unsigned int)criteria);
      break;

    case flowhashing_ingress_iface_idx:
      vIface_type = CONST_INTERFACE_TYPE_FLOW;
      snprintf(buf, sizeof(buf), "%s [InIfIdx: %u]", ifname,
               (unsigned int)criteria);
      break;

    case flowhashing_probe_ip_and_ingress_iface_idx: {
      /* 64 bit value: upper 32 bit is nProbe IP, lower 32 bit ifIdx */
      u_int32_t nprobe_ip = (u_int32_t)(criteria >> 32);
      u_int32_t if_id = (u_int32_t)(criteria & 0xFFFFFFFF);

      vIface_type = CONST_INTERFACE_TYPE_FLOW;
      snprintf(buf, sizeof(buf), "%s [Probe IP: %s][InIfIdx: %u]", ifname,
               Utils::intoaV4(nprobe_ip, buf1, sizeof(buf1)), if_id);
    } break;

    case flowhashing_vrfid:
      vIface_type = CONST_INTERFACE_TYPE_FLOW;
      snprintf(buf, sizeof(buf), "%s [VRF Id: %u]", ifname,
               (unsigned int)criteria);
      break;

    default:
      return (NULL);
      break;
  }

  if (dynamic_cast<ZMQParserInterface *>(this))
    sub_iface = new (std::nothrow) ZMQParserInterface(buf, vIface_type);
  else if (dynamic_cast<SyslogParserInterface *>(this))
    sub_iface = new (std::nothrow) SyslogParserInterface(buf, vIface_type);
  else
    sub_iface = new (std::nothrow) NetworkInterface(buf, vIface_type);

  if (sub_iface == NULL) {
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "Failure allocating interface: not enough memory?");
    return (NULL);
  }

  if (!this->registerSubInterface(sub_iface, criteria)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Failure registering sub-interface");
    sub_iface = NULL; /* NOTE: interface deleted by registerSubInterface */
    return (NULL);
  }
#endif

  return (sub_iface);
}

/* **************************************************** */

bool NetworkInterface::processPacket(
    u_int32_t bridge_iface_idx, bool ingressPacket,
    const struct bpf_timeval *when, const u_int64_t packet_time,
    struct ndpi_ethhdr *eth, u_int16_t vlan_id, struct ndpi_iphdr *iph,
    struct ndpi_ipv6hdr *ip6, u_int16_t ip_offset,
    u_int16_t encapsulation_overhead, u_int32_t len_on_wire,
    const struct pcap_pkthdr *h, const u_char *packet, u_int16_t *ndpiProtocol,
    Host **srcHost, Host **dstHost, Flow **hostFlow) {
  u_int16_t trusted_ip_len = max_val(0, (int)h->caplen - ip_offset);
  u_int16_t trusted_payload_len = 0;
  u_int32_t private_flow_id = 0;
  bool src2dst_direction;
  u_int8_t l4_proto;
  Flow *flow;
  Mac *srcMac = NULL, *dstMac = NULL;
  IpAddress src_ip, dst_ip;
  ICMPinfo icmp_info;
  u_int16_t frame_padding = 0;
  u_int16_t src_port = 0, dst_port = 0;
  struct ndpi_tcphdr *tcph = NULL;
  struct ndpi_udphdr *udph = NULL;
  struct sctphdr *sctph = NULL;
  u_int16_t trusted_l4_packet_len;
  u_int8_t *l4, tcp_flags = 0, *payload = NULL;
  u_int8_t *ip;
  bool is_fragment = false, new_flow;
  bool pass_verdict = true;
  u_int16_t l4_len = 0, fragment_offset = 0;
#ifndef HAVE_NEDGE
#ifdef IMPLEMENT_SMART_FRAGMENTS
  u_int16_t fragment_extra_overhead = 0;
#endif
#endif
  u_int8_t tos;

  *hostFlow = NULL;

  if (!isSubInterface()) {
    bool processed = false;
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    /* Custom disaggregation */
    if (sub_interfaces && (sub_interfaces->getNumSubInterfaces() > 0)) {
      processed = sub_interfaces->processPacket(
          bridge_iface_idx, ingressPacket, when, packet_time, eth, vlan_id, iph,
          ip6, ip_offset, encapsulation_overhead, len_on_wire, h, packet,
          ndpiProtocol, srcHost, dstHost, hostFlow);
    }
#endif
#endif

    if ((!processed) && (flowHashingMode != flowhashing_none)) {
      /* VLAN disaggregation */
      if ((flowHashingMode == flowhashing_vlan) && (vlan_id > 0)) {
        NetworkInterface *vIface;

        if ((vIface = getDynInterface((u_int32_t)vlan_id, false)) != NULL) {
          vIface->setTimeLastPktRcvd(h->ts.tv_sec);
          pass_verdict = vIface->processPacket(
              bridge_iface_idx, ingressPacket, when, packet_time, eth, vlan_id,
              iph, ip6, ip_offset, encapsulation_overhead, len_on_wire, h,
              packet, ndpiProtocol, srcHost, dstHost, hostFlow);
          processed = true;
        }
      }
    }

    if (processed && !showDynamicInterfaceTraffic()) {
      incStats(ingressPacket, when->tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN,
               NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);

      return (pass_verdict);
    }
  }

  if (eth == NULL) {
    incStats(ingressPacket, when->tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN,
             NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
    return (pass_verdict);
  }

  if ((srcMac = getMac(eth->h_source, true /* Create if missing */,
                       true /* Inline call */))) {
    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
    srcMac->incSentStats(getTimeLastPktRcvd(), 1, len_on_wire);
#endif
    srcMac->setSeenIface(bridge_iface_idx);

#ifdef HAVE_NEDGE
    u_int16_t mac_pool = 0;
    char bufMac[24];
    char *mac_str;

    /* When captive portal is disabled, use the auto_assigned_pool_id as the
     * default MAC pool */
    if (host_pools &&
        (ntop->getPrefs()->get_auto_assigned_pool_id() != NO_HOST_POOL_ID) &&
        (!ntop->getPrefs()->isCaptivePortalEnabled()) &&
        (srcMac->locate() == located_on_lan_interface)) {
      if (!host_pools->findMacPool(srcMac->get_mac(), &mac_pool) ||
          (mac_pool == NO_HOST_POOL_ID)) {
        mac_str = Utils::formatMac(srcMac->get_mac(), bufMac, sizeof(bufMac));
        ntop->addToPool(mac_str, ntop->getPrefs()->get_auto_assigned_pool_id());
      }
    }
#endif
  }

  if ((dstMac = getMac(eth->h_dest, true /* Create if missing */,
                       true /* Inline call */))) {
    /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
    dstMac->incRcvdStats(getTimeLastPktRcvd(), 1, len_on_wire);
#endif
  }

  if (iph != NULL) {
    u_int16_t ip_len, ip_tot_len;

    /* IPv4 */
    if ((trusted_ip_len < 20) || ((ip_len = iph->ihl * 4) == 0)) {
      incStats(ingressPacket, when->tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN,
               NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
      return (pass_verdict);
    }

    /* NOTE: ip_tot_len is not trusted as may be forged */
    ip_tot_len = ntohs(iph->tot_len);
    tos = iph->tos;

    /* Use the actual h->len and not the h->caplen to determine
       whether a packet is fragmented. */
    if (ip_len > (int)h->len - ip_offset ||
        (int)h->len - ip_offset < ip_tot_len ||
        (iph->frag_off & htons(0x1FFF /* IP_OFFSET */)) ||
        (iph->frag_off & htons(0x2000 /* More Fragments: set */))) {
      is_fragment = true;
      fragment_offset = ((ntohs(iph->frag_off) & 0x3fff) & 0x1FFF) * 8;

#ifdef IMPLEMENT_SMART_FRAGMENTS
      if (fragment_offset) return (pass_verdict);
#endif
    }

    l4_proto = iph->protocol;
    l4 = ((u_int8_t *)iph + ip_len);
    l4_len =
        ip_tot_len -
        ip_len; /* use len from the ip header to compute sequence numbers */
    ip = (u_int8_t *)iph;

    /* An ethernet frame can contain padding at the end of the packet.
     * Such padding can be identified by comparing the total packet length
     * reported into the IP header with the ethernet frame size. Such padding
     * should not be accounted in the L4 size. */
    if (packet + h->caplen > ip + ip_tot_len)
      frame_padding = packet + h->caplen - ip - ip_tot_len;

    tos = iph->tos;
  } else {
    /* IPv6 */
    u_int ipv6_shift = sizeof(const struct ndpi_ipv6hdr);
    u_int32_t *tos_ptr = (u_int32_t *)ip6;

    if (trusted_ip_len < sizeof(const struct ndpi_ipv6hdr)) {
      incStats(ingressPacket, when->tv_sec, ETHERTYPE_IPV6,
               NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0,
               len_on_wire, 1);
      return (pass_verdict);
    }

    l4_proto = ip6->ip6_hdr.ip6_un1_nxt;

    if ((l4_proto == 0x3C /* IPv6 destination option */) ||
        (l4_proto == 0x0 /* Hop-by-hop option */)) {
      u_int8_t *options = (u_int8_t *)ip6 + ipv6_shift;

      l4_proto = options[0];
      ipv6_shift += 8 * (options[1] + 1);

      if (trusted_ip_len < ipv6_shift) {
        incStats(ingressPacket, when->tv_sec, ETHERTYPE_IPV6,
                 NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0,
                 len_on_wire, 1);
        return (pass_verdict);
      }
    }

    l4 = (u_int8_t *)ip6 + ipv6_shift;
    l4_len = packet + h->len - l4;
    ip = (u_int8_t *)ip6;

    tos = ((ntohl(*tos_ptr) & 0xFF00000) >> 20) & 0xFF;
  }

  trusted_l4_packet_len = packet + h->caplen - l4;

  if (trusted_l4_packet_len > frame_padding)
    trusted_l4_packet_len -= frame_padding;

  if (l4_proto == IPPROTO_TCP) {
    if (trusted_l4_packet_len >= sizeof(struct ndpi_tcphdr)) {
      u_int tcp_len;

      /* TCP */
      tcph = (struct ndpi_tcphdr *)l4;
      src_port = tcph->source, dst_port = tcph->dest;
      tcp_flags = l4[13];
      tcp_len = min_val(4 * tcph->doff, trusted_l4_packet_len);
      payload = &l4[tcp_len];
      trusted_payload_len = trusted_l4_packet_len - tcp_len;
      // TODO: check if payload should be set to NULL when trusted_payload_len
      // == 0
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(
          TRACE_INFO, "Invalid TCP packet received [%u bytes long]",
          trusted_l4_packet_len);
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
               NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0,
               len_on_wire, 1);
      return (pass_verdict);
    }
  } else if (l4_proto == IPPROTO_UDP) {
    if (trusted_l4_packet_len >= sizeof(struct ndpi_udphdr)) {
      /* UDP */
      udph = (struct ndpi_udphdr *)l4;
      src_port = udph->source, dst_port = udph->dest;
      payload = &l4[sizeof(struct ndpi_udphdr)];
      trusted_payload_len = trusted_l4_packet_len - sizeof(struct ndpi_udphdr);

#ifndef HAVE_NEDGE
#ifdef IMPLEMENT_SMART_FRAGMENTS
      if (is_fragment)
        fragment_extra_overhead =
            ntohs(udph->len) - l4_len + sizeof(struct ndpi_iphdr);
#endif
#endif
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(
          TRACE_INFO, "Invalid UDP packet received [%u bytes long]",
          trusted_l4_packet_len);
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
               NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0,
               len_on_wire, 1);
      return (pass_verdict);
    }
  } else if (l4_proto == IPPROTO_SCTP) {
    if (trusted_l4_packet_len >= sizeof(struct sctphdr)) {
      /* SCTP */
      sctph = (struct sctphdr *)l4;
      src_port = sctph->sport, dst_port = sctph->dport;

      payload = &l4[sizeof(struct sctphdr)];
      trusted_payload_len = trusted_l4_packet_len - sizeof(struct sctphdr);
    } else {
      /* Packet too short: this is a faked packet */
      ntop->getTrace()->traceEvent(
          TRACE_INFO, "Invalid SCTP packet received [%u bytes long]",
          trusted_l4_packet_len);
      incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
               NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0,
               len_on_wire, 1);
      return (pass_verdict);
    }
  } else if (l4_proto == IPPROTO_ICMP) {
    icmp_info.dissectICMP(trusted_l4_packet_len, l4);
  } else {
    /* non TCP/UDP protocols */
  }

  if (iph != NULL)
    src_ip.set(iph->saddr), dst_ip.set(iph->daddr);
  else
    src_ip.set(&ip6->ip6_src), dst_ip.set(&ip6->ip6_dst);

#if defined(WIN32) && defined(DEMO_WIN32)
  if (this->ethStats.getNumPackets() > MAX_NUM_PACKETS) {
    static bool showMsg = false;

    if (!showMsg) {
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL,
          "-----------------------------------------------------------");
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL,
          "WARNING: this demo application is a limited ntopng version able to");
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL, "capture up to %d packets. If you are interested",
          MAX_NUM_PACKETS);
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL, "in the full version please have a look at the ntop");
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                   "home page http://www.ntop.org/.");
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL,
          "-----------------------------------------------------------");
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "");
      showMsg = true;
    }

    return (pass_verdict);
  }
#endif

  /*
    We need to populate the private_flow_id with protocol-specific
    such as DNS....

    Unfortunately nDPI has not yet seen this packet so we need to
    implement a micro-DPI code here
  */
  if ((l4_proto == IPPROTO_UDP) && (trusted_payload_len > 20)) {
    u_int16_t fiftythree = htons(53);

    if ((src_port == fiftythree) || (dst_port == fiftythree)) {
      /* Looks like DNS */
      u_int16_t dns_transaction_id = (payload[0] << 8) + payload[1];

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%04X", dns_transaction_id);
      private_flow_id = (u_int32_t)dns_transaction_id;
    }
  }

  INTERFACE_PROFILING_SECTION_ENTER("NetworkInterface::processPacket: getFlow",
                                    0);

pre_get_flow:
  /* Updating Flow */
  flow = getFlow(
      srcMac, dstMac, vlan_id, 0 /* observationPointId */, private_flow_id, 0,
      0, 0, l4_proto == IPPROTO_ICMP ? &icmp_info : NULL, &src_ip, &dst_ip,
      src_port, dst_port, l4_proto, &src2dst_direction, last_pkt_rcvd,
      last_pkt_rcvd, len_on_wire, &new_flow, true, eth->h_source,
      eth->h_dest /* Eth lvl, used just in view interfaces to add MAC */);
  INTERFACE_PROFILING_SECTION_EXIT(0);

  if (flow == NULL) {
    incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
             NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
             l4_proto, len_on_wire, 1);
    return (pass_verdict);
  } else {
#ifdef HAVE_NEDGE
    if (new_flow) flow->setIngress2EgressDirection(ingressPacket);
#endif

    if (flow->is_swap_requested()
        /* This guarantees that at least a packet has been observed in both
           directions, and that we are in the dst->src direction of the flow
           that is being swapped
        */
        && (!src2dst_direction)) {
#if 0
      char buf[256];
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Swapping %s", flow->print(buf, sizeof(buf)));
#endif

      flow->set_swap_done(); /* Mark the old flow with the swap done */
      goto pre_get_flow;     /* Start over */
    }

    *srcHost = src2dst_direction ? flow->get_cli_host() : flow->get_srv_host();
    *dstHost = src2dst_direction ? flow->get_srv_host() : flow->get_cli_host();
    *hostFlow = flow;

    flow->setTOS(tos, src2dst_direction);

    switch (l4_proto) {
      case IPPROTO_TCP:
        flow->updateTcpFlags(when, tcp_flags, src2dst_direction);

        /*
          This is the heuristic "For TCP flows for which the 3WH has not been
          observed..." at https://github.com/ntop/ntopng/issues/5058

          So, only for the first packet check if this flow is a swap candidate.
          The only condition that should NOT be checked for swap is when there's
          a SYN and not an ACK, i.e., when we see the first packet of the TWH
          that allows to reliably determine the direction.
        */
        if (new_flow && (!(tcp_flags & TH_SYN) || (tcp_flags & TH_ACK)))
          flow->check_swap();

        if ((tcp_flags & (TH_RST | TH_FIN)) == 0) {
          /*
            Ignore Zero-window on flow termination as this case
            is not necessary a zero windon indication
          */
          flow->updateTcpWindow(ntohs(tcph->window), src2dst_direction);
        }

        flow->updateTcpSeqNum(when, ntohl(tcph->seq), ntohl(tcph->ack_seq),
                              ntohs(tcph->window), tcp_flags,
                              l4_len - (4 * tcph->doff), src2dst_direction);
        break;

      case IPPROTO_ICMP:
      case IPPROTO_ICMPV6:
        if (trusted_l4_packet_len > 2) {
          u_int8_t icmp_type = l4[0];
          u_int8_t icmp_code = l4[1];

          flow->setICMP(src2dst_direction, icmp_type, icmp_code, l4);
          flow->updateICMPFlood(when, src2dst_direction);
          flow->setICMPPayloadSize(trusted_l4_packet_len);
          trusted_payload_len = trusted_l4_packet_len, payload = l4;
        }
        break;

      default:
        /*
          NOTE: for non TCP-flows, the swap heuristic is always checked on the
          first packet
        */
        if (new_flow) flow->check_swap();
        break;
    }

#ifndef HAVE_NEDGE
#ifdef __OpenBSD__
    struct timeval tv_ts;

    tv_ts.tv_sec = h->ts.tv_sec;
    tv_ts.tv_usec = h->ts.tv_usec;

    flow->incStats(src2dst_direction, len_on_wire - encapsulation_overhead,
                   payload, trusted_payload_len, l4_proto, is_fragment,
                   tcp_flags, &tv_ts, fragment_extra_overhead);
#else
    flow->incStats(src2dst_direction, len_on_wire - encapsulation_overhead,
                   payload, trusted_payload_len, l4_proto, is_fragment,
                   tcp_flags, &h->ts, fragment_extra_overhead);
#endif
#endif
  }

  /*
    In case of a traffic mirror with no MAC gateway address configured
    the traffic direction is set based on the local (-m) host
  */
  if (isTrafficMirrored() && (!isGwMacConfigured())) {
    bool cli_local = src_ip.isLocalHost();
    bool srv_local = dst_ip.isLocalHost();

    if (cli_local && (!srv_local))
      ingressPacket = false;
    else if ((!cli_local) && srv_local)
      ingressPacket = true;
    else
      ; /* Leave as is */

#if 0
    char a[32], b[32];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s (%s) -> %s (%s) [%s]",
				 src_ip.print(a, sizeof(a)),
				 src_ip.isLocalHost() ? "L" : "R",
				 dst_ip.print(b, sizeof(b)),
				 dst_ip.isLocalHost() ? "L" : "R",
				 ingressPacket ? "IN" : "OUT");
#endif
  }

  /* Protocol Detection */

  /* This is now incremented in Flow::hosts_periodic_stats_update
   * by calling iface->incLocalStats */
  // flow->updateInterfaceLocalStats(src2dst_direction, 1, len_on_wire);

  if (!flow->isDetectionCompleted() || flow->needsExtraDissection()) {
    if ((!is_fragment)
#ifdef IMPLEMENT_SMART_FRAGMENTS
        || (fragment_offset == 0)
#endif
    )
      flow->processPacket(h, ip, trusted_ip_len, packet_time, payload,
                          trusted_payload_len, src_port);
    else {
      // FIX - only handle unfragmented packets
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "IP fragments are not
      // handled yet!");
    }
  }

  if (flow->isDetectionCompleted() && (!isSampledTraffic())) {
    switch (ndpi_get_lower_proto(flow->get_detected_protocol())) {
      case NDPI_PROTOCOL_DHCP:
        if (*srcHost) {
          Mac *mac = (*srcHost)->getMac(), *payload_cli_mac;

          if (mac && (trusted_payload_len > 240)) {
            struct dhcp_packet *dhcpp = (struct dhcp_packet *)payload;

            if (dhcpp->msgType == 0x01) {
              /* Request */
              ;  // mac->setDhcpHost();
              mac->incNumDHCPRequests();
            } else if (dhcpp->msgType == 0x02) { /* Reply */
              checkMacIPAssociation(false, dhcpp->chaddr, dhcpp->yiaddr, mac);
              checkDhcpIPRange(mac, dhcpp, vlan_id);
              setDHCPAddressesSeen();
              mac->incNumDHCPReplies();
            }

            for (u_int32_t i = 240; i < trusted_payload_len;) {
              u_int8_t id = payload[i], len = payload[i + 1];

              if (len == 0) break;

#ifdef DHCP_DEBUG
              ntop->getTrace()->traceEvent(TRACE_WARNING,
                                           "[DHCP] [id=%u][len=%u]", id, len);
#endif

              if (id == 12 /* Host Name */) {
                char name[64], buf[24], *client_mac, key[64];
                int j;

                j = ndpi_min(len, sizeof(name) - 1);
                strncpy((char *)name, (char *)&payload[i + 2], j);
                name[j] = '\0';

                client_mac = Utils::formatMac(&payload[28], buf, sizeof(buf));
                ntop->getTrace()->traceEvent(TRACE_INFO, "[DHCP] %s = '%s'",
                                             client_mac, name);

                snprintf(key, sizeof(key), DHCP_CACHE, get_id(), client_mac);
                ntop->getRedis()->set(key, name, 86400 /* 1d duration */);

                if ((payload_cli_mac = getMac(
                         &payload[28], false /* Do not create if missing */,
                         true /* Inline call */)))
                  payload_cli_mac->inlineSetDHCPName(name);

#ifdef DHCP_DEBUG
                ntop->getTrace()->traceEvent(TRACE_WARNING, "[DHCP] %s = '%s'",
                                             client_mac, name);
#endif
              } else if ((id == 55 /* Parameters List (Fingerprint) */) &&
                         flow->get_ndpi_flow()) {
                char fingerprint[64], buf[32];
                u_int idx, offset = 0;

                len = ndpi_min(len, sizeof(buf) / 2);

                for (idx = 0; idx < len; idx++) {
                  snprintf((char *)&fingerprint[offset],
                           sizeof(fingerprint) - offset - 1, "%02X",
                           payload[i + 2 + idx] & 0xFF);
                  offset += 2;
                }

#ifdef DHCP_DEBUG
                ntop->getTrace()->traceEvent(TRACE_WARNING, "%s = %s",
                                             mac->print(buf, sizeof(buf)),
                                             fingerprint);
#endif
                mac->inlineSetFingerprint(
                    (char *)flow->get_ndpi_flow()->protos.dhcp.fingerprint);
              } else if (id == 0xFF)
                break; /* End of options */

              i += len + 2;
            }
          }
        }
        break;

      case NDPI_PROTOCOL_DHCPV6:
        if (*srcHost && *dstHost) {
          Mac *src_mac = (*srcHost)->getMac();
          Mac *dst_mac = (*dstHost)->getMac();

          if (src_mac && dst_mac && (trusted_payload_len > 20) &&
              dst_mac->isMulticast())
            ;  // src_mac->setDhcpHost();
        }
        break;

      case NDPI_PROTOCOL_NETBIOS:
        flow->dissectNetBIOS(payload, trusted_payload_len);
        break;

      case NDPI_PROTOCOL_BITTORRENT:
        if ((flow->getBitTorrentHash() == NULL) && (l4_proto == IPPROTO_UDP) &&
            (flow->get_packets() < 8))
          flow->dissectBittorrent((char *)payload, trusted_payload_len);
        break;

      case NDPI_PROTOCOL_HTTP:
        if (trusted_payload_len > 0)
          flow->dissectHTTP(src2dst_direction, (char *)payload,
                            trusted_payload_len);
        break;

      case NDPI_PROTOCOL_SSDP:
        if (trusted_payload_len > 0)
          flow->dissectSSDP(src2dst_direction, (char *)payload,
                            trusted_payload_len);
        break;

      case NDPI_PROTOCOL_DNS:
        /*
          DNS-over-TCP flows may carry zero-payload TCP segments
          e.g., during three-way-handshake, or when acknowledging.
          Make sure only non-zero-payload segments are processed.
        */
        /* However still consider for a possible DNS flood */
#ifdef NTOPNG_PRO
        flow->updateDNSFlood(when, src2dst_direction);
#endif

        if ((trusted_payload_len > 0) && payload) {
          flow->dissectDNS(src2dst_direction, (char *)payload,
                           trusted_payload_len);
          /*
            DNS-over-TCP has a 2-bytes field with DNS payload length
            at the beginning. See RFC1035 section 4.2.2. TCP usage.
          */
        }

        break;

      case NDPI_PROTOCOL_SNMP:
#ifdef NTOPNG_PRO
        flow->updateSNMPFlood(when, src2dst_direction);
#endif
        break;

      case NDPI_PROTOCOL_IEC60870:
        if ((trusted_payload_len > 0) && payload) {
          flow->processIEC60870Packet((htons(src_port) == 2404) ? true : false,
                                      payload, trusted_payload_len,
                                      (struct timeval *)&h->ts);
        }
        break;

      case NDPI_PROTOCOL_MDNS:
#ifdef MDNS_TEST
        extern void _dissectMDNS(u_char * buf, u_int buf_len, char *out,
                                 u_int out_len);
        char outbuf[1024];

        _dissectMDNS(payload, trusted_payload_len, outbuf, sizeof(outbuf));
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", outbuf);
#endif
        flow->dissectMDNS(payload, trusted_payload_len);

        if (discovery && iph)
          discovery->queueMDNSResponse(iph->saddr, payload,
                                       trusted_payload_len);
        break;

      case NDPI_PROTOCOL_RTP:

        if (flow->isZoomRTP()) {
          // ntop->getTrace()->traceEvent(TRACE_NORMAL, "XXX [%d]", payload[0]);

          if (payload[0] == 5 /* RTCP/RTP */) {
            u_int8_t encoding_type = payload[8];

            switch (encoding_type) {
              case 13: /* Screen Share */
              case 30: /* Screen Share */
                flow->setRTPStreamType(rtp_screen_share);
                break;

              case 15: /* Audio */
                flow->setRTPStreamType(rtp_audio);
                break;

              case 16: /* Video */
                flow->setRTPStreamType(rtp_video);
                break;
            }
          }
        } else if (flow->getRTPStreamType() == rtp_unknown) {
          if (flow->get_ndpi_flow() != NULL) {
            flow->setRTPStreamType(
                flow->get_ndpi_flow()->protos.rtp.stream_type);
          }
        }
        break;
    }

#ifdef HAVE_NEDGE
    if (is_bridge_interface()) {
      struct tm now;
      time_t t_now = time(NULL);
      localtime_r(&t_now, &now);
      pass_verdict = flow->checkPassVerdict(&now);

      if (pass_verdict) {
        TrafficShaper *shaper_ingress, *shaper_egress;
        char buf[64];

        flow->getFlowShapers(src2dst_direction, &shaper_ingress,
                             &shaper_egress);
        ntop->getTrace()->traceEvent(
            TRACE_DEBUG, "[%s] %u / %u ",
            flow->get_detected_protocol_name(buf, sizeof(buf)), shaper_ingress,
            shaper_egress);
        pass_verdict = passShaperPacket(shaper_ingress, shaper_egress,
                                        (struct pcap_pkthdr *)h);
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

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "direction: %s / len: %u",
  // ingressPacket ? "IN" : "OUT", len_on_wire);

  incStats(ingressPacket, when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
           flow->getStatsProtocol(), flow->get_protocol_category(), l4_proto,
           len_on_wire, 1);

  /* For large flows, a periodic_stats_update is performed straight after
     processing a packet. Conditions checked to determine 'a large flow' are

     (1) A minimum number of bytes transferred since the previous
     periodic_stats_update (checked using get_current_*) (2) A minimum number of
     milliseconds elapsed since the previous periodic_stats_update (checked
     using get_current_update_time())

     Conditions above are necessary as:

     (1) ensures that large flows perform faster periodic_stats_update, without
     having to wait for purgeIdle to visit the whole hash table (this may take
     up to PURGE_FRACTION seconds). (2) ensures that periodic_stats_update is
     not performed too frequently as it could be detrimental for performances
     and lead to packet drops.
  */
  if (flow->get_current_bytes_cli2srv() + flow->get_current_bytes_srv2cli() >=
          PERIODIC_STATS_UPDATE_MIN_REFRESH_BYTES &&
      Utils::msTimevalDiff(when, flow->get_current_update_time()) >=
          PERIODIC_STATS_UPDATE_MIN_REFRESH_MS) {
    flow->periodic_stats_update(when);
  }

  return (pass_verdict);
}

/* **************************************************** */

void NetworkInterface::purgeIdle(time_t when, bool force_idle, bool full_scan) {
  u_int n, m, o;
  last_pkt_rcvd = when;

  bcast_domains->reloadBroadcastDomains(
      full_scan /* Force a reload only if a full scan is requested */);

  if ((n = purgeIdleFlows(force_idle, full_scan)) > 0)
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Purged %u/%u idle flows on %s",
                                 n, getNumFlows(), ifname);

  if ((m = purgeIdleHosts(force_idle, full_scan)) > 0)
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Purged %u/%u idle hosts on %s",
                                 m, getNumHosts(), ifname);

  if ((o = purgeIdleMacsASesCountriesVLANs(force_idle, full_scan)) > 0)
    ntop->getTrace()->traceEvent(
        TRACE_DEBUG, "Purged %u idle ASs, MAC, Countries, VLANs... on %s", o,
        ifname);

  for (std::map<u_int64_t, NetworkInterface *>::iterator it =
           flowHashing.begin();
       it != flowHashing.end(); ++it)
    it->second->purgeIdle(when, force_idle, full_scan);

  checkHostsToRestore();

#if defined(NTOPNG_PRO)
  if (pMap) pMap->purgeIdle(when);
  if (sMap) sMap->purgeIdle(when);
#endif

  if (gw_macs_reload_requested) reloadGwMacs();
}

/* ****************************************************** */

u_int16_t NetworkInterface::guessEthType(const u_char *p, u_int len,
                                         u_int8_t *is_ethernet) {
  if (len >= sizeof(struct ndpi_ethhdr)) {
    /* Check if this looks like ethernet */
    struct ndpi_ethhdr *ehdr = (struct ndpi_ethhdr *)p;
    u_int16_t eth_type = ntohs(ehdr->h_proto);

    switch (eth_type) {
      case ETHERTYPE_IP:
      case ETHERTYPE_IPV6:
      case ETHERTYPE_PPPoE:
      case ETHERTYPE_VLAN:
        *is_ethernet = 1;
        return (eth_type);
    }
  }

  *is_ethernet = 0;

  if (len >= sizeof(struct ndpi_iphdr)) {
    struct ndpi_iphdr *ipv4 = (struct ndpi_iphdr *)p;

    if (ipv4->version == 4) return (ETHERTYPE_IP);
  }

  if (len >= sizeof(struct ip6_hdr)) {
    struct ip6_hdr *ipv6 = (struct ip6_hdr *)p;

    if (((ipv6->ip6_vfc >> 4) & 0x0f) == 6) return (ETHERTYPE_IPV6);
  }

  return (1 /* Unknown */);
}

/* **************************************************** */

bool NetworkInterface::dissectPacket(u_int32_t bridge_iface_idx,
                                     bool ingressPacket, u_int8_t *sender_mac,
                                     const struct pcap_pkthdr *h,
                                     const u_char *packet,
                                     u_int16_t *ndpiProtocol, Host **srcHost,
                                     Host **dstHost, Flow **flow) {
  struct ndpi_ethhdr *ethernet = NULL, dummy_ethernet;
  u_int64_t time;
  u_int16_t eth_type, ip_offset = 0, vlan_id = 0, eth_offset = 0,
                      encapsulation_overhead = 0;
  u_int32_t null_type;
  int pcap_datalink_type = get_datalink();
  bool pass_verdict = true;
  u_int32_t len_on_wire = h->len * getScalingFactor();
  *flow = NULL;

  /* Note summy ethernet is always 0 unless sender_mac is set (Netfilter only)
   */
  memset(&dummy_ethernet, 0, sizeof(dummy_ethernet));

  pollQueuedeCompanionEvents();
  bcast_domains->reloadBroadcastDomains();

  /* Netfilter interfaces don't report MAC addresses on packets */
  if (getIfType() == interface_type_NETFILTER)
    len_on_wire += sizeof(struct ndpi_ethhdr);

  if (h->len > ifMTU) {
    if (!mtuWarningShown) {
#ifdef __linux__
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL,
          "Packets exceeding the expected max size have been received "
          "[len: %u][max len: %u].",
          h->len, ifMTU);

      if (!read_from_pcap_dump()) {
        ntop->getTrace()->traceEvent(
            TRACE_WARNING,
            "If TSO/GRO is enabled, please disable it for best accuracy");
        if (strchr(ifname, ':') ==
            NULL) /* print ethtool command for standard interfaces only */
          ntop->getTrace()->traceEvent(
              TRACE_WARNING,
              "using: sudo ethtool -K %s gro off gso off tso off", ifname);
      }
#endif
      mtuWarningShown = true;
    }
  }

  setTimeLastPktRcvd(h->ts.tv_sec);

  if (last_purge_idle != (u_int32_t)h->ts.tv_sec) {
    if (!read_from_pcap_dump()) purgeIdle(h->ts.tv_sec);
    last_purge_idle = h->ts.tv_sec;
  }

  time = ((uint64_t)h->ts.tv_sec) * 1000 + h->ts.tv_usec / 1000;

datalink_check:
  if (pcap_datalink_type == DLT_NULL) {
    memcpy(&null_type, &packet[eth_offset], sizeof(u_int32_t));

    switch (null_type) {
      case BSD_AF_INET:
        eth_type = ETHERTYPE_IP;
        break;
      case BSD_AF_INET6_BSD:
      case BSD_AF_INET6_FREEBSD:
      case BSD_AF_INET6_DARWIN:
        eth_type = ETHERTYPE_IPV6;
        break;
      default:
        incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
                 NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
        goto dissect_packet_end; /* Any other non IP protocol */
    }

    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    if (sender_mac) memcpy(&dummy_ethernet.h_source, sender_mac, 6);
    ip_offset = 4 + eth_offset;
  } else if (pcap_datalink_type == DLT_EN10MB) {
    ethernet = (struct ndpi_ethhdr *)&packet[eth_offset];
    ip_offset = sizeof(struct ndpi_ethhdr) + eth_offset;
    eth_type = ntohs(ethernet->h_proto);
  } else if (pcap_datalink_type == 113 /* Linux Cooked Capture */) {
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    if (sender_mac) memcpy(&dummy_ethernet.h_source, sender_mac, 6);
    eth_type = (packet[eth_offset + 14] << 8) + packet[eth_offset + 15];
    ip_offset = 16 + eth_offset;
#ifdef DLT_RAW
  } else if (pcap_datalink_type ==
                 DLT_RAW /* Linux TUN/TAP device in TUN mode; Raw IP capture */
             || pcap_datalink_type ==
                    14 /* raw IP DLT_RAW on OpenBSD captures */) {
    switch ((packet[eth_offset] & 0xf0) >> 4) {
      case 4:
        eth_type = ETHERTYPE_IP;
        break;
      case 6:
        eth_type = ETHERTYPE_IPV6;
        break;
      default:
        incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
                 NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
        goto dissect_packet_end; /* Unknown IP protocol version */
    }

    if (sender_mac) memcpy(&dummy_ethernet.h_source, sender_mac, 6);
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    ip_offset = eth_offset;
#endif /* DLT_RAW */
  } else if (pcap_datalink_type == DLT_ENC) {
    if (packet[0] == 2 /* IPv4 */) {
      eth_type = ETHERTYPE_IP;
      ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
      ip_offset = 12;
    }
    /* TODO support IPv6 encapsulation one day */
  } else if (pcap_datalink_type == DLT_IPV4) {
    eth_type = ETHERTYPE_IP;
    if (sender_mac) memcpy(&dummy_ethernet.h_source, sender_mac, 6);
    ethernet = (struct ndpi_ethhdr *)&dummy_ethernet;
    ip_offset = 0;
  } else {
    incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
             NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
    goto dissect_packet_end;
  }

  /*
    Make sure this label is BEFORE detunneling of VLAN or MPLS traffic.
    Otherwise, VLAN or MPLS traffic carried inside other tunnels, i.e.,
    GRE or ERSPAN, won't be detunneled.
  */
decode_packet_eth:

  while (true) {
    if (eth_type == 0x8100 /* VLAN */) {
      Ether80211q *qType = (Ether80211q *)&packet[ip_offset];

      vlan_id = ntohs(qType->vlanId) & 0xFFF;
      eth_type = (packet[ip_offset + 2] << 8) + packet[ip_offset + 3];
      ip_offset += 4;
    } else if (eth_type == 0x8847 /* MPLS */) {
      u_int8_t bos; /* bottom_of_stack */

      bos = (((u_int8_t)packet[ip_offset + 2]) & 0x1), ip_offset += 4;
      if (bos) {
        u_int8_t is_ethernet;

        eth_type = guessEthType((const u_char *)&packet[ip_offset],
                                h->caplen - ip_offset, &is_ethernet);

        if (is_ethernet) ip_offset += sizeof(struct ndpi_ethhdr);
        break;
      }
    } else
      break;
  }

  /* Setting traffic direction based on MAC */
  if (ethernet) {
    if (isTrafficMirrored()) {
      /* Mirror */
      if (isGwMac(ethernet->h_dest)) ingressPacket = false;
    } else if (!areTrafficDirectionsSupported()) {
      /* Interface with no direction info */
      if (isInterfaceMac(ethernet->h_source)) ingressPacket = false;
    }
  }

  switch (eth_type) {
    case ETHERTYPE_PPPoE:
      ip_offset += 6 /* PPPoE */;
      /* Now we need to skip the PPP header */
      if (packet[ip_offset] == 0x0)
        eth_type = packet[ip_offset + 1], ip_offset += 2; /* 2 Byte protocol */
      else
        eth_type = packet[ip_offset], ip_offset += 1; /* 1 Byte protocol */

      switch (eth_type) {
        case 0x21:
          eth_type = ETHERTYPE_IP;
          break;

        case 0x57:
          eth_type = ETHERTYPE_IPV6;
          break;

        default:
          incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IP,
                   NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0,
                   len_on_wire, 1);
          goto dissect_packet_end;
      }
      goto decode_packet_eth;
      break;

    case ETHERTYPE_IP:
      if (h->caplen >= ip_offset + sizeof(struct ndpi_iphdr)) {
        u_int16_t frag_off;
        struct ndpi_iphdr *iph = (struct ndpi_iphdr *)&packet[ip_offset];
        u_short ip_len = ((u_short)iph->ihl * 4);
        struct ndpi_ipv6hdr *ip6 = NULL;

        if (iph->version != 4) {
          /* This is not IPv4 */
          incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IP,
                   NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0,
                   len_on_wire, 1);
          goto dissect_packet_end;
        } else
          frag_off = ntohs(iph->frag_off);

        if (ntop->getGlobals()->decode_tunnels() &&
            (iph->protocol == IPPROTO_GRE) &&
            ((frag_off & 0x3FFF /* IP_MF | IP_OFFSET */) == 0) &&
            h->caplen >= ip_offset + ip_len + sizeof(struct grev1_header)) {
          struct grev1_header gre;
          u_int offset = ip_offset + ip_len + sizeof(struct grev1_header);

          memcpy(&gre, &packet[ip_offset + ip_len],
                 sizeof(struct grev1_header));
          gre.flags_and_version = ntohs(gre.flags_and_version);
          gre.proto = ntohs(gre.proto);

          if (gre.flags_and_version &
              (GRE_HEADER_CHECKSUM | GRE_HEADER_ROUTING))
            offset += 4;
          if (gre.flags_and_version & GRE_HEADER_KEY) offset += 4;
          if (gre.flags_and_version & GRE_HEADER_SEQ_NUM) offset += 4;

          if (h->caplen >= offset) {
            if (gre.proto == 0x6558 /* Transparent Ethernet Bridging */) {
              eth_offset = offset;
              goto datalink_check;
            } else if (gre.proto == ETHERTYPE_IP) {
              ip_offset = offset, encapsulation_overhead = offset;
              goto decode_packet_eth;
            } else if (gre.proto == ETHERTYPE_IPV6) {
              eth_type = ETHERTYPE_IPV6;
              ip_offset = offset, encapsulation_overhead = offset;
              goto decode_packet_eth;
            }
          }

          /* ERSPAN Type 2 has an 8-byte header
             https://tools.ietf.org/html/draft-foschiano-erspan-00 */
          if (h->caplen >= offset + sizeof(struct ndpi_ethhdr) + 8) {
            if (gre.proto == ETH_P_ERSPAN /* ERSPAN type II */) {
              offset += 8;
              eth_offset = offset, encapsulation_overhead = offset;
              ethernet = (struct ndpi_ethhdr *)&packet[eth_offset];
              ip_offset = eth_offset + sizeof(struct ndpi_ethhdr);
              eth_type = ntohs(ethernet->h_proto);
              goto decode_packet_eth;
            } else if (gre.proto ==
                       ETH_P_ERSPAN2 /* ERSPAN version 2 (type III) */) {
              if (h->caplen >= offset + sizeof(struct ndpi_ethhdr) + 20) {
                offset += 20;
                eth_offset = offset, encapsulation_overhead = offset;
                ethernet = (struct ndpi_ethhdr *)&packet[eth_offset];
                ip_offset = eth_offset + sizeof(struct ndpi_ethhdr);
                eth_type = ntohs(ethernet->h_proto);
                goto decode_packet_eth;
              }
            } else {
              /* Unknown encapsulation */
            }
          }
        } else if (ntop->getGlobals()->decode_tunnels() &&
                   iph->protocol == IPPROTO_IPV6 &&
                   h->caplen >=
                       ip_offset + ip_len + sizeof(struct ndpi_ipv6hdr)) {
          /* Detunnel 6in4 tunnel */
          ip_offset += ip_len;
          eth_type = ETHERTYPE_IPV6;
          encapsulation_overhead = ip_offset;
          goto decode_packet_eth;
        } else if (ntop->getGlobals()->decode_tunnels() &&
                   (iph->protocol == IPPROTO_UDP) &&
                   ((frag_off & 0x3FFF /* IP_MF | IP_OFFSET */) == 0)) {
          struct ndpi_udphdr *udp =
              (struct ndpi_udphdr *)&packet[ip_offset + ip_len];
          u_int16_t sport = ntohs(udp->source), dport = ntohs(udp->dest);

          if ((sport == GTP_U_V1_PORT) || (dport == GTP_U_V1_PORT)) {
            /* Check if it's GTPv1 */
            u_int offset =
                (u_int)(ip_offset + ip_len + sizeof(struct ndpi_udphdr));
            u_int8_t flags = packet[offset];
            u_int8_t message_type = packet[offset + 1];

            if ((((flags & 0xE0) >> 5) == 1 /* GTPv1 */) &&
                (message_type == 0xFF /* T-PDU */)) {
              ip_offset = ip_offset + ip_len + sizeof(struct ndpi_udphdr) +
                          8 /* GTPv1 header len */;

              if (flags & 0x04) ip_offset += 1; /* next_ext_header is present */
              if (flags & 0x02)
                ip_offset += 4; /* sequence_number is present (it also includes
                                   next_ext_header and pdu_number) */
              if (flags & 0x01) ip_offset += 1; /* pdu_number is present */

              iph = (struct ndpi_iphdr *)&packet[ip_offset];

              if (iph->version != 4) {
                /* FIX - Add IPv6 support */
                incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6,
                         NDPI_PROTOCOL_UNKNOWN,
                         NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
                goto dissect_packet_end;
              }
            }
          } else if ((sport == TZSP_PORT) || (dport == TZSP_PORT)) {
            /* https://en.wikipedia.org/wiki/TZSP */
            u_int offset = ip_offset + ip_len + sizeof(struct ndpi_udphdr);
            u_int8_t version = packet[offset];
            u_int8_t type = packet[offset + 1];
            u_int16_t encapsulates = ntohs(*((u_int16_t *)&packet[offset + 2]));

            if ((version == 1) && (type == 0) && (encapsulates == 1)) {
              u_int8_t stop = 0;

              offset += 4;

              while ((!stop) && (offset < h->caplen)) {
                u_int8_t tag_type = packet[offset];
                u_int8_t tag_len;

                switch (tag_type) {
                  case 0: /* PADDING Tag */
                    tag_len = 1;
                    break;
                  case 1: /* END Tag */
                    tag_len = 1, stop = 1;
                    break;
                  default:
                    tag_len = packet[offset + 1];
                    break;
                }

                offset += tag_len;

                if (offset >= h->caplen) {
                  incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6,
                           NDPI_PROTOCOL_UNKNOWN,
                           NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire,
                           1);
                  goto dissect_packet_end;
                } else {
                  eth_offset = offset;
                  goto datalink_check;
                }
              }
            }
          } else if (dport == VXLAN_PORT) {
            eth_offset = ip_offset + ip_len + sizeof(struct ndpi_udphdr) +
                         sizeof(struct ndpi_vxlanhdr);
            goto datalink_check;
          }

          if ((sport == CAPWAP_DATA_PORT) || (dport == CAPWAP_DATA_PORT)) {
            /*
              Control And Provisioning of Wireless Access Points

              https://www.rfc-editor.org/rfc/rfc5415.txt

              CAPWAP Header          - variable length (5 MSB of byte 2 of
              header) IEEE 802.11 Data Flags - 24 bytes Logical-Link Control   -
              8  bytes

              Total = CAPWAP_header_length + 24 + 8
            */
            u_short eth_type;
            ip_offset = ip_offset + ip_len + sizeof(struct ndpi_udphdr);
            u_int8_t capwap_header_len =
                ((*(u_int8_t *)&packet[ip_offset + 1]) >> 3) * 4;
            ip_offset = ip_offset + capwap_header_len + 24 + 8;

            if (ip_offset >= h->len) {
              incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
                       NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
              goto dissect_packet_end;
            }
            eth_type = ntohs(*(u_int16_t *)&packet[ip_offset - 2]);

            switch (eth_type) {
              case ETHERTYPE_IP:
                iph = (struct ndpi_iphdr *)&packet[ip_offset];
                break;
              case ETHERTYPE_IPV6:
                iph = NULL;
                ip6 = (struct ndpi_ipv6hdr *)&packet[ip_offset];
                break;
              default:
                incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
                         NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
                goto dissect_packet_end;
            }
          }
        } else if (ntop->getGlobals()->decode_tunnels() &&
                   (iph->protocol == IPPROTO_IP_IN_IP)) {
          u_short ip_len = ((u_short)iph->ihl * 4);

          ip_offset += ip_len, eth_type = ETHERTYPE_IP;

          if (ip_offset > h->caplen)
            goto dissect_packet_end;
          else
            goto decode_packet_eth;
        }

        if (vlan_id && ntop->getPrefs()->do_ignore_vlans()) vlan_id = 0;
        if ((vlan_id == 0) && ntop->getPrefs()->do_simulate_vlans())
          vlan_id = (ip6 ? ip6->ip6_src.u6_addr.u6_addr8[15] +
                               ip6->ip6_dst.u6_addr.u6_addr8[15]
                         : iph->saddr + iph->daddr) &
                    0xFFF;

        if (ntop->getPrefs()->do_ignore_macs())
          ethernet = &dummy_ethernet;
        else if (unlikely(ntop->getPrefs()->do_simulate_macs())) {
          dummy_ethernet.h_source[0] = 0xb8, dummy_ethernet.h_source[1] = 0x27,
          dummy_ethernet.h_source[2] = 0xeb, dummy_ethernet.h_source[3] = 0xfd,
          dummy_ethernet.h_source[4] = 0x8e,
          dummy_ethernet.h_source[5] = rand() % 8;
          dummy_ethernet.h_dest[0] = 0xb8, dummy_ethernet.h_dest[1] = 0x27,
          dummy_ethernet.h_dest[2] = 0xeb, dummy_ethernet.h_dest[3] = 0xfd,
          dummy_ethernet.h_dest[4] = 0x8e,
          dummy_ethernet.h_dest[5] = rand() % 8;
          ethernet = &dummy_ethernet;
        }

        try {
          pass_verdict = processPacket(
              bridge_iface_idx, ingressPacket, &h->ts, time, ethernet, vlan_id,
              iph, ip6, ip_offset, encapsulation_overhead, len_on_wire, h,
              packet, ndpiProtocol, srcHost, dstHost, flow);
        } catch (std::bad_alloc &ba) {
          static bool oom_warning_sent = false;

          if (!oom_warning_sent) {
            ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
            oom_warning_sent = true;
          }
        }
      }
      break;

    case ETHERTYPE_IPV6:
      if (h->caplen >= ip_offset + sizeof(struct ndpi_ipv6hdr)) {
        struct ndpi_iphdr *iph = NULL;
        struct ndpi_ipv6hdr *ip6 = (struct ndpi_ipv6hdr *)&packet[ip_offset];

        if ((ntohl(ip6->ip6_hdr.ip6_un1_flow) & 0xF0000000) != 0x60000000) {
          /* This is not IPv6 */
          incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6,
                   NDPI_PROTOCOL_UNKNOWN, NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0,
                   len_on_wire, 1);
          goto dissect_packet_end;
        } else {
          u_int ipv6_shift = sizeof(const struct ndpi_ipv6hdr);
          u_int8_t l4_proto = ip6->ip6_hdr.ip6_un1_nxt;

          if (l4_proto == 0x3C /* IPv6 destination option */) {
            u_int8_t *options = (u_int8_t *)ip6 + ipv6_shift;
            l4_proto = options[0];
            ipv6_shift = 8 * (options[1] + 1);
          }

          if (ntop->getGlobals()->decode_tunnels() &&
              (l4_proto == IPPROTO_GRE) &&
              h->caplen >=
                  ip_offset + ipv6_shift + sizeof(struct grev1_header)) {
            struct grev1_header gre;
            u_int offset = ip_offset + ipv6_shift + sizeof(struct grev1_header);

            memcpy(&gre, &packet[ip_offset + ipv6_shift],
                   sizeof(struct grev1_header));
            gre.flags_and_version = ntohs(gre.flags_and_version);
            gre.proto = ntohs(gre.proto);

            if (gre.flags_and_version &
                (GRE_HEADER_CHECKSUM | GRE_HEADER_ROUTING))
              offset += 4;
            if (gre.flags_and_version & GRE_HEADER_KEY) offset += 4;
            if (gre.flags_and_version & GRE_HEADER_SEQ_NUM) offset += 4;

            if (h->caplen >= offset) {
              if (gre.proto == ETHERTYPE_IP) {
                eth_type = ETHERTYPE_IP;
                ip_offset = offset, encapsulation_overhead = offset;
                goto decode_packet_eth;
              } else if (gre.proto == ETHERTYPE_IPV6) {
                ip_offset = offset, encapsulation_overhead = offset;
                goto decode_packet_eth;
              }
            }

            if (h->caplen >= offset + sizeof(struct ndpi_ethhdr) +
                                 8 /* ERSPAN Type 2 header */) {
              if (gre.proto == ETH_P_ERSPAN) {
                offset += 8;
                eth_offset = offset, encapsulation_overhead = offset;
                ethernet = (struct ndpi_ethhdr *)&packet[eth_offset];
                ip_offset = eth_offset + sizeof(struct ndpi_ethhdr);
                eth_type = ntohs(ethernet->h_proto);
                goto decode_packet_eth;
              } else if (gre.proto == ETH_P_ERSPAN2) {
                ; /* TODO: support ERSPAN Type 3 */
              } else {
                /* Unknown encapsulation */
              }
            }
          } else if (ntop->getGlobals()->decode_tunnels() &&
                     (l4_proto == IPPROTO_UDP)) {
            // ip_offset += ipv6_shift;
            if ((ip_offset + ipv6_shift) >= h->len) {
              incStats(ingressPacket, h->ts.tv_sec, ETHERTYPE_IPV6,
                       NDPI_PROTOCOL_UNKNOWN,
                       NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
              goto dissect_packet_end;
            }

            struct ndpi_udphdr *udp =
                (struct ndpi_udphdr *)&packet[ip_offset + ipv6_shift];
            u_int16_t sport = udp->source, dport = udp->dest;

            if ((sport == CAPWAP_DATA_PORT) || (dport == CAPWAP_DATA_PORT)) {
              /*
                Control And Provisioning of Wireless Access Points

                https://www.rfc-editor.org/rfc/rfc5415.txt

                CAPWAP Header          - variable length (5 MSB of byte 2 of
                header) IEEE 802.11 Data Flags - 24 bytes Logical-Link Control
                - 8  bytes

                Total = CAPWAP_header_length + 24 + 8
              */

              u_short eth_type;
              ip_offset = ip_offset + ipv6_shift + sizeof(struct ndpi_udphdr);
              u_int8_t capwap_header_len =
                  ((*(u_int8_t *)&packet[ip_offset + 1]) >> 3) * 4;
              ip_offset = ip_offset + capwap_header_len + 24 + 8;

              if (ip_offset >= h->len) {
                incStats(ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
                         NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
                goto dissect_packet_end;
              }
              eth_type = ntohs(*(u_int16_t *)&packet[ip_offset - 2]);

              switch (eth_type) {
                case ETHERTYPE_IP:
                  iph = (struct ndpi_iphdr *)&packet[ip_offset];
                  ip6 = NULL;
                  break;
                case ETHERTYPE_IPV6:
                  ip6 = (struct ndpi_ipv6hdr *)&packet[ip_offset];
                  break;
                default:
                  incStats(
                      ingressPacket, h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN,
                      NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
                  goto dissect_packet_end;
              }
            }
          } else if (ntop->getGlobals()->decode_tunnels() &&
                     (l4_proto == IPPROTO_IP_IN_IP)) {
            eth_type = ETHERTYPE_IP;
            ip_offset += sizeof(struct ndpi_ipv6hdr);
            encapsulation_overhead = ip_offset;
            goto decode_packet_eth;
          }

          if (vlan_id && ntop->getPrefs()->do_ignore_vlans()) vlan_id = 0;
          if ((vlan_id == 0) && ntop->getPrefs()->do_simulate_vlans())
            vlan_id = (ip6 ? ip6->ip6_src.u6_addr.u6_addr8[15] +
                                 ip6->ip6_dst.u6_addr.u6_addr8[15]
                           : iph->saddr + iph->daddr) %
                      0xFF;

          if (ntop->getPrefs()->do_ignore_macs()) ethernet = &dummy_ethernet;

          try {
            pass_verdict = processPacket(
                bridge_iface_idx, ingressPacket, &h->ts, time, ethernet,
                vlan_id, iph, ip6, ip_offset, encapsulation_overhead,
                len_on_wire, h, packet, ndpiProtocol, srcHost, dstHost, flow);
          } catch (std::bad_alloc &ba) {
            static bool oom_warning_sent = false;

            if (!oom_warning_sent) {
              ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
              oom_warning_sent = true;
            }
          }
        }
      }
      break;

    default: /* No IPv4 nor IPv6 */
      if (ntop->getPrefs()->do_ignore_macs()) ethernet = &dummy_ethernet;

      if (ethernet == NULL) {
        incStats(ingressPacket, h->ts.tv_sec, eth_type, NDPI_PROTOCOL_UNKNOWN,
                 NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
        goto dissect_packet_end;
      }

      Mac *srcMac = getMac(ethernet->h_source, true /* Create if missing */,
                           true /* Inline call */);
      Mac *dstMac = getMac(ethernet->h_dest, true /* Create if missing */,
                           true /* Inline call */);

      /* NOTE: in nEdge, stats are updated into Flow::update_hosts_stats */
#ifndef HAVE_NEDGE
      if (srcMac) srcMac->incSentStats(h->ts.tv_sec, 1, len_on_wire);
      if (dstMac) dstMac->incRcvdStats(h->ts.tv_sec, 1, len_on_wire);
#endif

      if ((eth_type == ETHERTYPE_ARP) &&
          (h->caplen >= (sizeof(arp_header) + sizeof(struct ndpi_ethhdr)))) {
        struct arp_header *arpp = (struct arp_header *)&packet[ip_offset];
        u_int16_t arp_opcode = ntohs(arpp->ar_op);

        /* Updates interface broadcast domains, according to what is seen in
         * this ARP that glues together L2 and L3 */
        updateBroadcastDomains(vlan_id, ethernet->h_source, ethernet->h_dest,
                               ntohl(arpp->arp_spa), ntohl(arpp->arp_tpa));

        if (srcMac && dstMac && (!srcMac->isNull() || !dstMac->isNull())) {
          setSeenMacAddresses();
          srcMac->setSourceMac();

          if (arp_opcode == 0x1 /* ARP request */) {
            arp_requests++;
            srcMac->incSentArpRequests();
            dstMac->incRcvdArpRequests();
          } else if (arp_opcode == 0x2 /* ARP reply */) {
            arp_replies++;
            srcMac->incSentArpReplies();
            dstMac->incRcvdArpReplies();

            checkMacIPAssociation(true, arpp->arp_sha, arpp->arp_spa, srcMac);
            checkMacIPAssociation(true, arpp->arp_tha, arpp->arp_tpa, dstMac);
          }
        }
      }

      incStats(ingressPacket, h->ts.tv_sec, eth_type, NDPI_PROTOCOL_UNKNOWN,
               NDPI_PROTOCOL_CATEGORY_UNSPECIFIED, 0, len_on_wire, 1);
      break;
  }

dissect_packet_end:

  /* Live packet dump to mongoose */
  if (num_live_captures > 0) deliverLiveCapture(h, packet, *flow);

  return (pass_verdict);
}

/* **************************************************** */

void NetworkInterface::pollQueuedeCompanionEvents() {
  if (companionQueue) {
    ParsedFlow *dequeued = NULL;

    while (dequeueFlowFromCompanion(&dequeued)) {
      Flow *flow = NULL;
      bool src2dst_direction, new_flow;

      flow = getFlow(NULL /* srcMac */, NULL /* dstMac */, 0 /* vlan_id */,
                     0 /* observationPointId */, 0 /* private_flow_id */,
                     0 /* deviceIP */, 0 /* inIndex */, 1 /* outIndex */,
                     NULL /* ICMPinfo */, &dequeued->src_ip, &dequeued->dst_ip,
                     dequeued->src_port, dequeued->dst_port, dequeued->l4_proto,
                     &src2dst_direction, 0, 0, 0, &new_flow,
                     true /* create_if_missing */, NULL, NULL);

      if (flow) {
#if 0
	char buf[128];
	flow->print(buf, sizeof(buf));
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Updating flow process info: [new flow: %u][src2dst_direction: %u] %s",
				     new_flow ? 1 : 0,
				     src2dst_direction ? 1 : 0, buf);
#endif

        if (new_flow) flow->updateSeen();

        if (dequeued->getAdditionalFieldsJSON()) {
          flow->setJSONInfo(dequeued->getAdditionalFieldsJSON());
        }

        if (dequeued->external_alert) {
          /* Flow from SyslogParserInterface (Suricata) */
          enum json_tokener_error jerr = json_tokener_success;
          json_object *o =
              json_tokener_parse_verbose(dequeued->external_alert, &jerr);

          if (o) flow->setExternalAlert(o);
        }

        if (dequeued->process_info_set || dequeued->container_info_set ||
            dequeued->tcp_info_set) {
          /* Flow from ZMQParserInterface (nProbe Agent) */
          flow->setParsedeBPFInfo(dequeued, false /* TODO */);
        }
      }

      delete dequeued;
    }

    return;
  }
}

/* **************************************************** */

/* Dequeue alerted flows from checks (and enqueue to recipients) */
u_int64_t NetworkInterface::dequeueFlowAlerts(u_int budget) {
  u_int64_t num_done = 0;

  while (flowAlertsQueue->isNotEmpty()) {
    FlowAlert *alert = flowAlertsQueue->dequeue();
    Flow *f = alert->getFlow();

    /* Enqueue alert to recipients */
    f->enqueueAlertToRecipients(alert);

#if DEBUG_FLOW_CHECKS
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dequeued flow alert");
#endif

    /*
      Now that the job is done, the reference counter to the flow can be
      decreased.
    */
    f->decUses();

    num_done++;

    if (budget > 0 /* Budget requested */
        && num_done >= budget /* Budget exceeded */)
      break;
  }

  return num_done;
}

/* **************************************************** */

/* Same as above but for hosts */
u_int64_t NetworkInterface::dequeueHostAlerts(u_int budget) {
  u_int64_t num_done = 0;

  while (hostAlertsQueue->isNotEmpty()) {
    HostAlertReleasedPair alert_info = hostAlertsQueue->dequeue();
    HostAlert *alert = alert_info.first;
    bool released = alert_info.second;
    Host *h = alert->getHost();

    /* Enqueue alert to recipients */
    h->enqueueAlertToRecipients(alert, released);

#if DEBUG_HOST_CHECKS
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dequeued host alert");
#endif

    /*
      Now that the job is done, the reference counter to the host can be
      decreased.
    */
    h->decUses();

    num_done++;

    if (budget > 0 /* Budget requested */
        && num_done >= budget /* Budget exceeded */)
      break;
  }

  return num_done;
}

/* **************************************************** */

u_int64_t NetworkInterface::dequeueFlowAlertsFromChecks(u_int budget) {
  u_int64_t num_done;

  num_done = dequeueFlowAlerts(budget);

#if DEBUG_FLOW_CHECKS
  if (num_done > 0)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dequeued flows total [%u]",
                                 num_done);
#endif

  return num_done;
}

/* **************************************************** */

u_int64_t NetworkInterface::dequeueHostAlertsFromChecks(u_int budget) {
  u_int64_t num_done;

  num_done = dequeueHostAlerts(budget);

#if DEBUG_HOST_CHECKS
  if (num_done > 0)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dequeued hosts total [%u]",
                                 num_done);
#endif

  return num_done;
}

/* **************************************************** */

void NetworkInterface::incNumQueueDroppedFlows(u_int32_t num) {
  /*
    For viewed interface, the dumper database is the one belonging to the
    overlying view interface.
  */
  DB *dumper = isViewed() ? viewedBy()->getDB() : getDB();

  if (dumper) dumper->incNumQueueDroppedFlows(num);
};

/* **************************************************** */

/*
  Dequeues flows enqueued for dump and perform the actual dump. A budget can be
  specified for idle and active flows. Specify a budget of 0 to indicate an
  unlimited budget.

  NOTE: in case of view interfaces, this method is called sequentially by the
  view interface on all the viewed interfaces.

  This function is called from a dedicated thread, only spawned when flow dump
  is enabled with -F.
*/
u_int64_t NetworkInterface::dequeueFlowsForDump(u_int idle_flows_budget,
                                                u_int active_flows_budget) {
  /*
    For viewed interface, the dumper database is the one belonging to the
    overlying view interface.
  */
  DB *dumper = isViewed() ? viewedBy()->getDB() : getDB();
  u_int64_t idle_flows_done = 0, active_flows_done = 0;
  time_t when = time(NULL);

#ifndef HAVE_NEDGE
  if (ntop->get_export_interface() == NULL)
#endif
    if (dumper == NULL) {
      ntop->getTrace()->traceEvent(
          TRACE_INFO, "WARNING: Something is broken with flow dump");
      return (0);
    }

  /*
    Process high-priority idle flows (they're high priority as an idle flow not
    dumped is lost)
  */
  while (idleFlowsToDump->isNotEmpty()) {
    Flow *f = idleFlowsToDump->dequeue();
    char *json = NULL;
    bool rc = true;

    f->update_partial_traffic_stats_db_dump(); /* Checkpoint flow traffic
                                                  counters for the dump */

    /* Prepare the JSON - if requested */
    if (flows_dump_json) {
      json = f->serialize(flows_dump_json_use_labels);

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", json);
    }

#ifndef HAVE_NEDGE
    if (ntop->get_export_interface() && (json != NULL))
      ntop->get_export_interface()->export_data(json);
#endif

    if (dumper != NULL) {
      if (f->get_partial_bytes()) /* Make sure data is not at zero */
        rc = dumper->dumpFlow(when, f, json); /* Finally dump this flow */
    }

    if (json) free(json);

#if DEBUG_FLOW_DUMP
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dumped idle flow");
#endif
    if (dumper && (!rc)) incDBNumDroppedFlows(dumper);

    f->decUses(); /* Job has been done, decrease the reference counter */
    f->set_dump_done();
    // delete f;
    idle_flows_done++;

    if (idle_flows_budget > 0 /* Budget requested */
        && idle_flows_done >= idle_flows_budget /* Budget exceeded */)
      break;
  }

  if (dumper) {
    /*
      Process low-priority active flows (they're low priority there can still be
      chances of dumping active flows later)
    */
    while (activeFlowsToDump->isNotEmpty()) {
      Flow *f = activeFlowsToDump->dequeue();
      char *json = NULL;
      bool rc = true;

      f->update_partial_traffic_stats_db_dump(); /* Checkpoint flow traffic
                                                    counters for the dump */

      /* Prepare the JSON - if requested */
      if (flows_dump_json) {
        json = f->serialize(flows_dump_json_use_labels);

        // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s", json);
      }

      if (f->get_partial_bytes()) /* Make sure data is not at zero */
        rc = dumper->dumpFlow(when, f, json); /* Finally dump this flow */

      if (json) free(json);

#if DEBUG_FLOW_DUMP
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dumped active flow");
#endif
      if (!rc) incDBNumDroppedFlows(dumper);
      f->decUses(); /* Job has been done, decrease the reference counter */
      f->set_dump_done();
      active_flows_done++;
      if (active_flows_budget > 0 /* Budget requested */
          && active_flows_done >= active_flows_budget /* Budget exceeded */)
        break;
    }
  }

  /*
    Wait until there's some work to do.
    Don't wait for viewed interfaces to prevent one viewed interface to block
    all the other interfaces. For viewed interfaces, this method is called
    sequentially in ViewInterface::dumpFlowLoop
  */
  u_int64_t num_done = idle_flows_done + active_flows_done;

#ifndef WIN32
  if (!isViewed() && num_done == 0) {
    /*
      Do a timedwait to avoid blocking indefinitely. Failing to do this, for
      interfaces with no traffic, would cause the calling thread to wait and
      ignore shutdown.
    */
    struct timespec dump_wait_expire;

    dump_wait_expire.tv_sec = time(NULL) + 2;
    dump_wait_expire.tv_nsec = 0;

    dump_condition.timedWait(&dump_wait_expire);
  }
#endif

#ifdef NTOPNG_PRO
  /* Flush possibly pending flows (avoids interfaces with almost no traffic
     to have their flows waiting in dump queues for too long) */
  // flushFlowDump();
#endif

  if (dumper) dumper->checkIdle(when);

  return (num_done);
}

/* **************************************************** */

void NetworkInterface::flowAlertsDequeueLoop() {
  u_int64_t n;
  char buf[16];

  snprintf(buf, sizeof(buf), "ntopng-%d-fchek", get_id());
  Utils::setThreadName(buf);

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Started flow user script hooks loop on interface %s [id: %u]...",
      get_description(), get_id());

  /* Wait until it starts up */
  while (!isRunning()) {
    /* Control-C during startup */
    if (ntop->getGlobals()->isShutdownRequested()) return;

    _usleep(10000);
  }

  /* Now operational */
  while (!isShuttingDown()) {
    /*
      Dequeue flows for dump.
    */
    n = dequeueFlowAlertsFromChecks(32 /* budget */);

    if (n == 0) {
      /* No flow was dequeued. Let's wait. */
#ifdef WIN32
      /*
        If windows, sleep if nothing was done during the previous cycle.
      */
      _usleep(10000);
#else
      /*
        On non-windows, signal/waits are implemented to throttle the speed
        Wait for at most 1-2s. Cannot wait indefinitely
        as we must ensure purgeQueuedIdleFlows() gets executed,
        and also to exit when it's time to shutdown.
      */
      struct timespec hooks_wait_expire;

      hooks_wait_expire.tv_sec = time(NULL) + 2;
      hooks_wait_expire.tv_nsec = 0;

      flow_checks_condvar.timedWait(&hooks_wait_expire);
#endif
    }
  }

  /* Make sure all alerts have been dequeued and processed */
  dequeueFlowAlertsFromChecks(0 /* unlimited budget */);

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL, "Flow alerts dump thread terminated for %s", get_name());
}

/* **************************************************** */

void NetworkInterface::hostAlertsDequeueLoop() {
  u_int64_t n;
  char buf[16];

  snprintf(buf, sizeof(buf), "ntopng-%d-hcheck", get_id());
  Utils::setThreadName(buf);

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Started host user script hooks loop on interface %s [id: %u]...",
      get_description(), get_id());

  /* Wait until it starts up */
  while (!isRunning()) {
    /* Control-C during startup */
    if (ntop->getGlobals()->isShutdownRequested()) return;

    _usleep(10000);
  }

  /* Now operational */
  while (!isShuttingDown()) {
    /*
      Dequeue hosts for dump.
    */
    n = dequeueHostAlertsFromChecks(32 /* budget */);

    if (n == 0) {
      /*
        No host was dequeued. Let's wait.
      */
#ifdef WIN32
      /*
        If windows, sleep if nothing was done during the previous cycle.
        On non-windows, there's nothing do to as signal/waits are implemented to
        throttle the speed
      */
      _usleep(10000);
#else
      /*
        Wait for at most 1-2s. Cannot wait indefinitely
        as we must ensure purgeQueuedIdleHosts() gets executed,
        and also to exit when it's time to shutdown.
      */
      struct timespec hooks_wait_expire;

      hooks_wait_expire.tv_sec = time(NULL) + 2;
      hooks_wait_expire.tv_nsec = 0;

      host_checks_condvar.timedWait(&hooks_wait_expire);
#endif
    }
  }

  /* Make sure all alerts have been dequeued and processed */
  dequeueHostAlertsFromChecks(0 /* unlimited budged */);

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL, "Host alerts dump thread terminated for %s", get_name());
}

/* **************************************************** */

void NetworkInterface::dumpFlowLoop() {
  char buf[16];

  snprintf(buf, sizeof(buf), "ntopng-%d-fdump", get_id());
  Utils::setThreadName(buf);

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL, "Started flow dump loop on interface %s [id: %u]...",
      get_description(), get_id());

  /* Wait until it starts up */
  while (!isRunning()) {
    /* Control-C during startup */
    if (ntop->getGlobals()->isShutdownRequested()) return;

    _usleep(10000);
  }

  /* Now operational */
  while (!isShuttingDown()) {
    /*
      Dequeue flows for dump. Use an unlimited budget for idle flows as they're
      high-priority and thus we want to keep processing them if they're in the
      queue.
    */
    u_int64_t n = dequeueFlowsForDump(
        0 /* Unlimited budget for idle flows */,
        MAX_ACTIVE_FLOW_QUEUE_LEN /* Limited budged for active flows */);

    if (n == 0) {
#ifdef WIN32
      _usleep(10000);
#endif
    }
  }

  /* Make sure all flows have been dumper */
  dequeueFlowsForDump(0 /* Unlimited budget for idle flows */,
                      0 /* Unlimited budged for active flows */);

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "Flow dump thread completed for %s", get_name());
}

/* **************************************************** */

static void *flowChecksLoop(void *ptr) {
  NetworkInterface *_if = (NetworkInterface *)ptr;

  _if->flowAlertsDequeueLoop();

  return (NULL);
}

/* **************************************************** */

static void *hostChecksLoop(void *ptr) {
  NetworkInterface *_if = (NetworkInterface *)ptr;

  _if->hostAlertsDequeueLoop();

  return (NULL);
}

/* **************************************************** */

static void *flowDumper(void *ptr) {
  NetworkInterface *_if = (NetworkInterface *)ptr;

  _if->dumpFlowLoop();
  return (NULL);
}

/* **************************************************** */

void NetworkInterface::startFlowDumping() {
  idleFlowsToDump = new (std::nothrow)
      SPSCQueue<Flow *>(MAX_IDLE_FLOW_QUEUE_LEN, "idleFlowsToDump");
  activeFlowsToDump = new (std::nothrow)
      SPSCQueue<Flow *>(MAX_ACTIVE_FLOW_QUEUE_LEN, "activeFlowsToDump");

  /*
    Precalculate constants that won't change during the execution.
  */
  if (flows_dump_json) {
    /*
      Use labels for JSON fields when exporting to ElasticSearch or LogStash.
    */
    flows_dump_json_use_labels =
        ntop->getPrefs()->do_dump_flows_on_es() ||
        ntop->getPrefs()->do_dump_flows_on_syslog() ||
        ntop->getPrefs()->do_dump_flows_on_clickhouse();
  }

  if (!isViewed()) { /* Do not spawn the dumper thread for viewed interfaces -
                        it's the view interface that has the dumper thread */
    if (idleFlowsToDump && activeFlowsToDump) {
      pthread_create(&flowDumpLoop, NULL, flowDumper, (void *)this);
      flowDumpLoopCreated = true;
    } else {
      if (idleFlowsToDump) {
        delete idleFlowsToDump;
        idleFlowsToDump = NULL;
      }
      if (activeFlowsToDump) {
        delete activeFlowsToDump;
        activeFlowsToDump = NULL;
      }
    }
  }
}

/* **************************************************** */

void NetworkInterface::startPacketPolling() {
  if (pollLoopCreated) {
    if ((cpu_affinity != -1) && (ntop->getNumCPUs() > 1)) {
      if (Utils::setThreadAffinity(pollLoop, cpu_affinity))
        ntop->getTrace()->traceEvent(
            TRACE_WARNING, "Couldn't set affinity of interface %s to core %d",
            get_description(), cpu_affinity);
      else
        ntop->getTrace()->traceEvent(
            TRACE_NORMAL, "Setting affinity of interface %s to core %d",
            get_description(), cpu_affinity);
    }

#ifdef __linux__
    char buf[16];
    snprintf(buf, sizeof(buf), "ntopng-%d-pkt", get_id());
    pthread_setname_np(pollLoop, buf);
#endif
  }

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL, "Started packet polling on interface %s [id: %u]...",
      get_description(), get_id());

  running = true;
}

/* **************************************************** */

void NetworkInterface::shutdown() {
  void *res;

  if (running) {
    running = false;

    if (pollLoopCreated) pthread_join(pollLoop, &res);

    /* purgeIdle one last time to make sure all entries will be marked as idle
     */
    purgeIdle(time(NULL), true, true);

    /* stop host/flow alerts dump threads */
    shutting_down = true;

    /* Shut down dump threads (after purging flows/hosts to flush engaged
     * alerts to the database) */
    if (flowDumpLoopCreated) pthread_join(flowDumpLoop, &res);
    if (flowAlertsDequeueLoopCreated) pthread_join(flowChecksLoop, &res);
    if (hostAlertsDequeueLoopCreated) pthread_join(hostChecksLoop, &res);

    if (db) db->flush();
  }
}

/* **************************************************** */

void NetworkInterface::cleanup() {
  if (this != ntop->getSystemInterface())
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Cleanup interface %s",
                                 get_description());

  next_idle_flow_purge = next_idle_host_purge = 0;
  cpu_affinity = -1, has_vlan_packets = false, has_ebpf_events = false,
  has_mac_addresses = false;
  has_seen_dhcp_addresses = false;
  running = false, inline_interface = false;
  has_seen_containers = false, has_seen_pods = false;
  has_external_alerts = false;

  getStats()->cleanup();
  if (flows_hash) flows_hash->cleanup();
  if (hosts_hash) hosts_hash->cleanup();
  if (ases_hash) ases_hash->cleanup();
  if (obs_hash) obs_hash->cleanup();
  if (oses_hash) oses_hash->cleanup();
  if (countries_hash) countries_hash->cleanup();
  if (vlans_hash) vlans_hash->cleanup();
  if (macs_hash) macs_hash->cleanup();
}

/* **************************************************** */

/*
  Used by ViewInterface to find hosts bound to flows
  in the ViewInterface
 */
void NetworkInterface::findFlowHosts(u_int16_t vlan_id,
                                     u_int16_t observation_domain_id,
                                     u_int32_t private_flow_id, Mac *src_mac,
                                     IpAddress *_src_ip, Host **src,
                                     Mac *dst_mac, IpAddress *_dst_ip,
                                     Host **dst) {
  if (!hosts_hash) {
    *src = *dst = NULL;
    return;
  }

  INTERFACE_PROFILING_SECTION_ENTER(
      "NetworkInterface::findFlowHosts: hosts_hash->get", 3);
  /* Do not look on sub interfaces, Flows are always created in the same
   * interface of its hosts */
  (*src) = hosts_hash->get(vlan_id, _src_ip, src_mac, true /* Inline call */,
                           observation_domain_id);
  INTERFACE_PROFILING_SECTION_EXIT(3);

  if ((*src) == NULL) {
    if (!hosts_hash->hasEmptyRoom()) {
      *src = *dst = NULL;
      has_too_many_hosts = true;
      return;
    }

    if (_src_ip &&
        (_src_ip->isLocalHost() || _src_ip->isLocalInterfaceAddress())) {
      INTERFACE_PROFILING_SECTION_ENTER(
          "NetworkInterface::findFlowHosts: new LocalHost", 4);
      (*src) = new (std::nothrow)
          LocalHost(this, src_mac, vlan_id, observation_domain_id, _src_ip);
      INTERFACE_PROFILING_SECTION_EXIT(4);
    } else {
      INTERFACE_PROFILING_SECTION_ENTER(
          "NetworkInterface::findFlowHosts: new RemoteHost", 5);
      (*src) = new (std::nothrow)
          RemoteHost(this, src_mac, vlan_id, observation_domain_id, _src_ip);
      INTERFACE_PROFILING_SECTION_EXIT(5);
    }

    if (*src) {
      INTERFACE_PROFILING_SECTION_ENTER(
          "NetworkInterface::findFlowHosts: hosts_hash->add", 6);
      bool add_res = hosts_hash->add(
          *src, false /* Don't lock, we're inline with the purgeIdle */);
      INTERFACE_PROFILING_SECTION_EXIT(6);

      if (!add_res) {
        // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in
        // interface %s", ifname);
        delete *src;
        *src = *dst = NULL;
        has_too_many_hosts = true;
        return;
      }

      has_too_many_hosts = false;
    }
  }

  /* ***************************** */

  INTERFACE_PROFILING_SECTION_ENTER(
      "NetworkInterface::findFlowHosts: hosts_hash->get", 3);
  (*dst) = hosts_hash->get(vlan_id, _dst_ip, dst_mac, true /* Inline call */,
                           observation_domain_id);
  INTERFACE_PROFILING_SECTION_EXIT(3);

  if ((*dst) == NULL) {
    if (!hosts_hash->hasEmptyRoom()) {
      *dst = NULL;
      has_too_many_hosts = true;
      return;
    }

    if (_dst_ip &&
        (_dst_ip->isLocalHost() || _dst_ip->isLocalInterfaceAddress())) {
      INTERFACE_PROFILING_SECTION_ENTER(
          "NetworkInterface::findFlowHosts: new LocalHost", 4);
      (*dst) = new (std::nothrow)
          LocalHost(this, dst_mac, vlan_id, observation_domain_id, _dst_ip);
      INTERFACE_PROFILING_SECTION_EXIT(4);
    } else {
      INTERFACE_PROFILING_SECTION_ENTER(
          "NetworkInterface::findFlowHosts: new RemoteHost", 5);
      (*dst) = new (std::nothrow)
          RemoteHost(this, dst_mac, vlan_id, observation_domain_id, _dst_ip);
      INTERFACE_PROFILING_SECTION_EXIT(5);
    }

    if (*dst) {
      INTERFACE_PROFILING_SECTION_ENTER(
          "NetworkInterface::findFlowHosts: hosts_hash->add", 6);
      bool add_res = hosts_hash->add(
          *dst, false /* Don't lock, we're inline with the purgeIdle */);
      INTERFACE_PROFILING_SECTION_EXIT(6);

      if (!add_res) {
        // ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many hosts in
        // interface %s", ifname);
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

bool NetworkInterface::viewEnqueue(time_t t, Flow *f) {
  /*
    Enqueue is only performed when the interface is 'viewed'.
    Enqueue needs to know the viewed interface id.
  */
  if (isViewed()) return viewedBy()->viewEnqueue(t, f, getViewedId());

  return false;
}

/* **************************************************** */

bool NetworkInterface::checkPeriodicStatsUpdateTime(const struct timeval *tv) {
  float diff = Utils::msTimevalDiff(tv, &last_periodic_stats_update) / 1000;

  if (diff < 0 /* Need a reset */
      || diff >= periodicStatsUpdateFrequency() || read_from_pcap_dump_done()) {
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

struct timeval NetworkInterface::periodicUpdateInitTime() const {
  struct timeval tv;

  if (getIfType() != interface_type_PCAP_DUMP)
    gettimeofday(&tv, NULL);
  else
    tv.tv_sec = last_pkt_rcvd, tv.tv_usec = 0;

  return tv;
}

/* **************************************************** */

u_int32_t NetworkInterface::getFlowMaxIdle() {
  return (ntop->getPrefs()->get_pkt_ifaces_flow_max_idle());
}

/* **************************************************** */

void NetworkInterface::periodicStatsUpdate() {
#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[%s][%s]", __FUNCTION__, get_name());
#endif
  struct timeval tv = periodicUpdateInitTime();

  if (db) db->updateStats(&tv);

  checkReloadHostsBroadcastDomain();

  if (!checkPeriodicStatsUpdateTime(&tv))
    return; /* Not yet the time to perform an update */

#ifdef NTOPNG_PRO
  if (getHostPools()) getHostPools()->checkPoolsStatsReset();
#endif

  updatePacketsStats();

  bytes_thpt.updateStats(&tv, getNumBytes());
  pkts_thpt.updateStats(&tv, getNumPackets());
  ethStats.updateStats(&tv);

  download_stats->addPoint((u_int32_t)ethStats.getIngressBytesThpt() / 1000);
  upload_stats->addPoint((u_int32_t)ethStats.getEgressBytesThpt() /
                         1000); /* Use KB instead of Bytes */

  if (ndpiStats) ndpiStats->updateStats(&tv);

  if (ntop->getGlobals()->isShutdownRequested()) return;

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "MySQL dump took %d seconds",
                               time(NULL) - tdebug.tv_sec);
  gettimeofday(&tdebug, NULL);
#endif

  if (host_pools) host_pools->updateStats(&tv);

  for (u_int16_t network_id = 0; network_id < ntop->getNumLocalNetworks();
       network_id++) {
    if (NetworkStats *ns = getNetworkStats(network_id)) ns->updateStats(&tv);
  }

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "Timeseries update took %d seconds",
                               time(NULL) - tdebug.tv_sec);
  gettimeofday(&tdebug, NULL);
#endif

#ifdef PERIODIC_STATS_UPDATE_DEBUG_TIMING
  gettimeofday(&tdebug, NULL);
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Stats update done [took: %d]",
                               tdebug.tv_sec - tdebug_init.tv_sec);
#endif

#ifdef NTOPNG_PRO
  if (tv.tv_sec >= nextMinPeriodicUpdate) {
    /* 5 minute periodic update */
    if (sMap) sMap->purgeIdle(nextMinPeriodicUpdate);
    if (pMap) pMap->purgeIdle(nextMinPeriodicUpdate);

    updateBehaviorStats(&tv);

    nextMinPeriodicUpdate = tv.tv_sec + IFACE_BEHAVIOR_REFRESH;
  }
#endif
}

/* *************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::updateBehaviorStats(const struct timeval *tv) {
  /* 5 Min Update */
  /* Traffic behavior stats update, currently score, traffic rx and tx */
  score_behavior->updateBehavior(this, score_as_cli + score_as_srv, "", false);

  traffic_tx_behavior->updateBehavior(this, ethStats.getNumEgressBytes(), "",
                                      false);

  traffic_rx_behavior->updateBehavior(this, ethStats.getNumIngressBytes(), "",
                                      false);
}

#endif

/* **************************************************** */

/*
  Frees the memory (destructors) of all idle hash table entries except flows
*/
u_int64_t NetworkInterface::purgeQueuedIdleEntries() {
  u_int64_t num_purged = 0;

#if 0
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Updating hash tables [%s]", get_name());
#endif
  GenericHash *ghs[] = {hosts_hash,     flows_hash, ases_hash, oses_hash,
                        countries_hash, vlans_hash, macs_hash, obs_hash};

  /* Delete all idle entries */
  for (u_int i = 0; i < sizeof(ghs) / sizeof(ghs[0]); i++) {
    if (ghs[i]) num_purged += ghs[i]->purgeQueuedIdleEntries();
  }

  return num_purged;
}

/* **************************************************** */

struct update_host_pool_l7policy {
  bool update_pool_id;
  bool update_l7policy;
};

static bool update_host_host_pool_l7policy(GenericHashEntry *node,
                                           void *user_data, bool *matched) {
  Host *h = (Host *)node;
  update_host_pool_l7policy *up = (update_host_pool_l7policy *)user_data;
#ifdef HOST_POOLS_DEBUG
  char buf[128];
  u_int16_t cur_pool_id = h->get_host_pool();
#endif

  *matched = true;

  if (up->update_pool_id)
    h->updateHostPool(false /* Not inline with traffic processing */);

#ifdef NTOPNG_PRO
  if (up->update_l7policy) h->resetBlockedTrafficStatus();
#endif

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Going to refresh pool for %s "
      "[refresh pool id: %i] "
      "[refresh l7policy: %i] "
      "[host pool id before refresh: %i] "
      "[host pool id after refresh: %i] ",
      h->get_ip()->print(buf, sizeof(buf)), up->update_pool_id ? 1 : 0,
      up->update_l7policy ? 1 : 0, cur_pool_id, h->get_host_pool());
#endif

  return (false); /* false = keep on walking */
}

static bool update_l2_device_host_pool(GenericHashEntry *node, void *user_data,
                                       bool *matched) {
  Mac *m = (Mac *)node;

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
                               cur_pool_id, m->get_host_pool());
#endif

  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::refreshHostPools() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  struct update_host_pool_l7policy update_host;
  update_host.update_pool_id = true;
  update_host.update_l7policy = false;

#ifdef NTOPNG_PRO
  if (is_bridge_interface() && getL7Policer()) {
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

  if (hosts_hash) {
    begin_slot = 0;
    walker(&begin_slot, walk_all, walker_hosts, update_host_host_pool_l7policy,
           &update_host);
  }

  if (macs_hash) {
    begin_slot = 0;
    walker(&begin_slot, walk_all, walker_macs, update_l2_device_host_pool,
           NULL);
  }

#ifdef HAVE_NEDGE
  if (update_host.update_l7policy) updateFlowsL7Policy();
#endif
}

/* **************************************************** */

static bool count_open_server_ports(GenericHashEntry *node, void *user_data,
                                    bool *matched) {
  Host *h = (Host *)node;
  std::unordered_map<u_int16_t /* port */, u_int32_t /* count */> *count =
      (std::unordered_map<u_int16_t, u_int32_t> *)user_data;
  std::unordered_map<u_int16_t, ndpi_protocol>::iterator it;

  for (u_int i = 0; i < 2; i++) {
    std::unordered_map<u_int16_t, ndpi_protocol> *ports;

    if (i == 0)
      ports = h->getServerPorts(true);
    else
      ports = h->getServerPorts(false);

    if (ports) {
      for (it = ports->begin(); it != ports->end(); ++it) {
        u_int16_t port = it->first;
        std::unordered_map<u_int16_t, u_int32_t>::iterator it1 =
            count->find(port);

        if (it1 == count->end())
          (*count)[port] = 1;
        else
          (*count)[port] = (*count)[port] + 1;
      }
    }
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::localHostsServerPorts(lua_State *vm) {
  u_int32_t begin_slot = 0;
  std::unordered_map<u_int16_t /* port */, u_int32_t /* count */> count;
  std::unordered_map<u_int16_t, u_int32_t>::iterator it;

  walker(&begin_slot, true /* walk_all */, walker_hosts,
         count_open_server_ports, &count);

  lua_newtable(vm);

  for (it = count.begin(); it != count.end(); ++it) {
    char port[32];

    snprintf(port, sizeof(port), "%u", it->first);
    lua_push_uint32_table_entry(vm, port, it->second);
  }
}

/* **************************************************** */

#ifdef HAVE_NEDGE

static bool update_flow_l7_policy(GenericHashEntry *node, void *user_data,
                                  bool *matched) {
  Flow *f = (Flow *)node;

  *matched = true;
  f->updateFlowShapers();
  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::updateHostsL7Policy(u_int16_t host_pool_id) {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (isView()) return;

  struct update_host_pool_l7policy update_host;
  update_host.update_pool_id = false;
  update_host.update_l7policy = true;

  /* Pool id didn't change here so there's no need to walk on the macs
     as policies are set on the hosts */
  if (hosts_hash)
    walker(&begin_slot, walk_all, walker_hosts, update_host_host_pool_l7policy,
           &update_host);
}

/* **************************************************** */

void NetworkInterface::updateFlowsL7Policy() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (isView()) return;

  if (flows_hash)
    walker(&begin_slot, walk_all, walker_flows, update_flow_l7_policy, NULL);
}

/* **************************************************** */

struct resetPoolsStatsData {
  struct tm *now;
  u_int16_t pool_filter;
};

static bool flow_recheck_quota_walker(GenericHashEntry *flow, void *user_data,
                                      bool *matched) {
  Flow *f = (Flow *)flow;
  struct tm *now = ((struct resetPoolsStatsData *)user_data)->now;

  *matched = true;
  f->recheckQuota(now);

  return (false); /* false = keep on walking */
}

static bool host_reset_quotas(GenericHashEntry *host, void *user_data,
                              bool *matched) {
  Host *h = (Host *)host;
  u_int16_t pool_filter =
      ((struct resetPoolsStatsData *)user_data)->pool_filter;

  if ((pool_filter == (u_int16_t)-1) || (h->get_host_pool() == pool_filter)) {
    *matched = true;
    h->resetQuotaStats();
    h->resetBlockedTrafficStatus();
  }

  return (false); /* false = keep on walking */
}

#endif

/* **************************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::resetPoolsStats(u_int16_t pool_filter) {
  struct tm now;
  time_t t_now = time(NULL);
  localtime_r(&t_now, &now);

  if (host_pools) {
    host_pools->resetPoolsStats(pool_filter);

#ifdef HAVE_NEDGE
    u_int32_t begin_slot = 0;
    bool walk_all = true;
    struct resetPoolsStatsData data;

    data.pool_filter = pool_filter;
    data.now = &now;

    walker(&begin_slot, walk_all, walker_hosts, host_reset_quotas, &data);
    begin_slot = 0;
    walker(&begin_slot, walk_all, walker_flows, flow_recheck_quota_walker,
           &data);
#endif
  }
}

#endif

/* **************************************************** */

struct host_find_info {
  char *host_to_find;
  u_int16_t vlan_id;
  u_int16_t observationPointId;
  Host *h;
};

/* **************************************************** */

struct as_find_info {
  u_int32_t asn;
  AutonomousSystem *as;
};

/* **************************************************** */

struct obs_point_find_info {
  u_int32_t obs_point_id;
  ObservationPoint *obs_point;
};

/* **************************************************** */

struct os_find_info {
  OSType os_id;
  OperatingSystem *os;
};

/* **************************************************** */

struct vlan_find_info {
  u_int16_t vlan_id;
  VLAN *vl;
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

static bool find_host_by_name(GenericHashEntry *h, void *user_data,
                              bool *matched) {
  struct host_find_info *info = (struct host_find_info *)user_data;
  Host *host = (Host *)h;
  char ip_buf[32], name_buf[96];
  name_buf[0] = '\0';

#ifdef DEBUG
  char buf[64];
  ntop->getTrace()->traceEvent(
      TRACE_WARNING, "[%s][%s][%s]",
      host->get_ip() ? host->get_ip()->print(buf, sizeof(buf)) : "",
      host->get_name(), info->host_to_find);
#endif

  if ((info->h == NULL) &&
      (host->get_observation_point_id() == info->observationPointId) &&
      (host->get_vlan_id() == info->vlan_id)) {
    host->get_name(name_buf, sizeof(name_buf), false);

    if (strlen(name_buf) == 0 && host->get_ip()) {
      char *ipaddr = host->get_ip()->print(ip_buf, sizeof(ip_buf));
      int rc = ntop->getRedis()->getAddress(
          ipaddr, name_buf, sizeof(name_buf),
          false /* Don't resolve it if not known */);

      if (rc == 0 /* found */ && strcmp(ipaddr, name_buf))
        host->setResolvedName(name_buf);
      else
        name_buf[0] = '\0';
    }

    if (!strcmp(name_buf, info->host_to_find)) {
      info->h = host;
      *matched = true;
      return (true); /* found */
    }
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool find_as_by_asn(GenericHashEntry *he, void *user_data,
                           bool *matched) {
  struct as_find_info *info = (struct as_find_info *)user_data;
  AutonomousSystem *as = (AutonomousSystem *)he;

  if ((info->as == NULL) && info->asn == as->get_asn()) {
    info->as = as;
    *matched = true;
    return (true); /* found */
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool find_obs_point_by_id(GenericHashEntry *he, void *user_data,
                                 bool *matched) {
  struct obs_point_find_info *info = (struct obs_point_find_info *)user_data;
  ObservationPoint *_obs_point = (ObservationPoint *)he;

  if ((info->obs_point == NULL) &&
      info->obs_point_id == _obs_point->getObsPoint()) {
    info->obs_point = _obs_point;
    *matched = true;
    return (true); /* found */
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool find_os(GenericHashEntry *he, void *user_data, bool *matched) {
  struct os_find_info *info = (struct os_find_info *)user_data;
  OperatingSystem *os = (OperatingSystem *)he;

  if ((info->os == NULL) && info->os_id == os->get_os_type()) {
    info->os = os;
    *matched = true;
    return (true); /* found */
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool find_country(GenericHashEntry *he, void *user_data, bool *matched) {
  struct country_find_info *info = (struct country_find_info *)user_data;
  Country *country = (Country *)he;

  if ((info->country == NULL) &&
      !strcmp(info->country_id, country->get_country_name())) {
    info->country = country;
    *matched = true;
    return (true); /* found */
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool find_vlan_by_vlan_id(GenericHashEntry *he, void *user_data,
                                 bool *matched) {
  struct vlan_find_info *info = (struct vlan_find_info *)user_data;
  VLAN *vl = (VLAN *)he;

  if ((info->vl == NULL) && info->vlan_id == vl->get_vlan_id()) {
    info->vl = vl;
    *matched = true;
    return (true); /* found */
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

/* Enqueues an host restore request on the interface. The checkHostsToRestore
 * function, in the datapath, will take care of restoring the host. */
bool NetworkInterface::restoreHost(char *host_ip, u_int16_t vlan_id) {
  char buf[64];
  bool rv;

  snprintf(buf, sizeof(buf), "%s@%u", host_ip, vlan_id);

  rv = hosts_to_restore->enqueue(buf);

  return (rv);
}

/* **************************************************** */

Host *NetworkInterface::getHostByIP(IpAddress *ip, u_int16_t vlan_id,
                                    u_int16_t observation_point_id,
                                    bool isInlineCall) {
  Host *h;

  h = hosts_hash ? hosts_hash->get(vlan_id, ip, NULL, isInlineCall,
                                   observation_point_id)
                 : NULL;

  return (h);
}

/* **************************************************** */

Host *NetworkInterface::getHost(char *host_ip, u_int16_t vlan_id,
                                u_int16_t observation_point_id,
                                bool isInlineCall) {
  struct in_addr a4;
  struct in6_addr a6;
  Host *h = NULL;

  if (!host_ip) return (NULL);

  /* Check if address is invalid */
  if ((inet_pton(AF_INET, (const char *)host_ip, &a4) == 0) &&
      (inet_pton(AF_INET6, (const char *)host_ip, &a6) == 0)) {
    /* Looks like a symbolic name */
    struct host_find_info info;
    u_int32_t begin_slot = 0;
    bool walk_all = true;

    memset(&info, 0, sizeof(info));
    info.host_to_find = host_ip, info.vlan_id = vlan_id;
    info.observationPointId = observation_point_id;
    walker(&begin_slot, walk_all, walker_hosts, find_host_by_name,
           (void *)&info);

    h = info.h;
  } else {
    IpAddress *ip = new (std::nothrow) IpAddress();

    if (ip) {
      ip->set(host_ip);

      h = getHostByIP(ip, vlan_id, isInlineCall, observation_point_id);

      delete ip;
    }
  }

  return (h);
}

/* **************************************************** */

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE

static bool update_flow_profile(GenericHashEntry *h, void *user_data,
                                bool *matched) {
  Flow *flow = (Flow *)h;

  flow->updateProfile();
  *matched = true;

  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::updateFlowProfiles() {
  if (isView()) return;

  if (ntop->getPro()->has_valid_license()) {
    FlowProfiles *newP;
    u_int32_t begin_slot = 0;
    bool walk_all = true;

    if (shadow_flow_profiles) {
      delete shadow_flow_profiles;
      shadow_flow_profiles = NULL;
    }

    flow_profiles->dumpCounters();
    shadow_flow_profiles = flow_profiles,
    newP = new (std::nothrow) FlowProfiles(id);

    newP->loadProfiles(); /* and reload */
    flow_profiles = newP; /* Overwrite the current profiles */

    if (flows_hash)
      walker(&begin_slot, walk_all, walker_flows, update_flow_profile, NULL);
  }
}

#endif
#endif

/* **************************************************** */

bool NetworkInterface::getHostInfo(lua_State *vm, AddressTree *allowed_hosts,
                                   char *host_ip, u_int16_t vlan_id) {
  Host *h;
  bool ret;

  h = findHostByIP(allowed_hosts, host_ip, vlan_id,
                   getLuaVMUservalue(vm, observationPointId));

  if (h) {
    h->lua(vm, allowed_hosts, true, true, true, false);
    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************************** */

bool NetworkInterface::getHostMinInfo(lua_State *vm, AddressTree *allowed_hosts,
                                      char *host_ip, u_int16_t vlan_id,
                                      bool only_ndpi_stats) {
  Host *h;
  bool ret;

  h = findHostByIP(allowed_hosts, host_ip, vlan_id,
                   getLuaVMUservalue(vm, observationPointId));

  if (h) {
    lua_newtable(vm);

    if (only_ndpi_stats)
      h->lua_get_ndpi_info(vm);
    else
      h->lua_get_min_info(vm);

    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************************** */

void NetworkInterface::checkReloadHostsBroadcastDomain() {
  time_t bcast_domains_last_update = bcast_domains->getLastUpdate();

  if (hosts_bcast_domain_last_update < bcast_domains_last_update)
    reload_hosts_bcast_domain = true,
    hosts_bcast_domain_last_update = bcast_domains_last_update;
  else if (reload_hosts_bcast_domain)
    reload_hosts_bcast_domain = false;
}

/* **************************************************** */

void NetworkInterface::checkPointHostTalker(lua_State *vm, char *host_ip,
                                            u_int16_t vlan_id) {
  Host *h;

  if (host_ip &&
      (h = getHost(host_ip, vlan_id, getLuaVMUservalue(vm, observationPointId),
                   false /* Not an inline call */)))
    h->checkpoint(vm);
  else
    lua_pushnil(vm);
}

/* **************************************************** */

Host *NetworkInterface::findHostByIP(AddressTree *allowed_hosts, char *host_ip,
                                     u_int16_t vlan_id,
                                     u_int16_t observationPointId) {
  Host *h = NULL;

  if (host_ip == NULL) return (NULL);

  h = getHost(host_ip, vlan_id, observationPointId,
              false /* Not an inline call */);

  if (h == NULL) return (NULL);

  if (allowed_hosts && !h->match(allowed_hosts)) return (NULL);

  return h;
}

/* **************************************************** */

struct flowHostRetrieveList {
  Flow *flow;
  /* Value */
  Host *hostValue;
  Mac *macValue;
  VLAN *vlanValue;
  AutonomousSystem *asValue;
  ObservationPoint *obsPointValue;
  OperatingSystem *osValue;
  Country *countryVal;
  u_int64_t numericValue;
  const char *stringValue;
  IpAddress *ipValue;
};

struct flowHostRetriever {
  /* Search criteria */
  AddressTree *allowed_hosts;
  Host *host, *talking_with_host, *server, *client;
  u_int16_t observationPointId;
  u_int8_t *mac, bridge_iface_idx;
  char *manufacturer;
  bool sourceMacsOnly, dhcpHostsOnly;
  time_t min_first_seen;
  char *country;
  char *flow_info;
  int ndpi_proto;           /* Not used in flow_search_walker */
  TrafficType traffic_type; /* Not used in flow_search_walker */
  sortField sorter;
  TcpFlowStateFilter tcp_flow_state_filter;
  LocationPolicy location;        /* Not used in flow_search_walker */
  u_int8_t ipVersionFilter;       /* Not used in flow_search_walker */
  bool filteredHosts;             /* Not used in flow_search_walker */
  bool blacklistedHosts;          /* Not used in flow_search_walker */
  bool anomalousOnly;             /* Not used in flow_search_walker */
  bool dhcpOnly;                  /* Not used in flow_search_walker */
  const AddressTree *cidr_filter; /* Not used in flow_search_walker */
  u_int16_t vlan_id;
  OSType osFilter;
  u_int32_t device_ip;
  u_int32_t asnFilter;
  u_int32_t uidFilter;
  u_int32_t pidFilter;
  int16_t networkFilter;
  u_int16_t poolFilter;
  u_int8_t devtypeFilter;
  u_int8_t locationFilter;

  /* Return values */
  u_int32_t maxNumEntries, actNumEntries;
  u_int64_t totBytesSent, totBytesRcvd, totThpt;
  struct flowHostRetrieveList *elems;

  bool only_traffic_stats;
  /* Used by getActiveFlowsStats */
  nDPIStats *ndpi_stats;
  FlowStats *stats;

  /* Paginator */
  Paginator *pag;
};

/* **************************************************** */

static bool flow_matches(Flow *f, struct flowHostRetriever *retriever) {
  int ndpi_proto_master_proto, ndpi_proto_app_proto, ndpi_cat;
  u_int16_t port;
  int16_t local_network_id;
  u_int16_t vlan_id = 0;
  u_int16_t cli_pool, srv_pool, pool_filter;
  AlertLevelGroup flow_status_severity_filter = alert_level_group_none;
  ndpi_patricia_node_t *srv_target_node = NULL, *cli_target_node = NULL;
  IpAddress *cli_ip = (IpAddress *)f->get_srv_ip_addr();
  IpAddress *srv_ip = (IpAddress *)f->get_cli_ip_addr();
  u_int16_t alert_type_filter;
  u_int8_t ip_version;
  u_int8_t l4_protocol;
  u_int8_t *mac_filter;
  LocationPolicy client_policy;
  LocationPolicy server_policy;
  TcpFlowStateFilter tcp_flow_state_filter;
  bool unicast, unidirectional, alerted_flows, periodic_flows,
      cli_pool_found = false, srv_pool_found = false;
  u_int32_t asn_filter;
  char *username_filter;
  char *pidname_filter;
  u_int32_t deviceIP = 0;
  u_int32_t inIndex, outIndex;
  u_int8_t icmp_type, icmp_code, dscp_filter;
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  char *traffic_profile_filter;
#endif
#endif
  char *container_filter, *pod_filter;
#ifdef HAVE_NEDGE
  bool filtered_flows;
#endif

  if (f && (!f->idle())) {
    if (f->get_observation_point_id() != retriever->observationPointId) {
#if 0
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Skipping VLAN: %u-%u / observationPointId: %u-%u",
				   f->get_vlan_id(), vlan_id,
				   f->get_observation_point_id(), retriever->observationPointId);
#endif
      return (false);
    }

    if (retriever->server) {
      if (!f->getInterface()->isViewed()) {
        if (retriever->server != f->get_srv_host()) {
          return (false);
        }
      } else {
        if (!(retriever->server->get_ip()->equal(f->get_srv_ip_addr()) &&
              retriever->server->get_vlan_id() == f->get_vlan_id()))
          return (false);
      }
    }

    if (retriever->talking_with_host) {
      if (!f->getInterface()->isViewed()) {
        if (retriever->talking_with_host != f->get_cli_host() &&
            retriever->talking_with_host != f->get_srv_host()) {
          return (false);
        }
      } else {
        if (!(retriever->talking_with_host->get_ip()->equal(
                  f->get_cli_ip_addr()) &&
              retriever->talking_with_host->get_vlan_id() ==
                  f->get_vlan_id()) &&
            !(retriever->talking_with_host->get_ip()->equal(
                  f->get_srv_ip_addr()) &&
              retriever->talking_with_host->get_vlan_id() == f->get_vlan_id()))
          return (false);
      }
    }

    if (retriever->client) {
      if (!f->getInterface()->isViewed()) {
        if (retriever->client != f->get_cli_host()) {
          return (false);
        }
      } else {
        if (!(retriever->client->get_ip()->equal(f->get_cli_ip_addr()) &&
              retriever->client->get_vlan_id() == f->get_vlan_id()))
          return (false);
      }
    }

    if (retriever->flow_info) {
      char buf[64];
      if (strcmp(retriever->flow_info, f->getFlowInfo(buf, sizeof(buf), false)))
        return (false);
    }

    if (retriever->host) {
      if (!f->getInterface()->isViewed()) {
        /*
          For non-viewed interfaces it is safe to just check on pointers
          equality. Indeed, the retriever->host has been obtained with
          getHost(), which has returned the same pointer also used by the flow
          to identify its client / server hosts.
        */
        if ((retriever->host != f->get_cli_host()) &&
            (retriever->host != f->get_srv_host())) {
#if 0
	  if(f->get_cli_host() && f->get_srv_host()) {
	    char buf[128], buf2[128], buf3[128];

	    ntop->getTrace()->traceEvent(TRACE_WARNING,
					 "Skipping Host: %s (%p) - %s (%p) / Talking Host: %s (%p)",
					 f->get_cli_host() ? f->get_cli_host()->get_hostkey(buf, sizeof(buf)) : "NULL", f->get_cli_host(),
					 f->get_srv_host() ? f->get_srv_host()->get_hostkey(buf2, sizeof(buf2)) : "NULL", f->get_srv_host(),
					 retriever->host ? retriever->host->get_hostkey(buf3, sizeof(buf3)) : "NULL", retriever->host);
	  }
#endif
          return (false);
        }
      } else {
        /*
          In case of view interfaces, hosts are in the view interface whereas
          flows are in the underlying viewed interfaces so in this case it is
          not possible to just check on pointers equality. This need to use the
          retriever->host which comes from the view interface to retrieve an
          IpAddress, and check it against the flow ip address, along with the
          vlan. Indeed, flow ip addresses exist also when a flow doesn't have
          Host* as in the case of viewed interfaces.
        */
        if (!(retriever->host->get_ip()->equal(f->get_cli_ip_addr()) &&
              retriever->host->get_vlan_id() == f->get_vlan_id()) &&
            !(retriever->host->get_ip()->equal(f->get_srv_ip_addr()) &&
              retriever->host->get_vlan_id() == f->get_vlan_id()))
          return (false);
      }
    }

    if (retriever->pag &&
        retriever->pag->l7protoFilter(&ndpi_proto_master_proto,
                                      &ndpi_proto_app_proto)) {
      if (((ndpi_proto_master_proto == NDPI_PROTOCOL_UNKNOWN) ||
           (ndpi_proto_master_proto ==
            f->get_detected_protocol().master_protocol)) &&
          ((ndpi_proto_app_proto == NDPI_PROTOCOL_UNKNOWN) ||
           (ndpi_proto_app_proto == f->get_detected_protocol().app_protocol)))
        ; /* We're good */
      else
        return (false);
    }

    if (retriever->pag && retriever->pag->l7categoryFilter(&ndpi_cat) &&
        f->get_protocol_category() != ndpi_cat)
      return (false);

    if (retriever->pag &&
        retriever->pag->tcpFlowStateFilter(&tcp_flow_state_filter) &&
        ((f->get_protocol() != IPPROTO_TCP) ||
         (tcp_flow_state_filter == tcp_flow_state_established &&
          !f->isTCPEstablished()) ||
         (tcp_flow_state_filter == tcp_flow_state_connecting &&
          !f->isTCPConnecting()) ||
         (tcp_flow_state_filter == tcp_flow_state_closed &&
          !f->isTCPClosed()) ||
         (tcp_flow_state_filter == tcp_flow_state_reset && !f->isTCPReset())))
      return (false);

    if (retriever->pag && retriever->pag->ipVersion(&ip_version) &&
        (((ip_version == 4) &&
          (f->get_cli_ip_addr() && !f->get_cli_ip_addr()->isIPv4())) ||
         ((ip_version == 6) &&
          (f->get_cli_ip_addr() && !f->get_cli_ip_addr()->isIPv6()))))
      return (false);

    if (retriever->pag && retriever->pag->L4Protocol(&l4_protocol) &&
        l4_protocol && l4_protocol != f->get_protocol())
      return (false);

    if (retriever->pag && retriever->pag->deviceIpFilter(&deviceIP)) {
      if ((f->getFlowDeviceIP() != deviceIP) ||
          (retriever->pag->inIndexFilter(&inIndex) &&
           f->getFlowDeviceInIndex() != inIndex) ||
          (retriever->pag->outIndexFilter(&outIndex) &&
           f->getFlowDeviceOutIndex() != outIndex))
        return (false);
    }

    if (retriever->pag && retriever->pag->containerFilter(&container_filter)) {
      const char *cli_container =
          f->getClientContainerInfo() ? f->getClientContainerInfo()->id : NULL;
      const char *srv_container =
          f->getServerContainerInfo() ? f->getServerContainerInfo()->id : NULL;

      if (!((cli_container && !strcmp(container_filter, cli_container)) ||
            (srv_container && !strcmp(container_filter, srv_container))))
        return (false);
    }

    if (retriever->pag && retriever->pag->podFilter(&pod_filter)) {
      const ContainerInfo *cli_cont = f->getClientContainerInfo();
      const ContainerInfo *srv_cont = f->getServerContainerInfo();

      const char *cli_pod =
          cli_cont && cli_cont->data_type == container_info_data_type_k8s
              ? cli_cont->data.k8s.pod
              : NULL;
      const char *srv_pod =
          srv_cont && srv_cont->data_type == container_info_data_type_k8s
              ? srv_cont->data.k8s.pod
              : NULL;

      if (!((cli_pod && !strcmp(pod_filter, cli_pod)) ||
            (srv_pod && !strcmp(pod_filter, srv_pod))))
        return (false);
    }

#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    if (retriever->pag &&
        retriever->pag->trafficProfileFilter(&traffic_profile_filter) &&
        (f->isMaskedFlow() ||
         strcmp(traffic_profile_filter, f->get_profile_name()))) {
      return (false);
    }
#endif
#endif

    if (retriever->pag && retriever->pag->asnFilter(&asn_filter) &&
        f->get_cli_host() && f->get_srv_host() &&
        f->get_cli_host()->get_asn() != asn_filter &&
        f->get_srv_host()->get_asn() != asn_filter)
      return (false);
    else if (retriever->pag && retriever->pag->asnFilter(&asn_filter) &&
             f->get_cli_host() && f->get_srv_host())
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Filtering ASN: %u | Client ASN: %u | Server ASN: %u",
          asn_filter, f->get_cli_host()->get_asn(),
          f->get_srv_host()->get_asn());

    if (retriever->pag && retriever->pag->usernameFilter(&username_filter) &&
        (!f->get_user_name(true /* client uid */) ||
         strcmp(f->get_user_name(true /* client uid */), username_filter)) &&
        (!f->get_user_name(false /* server uid */) ||
         strcmp(f->get_user_name(false /* server uid */), username_filter)))
      return (false);

    if (retriever->pag && retriever->pag->pidnameFilter(&pidname_filter) &&
        (!f->get_proc_name(true /* client pid */) ||
         strcmp(f->get_proc_name(true /* client pid */), pidname_filter)) &&
        (!f->get_proc_name(false /* server pid */) ||
         strcmp(f->get_proc_name(false /* server pid */), pidname_filter)))
      return (false);

    if (retriever->pag && retriever->pag->icmpValue(&icmp_type, &icmp_code)) {
      u_int8_t cur_type, cur_code;

      f->getICMP(&cur_code, &cur_type);

      if ((!f->isICMP()) || (cur_type != icmp_type) || (cur_code != icmp_code))
        return (false);
    }

    if (retriever->pag && retriever->pag->dscpFilter(&dscp_filter) &&
        f->getCli2SrvDSCP() != dscp_filter &&
        f->getSrv2CliDSCP() != dscp_filter)
      return (false);

    if (retriever->pag && retriever->pag->portFilter(&port) &&
        f->get_cli_port() != port && f->get_srv_port() != port)
      return (false);

    if (retriever->pag &&
        retriever->pag->localNetworkFilter(&local_network_id)) {
      int16_t cli_local_network_id, srv_local_network_id;

      f->get_cli_ip_addr()->isLocalHost(&cli_local_network_id),
          f->get_srv_ip_addr()->isLocalHost(&srv_local_network_id);

      if (cli_local_network_id != local_network_id &&
          srv_local_network_id != local_network_id)
        return (false);
    }

    if (retriever->pag && retriever->pag->vlanIdFilter(&vlan_id) &&
        (f->get_vlan_id() != vlan_id))
      return (false);

    if (retriever->pag && retriever->pag->clientMode(&client_policy) &&
        (((client_policy == location_local_only) &&
          (!f->get_cli_ip_addr()->isLocalHost())) ||
         ((client_policy == location_remote_only) &&
          (f->get_cli_ip_addr()->isLocalHost()))))
      return (false);

    if (retriever->pag && retriever->pag->serverMode(&server_policy) &&
        (((server_policy == location_local_only) &&
          (!f->get_srv_ip_addr()->isLocalHost())) ||
         ((server_policy == location_remote_only) &&
          (f->get_srv_ip_addr()->isLocalHost()))))
      return (false);

    if (retriever->pag && retriever->pag->alertedFlows(&alerted_flows) &&
        ((alerted_flows && !f->isFlowAlerted()) ||
         (!alerted_flows && f->isFlowAlerted())))
      return (false);

    if (retriever->pag && retriever->pag->periodicFlows(&periodic_flows) &&
        ((periodic_flows && !f->isPeriodicFlow()) ||
         (!periodic_flows && f->isPeriodicFlow())))
      return (false);

    /* Flow Status filter */
    if (retriever->pag &&
        retriever->pag->flowStatusFilter(&alert_type_filter) &&
        !f->getAlertsBitmap().isSetBit(alert_type_filter))
      return (false);

    /* Flow Status severity filter */
    if (retriever->pag &&
        retriever->pag->flowStatusFilter(&flow_status_severity_filter)) {
      if (!f->isFlowAlerted() ||
          f->getPredominantAlertSeverity() == alert_level_none ||
          (flow_status_severity_filter == alert_level_group_notice_or_lower &&
           f->getPredominantAlertSeverity() > alert_level_notice) ||
          (flow_status_severity_filter == alert_level_group_warning &&
           f->getPredominantAlertSeverity() != alert_level_warning) ||
          (flow_status_severity_filter == alert_level_group_error &&
           f->getPredominantAlertSeverity() < alert_level_error))
        return (false);
    }

#ifdef HAVE_NEDGE
    if (retriever->pag && retriever->pag->filteredFlows(&filtered_flows) &&
        ((filtered_flows && f->isPassVerdict()) ||
         (!filtered_flows && !f->isPassVerdict())))
      return (false);
#endif

    if (retriever->pag &&
        retriever->pag->unidirectionalTraffic(&unidirectional) &&
        ((unidirectional && !f->isOneWay()) ||
         (!unidirectional && f->isBidirectional())))
      return (false);

    /* Unicast: at least one between client and server is unicast address */
    if (retriever->pag && retriever->pag->unicastTraffic(&unicast) &&
        ((unicast && ((f->get_cli_ip_addr()->isMulticastAddress() ||
                       f->get_cli_ip_addr()->isBroadcastAddress() ||
                       f->get_srv_ip_addr()->isMulticastAddress() ||
                       f->get_srv_ip_addr()->isBroadcastAddress()))) ||
         (!unicast && (!f->get_cli_ip_addr()->isMulticastAddress() &&
                       !f->get_cli_ip_addr()->isBroadcastAddress() &&
                       !f->get_srv_ip_addr()->isMulticastAddress() &&
                       !f->get_srv_ip_addr()->isBroadcastAddress()))))
      return (false);

    if (cli_ip && !f->get_cli_host())
      cli_pool_found = f->getInterface()->getHostPools()->findIpPool(
          cli_ip, f->get_vlan_id(), &cli_pool, &cli_target_node);

    if (srv_ip && !f->get_srv_host())
      srv_pool_found = f->getInterface()->getHostPools()->findIpPool(
          srv_ip, f->get_vlan_id(), &srv_pool, &srv_target_node);

    /* Pool filter */
    if (retriever->pag && retriever->pag->poolFilter(&pool_filter) &&
        !((f->get_cli_host() &&
           f->get_cli_host()->get_host_pool() == pool_filter) ||
          (f->get_srv_host() &&
           f->get_srv_host()->get_host_pool() == pool_filter)) &&
        !((cli_pool_found && cli_pool == pool_filter) ||
          (srv_pool_found && srv_pool == pool_filter)))
      return (false);

    /* Mac filter - NOTE: must stay below the vlan_id filter */
    if (retriever->pag && retriever->pag->macFilter(&mac_filter) &&
        !((f->get_cli_host() && f->get_cli_host()->getMac() &&
           f->get_cli_host()->getMac()->equal(mac_filter)) ||
          (f->get_srv_host() && f->get_srv_host()->getMac() &&
           f->get_srv_host()->getMac()->equal(mac_filter))))
      return (false);

    if (f->match(retriever->allowed_hosts)) return (true); /* match */
  }

  return (false);
}

/* **************************************************** */

static bool flow_search_walker(GenericHashEntry *h, void *user_data,
                               bool *matched) {
  struct flowHostRetriever *retriever = (struct flowHostRetriever *)user_data;
  Flow *f = (Flow *)h;
  const char *flow_info;
  const TcpInfo *tcp_info;

  if (retriever->actNumEntries >= retriever->maxNumEntries)
    return (true); /* Limit reached - stop iterating */

  if (flow_matches(f, retriever)) {
    retriever->elems[retriever->actNumEntries].flow = f;
    retriever->totBytesSent += f->get_bytes_cli2srv();
    retriever->totBytesRcvd += f->get_bytes_srv2cli();

    switch (retriever->sorter) {
      case column_client:
        if (f->getInterface()->isViewed())
          retriever->elems[retriever->actNumEntries++].ipValue =
              (IpAddress *)f->get_cli_ip_addr();
        else
          retriever->elems[retriever->actNumEntries++].hostValue =
              f->get_cli_host();
        break;
      case column_server:
        if (f->getInterface()->isViewed())
          retriever->elems[retriever->actNumEntries++].ipValue =
              (IpAddress *)f->get_srv_ip_addr();
        else
          retriever->elems[retriever->actNumEntries++].hostValue =
              f->get_srv_host();
        break;
      case column_vlan:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->get_vlan_id();
        break;
      case column_proto_l4:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->get_protocol();
        break;
      case column_ndpi:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->get_detected_protocol().app_protocol;
        break;
      case column_duration:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->get_duration();
        break;
      case column_score:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->getScore();
        break;
      case column_thpt:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->get_bytes_thpt();
        break;
      case column_bytes:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->get_bytes();
        break;
      case column_last_seen:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->get_last_seen();
        break;
      case column_first_seen:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->get_first_seen();
        break;
      case column_client_rtt:
        if ((tcp_info = f->getClientTcpInfo()))
          retriever->elems[retriever->actNumEntries++].numericValue =
              (u_int64_t)(tcp_info->rtt * 1000);
        else
          retriever->elems[retriever->actNumEntries++].numericValue = 0;
        break;
      case column_server_rtt:
        if ((tcp_info = f->getServerTcpInfo()))
          retriever->elems[retriever->actNumEntries++].numericValue =
              (u_int64_t)(tcp_info->rtt * 1000);
        else
          retriever->elems[retriever->actNumEntries++].numericValue = 0;
        break;
      case column_info: {
        char buf[64];

        flow_info = f->getFlowInfo(buf, sizeof(buf), false);
        retriever->elems[retriever->actNumEntries++].stringValue =
            flow_info ? flow_info : (char *)"";
      } break;
      case column_device_ip:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->getFlowDeviceIP();
        break;
      case column_in_index:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->getFlowDeviceInIndex();
        break;
      case column_out_index:
        retriever->elems[retriever->actNumEntries++].numericValue =
            f->getFlowDeviceOutIndex();
        break;
      default:
        ntop->getTrace()->traceEvent(TRACE_WARNING,
                                     "Internal error: column %d not handled",
                                     retriever->sorter);
        break;
    }

    *matched = true;
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool host_search_walker(GenericHashEntry *he, void *user_data,
                               bool *matched) {
  char buf[64];
  u_int8_t network_prefix = 0;
  IpAddress *ip_addr = NULL;
  struct flowHostRetriever *r = (struct flowHostRetriever *)user_data;
  Host *h = (Host *)he;

  if (r->actNumEntries >= r->maxNumEntries) return (true); /* Limit reached */

  // ntop->getTrace()->traceEvent(TRACE_WARNING, "Host %u / Menu %u",
  // h->get_observation_point_id(), r->observationPointId);

  if (!h || h->idle() || !h->match(r->allowed_hosts) ||
      (h->get_observation_point_id() != r->observationPointId))
    return (false);

  if ((r->location == location_local_only && (!h->isLocalUnicastHost())) ||
      (r->location == location_local_only_no_tx &&
       ((!h->isLocalUnicastHost()) || (!h->isRxOnlyHost()))) ||
      (r->location == location_local_only_no_tcp_tx &&
       ((!h->isLocalUnicastHost()) || (!h->isRxOnlyHost()) ||
        (h->getNumBytesTCPSent() > 0) || (h->getNumBytesTCPRcvd() == 0))) ||
      (r->location == location_remote_only && h->isLocalHost()) ||
      (r->location == location_remote_only_no_tx &&
       (h->isLocalHost() || (!h->isRxOnlyHost()))) ||
      (r->location == location_remote_only_no_tcp_tx &&
       (h->isLocalHost() || (!h->isRxOnlyHost()) ||
        (h->getNumBytesTCPSent() > 0) || (h->getNumBytesTCPRcvd() == 0))) ||
      (r->location == location_broadcast_domain_only &&
       !h->isBroadcastDomainHost()) ||
      (r->location == location_private_only && !h->isPrivateHost()) ||
      (r->location == location_public_only && h->isPrivateHost()) ||
      (r->location == location_public_only && h->isPrivateHost()) ||
      ((r->vlan_id != ((u_int16_t)-1)) && (r->vlan_id != h->get_vlan_id())) ||
      ((r->ndpi_proto != -1) &&
       (h->get_ndpi_stats()->getProtoBytes(r->ndpi_proto) == 0)) ||
      ((r->asnFilter != (u_int32_t)-1) && (r->asnFilter != h->get_asn())) ||
      ((r->networkFilter != -2) &&
       (r->networkFilter != h->get_local_network_id())) ||
      (r->mac && ((!h->getMac()) || (!h->getMac()->equal(r->mac)))) ||
      ((r->poolFilter != (u_int16_t)-1) &&
       (r->poolFilter != h->get_host_pool())) ||
      (r->country && strlen(r->country) &&
       strcmp(h->get_country(buf, sizeof(buf)), r->country)) ||
      (r->osFilter != os_any && (h->getOS() != r->osFilter)) ||
      (r->blacklistedHosts && !h->isBlacklisted()) ||
      (r->anomalousOnly && !h->hasAnomalies()) ||
      (r->dhcpOnly && !h->isDHCPHost()) ||
      (r->cidr_filter && !h->match(r->cidr_filter)) ||
      (r->traffic_type == traffic_type_unidirectional &&
       !h->isUnidirectionalTraffic()) ||
      (r->traffic_type == traffic_type_bidirectional &&
       !h->isBidirectionalTraffic()) ||
      (r->device_ip && h->getLastDeviceIp() &&
       (r->device_ip != h->getLastDeviceIp())) ||
      (r->dhcpHostsOnly && (!h->isDHCPHost())) ||
#ifdef NTOPNG_PRO
      (r->filteredHosts && !h->hasBlockedTraffic()) ||
#endif
      (r->ipVersionFilter &&
       (((r->ipVersionFilter == 4) && (!h->get_ip()->isIPv4())) ||
        ((r->ipVersionFilter == 6) && (!h->get_ip()->isIPv6())))))
    return (false); /* false = keep on walking */

  r->elems[r->actNumEntries].hostValue = h;
  h->incUses(); /* (***) */

  switch (r->sorter) {
    case column_ip:
      r->elems[r->actNumEntries++].hostValue =
          h; /* hostValue was already set */
      break;

    case column_alerts:
      r->elems[r->actNumEntries++].numericValue = h->getNumEngagedAlerts();
      break;

    case column_name:
      r->elems[r->actNumEntries++].stringValue =
          strdup(h->get_visual_name(buf, sizeof(buf)));
      break;

    case column_country:
      r->elems[r->actNumEntries++].stringValue =
          strdup(h->get_country(buf, sizeof(buf)));
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

    case column_obs_point:
      r->elems[r->actNumEntries++].numericValue = h->get_observation_point_id();
      break;

    case column_score:
      r->elems[r->actNumEntries++].numericValue = h->getScore();
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
      ntop->getLocalNetworkIp(h->get_local_network_id(), &ip_addr,
                              &network_prefix);
      r->elems[r->actNumEntries].ipValue = ip_addr;
      r->elems[r->actNumEntries++].numericValue = network_prefix;
      break;

    case column_mac:
      r->elems[r->actNumEntries++].numericValue =
          Utils::macaddr_int(h->get_mac());
      break;

    case column_pool_id:
      r->elems[r->actNumEntries++].numericValue = h->get_host_pool();
      break;

    case column_tcp_udp_unresp_as_client:
      r->elems[r->actNumEntries++].numericValue =
          h->getNumContactedPeersAsClientTCPUDPNoTX();
      break;

    case column_tcp_udp_unresp_as_server:
      r->elems[r->actNumEntries++].numericValue =
          h->getNumContactsFromPeersAsServerTCPUDPNoTX();
      break;

      /* Criteria */
    case column_traffic_sent:
      r->elems[r->actNumEntries++].numericValue = h->getNumBytesSent();
      break;
    case column_traffic_rcvd:
      r->elems[r->actNumEntries++].numericValue = h->getNumBytesRcvd();
      break;
    case column_traffic_unknown:
      r->elems[r->actNumEntries++].numericValue =
          h->get_ndpi_stats()->getProtoBytes(NDPI_PROTOCOL_UNKNOWN);
      break;
    case column_num_flows_as_client:
      r->elems[r->actNumEntries++].numericValue = h->getNumOutgoingFlows();
      break;
    case column_num_flows_as_server:
      r->elems[r->actNumEntries++].numericValue = h->getNumIncomingFlows();
      break;
    case column_total_num_alerted_flows_as_client:
      r->elems[r->actNumEntries++].numericValue =
          h->getTotalNumAlertedOutgoingFlows();
      break;
    case column_total_num_alerted_flows_as_server:
      r->elems[r->actNumEntries++].numericValue =
          h->getTotalNumAlertedIncomingFlows();
      break;
    case column_total_num_unreachable_flows_as_client:
      r->elems[r->actNumEntries++].numericValue =
          h->getTotalNumUnreachableOutgoingFlows();
      break;
    case column_total_num_unreachable_flows_as_server:
      r->elems[r->actNumEntries++].numericValue =
          h->getTotalNumUnreachableIncomingFlows();
      break;
    case column_total_num_retx_sent:
      r->elems[r->actNumEntries++].numericValue =
          h->getTcpPacketSentStats()->get_retr();
      break;
    case column_total_num_retx_rcvd:
      r->elems[r->actNumEntries++].numericValue =
          h->getTcpPacketRcvdStats()->get_retr();
      break;
    case column_total_alerts:
      r->elems[r->actNumEntries++].numericValue = h->getTotalAlerts();
      break;
    case column_score_as_client:
      r->elems[r->actNumEntries++].numericValue = h->getScoreAsClient();
      break;
    case column_score_as_server:
      r->elems[r->actNumEntries++].numericValue = h->getScoreAsServer();
      break;

    default:
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
      break;
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool mac_search_walker(GenericHashEntry *he, void *user_data,
                              bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever *)user_data;
  Mac *m = (Mac *)he;

  if (r->actNumEntries >= r->maxNumEntries) return (true); /* Limit reached */

  if (!m || m->idle() ||
      (r->min_first_seen >=
       m->get_first_seen()) /* first seen must be greater than or equal to the
                               minimum first seen */
      || (r->sourceMacsOnly && !m->isSourceMac()) ||
      ((r->devtypeFilter != (u_int8_t)-1) &&
       (m->getDeviceType() != r->devtypeFilter))
#ifdef HAVE_NEDGE
      || ((r->locationFilter != (u_int8_t)-1) &&
          (m->locate() != r->locationFilter))
#endif
      || ((r->poolFilter != (u_int16_t)-1) &&
          (m->getInterface()->getHostPool(m) != r->poolFilter)) ||
      (r->manufacturer &&
       strcmp(r->manufacturer,
              m->get_manufacturer() ? m->get_manufacturer() : "") != 0))
    return (false); /* false = keep on walking */

  r->elems[r->actNumEntries].macValue = m;

  switch (r->sorter) {
    case column_mac:
      r->elems[r->actNumEntries++].numericValue =
          Utils::macaddr_int(m->get_mac());
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
      r->elems[r->actNumEntries++].stringValue =
          m->get_manufacturer() ? (char *)m->get_manufacturer() : (char *)"zzz";
      break;

    case column_device_type:
      r->elems[r->actNumEntries++].numericValue = m->getDeviceType();
      break;

    case column_arp_total:
      r->elems[r->actNumEntries++].numericValue =
          m->getNumSentArp() + m->getNumRcvdArp();
      break;

    case column_arp_sent:
      r->elems[r->actNumEntries++].numericValue = m->getNumSentArp();
      break;

    case column_arp_rcvd:
      r->elems[r->actNumEntries++].numericValue = m->getNumRcvdArp();
      break;

    default:
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
      break;
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool as_search_walker(GenericHashEntry *he, void *user_data,
                             bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever *)user_data;
  AutonomousSystem *as = (AutonomousSystem *)he;

  if (r->actNumEntries >= r->maxNumEntries) return (true); /* Limit reached */

  if (!as || as->idle()) return (false); /* false = keep on walking */

  r->elems[r->actNumEntries].asValue = as;

  switch (r->sorter) {
    case column_asn:
      r->elems[r->actNumEntries++].numericValue = as->get_asn();
      break;

    case column_asname:
      r->elems[r->actNumEntries++].stringValue =
          as->get_asname() ? as->get_asname() : (char *)"zzz";
      break;

    case column_score:
      r->elems[r->actNumEntries++].numericValue = as->getScore();
      break;

    case column_alerted_flows:
      r->elems[r->actNumEntries++].numericValue =
          as->getTotalAlertedNumFlowsAsClient() +
          as->getTotalAlertedNumFlowsAsServer();
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
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
      break;
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool obs_point_search_walker(GenericHashEntry *he, void *user_data,
                                    bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever *)user_data;
  ObservationPoint *obs_point = (ObservationPoint *)he;

  if (r->actNumEntries >= r->maxNumEntries) return (true); /* Limit reached */

  if (!obs_point || obs_point->idle())
    return (false); /* false = keep on walking */

  r->elems[r->actNumEntries].obsPointValue = obs_point;

  switch (r->sorter) {
    case column_obs_point:
      r->elems[r->actNumEntries++].numericValue = obs_point->getObsPoint();
      break;

    case column_score:
      r->elems[r->actNumEntries++].numericValue = obs_point->getScore();
      break;

    case column_since:
      r->elems[r->actNumEntries++].numericValue = obs_point->get_first_seen();
      break;

    case column_thpt:
      r->elems[r->actNumEntries++].numericValue = obs_point->getBytesThpt();
      break;

    case column_traffic:
      r->elems[r->actNumEntries++].numericValue = obs_point->getNumBytes();
      break;

    case column_num_hosts:
      r->elems[r->actNumEntries++].numericValue = obs_point->getNumHosts();
      break;

    default:
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
      break;
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool os_search_walker(GenericHashEntry *he, void *user_data,
                             bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever *)user_data;
  OperatingSystem *os = (OperatingSystem *)he;

  if (r->actNumEntries >= r->maxNumEntries) return (true); /* Limit reached */

  if (!os || os->idle()) return (false); /* false = keep on walking */

  r->elems[r->actNumEntries].osValue = os;

  switch (r->sorter) {
    case column_since:
      r->elems[r->actNumEntries++].numericValue = os->get_first_seen();
      break;

    case column_thpt:
      r->elems[r->actNumEntries++].numericValue = os->getBytesThpt();
      break;

    case column_traffic:
      r->elems[r->actNumEntries++].numericValue = os->getNumBytes();
      break;

    case column_num_hosts:
      r->elems[r->actNumEntries++].numericValue = os->getNumHosts();
      break;

    default:
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
      break;
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool country_search_walker(GenericHashEntry *he, void *user_data,
                                  bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever *)user_data;
  Country *country = (Country *)he;

  if (r->actNumEntries >= r->maxNumEntries) return (true); /* Limit reached */

  if (!country || country->idle()) return (false); /* false = keep on walking */

  r->elems[r->actNumEntries].countryVal = country;

  /* Note: we don't have throughput information into the countries */
  switch (r->sorter) {
    case column_country:
      r->elems[r->actNumEntries++].stringValue = country->get_country_name();
      break;

    case column_since:
      r->elems[r->actNumEntries++].numericValue = country->get_first_seen();
      break;

    case column_score:
      r->elems[r->actNumEntries++].numericValue = country->getScore();
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
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
      break;
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool vlan_search_walker(GenericHashEntry *he, void *user_data,
                               bool *matched) {
  struct flowHostRetriever *r = (struct flowHostRetriever *)user_data;
  VLAN *vl = (VLAN *)he;

  if (r->actNumEntries >= r->maxNumEntries) return (true); /* Limit reached */

  if (!vl || vl->idle()) return (false); /* false = keep on walking */

  r->elems[r->actNumEntries].vlanValue = vl;

  switch (r->sorter) {
    case column_vlan:
      r->elems[r->actNumEntries++].numericValue = vl->get_vlan_id();
      break;

    case column_since:
      r->elems[r->actNumEntries++].numericValue = vl->get_first_seen();
      break;

    case column_thpt:
      r->elems[r->actNumEntries++].numericValue = vl->getBytesThpt();
      break;

    case column_score:
      r->elems[r->actNumEntries++].numericValue = vl->getScore();
      break;

    case column_traffic:
      r->elems[r->actNumEntries++].numericValue = vl->getNumBytes();
      break;

    case column_num_hosts:
      r->elems[r->actNumEntries++].numericValue = vl->getNumHosts();
      break;

    default:
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
      break;
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

int hostSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList *)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList *)_b;

  return (a->hostValue->compare(b->hostValue));
}

/* **************************************************** */

int ipNetworkSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList *)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList *)_b;
  int rv;

  if (!a || !b || !a->ipValue || !b->ipValue) return (true);

  /* Compare network address first */
  rv = a->ipValue->compare(b->ipValue);
  if (rv != 0) return rv;

  /* If the address matches, compare netmasks */
  if (a->numericValue < b->numericValue)
    return (-1);
  else if (a->numericValue > b->numericValue)
    return (1);
  else
    return (0);
}

int ipSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList *)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList *)_b;

  if (!a || !b || !a->ipValue || !b->ipValue) return (true);

  return (a->ipValue->compare(b->ipValue));
}

int numericSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList *)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList *)_b;

  if (a->numericValue < b->numericValue)
    return (-1);
  else if (a->numericValue > b->numericValue)
    return (1);
  else
    return (0);
}

int stringSorter(const void *_a, const void *_b) {
  struct flowHostRetrieveList *a = (struct flowHostRetrieveList *)_a;
  struct flowHostRetrieveList *b = (struct flowHostRetrieveList *)_b;

  return (strcasecmp(a->stringValue, b->stringValue));
}

/* **************************************************** */

int NetworkInterface::sortFlows(u_int32_t *begin_slot, bool walk_all,
                                struct flowHostRetriever *retriever,
                                AddressTree *allowed_hosts, Host *host,
                                Host *client, Host *server, char *flow_info,
                                Paginator *p, const char *sortColumn) {
  int (*sorter)(const void *_a, const void *_b);

  if (retriever == NULL) return (-1);

  retriever->pag = p;
  retriever->host = host, retriever->location = location_all;
  retriever->server = server;
  retriever->client = client;
  retriever->flow_info = flow_info;
  retriever->ndpi_proto = -1;
  retriever->actNumEntries = 0, retriever->maxNumEntries = getFlowsHashSize(),
  retriever->allowed_hosts = allowed_hosts;

  retriever->elems = (struct flowHostRetrieveList *)calloc(
      sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if (retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return (-1);
  }

  if (!strcmp(sortColumn, "column_client"))
    retriever->sorter = column_client,
    sorter = (isViewed() || isView()) ? ipSorter : hostSorter;
  else if (!strcmp(sortColumn, "column_vlan"))
    retriever->sorter = column_vlan, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_server"))
    retriever->sorter = column_server,
    sorter = (isViewed() || isView()) ? ipSorter : hostSorter;
  else if (!strcmp(sortColumn, "column_proto_l4"))
    retriever->sorter = column_proto_l4, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_ndpi"))
    retriever->sorter = column_ndpi, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_duration"))
    retriever->sorter = column_duration, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score"))
    retriever->sorter = column_score, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score_as_client"))
    retriever->sorter = column_score_as_client, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score_as_server"))
    retriever->sorter = column_score_as_server, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_thpt"))
    retriever->sorter = column_thpt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_last_seen"))
    retriever->sorter = column_last_seen, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_first_seen"))
    retriever->sorter = column_first_seen, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_client_rtt"))
    retriever->sorter = column_client_rtt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_server_rtt"))
    retriever->sorter = column_server_rtt, sorter = numericSorter;
  else if ((!strcmp(sortColumn, "column_bytes")) ||
           (!strcmp(sortColumn, "column_") /* default */))
    retriever->sorter = column_bytes, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_info"))
    retriever->sorter = column_info, sorter = stringSorter;
  else if (!strcmp(sortColumn, "column_device_ip"))
    retriever->sorter = column_device_ip, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_in_index"))
    retriever->sorter = column_in_index, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_out_index"))
    retriever->sorter = column_out_index, sorter = numericSorter;
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s",
                                 sortColumn);
    retriever->sorter = column_bytes, sorter = numericSorter;
  }

  if (false) {
    u_int32_t deviceIP = 0;
    u_int32_t inIndex = 0, outIndex = 0;
    char buf[32];

    p->deviceIpFilter(&deviceIP), p->inIndexFilter(&inIndex),
        p->outIndexFilter(&outIndex);

    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "[Device IP] %s / [In Idx] %u / [Out Idx] %u",
        Utils::intoaV4(deviceIP, buf, sizeof(buf)), inIndex, outIndex);
  }

  // make sure the caller has disabled the purge!!
  walker(begin_slot, walk_all, walker_flows, flow_search_walker,
         (void *)retriever);

  qsort(retriever->elems, retriever->actNumEntries,
        sizeof(struct flowHostRetrieveList), sorter);

  return (retriever->actNumEntries);
}

/* **************************************************** */

static bool flow_sum_stats(GenericHashEntry *flow, void *user_data,
                           bool *matched) {
  flowHostRetriever *retriever = (flowHostRetriever *)user_data;
  nDPIStats *ndpi_stats = retriever->ndpi_stats;
  FlowStats *stats = retriever->stats;
  Flow *f = (Flow *)flow;

  if (flow_matches(f, retriever)) {
    stats->updateTalkingHosts(f);
    retriever->totBytesSent += f->get_bytes_cli2srv();
    retriever->totBytesRcvd += f->get_bytes_srv2cli();
    retriever->totThpt += f->get_bytes_thpt();

    if (!retriever->only_traffic_stats) f->sumStats(ndpi_stats, stats);

    *matched = true;
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getActiveFlowsStats(
    nDPIStats *ndpi_stats, FlowStats *stats, AddressTree *allowed_hosts,
    Host *h, Host *talking_with_host, Host *client, Host *server,
    char *flow_info, Paginator *p, lua_State *vm, bool only_traffic_stats) {
  flowHostRetriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&retriever, 0, sizeof(retriever));

  retriever.pag = p;
  retriever.host = h;
  retriever.talking_with_host = talking_with_host;
  retriever.client = client;
  retriever.server = server;
  retriever.location = location_all;
  retriever.ndpi_proto = -1;
  retriever.actNumEntries = 0;
  retriever.maxNumEntries = getFlowsHashSize();
  retriever.allowed_hosts = allowed_hosts;
  retriever.ndpi_stats = ndpi_stats;
  retriever.stats = stats;
  retriever.totBytesSent = 0, retriever.totBytesRcvd = 0, retriever.totThpt = 0;
  retriever.only_traffic_stats = only_traffic_stats;
  retriever.observationPointId = getLuaVMUservalue(vm, observationPointId);
  retriever.flow_info = flow_info;

  walker(&begin_slot, walk_all, walker_flows, flow_sum_stats, &retriever);

  lua_newtable(vm);
  /* Overview stats */
  lua_push_uint64_table_entry(vm, "numFlows", retriever.actNumEntries);
  lua_push_uint64_table_entry(vm, "totBytesSent", retriever.totBytesSent);
  lua_push_uint64_table_entry(vm, "totBytesRcvd", retriever.totBytesRcvd);
  lua_push_uint64_table_entry(vm, "totThpt", retriever.totThpt);

  if (!only_traffic_stats) {
    /* DPI stats */
    ndpi_stats->lua(this, vm);
    stats->lua(vm);
  }

  retriever.stats->resetTalkingHosts();
}

/* **************************************************** */

int NetworkInterface::getFlows(lua_State *vm, u_int32_t *begin_slot,
                               bool walk_all, AddressTree *allowed_hosts,
                               Host *host, Host *talking_with_host,
                               Host *client, Host *server, char *flow_info,
                               Paginator *p) {
  struct flowHostRetriever retriever;
  char sortColumn[32];
  DetailsLevel highDetails;

  if (p == NULL) {
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "Unable to return results with a NULL paginator");
    return (-1);
  }

  LocationPolicy client_mode = location_all;
  LocationPolicy server_mode = location_all;
  p->clientMode(&client_mode);
  p->serverMode(&server_mode);
  bool local_hosts = ((client_mode == location_local_only) &&
                      (server_mode == location_local_only));

  snprintf(sortColumn, sizeof(sortColumn), "%s", p->sortColumn());
  if (!p->getDetailsLevel(&highDetails))
    highDetails = p->detailedResults() ? details_high
                  : (local_hosts || (p && p->maxHits() != CONST_MAX_NUM_HITS))
                      ? details_high
                      : details_normal;

  retriever.observationPointId = getLuaVMUservalue(vm, observationPointId);
  retriever.talking_with_host = talking_with_host;

  if (sortFlows(begin_slot, walk_all, &retriever, allowed_hosts, host, client,
                server, flow_info, p, sortColumn) < 0)
    return (-1);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numFlows", retriever.actNumEntries);
  lua_push_uint64_table_entry(vm, "nextSlot", *begin_slot);

  lua_newtable(vm);

  if (p->a2zSortOrder()) {
    for (int i = p->toSkip(), num = 0; i < (int)retriever.actNumEntries; i++) {
      lua_newtable(vm);

      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);

      lua_pushinteger(vm, num + 1);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if (++num >= (int)p->maxHits()) break;
    }
  } else {
    for (int i = (retriever.actNumEntries - 1 - p->toSkip()), num = 0; i >= 0;
         i--) {
      lua_newtable(vm);

      retriever.elems[i].flow->lua(vm, allowed_hosts, highDetails, true);

      lua_pushinteger(vm, num + 1);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      if (++num >= (int)p->maxHits()) break;
    }
  }

  lua_pushstring(vm, "flows");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getFlowsGroup(lua_State *vm, AddressTree *allowed_hosts,
                                    Paginator *p, const char *groupColumn) {
  struct flowHostRetriever retriever;
  FlowGrouper *gper;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (p == NULL) {
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "Unable to return results with a NULL paginator");
    return (-1);
  }

  retriever.observationPointId = getLuaVMUservalue(vm, observationPointId);

  if (sortFlows(&begin_slot, walk_all, &retriever, allowed_hosts, NULL, NULL,
                NULL, NULL, p, groupColumn) < 0) {
    return (-1);
  }

  // build a new grouper that will help in aggregating stats
  if ((gper = new (std::nothrow) FlowGrouper(retriever.sorter)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to allocate memory for a Grouper.");
    return (-1);
  }

  lua_newtable(vm);

  for (int i = 0; i < (int)retriever.actNumEntries; i++) {
    Flow *flow = retriever.elems[i].flow;

    if (flow) {
      if (gper->inGroup(flow) == false) {
        if (gper->getNumEntries() > 0) gper->lua(vm);
        gper->newGroup(flow);
      }

      gper->incStats(flow);
    }
  }

  if (gper->getNumEntries() > 0) gper->lua(vm);

  delete gper;

  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************************** */

static bool flow_drop_walker(GenericHashEntry *h, void *user_data,
                             bool *matched) {
  struct flowHostRetriever *retriever = (struct flowHostRetriever *)user_data;
  Flow *f = (Flow *)h;

  if (flow_matches(f, retriever)) {
    f->setDropVerdict();
    *matched = true;
  }

  return (false); /* Keep on walking */
}

/* **************************************************** */

int NetworkInterface::dropFlowsTraffic(AddressTree *allowed_hosts,
                                       Paginator *p) {
  struct flowHostRetriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&retriever, 0, sizeof(retriever));

  retriever.allowed_hosts = allowed_hosts;
  retriever.pag = p;

  walker(&begin_slot, walk_all, walker_flows, flow_drop_walker,
         (void *)&retriever);

  return (0);
}

/* **************************************************** */

int NetworkInterface::sortHosts(
    u_int32_t *begin_slot, bool walk_all, struct flowHostRetriever *retriever,
    u_int8_t bridge_iface_idx, AddressTree *allowed_hosts, bool host_details,
    LocationPolicy location, char *countryFilter, char *mac_filter,
    u_int16_t vlan_id, OSType osFilter, u_int32_t asnFilter,
    int16_t networkFilter, u_int16_t pool_filter, bool filtered_hosts,
    bool blacklisted_hosts, bool anomalousOnly, bool dhcpOnly,
    const AddressTree *const cidr_filter, u_int8_t ipver_filter,
    int proto_filter, TrafficType traffic_type_filter, u_int32_t device_ip,
    char *sortColumn) {
  u_int8_t macAddr[6];
  int (*sorter)(const void *_a, const void *_b);

  if (retriever == NULL) return (-1);

  if (mac_filter) {
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
  retriever->anomalousOnly = anomalousOnly, retriever->dhcpOnly = dhcpOnly,
  retriever->cidr_filter = cidr_filter, retriever->ndpi_proto = proto_filter,
  retriever->traffic_type = traffic_type_filter,
  retriever->device_ip = device_ip,
  retriever->maxNumEntries = getHostsHashSize();
  retriever->elems = (struct flowHostRetrieveList *)calloc(
      sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if (retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return (-1);
  }

  if ((!strcmp(sortColumn, "column_ip")) || (!strcmp(sortColumn, "column_")))
    retriever->sorter = column_ip,
    sorter = (isViewed() || isView()) ? ipSorter : hostSorter;
  else if (!strcmp(sortColumn, "column_vlan"))
    retriever->sorter = column_vlan, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_alerts"))
    retriever->sorter = column_alerts, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_name"))
    retriever->sorter = column_name, sorter = stringSorter;
  else if (!strcmp(sortColumn, "column_country"))
    retriever->sorter = column_country, sorter = stringSorter;
  else if (!strcmp(sortColumn, "column_os"))
    retriever->sorter = column_os, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_since"))
    retriever->sorter = column_since, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_asn"))
    retriever->sorter = column_asn, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_thpt"))
    retriever->sorter = column_thpt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_num_flows"))
    retriever->sorter = column_num_flows, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_num_dropped_flows"))
    retriever->sorter = column_num_dropped_flows, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_traffic"))
    retriever->sorter = column_traffic, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_local_network_id"))
    retriever->sorter = column_local_network_id, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_local_network"))
    retriever->sorter = column_local_network, sorter = ipNetworkSorter;
  else if (!strcmp(sortColumn, "column_mac"))
    retriever->sorter = column_mac, sorter = numericSorter;
  /* criteria (datatype sortField in ntop_typedefs.h / see also
   * host_search_walker:NetworkInterface.cpp) */
  else if (!strcmp(sortColumn, "column_traffic_sent"))
    retriever->sorter = column_traffic_sent, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_traffic_rcvd"))
    retriever->sorter = column_traffic_rcvd, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_traffic_unknown"))
    retriever->sorter = column_traffic_unknown, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_num_flows_as_client"))
    retriever->sorter = column_num_flows_as_client, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_num_flows_as_server"))
    retriever->sorter = column_num_flows_as_server, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_total_num_alerted_flows_as_client"))
    retriever->sorter = column_total_num_alerted_flows_as_client,
    sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_total_num_alerted_flows_as_server"))
    retriever->sorter = column_total_num_alerted_flows_as_server,
    sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_total_num_unreachable_flows_as_client"))
    retriever->sorter = column_total_num_unreachable_flows_as_client,
    sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_total_num_unreachable_flows_as_server"))
    retriever->sorter = column_total_num_unreachable_flows_as_server,
    sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_total_num_retx_sent"))
    retriever->sorter = column_total_num_retx_sent, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_total_num_retx_rcvd"))
    retriever->sorter = column_total_num_retx_rcvd, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_total_alerts"))
    retriever->sorter = column_total_alerts, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score"))
    retriever->sorter = column_score, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score_as_client"))
    retriever->sorter = column_score_as_client, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score_as_server"))
    retriever->sorter = column_score_as_server, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_pool_id"))
    retriever->sorter = column_pool_id, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_tcp_unresp_as_client"))
    retriever->sorter = column_tcp_udp_unresp_as_client, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_tcp_unresp_as_server"))
    retriever->sorter = column_tcp_udp_unresp_as_server, sorter = numericSorter;
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s",
                                 sortColumn);
    retriever->sorter = column_traffic, sorter = numericSorter;
  }

  // make sure the caller has disabled the purge!!
  walker(begin_slot, walk_all, walker_hosts, host_search_walker,
         (void *)retriever);

  qsort(retriever->elems, retriever->actNumEntries,
        sizeof(struct flowHostRetrieveList), sorter);

  return (retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortMacs(u_int32_t *begin_slot, bool walk_all,
                               struct flowHostRetriever *retriever,
                               u_int8_t bridge_iface_idx, bool sourceMacsOnly,
                               const char *manufacturer, char *sortColumn,
                               u_int16_t pool_filter, u_int8_t devtype_filter,
                               u_int8_t location_filter,
                               time_t min_first_seen) {
  int (*sorter)(const void *_a, const void *_b);

  if (retriever == NULL) return (-1);

  retriever->sourceMacsOnly = sourceMacsOnly, retriever->actNumEntries = 0,
  retriever->poolFilter = pool_filter,
  retriever->manufacturer = (char *)manufacturer,
  retriever->maxNumEntries = getMacsHashSize();
  retriever->devtypeFilter = devtype_filter,
  retriever->locationFilter = location_filter,
  retriever->min_first_seen = min_first_seen, retriever->ndpi_proto = -1,
  retriever->elems = (struct flowHostRetrieveList *)calloc(
      sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if (retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return (-1);
  }

  if ((!strcmp(sortColumn, "column_mac")) || (!strcmp(sortColumn, "column_")))
    retriever->sorter = column_mac, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_since"))
    retriever->sorter = column_since, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_thpt"))
    retriever->sorter = column_thpt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_traffic"))
    retriever->sorter = column_traffic, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_hosts"))
    retriever->sorter = column_num_hosts, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_manufacturer"))
    retriever->sorter = column_manufacturer, sorter = stringSorter;
  else if (!strcmp(sortColumn, "column_device_type"))
    retriever->sorter = column_device_type, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_arp_total"))
    retriever->sorter = column_arp_total, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_arp_sent"))
    retriever->sorter = column_arp_sent, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_arp_rcvd"))
    retriever->sorter = column_arp_rcvd, sorter = numericSorter;
  else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s",
                                 sortColumn),
        sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(begin_slot, walk_all, walker_macs, mac_search_walker,
         (void *)retriever);

  qsort(retriever->elems, retriever->actNumEntries,
        sizeof(struct flowHostRetrieveList), sorter);

  return (retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortASes(struct flowHostRetriever *retriever,
                               char *sortColumn) {
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (retriever == NULL) return (-1);

  retriever->actNumEntries = 0, retriever->maxNumEntries = getASesHashSize();
  retriever->elems = (struct flowHostRetrieveList *)calloc(
      sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if (retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return (-1);
  }

  if ((!strcmp(sortColumn, "column_asn")) || (!strcmp(sortColumn, "column_")))
    retriever->sorter = column_asn, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_asname"))
    retriever->sorter = column_asname, sorter = stringSorter;
  else if (!strcmp(sortColumn, "column_score"))
    retriever->sorter = column_score, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_alerted_flows"))
    retriever->sorter = column_alerted_flows, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_since"))
    retriever->sorter = column_since, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_thpt"))
    retriever->sorter = column_thpt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_traffic"))
    retriever->sorter = column_traffic, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_hosts"))
    retriever->sorter = column_num_hosts, sorter = numericSorter;
  else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s",
                                 sortColumn),
        sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all, walker_ases, as_search_walker,
         (void *)retriever);

  qsort(retriever->elems, retriever->actNumEntries,
        sizeof(struct flowHostRetrieveList), sorter);

  return (retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortObsPoints(struct flowHostRetriever *retriever,
                                    char *sortColumn) {
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (retriever == NULL) return (-1);

  retriever->actNumEntries = 0, retriever->maxNumEntries = getObsHashSize();
  retriever->elems = (struct flowHostRetrieveList *)calloc(
      sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if (retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return (-1);
  }

  if ((!strcmp(sortColumn, "column_obs_point")) ||
      (!strcmp(sortColumn, "column_")))
    retriever->sorter = column_obs_point, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score"))
    retriever->sorter = column_score, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_since"))
    retriever->sorter = column_since, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_thpt"))
    retriever->sorter = column_thpt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_traffic"))
    retriever->sorter = column_traffic, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_hosts"))
    retriever->sorter = column_num_hosts, sorter = numericSorter;
  else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s",
                                 sortColumn),
        sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all, walker_obs, obs_point_search_walker,
         (void *)retriever);

  qsort(retriever->elems, retriever->actNumEntries,
        sizeof(struct flowHostRetrieveList), sorter);

  return (retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortOSes(struct flowHostRetriever *retriever,
                               char *sortColumn) {
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (retriever == NULL) return (-1);

  retriever->actNumEntries = 0, retriever->maxNumEntries = getOSesHashSize();
  retriever->elems = (struct flowHostRetrieveList *)calloc(
      sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if (retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return (-1);
  }

  if ((!strcmp(sortColumn, "column_traffic")) ||
      (!strcmp(sortColumn, "column_")))
    retriever->sorter = column_traffic, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_since"))
    retriever->sorter = column_since, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_thpt"))
    retriever->sorter = column_thpt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_hosts"))
    retriever->sorter = column_num_hosts, sorter = numericSorter;
  else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s",
                                 sortColumn),
        sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all, walker_oses, os_search_walker,
         (void *)retriever);

  qsort(retriever->elems, retriever->actNumEntries,
        sizeof(struct flowHostRetrieveList), sorter);

  return (retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortCountries(struct flowHostRetriever *retriever,
                                    char *sortColumn) {
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (retriever == NULL) return (-1);

  retriever->actNumEntries = 0,
  retriever->maxNumEntries = getCountriesHashSize();
  retriever->elems = (struct flowHostRetrieveList *)calloc(
      sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if (retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return (-1);
  }

  if ((!strcmp(sortColumn, "column_country")) ||
      (!strcmp(sortColumn, "column_id")) || (!strcmp(sortColumn, "column_")))
    retriever->sorter = column_country, sorter = stringSorter;
  else if (!strcmp(sortColumn, "column_since"))
    retriever->sorter = column_since, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score"))
    retriever->sorter = column_score, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_hosts"))
    retriever->sorter = column_num_hosts, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_thpt"))
    retriever->sorter = column_thpt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_traffic"))
    retriever->sorter = column_traffic, sorter = numericSorter;
  else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s",
                                 sortColumn),
        sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all, walker_countries, country_search_walker,
         (void *)retriever);

  qsort(retriever->elems, retriever->actNumEntries,
        sizeof(struct flowHostRetrieveList), sorter);

  return (retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortVLANs(struct flowHostRetriever *retriever,
                                char *sortColumn) {
  int (*sorter)(const void *_a, const void *_b);
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (retriever == NULL) return (-1);

  retriever->actNumEntries = 0, retriever->maxNumEntries = getVLANsHashSize();
  retriever->elems = (struct flowHostRetrieveList *)calloc(
      sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if (retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return (-1);
  }

  if ((!strcmp(sortColumn, "column_vlan")) || (!strcmp(sortColumn, "column_")))
    retriever->sorter = column_vlan, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_since"))
    retriever->sorter = column_since, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_thpt"))
    retriever->sorter = column_thpt, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_score"))
    retriever->sorter = column_score, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_traffic"))
    retriever->sorter = column_traffic, sorter = numericSorter;
  else if (!strcmp(sortColumn, "column_hosts"))
    retriever->sorter = column_num_hosts, sorter = numericSorter;
  else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s",
                                 sortColumn),
        sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(&begin_slot, walk_all, walker_vlans, vlan_search_walker,
         (void *)retriever);

  qsort(retriever->elems, retriever->actNumEntries,
        sizeof(struct flowHostRetrieveList), sorter);

  return (retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getActiveHostsList(
    lua_State *vm, u_int32_t *begin_slot, bool walk_all,
    u_int8_t bridge_iface_idx, AddressTree *allowed_hosts, bool host_details,
    LocationPolicy location, char *countryFilter, char *mac_filter,
    u_int16_t vlan_id, OSType osFilter, u_int32_t asnFilter,
    int16_t networkFilter, u_int16_t pool_filter, bool filtered_hosts,
    bool blacklisted_hosts, u_int8_t ipver_filter, int proto_filter,
    TrafficType traffic_type_filter, u_int32_t device_ip, bool tsLua,
    bool anomalousOnly, bool dhcpOnly, const AddressTree *const cidr_filter,
    char *sortColumn, u_int32_t maxHits, u_int32_t toSkip, bool a2zSortOrder) {
  struct flowHostRetriever retriever;

#if DEBUG
  if (!walk_all)
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "[BEGIN] %s(begin_slot=%u, walk_all=%u)",
                                 __FUNCTION__, *begin_slot, walk_all);
#endif

  memset(&retriever, 0, sizeof(struct flowHostRetriever));
  retriever.observationPointId = getLuaVMUservalue(vm, observationPointId);

  if (sortHosts(begin_slot, walk_all, &retriever, bridge_iface_idx,
                allowed_hosts, host_details, location, countryFilter,
                mac_filter, vlan_id, osFilter, asnFilter, networkFilter,
                pool_filter, filtered_hosts, blacklisted_hosts, anomalousOnly,
                dhcpOnly, cidr_filter, ipver_filter, proto_filter,
                traffic_type_filter, device_ip, sortColumn) < 0) {
    return (-1);
  }

#if DEBUG
  if (!walk_all)
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "[END] %s(end_slot=%u, numHosts=%u)", __FUNCTION__,
        *begin_slot, retriever.actNumEntries);
#endif

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numHosts", retriever.actNumEntries);
  lua_push_uint64_table_entry(vm, "nextSlot", *begin_slot);

  lua_newtable(vm);

  if (a2zSortOrder) {
    for (int i = toSkip, num = 0;
         i < (int)retriever.actNumEntries && num < (int)maxHits; i++, num++) {
      Host *h = retriever.elems[i].hostValue;

      if (h != NULL) {
        if (!tsLua)
          h->lua(vm, NULL /* Already checked */, host_details, false, false,
                 true);
        else
          h->lua_get_timeseries(vm);
      }
    }
  } else {
    for (int i = (retriever.actNumEntries - 1 - toSkip), num = 0;
         i >= 0 && num < (int)maxHits; i--, num++) {
      Host *h = retriever.elems[i].hostValue;

      if (h != NULL) {
        if (!tsLua)
          h->lua(vm, NULL /* Already checked */, host_details, false, false,
                 true);
        else
          h->lua_get_timeseries(vm);
      }
    }
  }

  lua_pushstring(vm, "hosts");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  for (u_int i = 0; i < retriever.actNumEntries; i++) {
    if (retriever.elems[i].hostValue)
      retriever.elems[i].hostValue->decUses(); /* See (***) */
  }

  // it's up to us to clean sorted data
  // make sure first to free elements in case a string sorter has been used
  if (retriever.sorter == column_name || retriever.sorter == column_country ||
      retriever.sorter == column_os) {
    for (u_int i = 0; i < retriever.maxNumEntries; i++)
      if (retriever.elems[i].stringValue)
        free((char *)retriever.elems[i].stringValue);
  } else if (retriever.sorter == column_local_network)
    for (u_int i = 0; i < retriever.maxNumEntries; i++)
      if (retriever.elems[i].ipValue) delete retriever.elems[i].ipValue;

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************************** */

struct hosts_get_macs_retriever {
  lua_State *vm;
  int idx;
};

static bool hosts_get_macs(GenericHashEntry *he, void *user_data,
                           bool *matched) {
  struct hosts_get_macs_retriever *r =
      (struct hosts_get_macs_retriever *)user_data;
  Host *host = (Host *)he;
  Mac *mac = host->getMac();
  char mac_buf[32], *mac_ptr;
  char ip_buf[64];

  if (mac && !mac->isSpecialMac() && host->get_ip()) {
    mac_ptr = Utils::formatMac(mac->get_mac(), mac_buf, sizeof(mac_buf));
    lua_getfield(r->vm, r->idx, mac_ptr);

    if (lua_type(r->vm, -1) == LUA_TTABLE) {
      lua_getfield(r->vm, -1, "ip");

      if (lua_type(r->vm, -1) == LUA_TNIL) {
        /* First assignment - create table */
        lua_pop(r->vm, 1);
        lua_pushstring(r->vm, "ip");
        lua_newtable(r->vm);
        lua_settable(r->vm, -3);
        lua_getfield(r->vm, -1, "ip");
      }

      if (lua_type(r->vm, -1) == LUA_TTABLE) {
        /* Add the ip address to the table */
        lua_push_uint64_table_entry(r->vm,
                                    host->get_hostkey(ip_buf, sizeof(ip_buf)),
                                    host->get_ip()->isIPv4() ? 4 : 6);
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

  walker(&begin_slot, walk_all, walker_hosts, hosts_get_macs,
         (void *)&retriever);
  return 0;
}

/* **************************************************** */

static bool flow_stats_walker(GenericHashEntry *h, void *user_data,
                              bool *matched) {
  struct active_flow_stats *stats = (struct active_flow_stats *)user_data;
  Flow *flow = (Flow *)h;

  stats->num_flows++,
      stats->ndpi_bytes[flow->get_detected_protocol().app_protocol] +=
      (u_int32_t)flow->get_bytes(),
      stats->breeds_bytes[flow->get_protocol_breed()] +=
      (u_int32_t)flow->get_bytes();

  *matched = true;

  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getFlowsStats(lua_State *vm) {
  struct active_flow_stats stats;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&stats, 0, sizeof(stats));
  walker(&begin_slot, walk_all, walker_flows, flow_stats_walker,
         (void *)&stats);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "num_flows", stats.num_flows);
  lua_newtable(vm);
  for (int i = 0;
       i < NDPI_MAX_SUPPORTED_PROTOCOLS + NDPI_MAX_NUM_CUSTOM_PROTOCOLS; i++) {
    if (stats.ndpi_bytes[i] > 0)
      lua_push_uint64_table_entry(vm, ndpi_get_proto_name(get_ndpi_struct(), i),
                                  stats.ndpi_bytes[i]);
  }

  lua_pushstring(vm, "protos");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  for (int i = 0; i < NUM_BREEDS; i++) {
    if (stats.breeds_bytes[i] > 0)
      lua_push_uint64_table_entry(
          vm,
          ndpi_get_proto_breed_name(get_ndpi_struct(),
                                    (ndpi_protocol_breed_t)i),
          stats.breeds_bytes[i]);
  }

  lua_pushstring(vm, "breeds");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* **************************************************** */

void NetworkInterface::getNetworkStats(lua_State *vm, u_int16_t network_id,
                                       AddressTree *allowed_hosts,
                                       bool diff) const {
  NetworkStats *network_stats;

  if ((network_stats = getNetworkStats(network_id)) &&
      network_stats->trafficSeen() && network_stats->match(allowed_hosts)) {
    lua_newtable(vm);

    network_stats->lua(vm, diff);

    lua_push_int32_table_entry(vm, "network_id", network_id);
    lua_pushstring(vm, ntop->getLocalNetworkName(network_id));
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* **************************************************** */

void NetworkInterface::getNetworksStats(lua_State *vm,
                                        AddressTree *allowed_hosts,
                                        bool diff) const {
  u_int16_t num_local_networks = ntop->getNumLocalNetworks();

  lua_newtable(vm);

  for (u_int16_t network_id = 0; network_id < num_local_networks; network_id++)
    getNetworkStats(vm, network_id, allowed_hosts, diff);
}

/* **************************************************** */

/* Used to give the interface a new check loader to be used */
void NetworkInterface::reloadFlowChecks(FlowChecksLoader *fcbl) {
  /* Reload of the checks for this interface (e.g., interface type matters) */
  FlowChecksExecutor *fce = new (std::nothrow) FlowChecksExecutor(fcbl, this);

  if (fce == NULL) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to reload checks on interface %s", ifname);
    return;
  }

  if (prev_flow_checks_executor) delete prev_flow_checks_executor;
  prev_flow_checks_executor = flow_checks_executor;
  flow_checks_executor = fce;
}

/* **************************************************** */

/* Used to give the interface a new check loader to be used */
void NetworkInterface::reloadHostChecks(HostChecksLoader *hcbl) {
  /* Reload of the checks for this interface (e.g., interface type matters) */
  HostChecksExecutor *hce = new (std::nothrow) HostChecksExecutor(hcbl, this);

  if (hce == NULL) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Unable to reload checks on interface %s", ifname);
    return;
  }

  if (prev_host_checks_executor) delete prev_host_checks_executor;
  prev_host_checks_executor = host_checks_executor;
  host_checks_executor = hce;
}

/* **************************************************** */

u_int NetworkInterface::purgeIdleFlows(bool force_idle, bool full_scan) {
  u_int n = 0;
  time_t last_packet_time = getTimeLastPktRcvd();

  pollQueuedeCompanionEvents();

  if (!force_idle && !full_scan && last_packet_time < next_idle_flow_purge) {
    return (0); /* Too early */
  } else {
    /* Time to purge flows */
    const struct timeval tv = periodicUpdateInitTime();

#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Purging idle flows [ifname: %s] [ifid: %i] [current size: %i] [full scan: %s]",
				 ifname, id, flows_hash->getNumEntries(), full_scan ? "True" : "False");
#endif
    n = (flows_hash ? flows_hash->purgeIdle(&tv, force_idle, full_scan) : 0);

#ifdef NTOPNG_PRO
    ntop->getPro()->purgeIdleFlows(force_idle);
#endif

    next_idle_flow_purge = last_packet_time + FLOW_PURGE_FREQUENCY;
    return (n);
  }
}

/* **************************************************** */

u_int64_t NetworkInterface::getNumPackets() {
  return (ethStats.getNumPackets());
};

/* **************************************************** */

u_int64_t NetworkInterface::getNumBytes() { return (ethStats.getNumBytes()); }

/* **************************************************** */

u_int64_t NetworkInterface::getNumDroppedAlerts() {
  return num_host_dropped_alerts + num_flow_dropped_alerts +
         num_other_dropped_alerts;
}

/* **************************************************** */

u_int32_t NetworkInterface::getNumPacketDrops() {
  return (!isSubInterface() ? getNumDroppedPackets() : 0);
};

/* **************************************************** */

u_int64_t NetworkInterface::getNumNewFlows() { return (num_new_flows); };

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
  return (flows_hash ? flows_hash->getNumEntries() : 0);
};

/* **************************************************** */

u_int NetworkInterface::getNumHTTPHosts() {
  return (hosts_hash ? hosts_hash->getNumHTTPEntries() : 0);
};

/* **************************************************** */

u_int NetworkInterface::getNumMacs() {
  return (macs_hash ? macs_hash->getNumEntries() : 0);
};

/* **************************************************** */

u_int NetworkInterface::purgeIdleHosts(bool force_idle, bool full_scan) {
  time_t last_packet_time = getTimeLastPktRcvd();

  if (!force_idle && !full_scan && last_packet_time < next_idle_host_purge)
    return (0); /* Too early */
  else {
    /* Time to purge hosts */
    const struct timeval tv = periodicUpdateInitTime();
    u_int n;
    /* If the interface is no longer running it is safe to force all entries as
     * idle */

#if 0
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "Purging idle hosts [ifname: %s] [ifid: %i] [current size: %i]",
				 ifname, id, hosts_hash->getNumEntries());
#endif

    // ntop->getTrace()->traceEvent(TRACE_INFO, "Purging idle hosts");
    n = (hosts_hash ? hosts_hash->purgeIdle(&tv, force_idle, full_scan) : 0);

    next_idle_host_purge = last_packet_time + HOST_PURGE_FREQUENCY;
    return (n);
  }
}

/* **************************************************** */

u_int NetworkInterface::purgeIdleMacsASesCountriesVLANs(bool force_idle,
                                                        bool full_scan) {
  time_t last_packet_time = getTimeLastPktRcvd();

  if (!force_idle && !full_scan && last_packet_time < next_idle_other_purge)
    return (0); /* Too early */
  else {
    /* Time to purge */
    const struct timeval tv = periodicUpdateInitTime();
    u_int n;
    /* If the interface is no longer running it is safe to force all entries as
     * idle */

    n = (macs_hash ? macs_hash->purgeIdle(&tv, force_idle, full_scan) : 0) +
        (ases_hash ? ases_hash->purgeIdle(&tv, force_idle, full_scan) : 0) +
        (oses_hash ? oses_hash->purgeIdle(&tv, force_idle, full_scan) : 0) +
        (countries_hash ? countries_hash->purgeIdle(&tv, force_idle, full_scan)
                        : 0) +
        (vlans_hash ? vlans_hash->purgeIdle(&tv, force_idle, full_scan) : 0) +
        (obs_hash ? obs_hash->purgeIdle(&tv, force_idle, full_scan) : 0);

    next_idle_other_purge = last_packet_time + OTHER_PURGE_FREQUENCY;

    return (n);
  }
}

/* **************************************************** */

void NetworkInterface::getnDPIProtocols(lua_State *vm,
                                        ndpi_protocol_category_t filter,
                                        bool skip_critical) {
  int i;
  u_int num_supported_protocols =
      ndpi_get_ndpi_num_supported_protocols(get_ndpi_struct());
  ndpi_proto_defaults_t *proto_defaults =
      ndpi_get_proto_defaults(get_ndpi_struct());

  lua_newtable(vm);

  for (i = 0; i < (int)num_supported_protocols; i++) {
    char buf[16];

    if (((filter == NDPI_PROTOCOL_ANY_CATEGORY) ||
         proto_defaults[i].protoCategory == filter) &&
        (!skip_critical || !Utils::isCriticalNetworkProtocol(i))) {
      snprintf(buf, sizeof(buf) - 1, "%d", i);
      if (!proto_defaults[i].protoName)
        ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                     "NULL protoname for index %d!!", i);
      else
        lua_push_str_table_entry(vm, proto_defaults[i].protoName, buf);
    }
  }
}

/* **************************************************** */

#define NUM_TCP_STATES 4
/*
  0 = RST
  1 = SYN
  2 = Established
  3 = FIN
*/

static bool num_flows_state_walker(GenericHashEntry *node, void *user_data,
                                   bool *matched) {
  Flow *flow = (Flow *)node;
  u_int32_t *num_flows = (u_int32_t *)user_data;

  if (flow->get_protocol() == IPPROTO_TCP) {
    if (flow->isTCPEstablished())
      num_flows[2]++;
    else if (flow->isTCPConnecting())
      num_flows[1]++;
    else if (flow->isTCPReset())
      num_flows[0]++;
    else if (flow->isTCPClosed())
      num_flows[3]++;
  }

  *matched = true;

  return (false /* keep walking */);
}

/* *************************************** */

static bool num_flows_walker(GenericHashEntry *node, void *user_data,
                             bool *matched) {
  Flow *flow = (Flow *)node;
  u_int32_t *num_flows = (u_int32_t *)user_data;

  num_flows[flow->get_detected_protocol().app_protocol]++;
  *matched = true;

  return (false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::getFlowsStatus(lua_State *vm) {
  u_int32_t num_flows[NUM_TCP_STATES] = {0};
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  walker(&begin_slot, walk_all, walker_flows, num_flows_state_walker,
         num_flows);

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
  u_int num_supported_protocols =
      ndpi_get_ndpi_num_supported_protocols(get_ndpi_struct());
  ndpi_proto_defaults_t *proto_defaults =
      ndpi_get_proto_defaults(get_ndpi_struct());

  num_flows = (u_int32_t *)calloc(num_supported_protocols, sizeof(u_int32_t));

  if (num_flows) {
    walker(&begin_slot, walk_all, walker_flows, num_flows_walker, num_flows);

    for (int i = 0; i < (int)num_supported_protocols; i++) {
      if (num_flows[i] > 0)
        lua_push_uint64_table_entry(vm, proto_defaults[i].protoName,
                                    num_flows[i]);
    }

    free(num_flows);
  }
}

/* *************************************** */

void NetworkInterface::sumStats(
    TcpFlowStats *_tcpFlowStats, EthStats *_ethStats,
    LocalTrafficStats *_localStats, nDPIStats *_ndpiStats,
    PacketStats *_pktStats, TcpPacketStats *_tcpPacketStats,
    ProtoStats *_discardedProbingStats, DSCPStats *_dscpStats,
    SyslogStats *_syslogStats, RoundTripStats *_downloadStats,
    RoundTripStats *_uploadStats) const {
  tcpFlowStats.sum(_tcpFlowStats), ethStats.sum(_ethStats),
      localStats.sum(_localStats), pktStats.sum(_pktStats),
      tcpPacketStats.sum(_tcpPacketStats),
      discardedProbingStats.sum(_discardedProbingStats),
      syslogStats.sum(_syslogStats);

  if (ndpiStats && _ndpiStats) ndpiStats->sum(_ndpiStats);

  if (dscpStats && _dscpStats) dscpStats->sum(_dscpStats);

  if (download_stats && _downloadStats) download_stats->sum(_downloadStats);

  if (upload_stats && _uploadStats) upload_stats->sum(_uploadStats);
}

/* *************************************** */

void NetworkInterface::lua(lua_State *vm) {
  char buf[32];
  TcpFlowStats _tcpFlowStats;
  EthStats _ethStats;
  RoundTripStats _downloadStats;
  RoundTripStats _uploadStats;
  LocalTrafficStats _localStats;
  PacketStats _pktStats;
  TcpPacketStats _tcpPacketStats;
  ProtoStats _discardedProbingStats;
  DSCPStats _dscpStats;
  SyslogStats _syslogStats;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "name", get_name());
  lua_push_str_table_entry(vm, "description", get_description());
  lua_push_uint64_table_entry(vm, "scalingFactor", getScalingFactor());
  lua_push_int32_table_entry(vm, "id", id);
  lua_push_str_table_entry(vm, "mac",
                           Utils::formatMac(ifMac, buf, sizeof(buf)));
  if (customIftype)
    lua_push_str_table_entry(vm, "customIftype", (char *)customIftype);
  lua_push_bool_table_entry(vm, "isView", isView());     /* View interface */
  lua_push_bool_table_entry(vm, "isViewed", isViewed()); /* Viewed interface */
  lua_push_bool_table_entry(
      vm, "isSampledTraffic",
      isSampledTraffic()); /* Whether this interface has sampled traffic */
  if (isSubInterface()) luaSubInterface(vm);
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
  lua_push_bool_table_entry(
      vm, "hasSubInterfaces",
      (sub_interfaces && sub_interfaces->getNumSubInterfaces()) ||
          (flowHashingMode != flowhashing_none));
#endif
#endif

  lua_push_bool_table_entry(vm, "isFlowDumpDisabled", isFlowDumpDisabled());
  lua_push_bool_table_entry(vm, "isFlowDumpRunning", db != NULL);
  lua_push_uint64_table_entry(vm, "seen.last", getTimeLastPktRcvd());
  lua_push_bool_table_entry(vm, "inline", get_inline_interface());
  lua_push_bool_table_entry(vm, "vlan", hasSeenVLANTaggedPackets());
  lua_push_bool_table_entry(vm, "has_macs", hasSeenMacAddresses());
  lua_push_bool_table_entry(vm, "has_seen_dhcp_addresses",
                            hasSeenDHCPAddresses());
  /* Note: source MAC is now used to get traffic direction when not
   * areTrafficDirectionsSupported() */
  lua_push_bool_table_entry(
      vm, "has_traffic_directions",
      (areTrafficDirectionsSupported() || (!Utils::isEmptyMac(ifMac))) && (!isLoopback()) /* && (!isTrafficMirrored() || isGwMacConfigured())*/);
  lua_push_bool_table_entry(vm, "has_seen_pods", hasSeenPods());
  lua_push_bool_table_entry(vm, "has_seen_containers", hasSeenContainers());
  lua_push_bool_table_entry(vm, "has_seen_external_alerts",
                            hasSeenExternalAlerts());
  lua_push_bool_table_entry(vm, "has_seen_ebpf_events", hasSeenEBPFEvents());

  luaNumEngagedAlerts(vm);
  luaAlertedFlows(vm);
  lua_push_uint64_table_entry(vm, "num_dropped_alerts",
                              getNumDroppedAlertsSinceReset());

  /* Those counters are absolute, i.e., they are not subject to reset */
  lua_push_uint64_table_entry(vm, "num_host_dropped_alerts",
                              num_host_dropped_alerts);
  lua_push_uint64_table_entry(vm, "num_flow_dropped_alerts",
                              num_flow_dropped_alerts);
  lua_push_uint64_table_entry(vm, "num_other_dropped_alerts",
                              num_other_dropped_alerts);

  lua_push_uint64_table_entry(vm, "periodic_stats_update_frequency_secs",
                              periodicStatsUpdateFrequency());

  /* .stats */
  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "packets", getNumPackets());
  lua_push_uint64_table_entry(vm, "bytes", getNumBytes());
  lua_push_uint64_table_entry(vm, "flows", getNumFlows());
  lua_push_uint64_table_entry(vm, "hosts", getNumHosts());
  lua_push_uint64_table_entry(vm, "hosts_rcvd_only", getNumRxOnlyHosts());
  lua_push_uint64_table_entry(vm, "local_hosts", getNumLocalHosts());
  lua_push_uint64_table_entry(vm, "local_rcvd_only_hosts",
                              getNumLocalRxOnlyHosts());
  lua_push_uint64_table_entry(vm, "http_hosts", getNumHTTPHosts());
  lua_push_uint64_table_entry(vm, "drops", getNumPacketDrops());
  lua_push_uint64_table_entry(vm, "new_flows", getNumNewFlows());
  lua_push_uint64_table_entry(vm, "devices", getNumL2Devices());
  lua_push_uint64_table_entry(vm, "current_macs", getNumMacs());
  lua_push_uint64_table_entry(vm, "num_live_captures", num_live_captures);
  lua_push_float_table_entry(vm, "throughput_bps", bytes_thpt.getThpt());
  lua_push_uint64_table_entry(vm, "throughput_trend_bps",
                              bytes_thpt.getTrend());
  lua_push_float_table_entry(vm, "throughput_pps", pkts_thpt.getThpt());
  lua_push_uint64_table_entry(vm, "throughput_trend_pps", pkts_thpt.getTrend());
  l4Stats.luaStats(vm);

  if (db) db->lua(vm, false /* Overall */);

  usedPorts.lua(vm, this);

  lua_pushstring(vm, "stats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "packets", getNumPacketsSinceReset());
  lua_push_uint64_table_entry(vm, "bytes", getNumBytesSinceReset());
  lua_push_uint64_table_entry(vm, "drops", getNumPacketDropsSinceReset());

  if (db) db->lua(vm, true /* Since last checkpoint */);

  if (discardProbingTraffic()) {
    lua_push_uint64_table_entry(vm, "discarded_probing_packets",
                                getNumDiscProbingPktsSinceReset());
    lua_push_uint64_table_entry(vm, "discarded_probing_bytes",
                                getNumDiscProbingBytesSinceReset());
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
  lua_push_str_table_entry(vm, "type", get_type());
  lua_push_uint64_table_entry(vm, "speed", ifSpeed);
  lua_push_uint64_table_entry(vm, "mtu", ifMTU);
  lua_push_str_table_entry(vm, "ip_addresses", (char *)getLocalIPAddresses());

  bcast_domains->lua(vm);

  if (top_sites && ntop->getPrefs()->are_top_talkers_enabled())
    top_sites->lua(vm, (char *)"sites", (char *)"sites.old");

  luaAnomalies(vm);
  luaScore(vm);

  sumStats(&_tcpFlowStats, &_ethStats, &_localStats, NULL, &_pktStats,
           &_tcpPacketStats, &_discardedProbingStats, &_dscpStats,
           &_syslogStats, &_downloadStats, &_uploadStats);

  _downloadStats.luaRTStats(vm, "download_stats");
  _uploadStats.luaRTStats(vm, "upload_stats");

  _tcpFlowStats.lua(vm, "tcpFlowStats");
  _ethStats.lua(vm);
  _localStats.lua(vm);
  luaNdpiStats(vm);

  _pktStats.lua(vm, "pktSizeDistribution");
  _tcpPacketStats.lua(vm, "tcpPacketStats");
  _dscpStats.lua(this, vm);
  _syslogStats.lua(vm);

  if (discardProbingTraffic())
    _discardedProbingStats.lua(vm, "discarded_probing_");

  if (!isView()) {
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
    if (flow_profiles) flow_profiles->lua(vm);
#endif
#endif
  }

  if (host_pools) host_pools->lua(vm);

#ifdef NTOPNG_PRO
  traffic_rx_behavior->luaBehavior(vm, "traffic_rx_behavior");
  traffic_tx_behavior->luaBehavior(vm, "traffic_tx_behavior");
  score_behavior->luaBehavior(vm, "score_behavior");

  if (custom_app_stats) custom_app_stats->lua(vm);

  if (pMap) pMap->lua(vm, "periodicity_map");
  if (sMap) sMap->lua(vm, "service_map");
#endif
}

/* *************************************** */

void NetworkInterface::luaSubInterface(lua_State *vm) {
  char buf[64];

  switch (dynamic_interface_mode) {
    case flowhashing_probe_ip:
      lua_push_str_table_entry(
          vm, "dynamic_interface_probe_ip",
          Utils::intoaV4(dynamic_interface_criteria, buf, sizeof(buf)));
      break;
    case flowhashing_probe_ip_and_ingress_iface_idx:
      lua_push_str_table_entry(
          vm, "dynamic_interface_probe_ip",
          Utils::intoaV4(dynamic_interface_criteria >> 32, buf, sizeof(buf)));
      lua_push_uint64_table_entry(vm, "dynamic_interface_inifidx",
                                  dynamic_interface_criteria & 0xFFFFFFFF);
      break;
    default:
      break;
  }
}

/* *************************************** */

void NetworkInterface::luaServiceMapStatus(lua_State *vm) {
#if defined(NTOPNG_PRO)
  lua_newtable(vm);

  if (sMap)
    lua_push_bool_table_entry(vm, "service_map_learning_status",
                              sMap->isLearning());
#endif
}

/* *************************************** */

void NetworkInterface::lua_hash_tables_stats(lua_State *vm) {
  /* Hash tables stats */
  GenericHash *gh[] = {flows_hash, hosts_hash, macs_hash,      vlans_hash,
                       ases_hash,  oses_hash,  countries_hash, obs_hash};

  lua_newtable(vm);

  for (u_int i = 0; i < sizeof(gh) / sizeof(gh[0]); i++) {
    if (gh[i]) gh[i]->lua(vm);
  }
}

/* *************************************** */

void NetworkInterface::lua_periodic_activities_stats(lua_State *vm) {
  lua_newtable(vm);

  /* Periodic activities stats */
  ntop->lua_periodic_activities_stats(this, vm);
}

/* **************************************************** */

void NetworkInterface::lua_queues_stats(lua_State *vm) {
  if (idleFlowsToDump) idleFlowsToDump->lua(vm);
  if (activeFlowsToDump) activeFlowsToDump->lua(vm);
  if (flowAlertsQueue) flowAlertsQueue->lua(vm);
}

/* **************************************************** */

void NetworkInterface::runHousekeepingTasks() { periodicStatsUpdate(); }

/* **************************************************** */

void NetworkInterface::runShutdownTasks() {
  /* NOTE NOTE NOTE
   *  This task runs asynchronously with respect to the datapath
   *  which has been already stopped
   */

  /* Run the periodic stats update one last time so certain tasks can be
     properly finalized, e.g., all hosts and all flows can be marked as idle */
  periodicStatsUpdate();

#ifdef NTOPNG_PRO
  flushFlowDump();
#endif
}

/* **************************************************** */

Mac *NetworkInterface::getMac(u_int8_t _mac[6], bool create_if_not_present,
                              bool isInlineCall) {
  Mac *ret = NULL;

  if (!_mac || !macs_hash) return (NULL);

  ret = macs_hash->get(_mac, isInlineCall);

  if ((ret == NULL) && create_if_not_present) {
    if (!macs_hash->hasEmptyRoom()) return (NULL);

    try {
      if ((ret = new Mac(this, _mac)) != NULL) {
        if(!macs_hash->add(ret,
			   !isInlineCall /* Lock only if not inline, if inline there's no need to lock as also the purgeIdle is done inline*/)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
          delete ret;
          return (NULL);
        }
      }
    } catch (std::bad_alloc &ba) {
      static bool oom_warning_sent = false;

      if (!oom_warning_sent) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
        oom_warning_sent = true;
      }

      return (NULL);
    }
  }

  return (ret);
}

/* **************************************************** */

VLAN *NetworkInterface::getVLAN(u_int16_t u_int16_t, bool create_if_not_present,
                                bool isInlineCall) {
  VLAN *ret = NULL;

  if (!vlans_hash) return (NULL);

  ret = vlans_hash->get(u_int16_t, isInlineCall);

  if ((ret == NULL) && create_if_not_present) {
    if (!vlans_hash->hasEmptyRoom()) return (NULL);

    try {
      if ((ret = new VLAN(this, u_int16_t)) != NULL) {
        if(!vlans_hash->add(ret,
			    !isInlineCall /* Lock only if not inline, if inline there is no need to lock as we are sequential with the purgeIdle */)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
          delete ret;
          return (NULL);
        }
      }
    } catch (std::bad_alloc &ba) {
      static bool oom_warning_sent = false;

      if (!oom_warning_sent) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
        oom_warning_sent = true;
      }

      return (NULL);
    }
  }

  return (ret);
}

/* **************************************************** */

AutonomousSystem *NetworkInterface::getAS(IpAddress *ipa,
                                          bool create_if_not_present,
                                          bool is_inline_call) {
  AutonomousSystem *ret = NULL;

  if ((!ipa) || (!ases_hash)) return (NULL);

  ret = ases_hash->get(ipa, is_inline_call);

  if ((ret == NULL) && create_if_not_present) {
    if (!ases_hash->hasEmptyRoom()) return (NULL);

    try {
      if ((ret = new AutonomousSystem(this, ipa)) != NULL) {
        if(!ases_hash->add(ret,
			   !is_inline_call /* Lock only if not inline, if inline there is no need to lock as we are sequential with the purgeIdle */)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
          delete ret;
          return (NULL);
        }
      }
    } catch (std::bad_alloc &ba) {
      static bool oom_warning_sent = false;

      if (!oom_warning_sent) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
        oom_warning_sent = true;
      }

      return (NULL);
    }
  }

  return (ret);
}

/* **************************************************** */

ObservationPoint *NetworkInterface::getObsPoint(u_int16_t obs_point,
                                                bool create_if_not_present,
                                                bool is_inline_call) {
  ObservationPoint *ret = NULL;

  if ((!obs_point) || (obs_point == (u_int16_t)-1) || (!obs_hash))
    return (NULL);

  ret = obs_hash->get(obs_point, is_inline_call);

  if ((ret == NULL) && create_if_not_present) {
    if (!obs_hash->hasEmptyRoom()) return (NULL);

    try {
      if ((ret = new ObservationPoint(this, obs_point)) != NULL) {
        if(!obs_hash->add(ret,
			  !is_inline_call /* Lock only if not inline, if inline there is no need to lock as we are sequential with the purgeIdle */)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
          delete ret;
          return (NULL);
        }
      }
    } catch (std::bad_alloc &ba) {
      static bool oom_warning_sent = false;

      if (!oom_warning_sent) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
        oom_warning_sent = true;
      }

      return (NULL);
    }
  }
  last_obs_point_id = obs_point;

  return (ret);
}

/* **************************************************** */

bool NetworkInterface::deleteObsPoint(u_int16_t obs_point) {
  ObservationPoint *ret = NULL;

  /* Invalid args given */
  if ((!obs_point) || (obs_point == (u_int16_t)-1) || (!obs_hash))
    return (false);

  ret = obs_hash->get(obs_point, true);

  /* Observation Point found, delete it */
  if (ret != NULL) ret->deleteObsStats();

  return (true);
}

/* **************************************************** */

bool NetworkInterface::prepareDeleteObsPoint(u_int16_t obs_point) {
  ObservationPoint *ret = NULL;

  /* Invalid args given */
  if ((!obs_point) || (obs_point == (u_int16_t)-1) || (!obs_hash))
    return (false);

  ret = obs_hash->get(obs_point, true);

  /* Observation Point found, delete it */
  if (ret != NULL) ret->setDeleteRequested(true);

  return (true);
}

/* **************************************************** */

OperatingSystem *NetworkInterface::getOS(OSType os_type,
                                         bool create_if_not_present,
                                         bool is_inline_call) {
  OperatingSystem *ret = NULL;

  if (!oses_hash) return (NULL);

  ret = oses_hash->get(os_type, is_inline_call);

  if ((ret == NULL) && create_if_not_present) {
    if (!oses_hash->hasEmptyRoom()) return (NULL);

    try {
      if ((ret = new OperatingSystem(this, os_type)) != NULL) {
        if(!oses_hash->add(ret,
			   !is_inline_call /* Lock only if not inline, if inline there is no need to lock as we are sequential with the purgeIdle */)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
          delete ret;
          return (NULL);
        }
      }
    } catch (std::bad_alloc &ba) {
      static bool oom_warning_sent = false;

      if (!oom_warning_sent) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
        oom_warning_sent = true;
      }

      return (NULL);
    }
  }

  return (ret);
}

/* **************************************************** */

Country *NetworkInterface::getCountry(const char *country_name,
                                      bool create_if_not_present,
                                      bool is_inline_call) {
  Country *ret = NULL;

  if ((!countries_hash) || (!country_name) || (!country_name[0])) return (NULL);

  ret = countries_hash->get(country_name, is_inline_call);

  if ((ret == NULL) && create_if_not_present) {
    if (!countries_hash->hasEmptyRoom()) return (NULL);

    try {
      if ((ret = new Country(this, country_name)) != NULL) {
        if(!countries_hash->add(ret, !is_inline_call /* Lock only if not inline, if inline there is no need to lock as we are sequential with the purgeIdle */)) {
          /* Note: this should never happen as we are checking hasEmptyRoom() */
          delete ret;
          return (NULL);
        }
      }
    } catch (std::bad_alloc &ba) {
      static bool oom_warning_sent = false;

      if (!oom_warning_sent) {
        ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
        oom_warning_sent = true;
      }

      return (NULL);
    }
  }

  return (ret);
}

/* **************************************************** */

Flow *NetworkInterface::findFlowByKeyAndHashId(u_int32_t key, u_int hash_id,
                                               AddressTree *allowed_hosts) {
  Flow *f = NULL;

  if (!flows_hash) return (NULL);

  f = flows_hash->findByKeyAndHashId(key, hash_id);

  if (f && (!f->match(allowed_hosts))) f = NULL;

  return (f);
}

/* **************************************************** */

Flow *NetworkInterface::findFlowByTuple(u_int16_t vlan_id,
                                        u_int16_t observation_domain_id,
                                        u_int32_t private_flow_id, Mac *src_mac,
                                        Mac *dst_mac, IpAddress *src_ip,
                                        IpAddress *dst_ip, u_int16_t src_port,
                                        u_int16_t dst_port, u_int8_t l4_proto,
                                        AddressTree *allowed_hosts) const {
  bool src2dst;
  Flow *f, *unswapped_flow;

  if (!flows_hash) return (NULL);

  f = (Flow *)flows_hash->find(src_mac, dst_mac, src_ip, dst_ip, src_port,
                               dst_port, vlan_id, observation_domain_id,
                               private_flow_id, l4_proto, NULL, &src2dst,
                               false /* Not an inline call */, &unswapped_flow);

  if (f && (!f->match(allowed_hosts))) f = NULL;

  return (f);
}

/* **************************************************** */

struct search_host_info {
  lua_State *vm;
  char *host_name_or_ip;
  u_int num_matches;
  AddressTree *allowed_hosts;
};

/* **************************************************** */

static bool hosts_search_walker(GenericHashEntry *h, void *user_data,
                                bool *matched) {
  Host *host = (Host *)h;
  struct search_host_info *info = (struct search_host_info *)user_data;

  if (host->addIfMatching(info->vm, info->allowed_hosts,
                          info->host_name_or_ip)) {
    info->num_matches++;
    *matched = true;
  }

  /* Stop after CONST_MAX_NUM_FIND_HITS matches */
  return ((info->num_matches > CONST_MAX_NUM_FIND_HITS)
              ? true /* stop */
              : false /* keep walking */);
}

/* **************************************************** */

struct search_mac_info {
  lua_State *vm;
  u_int8_t *mac;
  u_int num_matches;
};

/* **************************************************** */

struct search_bost_by_mac {
  u_int8_t *mac;
  Host *match;
};

/* **************************************************** */

static bool macs_search_walker(GenericHashEntry *h, void *user_data,
                               bool *matched) {
  Host *host = (Host *)h;
  struct search_mac_info *info = (struct search_mac_info *)user_data;

  if (host->addIfMatching(info->vm, info->mac)) {
    info->num_matches++;
    *matched = true;
  }

  /* Stop after CONST_MAX_NUM_FIND_HITS matches */
  return ((info->num_matches > CONST_MAX_NUM_FIND_HITS)
              ? true /* stop */
              : false /* keep walking */);
}

/* **************************************************** */

static bool first_mac_search_walker(GenericHashEntry *h, void *user_data,
                                    bool *matched) {
  Host *host = (Host *)h;
  struct search_bost_by_mac *info = (struct search_bost_by_mac *)user_data;

  if (memcmp(info->mac, host->get_mac(), 6) == 0) {
    info->match = host;
    return (true /* stop */);
  } else
    return (false);
}

/* *************************************** */

bool NetworkInterface::findHostsByMac(lua_State *vm, u_int8_t *mac) {
  struct search_mac_info info;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  info.vm = vm, info.mac = mac, info.num_matches = 0;

  lua_newtable(vm);
  walker(&begin_slot, walk_all, walker_hosts, macs_search_walker,
         (void *)&info);
  return (info.num_matches > 0);
}

/* **************************************************** */

Host *NetworkInterface::findHostByMac(u_int8_t *mac) {
  struct search_bost_by_mac info;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  info.mac = mac, info.match = NULL;

  walker(&begin_slot, walk_all, walker_hosts, first_mac_search_walker,
         (void *)&info);

#if 0
  if(info.match) {
    char buf[64], buf1[64];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "*** %s %s ***",
				 info.match->get_visual_name(buf, sizeof(buf)),
				 info.match->printMask(buf1, sizeof(buf1)));
  }
#endif

  return (info.match);
}

/* **************************************************** */

bool NetworkInterface::findHostsByName(lua_State *vm,
                                       AddressTree *allowed_hosts, char *key) {
  struct search_host_info info;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  info.vm = vm, info.host_name_or_ip = key, info.num_matches = 0,
  info.allowed_hosts = allowed_hosts;

  lua_newtable(vm);
  walker(&begin_slot, walk_all, walker_hosts, hosts_search_walker,
         (void *)&info);
  return (info.num_matches > 0);
}

/* **************************************************** */

u_int NetworkInterface::printAvailableInterfaces(bool printHelp, int idx,
                                                 char *ifname,
                                                 u_int ifname_len) {
  int numInterfaces = 0;
  ntop_if_t *devpointer, *cur;

  if (printHelp && help_printed) return (0);

  if (Utils::ntop_findalldevs(&devpointer)) {
    ;
  } else {
    if (ifname == NULL) {
      if (printHelp)
        printf("Available interfaces (-i <interface index>):\n");
      else if (!help_printed)
        ntop->getTrace()->traceEvent(
            TRACE_NORMAL, "Available interfaces (-i <interface index>):");
    }

    for (cur = devpointer; cur; cur = cur->next) {
      if (Utils::validInterface(cur)) {
        numInterfaces++;

        if (ifname == NULL) {
          if (printHelp) {
#ifdef WIN32
            printf(
                "   %d. %s\n"
                "\t%s\n",
                numInterfaces, cur->description ? cur->description : "",
                cur->name);
#else
            printf("   %d. %s\n", numInterfaces, cur->name);
#endif
          } else if (!help_printed)
            ntop->getTrace()->traceEvent(
                TRACE_NORMAL, "%d. %s (%s)\n", numInterfaces, cur->name,
                cur->description ? cur->description : cur->name);
        } else if (numInterfaces == idx) {
          snprintf(ifname, ifname_len, "%s", cur->name);
          break;
        }
      }
    } /* for */

    Utils::ntop_freealldevs(devpointer);
  } /* else */

  if (numInterfaces == 0) {
#ifdef WIN32
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "No interfaces available! This application cannot work");
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "Make sure that https://nmap.org/npcap/ is installed,");
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "that you have administrative rights,");
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "and that you have network interfaces installed.");
#else
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "No interfaces available: are you superuser?");
#endif
  }

  help_printed = true;

  return (numInterfaces);
}

/* **************************************************** */

bool NetworkInterface::isNumber(const char *str) {
  while (*str) {
    if (!isdigit(*str)) return (false);

    str++;
  }

  return (true);
}

/* **************************************************** */

struct proc_name_flows {
  lua_State *vm;
  char *proc_name;
};

static bool proc_name_finder_walker(GenericHashEntry *node, void *user_data,
                                    bool *matched) {
  Flow *f = (Flow *)node;
  struct proc_name_flows *info = (struct proc_name_flows *)user_data;
  char *name = f->get_proc_name(true);

  if (name && (strcmp(name, info->proc_name) == 0)) {
    f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
    lua_pushinteger(info->vm, f->key());  // Key
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
  } else {
    name = f->get_proc_name(false);

    if (name && (strcmp(name, info->proc_name) == 0)) {
      f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
      lua_pushinteger(info->vm, f->key());  // Key
      lua_insert(info->vm, -2);
      lua_settable(info->vm, -3);
    }
  }
  *matched = true;

  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::findProcNameFlows(lua_State *vm, char *proc_name) {
  struct proc_name_flows u;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  u.vm = vm, u.proc_name = proc_name;

  lua_newtable(vm);
  walker(&begin_slot, walk_all, walker_flows, proc_name_finder_walker, &u);
}

/* **************************************************** */

struct pid_flows {
  lua_State *vm;
  u_int32_t pid;
};

static bool pidfinder_walker(GenericHashEntry *node, void *pid_data,
                             bool *matched) {
  Flow *f = (Flow *)node;
  struct pid_flows *info = (struct pid_flows *)pid_data;

  if ((f->getPid(true) == info->pid) || (f->getPid(false) == info->pid)) {
    f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
    lua_pushinteger(info->vm, f->key());  // Key
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
    *matched = true;
  }

  return (false); /* false = keep on walking */
}

/* **************************************** */

void NetworkInterface::findPidFlows(lua_State *vm, u_int32_t pid) {
  struct pid_flows u;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  u.vm = vm, u.pid = pid;

  lua_newtable(vm);
  walker(&begin_slot, walk_all, walker_flows, pidfinder_walker, &u);
}

/* **************************************** */

struct virtual_host_valk_info {
  lua_State *vm;
  char *key;
  u_int32_t num;
};

/* **************************************** */

static bool virtual_http_hosts_walker(GenericHashEntry *node, void *data,
                                      bool *matched) {
  Host *h = (Host *)node;
  struct virtual_host_valk_info *info = (struct virtual_host_valk_info *)data;
  HTTPstats *s = h->getHTTPstats();

  if (s) {
    info->num += s->luaVirtualHosts(info->vm, info->key, h);
    *matched = true;
  }

  return (false); /* false = keep on walking */
}

/* **************************************** */

bool NetworkInterface::alert_store_query(lua_State *vm, const char *sql) {
  if (!alertStore) return false;

  return alertStore->query(vm, sql);
}

/* **************************************** */

void NetworkInterface::listHTTPHosts(lua_State *vm, char *key) {
  struct virtual_host_valk_info info;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  lua_newtable(vm);

  info.vm = vm, info.key = key, info.num = 0;
  walker(&begin_slot, walk_all, walker_hosts, virtual_http_hosts_walker, &info);
}

/* **************************************** */

void NetworkInterface::addAllAvailableInterfaces() {
  ntop_if_t *devpointer, *cur;
  if (!Utils::ntop_findalldevs(&devpointer)) {
    for (cur = devpointer; cur; cur = cur->next) {
      if (Utils::validInterface(cur) &&
          (strncmp(cur->name, "virbr", 5) != 0) /* Ignore virtual interfaces */
          && Utils::isInterfaceUp(cur->name)) {
        ntop->getPrefs()->add_network_interface(cur->name, cur->description);
      } else
        ntop->getTrace()->traceEvent(
            TRACE_INFO, "Interface [%s][%s] not valid or down: discarded",
            cur->name, cur->description);
    } /* for */

    Utils::ntop_freealldevs(devpointer);
  }
}

/* **************************************** */

#ifdef NTOPNG_PRO
void NetworkInterface::refreshL7Rules() {
  if (ntop->getPro()->has_valid_license() && policer) policer->refreshL7Rules();
}
#endif

/* **************************************** */

#ifdef NTOPNG_PRO
void NetworkInterface::refreshShapers() {
  if (ntop->getPro()->has_valid_license() && policer) policer->refreshShapers();
}
#endif

/* **************************************** */

void NetworkInterface::addInterfaceAddress(char *const addr) {
  if (ip_addresses.size() == 0)
    ip_addresses = addr;
  else {
    string s = addr;

    ip_addresses = ip_addresses + "," + s;
  }
}

/* **************************************** */

void NetworkInterface::addInterfaceNetwork(char *const net, char *addr) {
  /* E.g. 192.168.1.0/24 -> 192.168.1.42 */
  char *addr_cp = strdup(addr);
  char *sep = NULL;

  if (addr_cp && (sep = strchr(addr_cp, '/'))) *sep = '\0';

  interface_networks.addAddressAndData(net, addr_cp);
}

/* **************************************** */

bool NetworkInterface::isInterfaceNetwork(const IpAddress *const ipa,
                                          int network_bits) const {
  return interface_networks.match(ipa, network_bits);
}

/* **************************************** */

void NetworkInterface::FillObsHash() {
  /* Adding all observation points to the hash map*/
  if (obs_hash) {
    char **keys;
    char pattern[64];
    int rc = 0;

    snprintf(pattern, sizeof(pattern),
             "ntopng.serialized_as.ifid_%u_obs_point_*", get_id());

    // ntop->getTrace()->traceEvent(TRACE_INFO, "Pattern: %s", pattern);

    /* Get all Observation Points keys */
    rc = ntop->getRedis()->keys(pattern, &keys);

    if (rc > 0) {
      for (int i = 0; i < rc; i++) {
        if (keys[i]) {
          char symbol = '_';
          /* Get last occurrence of _ , because the key is serialized like
           * ntopng.serialized_as.ifid_10_obs_point_1234 */
          /* In this way it's possible to get all the ids of the Obs. Points */
          char *obs_point = strrchr(keys[i], symbol);

          if (obs_point) {
            u_int16_t obs_point_id = atoi(&obs_point[1]);

            if (!obs_point_id) {
              ntop->getTrace()->traceEvent(
                  TRACE_ERROR,
                  "Failed to deserialize Observation Point stats: %u",
                  obs_point_id);
              if (keys[i]) free(keys[i]);
              continue;
            }

            /* Found at least one element */
            /* Create a new observation point with the id found to deserialize
             * stats */
            ObservationPoint *tmp_obs_point =
                new ObservationPoint(this, obs_point_id);

            last_obs_point_id = obs_point_id;
            /* Add to the map */
            if (obs_hash->add(tmp_obs_point, false /* Do lock */))
              ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                           "Found Observation Point: %u; Stats "
                                           "deserialization complete.",
                                           obs_point_id);
            else
              ntop->getTrace()->traceEvent(
                  TRACE_ERROR,
                  "Failed to deserialize Observation Point stats: %u",
                  obs_point_id);
          }
        }

        if (keys[i]) free(keys[i]);
      }

      free(keys);
    }
  }
}

/* **************************************** */

void NetworkInterface::allocateStructures() {
  u_int16_t numNetworks = ntop->getNumLocalNetworks();
  char buf[16];

  try {
    if (get_id() >= 0) {
      u_int32_t num_hashes =
          max_val(4096, ntop->getPrefs()->get_max_num_flows() / 4);

      flows_hash =
          new FlowHash(this, num_hashes, ntop->getPrefs()->get_max_num_flows());

      if(!flowsOnlyInterface() /* Do not allocate HTs when the interface should only have flows */
	 && !isViewed() /* Do not allocate HTs when the interface is viewed, HTs are allocated in the corresponding ViewInterface */)
	{
        num_hashes = max_val(4096, ntop->getPrefs()->get_max_num_hosts() / 4);
        hosts_hash = new HostHash(this, num_hashes,
                                  ntop->getPrefs()->get_max_num_hosts());
        /* The number of ASes cannot be greater than the number of hosts */
        ases_hash =
            new AutonomousSystemHash(this, ndpi_min(num_hashes, 4096), 32768);
        if (!isPacketInterface())
          obs_hash =
              new ObservationPointHash(this, ndpi_min(num_hashes, 4096), 32768);
        oses_hash =
            new OperatingSystemHash(this, ndpi_min(num_hashes, 1024), 32768);
        countries_hash =
            new CountriesHash(this, ndpi_min(num_hashes, 1024), 32768);
        vlans_hash = new VLANHash(this, 1024, 2048);
        macs_hash = new MacHash(this, ndpi_min(num_hashes, 8192), 32768);
      }
    }

    FillObsHash();

    networkStats = new NetworkStats *[numNetworks];
    statsManager = new StatsManager(id, STATS_MANAGER_STORE_NAME);
    ndpiStats =
        new nDPIStats(true /* Enable throughput calculation */,
                      ntop->getPrefs()->isIfaceL7BehavourAnalysisEnabled());
    dscpStats = new DSCPStats();

    download_stats = new RoundTripStats();
    upload_stats = new RoundTripStats();

    gw_macs = new MacHash(this, 32, 64);

    top_sites = new (std::nothrow) MostVisitedList(HOST_SITES_TOP_NUMBER);
    top_os = new (std::nothrow) MostVisitedList(HOST_SITES_TOP_NUMBER);

    if (db == NULL) {
      if (ntop->getPrefs()->do_dump_flows_on_clickhouse()) {
#ifdef NTOPNG_PRO
#if defined(HAVE_CLICKHOUSE) && defined(HAVE_MYSQL)
        /* Allocate only the DB connection, not any thread or queue for the
         * export */
        try {
          db = new ClickHouseFlowDB(this);
        } catch (const std::invalid_argument &e) {
          db = NULL;
          ntop->getTrace()->traceEvent(
              TRACE_WARNING, "Leaving due to failed ClickHouse initialization");
          exit(-1);
        }
#endif
#endif
      }
    }

    if (!isViewed()) {
#if defined(NTOPNG_PRO) && defined(HAVE_CLICKHOUSE) && defined(HAVE_MYSQL)
      if (ntop->getPrefs()->do_dump_alerts_on_clickhouse())
        alertStore = new ClickHouseAlertStore(this);
#endif

      if (alertStore == NULL)
        alertStore = new SQLiteAlertStore(id, ALERTS_STORE_DB_FILE_NAME);

      alertsQueue = new AlertsQueue(this);
    }

    for (u_int16_t i = 0; i < numNetworks; i++)
      networkStats[i] = new NetworkStats(this, i);
  } catch (std::bad_alloc &ba) {
    static bool oom_warning_sent = false;

    if (!oom_warning_sent) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      oom_warning_sent = true;
    }
  }

#if defined(NTOPNG_PRO)
  if (ntop->getPrefs() && ntop->getPro()->has_valid_license() &&
      ntop->getPrefs()->isBehavourAnalysisEnabled() &&
      (ntop->getPrefs()->is_enterprise_l_edition() ||
       ntop->getPrefs()->is_nedge_enterprise_edition()) &&
      ifname && strcmp(ifname, SYSTEM_INTERFACE_NAME) &&
      !isViewed() /* Skip for viewed interface, only store service maps in the
                     view to save memory */
  ) {
    pMap = new (std::nothrow)
        PeriodicityMap(this, ntop->getPrefs()->get_max_num_flows() / 8,
                       3600 /* 1h idleness */);
    sMap = new (std::nothrow)
        ServiceMap(this, ntop->getPrefs()->get_max_num_flows() / 8,
                   86400 /* 1d idleness */);
  } else
    pMap = NULL, sMap = NULL;

#ifndef HAVE_NEDGE
  updateFlowProfiles();
#endif
#endif

  // Keep format in sync with alerts_api.interfaceAlertEntity(ifid)
  snprintf(buf, sizeof(buf), "%d", get_id());
  setEntityValue(buf);
  reloadGwMacs();
  removeRedisSitesKey();
}

/* **************************************** */

AlertsQueue *NetworkInterface::getAlertsQueue() const {
  if (isViewed())
    return viewedBy()->getAlertsQueue();
  else
    return alertsQueue;
}

/* **************************************** */

NetworkStats *NetworkInterface::getNetworkStats(u_int16_t networkId) const {
  if ((networkStats == NULL) || (networkId >= ntop->getNumLocalNetworks()))
    return (NULL);
  else
    return (networkStats[networkId]);
}

/* **************************************** */

void NetworkInterface::checkPointCounters(bool drops_only) {
  if (!drops_only) {
    checkpointPktCount = getNumPackets(), checkpointBytesCount = getNumBytes();
  }
  checkpointDroppedAlertsCount = getNumDroppedAlerts();
  checkpointPktDropCount = getNumPacketDrops();
  checkpointDiscardedProbingPktCount = getNumDiscardedProbingPackets();
  checkpointDiscardedProbingBytesCount = getNumDiscardedProbingBytes();

  if (db) db->checkPointCounters(drops_only);
}

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointNumPackets() {
  return (checkpointPktCount);
};

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointDroppedAlerts() {
  return (checkpointDroppedAlertsCount);
};

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointNumBytes() {
  return (checkpointBytesCount);
}

/* **************************************************** */

u_int32_t NetworkInterface::getCheckPointNumPacketDrops() {
  return (checkpointPktDropCount);
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
  if (interfaceStats == NULL)
    interfaceStats =
        new (std::nothrow) InterfaceStatsHash(NUM_IFACE_STATS_HASH);

  if (interfaceStats) {
    char a[64];

    ntop->getTrace()->traceEvent(TRACE_INFO, "[%s][ifIndex=%u]",
                                 Utils::intoaV4(stats->deviceIP, a, sizeof(a)),
                                 stats->ifIndex);

    interfaceStats->set(stats);
  }
}

/* **************************************** */

void NetworkInterface::reloadGwMacs() {
  char kname[64];
  char **macs = NULL;

  if (!ntop->getRedis()) return;

  gw_macs->cleanup();

  snprintf(kname, sizeof(kname), CONST_IFACE_GW_MACS_PREFS, id);
  int num_macs = ntop->getRedis()->smembers(kname, &macs);
  for (int i = 0; i < num_macs; i++) {
    Mac *m = NULL;
    u_int8_t addr[6];
    char *mac = macs[i];

    if (!mac) continue;

    // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Loading Gw MAC %s", mac);

    Utils::parseMac(addr, mac);

    try {
      if ((m = new Mac(this, addr)) != NULL) {
        if (!gw_macs->add(m, true)) {
          ntop->getTrace()->traceEvent(TRACE_WARNING,
                                       "Not enough root in GW macs hash");
          delete m;
        }
      }
    } catch (std::bad_alloc &ba) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    }

    free(mac);
  }

  if (macs) free(macs);

  gw_macs_reload_requested = false;
}

/* **************************************** */

int NetworkInterface::getActiveMacList(
    lua_State *vm, u_int32_t *begin_slot, bool walk_all,
    u_int8_t bridge_iface_idx, bool sourceMacsOnly, const char *manufacturer,
    char *sortColumn, u_int32_t maxHits, u_int32_t toSkip, bool a2zSortOrder,
    u_int16_t pool_filter, u_int8_t devtype_filter, u_int8_t location_filter,
    time_t min_first_seen) {
  struct flowHostRetriever retriever;
  bool show_details = true;

  retriever.observationPointId = getLuaVMUservalue(vm, observationPointId);

  if (sortMacs(begin_slot, walk_all, &retriever, bridge_iface_idx,
               sourceMacsOnly, manufacturer, sortColumn, pool_filter,
               devtype_filter, location_filter, min_first_seen) < 0) {
    return (-1);
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numMacs", retriever.actNumEntries);
  lua_push_uint64_table_entry(vm, "nextSlot", *begin_slot);

  lua_newtable(vm);

  if (a2zSortOrder) {
    for (int i = toSkip, num = 0;
         i < (int)retriever.actNumEntries && num < (int)maxHits; i++, num++) {
      Mac *m = retriever.elems[i].macValue;

      m->lua(vm, show_details, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and
                                       iterate inorder with ipairs */
    }
  } else {
    for (int i = (retriever.actNumEntries - 1 - toSkip), num = 0;
         i >= 0 && num < (int)maxHits; i--, num++) {
      Mac *m = retriever.elems[i].macValue;

      m->lua(vm, show_details, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "macs");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveASList(lua_State *vm, const Paginator *p,
                                      bool diff) {
  struct flowHostRetriever retriever;
  DetailsLevel details_level;

  if (!p) return (-1);

  if (sortASes(&retriever, p->sortColumn()) < 0) {
    return (-1);
  }

  if (!p->getDetailsLevel(&details_level)) details_level = details_normal;

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numASes", retriever.actNumEntries);

  lua_newtable(vm);

  if (p->a2zSortOrder()) {
    for (int i = p->toSkip(), num = 0;
         i < (int)retriever.actNumEntries && num < (int)p->maxHits();
         i++, num++) {
      AutonomousSystem *as = retriever.elems[i].asValue;

      as->lua(vm, details_level, false, diff);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and
                                       iterate inorder with ipairs */
    }
  } else {
    for (int i = (retriever.actNumEntries - 1 - p->toSkip()), num = 0;
         i >= 0 && num < (int)p->maxHits(); i--, num++) {
      AutonomousSystem *as = retriever.elems[i].asValue;

      as->lua(vm, details_level, false, diff);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "ASes");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveObsPointsList(lua_State *vm,
                                             const Paginator *p) {
  struct flowHostRetriever retriever;
  DetailsLevel details_level;

  if (!p) return (-1);

  if (sortObsPoints(&retriever, p->sortColumn()) < 0) {
    return (-1);
  }

  if (!p->getDetailsLevel(&details_level)) details_level = details_normal;

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numObsPoints", retriever.actNumEntries);

  lua_newtable(vm);

  if (p->a2zSortOrder()) {
    for (int i = p->toSkip(), num = 0;
         i < (int)retriever.actNumEntries && num < (int)p->maxHits();
         i++, num++) {
      ObservationPoint *obs_point = retriever.elems[i].obsPointValue;

      obs_point->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and
                                       iterate inorder with ipairs */
    }
  } else {
    for (int i = (retriever.actNumEntries - 1 - p->toSkip()), num = 0;
         i >= 0 && num < (int)p->maxHits(); i--, num++) {
      ObservationPoint *obs_point = retriever.elems[i].obsPointValue;

      obs_point->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "ObsPoints");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveOSList(lua_State *vm, const Paginator *p) {
  struct flowHostRetriever retriever;
  DetailsLevel details_level;

  if (!p) return (-1);

  if (sortOSes(&retriever, p->sortColumn()) < 0) {
    return (-1);
  }

  if (!p->getDetailsLevel(&details_level)) details_level = details_normal;

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numOSes", retriever.actNumEntries);

  lua_newtable(vm);

  if (p->a2zSortOrder()) {
    for (int i = p->toSkip(), num = 0;
         i < (int)retriever.actNumEntries && num < (int)p->maxHits();
         i++, num++) {
      OperatingSystem *os = retriever.elems[i].osValue;

      os->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and
                                       iterate inorder with ipairs */
    }
  } else {
    for (int i = (retriever.actNumEntries - 1 - p->toSkip()), num = 0;
         i >= 0 && num < (int)p->maxHits(); i--, num++) {
      OperatingSystem *os = retriever.elems[i].osValue;

      os->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "OSes");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveCountriesList(lua_State *vm,
                                             const Paginator *p) {
  struct flowHostRetriever retriever;
  DetailsLevel details_level;

  if (!p) return (-1);

  if (sortCountries(&retriever, p->sortColumn()) < 0) {
    return (-1);
  }

  if (!p->getDetailsLevel(&details_level)) details_level = details_normal;

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numCountries", retriever.actNumEntries);

  lua_newtable(vm);

  if (p->a2zSortOrder()) {
    for (int i = p->toSkip(), num = 0;
         i < (int)retriever.actNumEntries && num < (int)p->maxHits();
         i++, num++) {
      Country *country = retriever.elems[i].countryVal;

      country->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and
                                       iterate inorder with ipairs */
    }
  } else {
    for (int i = (retriever.actNumEntries - 1 - p->toSkip()), num = 0;
         i >= 0 && num < (int)p->maxHits(); i--, num++) {
      Country *country = retriever.elems[i].countryVal;

      country->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "Countries");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveVLANList(lua_State *vm, char *sortColumn,
                                        u_int32_t maxHits, u_int32_t toSkip,
                                        bool a2zSortOrder,
                                        DetailsLevel details_level) {
  struct flowHostRetriever retriever;

  if (!hasSeenVLANTaggedPackets()) {
    /* VLAN statistics are calculated only if VLAN tagged traffic has been seen
     */
    lua_pushnil(vm);
    return 0;
  }

  if (sortVLANs(&retriever, sortColumn) < 0) {
    return (-1);
  }

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "numVLANs", retriever.actNumEntries);

  lua_newtable(vm);

  if (a2zSortOrder) {
    for (int i = toSkip, num = 0;
         i < (int)retriever.actNumEntries && num < (int)maxHits; i++, num++) {
      VLAN *vl = retriever.elems[i].vlanValue;

      vl->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1); /* Must use integer keys to preserve and
                                       iterate inorder with ipairs */
    }
  } else {
    for (int i = (retriever.actNumEntries - 1 - toSkip), num = 0;
         i >= 0 && num < (int)maxHits; i--, num++) {
      VLAN *vl = retriever.elems[i].vlanValue;

      vl->lua(vm, details_level, false);
      lua_rawseti(vm, -2, num + 1);
    }
  }

  lua_pushstring(vm, "VLANs");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************** */

int NetworkInterface::getActiveMacManufacturers(
    lua_State *vm, u_int8_t bridge_iface_idx, bool sourceMacsOnly,
    u_int32_t maxHits, u_int8_t devtype_filter, u_int8_t location_filter) {
  struct flowHostRetriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (sortMacs(&begin_slot, walk_all, &retriever, bridge_iface_idx,
               sourceMacsOnly, NULL, (char *)"column_manufacturer",
               (u_int16_t)-1, devtype_filter, location_filter, 0) < 0) {
    return (-1);
  }

  lua_newtable(vm);

  const char *cur_manuf = NULL;
  u_int32_t cur_count = 0;
  int k = 0;

  for (int i = 0; i < (int)retriever.actNumEntries && k < (int)maxHits; i++) {
    Mac *m = retriever.elems[i].macValue;

    const char *manufacturer = m->get_manufacturer();
    if (manufacturer != NULL) {
      if (!cur_manuf || (strcmp(cur_manuf, manufacturer) != 0)) {
        if (cur_manuf != NULL)
          lua_push_int32_table_entry(vm, cur_manuf, cur_count);

        cur_manuf = manufacturer;
        cur_count = 1;
        k++;
      } else {
        cur_count++;
      }
    }
  }
  if (cur_manuf != NULL) lua_push_int32_table_entry(vm, cur_manuf, cur_count);

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************** */

static bool find_mac_hosts(GenericHashEntry *h, void *user_data,
                           bool *matched) {
  struct mac_find_info *info = (struct mac_find_info *)user_data;
  Host *host = (Host *)h;

  if (host->getMac() == info->m)
    host->lua(info->vm, NULL /* Already checked */, false, false, false, true);

  return false; /* false = keep on walking */
}

/* **************************************** */

bool NetworkInterface::getActiveMacHosts(lua_State *vm, const char *mac) {
  struct mac_find_info info;
  bool res = false;
  u_int32_t begin_slot = 0;

  if (!macs_hash) return res;

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

int NetworkInterface::getActiveDeviceTypes(
    lua_State *vm, u_int8_t bridge_iface_idx, bool sourceMacsOnly,
    u_int32_t maxHits, const char *manufacturer, u_int8_t location_filter) {
  struct flowHostRetriever retriever;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  if (sortMacs(&begin_slot, walk_all, &retriever, bridge_iface_idx,
               sourceMacsOnly, manufacturer, (char *)"column_device_type",
               (u_int16_t)-1, (u_int8_t)-1, location_filter, 0) < 0) {
    return (-1);
  }

  lua_newtable(vm);

  u_int8_t cur_devtype = 0;
  u_int32_t cur_count = 0;
  int k = 0;

  for (int i = 0; i < (int)retriever.actNumEntries && k < (int)maxHits; i++) {
    Mac *m = retriever.elems[i].macValue;

    if (m->getDeviceType() != cur_devtype) {
      if (cur_count) {
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

  if (cur_count) {
    lua_pushinteger(vm, cur_devtype);
    lua_pushinteger(vm, cur_count);
    lua_settable(vm, -3);
  }

  // finally free the elements regardless of the sorted kind
  if (retriever.elems) free(retriever.elems);

  return (retriever.actNumEntries);
}

/* **************************************** */

bool NetworkInterface::getMacInfo(lua_State *vm, char *mac) {
  struct mac_find_info info;
  bool ret = false;

  if (!macs_hash) return ret;

  memset(&info, 0, sizeof(info));
  Utils::parseMac(info.mac, mac);

  info.m = macs_hash->get(info.mac, false /* Not an inline call */);

  if (info.m) {
    info.m->lua(vm, true, false);
    ret = true;
  }

  return ret;
}

/* **************************************** */

bool NetworkInterface::resetMacStats(lua_State *vm, char *mac,
                                     bool delete_data) {
  struct mac_find_info info;
  bool ret = false;

  if (!macs_hash) return ret;

  memset(&info, 0, sizeof(info));
  Utils::parseMac(info.mac, mac);

  info.m = macs_hash->get(info.mac, false /* Not an inline call */);

  if (info.m) {
    if (delete_data)
      info.m->requestDataReset();
    else
      info.m->requestStatsReset();
    ret = true;
  }

  return ret;
}

/* **************************************** */

bool NetworkInterface::setMacDeviceType(char *strmac, DeviceType dtype,
                                        bool alwaysOverwrite) {
  u_int8_t mac[6];
  Mac *m;
  DeviceType oldtype;

  Utils::parseMac(mac, strmac);

  ntop->getTrace()->traceEvent(TRACE_INFO, "setMacDeviceType(%s) = %d", strmac,
                               (int)dtype);

  if ((m = getMac(mac, false /* Don't create if missing */,
                  false /* Not an inline call */))) {
    oldtype = m->getDeviceType();

    if (alwaysOverwrite || (oldtype == device_unknown)) {
      m->forceDeviceType(dtype);

      if (alwaysOverwrite && (oldtype != device_unknown) && (oldtype != dtype))
        ntop->getTrace()->traceEvent(TRACE_INFO,
                                     "Device %s type changed from %d to %d\n",
                                     strmac, oldtype, dtype);
    }
    return (true);
  } else
    return (false);
}

/* **************************************** */

bool NetworkInterface::getASInfo(lua_State *vm, u_int32_t asn) {
  struct as_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  info.asn = asn;

  walker(&begin_slot, walk_all, walker_ases, find_as_by_asn, (void *)&info);

  if (info.as) {
    info.as->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************** */

bool NetworkInterface::getObsPointInfo(lua_State *vm, u_int16_t obs_point) {
  struct obs_point_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  info.obs_point_id = obs_point;

  walker(&begin_slot, walk_all, walker_obs, find_obs_point_by_id,
         (void *)&info);

  if (info.obs_point) {
    info.obs_point->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************** */

bool NetworkInterface::getOSInfo(lua_State *vm, OSType os_type) {
  struct os_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  info.os_id = os_type;

  walker(&begin_slot, walk_all, walker_oses, find_os, (void *)&info);

  if (info.os) {
    info.os->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************** */

bool NetworkInterface::getCountryInfo(lua_State *vm, const char *country) {
  struct country_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  info.country_id = country;

  walker(&begin_slot, walk_all, walker_countries, find_country, (void *)&info);

  if (info.country) {
    info.country->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************** */

bool NetworkInterface::getVLANInfo(lua_State *vm, u_int16_t vlan_id) {
  struct vlan_find_info info;
  bool ret;
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  memset(&info, 0, sizeof(info));
  info.vlan_id = vlan_id;

  walker(&begin_slot, walk_all, walker_vlans, find_vlan_by_vlan_id,
         (void *)&info);

  if (info.vl) {
    info.vl->lua(vm, details_higher, false);
    ret = true;
  } else
    ret = false;

  return ret;
}

/* **************************************** */

int NetworkInterface::updateHostTrafficPolicy(AddressTree *allowed_networks,
                                              char *host_ip,
                                              u_int16_t host_vlan) {
  Host *h;
  int rv;

  if ((h = findHostByIP(allowed_networks, host_ip, host_vlan,
                        0 /* any observation point */)) != NULL) {
    h->updateHostTrafficPolicy(host_ip);
    rv = CONST_LUA_OK;
  } else
    rv = CONST_LUA_ERROR;

  return rv;
}

/* *************************************** */

TimeseriesExporter *NetworkInterface::getInfluxDBTSExporter() {
  if (!influxdb_ts_exporter)
    influxdb_ts_exporter = new (nothrow) InfluxDBTimeseriesExporter(this);

  return (influxdb_ts_exporter);
}

/* *************************************** */

TimeseriesExporter *NetworkInterface::getRRDTSExporter() {
  if (!rrd_ts_exporter)
    rrd_ts_exporter = new (nothrow) RRDTimeseriesExporter(this);

  return (rrd_ts_exporter);
}

/* *************************************** */

void NetworkInterface::checkMacIPAssociation(bool triggerEvent, u_char *_mac,
                                             u_int32_t ipv4, Mac *host_mac) {
  if (!are_ip_reassignment_alerts_enabled()) return;

  u_int64_t mac = Utils::mac2int(_mac);

  if ((ipv4 != 0) && (mac != 0) && (mac != 0xFFFFFFFFFFFF)) {
    std::map<u_int32_t, u_int64_t>::iterator it;

    if (!triggerEvent)
      ip_mac[ipv4] = mac;
    else {
      if ((it = ip_mac.find(ipv4)) != ip_mac.end()) {
        /* Found entry */
        if (it->second != mac) {
          u_char tmp[16];
          Utils::int2mac(it->second, tmp);

          getAlertsQueue()->pushMacIpAssociationChangedAlert(ntohl(ipv4), tmp,
                                                             _mac, host_mac);

          ip_mac[ipv4] = mac;
        }
      } else
        ip_mac[ipv4] = mac;
    }
  }
}

/* *************************************** */

void NetworkInterface::checkDhcpIPRange(Mac *sender_mac,
                                        struct dhcp_packet *dhcp_reply,
                                        u_int16_t vlan_id) {
  if (!hasConfiguredDhcpRanges()) return;

  u_char *_mac = dhcp_reply->chaddr;
  u_int64_t mac = Utils::mac2int(_mac);
  u_int32_t ipv4 = dhcp_reply->yiaddr;

  if ((ipv4 != 0) && (mac != 0) && (mac != 0xFFFFFFFFFFFF)) {
    IpAddress ip;
    ip.set(ipv4);

    if (!isInDhcpRange(&ip))
      getAlertsQueue()->pushOutsideDhcpRangeAlert(
          _mac, sender_mac, ntohl(ipv4), ntohl(dhcp_reply->siaddr), vlan_id);
  }
}

/* *************************************** */

/*
  Updates interface broadcast domains, inferring them from the range between
  `src` and `dst` IP addresses. This function must be called when `src` and
  `dst` are (reasonably) assumed to be in the same broadcast domain.

  For example, this function must be called when:
  - `src` and `dst` are read inside ARP sender protocol address (spa) and target
  protocol address (tpa)
  - `src` and `dst` are read from an IP packet with broadcast destination MAC
  (FF:FF:FF:FF:FF:FF)
*/
void NetworkInterface::updateBroadcastDomains(u_int16_t vlan_id,
                                              const u_int8_t *src_mac,
                                              const u_int8_t *dst_mac,
                                              u_int32_t src, u_int32_t dst) {
  u_int32_t net = src & dst;
  u_int32_t diff;
  IpAddress cur_bcast_domain;

  /* Smaller address in src */
  if (src > dst) {
    u_int32_t r = src;

    src = dst;
    dst = r;
  }

  /* Range between dst and src */
  diff = dst - src;

  /*
    Following is an heuristic which tries to detect the broadcast domain
    with its size and network-part of the address. Detection is done by checking
    source and target protocol addresses found in arp.

    Link-local addresses are excluded, as well as arp Probes with a zero source
    IP.

    ARP Probes are defined in RFC 5227:
    In this document, the term 'ARP Probe' is used to refer to an ARP
    Request packet, broadcast on the local link, with an all-zero 'sender
    IP address'.  [...]  The 'target IP
    address' field MUST be set to the address being probed.  An ARP Probe
    conveys both a question ("Is anyone using this address?") and an
    implied statement ("This is the address I hope to use.").
  */

  if (diff && src                         /* Not a zero source IP (ARP Probe) */
      && (src & 0xFFFF0000) != 0xA9FE0000 /* Not a link-local IP */
      && (dst & 0xFFFF0000) != 0xA9FE0000 /* Not a link-local IP */) {
    u_int32_t cur_mask;
    u_int8_t cur_cidr;

    for (cur_mask = 0xFFFFFFF0, cur_cidr = 28; cur_mask > 0x00000000;
         cur_mask <<= 1, cur_cidr--) {
      if ((diff & cur_mask) == 0) { /* diff < cur_mask */
        net &= cur_mask;

        if ((src & cur_mask) != (dst & cur_mask)) {
          cur_mask <<= 1, cur_cidr -= 1;
          net = src & cur_mask;
        }

        cur_bcast_domain.set(htonl(net));

        if (cur_mask > 0xFFFF0000 /* /16 */) {
          /* NOTE: call this also for existing domains in order to update the
           * hits */
          bcast_domains->addAddress(&cur_bcast_domain, cur_cidr);
#ifdef BROADCAST_DOMAINS_DEBUG
          char buf1[32], buf2[32], buf3[32];

          ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s <-> %s [%s - %u]",
                                       Utils::intoaV4(src, buf1, sizeof(buf1)),
                                       Utils::intoaV4(dst, buf2, sizeof(buf2)),
                                       Utils::intoaV4(net, buf3, sizeof(buf3)),
                                       cur_cidr);
#endif
        } else {
          if (ntop->getPrefs()->isBroadcastDomainTooLargeEnabled())
            getAlertsQueue()->pushBroadcastDomainTooLargeAlert(
                src_mac, dst_mac, src, dst, vlan_id);
        }
        break;
      }
    }
  }
}

/* *************************************** */

/*
  Start the thread for the execution of flow user script hooks
*/
bool NetworkInterface::initFlowChecksLoop() {
  pthread_create(&flowChecksLoop, NULL, ::flowChecksLoop, (void *)this);
  flowAlertsDequeueLoopCreated = true;

  return true;
}

/* *************************************** */

/*
  Start the thread for the execution of host user script hooks
*/
bool NetworkInterface::initHostChecksLoop() {
  pthread_create(&hostChecksLoop, NULL, ::hostChecksLoop, (void *)this);
  hostAlertsDequeueLoopCreated = true;

  return true;
}

/* *************************************** */

/*
  Put here all the code that is executed when the NIC initialization
  is successful
*/
bool NetworkInterface::initFlowDump(u_int8_t num_dump_interfaces) {
  startFlowDumping();

  /* Flows are dumped by the view only */
  if (isViewed()) /* No need to allocate databases on view interfaces */
    return (true);

  if (db == NULL) {
    if (ntop->getPrefs()->do_dump_flows_on_clickhouse()) {
#if defined(NTOPNG_PRO) && defined(HAVE_CLICKHOUSE) && defined(HAVE_MYSQL)
      db = new (std::nothrow) ClickHouseFlowDB(this);

      if ((db == NULL) || (db->isDbCreated() == false)) {
        ntop->getTrace()->traceEvent(
            TRACE_WARNING, "Leaving due to failed ClickHouse initialization");
        exit(-1);
      }
#endif
    }
#ifdef HAVE_MYSQL
    else if (ntop->getPrefs()->do_dump_flows_on_mysql()) {
      db = new (std::nothrow) MySQLDB(this);
      if (!db) throw "Not enough memory";
    }
#endif
#ifndef HAVE_NEDGE
    else if (ntop->getPrefs()->do_dump_flows_on_es()) {
      db = new (std::nothrow) ElasticSearch(this);
    }
#if defined(HAVE_KAFKA) && defined(NTOPNG_PRO)
    else if ((ntop->getPrefs()->getKakfaBrokersList() != NULL)) {
      kafka = new KafkaProducer(this, ntop->getPrefs()->getKakfaBrokersList(),
                                ntop->getPrefs()->getKafkaTopic(),
                                ntop->getPrefs()->getKafkaOptions());
      db = kafka;
    }
#endif
#if !defined(WIN32) && !defined(__APPLE__)
    else if (ntop->getPrefs()->do_dump_flows_on_syslog()) {
      db = new (std::nothrow) SyslogDump(this);
    }
#endif
#endif
  }

  return (db != NULL);
}

/* *************************************** */

bool NetworkInterface::registerLiveCapture(
    struct ntopngLuaContext *const luactx, int *id) {
  bool ret = false;

  *id = -1;
  active_captures_lock.lock(__FILE__, __LINE__);

  if (num_live_captures < MAX_NUM_PCAP_CAPTURES) {
    for (int i = 0; i < MAX_NUM_PCAP_CAPTURES; i++) {
      if (live_captures[i] == NULL) {
        live_captures[i] = luactx, num_live_captures++;
        ret = true, *id = i;
        break;
      }
    }
  }

  active_captures_lock.unlock(__FILE__, __LINE__);

  return (ret);
}

/* *************************************** */

bool NetworkInterface::deregisterLiveCapture(
    struct ntopngLuaContext *const luactx) {
  bool ret = false;

  active_captures_lock.lock(__FILE__, __LINE__);

  for (int i = 0; i < MAX_NUM_PCAP_CAPTURES; i++) {
    if (live_captures[i] == luactx) {
      struct ntopngLuaContext *c = (struct ntopngLuaContext *)live_captures[i];

      c->live_capture.stopped = true;
      live_captures[i] = NULL, num_live_captures--;
      ret = true;
      break;
    }
  }

  active_captures_lock.unlock(__FILE__, __LINE__);

  return (ret);
}

/* *************************************** */

bool NetworkInterface::matchLiveCapture(struct ntopngLuaContext *const luactx,
                                        const struct pcap_pkthdr *const h,
                                        const u_char *const packet,
                                        Flow *const f) {
  if (!luactx->live_capture.matching_host /* No host filter set */
      || (f && (luactx->live_capture.matching_host == f->get_cli_host() ||
                luactx->live_capture.matching_host == f->get_srv_host()))) {
    if (luactx->live_capture.bpfFilterSet) {
      if (!bpf_filter(luactx->live_capture.fcode.bf_insns,
                      (const u_char *)packet, h->caplen, h->caplen)) {
        return (false);
      }
    }

    return (true);
  }

  return false;
}

/* *************************************** */

void NetworkInterface::deliverLiveCapture(const struct pcap_pkthdr *const h,
                                          const u_char *const packet,
                                          Flow *const f) {
  int res;

  for (u_int i = 0, num_found = 0;
       (i < MAX_NUM_PCAP_CAPTURES) && (num_found < num_live_captures); i++) {
    if (live_captures[i] != NULL) {
      struct ntopngLuaContext *c = (struct ntopngLuaContext *)live_captures[i];
      bool http_client_disconnected = false;
      int disconnect_stage = 0;

      num_found++;

      if ((c->live_capture.capture_until < (u_int32_t)h->ts.tv_sec) ||
          c->live_capture.stopped)
        http_client_disconnected = true, disconnect_stage = 1;

#ifdef TRACE_DOWNLOAD
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL, "%d seconds left",
          c->live_capture.capture_until - h->ts.tv_sec);
#endif

      /* The header is always sent even when there is never a match with
         matchLiveCapture, as otherwise some browsers may end up in hanging.
         Hanging has been verified with Safari Version 12.0 (13606.2.11) but not
         with Chrome Version 68.0.3440.106 (Official Build) (64-bit) */
      if (!http_client_disconnected && c->conn &&
          !c->live_capture.pcaphdr_sent) {
        struct pcap_file_header pcaphdr;

        Utils::init_pcap_header(&pcaphdr, get_datalink(),
                                ntop->getGlobals()->getSnaplen(get_name()));

        if ((res = mg_write_async(c->conn, &pcaphdr, sizeof(pcaphdr))) <
            (int)sizeof(pcaphdr))
          http_client_disconnected = true, disconnect_stage = 2;

        c->live_capture.pcaphdr_sent = true;
      }

      if (!http_client_disconnected && c->conn &&
          matchLiveCapture(c, h, packet, f)) {
        struct pcap_disk_pkthdr
            *pkthdr; /* Cannot use h as the format on disk differs */

        if (c->live_capture.data_not_yet_sent_len > 0) {
          /* We have some leftover from the previous send,
             so let's try to send this data first
          */

#ifdef TRACE_DOWNLOAD
          ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                       "Resending data [%u bytes left]",
                                       c->live_capture.data_not_yet_sent_len);
#endif

          res = mg_write_async(c->conn, c->live_capture.send_buffer,
                               c->live_capture.data_not_yet_sent_len);

          if (res > 0) {
            if (res == (int)c->live_capture.data_not_yet_sent_len) {
              c->live_capture.data_not_yet_sent_len =
                  0; /* We've sent everything that was in queue */
            } else {
              u_int leftover = c->live_capture.data_not_yet_sent_len - res;

              memmove(c->live_capture.send_buffer,
                      &c->live_capture.send_buffer[res], leftover);

              c->live_capture.data_not_yet_sent_len = leftover;

#ifdef TRACE_DOWNLOAD
              ntop->getTrace()->traceEvent(
                  TRACE_NORMAL, "Partial send [%u bytes left]",
                  c->live_capture.data_not_yet_sent_len);
#endif
              return; /* The current packet is dropped */
            }
          }
        }

        /* If we're here all the previous data has been sent out */
        pkthdr = (struct pcap_disk_pkthdr *)c->live_capture.send_buffer;

        pkthdr->ts.tv_sec = h->ts.tv_sec, pkthdr->ts.tv_usec = h->ts.tv_usec,
        pkthdr->caplen =
            ndpi_min(h->caplen, sizeof(c->live_capture.send_buffer) -
                                    sizeof(struct pcap_disk_pkthdr)),
        pkthdr->len = h->len;

        memcpy(&c->live_capture.send_buffer[sizeof(struct pcap_disk_pkthdr)],
               packet, pkthdr->caplen);
        c->live_capture.data_not_yet_sent_len =
            pkthdr->caplen + sizeof(struct pcap_disk_pkthdr);

        /* Now send data */
#ifdef TRACE_DOWNLOAD
        ntop->getTrace()->traceEvent(
            TRACE_NORMAL, "About to send %u bytes [%d sec left]",
            c->live_capture.data_not_yet_sent_len,
            c->live_capture.capture_until - h->ts.tv_sec);
#endif

        res = mg_write_async(c->conn, &c->live_capture.send_buffer,
                             c->live_capture.data_not_yet_sent_len);

#ifdef TRACE_DOWNLOAD
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Sent %d / %u bytes", res,
                                     c->live_capture.data_not_yet_sent_len);
#endif

        if (res == (int)c->live_capture.data_not_yet_sent_len) {
          c->live_capture.data_not_yet_sent_len = 0; /* All sent */

          c->live_capture.num_captured_packets++;

          if ((c->live_capture.capture_max_pkts != 0) &&
              (c->live_capture.num_captured_packets ==
               c->live_capture.capture_max_pkts)) {
            http_client_disconnected = true, disconnect_stage = 4;
          }
        } else if (res >= 0) {
#ifdef TRACE_DOWNLOAD
          ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                       "Partial send: %u bytes sent", res);
#endif

          if (res > 0) {
            /* Some data has been sent */
            u_int leftover = c->live_capture.data_not_yet_sent_len - res;

            memmove(c->live_capture.send_buffer,
                    &c->live_capture.send_buffer[res], leftover);

            c->live_capture.data_not_yet_sent_len = leftover;

#ifdef TRACE_DOWNLOAD
            ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                         "Partial send [%u bytes left]",
                                         c->live_capture.data_not_yet_sent_len);
#endif
          }

          return; /* The current packet is dropped */
        } else {
          /* An error occurred */
          http_client_disconnected = true, disconnect_stage = 3;
        }
      }

      if (http_client_disconnected) {
        ntop->getTrace()->traceEvent(TRACE_INFO,
                                     "Client disconnected or socket for live "
                                     "capture is busy, stopping capture (%d)",
                                     disconnect_stage);

        deregisterLiveCapture(c); /* (*) */
      }
    }
  }
}

/* *************************************** */

void NetworkInterface::dumpLiveCaptures(lua_State *vm) {
  /* Administrative privileges checked by the caller */

  active_captures_lock.lock(__FILE__, __LINE__);

  lua_newtable(vm);

  for (int i = 0, capture_id = 0; i < MAX_NUM_PCAP_CAPTURES; i++) {
    if (live_captures[i] != NULL && !live_captures[i]->live_capture.stopped) {
      lua_newtable(vm);

      lua_push_uint64_table_entry(vm, "id", i);
      lua_push_uint64_table_entry(vm, "capture_until",
                                  live_captures[i]->live_capture.capture_until);
      lua_push_uint64_table_entry(
          vm, "capture_max_pkts",
          live_captures[i]->live_capture.capture_max_pkts);
      lua_push_uint64_table_entry(
          vm, "num_captured_packets",
          live_captures[i]->live_capture.num_captured_packets);

      if (live_captures[i]->live_capture.matching_host != NULL) {
        Host *h = (Host *)live_captures[i]->live_capture.matching_host;
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
  bool rc = false;

  /* Administrative privileges checked by the caller */

  if ((capture_id >= 0) && (capture_id < MAX_NUM_PCAP_CAPTURES)) {
    active_captures_lock.lock(__FILE__, __LINE__);

    if (live_captures[capture_id] != NULL) {
      struct ntopngLuaContext *c =
          (struct ntopngLuaContext *)live_captures[capture_id];

      c->live_capture.stopped = true, rc = true;
      if (c->live_capture.bpfFilterSet) pcap_freecode(&c->live_capture.fcode);
      /* live_captures[capture_id] = NULL; */ /* <-- not necessary as mongoose
                                                 will clean it */
    }

    active_captures_lock.unlock(__FILE__, __LINE__);
  }

  return (rc);
}

/* *************************************** */

static bool host_reload_blacklist(GenericHashEntry *host, void *user_data,
                                  bool *matched) {
  Host *h = (Host *)host;

  h->reloadHostBlacklist();
  *matched = true;

  return (false); /* false = keep on walking */
}

/* *************************************** */

void NetworkInterface::reloadHostsBlacklist() {
  u_int32_t begin_slot = 0;
  bool walk_all = true;

  /* Update the hosts */
  walker(&begin_slot, walk_all, walker_hosts, host_reload_blacklist, NULL);
}

/* *************************************** */

static bool host_reload_dhcp_host(GenericHashEntry *host, void *user_data,
                                  bool *matched) {
  Host *h = (Host *)host;

  h->reloadDhcpHost();
  *matched = true;

  return (false); /* false = keep on walking */
}

/* *************************************** */

void NetworkInterface::reloadDhcpRanges() {
  char redis_key[CONST_MAX_LEN_REDIS_KEY], *rsp = NULL;
  dhcp_range *new_ranges = NULL;
  u_int num_ranges = 0;
  u_int len;

  if (!ntop->getRedis()) return;

  snprintf(redis_key, sizeof(redis_key), IFACE_DHCP_RANGE_KEY, get_id());

  if ((rsp = (char *)malloc(CONST_MAX_LEN_REDIS_VALUE)) &&
      !ntop->getRedis()->get(redis_key, rsp, CONST_MAX_LEN_REDIS_VALUE) &&
      (len = strlen(rsp))) {
    u_int i;
    num_ranges = 1;

    for (i = 0; i < len; i++) {
      if (rsp[i] == ',') num_ranges++;
    }

    // +1 for final zero IP, which is used to indicate array termination
    new_ranges = new (std::nothrow) dhcp_range[num_ranges + 1];

    if (new_ranges) {
      char *cur_pos = rsp;

      /* E.g. 192.168.1.2-192.168.1.150,10.0.0.50-10.0.0.60 */
      for (i = 0; i < num_ranges; i++) {
        char *end = strchr(cur_pos, ',');
        char *delim = strchr(cur_pos, '-');

        if (!end) end = cur_pos + strlen(cur_pos);

        if (delim) {
          *delim = 0;
          *end = 0;

          new_ranges[i].first_ip.set(cur_pos);
          new_ranges[i].last_ip.set(delim + 1);
        }

        cur_pos = end + 1;
      }
    }
  }

  if (dhcp_ranges_shadow) delete[] (dhcp_ranges_shadow);

  dhcp_ranges_shadow = dhcp_ranges;
  dhcp_ranges = new_ranges;

  if (rsp) free(rsp);

  /* Reload existing hosts */
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  walker(&begin_slot, walk_all, walker_hosts, host_reload_dhcp_host, NULL);
}

/* *************************************** */

bool NetworkInterface::isInDhcpRange(IpAddress *ip) {
  // Important: cache it as it may change
  dhcp_range *ranges = dhcp_ranges;

  if (!ranges) return (false);

  while (!ranges->last_ip.isEmpty()) {
    if ((ranges->first_ip.compare(ip) <= 0) &&
        (ranges->last_ip.compare(ip) >= 0))
      return true;

    ranges++;
  }

  return false;
}

/* *************************************** */

bool NetworkInterface::isLocalBroadcastDomainHost(Host *const h,
                                                  bool is_inline_call) {
  bool res = bcast_domains->isLocalBroadcastDomainHost(h, is_inline_call);

  return res;
}

/* *************************************** */

typedef std::map<std::string, ContainerStats> PodsMap;

static bool flow_get_pods_stats(GenericHashEntry *entry, void *user_data,
                                bool *matched) {
  PodsMap *pods_stats = (PodsMap *)user_data;
  Flow *flow = (Flow *)entry;
  const ContainerInfo *cli_cont, *srv_cont;
  const char *cli_pod = NULL, *srv_pod = NULL;

  if ((cli_cont = flow->getClientContainerInfo()) &&
      cli_cont->data_type == container_info_data_type_k8s)
    cli_pod = cli_cont->data.k8s.pod;
  if ((srv_cont = flow->getServerContainerInfo()) &&
      srv_cont->data_type == container_info_data_type_k8s)
    srv_pod = srv_cont->data.k8s.pod;

  if (cli_pod) {
    ContainerStats stats =
        (*pods_stats)[cli_pod]; /* get existing or create new */
    const TcpInfo *client_tcp = flow->getClientTcpInfo();

    stats.incNumFlowsAsClient();
    stats.accountLatency(client_tcp ? client_tcp->rtt : 0,
                         client_tcp ? client_tcp->rtt_var : 0,
                         true /* as_client */);
    if (cli_cont->id) stats.addContainer(cli_cont->id);

    /* Update */
    (*pods_stats)[cli_pod] = stats;
  }

  if (srv_pod) {
    ContainerStats stats =
        (*pods_stats)[srv_pod]; /* get existing or create new */
    const TcpInfo *server_tcp = flow->getServerTcpInfo();

    stats.incNumFlowsAsServer();
    stats.accountLatency(server_tcp ? server_tcp->rtt : 0,
                         server_tcp ? server_tcp->rtt_var : 0,
                         false /* as server */);
    if (srv_cont->id) stats.addContainer(srv_cont->id);

    /* Update */
    (*pods_stats)[srv_pod] = stats;
  }

  return (false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::getPodsStats(lua_State *vm) {
  PodsMap pods_stats;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  PodsMap::iterator it;

  walker(&begin_slot, walk_all, walker_flows, flow_get_pods_stats,
         (void *)&pods_stats);

  lua_newtable(vm);

  for (it = pods_stats.begin(); it != pods_stats.end(); ++it) {
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

static bool flow_get_container_stats(GenericHashEntry *entry, void *user_data,
                                     bool *matched) {
  ContainersMap *containers_data =
      &((containerRetrieverData *)user_data)->containers;
  const char *pod_filter = ((containerRetrieverData *)user_data)->pod_filter;
  Flow *flow = (Flow *)entry;
  const ContainerInfo *cli_cont, *srv_cont;
  const char *cli_cont_id = NULL, *srv_cont_id = NULL;
  const char *cli_pod = NULL, *srv_pod = NULL;

  if ((cli_cont = flow->getClientContainerInfo())) {
    cli_cont_id = cli_cont->id;
    if (cli_cont->data_type == container_info_data_type_k8s)
      cli_pod = cli_cont->data.k8s.pod;
  }
  if ((srv_cont = flow->getServerContainerInfo())) {
    srv_cont_id = srv_cont->id;
    if (srv_cont->data_type == container_info_data_type_k8s)
      srv_pod = srv_cont->data.k8s.pod;
  }

  if (cli_cont_id &&
      ((!pod_filter) || (cli_pod && !strcmp(pod_filter, cli_pod)))) {
    ContainerData data =
        (*containers_data)[cli_cont_id]; /* get existing or create new */
    const TcpInfo *client_tcp = flow->getClientTcpInfo();

    data.stats.incNumFlowsAsClient();
    data.stats.accountLatency(client_tcp ? client_tcp->rtt : 0,
                              client_tcp ? client_tcp->rtt_var : 0,
                              true /* as_client */);
    data.info = cli_cont;

    /* Update */
    (*containers_data)[cli_cont_id] = data;
  }

  if (srv_cont_id &&
      ((!pod_filter) || (srv_pod && !strcmp(pod_filter, srv_pod)))) {
    ContainerData data =
        (*containers_data)[srv_cont_id]; /* get existing or create new */
    const TcpInfo *server_tcp = flow->getServerTcpInfo();

    data.stats.incNumFlowsAsServer();
    data.stats.accountLatency(server_tcp ? server_tcp->rtt : 0,
                              server_tcp ? server_tcp->rtt_var : 0,
                              false /* as server */);
    data.info = srv_cont;

    /* Update */
    (*containers_data)[srv_cont_id] = data;
  }

  return (false /* keep walking */);
}

/* *************************************** */

void NetworkInterface::getContainersStats(lua_State *vm,
                                          const char *pod_filter) {
  containerRetrieverData user_data;
  u_int32_t begin_slot = 0;
  bool walk_all = true;
  ContainersMap::iterator it;

  user_data.pod_filter = pod_filter;
  walker(&begin_slot, walk_all, walker_flows, flow_get_container_stats,
         (void *)&user_data);

  lua_newtable(vm);

  for (it = user_data.containers.begin(); it != user_data.containers.end();
       ++it) {
    it->second.stats.lua(vm);

    if (it->second.info) {
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

bool NetworkInterface::enqueueFlowToCompanion(ParsedFlow *const pf,
                                              bool skip_loopback_traffic) {
  if (skip_loopback_traffic &&
      (pf->src_ip.isLoopbackAddress() || pf->dst_ip.isLoopbackAddress()))
    return false;

  if (companionQueue[next_compq_insert_idx]) return false;

  if ((companionQueue[next_compq_insert_idx] =
           new (std::nothrow) ParsedFlow(*pf))) {
    next_compq_insert_idx = (next_compq_insert_idx + 1) % COMPANION_QUEUE_LEN;
    return true;
  }

  return false;
}

/* *************************************** */

void NetworkInterface::incNumAlertedFlows(Flow *f, AlertLevel severity) {
  switch (Utils::mapAlertLevelToGroup(severity)) {
    case alert_level_group_notice_or_lower:
      num_active_alerted_flows_notice++;
      break;
    case alert_level_group_warning:
      num_active_alerted_flows_warning++;
      break;
    case alert_level_group_error:
      num_active_alerted_flows_error++;
      break;
    default:
      break;
  }
}

/* *************************************** */

void NetworkInterface::decNumAlertedFlows(Flow *f, AlertLevel severity) {
  switch (Utils::mapAlertLevelToGroup(severity)) {
    case alert_level_group_notice_or_lower:
      num_active_alerted_flows_notice--;
      break;
    case alert_level_group_warning:
      num_active_alerted_flows_warning--;
      break;
    case alert_level_group_error:
      num_active_alerted_flows_error--;
      break;
    default:
      break;
  }
};

/* *************************************** */

u_int64_t NetworkInterface::getNumActiveAlertedFlows(
    AlertLevelGroup alert_level_group) const {
  switch (alert_level_group) {
    case alert_level_group_notice_or_lower:
      return num_active_alerted_flows_notice;
    case alert_level_group_warning:
      return num_active_alerted_flows_warning;
    case alert_level_group_error:
      return num_active_alerted_flows_error;
    default:
      return 0;
  }
};

/* *************************************** */

u_int64_t NetworkInterface::getNumActiveAlertedFlows() const {
  return num_active_alerted_flows_notice + num_active_alerted_flows_warning +
         num_active_alerted_flows_error;
};

/* *************************************** */

bool NetworkInterface::dequeueFlowFromCompanion(ParsedFlow **f) {
  if (!companionQueue[next_compq_remove_idx]) {
    *f = NULL;
    return false;
  }

  *f = companionQueue[next_compq_remove_idx];
  companionQueue[next_compq_remove_idx] = NULL;
  next_compq_remove_idx = (next_compq_remove_idx + 1) % COMPANION_QUEUE_LEN;

  return true;
}

/* *************************************** */

struct alertable_walker_data {
  AddressTree *allowed_nets;
  alertable_callback *callback;
  void *user_data;
};

static bool host_invoke_alertable_callback(GenericHashEntry *entity,
                                           void *user_data, bool *matched) {
  AlertableEntity *alertable = dynamic_cast<AlertableEntity *>(entity);
  struct alertable_walker_data *data =
      (struct alertable_walker_data *)user_data;

  if (alertable->matchesAllowedNetworks(data->allowed_nets)) {
    data->callback(alert_entity_host, alertable, data->user_data);
    *matched = true;
  }

  return (false); /* false = keep on walking */
}

/* *************************************** */

/* Walks alertable entities on this interface.
 * The user provided callback is called with the alertable_walker_data.user_data
 * parameter set to the provided user_data.
 */
void NetworkInterface::walkAlertables(AlertEntity alert_entity,
                                      const char *entity_value,
                                      AddressTree *allowed_nets,
                                      alertable_callback *callback,
                                      void *user_data) {
  std::map<std::pair<AlertEntity, std::string>,
           InterfaceMemberAlertableEntity *>::iterator it;

  /* Hosts */
  if (((alert_entity == alert_entity_none) ||
       (alert_entity == alert_entity_host))) {
    if (entity_value == NULL) {
      struct alertable_walker_data data;
      bool walk_all = true;
      u_int32_t begin_slot = 0;

      data.callback = callback;
      data.user_data = user_data;
      data.allowed_nets = allowed_nets;

      walker(&begin_slot, walk_all, walker_hosts,
             host_invoke_alertable_callback, &data);
    } else {
      /* Specific host */
      char *host_ip = NULL;
      u_int16_t vlan_id = 0;
      char buf[64];
      Host *host;

      get_host_vlan_info((char *)entity_value, &host_ip, &vlan_id, buf,
                         sizeof(buf));

      if (host_ip &&
          (host = getHost(host_ip, vlan_id,
                          0 /* not sure it can be read by the VM */,
                          false /* not inline */)) &&
          host->matchesAllowedNetworks(allowed_nets))
        callback(alert_entity_host, host, user_data);
    }
  }

  /* Interface */
  if (((alert_entity == alert_entity_none) ||
       (alert_entity == alert_entity_interface))) {
    if ((entity_value != NULL) && (getEntityValue().compare(entity_value) != 0))
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Interface filter does not "
                                   "correspond[type=%u]: expected %s, found %s",
                                   alert_entity, entity_value,
                                   getEntityValue().c_str());

    if (matchesAllowedNetworks(allowed_nets))
      callback(alert_entity_interface, this, user_data);
  }

  /* Networks */
  if (((alert_entity == alert_entity_none) ||
       (alert_entity == alert_entity_network))) {
    u_int16_t num_local_networks = ntop->getNumLocalNetworks();

    for (u_int16_t network_id = 0; network_id < num_local_networks;
         network_id++) {
      NetworkStats *netstats = getNetworkStats(network_id);

      if ((entity_value == NULL) ||
          (netstats->getEntityValue().compare(entity_value) == 0)) {
        if (netstats->matchesAllowedNetworks(allowed_nets))
          callback(alert_entity_network, netstats, user_data);
      }
    }
  }

  /* External Alerts.
   * Must lock in order to avoid concurrency issues with insertions/updates */
  external_alerts_lock.lock(__FILE__, __LINE__);

  for (it = external_alerts.begin(); it != external_alerts.end(); ++it) {
    if (((alert_entity == alert_entity_none) ||
         (alert_entity == it->second->getEntityType()))) {
      if ((entity_value == NULL) ||
          (it->second->getEntityValue().compare(entity_value) == 0)) {
        if (it->second->matchesAllowedNetworks(allowed_nets))
          callback(alert_entity_other, it->second, user_data);
      }
    }
  }

  external_alerts_lock.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void NetworkInterface::incNumAlertsEngaged(AlertEntity alert_entity,
                                           AlertLevel alert_severity) {
  u_int i = alert_entity;

  if (i < ALERT_ENTITY_MAX_NUM_ENTITIES) {
    switch (Utils::mapAlertLevelToGroup(alert_severity)) {
      case alert_level_group_notice_or_lower:
        num_alerts_engaged_notice[i]++;
        break;
      case alert_level_group_warning:
        num_alerts_engaged_warning[i]++;
        break;
      case alert_level_group_error:
        num_alerts_engaged_error[i]++;
        break;
      case alert_level_group_critical:
        num_alerts_engaged_critical[i]++;
        break;
      case alert_level_group_emergency:
        num_alerts_engaged_emergency[i]++;
        break;
      default:
        break;
    }
  }
}

/* *************************************** */

void NetworkInterface::decNumAlertsEngaged(AlertEntity alert_entity,
                                           AlertLevel alert_severity) {
  u_int i = alert_entity;

  if (i < ALERT_ENTITY_MAX_NUM_ENTITIES) {
    switch (Utils::mapAlertLevelToGroup(alert_severity)) {
      case alert_level_group_notice_or_lower:
        num_alerts_engaged_notice[i]--;
        break;
      case alert_level_group_warning:
        num_alerts_engaged_warning[i]--;
        break;
      case alert_level_group_error:
        num_alerts_engaged_error[i]--;
        break;
      case alert_level_group_critical:
        num_alerts_engaged_critical[i]--;
        break;
      case alert_level_group_emergency:
        num_alerts_engaged_emergency[i]--;
        break;
      default:
        break;
    }
  }
}

/* *************************************** */

u_int32_t NetworkInterface::getNumEngagedAlerts() const {
  u_int32_t tot_engaged_alerts = 0;

  for (int i = 0; i < ALERT_ENTITY_MAX_NUM_ENTITIES; i++)
    tot_engaged_alerts += num_alerts_engaged_notice[i] +
                          num_alerts_engaged_warning[i] +
                          num_alerts_engaged_error[i];

  return tot_engaged_alerts;
};

/* *************************************** */

u_int32_t NetworkInterface::getNumEngagedAlerts(
    AlertLevelGroup alert_level_group) const {
  u_int32_t tot_engaged_alerts = 0;
  const u_int32_t(*num_alerts_engaged)[ALERT_ENTITY_MAX_NUM_ENTITIES] = NULL;

  switch (alert_level_group) {
    case alert_level_group_notice_or_lower:
      num_alerts_engaged = &num_alerts_engaged_notice;
      break;
    case alert_level_group_warning:
      num_alerts_engaged = &num_alerts_engaged_warning;
      break;
    case alert_level_group_error:
      num_alerts_engaged = &num_alerts_engaged_error;
      break;
    case alert_level_group_critical:
      num_alerts_engaged = &num_alerts_engaged_critical;
      break;
    case alert_level_group_emergency:
      num_alerts_engaged = &num_alerts_engaged_emergency;
      break;
    default:
      return tot_engaged_alerts;
  }

  for (int i = 0; i < ALERT_ENTITY_MAX_NUM_ENTITIES; i++)
    tot_engaged_alerts += (*num_alerts_engaged)[i];

  return tot_engaged_alerts;
};

/* *************************************** */

void NetworkInterface::luaNumEngagedAlerts(lua_State *vm) const {
  lua_push_int32_table_entry(vm, "num_alerts_engaged", getNumEngagedAlerts());

  /* By Entity */
  lua_newtable(vm);

  for (int i = 0; i < ALERT_ENTITY_MAX_NUM_ENTITIES; i++) {
    u_int32_t num_alerts = num_alerts_engaged_notice[i] +
                           num_alerts_engaged_warning[i] +
                           num_alerts_engaged_error[i];

    if (num_alerts)
      /* Use string keys for entity id to avoid confusing lua and treating the
       * table as an array */
      lua_push_uint64_table_entry(vm, to_string(i).c_str(), num_alerts);
  }

  lua_pushstring(vm, "num_alerts_engaged_by_entity");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  /* By severity */
  lua_newtable(vm);

  lua_push_uint64_table_entry(
      vm, "notice", getNumEngagedAlerts(alert_level_group_notice_or_lower));
  lua_push_uint64_table_entry(vm, "warning",
                              getNumEngagedAlerts(alert_level_group_warning));
  lua_push_uint64_table_entry(vm, "error",
                              getNumEngagedAlerts(alert_level_group_error));
  lua_push_uint64_table_entry(vm, "critical",
                              getNumEngagedAlerts(alert_level_group_critical));
  lua_push_uint64_table_entry(vm, "emergency",
                              getNumEngagedAlerts(alert_level_group_emergency));

  lua_pushstring(vm, "num_alerts_engaged_by_severity");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
};

/* *************************************** */

void NetworkInterface::incNumDroppedAlerts(AlertEntity alert_entity) {
  switch (alert_entity) {
    case alert_entity_host:
      num_host_dropped_alerts++;
      break;
    case alert_entity_flow:
      num_flow_dropped_alerts++;
      break;
    default:
      num_other_dropped_alerts++;
      break;
  }
}

/* *************************************** */

struct get_engaged_alerts_userdata {
  lua_State *vm;
  AlertEntity alert_entity;
  AlertType alert_type;
  AlertLevel alert_severity;
  AlertRole role_filter;
  u_int idx;
};

static void get_engaged_alerts_callback(AlertEntity alert_entity,
                                        AlertableEntity *alertable,
                                        void *user_data) {
  struct get_engaged_alerts_userdata *data =
      (struct get_engaged_alerts_userdata *)user_data;

  alertable->getAlerts(data->vm, no_periodicity, data->alert_type,
                       data->alert_severity, data->role_filter, &data->idx);
}

void NetworkInterface::getEngagedAlerts(lua_State *vm, AlertEntity alert_entity,
                                        const char *entity_value,
                                        AlertType alert_type,
                                        AlertLevel alert_severity,
                                        AlertRole role_filter,
                                        AddressTree *allowed_nets) {
  struct get_engaged_alerts_userdata data;

  data.vm = vm;
  data.idx = 0;
  data.alert_entity = alert_entity;
  data.alert_type = alert_type;
  data.alert_severity = alert_severity;
  data.role_filter = role_filter;

  lua_newtable(vm);

  walkAlertables(alert_entity, entity_value, allowed_nets,
                 get_engaged_alerts_callback, &data);
}

/* *************************************** */

void NetworkInterface::processExternalAlertable(AlertEntity entity,
                                                const char *entity_val,
                                                lua_State *vm,
                                                u_int vm_argument_idx,
                                                bool do_store_alert) {
  std::map<std::pair<AlertEntity, std::string>,
           InterfaceMemberAlertableEntity *>::iterator it;
  std::pair<AlertEntity, std::string> key(entity, std::string(entity_val));
  InterfaceMemberAlertableEntity *alertable = NULL;

  external_alerts_lock.lock(__FILE__, __LINE__);

  /* Lookup */
  if ((it = external_alerts.find(key)) != external_alerts.end())
    alertable = it->second;

  if (alertable) {
    /* Already present */

    if (do_store_alert) {
      /* Nothing to store - return */
      external_alerts_lock.unlock(__FILE__, __LINE__);
      lua_pushnil(vm);
      return;
    }

  } else {
    /* Not present */

    if (!do_store_alert) {
      /* Nothing to release - return */
      external_alerts_lock.unlock(__FILE__, __LINE__);
      lua_pushnil(vm);
      return;
    }

    /* Create */
    alertable = new (std::nothrow) InterfaceMemberAlertableEntity(this, entity);
    if (alertable == NULL) {
      external_alerts_lock.unlock(__FILE__, __LINE__);
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Not enough memory");
      lua_pushnil(vm);
      return;
    }

    alertable->setEntityValue(entity_val);

    /* Add to the map */
    external_alerts[key] = alertable;
  }

  if (do_store_alert)
    ntop_store_triggered_alert(vm, alertable, vm_argument_idx);
  else {
    ntop_release_triggered_alert(vm, alertable, vm_argument_idx);

    if (alertable->getNumEngagedAlerts() == 0) {
      external_alerts.erase(key);
      delete alertable;
    }
  }

  external_alerts_lock.unlock(__FILE__, __LINE__);
}

/* *************************************** */

void NetworkInterface::checkHostsToRestore() {
  int i = 0;

  if (!hosts_hash) return;

  /* Restore at maximum 5 hosts per run */
  for (i = 0; (i < 5) && hosts_hash->hasEmptyRoom(); i++) {
    char *ip, *d;
    Host *h;
    Mac *mac = NULL;
    u_int16_t vlan_id;
    IpAddress ipa;

    if (hosts_to_restore->empty()) break;

    ip = hosts_to_restore->dequeue();

    if (!(d = strchr(ip, '@'))) goto next_host;

    /* Split IP from VLAN */
    *d = '\0';
    vlan_id = atoi(d + 1);
    ipa.set(ip);

    if ((h = getHost(ip, vlan_id, 0 /* any observation point */,
                     true /* inline call */)))
      /* Host already exists */
      goto next_host;

    if (serializeLbdHostsAsMacs()) {
      /* Try to retrieve the associated MAC address (only for LBD hosts) */
      char key[CONST_MAX_LEN_REDIS_KEY];
      char mac_buf[64];
      u_int8_t mac_bytes[6];

      snprintf(key, sizeof(key), IP_MAC_ASSOCIATION, get_id(), ip, vlan_id);

      /* The host is possibly a LBD host in DHCP range, so also bring up its MAC
       * for the deserialization */
      if ((!ntop->getRedis()->get(key, mac_buf, sizeof(mac_buf))) &&
          (mac_buf[0] != '\0')) {
        Utils::parseMac(mac_bytes, mac_buf);
        mac = getMac(mac_bytes, true /* Create if not present */,
                     true /* inline call */);
      } else {
        goto next_host;
      }
    }

    /* TODO provide the host MAC address when available to properly restore LBD
     * hosts */
    if (ipa.isLocalHost() || ipa.isLocalInterfaceAddress())
      h = new (std::nothrow)
          LocalHost(this, mac, vlan_id, 0 /* any observation point */, &ipa);
    else
      h = new (std::nothrow)
          RemoteHost(this, mac, vlan_id, 0 /* any observation point */, &ipa);

    if (!h) goto next_host;

    if (!hosts_hash->add(
            h, false /* Don't lock, we're inline with the purgeIdle */))
      delete h;

  next_host:
    /* Always free the string retrieved from the queue */
    free(ip);
  }
}

/* *************************************** */

void NetworkInterface::luaAlertedFlows(lua_State *vm) {
  /* Total */
  lua_push_int32_table_entry(vm, "num_alerted_flows",
                             getNumActiveAlertedFlows());
  /* Breakdown */
  lua_push_int32_table_entry(
      vm, "num_alerted_flows_notice",
      getNumActiveAlertedFlows(alert_level_group_notice_or_lower));
  lua_push_int32_table_entry(
      vm, "num_alerted_flows_warning",
      getNumActiveAlertedFlows(alert_level_group_warning));
  lua_push_int32_table_entry(vm, "num_alerted_flows_error",
                             getNumActiveAlertedFlows(alert_level_group_error));
}

/* *************************************** */

void NetworkInterface::luaPeriodicityFilteringMenu(lua_State *vm,
                                                   MapsFilters *filters) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  if (pMap) {
    pMap->luaFilteringMenu(vm, this, true, filters);
    return;
  }
#endif

  lua_pushnil(vm);
}

/* *************************************** */

void NetworkInterface::luaServiceFilteringMenu(lua_State *vm,
                                               MapsFilters *filters) {
#if defined(NTOPNG_PRO)
  if (sMap) {
    sMap->luaFilteringMenu(vm, this, false, filters);
    return;
  }
#endif

  lua_pushnil(vm);
}

/* *************************************** */

void NetworkInterface::luaPeriodicityMap(lua_State *vm, MapsFilters *filters) {
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  if (pMap) {
    pMap->lua(vm, filters);
    return;
  }
#endif

  lua_pushnil(vm);
}

/* *************************************** */

void NetworkInterface::luaServiceMap(lua_State *vm, MapsFilters *filters) {
#if defined(NTOPNG_PRO)
  if (sMap) {
    sMap->lua(vm, filters);
    return;
  }
#endif

  lua_pushnil(vm);
}

/* *************************************** */

#if defined(NTOPNG_PRO)
void NetworkInterface::updateFlowPeriodicity(Flow *f) {
  if (isViewed())
    viewedBy()->updateFlowPeriodicity(f);
  else if (pMap)
    pMap->updateElement(f, f->get_first_seen());
}

/* *************************************** */

void NetworkInterface::updateServiceMap(Flow *f) {
  if (isViewed())
    viewedBy()->updateServiceMap(f);
  else if (sMap)
    sMap->update(f, f->get_first_seen());
}
#endif

/* *************************************** */

void NetworkInterface::updateSitesStats() {
  if (ntop->getPrefs()->are_top_talkers_enabled()) {
    /* String used to add extra info to the redis key */
    std::string additional_key_info = "";

    if (top_sites)
      top_sites->saveOldData(
          get_id(), (char *)additional_key_info.c_str(),
          (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED);

    if (top_os) {
      additional_key_info = ".topOs";
      top_os->saveOldData(get_id(), (char *)additional_key_info.c_str(),
                          (char *)HASHKEY_IFACE_TOP_OS_HOUR_KEYS_PUSHED);
    }
  }
}

void NetworkInterface::incrVisitedWebSite(char *hostname) {
  if (top_sites) top_sites->incrVisitedData(hostname, 1);
}

/* *************************************** */

void NetworkInterface::incrOS(char *hostname) {
  char *firstdot = NULL, *nextdot = NULL;

  firstdot = strchr(hostname, '.');

  if (firstdot) nextdot = strchr(&firstdot[1], '.');

  top_os->incrVisitedData(nextdot ? &firstdot[1] : hostname, 1);
}

/* *************************************** */

HostCheck *NetworkInterface::getCheck(HostCheckID t) {
  return (host_checks_executor->getCheck(t));
}

/* *************************************** */

void NetworkInterface::execProtocolDetectedChecks(Flow *f) {
  if (flow_checks_executor) {
    FlowAlert *alert =
        flow_checks_executor->execChecks(f, flow_check_protocol_detected);
    if (alert) enqueueFlowAlert(alert);
  }
}

/* *************************************** */

void NetworkInterface::execPeriodicUpdateChecks(Flow *f) {
  if (flow_checks_executor) {
    FlowAlert *alert =
        flow_checks_executor->execChecks(f, flow_check_periodic_update);

    if (alert) enqueueFlowAlert(alert);
  }
}

/* *************************************** */

void NetworkInterface::execFlowEndChecks(Flow *f) {
  if (flow_checks_executor) {
    FlowAlert *alert = flow_checks_executor->execChecks(f, flow_check_flow_end);

    if (alert) enqueueFlowAlert(alert);
  }
}

/* *************************************** */

void NetworkInterface::execFlowBeginChecks(Flow *f) {
  if (flow_checks_executor) {
    FlowAlert *alert =
        flow_checks_executor->execChecks(f, flow_check_flow_begin);

    if (alert) enqueueFlowAlert(alert);
  }
}

/* *************************************** */

void NetworkInterface::luaScore(lua_State *vm) {
  /* Score */
  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "score_as_cli", score_as_cli);
  lua_push_uint64_table_entry(vm, "score_as_srv", score_as_srv);
  lua_pushstring(vm, "score");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void NetworkInterface::luaNdpiStats(lua_State *vm, bool diff) {
  /* nDPI stats */
  if (ndpiStats) ndpiStats->lua(this, vm, true, diff);
}

/* *************************************** */

void NetworkInterface::luaAnomalies(lua_State *vm) {
  /* Anomalies */
  lua_newtable(vm);
  if (has_too_many_flows) lua_push_bool_table_entry(vm, "too_many_flows", true);
  if (has_too_many_hosts) lua_push_bool_table_entry(vm, "too_many_hosts", true);

  lua_push_uint32_table_entry(vm, "num_local_hosts_anomalies",
                              tot_num_anomalies.local_hosts);
  lua_push_uint32_table_entry(vm, "num_remote_hosts_anomalies",
                              tot_num_anomalies.remote_hosts);

  lua_pushstring(vm, "anomalies");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* *************************************** */

void NetworkInterface::execHostChecks(Host *h) {
  if (host_checks_executor) host_checks_executor->execChecks(h);
}

/* *************************************** */

void NetworkInterface::incObservationPointIdFlows(u_int16_t pointId) {
  ObservationPoint *obs_point_stats =
      obs_hash ? obs_hash->get(pointId, true /* Lock */) : NULL;
  if (obs_point_stats) obs_point_stats->incFlows();
}

/* *************************************** */

bool NetworkInterface::hasObservationPointId(u_int16_t pointId) {
  return (((obs_hash) && (obs_hash->get(pointId, false)) ? true : false));
}

/* *************************************** */

bool NetworkInterface::haveObservationPointsDefined() {
  return (((!obs_hash) || (obs_hash->getNumEntries() == 0)) ? false : true);
}

/* *************************************** */

u_int16_t NetworkInterface::getFirstObservationPointId() {
  return (((!obs_hash) || (obs_hash->getNumEntries() == 0))
              ? 0
              : last_obs_point_id);
}

/* *************************************** */

void NetworkInterface::removeRedisSitesKey() {
  // System Interface, no Network sites for sure
  if (id == -1 || !top_sites || !top_os) return;

  top_sites->serializeDeserialize(
      id, false, (char *)"", (char *)HASHKEY_TOP_SITES_SERIALIZATION_KEY,
      (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED,
      (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_DAY_KEYS_PUSHED);
  top_os->serializeDeserialize(id, false, (char *)"",
                               (char *)HASHKEY_TOP_OS_SERIALIZATION_KEY,
                               (char *)HASHKEY_IFACE_TOP_OS_HOUR_KEYS_PUSHED,
                               (char *)HASHKEY_IFACE_TOP_OS_DAY_KEYS_PUSHED);
}

/* *************************************** */

void NetworkInterface::addRedisSitesKey() {
  // System Interface, no Network sites for sure
  if (id == -1 || !top_sites || !top_os) return;

  top_sites->serializeDeserialize(
      id, true, (char *)"", (char *)HASHKEY_TOP_SITES_SERIALIZATION_KEY,
      (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_HOUR_KEYS_PUSHED,
      (char *)HASHKEY_LOCAL_HOSTS_TOP_SITES_DAY_KEYS_PUSHED);
  top_os->serializeDeserialize(id, true, (char *)"",
                               (char *)HASHKEY_TOP_OS_SERIALIZATION_KEY,
                               (char *)HASHKEY_IFACE_TOP_OS_HOUR_KEYS_PUSHED,
                               (char *)HASHKEY_IFACE_TOP_OS_DAY_KEYS_PUSHED);
}

/* *************************************** */

int NetworkInterface::exec_csv_query(const char *sql, bool dump_in_json_format,
                                     struct mg_connection *conn) {
#if defined(NTOPNG_PRO) && defined(HAVE_MYSQL) && defined(HAVE_CLICKHOUSE)
  ((ClickHouseFlowDB *)db)->execCSVQuery(sql, dump_in_json_format, conn);

  return (0);
#endif
  return (-1);
};

/* *************************************** */

struct host_walker_metadata {
  std::vector<ActiveHostWalkerInfo> info;
  int16_t networkIdFilter;
  HostWalkMode mode;
  bool localHostsOnly;
};

static bool active_hosts_walker(GenericHashEntry *h, void *user_data,
                                bool *matched) {
  Host *host = (Host *)h;
  struct host_walker_metadata *m = (struct host_walker_metadata *)user_data;
  bool isLocal;

  if ((host == NULL) || ((m->networkIdFilter != -1 /* -1 == all networks */) &&
                         (host->get_local_network_id() != m->networkIdFilter)))
    return (false);

  isLocal = host->isLocalHost() || host->isSystemHost();

  if ((m->localHostsOnly && isLocal) ||
      ((m->localHostsOnly == false) && (!isLocal)))
    host->visit(&m->info, m->mode);

  return (false); /* false = keep on walking */
}

/* *************************************** */

static bool walkerSort(const ActiveHostWalkerInfo &a,
                       const ActiveHostWalkerInfo &b) {
  return (a.getZ() > b.getZ());
}

/* *************************************** */

int NetworkInterface::walkActiveHosts(
    lua_State *vm, HostWalkMode mode, u_int32_t maxHits,
    int16_t networkIdFilter, /* -1 = means any network */
    bool localHostsOnly, bool treeMapMode) {
  u_int32_t begin_slot = 0;
  struct host_walker_metadata m;
  int rc;
  std::vector<ActiveHostWalkerInfo>::iterator it;

  m.mode = mode, m.localHostsOnly = localHostsOnly,
  m.networkIdFilter = networkIdFilter;

  rc = walker(&begin_slot, true /* walk_all */, walker_hosts,
              active_hosts_walker, (void *)&m);

  if ((rc != 0) || (m.info.size() == 0)) {
    lua_pushnil(vm);

    return (-1);
  } else {
    u_int num = 0;

    std::sort(m.info.begin(), m.info.end(), walkerSort);

    lua_newtable(vm);

    for (it = m.info.begin(); (num < maxHits) && (it != m.info.end());
         ++it, num++) {
      it->lua(vm, treeMapMode);

      // ntop->getTrace()->traceEvent(TRACE_WARNING, "[%u] %u", num+1,
      // it->getZ());

      lua_rawseti(vm, -2, num + 1); /* Array */
    }

    return (m.info.size());
  }
}

/* *************************************** */

#ifdef NTOPNG_PRO
void NetworkInterface::checkDHCPStorm(time_t when, u_int32_t num_pkts) {
  if (last_sec_epoch == (u_int32_t)when)
    dhcp_last_sec_pkts += num_pkts;
  else {
    if (dhcp_last_sec_pkts > DHCP_STORM_PPS_THSHOLD) {
      char value[32], key[32];

#ifdef DEBUG
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL, "DHCP [iface: %d][when: %u][total: %u]", get_id(),
          last_sec_epoch, dhcp_last_sec_pkts);
#endif

      /* Queue alert for the DHCP storm plugin */
      snprintf(key, sizeof(key), DHCP_STORM_QUEUE_NAME, get_id());

      snprintf(value, sizeof(value), "%u;%u", last_sec_epoch,
               dhcp_last_sec_pkts);
      ntop->getRedis()->rpush(key, value, 32 /* trim size */);
    }

    last_sec_epoch = when, dhcp_last_sec_pkts = num_pkts; /* Reset counter */
  }
}
#endif

/* *************************************** */

void NetworkInterface::incNumHosts(bool local, bool rxOnlyHost) {
  if (local) numLocalHosts++;
  if (local && rxOnlyHost) numLocalRxOnlyHosts++;
  if (rxOnlyHost) numTotalRxOnlyHosts++;
  totalNumHosts++;
};

/* *************************************** */

void NetworkInterface::decNumHosts(bool local, bool rxOnlyHost) {
  if (local) numLocalHosts--;
  if (local && rxOnlyHost) numLocalRxOnlyHosts--;
  if (rxOnlyHost) numTotalRxOnlyHosts--;
  totalNumHosts--;
};

/* **************************************************** */

bool NetworkInterface::resetHostTopSites(AddressTree *allowed_hosts,
                                         char *host_ip, u_int16_t vlan_id,
                                         u_int16_t observationPointId) {
  Host *h = findHostByIP(allowed_hosts, host_ip, vlan_id, observationPointId);

  if (h)
    return (h->resetHostTopSites());
  else
    return (false);
}

/* **************************************************** */

bool NetworkInterface::compute_protocol_flow_stats(GenericHashEntry *node,
                                                   void *user_data,
                                                   bool *matched) {
  Flow *f = (Flow *)node;

  if (!f) {
    return false;
  }

  u_int64_t key = 0;
  u_int64_t vlan_id = f->get_vlan_id();
  ndpi_protocol detected_protocol = f->get_detected_protocol();
  std::unordered_map<u_int64_t, AggregatedFlowsStats *>::iterator it;
  std::unordered_map<u_int64_t, AggregatedFlowsStats *> *count =
      static_cast<std::unordered_map<u_int64_t, AggregatedFlowsStats *> *>(
          user_data);
  u_int64_t is_not_guessed = (u_int64_t) int(f->isDPIDetectedFlow());

  /* <is_not_guessed (16 bit)><vlan_id (16 bit)><app_protocol (16 bit)><master_protocol (16
   * bit) */
  key = ((u_int64_t) is_not_guessed << 48) +
        ((u_int64_t)vlan_id << 32) +
        (((u_int64_t)detected_protocol.app_protocol) << 16) +
        (u_int64_t)detected_protocol.master_protocol;

  it = count->find(key);

  if (it == count->end()) {
    AggregatedFlowsStats *fs = new (std::nothrow) AggregatedFlowsStats(
        f->get_cli_ip_addr(), f->get_srv_ip_addr(), f->get_protocol(),
        f->get_bytes_cli2srv(), f->get_bytes_srv2cli(), f->getScore());

    if (fs) {
      fs->setProtoKey(key);
      fs->setVlanId(vlan_id);
      fs->setClient(f->get_cli_ip_addr(), f->get_cli_host());
      fs->setServer(f->get_srv_ip_addr(), f->get_srv_host());
      (*count)[key] = fs;
    }
  } else {
    it->second->incFlowStats(f->get_cli_ip_addr(), f->get_srv_ip_addr(),
                             f->get_bytes_cli2srv(), f->get_bytes_srv2cli(),
                             f->getScore());
  }

  *matched = true;

  return (false); /* false = keep on walking */
}

/* **************************************************** */

bool NetworkInterface::compute_client_flow_stats(GenericHashEntry *node,
                                                 void *user_data,
                                                 bool *matched) {
  Flow *f = (Flow *)node;

  if (!f) {
    return false;
  }

  u_int64_t vlan_id = f->get_vlan_id();
  u_int64_t key =
      (((u_int64_t)f->get_cli_ip_addr()->key()) << 16) + ((u_int64_t)vlan_id);
  std::unordered_map<u_int64_t, AggregatedFlowsStats *>::iterator it;
  std::unordered_map<u_int64_t, AggregatedFlowsStats *> *count =
      static_cast<std::unordered_map<u_int64_t, AggregatedFlowsStats *> *>(
          user_data);

  it = count->find(key);

  if (it == count->end()) {
    AggregatedFlowsStats *fs = new (std::nothrow) AggregatedFlowsStats(
        f->get_cli_ip_addr(), f->get_srv_ip_addr(), f->get_protocol(),
        f->get_bytes_cli2srv(), f->get_bytes_srv2cli(), f->getScore());

    if (fs != NULL) {
      fs->setClient(f->get_cli_ip_addr(), f->get_cli_host());
      fs->setServer(f->get_srv_ip_addr(), f->get_srv_host());
      fs->setVlanId(f->get_vlan_id());
      fs->setKey(key);
      (*count)[key] = fs;
    }
  } else {
    it->second->incFlowStats(f->get_cli_ip_addr(), f->get_srv_ip_addr(),
                             f->get_bytes_cli2srv(), f->get_bytes_srv2cli(),
                             f->getScore());
  }

  *matched = true;

  return (false); /* false = keep on walking */
}

/* **************************************************** */

bool NetworkInterface::compute_server_flow_stats(GenericHashEntry *node,
                                                 void *user_data,
                                                 bool *matched) {
  Flow *f = (Flow *)node;

  if (!f) {
    return false;
  }

  u_int64_t vlan_id = f->get_vlan_id();
  u_int64_t key =
      (((u_int64_t)f->get_srv_ip_addr()->key()) << 16) + ((u_int64_t)vlan_id);
  std::unordered_map<u_int64_t, AggregatedFlowsStats *>::iterator it;
  std::unordered_map<u_int64_t, AggregatedFlowsStats *> *count =
      static_cast<std::unordered_map<u_int64_t, AggregatedFlowsStats *> *>(
          user_data);

  it = count->find(key);

  if (it == count->end()) {
    AggregatedFlowsStats *fs = new (std::nothrow) AggregatedFlowsStats(
        f->get_cli_ip_addr(), f->get_srv_ip_addr(), f->get_protocol(),
        f->get_bytes_cli2srv(), f->get_bytes_srv2cli(), f->getScore());

    if (fs != NULL) {
      fs->setClient(f->get_cli_ip_addr(), f->get_cli_host());
      fs->setServer(f->get_srv_ip_addr(), f->get_srv_host());
      fs->setVlanId(f->get_vlan_id());
      fs->setKey(key);
      (*count)[key] = fs;
    }
  } else {
    it->second->incFlowStats(f->get_cli_ip_addr(), f->get_srv_ip_addr(),
                             f->get_bytes_cli2srv(), f->get_bytes_srv2cli(),
                             f->getScore());
  }

  *matched = true;
  return (false); /* false = keep on walking */
}

/* **************************************************** */

/* Sort compare functions */

static bool asc_str_cmp(AggregatedFlowsStats *a, AggregatedFlowsStats *b) {
  return strcasecmp(a->getProtoName(), b->getProtoName()) < 0;
}

static bool asc_str_info_cmp(AggregatedFlowsStats *a, AggregatedFlowsStats *b) {
  return strcasecmp(a->getInfoKey(), b->getInfoKey()) < 0;
}

static bool asc_cli_ip_hex_cmp(AggregatedFlowsStats *a,
                               AggregatedFlowsStats *b) {
  char a_buf[48], b_buf[48];
  return strcmp(a->getCliIPHex(a_buf, sizeof(a_buf)),
                b->getCliIPHex(b_buf, sizeof(b_buf))) < 0;
}

static bool asc_srv_ip_hex_cmp(AggregatedFlowsStats *a,
                               AggregatedFlowsStats *b) {
  char a_buf[48], b_buf[48];
  return strcmp(a->getSrvIPHex(a_buf, sizeof(a_buf)),
                b->getSrvIPHex(b_buf, sizeof(b_buf))) < 0;
}

static bool asc_srv_cli_ip_hex_cmp(AggregatedFlowsStats *a,
                                   AggregatedFlowsStats *b) {
  char a_c_buf[48], a_s_buf[48], b_c_buf[48], b_s_buf[48];
  char a_sc_buf[96], b_sc_buf[96];

  snprintf(a_sc_buf, sizeof(a_sc_buf), "%s%s",
           a->getCliIPHex(a_c_buf, sizeof(a_c_buf)),
           a->getSrvIPHex(a_s_buf, sizeof(a_s_buf)));

  snprintf(b_sc_buf, sizeof(b_sc_buf), "%s%s",
           b->getCliIPHex(b_c_buf, sizeof(b_c_buf)),
           b->getSrvIPHex(b_s_buf, sizeof(b_s_buf)));

  return (strcmp(a_sc_buf, b_sc_buf) < 0);
}

static bool asc_flownum_cmp(AggregatedFlowsStats *a, AggregatedFlowsStats *b) {
  return a->getNumFlows() < b->getNumFlows();
}

static bool asc_totalscore_cmp(AggregatedFlowsStats *a,
                               AggregatedFlowsStats *b) {
  return a->getTotalScore() < b->getTotalScore();
}

static bool asc_numclients_cmp(AggregatedFlowsStats *a,
                               AggregatedFlowsStats *b) {
  return a->getNumClients() < b->getNumClients();
}

static bool asc_vlan_cmp(AggregatedFlowsStats *a, AggregatedFlowsStats *b) {
  return a->getVlanId() < b->getVlanId();
}

static bool asc_numservers_cmp(AggregatedFlowsStats *a,
                               AggregatedFlowsStats *b) {
  return a->getNumServers() < b->getNumServers();
}

static bool asc_totalsent_cmp(AggregatedFlowsStats *a,
                              AggregatedFlowsStats *b) {
  return a->getTotalSent() < b->getTotalSent();
}

static bool asc_totalrcvd_cmp(AggregatedFlowsStats *a,
                              AggregatedFlowsStats *b) {
  return a->getTotalRcvd() < b->getTotalRcvd();
}

static bool asc_totaltraffic_cmp(AggregatedFlowsStats *a,
                                 AggregatedFlowsStats *b) {
  return (a->getTotalRcvd() + a->getTotalSent()) <
         (b->getTotalRcvd() + b->getTotalSent());
}

/* **************************************************** */

/* Analysis Flows Stats Lua response builders */

void NetworkInterface::build_lua_rsp(lua_State *vm,
                                     AggregatedFlowsStats *flow_stats,
                                     u_int filter_type, u_int32_t size,
                                     u_int *num, bool set_resp) {
  if (set_resp) {
    char buf[128];
    u_int8_t add_client = false, add_server = false, add_app_proto = false,
             add_info = false;

    lua_newtable(vm);

    switch (filter_type) {
      case 1:
        add_app_proto = true;
        break;

      case 3:
        add_server = true;
        break;

      case 4:
        add_client = add_server = true;
        break;

      case 5:
        add_app_proto = add_client = add_server = true;
        break;

      case 6:
        add_info = true;
        break;

      default:
        add_client = true;
        break;
    }

    if (add_app_proto) {
      ndpi_protocol detected_protocol;
      char buf[64], proto[16];
      u_int64_t key = flow_stats->getProtoKey();

      detected_protocol.master_protocol = (u_int16_t)(key & 0x00000000000FFFF);
      detected_protocol.app_protocol =
          (u_int16_t)((key >> 16) & 0x000000000000FFFF);

      if (detected_protocol.master_protocol == detected_protocol.app_protocol)
        snprintf(proto, sizeof(proto), "%u", detected_protocol.master_protocol);
      else if (detected_protocol.app_protocol == NDPI_PROTOCOL_UNKNOWN)
        snprintf(proto, sizeof(proto), "%u", detected_protocol.master_protocol);
      else if (detected_protocol.master_protocol == NDPI_PROTOCOL_UNKNOWN)
        snprintf(proto, sizeof(proto), "%u", detected_protocol.app_protocol);
      else
        snprintf(proto, sizeof(proto), "%u", detected_protocol.app_protocol);

      /* Currently it is not supported the possibily to add double filter on
       * master and app proto */
      lua_push_str_table_entry(vm, "proto_id", proto);
      lua_push_str_table_entry(
          vm, "proto_name",
          get_ndpi_full_proto_name(detected_protocol, buf, sizeof(buf)));
      lua_push_str_table_entry(
          vm, "proto_name",
          get_ndpi_full_proto_name(detected_protocol, buf, sizeof(buf)));
      lua_push_bool_table_entry(vm, "is_not_guessed", flow_stats->isNotGuessed());
    }

    if (add_client) {
      lua_push_uint64_table_entry(vm, "cli_vlan_id",
                                  (u_int64_t)flow_stats->getCliVLANId());
      lua_push_str_table_entry(vm, "client_ip",
                               flow_stats->getCliIP(buf, sizeof(buf)));
      lua_push_str_table_entry(vm, "client_name",
                               flow_stats->getCliName(buf, sizeof(buf)));
      lua_push_bool_table_entry(vm, "is_cli_in_mem", flow_stats->isCliInMem());
    }

    if (add_server) {
      lua_push_uint64_table_entry(vm, "srv_vlan_id",
                                  (u_int64_t)flow_stats->getSrvVLANId());
      lua_push_str_table_entry(vm, "server_ip",
                               flow_stats->getSrvIP(buf, sizeof(buf)));
      lua_push_str_table_entry(vm, "server_name",
                               flow_stats->getSrvName(buf, sizeof(buf)));
      lua_push_bool_table_entry(vm, "is_srv_in_mem", flow_stats->isSrvInMem());
    }

    if (add_info) {
      lua_push_str_table_entry(vm, "info", flow_stats->getInfoKey());
    }

    lua_push_uint64_table_entry(vm, "vlan_id",
                                (u_int64_t)flow_stats->getVlanId());
    lua_push_uint32_table_entry(vm, "l4_proto", flow_stats->getL4Protocol());
    lua_push_uint32_table_entry(vm, "num_clients", flow_stats->getNumClients());
    lua_push_uint32_table_entry(vm, "num_servers", flow_stats->getNumServers());
    lua_push_uint32_table_entry(vm, "num_flows", flow_stats->getNumFlows());
    lua_push_uint64_table_entry(vm, "bytes_sent", flow_stats->getTotalSent());
    lua_push_uint64_table_entry(vm, "bytes_rcvd", flow_stats->getTotalRcvd());
    lua_push_uint64_table_entry(vm, "total_score", flow_stats->getTotalScore());
    lua_push_uint32_table_entry(vm, "num_entries", size);

    lua_pushinteger(vm, ++(*num));
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  } else {
    lua_newtable(vm);

    lua_push_uint32_table_entry(vm, "num_entries", size);

    lua_pushinteger(vm, ++(*num));
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* **************************************************** */

/* Verify function for the map search filter client case */
bool NetworkInterface::verify_search_filter_on_client(AggregatedFlowsStats *fs,
                                                      char *filter) {
  char buf[64];

  if (strcasestr(fs->getCliIP(buf, sizeof(buf)), filter))
    return true;
  else if (strcasestr(fs->getCliName(buf, sizeof(buf)), filter))
    return true;

  return false;
}

/* **************************************************** */

/* Verify function for the map search filter server case */
bool NetworkInterface::verify_search_filter_on_server(AggregatedFlowsStats *fs,
                                                      char *filter) {
  char buf[64];

  if (strcasestr(fs->getSrvIP(buf, sizeof(buf)), filter))
    return true;
  else if (strcasestr(fs->getSrvName(buf, sizeof(buf)), filter))
    return true;

  return false;
}

/* **************************************************** */

/* Verify function for the map search filter */
bool NetworkInterface::verify_search_filter(AggregatedFlowsStats *fs,
                                            char *filter,
                                            AnalysisCriteria filter_type) {
  switch (filter_type) {
    case AnalysisCriteria::application_criteria: {
      if (strcasestr(fs->getProtoName(), filter)) {
        return true;
      } else {
        if (strcasestr(fs->getProtoName(), filter)) return true;
      }
    } break;

    case AnalysisCriteria::info_criteria:
      if (strcasestr(fs->getInfoKey(), filter))
        return true;
      else if (strcasestr(fs->getInfoKey(), filter))
        return true;
      break;

    case AnalysisCriteria::client_criteria:
      return verify_search_filter_on_client(fs, filter);
      break;

    case AnalysisCriteria::server_criteria:
      return verify_search_filter_on_server(fs, filter);
      break;

    case AnalysisCriteria::client_server_criteria:
      // client case
      if (verify_search_filter_on_client(fs, filter))
        return true;
      else
        return verify_search_filter_on_server(fs, filter);
      break;

    case AnalysisCriteria::app_client_server_criteria:
      // application protocol case
      if (strcasestr(fs->getProtoName(), filter))
        return true;
      else if (strcasestr(fs->getProtoName(), filter))
        return true;
      else if (verify_search_filter_on_client(fs, filter))
        return true;
      else
        return verify_search_filter_on_server(fs, filter);
      break;
  }

  return false;
}

/* **************************************************** */

/* Verify function for the host ip filter */
bool NetworkInterface::verify_host_ip_filter(AggregatedFlowsStats *fs,
                                            char *filter, string vlan) {
  char buf[64];
  u_int64_t vlan_id;

  if (vlan.c_str() != NULL && !strcmp(vlan.c_str(),""))
    vlan_id = 0;
  else
    vlan_id = stoi(vlan);

  if(((!strcmp(fs->getCliIP(buf, sizeof(buf)), filter) && (vlan_id == 0 || vlan_id == fs->getCliVLANId()) )|| 
     ((!strcmp(fs->getSrvIP(buf, sizeof(buf)), filter)) && (vlan_id == 0 || vlan_id == fs->getSrvVLANId()))) )
    return true;

  return false;
}

/* **************************************************** */

/* Function to filter flows with search_filter and host_ip_filter  */
bool NetworkInterface::filters_flows(AggregatedFlowsStats *fs,
                                            char *search_filter, AnalysisCriteria filter_type, char *host_ip_filter ) {
  
  string ip = "";
  string vlan = "";
  if (host_ip_filter != NULL && host_ip_filter[0] != 0) {
    char *token = strtok(host_ip_filter, "@");
   
    int h = 0;
    while (token != NULL)
    {
        if(h == 0) {
          ip = token;
        } else if (h == 1) {
          vlan = token;
        } 
        token = strtok(NULL, "|");
        h++;
    }
  }
  
  if ((search_filter != NULL) && (search_filter[0] != 0)) {

    if (verify_search_filter(fs, search_filter, filter_type)) {
              
      // check host_ip filter
      if ((host_ip_filter != NULL) && (host_ip_filter[0] != 0)) {
        if( verify_host_ip_filter(fs, (char*)ip.c_str(), vlan))
          return(true);
      } else {
        return(true);
      }
    }     
  } else {

    // check host_ip filter
    if ((host_ip_filter != NULL) && (host_ip_filter[0] != 0)) {
      if( verify_host_ip_filter(fs, (char*)ip.c_str(), vlan))
        return(true);
    } else {
      return(true);
    }
  } 

  return(false);

}
/* **************************************************** */


/* Analysis Flows Stats sorter function */
void NetworkInterface::sort_and_filter_flow_stats(
    lua_State *vm, std::unordered_map<u_int64_t, AggregatedFlowsStats *> *count,
    std::unordered_map<string, AggregatedFlowsStats *> *count_info,
    AnalysisCriteria filter_type) {
  std::vector<AggregatedFlowsStats *> vector;
  std::vector<AggregatedFlowsStats *>::iterator vector_it;
  char *sortColumn = NULL, *sortOrder = NULL, *search_string = NULL, *host_ip = NULL;
  u_int32_t start = 0, max_num_rows = 0;

  if (lua_type(vm, 3) == LUA_TSTRING) sortColumn = (char *)lua_tostring(vm, 3);
  if (lua_type(vm, 4) == LUA_TSTRING) sortOrder = (char *)lua_tostring(vm, 4);
  if (lua_type(vm, 5) == LUA_TNUMBER) start = (u_int32_t)lua_tonumber(vm, 5);
  if (lua_type(vm, 6) == LUA_TNUMBER)
    max_num_rows = (u_int32_t)lua_tonumber(vm, 6);
  if (lua_type(vm, 7) == LUA_TSTRING)
    search_string = (char *)lua_tostring(vm, 7);
  if (lua_type(vm, 8) == LUA_TSTRING)
    host_ip = (char *)lua_tostring(vm, 8); 

  bool is_asc = sortOrder ? (!strcmp(sortOrder, "asc")) : true;
  bool (*sorter)(AggregatedFlowsStats *, AggregatedFlowsStats *) =
      &asc_totalsent_cmp;

  switch (filter_type) {
    case AnalysisCriteria::application_criteria: {
      /* Sorting by application criteria */
      std::unordered_map<u_int64_t, AggregatedFlowsStats *>::iterator it;

      for (it = count->begin(); it != count->end(); ++it) {
        ndpi_protocol detected_protocol;
        char buf[64];

        /* Get from the key, the master and application protocol,
         * first 16 bit for the master, second for the application
         */
        detected_protocol.master_protocol =
            (u_int16_t)(it->first & 0x00000000000FFFF);
        detected_protocol.app_protocol =
            (u_int16_t)((it->first >> 16) & 0x000000000000FFFF);

        it->second->setProtoName(
            get_ndpi_full_proto_name(detected_protocol, buf, sizeof(buf)));

        // check filters
        if(filters_flows(it->second, search_string, filter_type, host_ip ))
          vector.push_back(it->second);
        else
          continue;

      }

      if (sortColumn && (!strcmp(sortColumn, "application")))
        sorter = &asc_str_cmp;
    } break;

    case AnalysisCriteria::info_criteria: {
      std::unordered_map<string, AggregatedFlowsStats *>::iterator it;

      for (it = count_info->begin(); it != count_info->end(); ++it) {
        
        // check filters
        if(filters_flows(it->second, search_string, filter_type, host_ip ))
          vector.push_back(it->second);
        else
          continue;
      }

      if (sortColumn && !strcmp(sortColumn, "info")) sorter = &asc_str_info_cmp;
    } break;

    default: {
      /* Client / Server / Client-Server */
      std::unordered_map<u_int64_t, AggregatedFlowsStats *>::iterator it;

      for (it = count->begin(); it != count->end(); ++it) {
        if (filter_type == AnalysisCriteria::app_client_server_criteria) {
          ndpi_protocol detected_protocol;
          char buf[64];

          /* Get from the key, the master and application protocol,
           * first 16 bit for the master, second for the application
           */
          detected_protocol.master_protocol =
              (u_int16_t)(it->second->getProtoKey() & 0x00000000000FFFF);
          detected_protocol.app_protocol =
              (u_int16_t)((it->second->getProtoKey() >> 16) &
                          0x000000000000FFFF);

          it->second->setProtoName(
              get_ndpi_full_proto_name(detected_protocol, buf, sizeof(buf)));
        }

        // check filters
        if(filters_flows(it->second, search_string, filter_type, host_ip ))
          vector.push_back(it->second);
        else
          continue;

      }

      if (sortColumn && !strcmp(sortColumn, "client"))
        sorter = &asc_cli_ip_hex_cmp;
      else if (sortColumn && !strcmp(sortColumn, "server"))
        sorter = &asc_srv_ip_hex_cmp;
      else if (sortColumn && !strcmp(sortColumn, "client_and_server"))
        sorter = &asc_srv_cli_ip_hex_cmp;
    } break;
  } /* switch */

  /* Choose the right sorter */
  if (sortColumn) {
    if (!strcmp(sortColumn, "flows")) {
      sorter = &asc_flownum_cmp;
    } else if (!strcmp(sortColumn, "tot_score")) {
      sorter = &asc_totalscore_cmp;
    } else if (!strcmp(sortColumn, "num_clients")) {
      sorter = &asc_numclients_cmp;
    } else if (!strcmp(sortColumn, "num_servers")) {
      sorter = &asc_numservers_cmp;
    } else if (!strcmp(sortColumn, "bytes_sent")) {
      sorter = &asc_totalsent_cmp;
    } else if (!strcmp(sortColumn, "bytes_rcvd")) {
      sorter = &asc_totalrcvd_cmp;
    } else if (!strcmp(sortColumn, "tot_traffic")) {
      sorter = &asc_totaltraffic_cmp;
    } else if (!strcmp(sortColumn, "vlan_id")) {
      sorter = &asc_vlan_cmp;
    }
  }

  std::sort(vector.begin(), vector.end(), sorter);

  /* Reverse order sort */
  if (!is_asc) std::reverse(vector.begin(), vector.end());

  const u_int32_t vector_size = vector.size();
  u_int num = 0;

  lua_newtable(vm);

  /* Build up the lua response */
  if (start < vector_size) {
    for (vector_it = std::next(vector.begin(), start);
         vector_it != vector.end(); ++vector_it) {
      AggregatedFlowsStats *fs = *vector_it;

      if (fs) {
        build_lua_rsp(vm, fs, filter_type, vector_size, &num, true);
      }

      if (num >= max_num_rows) break;
    }
  } else {
    build_lua_rsp(vm, NULL, filter_type, vector_size, &num, false);
  }
}

/* **************************************************** */

void NetworkInterface::getFilteredLiveFlowsStats(lua_State *vm) {
  u_int32_t begin_slot = 0;
  std::unordered_map<u_int64_t, AggregatedFlowsStats *> count;
  std::unordered_map<string, AggregatedFlowsStats *> info_count;
  AnalysisCriteria filter_type = (AnalysisCriteria)lua_tonumber(vm, 1);

  switch (filter_type) {
    case AnalysisCriteria::application_criteria:
      /* application protocol criteria flows stats case */
      walker(&begin_slot, true /* walk_all */, walker_flows,
             compute_protocol_flow_stats, &count);
      break;

    case AnalysisCriteria::client_criteria:
      /* client criteria flows stats case */
      walker(&begin_slot, true /* walk_all */, walker_flows,
             compute_client_flow_stats, &count);
      break;

    case AnalysisCriteria::server_criteria:
      /* server criteria flows stats case */
      walker(&begin_slot, true /* walk_all */, walker_flows,
             compute_server_flow_stats, &count);
      break;

#if defined(NTOPNG_PRO)
    case AnalysisCriteria::client_server_criteria:
      /* client server criteria flows stats case */
      if (ntop->getPrefs()->is_enterprise_m_edition())
        walker(&begin_slot, true /* walk_all */, walker_flows,
               compute_client_server_flow_stats, &count);
      break;

    case AnalysisCriteria::app_client_server_criteria:
      /* app client server criteria flows stats case */
      if (ntop->getPrefs()->is_enterprise_m_edition())
        walker(&begin_slot, true /* walk_all */, walker_flows,
               compute_app_client_server_flow_stats, &count);
      break;

    case AnalysisCriteria::info_criteria:
      /* info criteria flows stats case */
      if (ntop->getPrefs()->is_enterprise_m_edition())
        walker(&begin_slot, true /* walk_all */, walker_flows,
               compute_info_flow_stats, &info_count);
      break;
#endif

    default:
      /* client criteria flows stats case */
      walker(&begin_slot, true /* walk_all */, walker_flows,
             compute_client_flow_stats, &count);
      break;
  }

  sort_and_filter_flow_stats(vm, &count, &info_count, filter_type);

  /* Free memory before leaving */
  for (std::unordered_map<u_int64_t, AggregatedFlowsStats *>::iterator it1 =
           count.begin();
       it1 != count.end(); ++it1)
    delete it1->second;

  for (std::unordered_map<string, AggregatedFlowsStats *>::iterator it2 =
           info_count.begin();
       it2 != info_count.end(); ++it2)
    delete it2->second;
}

/* **************************************************** */

static bool compute_vlan_flow_stats(GenericHashEntry *node, void *user_data,
                                    bool *matched) {
  Flow *f = (Flow *)node;

  if (!f) {
    return false;
  }

  ndpi_protocol detected_protocol = f->get_detected_protocol();
  u_int64_t vlan_id = f->get_vlan_id();
  /* <0 (16 bit)><u_int16_t (16 bit)><app_protocol (16 bit)><master_protocol (16
   * bit) */
  u_int64_t key = (((u_int64_t)f->get_srv_port()) << 48) +
                  (((u_int64_t)vlan_id) << 32) +
                  (((u_int64_t)detected_protocol.app_protocol) << 16) +
                  (u_int64_t)detected_protocol.master_protocol;
  std::unordered_map<u_int64_t, AggregatedFlowsStats *>::iterator it;
  std::unordered_map<u_int64_t, AggregatedFlowsStats *> *count =
      static_cast<std::unordered_map<u_int64_t, AggregatedFlowsStats *> *>(
          user_data);

  it = count->find(key);

  if (it == count->end()) {
    AggregatedFlowsStats *fs = new (std::nothrow) AggregatedFlowsStats(
        f->get_cli_ip_addr(), f->get_srv_ip_addr(), f->get_protocol(),
        f->get_bytes_cli2srv(), f->get_bytes_srv2cli(), f->getScore());

    if (fs != NULL) (*count)[key] = fs;
  } else {
    it->second->incFlowStats(f->get_cli_ip_addr(), f->get_srv_ip_addr(),
                             f->get_bytes_cli2srv(), f->get_bytes_srv2cli(),
                             f->getScore());
  }

  *matched = true;

  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getVLANFlowsStats(lua_State *vm) {
  u_int32_t begin_slot = 0;
  std::unordered_map<u_int64_t /* u_int16_t + l7 proto */,
                     AggregatedFlowsStats *>
      count;
  std::unordered_map<u_int64_t, AggregatedFlowsStats *>::iterator it;
  u_int num = 0;

  walker(&begin_slot, true /* walk_all */, walker_flows,
         compute_vlan_flow_stats, &count);

  lua_newtable(vm);

  for (it = count.begin(); it != count.end(); ++it) {
    AggregatedFlowsStats *fs = it->second;
    ndpi_protocol detected_protocol;
    char buf[64], proto[16];
    u_int16_t vlan_id, dst_port;

    if (fs) {
      detected_protocol.master_protocol =
          (u_int16_t)(it->first & 0x00000000000FFFF);
      detected_protocol.app_protocol =
          (u_int16_t)((it->first >> 16) & 0x000000000000FFFF);
      vlan_id = (u_int16_t)((it->first >> 32) & 0x000000000000FFFF);
      dst_port = (u_int16_t)((it->first >> 48) & 0x000000000000FFFF);

      lua_newtable(vm);

      if (detected_protocol.master_protocol == detected_protocol.app_protocol)
        snprintf(proto, sizeof(proto), "%u", detected_protocol.master_protocol);
      else if (detected_protocol.app_protocol == NDPI_PROTOCOL_UNKNOWN)
        snprintf(proto, sizeof(proto), "%u", detected_protocol.master_protocol);
      else if (detected_protocol.master_protocol == NDPI_PROTOCOL_UNKNOWN)
        snprintf(proto, sizeof(proto), "%u", detected_protocol.app_protocol);
      else
        snprintf(proto, sizeof(proto), "%u.%u",
                 detected_protocol.master_protocol,
                 detected_protocol.app_protocol);

      lua_push_uint32_table_entry(vm, "vlan_id", vlan_id);
      lua_push_uint32_table_entry(vm, "dst_port", dst_port);
      lua_push_str_table_entry(vm, "proto_id", proto);
      lua_push_str_table_entry(
          vm, "proto_name",
          get_ndpi_full_proto_name(detected_protocol, buf, sizeof(buf)));
      lua_push_uint32_table_entry(vm, "l4_proto", fs->getL4Protocol());
      lua_push_uint32_table_entry(vm, "num_clients", fs->getNumClients());
      lua_push_uint32_table_entry(vm, "num_servers", fs->getNumServers());
      lua_push_uint32_table_entry(vm, "num_flows", fs->getNumFlows());
      lua_push_uint64_table_entry(vm, "bytes_sent", fs->getTotalSent());
      lua_push_uint64_table_entry(vm, "bytes_rcvd", fs->getTotalRcvd());
      lua_push_uint64_table_entry(vm, "total_score", fs->getTotalScore());

      lua_pushinteger(vm, ++num);
      lua_insert(vm, -2);
      lua_settable(vm, -3);

      delete it->second;
    }
  }
}

/* **************************************************** */

struct walk_no_tx_hosts_info {
  lua_State *vm;
  bool local_host_rx_only, list_host_peers;
  std::unordered_map<std::string, bool> hosts;
  NetworkInterface *iface;
};

/* **************************************************** */

static bool setHostNoTXInfo(lua_State *vm, Host *h) {
  u_int32_t a = h->getNumContactedPeersAsClientTCPUDPNoTX();
  u_int32_t b = h->getNumContactsFromPeersAsServerTCPUDPNoTX();

  if ((a > 0) || (b > 0)) {
    IpAddress *i = h->get_ip();
    char buf[64], *label = i->print(buf, sizeof(buf));

    lua_newtable(vm);

    lua_push_uint32_table_entry(vm, "tcp_num_contacted_peers_as_client", a);
    lua_push_uint32_table_entry(vm, "tcp_num_peers_contacts_rcvd_as_server", b);
    lua_push_uint32_table_entry(vm, "tcp_num_ports_contacted_as_client",
                                h->getNumContactedTCPUDPServerPortsNoTX());

    lua_pushstring(vm, label);
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    return (true);
  } else
    return (false);
}

/* **************************************************** */

static bool walk_no_tx_hosts(GenericHashEntry *node, void *user_data,
                             bool *matched) {
  Host *h = (Host *)node;

  if (!(h->isBroadcastHost() || h->isMulticastHost())) {
    struct walk_no_tx_hosts_info *hosts =
        static_cast<struct walk_no_tx_hosts_info *>(user_data);
    bool good = false;

    if (hosts->local_host_rx_only) {
      /* retrieve local host (server) with no TX traffic */
      if (h->isLocalHost()) good = true;
    } else {
      /* retrieve remote host (server) with no TX traffic */
      if (!h->isLocalHost()) good = true;
    }

    if (good) setHostNoTXInfo(hosts->vm, h);
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

static bool walk_no_tx_host_flows(GenericHashEntry *node, void *user_data,
                                  bool *matched) {
  Flow *f = (Flow *)node;
  struct walk_no_tx_hosts_info *hosts =
      static_cast<struct walk_no_tx_hosts_info *>(user_data);
  Host *c = f->get_cli_host(), *s = f->get_srv_host();

  /* View interfaces need this extra step */
  if (c == NULL)
    c = hosts->iface->getHostByIP((IpAddress *)f->get_cli_ip_addr(),
                                  f->get_vlan_id(),
                                  f->getFlowObservationPointId(), false);
  if (s == NULL)
    s = hosts->iface->getHostByIP((IpAddress *)f->get_srv_ip_addr(),
                                  f->get_vlan_id(),
                                  f->getFlowObservationPointId(), false);

  if (c && s && s->isRxOnlyHost()) {
    if (!(s->isBroadcastHost() || s->isMulticastHost())) {
      bool good = false;

      if (hosts->local_host_rx_only) {
        /* retrieve local host (server) with no TX traffic */
        if (c->isLocalHost()) good = true;
      } else {
        /* retrieve remote host (server) with no TX traffic */
        if (!c->isLocalHost()) good = true;
      }

      if (good) {
        IpAddress *i = c->get_ip();
        char buf[64], *what = i->print(buf, sizeof(buf));
        std::string name(what);

        /* ntop->getTrace()->traceEvent(TRACE_NORMAL, "Checking %s",
         * name.c_str()); */

        if (hosts->hosts.find(name) == hosts->hosts.end()) {
          if (setHostNoTXInfo(hosts->vm, c))
            hosts->hosts[name] = true; /* Used to avoid duplicates */
        }
      }
    }
  }

  return (false); /* false = keep on walking */
}

/* **************************************************** */

/*
  local_host_rx_only
  - true:  retrieve local host (server) with no TX traffic
  - false: retrieve remote host (server) with no TX traffic

  list_host_peers
  - true:  retrieve the peers talking with the hosts with no TX traffic
  - false: retrieve the host with no TX traffic
*/
void NetworkInterface::getRxOnlyHostsList(lua_State *vm,
                                          bool local_host_rx_only,
                                          bool list_host_peers) {
  u_int32_t begin_slot = 0;
  struct walk_no_tx_hosts_info hosts;

  lua_newtable(vm);

  hosts.iface = this;

  if (list_host_peers) {
    hosts.local_host_rx_only = local_host_rx_only,
    hosts.list_host_peers = list_host_peers, hosts.vm = vm;
    walker(&begin_slot, true /* walk_all */, walker_flows,
           walk_no_tx_host_flows, &hosts);
  } else {
    hosts.local_host_rx_only = local_host_rx_only,
    hosts.list_host_peers = list_host_peers, hosts.vm = vm;
    walker(&begin_slot, true /* walk_all */, walker_hosts, walk_no_tx_hosts,
           &hosts);
  }
}

/* **************************************************** */

struct LuaArrayEntryStats {
  lua_State *vm;
  u_int num;
};

static bool active_mac_search_walker(GenericHashEntry *he, void *user_data,
                                     bool *matched) {
  struct LuaArrayEntryStats *s = (struct LuaArrayEntryStats *)user_data;
  Mac *m = (Mac *)he;
  char buf[32];

  lua_pushstring(s->vm, m->print(buf, sizeof(buf)));
  lua_rawseti(s->vm, -2, s->num + 1); /* Array */
  s->num++;

  return (false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getActiveMacs(lua_State *vm) {
  struct LuaArrayEntryStats s;
  u_int32_t begin_slot = 0;

  lua_newtable(vm);

  s.vm = vm, s.num = 0;
  walker(&begin_slot, true /* walk_all */, walker_macs,
         active_mac_search_walker, (void *)&s);
}
