/*
 *
 * (C) 2013-17 - ntop.org
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

/* UserActivityStats.cpp */
extern const char* activity_names[];

/* Lua.cpp */
extern int ntop_lua_cli_print(lua_State* vm);
extern int ntop_lua_check(lua_State* vm, const char* func, int pos, int expected_type);

static bool help_printed = false;

/* **************************************************** */

/* Method used for collateral activities */
NetworkInterface::NetworkInterface() { init(); }

/* **************************************************** */

NetworkInterface::NetworkInterface(const char *name,
				   const char *custom_interface_type) {
  NDPI_PROTOCOL_BITMASK all;
  char _ifname[64];
  bool isViewInterface = (strncmp(name, "view:", 5) == 0) ? 1 : 0; /* We need to do it as isView() is not yet initialized */

  customIftype = custom_interface_type, flowHashingMode = flowhashing_none;
  init();

#ifdef WIN32
  if(name == NULL) name = "1"; /* First available interface */
#endif

  scalingFactor = 1, remoteIfname = remoteIfIPaddr = remoteProbeIPaddr = remoteProbePublicIPaddr = NULL;
  if(strcmp(name, "-") == 0) name = "stdin";
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

    macs_hash = new MacHash(this, 4, ntop->getPrefs()->get_max_num_hosts());

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
			    (char*)"Operating System",
			    NDPI_PROTOCOL_CATEGORY_SYSTEM,
			    d_port, d_port);

    // enable all protocols
    NDPI_BITMASK_SET_ALL(all);
    ndpi_set_protocol_detection_bitmask2(ndpi_struct, &all);

    last_pkt_rcvd = last_pkt_rcvd_remote = 0, pollLoopCreated = false, bridge_interface = false;
    next_idle_flow_purge = next_idle_host_purge = 0;
    cpu_affinity = -1 /* no affinity */, has_vlan_packets = false, pkt_dumper = NULL;
    if(ntop->getPrefs()->are_taps_enabled())
      pkt_dumper_tap = new PacketDumperTuntap(this);

    running = false, inline_interface = false, db = NULL;

    if((!isViewInterface) && (ntop->getPrefs()->do_dump_flows_on_mysql())) {
#ifdef NTOPNG_PRO
      if(ntop->getPrefs()->is_enterprise_edition()) db = new BatchedMySQLDB(this);
#endif

      if(db == NULL)
	db = new MySQLDB(this);

      if(!db) throw "Not enough memory";
    }

    checkIdle();
    ifSpeed = Utils::getMaxIfSpeed(name);
    ifMTU = Utils::getIfMTU(name), mtuWarningShown = false;
  } else {
    flows_hash = NULL, hosts_hash = NULL;
    ndpi_struct = NULL, db = NULL, ifSpeed = 0;
    pkt_dumper = NULL, pkt_dumper_tap = NULL;
  }

  networkStats = NULL;

#ifdef NTOPNG_PRO
  policer = NULL; /* possibly instantiated by subclass PacketBridge */
  flow_profiles = ntop->getPro()->has_valid_license() ? new FlowProfiles(id) : NULL;
  if(flow_profiles) flow_profiles->loadProfiles();
  shadow_flow_profiles = NULL;
#endif

  loadDumpPrefs();
  loadScalingFactorPrefs();

  if(((statsManager  = new StatsManager(id, STATS_MANAGER_STORE_NAME)) == NULL)
     || ((alertsManager = new AlertsManager(id, ALERTS_MANAGER_STORE_NAME)) == NULL))
    throw "Not enough memory";

  if((host_pools = new HostPools(this)) == NULL)
    throw "Not enough memory";

  alertLevel = alertsManager->getNumAlerts(true);
}

/* **************************************************** */

void NetworkInterface::init() {
  ifname = remoteIfname = remoteIfIPaddr = remoteProbeIPaddr = NULL,
    remoteProbePublicIPaddr = NULL, flows_hash = NULL, hosts_hash = NULL,
    ndpi_struct = NULL, zmq_initial_bytes = 0, zmq_initial_pkts = 0,
    inline_interface = false, has_vlan_packets = false,
    last_pkt_rcvd = last_pkt_rcvd_remote = 0,
    next_idle_flow_purge = next_idle_host_purge = 0,
    running = false, numSubInterfaces = 0,
    numVirtualInterfaces = 0, flowHashing = NULL,
    pcap_datalink_type = 0, mtuWarningShown = false, lastSecUpdate = 0,
    purge_idle_flows_hosts = true, id = (u_int8_t)-1,
    last_remote_pps = 0, last_remote_bps = 0,
    has_vlan_packets = false,
    pcap_datalink_type = 0, cpu_affinity = -1 /* no affinity */,
    inline_interface = false, running = false, interfaceStats = NULL,
    tooManyFlowsAlertTriggered = tooManyHostsAlertTriggered = false,
    pkt_dumper = NULL, numL2Devices = 0,
    checkpointPktCount = checkpointBytesCount = checkpointPktDropCount = 0,
    pollLoopCreated = false, bridge_interface = false;

  if(ntop && ntop->getPrefs() && ntop->getPrefs()->are_taps_enabled())
    pkt_dumper_tap = new PacketDumperTuntap(this);
  else
    pkt_dumper_tap = NULL;

  memset(subInterfaces, 0, sizeof(subInterfaces));
  ip_addresses = "", networkStats = NULL,
    pcap_datalink_type = 0, cpu_affinity = -1,
    pkt_dumper = NULL;

  memset(lastMinuteTraffic, 0, sizeof(lastMinuteTraffic));
  resetSecondTraffic();

  reloadLuaInterpreter = true, L_flow_create_delete_ndpi = L_flow_update = NULL;

  db = NULL;
#ifdef NTOPNG_PRO
  policer = NULL;
#endif
  statsManager = NULL, alertsManager = NULL, ifSpeed = 0;
  host_pools = NULL;
  checkIdle();
  dump_all_traffic = dump_to_disk = dump_unknown_traffic
    = dump_security_packets = dump_to_tap = false;
  dump_sampling_rate = CONST_DUMP_SAMPLING_RATE;
  dump_max_pkts_file = CONST_MAX_NUM_PACKETS_PER_DUMP;
  dump_max_duration = CONST_MAX_DUMP_DURATION;
  dump_max_files = CONST_MAX_DUMP;
  ifMTU = CONST_DEFAULT_MAX_PACKET_SIZE, mtuWarningShown = false;
#ifdef NTOPNG_PRO
  flow_profiles = shadow_flow_profiles = NULL;
#endif
}

/* **************************************************** */

#ifdef NTOPNG_PRO

void NetworkInterface::initL7Policer() {
  /* Instantiate the policer */
  policer = new L7Policer(this);
}

#endif

/* **************************************************** */

void NetworkInterface::checkAggregationMode() {
 if(!customIftype) {
    char rsp[32];

    if(!strcmp(get_type(), CONST_INTERFACE_TYPE_ZMQ)) {
      if(ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_IFACE_FLOW_COLLECTION, rsp, sizeof(rsp)) == 0) {

	if(!strcmp(rsp, "probe_ip")) flowHashingMode = flowhashing_probe_ip;
	else if(!strcmp(rsp, "ingress_iface_idx")) flowHashingMode = flowhashing_ingress_iface_idx;
      }
    } else {
      if((ntop->getRedis()->get((char*)CONST_RUNTIME_PREFS_IFACE_VLAN_CREATION, rsp, sizeof(rsp)) == 0)
	 && (!strncmp(rsp, "1", 1)))
	flowHashingMode = flowhashing_vlan;
    }
  }
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
    if((ntop->getRedis()->get(rkey, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0')) {
      int val = atoi(rsp);

      if(val == 0) is_idle = true;
    }
  }

  return(is_idle);
}

/* **************************************************** */

void NetworkInterface::deleteDataStructures() {
  if(flows_hash) { delete(flows_hash); flows_hash = NULL; }
  if(hosts_hash) { delete(hosts_hash); hosts_hash = NULL; }
  if(macs_hash)  { delete(macs_hash);  macs_hash = NULL;  }

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

  if(host_pools)     delete host_pools;     /* note: this requires ndpi_struct */
  deleteDataStructures();

  if(remoteIfname)      free(remoteIfname);
  if(remoteIfIPaddr)    free(remoteIfIPaddr);
  if(remoteProbeIPaddr) free(remoteProbeIPaddr);
  if(remoteProbePublicIPaddr) free(remoteProbePublicIPaddr);
  if(db)             delete db;
  if(statsManager)   delete statsManager;
  if(alertsManager)  delete alertsManager;
  if(networkStats)   delete []networkStats;
  if(pkt_dumper)     delete pkt_dumper;
  if(pkt_dumper_tap) delete pkt_dumper_tap;
  if(interfaceStats) delete interfaceStats;

  if(flowHashing) {
    FlowHashing *current, *tmp;

    HASH_ITER(hh, flowHashing, current, tmp) {
      /* Interfaces are deleted by the main termination function */
      HASH_DEL(flowHashing, current);
      free(current);
    }
  }

#ifdef NTOPNG_PRO
  if(policer)       delete(policer);
  if(flow_profiles) delete(flow_profiles);
  if(shadow_flow_profiles) delete(shadow_flow_profiles);
#endif

  termLuaInterpreter();
}

/* **************************************************** */

int NetworkInterface::dumpFlow(time_t when, bool idle_flow, Flow *f) {
  if(ntop->getPrefs()->do_dump_flows_on_mysql()) {
    return(dumpDBFlow(when, idle_flow, f));
  } else if(ntop->getPrefs()->do_dump_flows_on_es())
    return(dumpEsFlow(when, f));
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
    return(-1);
  }
}

/* **************************************************** */

int NetworkInterface::dumpEsFlow(time_t when, Flow *f) {
  char *json = f->serialize(true);
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

int NetworkInterface::dumpDBFlow(time_t when, bool idle_flow, Flow *f) {
  char *json = f->serialize(false);
  int rc;

  if(json) {
    rc = db->dumpFlow(when, idle_flow, f, json);
    free(json);
  } else
    rc = -1;

  return(rc);
}

/* **************************************************** */

static bool local_hosts_2_redis_walker(GenericHashEntry *h, void *user_data) {
  Host *host = (Host*)h;

  if(host && (host->isLocalHost() || host->isSystemHost()))
    host->serialize2redis();

  return(false); /* false = keep on walking */
}

/* **************************************************** */

int NetworkInterface::dumpLocalHosts2redis(bool disable_purge) {
  int rc;

  if(disable_purge) disablePurge(false /* on hosts */);
  rc = walker(walker_hosts, local_hosts_2_redis_walker, NULL) ? 0 : -1;
  if(disable_purge) enablePurge(false /* on hosts */);

  return rc;
}

/* **************************************************** */

u_int32_t NetworkInterface::getHostsHashSize() {
  if(!isView())
    return(hosts_hash->getNumEntries());
  else {
    u_int32_t tot = 0;

    for(u_int8_t s = 0; s<numSubInterfaces; s++)
      tot += subInterfaces[s]->get_hosts_hash()->getNumEntries();

    return(tot);
  }
}

/* **************************************************** */

u_int32_t NetworkInterface::getFlowsHashSize() {
  if(!isView())
    return(flows_hash->getNumEntries());
  else {
    u_int32_t tot = 0;

    for(u_int8_t s = 0; s<numSubInterfaces; s++)
      tot += subInterfaces[s]->get_flows_hash()->getNumEntries();

    return(tot);
  }
}

/* **************************************************** */

u_int32_t NetworkInterface::getMacsHashSize() {
  if(!isView())
    return(macs_hash->getNumEntries());
  else {
    u_int32_t tot = 0;

    for(u_int8_t s = 0; s<numSubInterfaces; s++)
      tot += subInterfaces[s]->get_macs_hash()->getNumEntries();

    return(tot);
  }
}

/* **************************************************** */

bool NetworkInterface::walker(WalkerType wtype,
			      bool (*walker)(GenericHashEntry *h, void *user_data),
			      void *user_data) {
  bool ret = false;

  switch(wtype) {
  case walker_hosts:
    if(!isView())
      ret = hosts_hash->walk(walker, user_data);
    else {
      for(u_int8_t s = 0; s<numSubInterfaces; s++)
	ret |= subInterfaces[s]->get_hosts_hash()->walk(walker, user_data);
    }
    break;

  case walker_flows:
    if(!isView())
      ret = flows_hash->walk(walker, user_data);
    else {
      for(u_int8_t s = 0; s<numSubInterfaces; s++)
	ret |= subInterfaces[s]->get_flows_hash()->walk(walker, user_data);
    }
    break;

  case walker_macs:
    if(!isView())
      ret = macs_hash->walk(walker, user_data);
    else {
      for(u_int8_t s = 0; s<numSubInterfaces; s++)
	ret |= subInterfaces[s]->get_macs_hash()->walk(walker, user_data);
    }

    break;
  }

  return(ret);
}

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
      if(inIndex && ret->get_cli_host()) {
	  Host *host = (Host*)ret->get_cli_host();

	  if(host->isLocalHost() || host->isSystemHost())
	      ret->get_cli_host()->setDeviceIfIdx(deviceIP, inIndex);
      }

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
	     "Interface <A HREF='%s/lua/if_stats.lua?ifid=%d'>%s</A> has too many flows. Please extend the --max-num-flows/-X command line option",
	     ntop->getPrefs()->get_http_prefix(),
	     id, get_name());

    alertsManager->engageInterfaceAlert(this,
					(char*)"app_misconfiguration",
					alert_app_misconfiguration, alert_level_error, alert_msg);
    tooManyFlowsAlertTriggered = true;
  }
}

/* **************************************************** */

void NetworkInterface::triggerTooManyHostsAlert() {
  if(!tooManyHostsAlertTriggered) {
    char alert_msg[512];

    snprintf(alert_msg, sizeof(alert_msg),
	     "Interface <A HREF='%s/lua/if_stats.lua?ifid=%d'>%s</A> has too many hosts. Please extend the --max-num-hosts/-x command line option",
	     ntop->getPrefs()->get_http_prefix(),
	     id, get_name());

    alertsManager->releaseInterfaceAlert(this,
					 (char*)"app_misconfiguration",
					 alert_app_misconfiguration, alert_level_error, alert_msg);
    tooManyHostsAlertTriggered = true;
  }
}

/* **************************************************** */

NetworkInterface* NetworkInterface::getSubInterface(u_int32_t criteria) {
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
	  snprintf(buf, sizeof(buf), "%s [vlanId: %u]", ifname, criteria);
	  break;

	case flowhashing_probe_ip:
	  vIface_type = CONST_INTERFACE_TYPE_FLOW;
	  snprintf(buf, sizeof(buf), "%s [probeIP: %s]", ifname,
		   Utils::intoaV4(criteria, buf1, sizeof(buf1)));
	  break;

	case flowhashing_ingress_iface_idx:
	  vIface_type = CONST_INTERFACE_TYPE_FLOW;
	  snprintf(buf, sizeof(buf), "%s [ifIdx: %u]", ifname, criteria);
	  break;

	default:
	  free(h);
	  return(NULL);
	  break;
	}

	if((h->iface = new NetworkInterface(buf, vIface_type)) != NULL) {
	  HASH_ADD_INT(flowHashing, criteria, h);
	  ntop->registerInterface(h->iface);
	  numVirtualInterfaces++;
	}
      } else
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    }
  }

  if(h) return(h->iface);

  return(NULL);
}

/* **************************************************** */

void NetworkInterface::processFlow(ZMQ_Flow *zflow) {
  bool src2dst_direction, new_flow;
  Flow *flow;
  ndpi_protocol p;
  time_t now = time(NULL);

  if(flowHashingMode != flowhashing_none) {
    NetworkInterface *vIface;

    switch(flowHashingMode) {
    case flowhashing_probe_ip:
      vIface = getSubInterface((u_int32_t)zflow->deviceIP);
      break;

    case flowhashing_ingress_iface_idx:
      vIface = getSubInterface((u_int32_t)zflow->inIndex);
      break;

    default:
      vIface = NULL;
      break;
    }

    if(vIface) {
      vIface->setTimeLastPktRcvd(getTimeLastPktRcvd());
      vIface->processFlow(zflow);
      return;
    }
  }

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
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
				 "[first=%u][last=%u][duration: %u][drift: %d][now: %u][remote: %u]",
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

  incStats(now, zflow->src_ip.isIPv4() ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	   flow ? flow->get_detected_protocol().protocol : NDPI_PROTOCOL_UNKNOWN,
	   zflow->pkt_sampling_rate*(zflow->in_bytes + zflow->out_bytes),
	   zflow->pkt_sampling_rate*(zflow->in_pkts + zflow->out_pkts),
	   24 /* 8 Preamble + 4 CRC + 12 IFG */ + 14 /* Ethernet header */);

  if(flow == NULL)
    return;

  if(zflow->l4_proto == IPPROTO_TCP) {
    struct timeval when;

    when.tv_sec = (long)now, when.tv_usec = 0;
    flow->updateTcpFlags((const struct bpf_timeval*)&when,
			 zflow->tcp_flags, src2dst_direction);
    flow->incTcpBadStats(true,
       zflow->tcp.ooo_in_pkts, zflow->tcp.retr_in_pkts, zflow->tcp.lost_in_pkts);
    flow->incTcpBadStats(false,
       zflow->tcp.ooo_out_pkts, zflow->tcp.retr_out_pkts, zflow->tcp.lost_out_pkts);
  }

  flow->addFlowStats(src2dst_direction,
		     zflow->pkt_sampling_rate*zflow->in_pkts,
		     zflow->pkt_sampling_rate*zflow->in_bytes, 0,
		     zflow->pkt_sampling_rate*zflow->out_pkts,
		     zflow->pkt_sampling_rate*zflow->out_bytes, 0,
		     zflow->last_switched);
  p.protocol = zflow->l7_proto, p.master_protocol = NDPI_PROTOCOL_UNKNOWN;
  flow->setDetectedProtocol(p, true);
  flow->setJSONInfo(json_object_to_json_string(zflow->additional_fields));
  flow->updateActivities();

  flow->updateInterfaceLocalStats(src2dst_direction,
				  zflow->pkt_sampling_rate*(zflow->in_pkts+zflow->out_pkts),
				  zflow->pkt_sampling_rate*(zflow->in_bytes+zflow->out_bytes));

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

  /* purge is actually performed at most one time every FLOW_PURGE_FREQUENCY */
  // purgeIdle(zflow->last_switched);
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
				     u_int32_t rawsize,
				     const struct pcap_pkthdr *h,
				     const u_char *packet,
				     u_int16_t *ndpiProtocol,
				     Host **srcHost, Host **dstHost,
				     Flow **hostFlow) {
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

  /* VLAN disaggregation */
  if((flowHashingMode == flowhashing_vlan) && (vlan_id > 0)) {
    NetworkInterface *vIface;

    if((vIface = getSubInterface((u_int32_t)vlan_id)) != NULL) {
      vIface->setTimeLastPktRcvd(getTimeLastPktRcvd());
      return(vIface->processPacket(when, time, eth, vlan_id,
				   iph, ip6, ipsize, rawsize,
				   h, packet, ndpiProtocol,
				   srcHost, dstHost, hostFlow));
    }
  }

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

  /* Updating Flow */
  flow = getFlow(eth_src, eth_dst, vlan_id, 0, 0, 0, &src_ip, &dst_ip, src_port, dst_port,
		 l4_proto, &src2dst_direction, last_pkt_rcvd, last_pkt_rcvd, &new_flow);

  if(flow == NULL) {
    incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN,
	     rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
    return(pass_verdict);
  } else {
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

        if((flow->get_cli_host()->isLocalHost()) && (flow->get_srv_host()->isLocalHost())) {
          /* Set correct direction in localhost ping */
          if((icmp_type == 8) ||                  /* ICMP Echo [RFC792] */
            (icmp_type == 128))                   /* ICMPV6 Echo Request [RFC4443] */
            src2dst_direction = true;
          else if((icmp_type == 0) ||             /* ICMP Echo Reply [RFC792] */
            (icmp_type == 129))                   /* ICMPV6 Echo Reply [RFC4443] */
            src2dst_direction = false;
        }

        flow->setICMP(icmp_type, icmp_code);
      }
      break;
    }

#ifdef __OpenBSD__
    struct timeval tv_ts;
    tv_ts.tv_sec  = h->ts.tv_sec;
    tv_ts.tv_usec = h->ts.tv_usec;
    flow->incStats(src2dst_direction, rawsize, payload, payload_len, l4_proto, &tv_ts);
#else
    flow->incStats(src2dst_direction, rawsize, payload, payload_len, l4_proto, &h->ts);
#endif
  }

  /* Protocol Detection */
  flow->updateActivities();
  flow->updateInterfaceLocalStats(src2dst_direction, 1, rawsize);

  if(!flow->isDetectionCompleted()) {
    if(isSampledTraffic())
      flow->guessProtocol();
    else {
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
  }

  if(flow->isDetectionCompleted()
     && (!isSampledTraffic())
     && flow->get_cli_host()
     && flow->get_srv_host()) {
    struct ndpi_flow_struct *ndpi_flow;

    switch(ndpi_get_lower_proto(flow->get_detected_protocol())) {
    case NDPI_PROTOCOL_DHCP:
      if(payload_len > 240) {
	for(int i = 240; i<payload_len; ) {
	  u_int8_t id  = payload[i], len = payload[i+1];

	  if(len == 0) break;

	  if(id == 12 /* Host Name */) {
	    char name[64], buf[24], *client_mac, key[64];
	    int j;

	    j = ndpi_min(len, sizeof(name)-1);
	    strncpy((char*)name, (char*)&payload[i+2], j);
	    name[j] = '\0';

	    client_mac = Utils::formatMac(&payload[28], buf, sizeof(buf)),
	    ntop->getTrace()->traceEvent(TRACE_INFO, "[DHCP] %s = '%s'", client_mac, name);

	    snprintf(key, sizeof(key), DHCP_CACHE, get_id());
	    ntop->getRedis()->hashSet(key, client_mac, name);
	    break;
	  } else if(id == 0xFF)
	    break; /* End of options */

	  i += len + 2;
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
      if(flow->isSSLProto())
        flow->dissectSSL(payload, payload_len, when, src2dst_direction);
    }

    flow->processDetectedProtocol();

#ifdef NTOPNG_PRO
    if(is_bridge_interface()) {
	pass_verdict = flow->isPassVerdict();

	if(pass_verdict) {
	    u_int8_t shaper_ingress, shaper_engress;
	    char buf[64];

	    flow->getFlowShapers(src2dst_direction, &shaper_ingress, &shaper_engress);
	    ntop->getTrace()->traceEvent(TRACE_DEBUG, "[%s] %u / %u ",
					 flow->get_detected_protocol_name(buf, sizeof(buf)),
					 shaper_ingress, shaper_engress);
	    pass_verdict = passShaperPacket(shaper_ingress, shaper_engress, (struct pcap_pkthdr*)h);
	}
    }
#endif

    bool dump_if_unknown = dump_unknown_traffic
      && (!flow->isDetectionCompleted() ||
	  flow->get_detected_protocol().protocol == NDPI_PROTOCOL_UNKNOWN);

    if(dump_if_unknown
       || dump_all_traffic
       || dump_security_packets
       || flow->dumpFlowTraffic()) {
      if(dump_to_disk) dumpPacketDisk(h, packet, dump_if_unknown ? UNKNOWN : GUI);
      if(dump_to_tap)  dumpPacketTap(h, packet, GUI);
    }
  }

  incStats(when->tv_sec, iph ? ETHERTYPE_IP : ETHERTYPE_IPV6,
	   flow->get_detected_protocol().protocol,
	   rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);

  // Detect user activities
  if((!isSampledTraffic())
      && (ntop->getPrefs()->is_flow_activity_enabled())) {
    Host *cli = flow->get_cli_host();
    Host *srv = flow->get_srv_host();

    if((cli->isLocalHost() || srv->isLocalHost())
       && (!flow->isSSLProto() || flow->isSSLData())) {
      UserActivityID activity;
      u_int64_t up = 0, down = 0, backgr = 0, bytes = payload_len;

      if(flow->getActivityId(&activity)) {
#ifdef __OpenBSD__
        struct timeval* tv_when;
        tv_when->tv_sec  = when->tv_sec;
        tv_when->tv_usec = when->tv_usec;
        if(flow->invokeActivityFilter(tv_when, src2dst_direction, payload_len)) {
#else 
        if(flow->invokeActivityFilter(when, src2dst_direction, payload_len)) {
#endif
          if(src2dst_direction)
            up = bytes;
          else
            down = bytes;
        } else {
          backgr = bytes;
        }

        if(cli->isLocalHost())
          cli->incActivityBytes(activity, up, down, backgr);

        if(srv->isLocalHost())
          srv->incActivityBytes(activity, down, up, backgr);
      }
    }
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

    if((n = purgeIdleHostsMacs()) > 0)
      ntop->getTrace()->traceEvent(TRACE_INFO, "Purged %u/%u idle hosts/macs on %s",
				   n, getNumHosts()+getNumMacs(), ifname);
  }

  if(pkt_dumper) pkt_dumper->idle(when);
  updateSecondTraffic(when);
}

/* **************************************************** */

bool NetworkInterface::dissectPacket(const struct pcap_pkthdr *h,
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

  if(h->len > ifMTU) {
    if(!mtuWarningShown) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Invalid packet received [len: %u][max-len: %u].", h->len, ifMTU);
      ntop->getTrace()->traceEvent(TRACE_WARNING, "If you have TSO/GRO enabled, please disable it");
#ifdef linux
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Use: sudo ethtool -K %s gro off gso off tso off", ifname);
#endif
      mtuWarningShown = true;
    }
  }

  setTimeLastPktRcvd(h->ts.tv_sec);

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
      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	incStats(h->ts.tv_sec, ETHERTYPE_IP, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	      incStats(h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
		incStats(h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	    incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	    return(pass_verdict);
	  }
	}
      }

      if((vlan_id == 0) && ntop->getPrefs()->do_simulate_vlans())
	vlan_id = (ip6 ? ip6->ip6_src.u6_addr.u6_addr8[15] : iph->saddr) & 0xFF;

      try {
	pass_verdict = processPacket(&h->ts, time, ethernet, vlan_id, iph,
				     ip6, h->caplen - ip_offset, rawsize,
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
    if(h->caplen >= ip_offset) {
      struct ndpi_iphdr *iph = NULL;
      struct ndpi_ipv6hdr *ip6 = (struct ndpi_ipv6hdr*)&packet[ip_offset];

      if((ntohl(ip6->ip6_ctlun.ip6_un1.ip6_un1_flow) & 0xF0000000) != 0x60000000) {
	/* This is not IPv6 */
	incStats(h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	    incStats(h->ts.tv_sec, ETHERTYPE_IPV6, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
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
	      incStats(h->ts.tv_sec, 0, NDPI_PROTOCOL_UNKNOWN, rawsize, 1, 24 /* 8 Preamble + 4 CRC + 12 IFG */);
	      return(pass_verdict);
	    }
	  }
	}

	if((vlan_id == 0) && ntop->getPrefs()->do_simulate_vlans())
	  vlan_id = (ip6 ? ip6->ip6_src.u6_addr.u6_addr8[15] : iph->saddr) & 0xFF;

	try {
	  pass_verdict = processPacket(&h->ts, time, ethernet, vlan_id,
				       iph, ip6, h->len - ip_offset, rawsize,
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
    Mac *srcMac = getMac(ethernet->h_source, vlan_id, true);
    Mac *dstMac = getMac(ethernet->h_dest, vlan_id, true);

    if(srcMac) srcMac->incSentStats(rawsize);
    if(dstMac) dstMac->incRcvdStats(rawsize);

    incStats(h->ts.tv_sec, eth_type, NDPI_PROTOCOL_UNKNOWN, rawsize,
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
  next_idle_flow_purge = next_idle_host_purge = 0;
  cpu_affinity = -1, has_vlan_packets = false;
  running = false, inline_interface = false;

  getStats()->cleanup();

  flows_hash->cleanup();
  hosts_hash->cleanup();
  macs_hash->cleanup();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Cleanup interface %s", get_name());
}

/* **************************************************** */

void NetworkInterface::findFlowHosts(u_int16_t vlanId,
				     u_int8_t src_mac[6], IpAddress *_src_ip, Host **src,
				     u_int8_t dst_mac[6], IpAddress *_dst_ip, Host **dst) {

  if(!isView())
    (*src) = hosts_hash->get(vlanId, _src_ip);
  else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if(((*src) = subInterfaces[s]->get_hosts_hash()->get(vlanId, _src_ip)) != NULL)
	break;
    }
  }

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

struct ndpiStatsRetrieverData {
  nDPIStats *stats;
  Host *host;
};

static bool flow_sum_protos(GenericHashEntry *flow, void *user_data) {
  ndpiStatsRetrieverData *retriever = (ndpiStatsRetrieverData*)user_data;
  nDPIStats *stats = retriever->stats;
  Flow *f = (Flow*)flow;

  if(retriever->host
       && (retriever->host != f->get_cli_host())
       && (retriever->host != f->get_srv_host()))
    return(false); /* false = keep on walking */

  f->sumStats(stats);
  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::getnDPIStats(nDPIStats *stats, AddressTree *allowed_hosts,
          const char *host_ip, u_int16_t vlan_id) {
  ndpiStatsRetrieverData retriever;

  Host *h = NULL;
  if (host_ip)
    h = findHostsByIP(allowed_hosts, (char *)host_ip, vlan_id);

  retriever.stats = stats;
  retriever.host = h;
  walker(walker_flows, flow_sum_protos, (void*)&retriever);
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

static bool update_macs_stats(GenericHashEntry *node, void *user_data) {
  Mac *mac = (Mac*)node;
  struct timeval *tv = (struct timeval*)user_data;

  mac->updateStats(tv);

  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::periodicStatsUpdate() {
  struct timeval tv;

  if(isView()) return;

  gettimeofday(&tv, NULL);

  flows_hash->walk(flow_update_hosts_stats, (void*)&tv);
  hosts_hash->walk(update_hosts_stats, (void*)&tv);
  macs_hash->walk(update_macs_stats, (void*)&tv);

  if(ntop->getPrefs()->do_dump_flows_on_mysql()) {
    static_cast<MySQLDB*>(db)->updateStats(&tv);
    db->flush(false /* not idle, periodic activities */);
  }

#ifdef NTOPNG_PRO
  if(host_pools)
    host_pools->updateStats(&tv);
#endif
}

/* **************************************************** */

struct update_host_pool_l7policy {
  bool update_pool_id;
  bool update_l7policy;
};

static bool update_host_host_pool_l7policy(GenericHashEntry *node, void *user_data) {
  Host *h = (Host*)node;
  update_host_pool_l7policy *up = (update_host_pool_l7policy*)user_data;
#ifdef HOST_POOLS_DEBUG
  char buf[128];
  u_int16_t cur_pool_id = h->get_host_pool();
#endif

  if(up->update_pool_id)
    h->updateHostPool();

  if(up->update_l7policy)
    h->updateHostL7Policy();

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

/* **************************************************** */

void NetworkInterface::refreshHostPools() {
  if(isView()) return;

  struct update_host_pool_l7policy update_host;
  update_host.update_pool_id = true;
  update_host.update_l7policy = false;

#ifdef NTOPNG_PRO
  if(is_bridge_interface() && getL7Policer()) {
    /* Every pool is associated with a set of L7 rules
     so a refresh must be triggered to seal this association */
    getL7Policer()->refreshL7Rules();
    /* Must refresh host l7policies as a change in the host pool id
       may determine an l7policy change for that host */
    update_host.update_l7policy = true;
  }
#endif

  hosts_hash->walk(update_host_host_pool_l7policy, &update_host);

#ifdef NTOPNG_PRO
  if(update_host.update_l7policy)
    updateFlowsL7Policy();
#endif
}

/* **************************************************** */

#ifdef NTOPNG_PRO

/* **************************************************** */

static bool update_flow_l7_policy(GenericHashEntry *node, void *user_data) {
  Flow *f = (Flow*)node;

  f->updateFlowShapers();
  f->updateProfile();

  return(false); /* false = keep on walking */
}


/* **************************************************** */

void NetworkInterface::updateHostsL7Policy(u_int16_t host_pool_id) {
  if(isView()) return;

  struct update_host_pool_l7policy update_host;
  update_host.update_pool_id = false;
  update_host.update_l7policy = true;

  hosts_hash->walk(update_host_host_pool_l7policy, &update_host);
}

/* **************************************************** */

void NetworkInterface::updateFlowsL7Policy() {
  if(isView()) return;

  flows_hash->walk(update_flow_l7_policy, NULL);
}

#endif

/* **************************************************** */

struct host_find_info {
  char *host_to_find;
  u_int16_t vlan_id;
  Host *h;
};

/* **************************************************** */

struct mac_find_info {
  u_int8_t mac[6];
  u_int16_t vlan_id;
  Mac *m;
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

static bool find_mac_by_name(GenericHashEntry *h, void *user_data) {
  struct mac_find_info *info = (struct mac_find_info*)user_data;
  Mac *m = (Mac*)h;

  if((info->m == NULL)
     && (m->get_vlan_id() == info->vlan_id)
     && (!memcmp(info->mac, m->get_mac(), 6))
     ) {
    info->m = m;
    return(true); /* found */
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

bool NetworkInterface::restoreHost(char *host_ip, u_int16_t vlan_id) {
  Host *h = new Host(this, host_ip, vlan_id);

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
    walker(walker_hosts, find_host_by_name, (void*)&info);

    h = info.h;
  } else {
    IpAddress *ip = new IpAddress();

    if(ip) {
      ip->set(host_ip);

      if(!isView())
	h = hosts_hash->get(vlan_id, ip);
      else {
	for(u_int8_t s = 0; s<numSubInterfaces; s++) {
	  h = subInterfaces[s]->get_hosts_hash()->get(vlan_id, ip);
	  if(h) break;
	}
      }

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

void NetworkInterface::updateFlowProfiles() {
  if(isView()) return;

  if(ntop->getPro()->has_valid_license()) {
    FlowProfiles *newP;

    if(shadow_flow_profiles) {
      delete shadow_flow_profiles;
      shadow_flow_profiles = NULL;
    }

    flow_profiles->dumpCounters();
    shadow_flow_profiles = flow_profiles, newP = new FlowProfiles(id);

    newP->loadProfiles(); /* and reload */
    flow_profiles = newP; /* Overwrite the current profiles */

    flows_hash->walk(update_flow_profile, NULL);
  }
}

#endif

/* **************************************************** */

bool NetworkInterface::getHostInfo(lua_State* vm,
				   AddressTree *allowed_hosts,
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
				          AddressTree *allowed_hosts,
				          char *host_ip, u_int16_t vlan_id) {
  Host *h = findHostsByIP(allowed_hosts, host_ip, vlan_id);

  if(h) {
    h->loadAlertPrefs();
    return(true);
  }
  return(false);
}

/* **************************************************** */

Host* NetworkInterface::findHostsByIP(AddressTree *allowed_hosts,
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
  u_int64_t numericValue;
  char *stringValue;
};

struct flowHostRetriever {
  /* Search criteria */
  AddressTree *allowed_hosts;
  Host *host;
  Mac *mac;
  char *manufacturer;
  bool skipSpecialMacs, hostMacsOnly;
  char *country;
  int ndpi_proto;
  sortField sorter;
  LocationPolicy location;
  u_int16_t *vlan_id;
  char *osFilter;
  u_int32_t *asnFilter;
  int16_t *networkFilter;
  u_int16_t *poolFilter;

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

  if(retriever->actNumEntries >= retriever->maxNumEntries)
    return(true); /* Limit reached */

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
  }
  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool host_search_walker(GenericHashEntry *he, void *user_data) {
  char buf[64];
  struct flowHostRetriever *r = (struct flowHostRetriever*)user_data;
  Host *h = (Host*)he;

  if(r->actNumEntries >= r->maxNumEntries)
    return(true); /* Limit reached */

  if(!h || h->idle() || !h->match(r->allowed_hosts))
    return(false);

  if((r->location == location_local_only      && !h->isLocalHost())         ||
     (r->location == location_remote_only     && h->isLocalHost())          ||
     (r->vlan_id       && *(r->vlan_id)       != h->get_vlan_id())          ||
     (r->asnFilter     && *(r->asnFilter)     != h->get_asn())              ||
     (r->networkFilter && *(r->networkFilter) != h->get_local_network_id()) ||
     (r->networkFilter && *(r->networkFilter) != h->get_local_network_id()) ||
     (r->hostMacsOnly  && h->getMac() && h->getMac()->isSpecialMac())       ||
     (r->mac           && (h->getMac() != r->mac))                          ||
     (r->poolFilter    && *(r->poolFilter)    != h->get_host_pool())        ||
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
    r->elems[r->actNumEntries++].stringValue = strdup(h->get_name(buf, sizeof(buf), false));
    break;

  case column_country:
    r->elems[r->actNumEntries++].stringValue = strdup(h->get_country() ? h->get_country() : (char*)"");
    break;

  case column_os:
    r->elems[r->actNumEntries++].stringValue = strdup(h->get_os() ? h->get_os() : (char*)"");
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

  case column_traffic:
    r->elems[r->actNumEntries++].numericValue = h->getNumBytes();
    break;

  case column_local_network_id:
    r->elems[r->actNumEntries++].numericValue = h->get_local_network_id();
    break;

  case column_mac:
    r->elems[r->actNumEntries++].numericValue = Utils::macaddr_int(h->get_mac());
    break;

  case column_pool_id:
    r->elems[r->actNumEntries++].numericValue = h->get_host_pool();
    break;

    /* Criteria */
  case column_uploaders:      r->elems[r->actNumEntries++].numericValue = h->getNumBytesSent(); break;
  case column_downloaders:    r->elems[r->actNumEntries++].numericValue = h->getNumBytesRcvd(); break;
  case column_unknowers:      r->elems[r->actNumEntries++].numericValue = h->get_ndpi_stats()->getProtoBytes(NDPI_PROTOCOL_UNKNOWN); break;
  case column_incomingflows:  r->elems[r->actNumEntries++].numericValue = h->getNumIncomingFlows(); break;
  case column_outgoingflows:  r->elems[r->actNumEntries++].numericValue = h->getNumOutgoingFlows(); break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
    break;
  }

  return(false); /* false = keep on walking */
}

/* **************************************************** */

static bool mac_search_walker(GenericHashEntry *he, void *user_data) {
  struct flowHostRetriever *r = (struct flowHostRetriever*)user_data;
  Mac *m = (Mac*)he;

  if(r->actNumEntries >= r->maxNumEntries)
    return(true); /* Limit reached */

  if(!m
     || m->idle()
     || ((r->vlan_id && (*(r->vlan_id) != m->get_vlan_id())))
     || (r->skipSpecialMacs && m->isSpecialMac())
     || (r->hostMacsOnly && m->getNumHosts() == 0))
    return(false); /* false = keep on walking */

  r->elems[r->actNumEntries].macValue = m;

  switch(r->sorter) {
  case column_mac:
    r->elems[r->actNumEntries++].numericValue = Utils::macaddr_int(m->get_mac());
    break;

  case column_vlan:
    r->elems[r->actNumEntries++].numericValue = m->get_vlan_id();
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

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error: column %d not handled", r->sorter);
    break;
  }

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

void NetworkInterface::disablePurge(bool on_flows) {
  if(!isView()) {
    if(on_flows)
      flows_hash->disablePurge();
    else {
      hosts_hash->disablePurge();
      macs_hash->disablePurge();
    }
  } else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if(on_flows)
	subInterfaces[s]->get_flows_hash()->disablePurge();
      else {
	subInterfaces[s]->get_hosts_hash()->disablePurge();
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
      macs_hash->enablePurge();
    }
  } else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if(on_flows)
	subInterfaces[s]->get_flows_hash()->enablePurge();
      else {
	subInterfaces[s]->get_hosts_hash()->enablePurge();
	subInterfaces[s]->get_macs_hash()->enablePurge();
      }
    }
  }
}

/* **************************************************** */

int NetworkInterface::getFlows(lua_State* vm,
			       AddressTree *allowed_hosts,
			       Host *host, int ndpi_proto,
			       LocationPolicy location,
			       char *sortColumn,
			       u_int32_t maxHits,
			       u_int32_t toSkip,
			       bool a2zSortOrder) {
  struct flowHostRetriever retriever;
  int (*sorter)(const void *_a, const void *_b);
  DetailsLevel highDetails = (location == location_local_only || (maxHits != CONST_MAX_NUM_HITS)) ? details_high : details_normal;

  if((maxHits > CONST_MAX_NUM_HITS) || (maxHits == 0)) maxHits = CONST_MAX_NUM_HITS;
  retriever.pag = NULL;
  retriever.host = host, retriever.ndpi_proto = ndpi_proto, retriever.location = location;
  retriever.actNumEntries = 0, retriever.maxNumEntries = getFlowsHashSize(), retriever.allowed_hosts = allowed_hosts;
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

  disablePurge(true);
  walker(walker_flows, flow_search_walker, (void*)&retriever);

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

  enablePurge(true);
  free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getFlows(lua_State* vm,
			       AddressTree *allowed_hosts,
			       LocationPolicy location, Host *host,
			       Paginator *p) {
  struct flowHostRetriever retriever;
  int (*sorter)(const void *_a, const void *_b);
  char sortColumn[32];
  DetailsLevel highDetails;

  if(p == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to return results with a NULL paginator");
    return(-1);
  }

  highDetails = p->detailedResults() ? details_high : (location == location_local_only || (p && p->maxHits() != CONST_MAX_NUM_HITS)) ? details_high : details_normal;

  retriever.pag = p;
  retriever.host = host, retriever.location = location;
  retriever.actNumEntries = 0, retriever.maxNumEntries = getFlowsHashSize(), retriever.allowed_hosts = allowed_hosts;
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
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn);
    retriever.sorter = column_bytes, sorter = numericSorter;
  }

  /* ******************************* */

  disablePurge(true);
  walker(walker_flows, flow_search_walker, (void*)&retriever);

  qsort(retriever.elems, retriever.actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "numFlows", retriever.actNumEntries);

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

  lua_pushstring(vm, "flows");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  enablePurge(true);
  free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getLatestActivityHostsList(lua_State* vm, AddressTree *allowed_hosts) {
  struct flowHostRetriever retriever;

  memset(&retriever, 0, sizeof(retriever));

  // there's not even the need to use the retriever or to sort results here
  // we use the retriever just to leverage on the exising code.
  retriever.allowed_hosts = allowed_hosts, retriever.location = location_all;
  retriever.actNumEntries = 0, retriever.maxNumEntries = getHostsHashSize();
  retriever.sorter = column_vlan; // just a placeholder, we don't care as we won't sort
  retriever.elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever.maxNumEntries);

  if(retriever.elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  disablePurge(false);
  walker(walker_hosts, host_search_walker, (void*)&retriever);

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

  enablePurge(false);
  free(retriever.elems);

  return(retriever.actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortHosts(struct flowHostRetriever *retriever,
				AddressTree *allowed_hosts,
				bool host_details,
				LocationPolicy location,
				char *countryFilter, char *mac_filter,
				u_int16_t *vlan_id, char *osFilter,
				u_int32_t *asnFilter, int16_t *networkFilter,
				u_int16_t *pool_filter,
				bool hostMacsOnly, char *sortColumn) {
  u_int32_t maxHits;
  int (*sorter)(const void *_a, const void *_b);

  if(retriever == NULL)
    return -1;

  maxHits = getHostsHashSize();
  if((maxHits > CONST_MAX_NUM_HITS) || (maxHits == 0))
    maxHits = CONST_MAX_NUM_HITS;

  memset(retriever, 0, sizeof(struct flowHostRetriever));

  if(mac_filter) {
    u_int8_t macAddr[6];

    Utils::parseMac(macAddr, mac_filter);

    retriever->mac = macs_hash->get(vlan_id ? *vlan_id : 0, (const u_int8_t*)macAddr);
  }

  retriever->allowed_hosts = allowed_hosts, retriever->location = location,
  retriever->country = countryFilter, retriever->vlan_id = vlan_id,
  retriever->osFilter = osFilter, retriever->asnFilter = asnFilter,
  retriever->networkFilter = networkFilter, retriever->actNumEntries = 0,
  retriever->poolFilter = pool_filter;
  retriever->maxNumEntries = maxHits, retriever->hostMacsOnly = hostMacsOnly;
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
  else if(!strcmp(sortColumn, "column_traffic")) retriever->sorter = column_traffic, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_local_network_id")) retriever->sorter = column_local_network_id, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_mac")) retriever->sorter = column_mac, sorter = numericSorter;
  /* criteria (datatype sortField in ntop_typedefs.h / see also host_search_walker:NetworkInterface.cpp) */
  else if(!strcmp(sortColumn, "column_uploaders")) retriever->sorter = column_uploaders, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_downloaders")) retriever->sorter = column_downloaders, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_unknowers")) retriever->sorter = column_unknowers, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_incomingflows")) retriever->sorter = column_incomingflows, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_outgoingflows")) retriever->sorter = column_outgoingflows, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_pool_id")) retriever->sorter = column_pool_id, sorter = numericSorter;
  else {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn);
    retriever->sorter = column_traffic, sorter = numericSorter;
  }

  // make sure the caller has disabled the purge!!
  walker(walker_hosts, host_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::sortMacs(struct flowHostRetriever *retriever,
			       u_int16_t vlan_id, bool skipSpecialMacs,
			       bool hostMacsOnly,
			       char *sortColumn) {
  u_int32_t maxHits;
  int (*sorter)(const void *_a, const void *_b);

  if(retriever == NULL)
    return -1;

  maxHits = getMacsHashSize();
  if((maxHits > CONST_MAX_NUM_HITS) || (maxHits == 0))
    maxHits = CONST_MAX_NUM_HITS;

  retriever->vlan_id = &vlan_id, retriever->skipSpecialMacs = skipSpecialMacs,
    retriever->hostMacsOnly = hostMacsOnly, retriever->actNumEntries = 0,
    retriever->maxNumEntries = maxHits,
    retriever->elems = (struct flowHostRetrieveList*)calloc(sizeof(struct flowHostRetrieveList), retriever->maxNumEntries);

  if(retriever->elems == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Out of memory :-(");
    return(-1);
  }

  if((!strcmp(sortColumn, "column_mac")) || (!strcmp(sortColumn, "column_"))) retriever->sorter = column_mac, sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_vlan"))         retriever->sorter = column_vlan,         sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_since"))        retriever->sorter = column_since,        sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_thpt"))         retriever->sorter = column_thpt,         sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_traffic"))      retriever->sorter = column_traffic,      sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_hosts"))        retriever->sorter = column_num_hosts,    sorter = numericSorter;
  else if(!strcmp(sortColumn, "column_manufacturer")) retriever->sorter = column_manufacturer, sorter = stringSorter;
  else ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown sort column %s", sortColumn), sorter = numericSorter;

  // make sure the caller has disabled the purge!!
  walker(walker_macs, mac_search_walker, (void*)retriever);

  qsort(retriever->elems, retriever->actNumEntries, sizeof(struct flowHostRetrieveList), sorter);

  return(retriever->actNumEntries);
}

/* **************************************************** */

int NetworkInterface::getActiveHostsList(lua_State* vm, AddressTree *allowed_hosts,
					 bool host_details, LocationPolicy location,
					 char *countryFilter, char *mac_filter,
					 u_int16_t *vlan_id, char *osFilter,
					 u_int32_t *asnFilter, int16_t *networkFilter,
					 u_int16_t *pool_filter,
					 char *sortColumn, u_int32_t maxHits,
					 u_int32_t toSkip, bool a2zSortOrder) {
  struct flowHostRetriever retriever;

  disablePurge(false);

  if(sortHosts(&retriever, allowed_hosts, host_details, location,
	       countryFilter, mac_filter, vlan_id, osFilter,
	       asnFilter, networkFilter, pool_filter, true, sortColumn) < 0) {
    enablePurge(false);
    return -1;
  }

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "numHosts", retriever.actNumEntries);

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
  }

  // finally free the elements regardless of the sorted kind
  if(retriever.elems) free(retriever.elems);

  return(retriever.actNumEntries);
}
/* **************************************************** */

int NetworkInterface::getActiveHostsGroup(lua_State* vm, AddressTree *allowed_hosts,
					  bool host_details, LocationPolicy location,
					  char *countryFilter,
					  u_int16_t *vlan_id, char *osFilter,
					  u_int32_t *asnFilter, int16_t *networkFilter,
					  u_int16_t *pool_filter,
					  bool local_macs, char *groupColumn) {
  struct flowHostRetriever retriever;
  Grouper *gper;

  disablePurge(false);

  // sort hosts according to the grouping criterion
  if(sortHosts(&retriever, allowed_hosts, host_details, location,
	       countryFilter, NULL /* Mac */, vlan_id,
	       osFilter, asnFilter, networkFilter, pool_filter,
	       local_macs, groupColumn) < 0 ) {
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

  enablePurge(false);

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
  walker(walker_flows, flow_stats_walker, (void*)&stats);

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

static bool host_activity_walker(GenericHashEntry *he, void *user_data) {
  HostActivityRetriever * r = (HostActivityRetriever *)user_data;
  Host *h = (Host*)he;
  int i;

  if(!h
     || !h->equal(&r->search)
     || (!h->get_user_activities()))
    return(false); /* false = keep on walking */

  r->found = true;
  for(i=0; i<UserActivitiesN; i++)
    r->counters[i] = *h->getActivityBytes((UserActivityID)i);

  return true; /* found, stop walking */
}

/* **************************************************** */

void NetworkInterface::getLocalHostActivity(lua_State* vm, const char *host) {
  HostActivityRetriever retriever(host);
  int i;

  disablePurge(false);
  walker(walker_hosts, host_activity_walker, &retriever);
  enablePurge(false);

  if(retriever.found) {
    lua_newtable(vm);
    for(i=0; i<UserActivitiesN; i++) {
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

    if(ntop->getPrefs()->do_dump_flows_on_mysql()) {
      // flush the queue
      db->flush(true /* idle */);
    }

    next_idle_flow_purge = last_pkt_rcvd + FLOW_PURGE_FREQUENCY;
    return(n);
  }
}

/* **************************************************** */

u_int64_t NetworkInterface::getNumPackets() {
  u_int64_t tot = ethStats.getNumPackets();
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getNumPackets();
  return(tot);
};

/* **************************************************** */

u_int64_t NetworkInterface::getNumBytes() {
  u_int64_t tot = ethStats.getNumBytes();
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getNumBytes();
  return(tot);
}

/* **************************************************** */

u_int32_t NetworkInterface::getNumPacketDrops() {
  u_int32_t tot = getNumDroppedPackets();
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getNumDroppedPackets();
  return(tot);
};

/* **************************************************** */

u_int NetworkInterface::getNumFlows()        {
  u_int tot = flows_hash ? flows_hash->getNumEntries() : 0;
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getNumFlows();
  return(tot);
};

/* **************************************************** */

u_int NetworkInterface::getNumHosts()        {
  u_int tot = hosts_hash ? hosts_hash->getNumEntries() : 0;
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getNumHosts();
  return(tot);
};

/* **************************************************** */

u_int NetworkInterface::getNumHTTPHosts()    {
  u_int tot = hosts_hash ? hosts_hash->getNumHTTPEntries() : 0;
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getNumHTTPHosts();
  return(tot);
};

/* **************************************************** */

u_int NetworkInterface::getNumMacs()        {
  u_int tot = macs_hash ? macs_hash->getNumEntries() : 0;
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getNumMacs();
  return(tot);
};

/* **************************************************** */

u_int NetworkInterface::purgeIdleHostsMacs() {
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
    n = hosts_hash->purgeIdle() + macs_hash->purgeIdle();
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

void NetworkInterface::getnDPIProtocols(lua_State *vm, ndpi_protocol_category_t filter) {
  int i;

  lua_newtable(vm);

  for(i=0; i<(int)ndpi_struct->ndpi_num_supported_protocols; i++) {
    char buf[8];

    if (ndpi_struct->proto_defaults[i].protoCategory == filter) {
      snprintf(buf, sizeof(buf), "%d", i);
      lua_push_str_table_entry(vm, ndpi_struct->proto_defaults[i].protoName, buf);
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

  walker(walker_flows, num_flows_state_walker, num_flows);

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
    walker(walker_flows, num_flows_walker, num_flows);

    for(int i=0; i<(int)ndpi_struct->ndpi_num_supported_protocols; i++) {
      if(num_flows[i] > 0)
	lua_push_int_table_entry(vm, ndpi_struct->proto_defaults[i].protoName, num_flows[i]);
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

  lua_push_str_table_entry(vm, "name", ifname);
  lua_push_int_table_entry(vm, "scalingFactor", scalingFactor);
  lua_push_int_table_entry(vm,  "id", id);
  lua_push_bool_table_entry(vm, "isView", isView()); /* View interface */
  lua_push_int_table_entry(vm,  "seen.last", getTimeLastPktRcvd());
  lua_push_bool_table_entry(vm, "inline", get_inline_interface());
  lua_push_bool_table_entry(vm, "vlan",   get_has_vlan_packets());

  if(remoteIfname)      lua_push_str_table_entry(vm, "remote.name",    remoteIfname);
  if(remoteIfIPaddr)    lua_push_str_table_entry(vm, "remote.if_addr", remoteIfIPaddr);
  if(remoteProbeIPaddr) lua_push_str_table_entry(vm, "probe.ip", remoteProbeIPaddr);
  if(remoteProbePublicIPaddr) lua_push_str_table_entry(vm, "probe.public_ip", remoteProbePublicIPaddr);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "packets",     getNumPackets());
  lua_push_int_table_entry(vm, "bytes",       getNumBytes());
  lua_push_int_table_entry(vm, "flows",       getNumFlows());
  lua_push_int_table_entry(vm, "hosts",       getNumHosts());
  lua_push_int_table_entry(vm, "http_hosts",  getNumHTTPHosts());
  lua_push_int_table_entry(vm, "drops",       getNumPacketDrops());
  lua_push_int_table_entry(vm, "devices", numL2Devices);
  /* even if the counter is global, we put it here on every interface
     as we may decide to make an elasticsearch thread per interface.
   */
  if(ntop->getPrefs()->do_dump_flows_on_es()) {
    ntop->getElasticSearch()->lua(vm, false /* Overall */);
  } else if(ntop->getPrefs()->do_dump_flows_on_mysql()) {
    if(db) db->lua(vm, false /* Overall */);
  }
  lua_pushstring(vm, "stats");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "packets",     getNumPackets() - getCheckPointNumPackets());
  lua_push_int_table_entry(vm, "bytes",       getNumBytes() - getCheckPointNumBytes());
  lua_push_int_table_entry(vm, "drops",       getNumPacketDrops() - getCheckPointNumPacketDrops());
  if(ntop->getPrefs()->do_dump_flows_on_es()) {
    ntop->getElasticSearch()->lua(vm, true /* Since last checkpoint */);
  } else if(ntop->getPrefs()->do_dump_flows_on_mysql()) {
    if(db) db->lua(vm, true /* Since last checkpoint */);
  }
  lua_pushstring(vm, "stats_since_reset");
  lua_insert(vm, -2);
  lua_settable(vm, -3);

  lua_push_int_table_entry(vm, "remote_pps", last_remote_pps);
  lua_push_int_table_entry(vm, "remote_bps", last_remote_bps);

  lua_push_str_table_entry(vm, "type", (char*)get_type());
  lua_push_int_table_entry(vm, "speed", ifSpeed);
  lua_push_int_table_entry(vm, "mtu", ifMTU);
  lua_push_int_table_entry(vm, "alertLevel", alertLevel);
  lua_push_str_table_entry(vm, "ip_addresses", (char*)getLocalIPAddresses());

  sumStats(&_tcpFlowStats, &_ethStats, &_localStats,
	   &_ndpiStats, &_pktStats, &_tcpPacketStats);

  for(u_int8_t s = 0; s<numSubInterfaces; s++)
    subInterfaces[s]->sumStats(&_tcpFlowStats, &_ethStats,
			       &_localStats, &_ndpiStats, &_pktStats, &_tcpPacketStats);

  _tcpFlowStats.lua(vm, "tcpFlowStats");
  _ethStats.lua(vm);
  _localStats.lua(vm);
  _ndpiStats.lua(this, vm);
  _pktStats.lua(vm, "pktSizeDistribution");
  _tcpPacketStats.lua(vm, "tcpPacketStats");

  if(!isView()) {
    if(pkt_dumper)    pkt_dumper->lua(vm);
#ifdef NTOPNG_PRO
    if(flow_profiles) flow_profiles->lua(vm);
#endif
  }
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

Mac* NetworkInterface::getMac(u_int8_t _mac[6], u_int16_t vlanId,
			      bool createIfNotPresent) {
  Mac *ret = NULL;

  if(_mac == NULL) return(NULL);

  if(!isView())
    ret = macs_hash->get(vlanId, _mac);
  else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      if((ret = subInterfaces[s]->get_macs_hash()->get(vlanId, _mac)) != NULL)
	break;
    }
  }

  if((ret == NULL) && createIfNotPresent) {
    try {
      if((ret = new Mac(this, _mac, vlanId)) != NULL)
	macs_hash->add(ret);
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
  Flow *f;

  if(!isView())
    f = (Flow*)(flows_hash->findByKey(key));
  else {
    for(u_int8_t s = 0; s<numSubInterfaces; s++) {
      f = (Flow*)subInterfaces[s]->get_flows_hash()->findByKey(key);
      if(f) break;
    }
  }

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

static bool hosts_search_walker(GenericHashEntry *h, void *user_data) {
  Host *host = (Host*)h;
  struct search_host_info *info = (struct search_host_info*)user_data;

  if(host->addIfMatching(info->vm, info->allowed_hosts, info->host_name_or_ip))
    info->num_matches++;

  /* Stop after CONST_MAX_NUM_FIND_HITS matches */
  return((info->num_matches > CONST_MAX_NUM_FIND_HITS) ? true /* stop */ : false /* keep walking */);
}

/* **************************************************** */

bool NetworkInterface::findHostsByName(lua_State* vm,
				       AddressTree *allowed_hosts,
				       char *key) {
  struct search_host_info info;

  info.vm = vm, info.host_name_or_ip = key, info.num_matches = 0, info.allowed_hosts = allowed_hosts;

  lua_newtable(vm);
  walker(walker_hosts, hosts_search_walker, (void*)&info);
  return(info.num_matches > 0);
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
					     AddressTree *allowed_hosts,
					     char *host_ip, u_int16_t vlan_id) {
  Host *h = getHost(host_ip, vlan_id);

  if(h) {
    struct correlator_host_info info;

    memset(&info, 0, sizeof(info));

    info.vm = vm, info.h = h;
    h->getActivityStats()->extractPoints(&info.x);
    walker(walker_hosts, correlator_walker, &info);

    return(true);
  } else
    return(false);
}

/* **************************************************** */

bool NetworkInterface::similarHostActivity(lua_State* vm,
					   AddressTree *allowed_hosts,
					   char *host_ip, u_int16_t vlan_id) {
  Host *h = getHost(host_ip, vlan_id);

  if(h) {
    struct correlator_host_info info;

    memset(&info, 0, sizeof(info));

    info.vm = vm, info.h = h;
    h->getActivityStats()->extractPoints(&info.x);
    walker(walker_hosts, similarity_walker, &info);

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
    f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
    lua_pushnumber(info->vm, f->key()); // Key
    lua_insert(info->vm, -2);
    lua_settable(info->vm, -3);
  }
  return(false); /* false = keep on walking */
}

/* **************************************************** */

void NetworkInterface::findUserFlows(lua_State *vm, char *username) {
  struct user_flows u;

  u.vm = vm, u.username = username;
  walker(walker_flows, userfinder_walker, &u);
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
      f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
      lua_pushnumber(info->vm, f->key()); // Key
      lua_insert(info->vm, -2);
      lua_settable(info->vm, -3);
  } else {
    name = f->get_proc_name(false);

    if(name && (strcmp(name, info->proc_name) == 0)) {
        f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
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
  walker(walker_flows, proc_name_finder_walker, &u);
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
    f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
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
  walker(walker_flows, pidfinder_walker, &u);
}

/* **************************************** */

static bool father_pidfinder_walker(GenericHashEntry *node, void *father_pid_data) {
  Flow *f = (Flow*)node;
  struct pid_flows *info = (struct pid_flows*)father_pid_data;

  if((f->getFatherPid(true) == info->pid) || (f->getFatherPid(false) == info->pid)) {
    f->lua(info->vm, NULL, details_normal /* Minimum details */, false);
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
  walker(walker_flows, father_pidfinder_walker, &u);
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
  walker(walker_hosts, virtual_http_hosts_walker, &info);
}

/* **************************************** */

bool NetworkInterface::isInterfaceUp(char *name) {
#ifdef WIN32
  return(true);
#else
  struct ifreq ifr;
  int sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_IP);

  if(strlen(name) >= sizeof(ifr.ifr_name))
    return(false);

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

/* **************************************** */

void NetworkInterface::checkPointCounters(bool drops_only) {
  if(!drops_only) {
    checkpointPktCount = getNumPackets(),
      checkpointBytesCount = getNumBytes();
  }
  checkpointPktDropCount = getNumPacketDrops();

  if(ntop->getPrefs()->do_dump_flows_on_es()) {
    ntop->getElasticSearch()->checkPointCounters(drops_only);
  } else if(ntop->getPrefs()->do_dump_flows_on_mysql()) {
    if(db) db->checkPointCounters(drops_only);
  }
}

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointNumPackets() {
  u_int64_t tot = checkpointPktCount;
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getCheckPointNumPackets();
  return(tot);
};

/* **************************************************** */

u_int64_t NetworkInterface::getCheckPointNumBytes() {
  u_int64_t tot = checkpointBytesCount;
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getCheckPointNumBytes();
  return(tot);
}

/* **************************************************** */

u_int32_t NetworkInterface::getCheckPointNumPacketDrops() {
  u_int32_t tot = checkpointPktDropCount;
  for(u_int8_t s = 0; s<numSubInterfaces; s++) tot += subInterfaces[s]->getCheckPointNumPacketDrops();
  return(tot);
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
    /*
     * Don't override ethStats here, these stats are properly updated
     * inside NetworkInterface::processFlow for ZMQ interfaces.
     * Overriding values here may cause glitches and non-strictly-increasing counters
     * yielding negative rates.
    ethStats.setNumBytes(remBytes), ethStats.setNumPackets(remPkts);
     *
    */
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

ndpi_protocol_category_t NetworkInterface::get_ndpi_proto_category(u_int protoid) {
  ndpi_protocol proto;
  proto.protocol = NDPI_PROTOCOL_UNKNOWN;
  proto.master_protocol = protoid;
  return get_ndpi_proto_category(proto);
}

/* **************************************** */

static int lua_flow_get_ndpi_category(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, ndpi_category_str(f->get_detected_protocol_category()));
  return(CONST_LUA_OK);
}

/* **************************************** */

static int lua_flow_get_ndpi_proto(lua_State* vm) {
  Flow *f;
  char buf[32];

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, f->get_detected_protocol_name(buf, sizeof(buf)));
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

static int lua_flow_get_http_content_type(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  lua_pushstring(vm, f->getHTTPContentType());
  return(CONST_LUA_OK);
}

/* **************************************** */

static int lua_flow_dump(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  f->lua(vm, NULL, details_high, false);
  return(CONST_LUA_OK);
}

/* **************************************** */

/* -1 on error */
static int lua_flow_get_profile_id(lua_State* vm) {
  Flow *f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  UserActivityID uaid;
  lua_pushnumber(vm, f->getActivityId(&uaid) ? uaid : -1);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/* -1 on error */
static int lua_flow_get_activity_filter_id(lua_State* vm) {
  Flow * f;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  ActivityFilterID fid;
  lua_pushnumber(vm, f->getActivityFilterId(&fid) ? fid : -1);
  return(CONST_LUA_OK);
}

/* ****************************************** */

/*
 * lua params:
 *    activityID  - ID of the activity to apply for filtered bytes
 *    filterID    - ID of the filter to apply to the flow for activity recording
 *    *parametes  - parameters to pass to the filter - See below
 *
 * SMA/WMA filter params:
 *    edge         - moving average edge to trigger activity
 *    minsamples   - minimum number of samples for activity detection
 * WMA filter params:
 *    timescale    - division scale for each second difference from previous packet. 0 to disable
 *    aggrsecs     - max packet seconds difference to aggregate. 0 to disable
 * SMA filter params:
 *    timebound    - expected time tick in milliseconds between activity packets. 0 to disable
 *    sustain      - time, in milliseconds, between packets to be considered activity. 0 to disable
 *
 * CommandSequence filter params:
 *    mustwait     - if true, activity trigger requires server to wait after command request
 *    minbytes     - minimum number of bytes to trigger activity
 *    maxinterval  - maximum milliseconds difference between interactions
 *    mincommands  - minimum number of commands seen in the flow to trigger activity
 *    minflips     - minimum number of server interactions to trigger activity
 *
 * Web filter params:
 *    numsamples   - number of packets to process for detection
 *    minbytes     - minimum number of bytes to trigger activity
 *    maxinterval  - maximum milliseconds difference between packets
 *    serverdominant - if true, server bytes must be more then client bytes
 *    forceWebProfile - if true, force 'web' profile for unknown and 'other' flow profiles
 *
 * Ratio filter params:
 *    numsamples   - number of packets to process for detection
 *    minbytes     - minimum number of bytes to trigger activity
 *    clisrv_ratio - minimum (positive ? client/server : server/client) bytes to trigger activity
 *
 * Interflow filter params:
 *    minflows     - minimum number of concurrent flows. -1 to disable [1]
 *    minpkts      - minimum number of cumulative packets in concurrent flows to trigger activity
 *    minduration  - minimum (max duration of cumulative packets) in concurrent flows. -1 to disable [1]
 *    sslonly      - if true, only SSL traffic can trigger activity
 *   NOTE: At least one of [1] must be satisfied to trigger activity
 */
static int lua_flow_set_activity_filter(lua_State* vm) {
  UserActivityID activityID;
  ActivityFilterID filterID;
  Flow *f;
  activity_filter_config config = {};
  u_int8_t params = 0;

  lua_getglobal(vm, CONST_USERACTIVITY_FLOW);
  f = (Flow*)lua_touserdata(vm, lua_gettop(vm));
  if(!f) return(CONST_LUA_ERROR);

  if(ntop_lua_check(vm, __FUNCTION__, params+1, LUA_TNUMBER)) return(CONST_LUA_ERROR);
  activityID = (UserActivityID)lua_tonumber(vm, ++params);
  if(activityID >= UserActivitiesN) return(CONST_LUA_ERROR);

  if(lua_type(vm, params+1) == LUA_TNUMBER)
    filterID = (ActivityFilterID)lua_tonumber(vm, ++params);
  else
    return(CONST_LUA_ERROR);

  // filter specific parameters
  switch(filterID) {
    case activity_filter_all:
      if(lua_type(vm, params+1) == LUA_TBOOLEAN) {
        config.all.pass = lua_toboolean(vm, ++params);
      }
      switch (params) {
        case 2+0: config.all.pass = true;
      }
      break;

    case activity_filter_web:
      if(lua_type(vm, params+1) == LUA_TNUMBER) {
        config.web.numsamples = lua_tonumber(vm, ++params);

        if(lua_type(vm, params+1) == LUA_TNUMBER) {
          config.web.minbytes = lua_tonumber(vm, ++params);

          if(lua_type(vm, params+1) == LUA_TNUMBER) {
            config.web.maxinterval = lua_tonumber(vm, ++params);

            if(lua_type(vm, params+1) == LUA_TBOOLEAN) {
              config.web.forceWebProfile = lua_toboolean(vm, ++params);

              if(lua_type(vm, params+1) == LUA_TBOOLEAN)
                config.web.serverdominant = lua_toboolean(vm, ++params);
            }
          }
        }
      }
      // defaults
      switch (params) {
        case 2+0: config.web.numsamples = 4;
        case 2+1: config.web.minbytes = 0;
        case 2+2: config.web.maxinterval = 2000;
        case 2+3: config.web.forceWebProfile = true;
        case 2+4: config.web.serverdominant = true;
      }
      break;

    case activity_filter_ratio:
      if(lua_type(vm, params+1) == LUA_TNUMBER) {
        config.ratio.numsamples = lua_tonumber(vm, ++params);

        if(lua_type(vm, params+1) == LUA_TNUMBER) {
          config.ratio.minbytes = lua_tonumber(vm, ++params);

          if(lua_type(vm, params+1) == LUA_TNUMBER)
            config.ratio.clisrv_ratio = lua_tonumber(vm, ++params);
        }
      }
      // defaults
      switch (params) {
        case 2+0: config.ratio.numsamples = 4;
        case 2+1: config.ratio.minbytes = 0;
        case 2+2: config.ratio.clisrv_ratio = -1.f;
      }
      break;

    case activity_filter_interflow:
      if(lua_type(vm, params+1) == LUA_TNUMBER) {
        config.interflow.minflows = min((int)lua_tonumber(vm, ++params), INTER_FLOW_ACTIVITY_SLOTS);

        if(lua_type(vm, params+1) == LUA_TNUMBER) {
          config.interflow.minpkts = lua_tonumber(vm, ++params);

          if(lua_type(vm, params+1) == LUA_TNUMBER) {
            config.interflow.minduration = lua_tonumber(vm, ++params);

            if(lua_type(vm, params+1) == LUA_TBOOLEAN)
              config.interflow.sslonly = lua_toboolean(vm, ++params);
          }
        }
      }
      // defaults
      switch (params) {
        case 2+0: config.interflow.minflows = INTER_FLOW_ACTIVITY_SLOTS;
        case 2+1: config.interflow.minpkts = 200;
        case 2+2: config.interflow.minduration = -1;
        case 2+3: config.interflow.sslonly = false;
      }
      break;

    case activity_filter_metrics_test:
      break;

    case activity_filter_sma:
      if(lua_type(vm, params+1) == LUA_TNUMBER) {
        config.sma.edge = lua_tonumber(vm, ++params);

        if(lua_type(vm, params+1) == LUA_TNUMBER) {
          config.sma.minsamples = lua_tonumber(vm, ++params);

          if(lua_type(vm, params+1) == LUA_TNUMBER) {
            config.sma.timebound = lua_tonumber(vm, ++params);

            if(lua_type(vm, params+1) == LUA_TNUMBER)
              config.sma.sustain = lua_tonumber(vm, ++params);
          }
        }
      }
      // defaults
      switch (params) {
        case 2+0: config.sma.edge = 0;
        case 2+1: config.sma.minsamples = ACTIVITY_FILTER_WMA_SAMPLES;
        case 2+2: config.sma.timebound = 2000;
        case 2+3: config.sma.sustain = 1000;
      }
      break;

    case activity_filter_wma:
      if(lua_type(vm, params+1) == LUA_TNUMBER) {
        config.wma.edge = lua_tonumber(vm, ++params);

        if(lua_type(vm, params+1) == LUA_TNUMBER) {
          config.wma.minsamples = lua_tonumber(vm, ++params);

          if(lua_type(vm, params+1) == LUA_TNUMBER) {
            config.wma.timescale = lua_tonumber(vm, ++params);

            if(lua_type(vm, params+1) == LUA_TNUMBER)
              config.wma.aggrsecs = lua_tonumber(vm, ++params);
          }
        }
      }
      // defaults
      switch (params) {
        case 2+0: config.wma.edge = 0;
        case 2+1: config.wma.minsamples = ACTIVITY_FILTER_WMA_SAMPLES;
        case 2+2: config.wma.timescale = 1.f;
        case 2+3: config.wma.aggrsecs = 0;
      }
      break;

    case activity_filter_command_sequence:
      if(lua_type(vm, params+1) == LUA_TBOOLEAN) {
        config.command_sequence.mustwait = lua_toboolean(vm, ++params);

        if(lua_type(vm, params+1) == LUA_TNUMBER) {
          config.command_sequence.minbytes = lua_tonumber(vm, ++params);

          if(lua_type(vm, params+1) == LUA_TNUMBER) {
            config.command_sequence.maxinterval = lua_tonumber(vm, ++params);

            if(lua_type(vm, params+1) == LUA_TNUMBER) {
              config.command_sequence.mincommands = lua_tonumber(vm, ++params);

              if(lua_type(vm, params+1) == LUA_TNUMBER)
                config.command_sequence.minflips = lua_tonumber(vm, ++params);
            }
          }
        }
      }
      switch (params) {
        case 2+0: config.command_sequence.mustwait = false;
        case 2+1: config.command_sequence.minbytes = 0;
        case 2+2: config.command_sequence.maxinterval = 3000;
        case 2+3: config.command_sequence.mincommands = 1;
        case 2+4: config.command_sequence.minflips = 1;
      }
      break;

    default:
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid activity filter (%d)", filterID);
      return (CONST_LUA_ERROR);
  }

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Flow %p setActivityFilter: filter=%d activity=%d", f, filterID, activityID);
  f->setActivityFilter(filterID, &config);
  f->setActivityId(activityID);

  return(CONST_LUA_OK);
}

/* ****************************************** */

static const luaL_Reg flow_reg[] = {
  { "getNdpiCategory",   lua_flow_get_ndpi_category },
  { "getNdpiProto",      lua_flow_get_ndpi_proto },
  { "getNdpiProtoId",    lua_flow_get_ndpi_proto_id },
  { "getFirstSeen",      lua_flow_get_first_seen },
  { "getLastSeen",       lua_flow_get_last_seen },
  { "getServerName",     lua_flow_get_server_name },
  { "getHTTPUrl",        lua_flow_get_http_url },
  { "getHTTPContentType",lua_flow_get_http_content_type },
  { "dump",              lua_flow_dump },
  { "setActivityFilter", lua_flow_set_activity_filter },
  { "getProfileId",      lua_flow_get_profile_id },
  { "getActivityFilterId", lua_flow_get_activity_filter_id },
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

  // Activity profiles - see ntop_typedefs.h
  lua_newtable(L);
  for(int i=0; i<UserActivitiesN; i++)
    lua_push_int_table_entry(L, activity_names[i], i);
  lua_setglobal(L, CONST_USERACTIVITY_PROFILES);

  // Activity filters
  lua_newtable(L);
  lua_push_int_table_entry(L, "All", activity_filter_all);
  lua_push_int_table_entry(L, "SMA", activity_filter_sma);
  lua_push_int_table_entry(L, "WMA", activity_filter_wma);
  lua_push_int_table_entry(L, "CommandSequence", activity_filter_command_sequence);
  lua_push_int_table_entry(L, "Web", activity_filter_web);
  lua_push_int_table_entry(L, "Ratio", activity_filter_ratio);
  lua_push_int_table_entry(L, "Interflow", activity_filter_interflow);
  lua_push_int_table_entry(L, "Metrics", activity_filter_metrics_test);
  lua_setglobal(L, CONST_USERACTIVITY_FILTERS);

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

  return(L);
}

/* **************************************** */

void NetworkInterface::termLuaInterpreter() {
  if(L_flow_create_delete_ndpi) { lua_close(L_flow_create_delete_ndpi); L_flow_create_delete_ndpi = NULL; }
  if(L_flow_update) { lua_close(L_flow_update); L_flow_update = NULL; }
}

/* **************************************** */

int NetworkInterface::luaEvalFlow(Flow *f, const LuaCallback cb) {
  int rc;
  lua_State *L;
  const char *luaFunction;

  return(0); // FIX
  if(reloadLuaInterpreter) {
    if(L_flow_create_delete_ndpi || L_flow_update) termLuaInterpreter();
    L_flow_create_delete_ndpi = initLuaInterpreter(CONST_FLOWACTIVITY_SCRIPT);
    L_flow_update = initLuaInterpreter(CONST_FLOWACTIVITY_SCRIPT);
    reloadLuaInterpreter = false;
  }

  switch(cb) {
  case callback_flow_create:
    L = L_flow_create_delete_ndpi, luaFunction = CONST_LUA_FLOW_CREATE;
    break;

  case callback_flow_delete:
    L = L_flow_create_delete_ndpi, luaFunction = CONST_LUA_FLOW_DELETE;
    break;

  case callback_flow_update:
    L = L_flow_update, luaFunction = CONST_LUA_FLOW_UPDATE;
    break;

  case callback_flow_proto_callback:
    L = L_flow_create_delete_ndpi, luaFunction = CONST_LUA_FLOW_NDPI_DETECT;
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid lua callback (%d)", cb);
    return(-1);
  }

  if(L == NULL)
    return(-2);

  lua_settop(L, 0); /* Reset stack */
  lua_pushlightuserdata(L, f);
  lua_setglobal(L, CONST_USERACTIVITY_FLOW);

  lua_getglobal(L, luaFunction); /* function to be called */
  if((rc = lua_pcall(L, 0 /* 0 parameters */, 0 /* no return values */, 0)) != 0) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Error while executing %s [rc=%d][%s]", luaFunction, rc, lua_tostring(L, -1));
  }

  return(rc);
}

/* **************************************** */

int NetworkInterface::getActiveMacList(lua_State* vm, u_int16_t vlan_id,
				       bool skipSpecialMacs,
				       bool hostMacsOnly,
				       char *sortColumn, u_int32_t maxHits,
				       u_int32_t toSkip, bool a2zSortOrder) {
  struct flowHostRetriever retriever;
  bool show_details = true;

  disablePurge(false);

  if(sortMacs(&retriever, vlan_id, skipSpecialMacs, hostMacsOnly, sortColumn) < 0) {
    enablePurge(false);
    return -1;
  }

  lua_newtable(vm);
  lua_push_int_table_entry(vm, "numMacs", retriever.actNumEntries);

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

bool NetworkInterface::getMacInfo(lua_State* vm, char *mac, u_int16_t vlan_id) {
  struct mac_find_info info;

  memset(&info, 0, sizeof(info));
  Utils::parseMac(info.mac, mac), info.vlan_id = vlan_id;

  walker(walker_macs, find_mac_by_name, (void*)&info);

  if(info.m) {
    info.m->lua(vm, true, false);

    return(true);
  } else
    return(false);
}


