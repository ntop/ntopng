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

/* ******************************************* */

Prefs::Prefs(Ntop *_ntop) {
  num_deferred_interfaces_to_register = 0;
  memset(deferred_interfaces_to_register, 0, sizeof(deferred_interfaces_to_register));
  ntop = _ntop, dump_timeline = false, sticky_hosts = location_none;
  local_networks = strdup(CONST_DEFAULT_HOME_NET","CONST_DEFAULT_LOCAL_NETS);
  local_networks_set = false, shutdown_when_done = false;
  enable_users_login = true, disable_localhost_login = false;
  enable_dns_resolution = sniff_dns_responses = true, use_promiscuous_mode = true;
  categorization_enabled = false, httpbl_enabled = false, resolve_all_host_ip = false;
  max_num_hosts = MAX_NUM_INTERFACE_HOSTS, max_num_flows = MAX_NUM_INTERFACE_HOSTS;
  data_dir = strdup(CONST_DEFAULT_DATA_DIR);
  install_dir = NULL;
  docs_dir = strdup(CONST_DEFAULT_DOCS_DIR);
  scripts_dir = strdup(CONST_DEFAULT_SCRIPTS_DIR);
  callbacks_dir = strdup(CONST_DEFAULT_CALLBACKS_DIR);
  config_file_path = ndpi_proto_path = NULL;
  http_port = CONST_DEFAULT_NTOP_PORT;
  http_prefix = strdup("");
  https_port = 0; // CONST_DEFAULT_NTOP_PORT+1;
  change_user = true, daemonize = false;
  user = strdup(CONST_DEFAULT_NTOP_USER);
  http_binding_address = https_binding_address = CONST_ANY_ADDRESS;
  categorization_key = NULL;
  httpbl_key = NULL;
  cpu_affinity = NULL;
  redis_host = strdup("127.0.0.1");
  redis_port = 6379;
  redis_db_id = 0;
  dns_mode = 0;
  logFd = NULL;
  disable_alerts = false;
  pid_path = strdup(DEFAULT_PID_PATH);
  packet_filter = NULL;
  disable_host_persistency = false;
  num_interfaces = 0, num_interface_views = 0, enable_auto_logout = true;
  dump_flows_on_db = false, dump_flows_on_es = false;
  enable_taps = false;
  enable_aggregations = aggregations_disabled;
  memset(ifNames, 0, sizeof(ifNames));
  memset(ifViewNames, 0, sizeof(ifViewNames));
  dump_hosts_to_db = location_none, dump_aggregations_to_db = location_none;
  shorten_aggregation_names = true; // TODO: make it configurable
  json_labels_string_format = true;
#ifdef WIN32
  daemonize = true;
#endif
  export_endpoint = NULL;
  enable_ixia_timestamps = enable_vss_apcon_timestamps = false;
#ifdef NTOPNG_PRO
  save_http_flows_traffic = false;
#endif

  /* Defaults */
  non_local_host_max_idle = MAX_REMOTE_HOST_IDLE /* sec */;
  local_host_max_idle     = MAX_LOCAL_HOST_IDLE /* sec */;
  flow_max_idle           = MAX_FLOW_IDLE /* sec */;

  intf_rrd_raw_days       = INTF_RRD_RAW_DAYS;
  intf_rrd_1min_days      = INTF_RRD_1MIN_DAYS;
  intf_rrd_1h_days        = INTF_RRD_1H_DAYS;
  intf_rrd_1d_days        = INTF_RRD_1D_DAYS;
  other_rrd_raw_days      = OTHER_RRD_RAW_DAYS;
  other_rrd_1min_days     = OTHER_RRD_1MIN_DAYS;
  other_rrd_1h_days       = OTHER_RRD_1H_DAYS;
  other_rrd_1d_days       = OTHER_RRD_1D_DAYS;

  es_type = strdup((char*)"flows"), es_index = strdup((char*)"ntopng-%Y.%m.%d"),
    es_url = strdup((char*)"http://localhost:9200/_bulk"),
    es_user = strdup((char*)""), es_pwd = strdup((char*)"");

#ifdef NTOPNG_PRO
  nagios_host = nagios_port = nagios_config = NULL;
#endif
}

/* ******************************************* */

Prefs::~Prefs() {
  for(int i=0; i<num_deferred_interfaces_to_register; i++)
    if(deferred_interfaces_to_register[i] != NULL)
      free(deferred_interfaces_to_register[i]);

  for(int i=0; i<num_interfaces; i++) {
    if(ifNames[i].name) free(ifNames[i].name);
    if(ifNames[i].description) free(ifNames[i].description);
  }

  if(logFd)            fclose(logFd);
  if(data_dir)         free(data_dir);
  if(install_dir)      free(install_dir);
  if(docs_dir)         free(docs_dir);
  if(scripts_dir)      free(scripts_dir);
  if(callbacks_dir)    free(callbacks_dir);
  if(config_file_path) free(config_file_path);
  if(user)             free(user);
  if(pid_path)         free(pid_path);
  if(packet_filter)    free(packet_filter);
  if(cpu_affinity)     free(cpu_affinity);
  if(es_type)          free(es_type);
  if(es_index)         free(es_index);
  if(es_url)           free(es_url);
  if(es_pwd)           free(es_pwd);
  free(http_prefix);
  free(redis_host);
  free(local_networks);

#ifdef NTOPNG_PRO
  if(nagios_host)   free(nagios_host);
  if(nagios_port)   free(nagios_port);
  if(nagios_config) free(nagios_config);
#endif
}

/* ******************************************* */

/* C-binding needed by Win32 service call */
void usage() {
  NetworkInterface n("dummy");

  printf("ntopng %s v.%s - "NTOP_COPYRIGHT"\n\n"
	 "Usage:\n"
	 "  ntopng <configuration file path>\n"
	 "  or\n"
	 "  ntopng <command line options> \n\n"
	 "Options:\n"
	 "[--dns-mode|-n] <mode>              | DNS address resolution mode\n"
	 "                                    | 0 - Decode DNS responses and resolve\n"
	 "                                    |     local numeric IPs only (default)\n"
	 "                                    | 1 - Decode DNS responses and resolve all\n"
	 "                                    |     numeric IPs\n"
	 "                                    | 2 - Decode DNS responses and don't\n"
	 "                                    |     resolve numeric IPs\n"
	 "                                    | 3 - Don't decode DNS responses and don't\n"
	 "                                    |     resolve numeric IPs\n"
	 "[--interface|-i] <interface|pcap>   | Input interface name (numeric/symbolic),\n"
         "                                    | view or pcap file path\n"
#ifndef WIN32
	 "[--data-dir|-d] <path>              | Data directory (must be writable).\n"
	 "                                    | Default: %s\n"
	 "[--install-dir|-d] <path>           | ntopng installation directory\n"
	 "[--daemon|-e]                       | Daemonize ntopng\n"
#endif
	 "[--httpdocs-dir|-1] <path>          | HTTP documents root directory.\n"
	 "                                    | Default: %s\n"
	 "[--scripts-dir|-2] <path>           | Scripts directory.\n"
	 "                                    | Default: %s\n"
	 "[--callbacks-dir|-3] <path>         | Callbacks directory.\n"
	 "                                    | Default: %s\n"
	 "[--dump-timeline|-C]                | Enable timeline dump.\n"
	 "[--no-promisc|-u]                   | Don't set the interface in promiscuous mode.\n"
	 "[--categorization-key|-c] <key>     | Key used to access host categorization\n"
	 "                                    | services (default: disabled). \n"
	 "                                    | Please read README.categorization for\n"
	 "                                    | more info.\n"
	 "[--httpbl-key|-k] <key>             | Key used to access httpbl\n"
	 "                                    | services (default: disabled). \n"
	 "                                    | Please read README.httpbl for\n"
	 "                                    | more info.\n"
	 "[--http-port|-w] <[:]http port>     | HTTP port. Set to 0 to disable http server.\n"
	 "                                    | Prepend a : before the port to listen to the\n"
	 "                                    | loopback address. Default: %u\n"
	 "[--https-port|-W] <[:]https port>   | HTTPS port. See usage of -w above. Default: %u\n"
	 "[--local-networks|-m] <local nets>  | Local nets list (default: 192.168.1.0/24)\n"
	 "                                    | (e.g. -m \"192.168.0.0/24,172.16.0.0/16\")\n"
	 "[--ndpi-protocols|-p] <file>.protos | Specify a nDPI protocol file\n"
	 "                                    | (eg. protos.txt)\n"
	 "[--disable-host-persistency|-P]     | Disable host persistency in the Redis cache\n"
	 "[--redis|-r] <host[:port][@db-id]>  | Redis host[:port][@database id]\n"
#ifdef linux
	 "[--core-affinity|-g] <cpu core ids> | Bind the capture/processing threads to\n"
	 "                                    | specific CPU cores (specified as a comma-\n"
	 "                                    | separated list)\n"
#endif
	 "[--user|-U] <sys user>              | Run ntopng with the specified user\n"
	 "                                    | instead of %s\n"
	 "[--dont-change-user|-s]             | Do not change user (debug only)\n"
	 "[--shutdown-when-done]              | Terminate when a pcap has been read (debug only)\n"
	 "[--disable-autologout|-q]           | Disable web interface logout for inactivity\n"
	 "[--disable-login|-l] <mode>         | Disable user login authentication:\n"
	 "                                    | 0 - Disable login only for localhost\n"
	 "                                    | 1 - Disable login only for all hosts\n"
	 "[--max-num-flows|-X] <num>          | Max number of active flows\n"
	 "                                    | (default: %u)\n"
	 "[--max-num-hosts|-x] <num>          | Max number of active hosts\n"
	 "                                    | (default: %u)\n"
	 "[--users-file|-u] <path>            | Users configuration file path\n"
	 "                                    | Default: %s\n"
#ifndef WIN32
	 "[--pid|-G] <path>                   | Pid file path\n"
#endif

	 "[--disable-alerts|-H]               | Disable alerts generation\n"
	 "[--packet-filter|-B] <filter>       | Ingress packet filter (BPF filter)\n"
	 "[--enable-aggregations|-A] <mode>   | Setup data aggregation:\n"
	 "                                    | 0 - No aggregations (default)\n"
	 "                                    | 1 - Enable aggregations, no timeline dump\n"
	 "                                    | 2 - Enable aggregations, with timeline\n"
	 "                                    |     dump (see -C)\n"
	 "[--dump-flows|-F] <mode>            | Dump expired flows. Mode:\n"
	 "                                    | db - Dump in SQLite DB\n"
	 "                                    | es - Dump in Redis "CONST_ES_QUEUE_NAME" queue\n"
	 "                                    |      Format:\n"
	 "                                    |      es;<idx type>;<idx name>;<es URL>;<es pwd>\n"
	 "                                    |      Example:\n"
	 "                                    |      es;flows;ntopng-%%Y.%%m.%%d;http://localhost:9200/_bulk;\n"
	 "                                    |      Note: the <idx name> accepts the strftime() format.\n"
	 "[--export-flows|-I] <endpoint>      | Export flows using the specified endpoint.\n"
	 "[--dump-hosts|-D] <mode>            | Dump hosts policy (default: none).\n"
	 "                                    | Values:\n"
	 "                                    | all    - Dump all hosts\n"
	 "                                    | local  - Dump only local hosts\n"
	 "                                    | remote - Dump only remote hosts\n"
	 "[--dump-aggregations|-E] <mode>     | Dump aggregations policy (default: none).\n"
	 "                                    | Values:\n"
	 "                                    | all    - Dump all hosts\n"
	 "                                    | local  - Dump only local hosts\n"
	 "                                    | remote - Dump only remote hosts\n"
	 "[--sticky-hosts|-S] <mode>          | Don't flush hosts (default: none).\n"
	 "                                    | Values:\n"
	 "                                    | all    - Keep all hosts in memory\n"
	 "                                    | local  - Keep only local hosts\n"
	 "                                    | remote - Keep only remote hosts\n"
	 "                                    | none   - Flush hosts when idle\n"
	 "--hw-timestamp-mode <mode>          | Enable hw timestamping/stripping.\n"
	 "                                    | Supported TS modes are:\n"
	 "                                    | apcon - Timestamped packets by apcon.com\n"
	 "                                    |         hardware devices\n"
	 "                                    | ixia  - Timestamped packets by ixiacom.com\n"
	 "                                    |         hardware devices\n"
	 "                                    | vss   - Timestamped packets by vssmonitoring.com\n"
	 "                                    |         hardware devices\n"
	 "[--enable-taps|-T]                  | Enable tap interfaces used to dump traffic\n"
	 "[--http-prefix|-Z] <prefix>         | HTTP prefix to be prepended to URLs. This is\n"
	 "                                    | useful when using ntopng behind a proxy.\n"
#ifdef NTOPNG_PRO
	 "[--community]                       | Start ntopng in community edition (debug only).\n"
#endif
	 "[--verbose|-v]                      | Verbose tracing\n"
	 "[--version|-V]                      | Print version and quit\n"
	 "[--help|-h]                         | Help\n"
	 , PACKAGE_MACHINE, PACKAGE_VERSION,
#ifndef WIN32
	 ntop->get_working_dir(),
#endif
	 CONST_DEFAULT_DOCS_DIR, CONST_DEFAULT_SCRIPTS_DIR,
         CONST_DEFAULT_CALLBACKS_DIR, CONST_DEFAULT_NTOP_PORT, CONST_DEFAULT_NTOP_PORT+1,
         CONST_DEFAULT_NTOP_USER,
	 MAX_NUM_INTERFACE_HOSTS, MAX_NUM_INTERFACE_HOSTS/2,
	 CONST_DEFAULT_USERS_FILE);

  printf("\n");
  n.printAvailableInterfaces(true, 0, NULL, 0);

  _exit(0);
}

/* ******************************************* */

u_int32_t Prefs::getDefaultPrefsValue(const char *pref_key, u_int32_t default_value) {
  char rsp[32];

  if(ntop->getRedis()->get((char*)pref_key, rsp, sizeof(rsp)) == 0)
    return(atoi(rsp));
  else {
    snprintf(rsp, sizeof(rsp), "%u", default_value);
    ntop->getRedis()->set((char*)pref_key, rsp);
    return(default_value);
  }
}

/* ******************************************* */

void Prefs::getDefaultStringPrefsValue(const char *pref_key, char **buffer, const char *default_value) {
  char rsp[32];

  if(ntop->getRedis()->get((char*)pref_key, rsp, sizeof(rsp)) == 0)
    *buffer = strdup(rsp);
  else
    *buffer = strdup(default_value);
}

/* ******************************************* */

void Prefs::loadIdleDefaults() {
  local_host_max_idle = getDefaultPrefsValue(CONST_LOCAL_HOST_IDLE_PREFS, MAX_LOCAL_HOST_IDLE);
  non_local_host_max_idle = getDefaultPrefsValue(CONST_REMOTE_HOST_IDLE_PREFS, MAX_REMOTE_HOST_IDLE);
  flow_max_idle = getDefaultPrefsValue(CONST_FLOW_MAX_IDLE_PREFS, MAX_FLOW_IDLE);

  intf_rrd_raw_days = getDefaultPrefsValue(CONST_INTF_RRD_RAW_DAYS, INTF_RRD_RAW_DAYS);
  intf_rrd_1min_days = getDefaultPrefsValue(CONST_INTF_RRD_1MIN_DAYS, INTF_RRD_1MIN_DAYS);
  intf_rrd_1h_days = getDefaultPrefsValue(CONST_INTF_RRD_1H_DAYS, INTF_RRD_1H_DAYS);
  intf_rrd_1d_days = getDefaultPrefsValue(CONST_INTF_RRD_1D_DAYS, INTF_RRD_1D_DAYS);
  other_rrd_raw_days = getDefaultPrefsValue(CONST_OTHER_RRD_RAW_DAYS, OTHER_RRD_RAW_DAYS);
  other_rrd_1min_days = getDefaultPrefsValue(CONST_OTHER_RRD_1MIN_DAYS, OTHER_RRD_1MIN_DAYS);
  other_rrd_1h_days = getDefaultPrefsValue(CONST_OTHER_RRD_1H_DAYS, OTHER_RRD_1H_DAYS);
  other_rrd_1d_days = getDefaultPrefsValue(CONST_OTHER_RRD_1D_DAYS, OTHER_RRD_1D_DAYS);
#ifdef NTOPNG_PRO
  save_http_flows_traffic = (bool)getDefaultPrefsValue(CONST_SAVE_HTTP_FLOWS_TRAFFIC, false);
#endif
}

/* ******************************************* */

#ifdef NTOPNG_PRO
void Prefs::loadNagiosDefaults() {
  if(nagios_host)   free(nagios_host);
  if(nagios_port)   free(nagios_port);
  if(nagios_config) free(nagios_config);

  getDefaultStringPrefsValue("nagios_host", &nagios_host, "localhost");
  getDefaultStringPrefsValue("nagios_port", &nagios_port, "5667");
  getDefaultStringPrefsValue("nagios_config", &nagios_config, "/etc/nagios/send_nsca.cfg");
}
#endif

/* ******************************************* */

static const struct option long_options[] = {
  { "categorization-key",                required_argument, NULL, 'c' },
#ifndef WIN32
  { "data-dir",                          required_argument, NULL, 'd' },
  { "install-dir",                       required_argument, NULL, 't' },
#endif
  { "daemon",                            no_argument,       NULL, 'e' },
  { "core-affinity",                     required_argument, NULL, 'g' },
  { "help",                              no_argument,       NULL, 'h' },
  { "interface",                         required_argument, NULL, 'i' },
  { "local-networks",                    required_argument, NULL, 'm' },
  { "dns-mode",                          required_argument, NULL, 'n' },
  { "httpbl-key",                        required_argument, NULL, 'k' },
  { "disable-login",                     required_argument, NULL, 'l' },
  { "ndpi-protocols",                    required_argument, NULL, 'p' },
  { "disable-autologout",                no_argument,       NULL, 'q' },
  { "redis",                             required_argument, NULL, 'r' },
  { "dont-change-user",                  no_argument,       NULL, 's' },
  { "no-promisc",                        no_argument,       NULL, 'u' },
  { "verbose",                           no_argument,       NULL, 'v' },
  { "max-num-hosts",                     required_argument, NULL, 'x' },
  { "http-port",                         required_argument, NULL, 'w' },
  { "enable-aggregations",               no_argument,       NULL, 'A' },
  { "packet-filter",                     required_argument, NULL, 'B' },
  { "dump-timeline",                     no_argument,       NULL, 'C' },
  { "dump-hosts",                        required_argument, NULL, 'D' },
  { "dump-aggregations",                 required_argument, NULL, 'E' },
  { "dump-flows",                        required_argument, NULL, 'F' },
#ifndef WIN32
  { "pid",                               required_argument, NULL, 'G' },
#endif
  { "disable-alerts",                    no_argument,       NULL, 'H' },
  { "export-flows",                      required_argument, NULL, 'I' },
  { "disable-host-persistency",          no_argument,       NULL, 'P' },
  { "sticky-hosts",                      required_argument, NULL, 'S' },
  { "enable-taps",                       no_argument,       NULL, 'T' },
  { "user",                              required_argument, NULL, 'U' },
  { "version",                           no_argument,       NULL, 'V' },
  { "max-num-flows",                     required_argument, NULL, 'X' },
  { "https-port",                        required_argument, NULL, 'W' },
  { "http-prefix",                       required_argument, NULL, 'Z' },
  { "httpdocs-dir",                      required_argument, NULL, '1' },
  { "scripts-dir",                       required_argument, NULL, '2' },
  { "callbacks-dir",                     required_argument, NULL, '3' },
  { "hw-timestamp-mode",                 required_argument, NULL, 212 },
  { "shutdown-when-done",                no_argument,       NULL, 213 },
#ifdef NTOPNG_PRO
  { "community-edition",                 no_argument,       NULL, 254 },
#endif

  /* End of options */
  { NULL,                                no_argument,       NULL,  0 }
};

/* ******************************************* */

int Prefs::setOption(int optkey, char *optarg) {
  char *double_dot;

  switch(optkey) {
  case 'A':
    switch(atoi(optarg)) {
    case 0:
      enable_aggregations = aggregations_disabled;
      break;
    case 1:
      enable_aggregations = aggregations_enabled_no_bitmap_dump;
      break;
    case 2:
      enable_aggregations = aggregations_enabled_with_bitmap_dump;
      break;
    default:
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid value for -A: disabling aggregations");
      enable_aggregations = aggregations_disabled;
      break;
    }
    break;

  case 'B':
    if((optarg[0] == '\"') && (strlen(optarg) > 2)) {
      packet_filter = strdup(&optarg[1]);
      packet_filter[strlen(packet_filter)-1] = '\0';
    } else
      packet_filter = strdup(optarg);
    break;

  case 'c':
    categorization_key = optarg;
    break;

  case 'k':
    httpbl_key = optarg;
    break;

  case 'C':
    dump_timeline = true;
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
    if(!strcmp(optarg, "all")) dump_hosts_to_db = location_all;
    else if(!strcmp(optarg, "local")) dump_hosts_to_db = location_local_only;
    else if(!strcmp(optarg, "remote")) dump_hosts_to_db = location_remote_only;
    else if(!strcmp(optarg, "none")) dump_hosts_to_db = location_none;
    else ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown value %s for -D", optarg);
    break;

  case 'e':
    daemonize = true;
    break;

  case 'E':
    if(!strcmp(optarg, "all")) dump_aggregations_to_db = location_all;
    else if(!strcmp(optarg, "local")) dump_aggregations_to_db = location_local_only;
    else if(!strcmp(optarg, "remote")) dump_aggregations_to_db = location_remote_only;
    else if(!strcmp(optarg, "none")) dump_aggregations_to_db = location_none;
    else ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown value %s for -E", optarg);
    break;

  case 'S':
    if(!strcmp(optarg, "all")) sticky_hosts = location_all;
    else if(!strcmp(optarg, "local")) sticky_hosts = location_local_only;
    else if(!strcmp(optarg, "remote")) sticky_hosts = location_remote_only;
    else if(!strcmp(optarg, "none")) sticky_hosts = location_none;
    else ntop->getTrace()->traceEvent(TRACE_ERROR, "Unknown value %s for -S", optarg);
    break;

  case 'g':
    cpu_affinity = strdup(optarg);
    break;

  case 'm':
    free(local_networks);
    local_networks = strdup(optarg);
    local_networks_set = true;
    break;

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
      help();
    }
    break;

  case 'p':
    ndpi_proto_path = strdup(optarg);
    ntop->setCustomnDPIProtos(ndpi_proto_path);
    break;

  case 'q':
    enable_auto_logout = false;
    break;

  case 'P':
    disable_host_persistency = true;
    break;

  case 'T':
    enable_taps = true;
    break;

  case 'h':
    help();
    break;

  case 'i':
    if(num_deferred_interfaces_to_register < MAX_NUM_INTERFACES)
      deferred_interfaces_to_register[num_deferred_interfaces_to_register++] = strdup(optarg);
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many interfaces specified with -i: ignored %s", optarg);
    break;

  case 'w':
    double_dot = strchr(optarg, ':');
    if(double_dot)
      http_port = atoi(&double_dot[1]), bind_http_to_loopback();
    else
      http_port = atoi(optarg);
    break;

  case 'W':
    double_dot = strchr(optarg, ':');
    if(double_dot)
      https_port = atoi(&double_dot[1]), bind_https_to_loopback();
    else
      https_port = atoi(optarg);
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

  case 'r':
    {
      char buf[64], *r;

      /*
	Supported formats for --redis

	host:port
	host@redis_instance
	host:port@redis_instance
       */
      snprintf(buf, sizeof(buf), "%s", optarg);
      r = strtok(buf, "@");
      if(r) {
	char *c;

	if(strchr(r, ':')) {
	  char *w;

	  c = strtok_r(r, ":", &w);

	  if(redis_host) free(redis_host);
	  redis_host = strdup(c);
	
	  c = strtok_r(NULL, ":", &w);
	  if(c) redis_port = atoi(c);
	} else {
	  if(redis_host) free(redis_host);
	  redis_host = strdup(r);
	}

	c = strtok(NULL, "@");
	if(c != NULL)
	  redis_db_id = atoi((const char*)c);
      }

      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "ntopng will use redis %s:%u@%u",
				   redis_host, redis_port, redis_db_id);
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

  case 'v':
    ntop->getTrace()->set_trace_level(MAX_TRACE_LEVEL);
    break;

  case 'F':
    if((strncmp(optarg, "es", 2) == 0)
       && (strlen(optarg) > 3)) {
      char *elastic_index_type = NULL, *elastic_index_name = NULL,
	*elastic_url = NULL, *elastic_user = NULL, *elastic_pwd = NULL;
      /* es;<index type>;<index name>;<es URL>;<es pwd> */

      if((elastic_index_type = strtok(&optarg[3], ";")) != NULL) {
	if((elastic_index_name = strtok(NULL, ";")) != NULL) {
	  if((elastic_url = strtok(NULL, ";")) != NULL) {
	    if((elastic_user = strtok(NULL, ";")) == NULL)
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
	free(es_type), free(es_index), free(es_url), free(es_user), free(es_pwd);

	es_type  = strdup(elastic_index_type);
	es_index = strdup(elastic_index_name);
	es_url   = strdup(elastic_url);
	es_user  = strdup(elastic_user ? elastic_user : "");
	es_pwd   = strdup(elastic_pwd ? elastic_pwd : "");
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Using ElasticSearch for data dump [%s][%s][%s]",
				     es_type, es_index, es_url);
	dump_flows_on_es = true;
      } else {
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Discarding -F: invalid format for es");
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Format: -F es;<index type>;<index name>;<es URL>;<user>:<pwd>");
      }
    } else if(!strcmp(optarg, "db"))
      dump_flows_on_db = true;
    else
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Discarding -F %s: value out of range",
				   optarg);
    break;

#ifndef WIN32
  case 'G':
    pid_path = strdup(optarg);
    break;
#endif

  case 'H':
    disable_alerts = true;
    break;

  case 'I':
    export_endpoint = strdup(optarg);
    break;

  case 'U':
    free(user);
    user = strdup(optarg);
    break;

  case 'V':
    printf("v.%s [%s%s Edition]\n", PACKAGE_VERSION,
#ifdef NTOPNG_PRO
	   "Professional"
#else
	   "Community"
#endif
	   ,
#ifdef NTOPNG_EMBEDDED_EDITION
	   "/Embedded"
#else
	   ""
#endif
	   );
    printf("GIT rev:   %s\n", NTOPNG_GIT_RELEASE);
#ifdef NTOPNG_PRO
    printf("Pro rev:   %s\n", NTOPNG_PRO_SVN_RELEASE);
    printf("System Id: %s\n", ntop->getPro()->get_system_id());
#endif
    _exit(0);
    break;

  case 'X':
    max_num_flows = max_val(atoi(optarg), 1024);
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

#ifdef NTOPNG_PRO
  case 254:
    ntop->getPro()->do_force_community_edition();
    break;
#endif

  default:
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unknown option -%c: Ignored.", (char)optkey);
    return(-1);
  }

  return(0);
}

/* ******************************************* */

int Prefs::checkOptions() {
#ifndef WIN32
  if(daemonize)
#endif
    {
      char path[MAX_PATH];

      ntop_mkdir(data_dir, 0777);
      snprintf(path, sizeof(path), "%s/ntopng.log", ntop->get_working_dir() /* "C:\\Windows\\Temp" */);
      ntop->fixPath(path);
      logFd = fopen(path, "w");
      if(logFd)
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Logging into %s", path);
      else
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to create log %s", path);
    }

  if (strnlen(ntop->get_install_dir(), MAX_PATH) == 0 && install_dir)
    ntop->set_install_dir(install_dir);
  free(data_dir); data_dir = strdup(ntop->get_install_dir());
  docs_dir      = ntop->getValidPath(docs_dir);
  scripts_dir   = ntop->getValidPath(scripts_dir);
  callbacks_dir = ntop->getValidPath(callbacks_dir);

  if(!data_dir)         { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate data dir");      return(-1); }
  if(!docs_dir[0])      { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate docs dir");      return(-1); }
  if(!scripts_dir[0])   { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate scripts dir");   return(-1); }
  if(!callbacks_dir[0]) { ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to locate callbacks dir"); return(-1); }

  ntop->removeTrailingSlash(docs_dir);
  ntop->removeTrailingSlash(scripts_dir);
  ntop->removeTrailingSlash(callbacks_dir);

  return(0);
}

/* ******************************************* */

int Prefs::loadFromCLI(int argc, char *argv[]) {
  u_char c;

  while((c = getopt_long(argc, argv,
			 "c:k:eg:hi:w:r:sg:m:n:p:qd:t:x:1:2:3:l:uvA:B:CD:E:F:G:HI:S:TU:X:W:VZ:",
			 long_options, NULL)) != '?') {
    if(c == 255) break;
    setOption(c, optarg);
  }

  if((http_port == 0) && (https_port == 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Both HTTP and HTTPS ports are disabled: quitting");
    _exit(0);
  }

  return(checkOptions());
}

/* ******************************************* */

int Prefs::loadFromFile(const char *path) {
  char buffer[512], *line, *key, *value;
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

    if(strlen(line) < 1 || line[0] == '#')
      continue;

    key = line;
    key = Utils::trim(key);

    value = strrchr(line, '=');

    /* Fallback to space */
    if(value == NULL) value = strrchr(line, ' ');

    if(value == NULL)
      value = &line[strlen(line)]; /* empty */
    else
      value[0] = 0, value = &value[1];
    value = Utils::trim(value);

    if(strlen(key) > 2) key = &key[2];
    else key = &key[1];

    opt = long_options;
    while (opt->name != NULL) {
      if((strcmp(opt->name, key) == 0)
	 || ((key[1] == '\0') && (opt->val == key[0]))) {
        setOption(opt->val, value);
        break;
      }
      opt++;
    }
  }

  fclose(fd);

  return(checkOptions());
}

/* ******************************************* */

int Prefs::save() {
  FILE *fd;

  if(config_file_path == NULL)
    return(-1);

  fd = fopen(config_file_path, "w");

  if(fd == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open file %s [%s]", config_file_path, strerror(errno));
    return(-1);
  }

  if(dns_mode != 0)       fprintf(fd, "dns-mode=%d\n", dns_mode);

  if(num_interfaces > 0) {
    fprintf(fd, "interface=");

    for(int i=0; i<num_interfaces; i++)
      fprintf(fd, "%s%s", (i > 0) ? "," : "", ifNames[i].name);

    fprintf(fd, "\n");
  }
  if(data_dir)            fprintf(fd, "data-dir=%s\n", data_dir);
  if(install_dir)         fprintf(fd, "install-dir=%s\n", install_dir);
  if(categorization_key)  fprintf(fd, "categorization-key=%s\n", categorization_key);
  if(httpbl_key)          fprintf(fd, "httpbl-key=%s\n", httpbl_key);
  if(local_networks)      fprintf(fd, "local-networks=%s\n", local_networks);
  if(ndpi_proto_path)     fprintf(fd, "ndpi-protocols=%s\n", ndpi_proto_path);
  if(redis_host)          fprintf(fd, "redis=%s:%d\n", redis_host, redis_port);
  if(!change_user)        fprintf(fd, "dont-change-user\n");
  if(!enable_users_login) fprintf(fd, "disable-login\n");
  if(docs_dir)            fprintf(fd, "httpdocs-dir=%s\n", docs_dir);
  if(scripts_dir)         fprintf(fd, "scripts-dir=%s\n", scripts_dir);
  if(callbacks_dir)       fprintf(fd, "callbacks-dir=%s\n", callbacks_dir);
  if(cpu_affinity != NULL) fprintf(fd, "core-affinity=%s\n", cpu_affinity);
  if(http_port != CONST_DEFAULT_NTOP_PORT) fprintf(fd, "http-port=%d\n", http_port);
  if(ntop->getTrace()->get_trace_level() != TRACE_LEVEL_NORMAL) fprintf(fd, "verbose\n");

  fclose(fd);

  return(0);
}

/* ******************************************* */

void Prefs::add_network_interface(char *name, char *description) {
  int id = Utils::ifname2id(name);

  if(id < (MAX_NUM_INTERFACES-1)) {
    ifNames[id].name = strdup(name);
    ifNames[id].description = strdup(description ? description : name);
    num_interfaces++;
  } else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many interfaces: discarded %s", name);
}

/* ******************************************* */

char *Prefs::getInterfaceViewAt(int id) {
  if (id >= MAX_NUM_INTERFACES) return NULL;
  return ifViewNames[id].name;
}

void Prefs::add_network_interface_view(char *name, char *description) {
  int id = Utils::ifname2id(name);

  if(id < (MAX_NUM_INTERFACES-1)) {
    ifViewNames[id].name = strdup(name);
    ifViewNames[id].description = strdup(description ? description : name);
    num_interface_views++;
  } else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many interface views: discarded %s", name);
}

/* ******************************************* */

void Prefs::add_default_interfaces() {
  NetworkInterface *dummy = new NetworkInterface("dummy");
  dummy->addAllAvailableInterfaces();
  delete dummy;
};

/* *************************************** */

void Prefs::lua(lua_State* vm) {
#ifdef NTOPNG_PRO
  char HTTP_stats_base_dir[MAX_PATH*2];
#endif

  lua_newtable(vm);

  lua_push_bool_table_entry(vm, "is_dns_resolution_enabled_for_all_hosts", resolve_all_host_ip);
  lua_push_bool_table_entry(vm, "is_dns_resolution_enabled", enable_dns_resolution);
  lua_push_bool_table_entry(vm, "is_categorization_enabled", categorization_enabled);
  lua_push_bool_table_entry(vm, "is_httpbl_enabled", httpbl_enabled);
  lua_push_int_table_entry(vm, "http_port", http_port);
  lua_push_int_table_entry(vm, "local_host_max_idle", local_host_max_idle);
  lua_push_int_table_entry(vm, "non_local_host_max_idle", non_local_host_max_idle);
  lua_push_int_table_entry(vm, "flow_max_idle", flow_max_idle);
  lua_push_int_table_entry(vm, "max_num_hosts", max_num_hosts);
  lua_push_int_table_entry(vm, "max_num_flows", max_num_flows);
  lua_push_bool_table_entry(vm, "is_dump_flows_enabled", dump_flows_on_db);
  lua_push_int_table_entry(vm, "dump_hosts", dump_hosts_to_db);
  lua_push_int_table_entry(vm, "dump_aggregation", dump_aggregations_to_db);

  /* RRD prefs */
  lua_push_int_table_entry(vm, "intf_rrd_raw_days", intf_rrd_raw_days);
  lua_push_int_table_entry(vm, "intf_rrd_1min_days", intf_rrd_1min_days);
  lua_push_int_table_entry(vm, "intf_rrd_1h_days", intf_rrd_1h_days);
  lua_push_int_table_entry(vm, "intf_rrd_1d_days", intf_rrd_1d_days);
  lua_push_int_table_entry(vm, "other_rrd_raw_days", other_rrd_raw_days);
  lua_push_int_table_entry(vm, "other_rrd_1min_days", other_rrd_1min_days);
  lua_push_int_table_entry(vm, "other_rrd_1h_days", other_rrd_1h_days);
  lua_push_int_table_entry(vm, "other_rrd_1d_days", other_rrd_1d_days);

#ifdef NTOPNG_PRO
  lua_push_str_table_entry(vm, "nagios_host", nagios_host);
  lua_push_str_table_entry(vm, "nagios_port", nagios_port);
  lua_push_str_table_entry(vm, "nagios_config", nagios_config);

  memset(HTTP_stats_base_dir, '\0', MAX_PATH);
  strncat(HTTP_stats_base_dir, (const char*)ntop->get_working_dir(), MAX_PATH);
  strncat(HTTP_stats_base_dir, "/httpstats/", MAX_PATH);
  lua_push_str_table_entry(vm, "http_stats_base_dir", HTTP_stats_base_dir);
#endif
}

/* *************************************** */

bool Prefs::isView(char *name) {
  istringstream ss(name);
  string cmdtok;

  if (std::getline(ss, cmdtok, ':')) {
    if (cmdtok != "view") return false;
    return true;
  }

  return false;
}

/* *************************************** */

void Prefs::registerNetworkInterfaces() {
  for(int i=0; i<num_deferred_interfaces_to_register; i++) {
    if(deferred_interfaces_to_register[i] != NULL) {
      if (isView(deferred_interfaces_to_register[i]))
        add_network_interface_view(deferred_interfaces_to_register[i], NULL);
      else
        add_network_interface(deferred_interfaces_to_register[i], NULL);
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

time_t Prefs::pro_edition_demo_ends_at() {
  return
#ifdef NTOPNG_PRO
    ntop->getPro()->demo_ends_at()
#else
    0
#endif
    ;
}
