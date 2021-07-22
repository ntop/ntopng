/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef FORCE_VALID_LICENSE
#ifdef NTOPNG_PRO
extern "C" {
#ifdef WIN32
#include "license.h"
#else
#include "../../license/license.h"
#endif
}
#endif
#endif

/* ******************************************* */

Prefs::Prefs(Ntop *_ntop) {
  num_deferred_interfaces_to_register = 0, cli = NULL;
  ntop = _ntop, pcap_file_purge_hosts_flows = false,
    ignore_vlans = false, simulate_vlans = false, ignore_macs = false;
  local_networks = strdup(CONST_DEFAULT_HOME_NET "," CONST_DEFAULT_LOCAL_NETS);
  num_simulated_ips = 0, enable_behaviour_analysis = false;
  local_networks_set = false, shutdown_when_done = false;
  enable_users_login = true, disable_localhost_login = false;
  enable_dns_resolution = sniff_dns_responses = true, use_promiscuous_mode = true;
  resolve_all_host_ip = false, online_license_check = false, service_license_check = false;
  max_num_hosts = MAX_NUM_INTERFACE_HOSTS, max_num_flows = MAX_NUM_INTERFACE_HOSTS;
  attacker_max_num_flows_per_sec = victim_max_num_flows_per_sec = CONST_MAX_NEW_FLOWS_SECOND;
  attacker_max_num_syn_per_sec = victim_max_num_syn_per_sec = CONST_MAX_NUM_SYN_PER_SECOND;
  ewma_alpha_percent = CONST_DEFAULT_EWMA_ALPHA_PERCENT;
  data_dir = strdup(CONST_DEFAULT_DATA_DIR);
  emit_flow_alerts = emit_host_alerts = true;
  zmq_publish_events_url = NULL;
  enable_access_log = false, enable_sql_log = false;
  enable_flow_device_port_rrd_creation = false;
  reproduce_at_original_speed = false;
  enable_top_talkers = false, enable_idle_local_hosts_cache = false;
  enable_active_local_hosts_cache = false,
    enable_tiny_flows_export = true,
    enable_captive_portal = false, mac_based_captive_portal = false,
    enable_arp_matrix_generation = false,
    enable_informative_captive_portal = false,
    override_dst_with_post_nat_dst = false, override_src_with_post_nat_src = false;
    hostMask = no_host_mask;
  enable_asn_behaviour_analysis = enable_network_behaviour_analysis = enable_iface_l7_behaviour_analysis = false; 
  enable_mac_ndpi_stats = false;
  auto_assigned_pool_id = NO_HOST_POOL_ID;
  default_l7policy = PASS_ALL_SHAPER_ID;
  device_protocol_policies_enabled = false, enable_vlan_trunk_bridge = false;
  max_extracted_pcap_bytes = CONST_DEFAULT_MAX_EXTR_PCAP_BYTES;
  behaviour_analysis_learning_period = CONST_DEFAULT_BEHAVIOUR_ANALYSIS_LEARNING_PERIOD;
  behaviour_analysis_learning_status_during_learning = service_allowed;
  behaviour_analysis_learning_status_post_learning = service_allowed;
  iec60870_learning_period = CONST_IEC104_LEARNING_TIME;
  auth_session_duration = HTTP_SESSION_DURATION;
  auth_session_midnight_expiration = HTTP_SESSION_MIDNIGHT_EXPIRATION;
  install_dir = NULL, captureDirection = PCAP_D_INOUT;
  docs_dir = strdup(CONST_DEFAULT_DOCS_DIR);
  scripts_dir = strdup(CONST_DEFAULT_SCRIPTS_DIR);
  callbacks_dir = strdup(CONST_DEFAULT_CALLBACKS_DIR);
  pcap_dir = NULL;
  test_pre_script_path = test_post_script_path = NULL;
  config_file_path = ndpi_proto_path = NULL;
  http_port = CONST_DEFAULT_NTOP_PORT;
  http_prefix = strdup("");
  instance_name = NULL;
  categorization_enabled = false, enable_users_login = true;
  categorization_key = NULL, zmq_encryption_pwd = NULL;
  enable_zmq_encryption = false, zmq_encryption_priv_key = NULL;
  export_zmq_encryption_key = NULL;
  es_index = es_url = es_user = es_pwd = es_host = NULL;
  https_port = 0; // CONST_DEFAULT_NTOP_PORT+1;
  change_user = true;
  user = strdup(CONST_DEFAULT_NTOP_USER);
  user_set = false;
  http_binding_address1 = NULL;
  http_binding_address2 = NULL;
  https_binding_address1 = NULL; // CONST_ANY_ADDRESS;
  https_binding_address2 = NULL;
  enable_client_x509_auth = false;
  timeseries_driver = ts_driver_rrd;
  lan_interface = wan_interface = NULL;
  cpu_affinity = other_cpu_affinity = NULL;
  flow_table_time = false;
#ifdef HAVE_LIBCAP
  CPU_ZERO(&other_cpu_affinity_mask);
#endif
#ifdef HAVE_PF_RING
  pfring_cluster_id = -1;
#endif
  redis_host = strdup("127.0.0.1");
  redis_password = NULL;
  redis_port = 6379;
  redis_db_id = 0;
  dns_mode = 0;
  pid_path = strdup(DEFAULT_PID_PATH);
  packet_filter = NULL;
  num_interfaces = 0, enable_auto_logout = true, enable_auto_logout_at_runtime = true;
  dump_flows_on_es = dump_flows_on_mysql = dump_flows_on_syslog = dump_flows_on_nindex = false;
  dump_json_flows_on_disk = load_json_flows_from_disk_to_nindex = dump_ext_json = false;
  routing_mode_enabled = false;
  global_dns_forging_enabled = false;
#ifdef NTOPNG_PRO
  dump_flows_direct = false;
#endif
  read_flows_from_mysql = false;
  enable_runtime_flows_dump = true;
  enable_activities_debug = false;
#ifndef HAVE_NEDGE
  appliance = false;
#endif

#ifdef NTOPNG_PRO
  print_maintenance = print_license = false;
#endif
  print_version = print_version_json = false;

  if(!(ifNames = (InterfaceInfo*)calloc(UNLIMITED_NUM_INTERFACES, sizeof(InterfaceInfo)))
     || !(deferred_interfaces_to_register = (char**)calloc(UNLIMITED_NUM_INTERFACES, sizeof(char*))))
    throw "Not enough memory";

  json_labels_string_format = true;
#ifdef WIN32
  daemonize = true;
#else
  daemonize = false;
#endif
  export_endpoint = NULL;
  enable_ixia_timestamps = enable_vss_apcon_timestamps = false;

  es_type = strdup((char*)"flows"), es_index = strdup((char*)"ntopng-%Y.%m.%d"),
    es_url = strdup((char*)"http://localhost:9200/_bulk"),
    es_user = strdup((char*)""), es_pwd = strdup((char*)""), es_host = strdup((char*)"");

  mysql_host = mysql_dbname = mysql_tablename = mysql_user = mysql_pw = NULL;
  mysql_port = CONST_DEFAULT_MYSQL_PORT;
  #ifndef WIN32
  flows_syslog_facility = CONST_DEFAULT_DUMP_SYSLOG_FACILITY;
  #endif
  ls_host = NULL;
  ls_port = NULL;
  ls_proto = NULL;
  has_cmdl_trace_lvl = false;

#ifdef HAVE_NEDGE
  disable_dns_resolution();
  disable_dns_responses_decoding();
#endif

  /* All allowed */
  iec104_allowed_typeids[0] = (u_int64_t)-1, iec104_allowed_typeids[1] = (u_int64_t)-1;
}

/* ******************************************* */

Prefs::~Prefs() {
  if(ifNames) {
    for(int i = 0; i < num_interfaces; i++) {
      if(ifNames[i].name) free(ifNames[i].name);
      if(ifNames[i].description) free(ifNames[i].description);
    }

    free(ifNames);
    ifNames = NULL;
  }

  if(deferred_interfaces_to_register) {
    for(int i = 0; i < num_deferred_interfaces_to_register; i++) {
      if(deferred_interfaces_to_register[i])
	free(deferred_interfaces_to_register[i]);
    }

    free(deferred_interfaces_to_register);
    deferred_interfaces_to_register = NULL;
  }

  if(zmq_publish_events_url) free(zmq_publish_events_url);
  if(data_dir)         free(data_dir);
  if(install_dir)      free(install_dir);
  if(docs_dir)         free(docs_dir);
  if(scripts_dir)      free(scripts_dir);
  if(callbacks_dir)    free(callbacks_dir);
  if(pcap_dir)         free(pcap_dir);
  if(config_file_path) free(config_file_path);
  if(user)             free(user);
  if(pid_path)         free(pid_path);
  if(packet_filter)    free(packet_filter);
  if(cpu_affinity)     free(cpu_affinity);
  if(other_cpu_affinity) free(other_cpu_affinity);
  if(es_type)          free(es_type);
  if(es_index)         free(es_index);
  if(es_url)           free(es_url);
  if(es_user)          free(es_user);
  if(es_pwd)           free(es_pwd);
  if(es_host)          free(es_host);
  if(instance_name)    free(instance_name);
  free(http_prefix);
  free(local_networks);
  free(redis_host);
  if(redis_password)  free(redis_password);
  if(cli)             free(cli);
  if(mysql_host)      free(mysql_host);
  if(mysql_dbname)    free(mysql_dbname);
  if(mysql_tablename) free(mysql_tablename);
  if(mysql_user)      free(mysql_user);
  if(mysql_pw)        free(mysql_pw);
  if(ls_host)         free(ls_host);
  if(ls_port)	      free(ls_port);
  if(ls_proto)	      free(ls_proto);
  if(http_binding_address1)  free(http_binding_address1);
  if(http_binding_address2)  free(http_binding_address2);
  if(https_binding_address1) free(https_binding_address1);
  if(https_binding_address2) free(https_binding_address2);
  if(lan_interface)	free(lan_interface);
  if(wan_interface)	free(wan_interface);
  if(ndpi_proto_path)	free(ndpi_proto_path);
  if(test_pre_script_path)  free(test_pre_script_path);
  if(test_post_script_path) free(test_post_script_path);
}

/* ******************************************* */

/* C-binding needed by Win32 service call */
void nDPIusage() {
  printf("\nnDPI detected protocols:\n");

  struct ndpi_detection_module_struct *ndpi_struct = ndpi_init_detection_module(ndpi_no_prefs);
  ndpi_dump_protocols(ndpi_struct);

  exit(0);
}

/* ******************************************* */

/* C-binding needed by Win32 service call */
void usage() {
  printf("ntopng %s%s v.%s - " NTOP_COPYRIGHT "\n\n"
	 "Usage:\n"
	 "  ntopng <configuration file path>\n"
	 "  or\n"
	 "  ntopng <command line options> \n\n"
	 "Options:\n"
#ifndef HAVE_NEDGE
	 "[--dns-mode|-n] <mode>              | DNS address resolution mode\n"
	 "                                    | 0 - Decode DNS responses and resolve\n"
	 "                                    |     local numeric IPs only (default)\n"
	 "                                    | 1 - Decode DNS responses and resolve all\n"
	 "                                    |     numeric IPs\n"
	 "                                    | 2 - Decode DNS responses and don't\n"
	 "                                    |     resolve numeric IPs\n"
	 "                                    | 3 - Don't decode DNS responses and don't\n"
	 "                                    |     resolve numeric IPs\n"
#endif
	 "[--interface|-i] <interface|pcap>   | Input interface name (numeric/symbolic),\n"
         "                                    | view or pcap file path\n"
#ifndef WIN32
	 "[--data-dir|-d] <path>              | Data directory (must be writable).\n"
	 "                                    | Default: %s\n"
	 "[--install-dir|-t] <path>           | Set the installation directory to <dir>.\n"
	 "                                    | Should be set when installing ntopng \n"
	 "                                    | under custom directories\n"
	 "[--daemon|-e]                       | Daemonize ntopng\n"
#endif
	 "[--httpdocs-dir|-1] <path>          | HTTP documents root directory.\n"
	 "                                    | Default: %s\n"
	 "[--scripts-dir|-2] <path>           | Scripts directory.\n"
	 "                                    | Default: %s\n"
	 "[--callbacks-dir|-3] <path>         | Callbacks directory.\n"
	 "                                    | Default: %s\n"
	 "[--pcap-dir|-5] <path>              | Storage directory used for continuous traffic\n"
	 "                                    | recording in PCAP format.\n"
	 "                                    | Default: %s\n"
	 "[--no-promisc|-u]                   | Don't set the interface in promisc mode.\n"
	 "[--http-port|-w] <[addr:]port>      | HTTP. Set to 0 to disable http server.\n"
	 "                                    | Addr can be an IPv4 (192.168.1.1)\n"
	 "                                    | or IPv6 ([3ffe:2a00:100:7031::1]) addr.\n"
	 "                                    | Surround IPv6 addr with square brackets.\n"
	 "                                    | Prepend a ':' without addr before the\n"
	 "                                    | listening port on the loopback address.\n"
	 "                                    | Default port: %u\n"
	 "                                    | Examples:\n"
	 "                                    | -w :3000\n"
	 "                                    | -w 192.168.1.1:3001\n"
	 "                                    | -w [3ffe:2a00:100:7031::1]:3002\n"
	 "[--https-port|-W] <[:]https port>   | HTTPS. See also -w above. Default: %u\n"
	 "[--local-networks|-m] <local nets>  | Local networks list.\n"
	 "                                    | <local nets> is a comma-separated list of networks\n"
	 "                                    | in CIDR format. An optional '=<alias>' is supported\n"
	 "                                    | to specify an alias.\n"
	 "                                    | Examples:\n"
	 "                                    | -m \"192.168.1.0/24,172.16.0.0/16\"\n"
	 "                                    | -m \"192.168.1.0/24=LAN_1,192.168.2.0/24=LAN_2,10.0.0.0/8\"\n"
	 "[--ndpi-protocols|-p] <file>.protos | Specify a nDPI protocol file\n"
	 "                                    | (eg. protos.txt)\n"
	 "[--redis|-r] <fmt>                  | Redis connection. <fmt> is specified as\n"
	 "                                    | [h[:port[:pwd]]][@db-id] where db-id\n"
	 "                                    | identifies the database Id (default 0).\n"
	 "                                    | h is the host running Redis (default\n"
	 "                                    | localhost), optionally followed by a\n"
	 "                                    |  ':'-separated port (default 6379).\n"
	 "                                    | A password can be specified after\n"
	 "                                    | the port when Redis auth is required.\n"
	 "                                    | By default password auth is disabled.\n"
#ifdef __linux__
	 "                                    | On unix <fmt> can also be the redis socket file path.\n"
	 "                                    | Port is ignored for socket-based connections.\n"
#endif
	 "                                    | Examples:\n"
	 "                                    | -r @2\n"
	 "                                    | -r 129.168.1.3\n"
	 "                                    | -r 129.168.1.3:6379@3\n"
	 "                                    | -r 129.168.1.3:6379:nt0pngPwD@0\n"
#ifdef __linux__
	 "                                    | -r /var/run/redis/redis.sock\n"
	 "                                    | -r /var/run/redis/redis.sock@2\n"
	 "[--core-affinity|-g] <ids>          | Bind the capture/processing threads to\n"
	 "                                    | specific CPU cores (specified as a comma-\n"
	 "                                    | separated list of core id)\n"
	 "[--other-core-affinity|-y] <ids>    | Bind service threads to specific CPU cores\n"
	 "                                    | (specified as a comma-separated list of core id)\n"
#endif
	 "[--user|-U] <sys user>              | Run ntopng with the specified user\n"
	 "                                    | instead of %s\n"
	 "[--dont-change-user|-s]             | Do not change user (debug only)\n"
	 "[--shutdown-when-done]              | Terminate after reading the pcap (debug only)\n"
#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,1,0)
	 "[--zmq-encryption]                  | Enable ZMQ encryption\n"
	 "[--zmq-encryption-key-priv <key>]   | ZMQ (collection) encryption secret key (debug only) \n"
	 "[--zmq-encryption-key <key>]        | ZMQ (export) encryption public key (-I only) \n"
#endif
	 "[--zmq-publish-events <URL>]        | Endpoint for publishing events (e.g. IPS)\n"
	 "[--disable-autologout|-q]           | Disable web logout for inactivity\n"
	 "[--disable-login|-l] <mode>         | Disable user login authentication:\n"
	 "                                    | 0 - Disable login only for localhost\n"
	 "                                    | 1 - Disable login for all hosts\n"
	 "[--max-num-flows|-X] <num>          | Max number of active flows\n"
	 "                                    | (default: %u)\n"
	 "[--max-num-hosts|-x] <num>          | Max number of active hosts\n"
	 "                                    | (default: %u)\n"
	 "[--users-file|-u] <path>            | Users configuration file path\n"
	 "                                    | Default: %s\n"
	 "[--original-speed]                  | Reproduce (-i) the pcap file at original speed\n"
#ifndef WIN32
	 "[--pid|-G] <path>                   | Pid file path\n"
#endif

	 "[--packet-filter|-B] <filter>       | Ingress packet filter (BPF filter)\n"
#ifndef HAVE_NEDGE
	 "[--dump-flows|-F] <mode>            | Dump expired flows. Mode:\n"
#ifdef HAVE_NINDEX
	 "                                    | nindex        Dump in nIndex (Enterprise only)\n"
	 "                                    |   Format:\n"
#ifdef NTOPNG_PRO
	 "                                    |   nindex[;direct]\n"
	 "                                    |   Note: the direct option delivers higher performance\n"
	 "                                    |   with less detailed flow information (it dumps raw flows)\n"
	 "                                    |   when collecting from ZMQ.\n"
#else
	 "                                    |   nindex\n"
#endif
	 "                                    |\n"
#endif
	 "                                    | es            Dump in ElasticSearch database\n"
	 "                                    |   Format:\n"
	 "                                    |   es;<mapping type>;<idx name>;<es URL>;<http auth>\n"
	 "                                    |   Example:\n"
	 "                                    |   es;ntopng;ntopng-%%Y.%%m.%%d;http://localhost:9200/_bulk;\n"
	 "                                    |   Notes:\n"
	 "                                    |   The <idx name> accepts the strftime() format.\n"
	 "                                    |   <mapping type>s have been removed starting at\n"
	 "                                    |   ElasticSearch version 6. <mapping type> values whill therefore be\n"
	 "                                    |   ignored when using versions greater than or equal to 6.\n"
	 "                                    |\n"
#ifndef WIN32
	 "                                    | syslog        Dump in syslog\n"
	 "                                    |   Format:\n"
	 "                                    |   syslog[;<facility-text>]\n"
	 "                                    |   Example:\n"
	 "                                    |   syslog\n"
	 "                                    |   syslog;local3\n"
	 "                                    |   Notes:\n"
	 "                                    |   <facility-text> is case-insensitive.\n"
	 "                                    |\n"
#endif
#ifdef HAVE_MYSQL
	 "                                    | mysql         Dump in MySQL database\n"
	 "                                    |   Format:\n"
	 "                                    |   mysql;<host[@port]|socket>;<dbname>;<table name>;<user>;<pw>\n"
	 "                                    |   mysql;localhost;ntopng;flows;root;\n"
	 "                                    |\n"
	 "                                    | mysql-nprobe  Read from an nProbe-generated MySQL database\n"
	 "                                    |   Format:\n"
	 "                                    |   mysql-nprobe;<host|socket>;<dbname>;<prefix>;<user>;<pw>\n"
	 "                                    |   mysql-nprobe;localhost;ntopng;nf;root;\n"
	 "                                    |   Notes:\n"
	 "                                    |    The <prefix> must be the same as used in nProbe.\n"
	 "                                    |    Only one ntopng -i <interface> is allowed.\n"
	 "                                    |    Flows are only read. Dump is assumed to be done by nProbe.\n"
	 "                                    |   Example:\n"
	 "                                    |     ./nprobe ... --mysql=\"localhost:ntopng:nf:root:root\"\n"
	 "                                    |     ./ntopng ... --dump-flows=\"mysql-nprobe;localhost;ntopng;nf;root;root\"\n"
#endif
#endif
	 "[--export-flows|-I] <endpoint>      | Export flows with the specified endpoint\n"
	 "                                    | See https://wp.me/p1LxdS-O5 for a -I use case.\n"
	 "[--hw-timestamp-mode] <mode>        | Enable hw timestamping/stripping.\n"
	 "                                    | Supported TS modes are:\n"
	 "                                    | apcon - Timestamped pkts by apcon.com\n"
	 "                                    |         hardware devices\n"
	 "                                    | ixia  - Timestamped pkts by ixiacom.com\n"
	 "                                    |         hardware devices\n"
	 "                                    | vss   - Timestamped pkts by vssmonitoring.com\n"
	 "                                    |         hardware devices\n"
	 "[--capture-direction] <dir>         | Specify packet capture direction\n"
	 "                                    | 0=RX+TX (default), 1=RX only, 2=TX only\n"
#ifdef HAVE_PF_RING
         "[--cluster-id] <cluster id>         | Specify the PF_RING cluster ID on which incoming packets will be bound.\n"
#endif
	 /* "--online-check                      | Check the license using the online service\n" */
	 "[--online-license-check]            | Check the license online\n" /* set as deprecated as soon as --online-check is supported */
	 "[--http-prefix|-Z <prefix>]         | HTTP prefix to be prepended to URLs.\n"
	 "                                    | Useful when using ntopng behind a proxy.\n"
	 "[--instance-name|-N <name>]         | Assign a name to this ntopng instance.\n"
#ifdef NTOPNG_PRO
	 "[--community]                       | Start ntopng in community edition.\n"
	 "[--check-license]                   | Check if the license is valid.\n"
	 "[--check-maintenance]               | Check until maintenance is included\n"
	 "                                    | in the license.\n"
#ifdef __linux__
         "[--vm]                              | Check the license on VMs (migration resistant).\n"
         "                                    | This flag should be used in combination with the other options (e.g. -V).\n"
         "                                    | Note: this changes the System ID (license should be migrated if any)\n"
#endif
#endif
	 "[--version|-V]                      | Print version and license information, then quit\n"
#ifdef NTOPNG_PRO
	 "[--version-json]                    | Print version and license information in JSON format, then quit\n"
#endif
	 "[--verbose|-v] <level>              | Verbose tracing [0 (min).. 6 (debug)]\n"
	 "[--print-ndpi-protocols]            | Print the nDPI protocols list\n"
#ifndef HAVE_NEDGE
	 "[--ignore-macs]                     | Ignore MAC addresses from traffic\n"
#endif
	 "[--ignore-vlans]                    | Ignore VLAN tags from traffic\n"
	 "[--pcap-file-purge-flows]           | Enable flow purge with pcap files (debug only)\n"
	 "[--simulate-vlans]                  | Simulate VLAN traffic (debug only)\n"
	 "[--simulate-ips] <num>              | Simulate IPs by choosing clients and servers among <num> random addresses\n"
	 "[--help|-h]                         | Help\n",
#ifdef HAVE_NEDGE
	 "edge "
#else
	 ""
#endif
	 , PACKAGE_MACHINE, PACKAGE_VERSION,
#ifndef WIN32
	 ntop->get_working_dir(),
#endif
	 CONST_DEFAULT_DOCS_DIR, CONST_DEFAULT_SCRIPTS_DIR,
         CONST_DEFAULT_CALLBACKS_DIR,
	 CONST_DEFAULT_DATA_DIR,
	 CONST_DEFAULT_NTOP_PORT, CONST_DEFAULT_NTOP_PORT+1,
         CONST_DEFAULT_NTOP_USER,
	 MAX_NUM_INTERFACE_HOSTS, MAX_NUM_INTERFACE_HOSTS,
	 CONST_DEFAULT_USERS_FILE);

  printf("\n");

  /* Just create an instance of the system interface to print out the available interfaces */
  NetworkInterface n(SYSTEM_INTERFACE_NAME);
  n.printAvailableInterfaces(true, 0, NULL, 0);

  exit(0);
}

/* ******************************************* */

void Prefs::setTraceLevelFromRedis(){
  char *lvlStr;

  if((lvlStr = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL)
    ;

  if(!hasCmdlTraceLevel()
     && ntop->getRedis()->get((char *)CONST_RUNTIME_PREFS_LOGGING_LEVEL,
			      lvlStr, CONST_MAX_LEN_REDIS_VALUE) == 0){
    if(!strcmp(lvlStr, "trace")){
      ntop->getTrace()->set_trace_level(TRACE_LEVEL_TRACE);
    }
    else if(!strcmp(lvlStr, "debug")){
      ntop->getTrace()->set_trace_level(TRACE_LEVEL_DEBUG);
    }
    else if(!strcmp(lvlStr, "info")){
      ntop->getTrace()->set_trace_level(TRACE_LEVEL_INFO);
    }
    else if(!strcmp(lvlStr, "normal")){
      ntop->getTrace()->set_trace_level(TRACE_LEVEL_NORMAL);
    }
    else if(!strcmp(lvlStr, "warning")){
      ntop->getTrace()->set_trace_level(TRACE_LEVEL_WARNING);
    }
    else if(!strcmp(lvlStr, "error")){
      ntop->getTrace()->set_trace_level(TRACE_LEVEL_ERROR);
    }
  }

  free(lvlStr);
}

/* ******************************************* */

char* Prefs::get_if_name(int id) {
  for(int i = 0; i < num_interfaces; i++) {
    if(ifNames[i].id == id)
      return ifNames[i].name;
  }

  return NULL;
};

/* ******************************************* */

char* Prefs::get_if_descr(int id) {
  for(int i = 0; i < num_interfaces; i++) {
    if(ifNames[i].id == id)
      return ifNames[i].description;
  }

  return NULL;
};

/* ******************************************* */

void Prefs::getDefaultStringPrefsValue(const char *pref_key, char **buffer, const char *default_value) {
  char rsp[MAX_PATH];

  if((ntop->getRedis()->get((char*)pref_key, rsp, sizeof(rsp)) == 0) && (rsp[0] != '\0'))
    *buffer = strdup(rsp);
  else
    *buffer = strdup(default_value);
}

/* ******************************************* */

bool Prefs::getDefaultBoolPrefsValue(const char *pref_key, const bool default_value) {
  char rsp[8];

  if(ntop->getRedis()->get((char*)pref_key, rsp, sizeof(rsp)) == 0 && rsp[0] != '\0')
    return((rsp[0] == '1') ? true : false);
  else
    return(default_value);
}

/* ******************************************* */

int32_t Prefs::getDefaultPrefsValue(const char *pref_key, int32_t default_value) {
  char rsp[32];

  if(ntop->getRedis()->get((char*)pref_key, rsp, sizeof(rsp)) == 0)
    return(atoi(rsp));
  else {
    snprintf(rsp, sizeof(rsp), "%i", default_value);
    ntop->getRedis()->set((char*)pref_key, rsp);
    return(default_value);
  }
}

/* ******************************************* */

static TsDriver str2TsDriver(const char *driver) {
  if(!strcmp(driver, "influxdb"))
    return(ts_driver_influxdb);
  else if(!strcmp(driver, "prometheus"))
    return(ts_driver_prometheus);
  else
    return(ts_driver_rrd);
}

/* ******************************************* */

void Prefs::reloadPrefsFromRedis() {
  char *aux = NULL;
  // sets to the default value in redis if no key is found
#ifdef PREFS_RELOAD_DEBUG
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "A preference has changed, reloading...");
#endif

  enable_auto_logout_at_runtime = getDefaultPrefsValue(CONST_RUNTIME_IS_AUTOLOGOUT_ENABLED, CONST_DEFAULT_IS_AUTOLOGOUT_ENABLED);

  // alert preferences
  enable_access_log     = getDefaultBoolPrefsValue(CONST_PREFS_ENABLE_ACCESS_LOG, false);
  enable_sql_log        = getDefaultBoolPrefsValue(CONST_PREFS_ENABLE_SQL_LOG, false);

  // auth session preferences
  auth_session_duration              = getDefaultPrefsValue(CONST_AUTH_SESSION_DURATION_PREFS, HTTP_SESSION_DURATION),
    auth_session_midnight_expiration = getDefaultBoolPrefsValue(CONST_AUTH_SESSION_MIDNIGHT_EXP_PREFS, HTTP_SESSION_MIDNIGHT_EXPIRATION);

  /* Runtime Preferences */
  housekeeping_frequency      = getDefaultPrefsValue(CONST_RUNTIME_PREFS_HOUSEKEEPING_FREQUENCY, HOUSEKEEPING_FREQUENCY),
    local_host_cache_duration = getDefaultPrefsValue(CONST_LOCAL_HOST_CACHE_DURATION_PREFS, LOCAL_HOSTS_CACHE_DURATION),
    local_host_max_idle       = getDefaultPrefsValue(CONST_LOCAL_HOST_IDLE_PREFS, MAX_LOCAL_HOST_IDLE),
    non_local_host_max_idle   = getDefaultPrefsValue(CONST_REMOTE_HOST_IDLE_PREFS, MAX_REMOTE_HOST_IDLE),
    pkt_ifaces_flow_max_idle  = getDefaultPrefsValue(CONST_FLOW_MAX_IDLE_PREFS, MAX_FLOW_IDLE),
    active_local_hosts_cache_interval = getDefaultPrefsValue(CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL, CONST_DEFAULT_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL),

    log_to_file         = getDefaultBoolPrefsValue(CONST_RUNTIME_PREFS_LOG_TO_FILE, false);
    intf_rrd_raw_days   = getDefaultPrefsValue(CONST_INTF_RRD_RAW_DAYS, INTF_RRD_RAW_DAYS),
    intf_rrd_1min_days  = getDefaultPrefsValue(CONST_INTF_RRD_1MIN_DAYS, INTF_RRD_1MIN_DAYS),
    intf_rrd_1h_days    = getDefaultPrefsValue(CONST_INTF_RRD_1H_DAYS, INTF_RRD_1H_DAYS),
    intf_rrd_1d_days    = getDefaultPrefsValue(CONST_INTF_RRD_1D_DAYS, INTF_RRD_1D_DAYS),
    other_rrd_raw_days  = getDefaultPrefsValue(CONST_OTHER_RRD_RAW_DAYS, OTHER_RRD_RAW_DAYS),
    other_rrd_1min_days = getDefaultPrefsValue(CONST_OTHER_RRD_1MIN_DAYS, OTHER_RRD_1MIN_DAYS),
    other_rrd_1h_days   = getDefaultPrefsValue(CONST_OTHER_RRD_1H_DAYS, OTHER_RRD_1H_DAYS),
    other_rrd_1d_days   = getDefaultPrefsValue(CONST_OTHER_RRD_1D_DAYS, OTHER_RRD_1D_DAYS),

    enable_top_talkers              = getDefaultBoolPrefsValue(CONST_TOP_TALKERS_ENABLED,
							       CONST_DEFAULT_TOP_TALKERS_ENABLED),
    enable_idle_local_hosts_cache   = getDefaultBoolPrefsValue(CONST_RUNTIME_IDLE_LOCAL_HOSTS_CACHE_ENABLED,
							       CONST_DEFAULT_IS_IDLE_LOCAL_HOSTS_CACHE_ENABLED),
    enable_active_local_hosts_cache = getDefaultBoolPrefsValue(CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED,
							       CONST_DEFAULT_IS_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED),
    enable_tiny_flows_export        = getDefaultBoolPrefsValue(CONST_IS_TINY_FLOW_EXPORT_ENABLED,
							       CONST_DEFAULT_IS_TINY_FLOW_EXPORT_ENABLED),

    max_entity_alerts = getDefaultPrefsValue(CONST_MAX_ENTITY_ALERTS, ALERTS_MANAGER_MAX_ENTITY_ALERTS),
    max_num_secs_before_delete_alert = getDefaultPrefsValue(CONST_MAX_NUM_SECS_ALERTS_BEFORE_DEL, ALERTS_MAX_SECS_BEFORE_PURGE), 

    enable_flow_device_port_rrd_creation = getDefaultBoolPrefsValue(CONST_RUNTIME_PREFS_FLOW_DEVICE_PORT_RRD_CREATION, false),
    disable_alerts        = getDefaultBoolPrefsValue(CONST_ALERT_DISABLED_PREFS, false),
    enable_activities_debug = getDefaultBoolPrefsValue(CONST_ACTIVITIES_DEBUG_ENABLED, false),

    enable_arp_matrix_generation = getDefaultBoolPrefsValue(CONST_DEFAULT_ARP_MATRIX_GENERATION, false),

    override_dst_with_post_nat_dst = getDefaultBoolPrefsValue(CONST_DEFAULT_OVERRIDE_DST_WITH_POST_NAT, false),
    override_src_with_post_nat_src = getDefaultBoolPrefsValue(CONST_DEFAULT_OVERRIDE_SRC_WITH_POST_NAT, false),

    max_num_packets_per_tiny_flow = getDefaultPrefsValue(CONST_MAX_NUM_PACKETS_PER_TINY_FLOW,
							 CONST_DEFAULT_MAX_NUM_PACKETS_PER_TINY_FLOW),
    max_num_bytes_per_tiny_flow   = getDefaultPrefsValue(CONST_MAX_NUM_BYTES_PER_TINY_FLOW,
							 CONST_DEFAULT_MAX_NUM_BYTES_PER_TINY_FLOW),
    max_extracted_pcap_bytes = getDefaultPrefsValue(CONST_MAX_EXTR_PCAP_BYTES,
                                                     CONST_DEFAULT_MAX_EXTR_PCAP_BYTES); 

    ewma_alpha_percent = getDefaultPrefsValue(CONST_EWMA_ALPHA_PERCENT, CONST_DEFAULT_EWMA_ALPHA_PERCENT);

    enable_captive_portal = getDefaultBoolPrefsValue(CONST_PREFS_CAPTIVE_PORTAL, false),
    mac_based_captive_portal = getDefaultBoolPrefsValue(CONST_PREFS_MAC_CAPTIVE_PORTAL, true),
    enable_informative_captive_portal = getDefaultBoolPrefsValue(CONST_PREFS_INFORM_CAPTIVE_PORTAL, false),
    enable_vlan_trunk_bridge = getDefaultBoolPrefsValue(CONST_PREFS_VLAN_TRUNK_MODE_ENABLED, false),
    default_l7policy = getDefaultPrefsValue(CONST_PREFS_DEFAULT_L7_POLICY, PASS_ALL_SHAPER_ID),

    max_ui_strlen = getDefaultPrefsValue(CONST_RUNTIME_MAX_UI_STRLEN, CONST_DEFAULT_MAX_UI_STRLEN),
    hostMask      = (HostMask)getDefaultPrefsValue(CONST_RUNTIME_PREFS_HOSTMASK, no_host_mask),
    flow_table_time      = (bool)getDefaultPrefsValue(CONST_FLOW_TABLE_TIME, flow_table_time),
    auto_assigned_pool_id = (u_int16_t) getDefaultPrefsValue(CONST_RUNTIME_PREFS_AUTO_ASSIGNED_POOL_ID, NO_HOST_POOL_ID);

  getDefaultStringPrefsValue(CONST_RUNTIME_PREFS_TS_DRIVER, &aux, (char*)"rrd");
  if(aux) {
    timeseries_driver = str2TsDriver(aux);
    free(aux);
  }

  getDefaultStringPrefsValue(CONST_RUNTIME_PREFS_ENABLE_MAC_NDPI_STATS, &aux, (char*)"none");
  if(aux) {
    enable_mac_ndpi_stats = strncmp(aux, (char*)"none", 4);
    free(aux);
  }

  getDefaultStringPrefsValue(CONST_SAFE_SEARCH_DNS, &aux, DEFAULT_SAFE_SEARCH_DNS);
  if(aux) {
    safe_search_dns_ip = Utils::inet_addr(aux);
    free(aux);
  }

  getDefaultStringPrefsValue(CONST_GLOBAL_DNS, &aux, DEFAULT_GLOBAL_DNS);
  if(aux) {
    global_primary_dns_ip = Utils::inet_addr(aux);
    free(aux);
  }

  getDefaultStringPrefsValue(CONST_SECONDARY_DNS, &aux, DEFAULT_GLOBAL_DNS);
  if(aux) {
    global_secondary_dns_ip = Utils::inet_addr(aux);
    free(aux);
  }

  global_dns_forging_enabled = getDefaultBoolPrefsValue(CONST_PREFS_GLOBAL_DNS_FORGING_ENABLED, false);
  enable_client_x509_auth    = getDefaultBoolPrefsValue(CONST_PREFS_CLIENT_X509_AUTH, false);
  emit_flow_alerts           = getDefaultBoolPrefsValue(CONST_PREFS_EMIT_FLOW_ALERTS, true);
  emit_host_alerts           = getDefaultBoolPrefsValue(CONST_PREFS_EMIT_HOST_ALERTS, true);

  setTraceLevelFromRedis();
  refreshHostsAlertsPrefs();
  refreshDeviceProtocolsPolicyPref();
  refreshDbDumpPrefs();
  refreshBehaviourAnalysis();
  
#ifdef PREFS_RELOAD_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Updated IPs "
			       "[global_primary_dns_ip: %u]"
			       "[global_secondary_dns_ip: %u]"
			       "[safe_search_dns_ip: %u]",
			       global_primary_dns_ip,
			       global_secondary_dns_ip,
			       safe_search_dns_ip
			       );

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Masked hosts"
			       "[no_host_mask: %u]"
			       "[mask_local_hosts: %u]"
			       "[mask_remote_hosts: %u]",
			       hostMask == no_host_mask ? 1 : 0,
			       hostMask == mask_local_hosts ? 1 : 0,
			       hostMask == mask_remote_hosts ? 1 : 0);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[disable_alerts: %u]",
			       disable_alerts ? 1 : 0);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[mac_ndpi_stats: %u]",
			       enable_mac_ndpi_stats ? 1 : 0);
#endif
}

/* ******************************************* */

void Prefs::refreshBehaviourAnalysis() {
  enable_behaviour_analysis          = getDefaultBoolPrefsValue(CONST_PREFS_BEHAVIOUR_ANALYSIS, false);
  enable_asn_behaviour_analysis      = getDefaultBoolPrefsValue(CONST_PREFS_ASN_BEHAVIOR_ANALYSIS, false);
  enable_network_behaviour_analysis  = getDefaultBoolPrefsValue(CONST_PREFS_NETWORK_BEHAVIOR_ANALYSIS, false);
  enable_iface_l7_behaviour_analysis = getDefaultBoolPrefsValue(CONST_PREFS_IFACE_L7_BEHAVIOR_ANALYSIS, false);
  behaviour_analysis_learning_period = getDefaultPrefsValue(CONST_PREFS_BEHAVIOUR_ANALYSIS_LEARNING_PERIOD, CONST_DEFAULT_BEHAVIOUR_ANALYSIS_LEARNING_PERIOD);
  behaviour_analysis_learning_status_during_learning = (ServiceAcceptance)getDefaultPrefsValue(CONST_PREFS_BEHAVIOUR_ANALYSIS_STATUS_DURING_LEARNING, service_allowed);
  behaviour_analysis_learning_status_post_learning = (ServiceAcceptance)getDefaultPrefsValue(CONST_PREFS_BEHAVIOUR_ANALYSIS_STATUS_POST_LEARNING, service_allowed);
  iec60870_learning_period = getDefaultPrefsValue(CONST_PREFS_IEC60870_ANALYSIS_LEARNING_PERIOD, CONST_IEC104_LEARNING_TIME);
}

/* ******************************************* */

void Prefs::loadInstanceNameDefaults() {
  // Do not re-set the interface name if it has already been set via command line
  if(instance_name || !ntop)
    return;
  else {
    char tmp[256];

    if(gethostname(tmp, sizeof(tmp)))
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read hostname [%s]",
				   strerror(errno));
    else
      instance_name = strdup(tmp);
  }
}

/* ******************************************* */

static const struct option long_options[] = {
#ifndef WIN32
  { "data-dir",                          required_argument, NULL, 'd' },
#endif
  { "daemon",                            no_argument,       NULL, 'e' },
  { "core-affinity",                     required_argument, NULL, 'g' },
  { "help",                              no_argument,       NULL, 'h' },
  { "interface",                         required_argument, NULL, 'i' },
  { "traffic-filtering",                 required_argument, NULL, 'k' },
  { "disable-login",                     required_argument, NULL, 'l' },
  { "local-networks",                    required_argument, NULL, 'm' },
#ifndef HAVE_NEDGE
  { "dns-mode",                          required_argument, NULL, 'n' },
#endif
  { "ndpi-protocols",                    required_argument, NULL, 'p' },
  { "disable-autologout",                no_argument,       NULL, 'q' },
  { "redis",                             required_argument, NULL, 'r' },
  { "dont-change-user",                  no_argument,       NULL, 's' },
#ifndef WIN32
  { "install-dir",                       required_argument, NULL, 't' },
#endif
  { "no-promisc",                        no_argument,       NULL, 'u' },
  { "verbose",                           required_argument, NULL, 'v' },
  { "http-port",                         required_argument, NULL, 'w' },
  { "max-num-hosts",                     required_argument, NULL, 'x' },
  { "other-core-affinity",               required_argument, NULL, 'y' },
  { "packet-filter",                     required_argument, NULL, 'B' },
  { "dump-hosts",                        required_argument, NULL, 'D' },
  { "dump-flows",                        required_argument, NULL, 'F' },
#ifndef WIN32
  { "pid",                               required_argument, NULL, 'G' },
#endif
  { "export-flows",                      required_argument, NULL, 'I' },
  { "instance-name",                     required_argument, NULL, 'N' },
  { "capture-direction",                 required_argument, NULL, 'Q' },
  { "sticky-hosts",                      required_argument, NULL, 'S' },
  { "user",                              required_argument, NULL, 'U' },
  { "version",                           no_argument,       NULL, 'V' },
  { "https-port",                        required_argument, NULL, 'W' },
  { "max-num-flows",                     required_argument, NULL, 'X' },
  { "http-prefix",                       required_argument, NULL, 'Z' },
  { "httpdocs-dir",                      required_argument, NULL, '1' },
  { "scripts-dir",                       required_argument, NULL, '2' },
  { "callbacks-dir",                     required_argument, NULL, '3' },
  { "prefs-dir",                         required_argument, NULL, '4' },
  { "pcap-dir",                          required_argument, NULL, '5' },
  { "zmq-publish-events",                required_argument, NULL, 203 },
#ifdef HAVE_PF_RING
  { "cluster-id",                        required_argument, NULL, 204 },
#endif
#ifdef NTOPNG_PRO
  { "version-json",                      no_argument,       NULL, 205 },
#endif
  { "test-script-pre",                   required_argument, NULL, 206 },
  { "pcap-file-purge-flows",             no_argument,       NULL, 207 },
  { "original-speed",                    no_argument,       NULL, 208 },
  { "online-check",                      no_argument,       NULL, 209 },
  { "print-ndpi-protocols",              no_argument,       NULL, 210 },
  { "online-license-check",              no_argument,       NULL, 211 },
  { "hw-timestamp-mode",                 required_argument, NULL, 212 },
  { "shutdown-when-done",                no_argument,       NULL, 213 },
  { "simulate-vlans",                    no_argument,       NULL, 214 },
  { "zmq-encrypt-pwd",                   required_argument, NULL, 215 },
#ifndef HAVE_NEDGE
  { "ignore-macs",                       no_argument,       NULL, 216 },
#endif
  { "ignore-vlans",                      no_argument,       NULL, 217 },
  { "test-script",                       required_argument, NULL, 218 },
  { "zmq-encryption",                    no_argument,       NULL, 219 },
  { "zmq-encryption-key-priv",           required_argument, NULL, 220 },
  { "simulate-ips",                      required_argument, NULL, 221 },
  { "zmq-encryption-key",                required_argument, NULL, 222 },
#ifndef HAVE_NEDGE
  { "appliance",                         no_argument,       NULL, 223 },
#endif
#ifdef NTOPNG_PRO
#ifdef __linux__
  { "vm",                                no_argument,       NULL, 251 },
#endif
  { "check-maintenance",                 no_argument,       NULL, 252 },
  { "check-license",                     no_argument,       NULL, 253 },
  { "community",                         no_argument,       NULL, 254 },
#endif

  /* End of options */
  { NULL,                                no_argument,       NULL,  0 }
};

/* ******************************************* */

/* Those options are hidden and will not be shown in the GUI cli string.
   Typically, such options contains passwords or other sensitive fields. */
static const int hidden_optkeys[] = {
  'F' /* flows export*/,
  'r' /* redis */,
  215 /* zmq encryption password */,
  220 /* zmq encryption secret key */,
  0
};

/* ******************************************* */

void Prefs::parseHTTPPort(char *arg) {
  char tmp[32], *a, *_t;

  snprintf(tmp, sizeof(tmp), "%s", arg);

  a = strtok_r(tmp, ",", &_t);
  if(a)
    http_port = atoi(a);
}

/* ******************************************* */

void Prefs::setCommandLineString(int optkey, const char * optarg){
  char *p, *opt = NULL;
  int len = 6;
  int i;

  if(optarg) {
    for(i = 0; hidden_optkeys[i] != 0; i++) {
      if(optkey == hidden_optkeys[i]) {
	optarg = "[hidden]";
	break;
      }
    }
    len += strlen(optarg);
  }

  for(i=0; long_options[i].name != NULL; i++) {
    if(long_options[i].val == optkey) {
      opt = (char*)long_options[i].name;
      len += strlen(opt) + 2;
      break;
    }
  }

  if((p = (char*)malloc(len)) != NULL) {
    if(opt) {
      if(optarg && strlen(optarg))
	snprintf(p, len-1, "--%s \"%s\" ", opt, optarg);
      else
	snprintf(p, len-1, "--%s ", opt);
    } else {
      if(optarg && strlen(optarg))
	snprintf(p, len-1, "-%c %s ", optkey, optarg);
      else
	snprintf(p, len-1, "-%c ", optkey);
    }

    if(cli == NULL)
      cli = p;
    else {
      int l = strlen(cli);
      char *backup = cli;

      if((cli = (char*)realloc(cli, l+len)) != NULL) {
	strcpy(&cli[l], p);
	free(p);
      } else
	cli = backup;
    }
  }

}

/* ******************************************* */

/* NOTE: avoid Redis connection in this function */
static void printVersionInformation() {
    printf("Version:\t%s [%s%s build]\n", PACKAGE_VERSION,
#ifndef HAVE_NEDGE
#ifdef NTOPNG_PRO
	   "Enterprise/Professional"
#else
	   "Community"
#endif
#else
	   "Edge"
#endif
	   ,
#ifdef NTOPNG_EMBEDDED_EDITION
	   "/Embedded"
#else
	   ""
#endif
	   );
    printf("GIT rev:\t%s\n", NTOPNG_GIT_RELEASE);

#ifdef NTOPNG_PRO
    printf("Pro rev:\t%s\n", NTOPNG_PRO_GIT_RELEASE);
    printf("Built on:\t%s\n", PACKAGE_OS);

    printf("System Id:\t%s\n", ntop->getPro()->get_system_id());
    printf("Platform:\t%s\n", PACKAGE_MACHINE);
#endif
}

/* ******************************************* */

int Prefs::setOption(int optkey, char *optarg) {
  const struct option *opt;
  char *double_dot, buf[128] = { '\0' };

  opt = long_options;
  while(opt->name != NULL) {
    if(optkey == opt->val) {
      if(opt->has_arg == required_argument && (!optarg || optarg[0] == '\0')) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Missing required argument. Skipping option -%c (--%s).", opt->val, opt->name);
	return(-1);
      }

      break;
    }

    opt++;
  }

  setCommandLineString(optkey, optarg);

  switch(optkey) {
  case 'B':
    if((optarg[0] == '\"') && (strlen(optarg) > 2)) {
      packet_filter = strdup(&optarg[1]);
      packet_filter[strlen(packet_filter)-1] = '\0';
    } else
      packet_filter = strdup(optarg);
    break;

  case 'u':
    use_promiscuous_mode = false;
    break;

#ifndef WIN32
  case 'd':
    ntop->setWorkingDir(optarg);
    break;

  case 't':
    install_dir = strndup(optarg, MAX_PATH);
    break;
#endif

  case 'D':
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "-D deprecated.");
    break;

  case 'e':
    daemonize = true;
    break;

  case 'S':
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "-S deprecated, sticky hosts no longer supported. "
				 "Configure remote and local hosts idle timeouts "
				 "from the preferences.");
    break;

  case 'g':
    cpu_affinity = strdup(optarg);
    break;

  case 'm':
    free(local_networks);
    local_networks = strdup(optarg);
    local_networks_set = true;
    break;

#ifndef HAVE_NEDGE
  case 'n':
    dns_mode = atoi(optarg);
    switch(dns_mode) {
    case 0:
      break;
    case 1:
      resolve_all_hosts();
      break;
    case 2:
      disable_dns_resolution();
      break;
    case 3:
      disable_dns_resolution();
      disable_dns_responses_decoding();
      break;
    default:
      usage();
    }
    break;
#endif

  case 'p':
    ndpi_proto_path = strdup(optarg);
    ntop->setCustomnDPIProtos(ndpi_proto_path);
    break;

  case 'q':
    enable_auto_logout = false;
    break;

  case 'Q':
    switch(atoi(optarg)) {
    case 1:  setCaptureDirection(PCAP_D_IN);    break;
    case 2:  setCaptureDirection(PCAP_D_OUT);   break;
    default: setCaptureDirection(PCAP_D_INOUT); break;
    }
    break;

  case 'h':
    //    ntop->registerPrefs(this, true);
    help();
    break;

  case 'i':
    if(!optarg)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "No interface specified, -i ignored");
    else if(strlen(optarg) > MAX_INTERFACE_NAME_LEN - 1)
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Interface name too long (exceeding %d characters): ignored %s",
				   MAX_INTERFACE_NAME_LEN - 1, optarg);
    else if(!addDeferredInterfaceToRegister(optarg))
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many interfaces specified with -i: ignored %s", optarg);
    break;

  case 'w':
    if(strchr(optarg, ':') == NULL) {
      // only the port
      parseHTTPPort(optarg);
    } else if(optarg[0] == ':'){
      // first char == ':' binds to the loopback address
      parseHTTPPort(&optarg[1]);
      bind_http_to_loopback();
    } else {
      // ':' is after the first character, so
      // we need to parse both the ip address and the port
      double_dot = strrchr(optarg, ':');
      u_int len = double_dot - optarg;
      http_binding_address1 = strndup(optarg, len);
      parseHTTPPort(&double_dot[1]);
    }
    break;

  case 'W':
    if(strchr(optarg, ':') == NULL){
      // only the port
      https_port = atoi(optarg);
    } else if(optarg[0] == ':'){
      // first char == ':' binds to the loopback address
      https_port = atoi(&optarg[1]);
      bind_https_to_loopback();
    } else {
      // ':' is after the first character, so
      // we need to parse both the ip address and the port
      double_dot = strrchr(optarg, ':');
      u_int len = double_dot - optarg;
      https_binding_address1 = strndup(optarg, len);
      https_port = atoi(&double_dot[1]);
    }
    break;

  case 'Z':
    if(optarg[0] != '/') {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "-Z argument (%s) must begin with '/' (example /ntopng): skipped", optarg);
    } else {
      int len = strlen(optarg);

      if(len > 0) {
	if(optarg[len-1] == '/') {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "-Z argument (%s) cannot end with '/' (example /ntopng): skipped", optarg);
	} else {
	  free(http_prefix);
	  http_prefix = strdup(optarg);
	}
      }
    }
    break;

  case 'N':
    instance_name = strndup(optarg, 256);
    break;

  case 'r':
    {
      char *r;

      /*
	Supported formats for --redis

	host:port
	host@redis_instance
	host:port@redis_instance
       */
      snprintf(buf, sizeof(buf), "%s", optarg);
      r = strrchr(buf, '@');
      if(r) {
	redis_db_id = atoi((const char*)&r[1]);
	(*r) = '\0';
      }

      if(strchr(buf, ':')) {
	char *w, *c;

	c = strtok_r(buf, ":", &w);

	if(redis_host) free(redis_host);
	redis_host = strdup(c);

	c = strtok_r(NULL, ":", &w);
	if(c) redis_port = atoi(c);

	c = strtok_r(NULL, ":", &w);
	if(c) redis_password = strdup(c);
      } else if(strlen(buf) > 0) {
	/* only the host */
	if(redis_host) free(redis_host);
	redis_host = strdup(buf);
      }

      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "ntopng will use redis %s@%u",
				   redis_host, redis_db_id);
      if(redis_password)
	ntop->getTrace()->traceEvent(TRACE_NORMAL,
				     "redis connection is password-protected");
    }
    break;

  case 's':
    change_user = false;
    break;

  case '1':
    free(docs_dir);
    docs_dir = strdup(optarg);
    break;

  case '2':
    free(scripts_dir);
    scripts_dir = strdup(optarg);
    break;

  case '3':
    free(callbacks_dir);
    callbacks_dir = strdup(optarg);
    break;

  case '5':
    if(pcap_dir) free(pcap_dir);
    pcap_dir = strdup(optarg);
    break;

  case 'l':
    switch(atoi(optarg)) {
    case 0:
      disable_localhost_login = true;
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Localhost HTTP user login disabled");
      break;
    case 1:
      enable_users_login = false;
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "All HTTP user login disabled");
      break;
    default:
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Invalid '%s' value specified for -l: ignored",
				   optarg);
    }
    break;

  case 'x':
    max_num_hosts = max_val(atoi(optarg), 1024);
    break;

  case 'y':
    other_cpu_affinity = strdup(optarg);
#ifdef HAVE_LIBCAP
    Utils::setAffinityMask(optarg, &other_cpu_affinity_mask);
#endif
    break;

  case 'v':
    {
      if(!optarg)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "No value specified for verbosity: ignored");
      else {
	has_cmdl_trace_lvl = true;
	errno = 0;
	int8_t lvl = (int8_t)strtol(optarg, NULL, 10);
	if(errno) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR,
				       "Invalid '%s' value specified for -v: ignored",
				       optarg);
	} else {
	  if(lvl < 0) lvl = 0;
	  ntop->getTrace()->set_trace_level((u_int8_t)lvl);
	}
      }
    }
    break;

  case 'F':
#ifndef HAVE_NEDGE
    if(!optarg)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "No connection specified, -F ignored");
    else
#if defined(NTOPNG_PRO) && defined(HAVE_NINDEX) && !defined(HAVE_NEDGE) /* NOTE: currently disable on nEdge */
    if(strncmp(optarg, "nindex", 2) == 0) {
      char *nindex_opt = strchr(optarg, ';');
      if(nindex_opt && strlen(nindex_opt) > 0) {
#ifdef NTOPNG_PRO
        if(strncmp(&nindex_opt[1], "direct", 6) == 0)
          toggle_dump_flows_direct(true);
        else
#endif
        if(strncmp(&nindex_opt[1], "dump", 4) == 0)
          dump_json_flows_on_disk = dump_ext_json = true;
        else if(strncmp(&nindex_opt[1], "load", 4) == 0)
          load_json_flows_from_disk_to_nindex = true;
        else if(strncmp(&nindex_opt[1], "debug", 5) == 0)
          dump_ext_json = true;
      }
      dump_flows_on_nindex = true;      
    } else
#endif
    if((strncmp(optarg, "es", 2) == 0) && (strlen(optarg) > 3)) {
      char *elastic_index_type = NULL, *elastic_index_name = NULL, *tmp = NULL,
	*elastic_url = NULL, *elastic_user = NULL, *elastic_pwd = NULL;
      /* es;<index type>;<index name>;<es URL>;<es pwd> */

      if((elastic_index_type = strtok_r(&optarg[3], ";", &tmp)) != NULL) {
	if((elastic_index_name = strtok_r(NULL, ";", &tmp)) != NULL) {
	  if((elastic_url = strtok_r(NULL, ";", &tmp)) != NULL) {
	    if((elastic_user = strtok_r(NULL, ";", &tmp)) == NULL)
	      elastic_pwd = (char*)"";
	    else {
	      char *double_col = strchr(elastic_user, ':');

	      if(double_col)
		elastic_pwd = &double_col[1], double_col[0] = '\0';
	      else
		elastic_pwd = (char*)"";
	    }
	  }
	}
      }

      if(elastic_index_type
	 && elastic_index_name
	 && elastic_url) {
	free(es_type), free(es_index), free(es_url), free(es_user), free(es_pwd), free(es_host);

	es_type  = strdup(elastic_index_type);
	es_index = strdup(elastic_index_name);
	es_url   = strdup(elastic_url);
	es_user  = strdup(elastic_user ? elastic_user : "");
	es_pwd   = strdup(elastic_pwd ? elastic_pwd : "");

	es_host = strdup(es_url);
	if(!strncmp(es_host, "http://", 7))  // url starts either with http or https
	  Utils::tokenizer(es_host + 7, '/', NULL);
        else if(!strncmp(es_host, "https://", 8))
	  Utils::tokenizer(es_host + 8, '/', NULL);
	else
	  Utils::tokenizer(es_host, '/', NULL);

	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Using ElasticSearch for data dump [%s][%s][%s][%s]",
				     es_type, es_index, es_url, es_host);
	dump_flows_on_es = true;
      } else {
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Discarding -F: invalid format for es");
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Format: -F es;<index type>;<index name>;<es URL>;<user>:<pwd>");
      }
    }
    else if(!strncmp(optarg, "mysql", 5)) {
#ifdef HAVE_MYSQL
      char *sep = strchr(optarg, ';');

      if(!sep) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid --mysql format: ignored");
      } else {
	if(!strncmp(optarg, "mysql-nprobe", 12))
	  read_flows_from_mysql = true;
	else
	  dump_flows_on_mysql = true;

	/* mysql;<host[@port]|unix socket>;<dbname>;<table name>;<user>;<pw> */
	optarg = Utils::tokenizer(sep + 1, ';', &mysql_host);
	optarg = Utils::tokenizer(optarg, ';', &mysql_dbname);
	optarg = Utils::tokenizer(optarg, ';', &mysql_tablename);
	optarg = Utils::tokenizer(optarg, ';', &mysql_user);
	mysql_pw = strdup(optarg ? optarg : "");

	if(mysql_host && mysql_user) {
	  if((mysql_dbname == NULL) || (mysql_dbname[0] == '\0'))       mysql_dbname  = strdup("ntopng");
	  if((mysql_tablename == NULL)
	     || (mysql_tablename[0] == '\0')
	     || dump_flows_on_mysql /*forcefully defaults the table name*/) {
	    if(mysql_tablename) free(mysql_tablename);
	    mysql_tablename  = strdup("flows");
	  }
	  if((mysql_pw == NULL) || (mysql_pw[0] == '\0')) mysql_pw  = strdup("");

	  /* Check for non-default SQL port on -F line */
	  char* mysql_port_str;
	  if((mysql_port_str = strchr(mysql_host, '@'))) {
	    *(mysql_port_str++) = '\0';

	    errno = 0;
	    long l = strtol(mysql_port_str, NULL, 10);

	    if(errno || !l)
	      ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid mysql port, using default port %d [%s]",
					   CONST_DEFAULT_MYSQL_PORT,
					   strerror(errno));
	    else
	      mysql_port = (int)l;
	  }
	} else
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid format for -F mysql;....");
      }
#else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "-F mysql is not available (missing MySQL support)");
#endif
    }
#ifndef WIN32
    else if(!strncmp(optarg, "syslog", strlen("syslog"))) {
      char *flows_syslog_facility_text;

      dump_flows_on_syslog = true;
      if(strchr(optarg, ';') != NULL) {
	int syslog_facility_value;
	
        optarg = Utils::tokenizer(strchr(optarg, ';') + 1, ';', &flows_syslog_facility_text);
	syslog_facility_value = Utils::mapSyslogFacilityTextToValue(flows_syslog_facility_text);

        if(syslog_facility_value != -1) {
          flows_syslog_facility = syslog_facility_value;
          ntop->getTrace()->traceEvent(TRACE_DEBUG, "Syslog facility for dumping flows is set to %s (%d)",
                  flows_syslog_facility_text, flows_syslog_facility);
        }
      }
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Dumping flows to syslog in JSON format");
    }
#endif
#endif
    break;

#ifndef WIN32
  case 'G':
    if(pid_path) free(pid_path);
    pid_path = strdup(optarg);
    break;
#endif

  case 'I':
    export_endpoint = strdup(optarg);
    break;

  case 'U':
    set_user(optarg);
    break;

  case 'V':
    print_version = true;
    break;

  case 203:
    zmq_publish_events_url = strdup(optarg);
    break;

#ifdef HAVE_PF_RING
  case 204:
    pfring_cluster_id = atoi(optarg);
    break;
#endif

  case 205:
    print_version_json = true;
    break;

  case 'X':
    max_num_flows = max_val(atoi(optarg), 1024);
    break;

  case 206:
    if(test_pre_script_path) free(test_pre_script_path);
    test_pre_script_path = strdup(optarg);
    break;

  case 207:
    pcap_file_purge_hosts_flows = true;
    break;

  case 208:
    reproduce_at_original_speed = true;
    break;

  case 209:
    service_license_check = true;
    break;

  case 210:
    nDPIhelp();
    break;

  case 211:
    online_license_check = true;
    break;

  case 212:
    if(!strcmp(optarg, "ixia"))
      enable_ixia_timestamps = true;
    else if((!strcmp(optarg, "vss")) || (!strcmp(optarg, "apcon")))
      enable_vss_apcon_timestamps = true;
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Unknown --hw-timestamp-mode mode, it has been ignored\n");
    break;

  case 213:
    shutdown_when_done = true;
    break;

  case 214:
    simulate_vlans = true;
    break;

  case 215:
    zmq_encryption_pwd = strdup(optarg);
    break;

#ifndef HAVE_NEDGE
  case 216:
    ignore_macs = true;
    break;
#endif

  case 217:
    ignore_vlans = true;
    break;

  case 219:
    enable_zmq_encryption = true;
    break;

  case 220:
    enable_zmq_encryption = true;
    zmq_encryption_priv_key = strdup(optarg);
    break;

  case 221:
    num_simulated_ips = atoi(optarg);
    break;

  case 222:
    export_zmq_encryption_key = strdup(optarg);
    break;

#ifndef HAVE_NEDGE
  case 223:
    appliance = true;
    break;
#endif

#ifdef NTOPNG_PRO
#ifdef __linux__
  case 251:
    ntop->getPro()->set_vm_mode();
    break;
#endif

  case 252:
    print_maintenance = true;
    break;

  case 253:
    print_license = true;
    break;

  case 254:
    ntop->getPro()->do_force_community_edition();
    break;
#endif

  case 218:
    if(test_post_script_path) free(test_post_script_path);
    test_post_script_path = strdup(optarg);
    break;

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown option -%c: Ignored.", (char)optkey);
    return(-1);
  }

  return(0);
}

/* ******************************************* */

int Prefs::checkOptions() {

#ifdef NTOPNG_PRO
  if(print_maintenance) {
    /* Disable tracing messages */
    ntop->getTrace()->set_trace_level(0);
    ntop->registerPrefs(this, true);
    if (ntop->getPro()->check_maintenance_duration())
      exit(0);
    else
      exit(1);
  }

  if(print_license) {
    /* Disable tracing messages */
    ntop->getTrace()->set_trace_level(0);
    ntop->registerPrefs(this, true);
    if (ntop->getPro()->check_license_validity())
      exit(0);
    else
      exit(1);
  }
#endif

  if(print_version) {
#ifdef NTOPNG_PRO
    char buf[128];
#endif

    printVersionInformation();

#ifdef NTOPNG_PRO
    ntop->getTrace()->set_trace_level((u_int8_t)0);
    ntop->registerPrefs(this, true);
    ntop->getPro()->init_license();
    
    printf("Edition:\t%s\n",      ntop->getPro()->get_edition());
    printf("License Type:\t%s\n", ntop->getPro()->get_license_type(buf, sizeof(buf)));

    if(ntop->getPro()->demo_ends_at())
      printf("Validity:\t%s\n", ntop->getPro()->get_demo_expiration(buf, sizeof(buf)));
    else
      printf("Maintenance:\t%s\n", ntop->getPro()->get_maintenance_expiration(buf, sizeof(buf)));

    if(ntop->getPro()->get_encoded_license()[0] != '\0') {
      char *enc_license = ntop->getPro()->get_encoded_license();
      int i, len = strlen(enc_license);
      for (i = 0; i < len; i += 69) {
        char buff[70];
        int clen = min((size_t) 69, strlen(&enc_license[i]));

	memcpy(buff, &enc_license[i], clen);
        buff[clen] = '\0';
        if(i == 0) printf("License:\t%s\n", buff);
        else        printf("        \t%s\n", buff);
      }
    }

    if(ntop->getPro()->get_license()[0] != '\0')
      printf("License Hash:\t%s\n",      ntop->getPro()->get_license());
#endif

    exit(0);
  } else if(print_version_json) {
#if defined(NTOPNG_PRO) && (!defined(FORCE_VALID_LICENSE))
    time_t license_until = (time_t)-1, maintenance_until = (time_t)-1;
    char outbuf[256], edition[64];
    
    snprintf(edition, sizeof(edition), "%s%s",
#ifndef HAVE_NEDGE
#ifdef NTOPNG_PRO
	     "Enterprise/Professional"
#else
	     "Community"
#endif
#else
	     "Edge"
#endif
	     ,
#ifdef NTOPNG_EMBEDDED_EDITION
	     "/Embedded"
#else
	     ""
#endif
      );


    ntop->getTrace()->set_trace_level((u_int8_t)0);
    ntop->registerPrefs(this, true);
    ntop->getPro()->init_license();
    
    if((license_until = ntop->getPro()->demo_ends_at()) == 0)
      license_until = (time_t)-1;
    
    maintenance_until = ntop->getPro()->maintenance_ends_at();
    
    printf("%s\n",
	   getLicenseJSON((char*)PACKAGE_VERSION,
			  (char*)PACKAGE_OS,
			  edition,
			  (char*)ntop->getPro()->get_system_id(),
			  license_until,
			  maintenance_until,
			  outbuf, sizeof(outbuf)));

    exit(0);
#endif
  }

  if(install_dir)
    ntop->set_install_dir(install_dir);

  free(data_dir);
  data_dir = strdup(ntop->get_install_dir());

  if(!pcap_dir) 
    pcap_dir = strdup(ntop->get_working_dir());

  docs_dir      = ntop->getValidPath(docs_dir);
  scripts_dir   = ntop->getValidPath(scripts_dir);
  callbacks_dir = ntop->getValidPath(callbacks_dir);

  if(!data_dir)         { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate data dir");      return(-1); }
  if(!docs_dir[0])      { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate docs dir");      return(-1); }
  if(!scripts_dir[0])   { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate scripts dir");   return(-1); }
  if(!callbacks_dir[0]) { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate callbacks dir"); return(-1); }
  if(!pcap_dir[0])      { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate pcap dir");   return(-1); }

  ntop->removeTrailingSlash(docs_dir);
  ntop->removeTrailingSlash(scripts_dir);
  ntop->removeTrailingSlash(callbacks_dir);
  ntop->removeTrailingSlash(pcap_dir);

  if(http_binding_address1 == NULL) http_binding_address1 = strdup(CONST_ANY_ADDRESS);
  if(http_binding_address2 == NULL) http_binding_address2 = strdup(CONST_ANY_ADDRESS);
  if(https_binding_address1 == NULL) https_binding_address1 = strdup(CONST_ANY_ADDRESS);
  if(https_binding_address2 == NULL) https_binding_address2 = strdup(CONST_ANY_ADDRESS);

  if(strcmp(ntop->get_working_dir(), CONST_OLD_DEFAULT_DATA_DIR) == 0 && !is_user_set()) {
    /* Using the old /var/tmp/ntopng with the default user:
     * keep using 'nobody' to preserve backward compaitibility */
    set_user(CONST_OLD_DEFAULT_NTOP_USER);
  }

  return(0);
}

/* ******************************************* */

int Prefs::loadFromCLI(int argc, char *argv[]) {
  u_char c;

  while((c = getopt_long(
#ifdef WIN32
	  (int *(__cdecl *)(void))argc, (char *const **(__cdecl *)(void))argv,
#else
	  argc, argv,
#endif
			 "k:eg:hi:w:r:sg:m:n:p:qd:t:x:y:1:2:3:4:5:l:uv:A:B:CD:E:F:N:G:I:O:Q:S:TU:X:W:VZ:",
			 long_options, NULL)) != '?') {
    if(c == 255) break;
    setOption(c, optarg);
  }

  if((http_port == 0) && (https_port == 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Both HTTP and HTTPS ports are disabled: quitting");
    exit(0);
  }

  return(checkOptions());
}

/* ******************************************* */

int Prefs::loadFromFile(const char *path) {
  char buffer[4096], *line, *key, *value;
  u_int line_len, opt_name_len;
  FILE *fd;
  const struct option *opt;

  config_file_path = strdup(path);

  fd = fopen(config_file_path, "r");

  if(fd == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Config file %s not found", config_file_path);
    return(-1);
  }

  while(true) {
    if(!(line = fgets(buffer, sizeof(buffer), fd)))
      break;

    line = Utils::trim(line);
    value = NULL;

    if((line_len = strlen(line)) < 2 || line[0] == '#')
      continue;

    if(!strncmp(line, "--", 2)) { /* long opt */
      key = &line[2], line_len -= 2;

      opt = long_options;
      while(opt->name != NULL) {
	opt_name_len = strlen(opt->name);

	if(!strncmp(key, opt->name, opt_name_len)
	   && (line_len <= opt_name_len
	       || key[opt_name_len] == '\0'
	       || key[opt_name_len] == ' '
	       || key[opt_name_len] == '=')) {
	  if(line_len > opt_name_len)	  key[opt_name_len] = '\0';
	  if(line_len > opt_name_len + 1) value = Utils::trim(&key[opt_name_len + 1]);
	  
	  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "key: %s value: %s", key, value);
	  setOption(opt->val, value);

	  break;
	}

	opt++;
      }
    } else if(line[0] == '-') { /* short opt */
      key = &line[1], line_len--;
      if(line_len > 1) key[1] = '\0';
      if(line_len > 2) value = Utils::trim(&key[2]);

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "key: %c value: %s", key[0], value);
      setOption(key[0], value);
    } else {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Skipping unrecognized line: %s", line);
      continue;
    }
  }

  fclose(fd);

  return(checkOptions());
}

/* ******************************************* */

void Prefs::add_network_interface(char *name, char *description) {
  if(num_interfaces < MAX_NUM_DEFINED_INTERFACES) {
    int id = Utils::ifname2id(name);

    if(id >= 0) {
      ifNames[num_interfaces].name = strdup(!strncmp(name, "-", 1) ? "stdin" : name);
      ifNames[num_interfaces].description = strdup(description ? description : name);
      ifNames[num_interfaces].id = id;
      num_interfaces++;
      //      ntop->getTrace()->traceEvent(TRACE_ERROR, "Added interface [id: %d][name: %s]", id, name);
    } else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to get a valid id for %s, skipping.", name);
  } else {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many interfaces (%d): discarded %s", num_interfaces, name);
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Hint: reset redis (redis-cli flushall) and then start ntopng again");
  }
}

/* ******************************************* */

void Prefs::add_default_interfaces() {
  NetworkInterface *dummy = new (std::nothrow) NetworkInterface("dummy");
  dummy->addAllAvailableInterfaces();
  delete dummy;
};

/* *************************************** */

void Prefs::bind_http_to_address(const char * const addr1, const char * const addr2) {
  if(http_binding_address1)  free(http_binding_address1);
  http_binding_address1 = strdup(addr1);

  if(http_binding_address2)  free(http_binding_address2);
  http_binding_address2 = strdup(addr2);
}

void Prefs::bind_https_to_address(const char * const addr1, const char * const addr2) {
  if(https_binding_address1) free(https_binding_address1);
  https_binding_address1 = strdup(addr1);

  if(https_binding_address2) free(https_binding_address2);
  https_binding_address2 = strdup(addr2);
}

/* *************************************** */

void Prefs::lua(lua_State* vm) {
  char buf[32];
#ifdef NTOPNG_PRO
  char HTTP_stats_base_dir[MAX_PATH*2];
#endif

  lua_newtable(vm);

  lua_push_bool_table_entry(vm, "is_dns_resolution_enabled_for_all_hosts", resolve_all_host_ip);
  lua_push_bool_table_entry(vm, "is_dns_resolution_enabled", enable_dns_resolution);
  lua_push_bool_table_entry(vm, "is_autologout_enabled", enable_auto_logout);
  lua_push_uint64_table_entry(vm, "http_port", http_port);

  lua_push_uint64_table_entry(vm, "max_num_hosts", max_num_hosts);
  lua_push_uint64_table_entry(vm, "max_num_flows", max_num_flows);

  lua_push_bool_table_entry(vm, "is_dump_flows_enabled", do_dump_flows());
  lua_push_bool_table_entry(vm, "is_dump_flows_runtime_enabled", is_runtime_flows_dump_enabled());
#ifdef NTOPNG_PRO
  lua_push_bool_table_entry(vm, "is_dump_flows_direct_enabled", do_dump_flows_direct());
#endif

  lua_push_bool_table_entry(vm, "is_dump_flows_to_mysql_enabled", dump_flows_on_mysql || read_flows_from_mysql);
  if(mysql_dbname) lua_push_str_table_entry(vm, "mysql_dbname", mysql_dbname);
  lua_push_bool_table_entry(vm, "is_dump_flows_to_es_enabled", dump_flows_on_es);
  lua_push_bool_table_entry(vm, "is_dump_flows_to_syslog_enabled", dump_flows_on_syslog);
#if defined(HAVE_NINDEX) && defined(NTOPNG_PRO)
  lua_push_bool_table_entry(vm, "is_nindex_enabled", do_dump_flows_on_nindex());
#endif

  lua_push_uint64_table_entry(vm, "http.port", get_http_port());

  lua_push_str_table_entry(vm, "instance_name", instance_name ? instance_name : (char*)"");

  /* Command line options */
  lua_push_bool_table_entry(vm, "has_cmdl_trace_lvl", has_cmdl_trace_lvl);

#ifdef NTOPNG_PRO
  memset(HTTP_stats_base_dir, '\0', MAX_PATH);
  strncat(HTTP_stats_base_dir, (const char*)ntop->get_working_dir(), MAX_PATH);
  strncat(HTTP_stats_base_dir, "/httpstats/", MAX_PATH);
  lua_push_str_table_entry(vm, "http_stats_base_dir", HTTP_stats_base_dir);
#endif

  lua_push_uint64_table_entry(vm, "auth_session_duration", get_auth_session_duration());
  lua_push_bool_table_entry(vm, "auth_session_midnight_expiration", get_auth_session_midnight_expiration());

  lua_push_uint64_table_entry(vm, "housekeeping_frequency",    housekeeping_frequency);
  lua_push_uint64_table_entry(vm, "local_host_cache_duration", local_host_cache_duration);
  lua_push_uint64_table_entry(vm, "local_host_max_idle", local_host_max_idle);
  lua_push_uint64_table_entry(vm, "non_local_host_max_idle", non_local_host_max_idle);
  lua_push_uint64_table_entry(vm, "flow_max_idle", pkt_ifaces_flow_max_idle);
  if(enable_active_local_hosts_cache)
    lua_push_uint64_table_entry(vm, "active_local_hosts_cache_interval", active_local_hosts_cache_interval);

  lua_push_uint64_table_entry(vm, "intf_rrd_raw_days", intf_rrd_raw_days);
  lua_push_uint64_table_entry(vm, "intf_rrd_1min_days", intf_rrd_1min_days);
  lua_push_uint64_table_entry(vm, "intf_rrd_1h_days", intf_rrd_1h_days);
  lua_push_uint64_table_entry(vm, "intf_rrd_1d_days", intf_rrd_1d_days);
  lua_push_uint64_table_entry(vm, "other_rrd_raw_days", other_rrd_raw_days);
  lua_push_uint64_table_entry(vm, "other_rrd_1min_days", other_rrd_1min_days);
  lua_push_uint64_table_entry(vm, "other_rrd_1h_days", other_rrd_1h_days);
  lua_push_uint64_table_entry(vm, "other_rrd_1d_days", other_rrd_1d_days);

  lua_push_bool_table_entry(vm, "are_top_talkers_enabled", enable_top_talkers);
  lua_push_bool_table_entry(vm, "flow_table_time", flow_table_time);
  lua_push_bool_table_entry(vm, "is_active_local_hosts_cache_enabled", enable_active_local_hosts_cache);

  lua_push_bool_table_entry(vm,"is_tiny_flows_export_enabled",             enable_tiny_flows_export);
  lua_push_uint64_table_entry(vm, "max_entity_alerts", max_entity_alerts);
  lua_push_uint64_table_entry(vm, "max_num_secs_before_delete_alert", max_num_secs_before_delete_alert);

  lua_push_bool_table_entry(vm, "is_flow_device_port_rrd_creation_enabled", enable_flow_device_port_rrd_creation);

  lua_push_bool_table_entry(vm, "are_alerts_enabled", !disable_alerts);
  lua_push_bool_table_entry(vm, "is_arp_matrix_generation_enabled", is_arp_matrix_generation_enabled());
  lua_push_bool_table_entry(vm, "is_users_login_enabled", enable_users_login);

  lua_push_uint64_table_entry(vm, "max_num_packets_per_tiny_flow", max_num_packets_per_tiny_flow);
  lua_push_uint64_table_entry(vm, "max_num_bytes_per_tiny_flow",   max_num_bytes_per_tiny_flow);

  lua_push_uint64_table_entry(vm, "max_extracted_pcap_bytes", max_extracted_pcap_bytes);

  lua_push_uint64_table_entry(vm, "ewma_alpha_percent", ewma_alpha_percent);

  lua_push_uint64_table_entry(vm, "behaviour_analysis_learning_period", behaviour_analysis_learning_period);
  lua_push_uint64_table_entry(vm, "iec60870_learning_period", iec60870_learning_period);

  lua_push_str_table_entry(vm, "safe_search_dns",
			   Utils::intoaV4(ntohl(safe_search_dns_ip), buf, sizeof(buf)));
  lua_push_str_table_entry(vm, "global_dns",
			   global_primary_dns_ip ? Utils::intoaV4(ntohl(global_primary_dns_ip), buf, sizeof(buf)) : (char*)"");
  lua_push_str_table_entry(vm, "secondary_dns",
			   global_secondary_dns_ip ? Utils::intoaV4(ntohl(global_secondary_dns_ip), buf, sizeof(buf)) : (char*)"");

  lua_push_bool_table_entry(vm, "is_captive_portal_enabled", enable_captive_portal);
  lua_push_bool_table_entry(vm, "is_informative_captive_portal_enabled", enable_informative_captive_portal);

  lua_push_uint64_table_entry(vm, "max_ui_strlen",   max_ui_strlen);

  lua_push_str_table_entry(vm, "config_file", config_file_path ? config_file_path : (char*)"");
  lua_push_str_table_entry(vm, "ndpi_proto_file", ndpi_proto_path ? ndpi_proto_path : (char*)"");

  lua_push_str_table_entry(vm, "cpu_affinity", cpu_affinity ? cpu_affinity : (char*)"");
  lua_push_str_table_entry(vm, "other_cpu_affinity", other_cpu_affinity ? other_cpu_affinity : (char*)"");
  lua_push_str_table_entry(vm, "user", change_user ? user : (char*)"");

  lua_push_str_table_entry(vm, "capture_direction", Utils::captureDirection2Str(captureDirection));
}

/* *************************************** */

void Prefs::refreshHostsAlertsPrefs() {
  char rsp[32];

  if(ntop->getRedis()->hashGet((char*)CONST_RUNTIME_PREFS_HOSTS_ALERTS_CONFIG,
          (char*)CONST_HOST_FLOW_ATTACKER_ALERT_THRESHOLD_KEY, rsp, sizeof(rsp)) == 0)
    attacker_max_num_flows_per_sec = atol(rsp);
  else
    attacker_max_num_flows_per_sec = CONST_MAX_NEW_FLOWS_SECOND;

  if(ntop->getRedis()->hashGet((char*)CONST_RUNTIME_PREFS_HOSTS_ALERTS_CONFIG,
          (char*)CONST_HOST_FLOW_VICTIM_ALERT_THRESHOLD_KEY, rsp, sizeof(rsp)) == 0)
    victim_max_num_flows_per_sec = atol(rsp);
  else
    victim_max_num_flows_per_sec = CONST_MAX_NEW_FLOWS_SECOND;

  if(ntop->getRedis()->hashGet((char*)CONST_RUNTIME_PREFS_HOSTS_ALERTS_CONFIG,
          (char*)CONST_HOST_SYN_ATTACKER_ALERT_THRESHOLD_KEY, rsp, sizeof(rsp)) == 0)
    attacker_max_num_syn_per_sec = atol(rsp);
  else
    attacker_max_num_syn_per_sec = CONST_MAX_NUM_SYN_PER_SECOND;

  if(ntop->getRedis()->hashGet((char*)CONST_RUNTIME_PREFS_HOSTS_ALERTS_CONFIG,
          (char*)CONST_HOST_SYN_VICTIM_ALERT_THRESHOLD_KEY, rsp, sizeof(rsp)) == 0)
    victim_max_num_syn_per_sec = atol(rsp);
  else
    victim_max_num_syn_per_sec = CONST_MAX_NUM_SYN_PER_SECOND;
}

/* *************************************** */

void Prefs::refreshDeviceProtocolsPolicyPref() {
  device_protocol_policies_enabled = getDefaultBoolPrefsValue(CONST_PREFS_ENABLE_DEVICE_PROTOCOL_POLICIES, false);
}

/* *************************************** */

void Prefs::refreshDbDumpPrefs() {
  enable_runtime_flows_dump = getDefaultBoolPrefsValue(CONST_PREFS_ENABLE_RUNTIME_FLOWS_DUMP, true);
}

/* *************************************** */

void Prefs::resetDeferredInterfacesToRegister() {
  int num = 0;
  ntop->getTrace()->traceEvent(TRACE_ERROR, "Reset interfaces");
  for(int i = 0; i < num_deferred_interfaces_to_register; i++) {
    /* Reset network interfaces, excluding event interfaces like syslog/zmq */
    if(deferred_interfaces_to_register[i] != NULL) {
      if (strstr(deferred_interfaces_to_register[i], "syslog://") ||
          strstr(deferred_interfaces_to_register[i], "tcp://"))
        deferred_interfaces_to_register[num++] = deferred_interfaces_to_register[i];
      else    
        free(deferred_interfaces_to_register[i]);
    }
  }
  num_deferred_interfaces_to_register = num;
}

/* *************************************** */

bool Prefs::addDeferredInterfaceToRegister(const char *ifname) {
  if(num_deferred_interfaces_to_register < UNLIMITED_NUM_INTERFACES) {
    deferred_interfaces_to_register[num_deferred_interfaces_to_register] = strdup(ifname);
    num_deferred_interfaces_to_register++;
    return true;
  } else {
    return false;
  }
}

/* *************************************** */

void Prefs::registerNetworkInterfaces() {
  for(int i = 0; i < num_deferred_interfaces_to_register; i++) {
    if(deferred_interfaces_to_register[i] != NULL) {
      add_network_interface(deferred_interfaces_to_register[i], NULL);
      free(deferred_interfaces_to_register[i]);
      deferred_interfaces_to_register[i] = NULL;
    }
  }
}

/* *************************************** */

bool Prefs::is_pro_edition() {
  return
#ifdef NTOPNG_PRO
    ntop->getPro()->has_valid_license()
#else
  false
#endif
    ;
}

/* *************************************** */

bool Prefs::is_enterprise_m_edition() {
  return
#ifdef NTOPNG_PRO
    ntop->getPro()->has_valid_enterprise_m_license() ||
    ntop->getPro()->has_valid_enterprise_l_license()
#else
  false
#endif
    ;
}

/* *************************************** */

bool Prefs::is_enterprise_l_edition() {
  return
#ifdef NTOPNG_PRO
    ntop->getPro()->has_valid_enterprise_l_license()
#else
  false
#endif
    ;
}

/* *************************************** */

bool Prefs::is_nedge_edition() {
  return
#ifdef HAVE_NEDGE
    ntop->getPro()->has_valid_license()
#else
  false
#endif
    ;
}

/* *************************************** */

bool Prefs::is_nedge_enterprise_edition() {
  return
#ifdef HAVE_NEDGE
    ntop->getPro()->has_valid_nedge_enterprise_license()
#else
  false
#endif
    ;
}

/* *************************************** */

void Prefs::set_routing_mode(bool enabled) {
#ifdef HAVE_NEDGE
  routing_mode_enabled = enabled && ntop->getPro()->has_valid_nedge_enterprise_license();
#else
  routing_mode_enabled = false;
#endif
}

/* *************************************** */

time_t Prefs::pro_edition_demo_ends_at() {
  return
#ifdef NTOPNG_PRO
    ntop->getPro()->demo_ends_at()
#else
    0
#endif
    ;
}

/* *************************************** */

/* Perform here post-initialization validations */

void Prefs::validate() {
#if defined(NTOPNG_PRO) && defined(HAVE_NINDEX)
  if(dump_flows_on_nindex) {
    if(!ntop->getPro()->is_nindex_in_use()) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Ignored '-F nindex' as nIndex is not in use");
      dump_flows_on_nindex = false;
    }
  }
#endif
}

/* *************************************** */

const char * const Prefs::getCaptivePortalUrl() {
#ifdef NTOPNG_PRO
  if(isInformativeCaptivePortalEnabled())
    return CAPTIVE_PORTAL_INFO_URL;
  else
#endif
    return CAPTIVE_PORTAL_URL;
}

/* *************************************** */

void Prefs::setIEC104AllowedTypeIDs(const char * const protos) {
  char *p, *buf, *tmp;
  
  if(!protos) return;

  if((strcmp(protos, "-1") == 0))
    iec104_allowed_typeids[0] = (u_int64_t)-1, iec104_allowed_typeids[1] = (u_int64_t)-1; /* All */
  else if((buf = strdup(protos))) {
    iec104_allowed_typeids[0] = (u_int64_t)0, iec104_allowed_typeids[1] = (u_int64_t)0;

    p = strtok_r(buf, ",", &tmp);
    while(p != NULL) {
      int type_id = atoi(p);
      
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "-> %d", type_id);
      
      if(type_id < 64)
	iec104_allowed_typeids[0] |= ((u_int64_t)1 << type_id);
      else if(type_id < 128)
	iec104_allowed_typeids[1] |= ((u_int64_t)1 << (type_id-64));
      
      p = strtok_r(NULL, ",", &tmp);
    }

    free(buf);
  }
}
