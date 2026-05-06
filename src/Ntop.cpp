/*
 *
 * (C) 2013-26 - ntop.org
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

#ifdef WIN32
#include <shlobj.h> /* SHGetFolderPath() */
#else
#include <ifaddrs.h>
#include <sys/file.h>
#endif

/* WebAuthn / Passkey: OpenSSL EC/ECDSA and SHA-256 */
#include <openssl/sha.h>
#include <openssl/ec.h>

#ifdef HAVE_OPENSSL_CORE_NAMES_H
#include <openssl/ecdsa.h>
#include <openssl/evp.h>
#include <openssl/core_names.h>   // OSSL_PKEY_PARAM_GROUP_NAME, etc.
#include <openssl/param_build.h>  // OSSL_PARAM_BLD
#include <openssl/bn.h>
#endif

#include <vector>

Ntop* ntop;

static const char* dirs[] = {
    NULL, /* Populated at runtime */
    NULL, /* Populated at runtime for WIN32 builds */
    CONST_ALT_INSTALL_DIR,
    CONST_ALT2_INSTALL_DIR,
#ifndef WIN32
    CONST_DEFAULT_INSTALL_DIR, /* Last is the <path> specified with ./configure
                                  --prefix <path>, defaulting to /usr/local */
#endif
    NULL};

extern struct keyval string_to_replace[]; /* LuaEngine.cpp */

/* ******************************************* */

Ntop::Ntop(const char* appName) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);

  ntop = this;
  globals = new (std::nothrow) NtopGlobals();
  extract = new (std::nothrow) TimelineExtract();
  num_active_lua_vms = 0;
  offline = false;
  forced_offline = false;
  pa = NULL;
#ifdef WIN32
  myTZname = strdup(_tzname[0] ? _tzname[0] : "CET");
#else
  myTZname = strdup(tzname[0] ? tzname[0] : "CET");
#endif
  custom_ndpi_protos = NULL;
  prefs = NULL, redis = NULL;

#ifdef HAVE_ZMQ
#ifndef HAVE_NEDGE
  export_interface = NULL;
  zmqPublisher = NULL;
#endif
#endif
  trackers_automa = NULL;
  num_cpus = -1;
  num_defined_interfaces = 0;
  iface = NULL;
  start_time = last_modified_static_file_epoch = 0,
  epoch_buf[0] = '\0'; /* It will be initialized by start() */
  last_stats_reset = 0;
  old_iface_to_purge = NULL;
  broadcast_ip_disabled = false;
  flow_id = 0;
  flow_id_initialized = false;

  setZoneInfo();

  /* Checks loader */
  flowChecksReloadInProgress = true; /* Lazy, will be reloaded the first time
                                        this condition is evaluated */
  hostChecksReloadInProgress = true;
  flow_checks_loader = NULL;
  host_checks_loader = NULL;

  /* Flow alerts exclusions */
#ifdef NTOPNG_PRO
  num_flow_exporters = num_flow_interfaces = 0;
  alertExclusionsReloadInProgress = true;
  alert_exclusions = alert_exclusions_shadow = NULL;
#endif

  /* Host Pools reload - Interfaces initialize their pools inside the
   * constructor */
  hostPoolsReloadInProgress = false;

  httpd = NULL, geo = NULL, mac_manufacturers = NULL;
  memset(&cpu_stats, 0, sizeof(cpu_stats));
  cpu_load = 0;
  system_interface = NULL;
  interfacesShuttedDown = false;
#ifdef NTOPNG_PRO
  message_broker = NULL;
#endif /* NTOPNG_PRO */
#ifndef WIN32
  cping = NULL, default_ping = NULL;
  ping_initialized = false;
#endif
  privileges_dropped = false;
  can_send_icmp = Utils::isPingSupported();

  for (int i = 0; i < CONST_MAX_NUM_NETWORKS; i++)
    local_network_names[i] = local_network_aliases[i] = NULL;

  internal_alerts_queue =
      new (std::nothrow) FifoSerializerQueue(INTERNAL_ALERTS_QUEUE_SIZE);

  resolvedHostsBloom = new (std::nothrow) Bloom(NUM_HOSTS_RESOLVED_BITS);

#ifdef WIN32
  if (SHGetFolderPath(NULL, CSIDL_PERSONAL, NULL, SHGFP_TYPE_CURRENT,
                      working_dir) != S_OK) {
    strncpy(working_dir, "C:\\Windows\\Temp\\ntopng",
            sizeof(working_dir));  // Fallback: it should never happen
    working_dir[sizeof(working_dir) - 1] = '\0';
  } else {
    int l = strlen(working_dir);

    snprintf(&working_dir[l], sizeof(working_dir), "%s", "\\ntopng");
  }

  // Get the full path and filename of this program
  if (GetModuleFileName(NULL, startup_dir, sizeof(startup_dir)) == 0) {
    startup_dir[0] = '\0';
  } else {
    for (int i = (int)strlen(startup_dir) - 1; i > 0; i--) {
      if (startup_dir[i] == '\\') {
        startup_dir[i] = '\0';
        break;
      }
    }
  }

  snprintf(install_dir, sizeof(install_dir), "%s", startup_dir);

  dirs[0] = startup_dir;
  dirs[1] = install_dir;
#else
  /* Note: working_dir folder will be created lazily, avoid creating it now */
  if (Utils::dir_exists(
          CONST_OLD_DEFAULT_DATA_DIR)) /* keep using the old dir */
    snprintf(working_dir, sizeof(working_dir), CONST_OLD_DEFAULT_DATA_DIR);
  else
    snprintf(working_dir, sizeof(working_dir), CONST_DEFAULT_DATA_DIR);

  // umask(0);

  if (getcwd(startup_dir, sizeof(startup_dir)) == NULL)
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Occurred while checking the current directory (errno=%d)",
        errno);

  dirs[0] = startup_dir;

  install_dir[0] = '\0';

  for (int i = 0; i < (int)COUNT_OF(dirs); i++) {
    if (dirs[i]) {
      char path[MAX_PATH + 32];
      struct stat statbuf;

      snprintf(path, sizeof(path), "%s/scripts/lua/index.lua", dirs[i]);
      fixPath(path);

      if (stat(path, &statbuf) == 0) {
        snprintf(install_dir, sizeof(install_dir), "%s", dirs[i]);
        break;
      }
    }
  }
#endif

  setScriptsDir();

#ifdef NTOPNG_PRO
  pro = new (std::nothrow) NtopPro();
#else
  pro = NULL;
#endif

  address = NULL;

#ifndef HAVE_NEDGE
  refresh_ips_rules = false;
#endif

  // printf("--> %s [%s]\n", startup_dir, appName);

  initTimezone();
  ntop->getTrace()->traceEvent(TRACE_INFO, "System Timezone offset: %+ld",
                               time_offset);

  initAllowedProtocolPresets();

  udp_socket = Utils::openSocket(AF_INET, SOCK_DGRAM, 0, "Ntop UDP");

#ifndef WIN32
  setservent(1);

  startupLockFile = -1;
#endif

#ifdef HAVE_SNMP_TRAP
  trap_collector = NULL;
#endif

  /* Internal chec to make sure everything is in order */
  if (!FlowRiskAlerts::checkConsistency()) {
    ntop->getTrace()->traceEvent(
        TRACE_ERROR,
        "Fatal error: nDPI risk alerts are out of sync with ntopng");
    exit(0);
  }

#ifdef NTOPNG_PRO
  ifRoles = ifRoles_shadow = NULL;
#endif
}

/* ******************************************* */

#ifndef WIN32

void Ntop::lockNtopInstance() {
  char lockPath[MAX_PATH + 8];
  struct flock lock;
  struct stat st;

  if ((stat(working_dir, &st) != 0) || !S_ISDIR(st.st_mode)) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Working dir does not exist yet");
    return;
  }

  snprintf(lockPath, sizeof(lockPath), "%s/.lock", working_dir);

  lock.l_type = F_WRLCK;    /* read/write (exclusive versus shared) lock */
  lock.l_whence = SEEK_SET; /* base for seek offsets */
  lock.l_start = 0;         /* 1st byte in file */
  lock.l_len = 0;           /* 0 here means 'until EOF' */
  lock.l_pid = getpid();    /* process id */

  if ((startupLockFile = open(lockPath, O_RDWR | O_CREAT, 0666)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to open lock file %s [%s]", lockPath,
                                 strerror(errno));
    exit(EXIT_FAILURE);
  }

  if (fcntl(startupLockFile, F_SETLK, &lock) <
      0) { /** F_SETLK doesn't block, F_SETLKW does **/
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Another ntopng instance is running...");
    exit(EXIT_FAILURE);
  }
}

#endif

/* ******************************************* */

/*
  Setup timezone differences

  We call it all the time as daylight can change
  during the night and thus we need to have it "fresh"
*/

void Ntop::initTimezone() {
#ifdef WIN32
  time_offset = -_timezone;
#else
  time_t t = time(NULL);
  struct tm* l = localtime(&t);

  time_offset = l->tm_gmtoff;
#endif
}

/* ******************************************* */

Ntop::~Ntop() {
  int num_local_networks = local_network_tree.getNumAddresses();

  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);

  for (int i = 0; i < num_local_networks; i++) {
    if (local_network_names[i] != NULL) free(local_network_names[i]);
    if (local_network_aliases[i] != NULL) free(local_network_aliases[i]);
  }

  if (httpd)
    delete httpd; /* Stop the http server before tearing down network interfaces
                   */

  /* The free below must be called before deleting the interface */
  if (flow_checks_loader) delete flow_checks_loader;
  if (host_checks_loader) delete host_checks_loader;

  for (int i = 0; i < num_defined_interfaces; i++) {
    if (iface[i]) {
      delete iface[i];
      iface[i] = NULL;
    }
  }

  if (zoneinfo) free(zoneinfo);

  delete[] iface;

  if (system_interface) delete system_interface;

  if (extract) delete extract;

#ifndef WIN32
  if (cping) delete cping;
  if (default_ping) delete default_ping;

  for (std::map<std::string /* ifname */, Ping*>::iterator it = ping.begin();
       it != ping.end(); ++it)
    delete it->second;
#endif

  Utils::closeSocket(udp_socket);

  if (trackers_automa) ndpi_free_automa(trackers_automa);
  if (custom_ndpi_protos) free(custom_ndpi_protos);
  if (old_iface_to_purge) delete old_iface_to_purge;

  delete address;

  if (pa) delete pa;
  if (geo) delete geo;
  if (mac_manufacturers) delete mac_manufacturers;
#ifndef HAVE_NEDGE
#ifdef HAVE_ZMQ
  if (zmqPublisher) delete zmqPublisher;
#endif
#endif

#ifdef NTOPNG_PRO
  if (pro) delete pro;
  if (alert_exclusions) delete alert_exclusions;
  if (alert_exclusions_shadow) delete alert_exclusions_shadow;
  if (message_broker) {
    delete message_broker;
    message_broker = NULL;
  }
#endif

  if (resolvedHostsBloom) delete resolvedHostsBloom;
  delete internal_alerts_queue;

  if (redis) {
    delete redis;
    redis = NULL;
  }

  if (prefs) {
    delete prefs;
    prefs = NULL;
  }

  if (globals) {
    delete globals;
    globals = NULL;
  }

  if (myTZname) free(myTZname);
#ifdef HAVE_NEDGE
  for (auto it = multicastForwarders.begin(); it != multicastForwarders.end();
       ++it) {
    delete (*it);
  }
#endif

#ifdef HAVE_RADIUS
  if (radiusAcc) delete radiusAcc;
#endif

#ifdef NTOPNG_PRO
  if (oidcAuth) delete oidcAuth;
#endif

#ifdef HAVE_SNMP_TRAP
  if (trap_collector) delete trap_collector;
#endif

  for (u_int i = 0; i < device_max_type; i++) {
    DeviceProtocolBitmask* b = getDeviceAllowedProtocols((DeviceType)i);
    ndpi_bitmask_free(&b->clientAllowed);
    ndpi_bitmask_free(&b->serverAllowed);
  }

#ifdef NTOPNG_PRO
  if(ifRoles_shadow) delete ifRoles_shadow;
  if(ifRoles)        delete ifRoles;
#endif
}

/* ******************************************* */

void Ntop::registerPrefs(Prefs* _prefs, bool quick_registration) {
  char value[32];
  struct stat buf;

  prefs = _prefs;

  if (!quick_registration) {
    if (stat(prefs->get_data_dir(), &buf) ||
        (!(buf.st_mode & S_IFDIR)) /* It's not a directory */
        // || (!(buf.st_mode & S_IWRITE)) /* It's not writable    */
    ) {
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Invalid directory %s specified", prefs->get_data_dir());
      exit(-1);
    }

    if (stat(prefs->get_callbacks_dir(), &buf) ||
        (!(buf.st_mode & S_IFDIR)) /* It's not a directory */
        || (!(buf.st_mode & S_IREAD)) /* It's not readable    */) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Invalid directory %s specified",
                                   prefs->get_callbacks_dir());
      exit(-1);
    }
  }

  if (!quick_registration) {
    /* Initialize redis and populate some default values */
    Utils::initRedis(&redis, prefs->get_redis_host(),
                     prefs->get_redis_password(), prefs->get_redis_port(),
                     prefs->get_redis_db_id(), quick_registration,
                     prefs->get_redis_tls_ca_cert(), prefs->get_redis_tls_cert(),
                     prefs->get_redis_tls_key(), prefs->get_redis_tls_skip_verify());
    if (redis) redis->setDefaults();
  }

  if ((!quick_registration) && (!prefs->limitResourcesUsage())) {
    /* Initialize another redis instance for the trace of events */
    ntop->getTrace()->initRedis(
        prefs->get_redis_host(), prefs->get_redis_password(),
        prefs->get_redis_port(), prefs->get_redis_db_id(),
        prefs->get_redis_tls_ca_cert(), prefs->get_redis_tls_cert(),
        prefs->get_redis_tls_key(), prefs->get_redis_tls_skip_verify());

    if (ntop->getRedis() == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
                                   "Unable to initialize redis. Quitting...");
      exit(-1);
    }
  } else
    ntop->getTrace()->setRedis(getRedis());

#ifdef NTOPNG_PRO
  /*
     This check is required when starting ntopng without --version
     but it's redundant when --version is used
  */
  pro->init_license(quick_registration);

  if (!ntop->getPro()->has_unlimited_enterprise_l_license())
    prefs->toggle_dump_flows_direct(false);
#endif

  if (quick_registration) return;

  if (prefs->get_local_networks()) {
    setLocalNetworks(prefs->get_local_networks());
  } else {
    /* Add defaults */
    /* http://www.networksorcery.com/enp/protocol/ip/multicast.htm */
    setLocalNetworks((char*)CONST_DEFAULT_LOCAL_NETS);
  }

  checkReloadAlertExclusions();

  int num_resolvers =
      ntop->getPrefs()->limitResourcesUsage() ? 1 : CONST_NUM_RESOLVERS;
#if defined(NTOPNG_PRO) || defined(HAVE_NEDGE)
  if (pro->is_embedded_version()) num_resolvers = 1;
#endif
  address = new (std::nothrow) AddressResolution(num_resolvers);

  system_interface = new (std::nothrow)
      NetworkInterface(SYSTEM_INTERFACE_NAME, SYSTEM_INTERFACE_NAME);

  /* License check could have increased the number of interfaces available */
  resetNetworkInterfaces();

  /* Read the old last_stats_reset */
  if (ntop->getRedis()->get((char*)LAST_RESET_TIME, value, sizeof(value)) >= 0)
    last_stats_reset = atol(value);

#ifndef FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION
  /* Now we can enable the periodic activities */
  pa = new (std::nothrow) PeriodicActivities();
#endif

  prefs->loadInstanceNameDefaults();

#ifdef HAVE_RADIUS
  if (!prefs->limitResourcesUsage())
    radiusAcc = new (std::nothrow) Radius();
  else
    radiusAcc = NULL;
#endif

#ifdef NTOPNG_PRO
  oidcAuth = new (std::nothrow) OIDCAuthenticator();
#endif

  redis->setInitializationComplete();
}

/* ******************************************* */

void Ntop::resetNetworkInterfaces() {
  if (iface) delete[] iface;

  if ((iface = new (std::nothrow)
           NetworkInterface*[MAX_NUM_DEFINED_INTERFACES]()) == NULL)
    throw "Not enough memory";

  ntop->getTrace()->traceEvent(TRACE_INFO, "Interfaces Available: %u",
                               MAX_NUM_DEFINED_INTERFACES);
}

/* ******************************************* */

void Ntop::createExportInterface() {
#ifdef HAVE_ZMQ
#ifndef HAVE_NEDGE
  if (prefs->get_export_endpoint())
    export_interface =
        new (std::nothrow) ExportInterface(prefs->get_export_endpoint());
  else
    export_interface = NULL;
#endif
#endif
}

/* ******************************************* */

void Ntop::start() {
  struct timeval begin, end;
  u_long usec_diff;
  char daybuf[64], buf[128];
  time_t when = time(NULL);
  int i = 0;

  getTrace()->traceEvent(TRACE_NORMAL, "Welcome to %s %s v.%s (%s)",
#ifdef HAVE_NEDGE
                         "ntopng edge",
#else
                         "ntopng",
#endif
                         PACKAGE_MACHINE, PACKAGE_VERSION, NTOPNG_GIT_RELEASE);

  if (PACKAGE_OS[0] != '\0')
    getTrace()->traceEvent(TRACE_NORMAL, "Built on %s", PACKAGE_OS);

  getTrace()->traceEvent(TRACE_NORMAL, "(C) 1998-26 ntop");

  last_modified_static_file_epoch = start_time = time(NULL);
  snprintf(epoch_buf, sizeof(epoch_buf), "%u", (u_int32_t)start_time);

  string_to_replace[i].key = CONST_HTTP_PREFIX_STRING,
  string_to_replace[i].val = ntop->getPrefs()->get_http_prefix();
  i++;
  string_to_replace[i].key = CONST_NTOP_STARTUP_EPOCH,
  string_to_replace[i].val = ntop->getStartTimeString();
  i++;
  string_to_replace[i].key = CONST_NTOP_PRODUCT_NAME,
  string_to_replace[i].val =
#ifdef HAVE_NEDGE
      ntop->getPro()->get_product_name()
#else
      (char*)"ntopng"
#endif
      ;
  i++;
  string_to_replace[i].key = NULL, string_to_replace[i].val = NULL;

  strftime(daybuf, sizeof(daybuf), CONST_DB_DAY_FORMAT, localtime(&when));
  snprintf(buf, sizeof(buf), "ntopng.%s.hostkeys", daybuf);

#ifdef NTOPNG_PRO
  if (!pro->forced_community_edition()) pro->printLicenseInfo();
#endif

  FlowRiskAlerts::checkUndefinedRisks();

  loadLocalInterfaceAddress();

  address->startResolveAddressLoop();

  system_interface->allocateStructures();

  for (int i = 0; i < num_defined_interfaces; i++)
    iface[i]->allocateStructures();

  /* Note: must start periodic activities loop only *after* interfaces have been
   * completely initialized.
   *
   * Note: this will also run the startup.lua script sequentially.
   * After this call, startup.lua has completed. */
  pa->startPeriodicActivitiesLoop();

  if (get_HTTPserver()) get_HTTPserver()->start_accepting_requests();

#ifdef HAVE_NEDGE
  /* TODO: enable start/stop of the captive portal webserver directly from Lua
   */
  if (get_HTTPserver() && prefs->isCaptivePortalEnabled())
    get_HTTPserver()->startCaptiveServer();
#endif

#ifdef HAVE_NEDGE
  char key[128];
  char** keys = NULL;
  int nkeys;
  char repeater[256];

  snprintf(key, sizeof(key), "ntopng.prefs.config.repeater.*");

  nkeys = redis->keys(key, &keys);

  for (int i = 0; i < nkeys; i++) {
    memset(repeater, 0, sizeof(repeater));
    redis->get(keys[i], repeater, sizeof(repeater));

    string ip;
    int port = 0;
    string interfaces;
    string restricted_interfaces;
    string type;
    bool keep_source = false;
    char* tmp = NULL;

    char* token = strtok_r(repeater, "|", &tmp);
    if (token != NULL) {
      type = token;
      token = strtok_r(NULL, "|", &tmp);
    }
    if (token != NULL) {
      ip = token;
      token = strtok_r(NULL, "|", &tmp);
    }
    if (token != NULL) {
      port = atoi(token);
      token = strtok_r(NULL, "|", &tmp);
    }
    if (token != NULL) {
      interfaces = token;
      token = strtok_r(NULL, "|", &tmp);
    }
    if (token != NULL) {
      keep_source = (token[0] == '1');
      token = strtok_r(NULL, "|", &tmp);
    }
    if (token != NULL) {
      restricted_interfaces = token;
    }
    if (interfaces.length() > 0) {
      PacketForwarder* multicastForwarder;

      if (ip.length() > 3 && strcmp(ip.c_str() + ip.length() - 3, "255") == 0)
        multicastForwarder = new (std::nothrow) BroadcastForwarder(
            ip, port, interfaces, restricted_interfaces, keep_source);
      else
        multicastForwarder = new (std::nothrow) MulticastForwarder(
            ip, port, interfaces, restricted_interfaces, keep_source);

      if (multicastForwarder) {
        multicastForwarder->start();
        multicastForwarders.push_back(multicastForwarder);
      } else {
        ntop->getTrace()->traceEvent(
            TRACE_ERROR,
            "Error occured instantiating forwarder on IP %s Port %d",
            ip.c_str(), port);
      }
    }

    if (keys[i]) free(keys[i]);
  }
  if (keys) free(keys);
#endif

  checkReloadHostPools();
  checkReloadFlowChecks();
  checkReloadHostChecks();

#ifdef NTOPNG_PRO
  connectMessageBroker();
#endif /* NTOPNG_PRO */

  for (int i = 0; i < num_defined_interfaces; i++)
    iface[i]->startPacketPolling();

  for (int i = 0; i < num_defined_interfaces; i++)
    iface[i]->checkPointCounters(true); /* Reset drop counters */

  /* Align to the next 5-th second of the clock to make sure
     housekeeping starts alinged (and remains aligned when
     the housekeeping frequency is a multiple of 5 seconds) */
  gettimeofday(&begin, NULL);
  _usleep((5 - begin.tv_sec % 5) * 1e6 - begin.tv_usec);

  registerThread("ntopng", pthread_self());

  globals->setInitialized(); /* We're ready to go */

  while ((!globals->isShutdown()) && (!globals->isShutdownRequested())) {
    const u_int32_t nap_usec =
        ntop->getPrefs()->get_housekeeping_frequency() * 1e6; /* 5 sec */

    gettimeofday(&begin, NULL);

    /* Run periodic tasks (note: this also runs runHousekeepingTasks) */
    runPeriodicHousekeepingTasks();

    /*
      Check if it is time to signal the shutdown, depending on the
      configuration. NOTE: Shutdown when done is only meaningful for pcap-dump
      interfaces when the file has been read.
    */
    checkShutdownWhenDone();

    gettimeofday(&end, NULL);
    usec_diff = Utils::usecTimevalDiff(&end, &begin);

    if (usec_diff >= nap_usec) {
      ntop->getTrace()->traceEvent(
          TRACE_NORMAL, "Housekeeping activities (main loop) took %.3fs",
          (float)usec_diff / 1e6);
    } else {
      while (usec_diff < nap_usec) {
        u_int32_t remaining_usec = nap_usec - usec_diff;
        u_int32_t power_nap_usec = 100 * 1e3; /* 100 msec */

        _usleep(remaining_usec >= power_nap_usec ? power_nap_usec
                                                 : remaining_usec);

        /* Run high frequency tasks */
        runHousekeepingTasks();

        gettimeofday(&end, NULL);
        usec_diff = Utils::usecTimevalDiff(&end, &begin);
      }
    }
  }
}

/* ******************************************* */

bool Ntop::isLocalAddress(int family, void* addr, int32_t* network_id,
                          u_int8_t* network_mask_bits) {
  u_int8_t nmask_bits;
#if 0
  char ipb[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Find %s",
    Utils::intoaV4(ntohl(*(u_int32_t*)addr), ipb, sizeof(ipb)));
#endif

  *network_id = localNetworkLookup(family, addr, &nmask_bits);

  if ((*network_id != -1) && network_mask_bits)
    *network_mask_bits = nmask_bits;
  
  return (((*network_id) == -1) ? false : true);
};

/* ******************************************* */

void Ntop::getLocalNetworkIp(int32_t local_network_id, IpAddress** network_ip,
                             u_int8_t* network_prefix) {
  char *network_address, *slash;
  *network_ip = new (std::nothrow) IpAddress();
  *network_prefix = 0;

  if (local_network_id >= 0)
    network_address = strdup(getLocalNetworkName(local_network_id));
  else
    network_address = strdup((char*)"0.0.0.0/0"); /* Remote networks */

  if ((slash = strchr(network_address, '/'))) {
    *network_prefix = atoi(slash + 1);
    *slash = '\0';
  }

  if (*network_ip) (*network_ip)->set(network_address);
  if (network_address) free(network_address);
};

/* ******************************************* */

#ifdef WIN32

#include <ws2tcpip.h>
#include <iphlpapi.h>

#define MALLOC(x) HeapAlloc(GetProcessHeap(), 0, (x))
#define FREE(x) HeapFree(GetProcessHeap(), 0, (x))

/* Note: could also use malloc() and free() */

char* Ntop::getIfName(int if_id, char* name, u_int name_len) {
  // Declare and initialize variables
  PIP_INTERFACE_INFO pInfo = NULL;
  ULONG ulOutBufLen = 0;
  DWORD dwRetVal = 0;
  int iReturn = 1;
  int i;

  name[0] = '\0';

  // Make an initial call to GetInterfaceInfo to get
  // the necessary size in the ulOutBufLen variable
  dwRetVal = GetInterfaceInfo(NULL, &ulOutBufLen);
  if (dwRetVal == ERROR_INSUFFICIENT_BUFFER) {
    pInfo = (IP_INTERFACE_INFO*)MALLOC(ulOutBufLen);
    if (pInfo == NULL) {
      return (name);
    }
  }

  // Make a second call to GetInterfaceInfo to get
  // the actual data we need
  dwRetVal = GetInterfaceInfo(pInfo, &ulOutBufLen);
  if (dwRetVal == NO_ERROR) {
    for (i = 0; i < pInfo->NumAdapters; i++) {
      if (pInfo->Adapter[i].Index == if_id) {
        int j, k, begin = 0;

        for (j = 0, k = 0;
             (k < name_len) && (pInfo->Adapter[i].Name[j] != '\0'); j++) {
          if (begin) {
            if ((char)pInfo->Adapter[i].Name[j] == '}') break;
            name[k++] = (char)pInfo->Adapter[i].Name[j];
          } else if ((char)pInfo->Adapter[i].Name[j] == '{')
            begin = 1;
        }

        name[k] = '\0';
      }
      break;
    }
  }

  FREE(pInfo);
  return (name);
}

#endif

/* ******************************************* */

/* ******************************************* */

void Ntop::loadLocalInterfaceAddress() {
  const int bufsize = 128;
  char buf[bufsize];

#ifdef WIN32
  PMIB_IPADDRTABLE pIPAddrTable;
  DWORD dwSize = 0;
  DWORD dwRetVal = 0;
  IN_ADDR IPAddr;
  char buf2[bufsize];

  /* Variables used to return error message */
  LPVOID lpMsgBuf;

  // Before calling AddIPAddress we use GetIpAddrTable to get
  // an adapter to which we can add the IP.
  pIPAddrTable = (MIB_IPADDRTABLE*)MALLOC(sizeof(MIB_IPADDRTABLE));

  if (pIPAddrTable) {
    // Make an initial call to GetIpAddrTable to get the
    // necessary size into the dwSize variable
    if (GetIpAddrTable(pIPAddrTable, &dwSize, 0) == ERROR_INSUFFICIENT_BUFFER) {
      FREE(pIPAddrTable);
      pIPAddrTable = (MIB_IPADDRTABLE*)MALLOC(dwSize);
    }
    if (pIPAddrTable == NULL) {
      return;
    }
  }

  // Make a second call to GetIpAddrTable to get the
  // actual data we want
  if ((dwRetVal = GetIpAddrTable(pIPAddrTable, &dwSize, 0)) != NO_ERROR) {
    if (FormatMessage(
            FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
                FORMAT_MESSAGE_IGNORE_INSERTS,
            NULL, dwRetVal,
            MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),  // Default language
            (LPTSTR)&lpMsgBuf, 0, NULL)) {
      LocalFree(lpMsgBuf);
    }

    return;
  }

  for (int ifIdx = 0; ifIdx < (int)pIPAddrTable->dwNumEntries; ifIdx++) {
    char name[256];

    getIfName(pIPAddrTable->table[ifIdx].dwIndex, name, sizeof(name));

    for (int id = 0; id < num_defined_interfaces; id++) {
      if ((name[0] != '\0') && (strstr(iface[id]->get_name(), name) != NULL)) {
        u_int32_t bits = Utils::numberOfSetBits(
            (u_int32_t)pIPAddrTable->table[ifIdx].dwMask);

        IPAddr.S_un.S_addr = (u_long)pIPAddrTable->table[ifIdx].dwAddr;
        snprintf(buf, bufsize, "%s/32", inet_ntoa(IPAddr));
        local_interface_addresses.addAddress(buf);
        ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                     "Adding %s as IPv4 NIC addr. [%s]", buf,
                                     iface[id]->get_description());
        iface[id]->addInterfaceAddress(buf);

        IPAddr.S_un.S_addr = (u_long)(pIPAddrTable->table[ifIdx].dwAddr &
                                      pIPAddrTable->table[ifIdx].dwMask);
        snprintf(buf2, bufsize, "%s/%u", inet_ntoa(IPAddr), bits);
        ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                     "Adding %s as IPv4 local nw [%s]", buf2,
                                     iface[id]->get_description());
        addLocalNetworkList(buf2);
        iface[id]->addInterfaceNetwork(buf2, buf);
      }
    }
  }

  /* TODO: add IPv6 support */
  if (pIPAddrTable) {
    FREE(pIPAddrTable);
    pIPAddrTable = NULL;
  }
#else
  struct ifaddrs *local_addresses, *ifa;
  /* buf must be big enough for an IPv6 address(e.g.
   * 3ffe:2fa0:1010:ca22:020a:95ff:fe8a:1cf8) */
  char buf_orig[bufsize + 32];
  char net_buf[bufsize + 32];
  int sock =
      Utils::openSocket(AF_INET, SOCK_STREAM, 0, "loadLocalInterfaceAddress");
  std::map<std::string, int> ifaces;
  std::map<std::string, int>::iterator it;

  for (int i = 0; i < num_defined_interfaces; i++) {
    char ifbuf[256], *tok, *tmp;

    snprintf(ifbuf, sizeof(ifbuf), "%s", iface[i]->get_name());
    tok = strtok_r(ifbuf, ",", &tmp);

    while (tok != NULL) {
      if (strchr(tok, ':') == NULL) ifaces[std::string(tok)] = i;

      tok = strtok_r(NULL, ",", &tmp);
    }
  }

  if (getifaddrs(&local_addresses) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to read interface addresses");
    Utils::closeSocket(sock);
    return;
  }

  for (ifa = local_addresses; ifa != NULL; ifa = ifa->ifa_next) {
    struct ifreq ifr;
    u_int32_t netmask;
    int cidr, ifId = -1;

    if ((ifa->ifa_addr == NULL) ||
        ((ifa->ifa_addr->sa_family != AF_INET) &&
         (ifa->ifa_addr->sa_family != AF_INET6)) ||
        ((ifa->ifa_flags & IFF_UP) == 0))
      continue;

    it = ifaces.find(ifa->ifa_name);
    if (it != ifaces.end())
      ifId = it->second;
    else
      continue;

    if (ifa->ifa_addr->sa_family == AF_INET) {
      struct sockaddr_in* s4 = (struct sockaddr_in*)(ifa->ifa_addr);
      u_int32_t nm;

      memset(&ifr, 0, sizeof(ifr));
      ifr.ifr_addr.sa_family = AF_INET;
      strncpy(ifr.ifr_name, ifa->ifa_name, sizeof(ifr.ifr_name) - 1);
      ioctl(sock, SIOCGIFNETMASK, &ifr);
      netmask = ((struct sockaddr_in*)&ifr.ifr_addr)->sin_addr.s_addr;

      cidr = 0, nm = netmask;

      while (nm) {
        cidr += (nm & 0x01);
        nm >>= 1;
      }

      if (inet_ntop(ifa->ifa_addr->sa_family, (void*)&(s4->sin_addr), buf,
                    sizeof(buf)) != NULL) {
        char buf_orig2[bufsize + 32];

        snprintf(buf_orig2, sizeof(buf_orig2), "%s/%d", buf, 32);
        ntop->getTrace()->traceEvent(
            TRACE_NORMAL, "Adding %s as IPv4 interface address for %s",
            buf_orig2, iface[ifId]->get_name());
        local_interface_addresses.addAddress(buf_orig2);
        iface[ifId]->addInterfaceAddress(buf_orig2);

        /* Set to zero non network bits */
        s4->sin_addr.s_addr =
            htonl(ntohl(s4->sin_addr.s_addr) & ntohl(netmask));
        inet_ntop(ifa->ifa_addr->sa_family, (void*)&(s4->sin_addr), buf,
                  sizeof(buf));
        snprintf(net_buf, sizeof(net_buf), "%s/%d", buf, cidr);
        ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                     "Adding %s as IPv4 local network for %s",
                                     net_buf, iface[ifId]->get_name());
        iface[ifId]->addInterfaceNetwork(net_buf, buf_orig2);
        addLocalNetworkList(net_buf);
      }
    } else if (ifa->ifa_addr->sa_family == AF_INET6) {
      struct sockaddr_in6* s6 = (struct sockaddr_in6*)(ifa->ifa_netmask);
      u_int8_t* b = (u_int8_t*)&(s6->sin6_addr);

      cidr = 0;

      for (int i = 0; i < 16; i++) {
        u_int8_t num_bits = __builtin_popcount(b[i]);

        if (num_bits == 0) break;
        cidr += num_bits;
      }

      s6 = (struct sockaddr_in6*)(ifa->ifa_addr);
      if (inet_ntop(ifa->ifa_addr->sa_family, (void*)&(s6->sin6_addr), buf,
                    sizeof(buf)) != NULL) {
        snprintf(buf_orig, sizeof(buf_orig), "%s/%d", buf, 128);

        ntop->getTrace()->traceEvent(
            TRACE_NORMAL, "Adding %s as IPv6 interface address for %s",
            buf_orig, iface[ifId]->get_name());
        local_interface_addresses.addAddresses(buf_orig);
        iface[ifId]->addInterfaceAddress(buf_orig);

        for (int i = cidr, j = 0; i > 0; i -= 8, ++j)
          s6->sin6_addr.s6_addr[j] &=
              i >= 8 ? 0xff : (u_int32_t)((0xffU << (8 - i)) & 0xffU);

        inet_ntop(ifa->ifa_addr->sa_family, (void*)&(s6->sin6_addr), buf,
                  sizeof(buf));
        snprintf(net_buf, sizeof(net_buf), "%s/%d", buf, cidr);
        ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                     "Adding %s as IPv6 local network for %s",
                                     net_buf, iface[ifId]->get_name());

        iface[ifId]->addInterfaceNetwork(net_buf, buf_orig);
        addLocalNetworkList(net_buf);
      }
    }
  }

  freeifaddrs(local_addresses);

  Utils::closeSocket(sock);
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO,
                               "Local Interface Addresses (System Host)");
  ntop->getTrace()->traceEvent(TRACE_INFO, "Local Networks");
}

/* ******************************************* */

void Ntop::loadGeolocation() {
  if (geo != NULL) delete geo;
  geo = new (std::nothrow) Geolocation();
}

/* ******************************************* */

void Ntop::loadMacManufacturers(char* dir) {
  if (mac_manufacturers != NULL) delete mac_manufacturers;
  if ((mac_manufacturers = new (std::nothrow) MacManufacturers(dir)) == NULL)
    throw "Not enough memory";
}

/* ******************************************* */

#ifdef HAVE_SNMP_TRAP
void Ntop::initSNMPTrapCollector() {
  if (trap_collector != NULL) return; /* already initialized */

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "Initializing SNMP Trap collector");

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && \
    !defined(HAVE_NEDGE)
  if (Utils::gainWriteCapabilities() == -1)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to enable capabilities");
#endif

  try {
    trap_collector = new SNMPTrap();
  } catch (...) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "Unable to initialize SNMP traps collector");
  }

#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(WIN32) && \
    !defined(HAVE_NEDGE)
  Utils::dropWriteCapabilities();
#endif
}

/* ******************************************* */

void Ntop::toggleSNMPTrapCollector(bool enable) {
  if (trap_collector == NULL) {
    initSNMPTrapCollector();

    if (trap_collector == NULL) return;
  }

  if (enable) {
    trap_collector->startTrapCollection();
  } else {
    trap_collector->stopTrapCollection();
  }
}
#endif

/* ******************************************* */

void Ntop::setWorkingDir(char* dir) {
  snprintf(working_dir, sizeof(working_dir), "%s", dir);
  removeTrailingSlash(working_dir);
  setScriptsDir();
};

/* ******************************************* */

void Ntop::removeTrailingSlash(char* str) {
  int len = (int)strlen(str) - 1;

  if ((len > 0) && ((str[len] == '/') || (str[len] == '\\'))) str[len] = '\0';
}

/* ******************************************* */

void Ntop::setCustomnDPIProtos(char* path) {
  if (path != NULL) {
    if (custom_ndpi_protos != NULL) free(custom_ndpi_protos);
    custom_ndpi_protos = strdup(path);
  }
}

/* ******************************************* */

void Ntop::lua_periodic_activities_stats(NetworkInterface* iface,
                                         lua_State* vm) {
  if (pa) pa->lua(iface, vm);
}

/* ******************************************* */

void Ntop::lua_alert_queues_stats(lua_State* vm) {
  lua_newtable(vm);

  if (getInternalAlertsQueue())
    getInternalAlertsQueue()->lua(vm, "internal_alerts_queue");

  lua_pushstring(vm, "alert_queues");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ******************************************* */

bool Ntop::recipients_are_empty() { return recipients.empty(); }

/* ******************************************* */

bool Ntop::recipients_enqueue(AlertFifoItem* notification) {
  return recipients.enqueue(notification);
}

/* ******************************************* */

bool Ntop::recipient_enqueue(u_int16_t recipient_id,
                             const AlertFifoItem* const notification) {
  return recipients.enqueue(recipient_id, notification);
}

/* ******************************************* */

AlertFifoItem* Ntop::recipient_dequeue(u_int16_t recipient_id) {
  return recipients.dequeue(recipient_id);
}

/* ******************************************* */

void Ntop::recipient_stats(u_int16_t recipient_id, lua_State* vm) {
  recipients.lua(recipient_id, vm);
}

/* ******************************************* */

time_t Ntop::recipient_last_use(u_int16_t recipient_id) {
  return recipients.last_use(recipient_id);
}

/* ******************************************* */

void Ntop::inc_recipient_stats(u_int16_t recipient_id, u_int64_t delivered,
                               u_int64_t filtered_out,
                               u_int64_t delivery_failures) {
  recipients.incStats(recipient_id, delivered, filtered_out, delivery_failures);
}

/* ******************************************* */

void Ntop::recipient_delete(u_int16_t recipient_id) {
  recipients.delete_recipient(recipient_id);
}

/* ******************************************* */

void Ntop::recipient_register(
    u_int16_t recipient_id, AlertLevel minimum_severity,
    Bitmap128 enabled_categories, Bitmap4096 enabled_host_pools,
    Bitmap128 enabled_entities, Bitmap128 enabled_flow_alert_types,
    Bitmap128 enabled_host_alert_types, Bitmap128 enabled_other_alert_types,
    bool match_alert_id, bool skip_alerts, Bitmap64 enabled_labels) {
  recipients.register_recipient(
      recipient_id, minimum_severity, enabled_categories, enabled_host_pools,
      enabled_entities, enabled_flow_alert_types, enabled_host_alert_types,
      enabled_other_alert_types, match_alert_id, skip_alerts, enabled_labels);
}

/* ******************************************* */

AlertLevel Ntop::get_default_recipient_minimum_severity() {
  return recipients.get_default_recipient_minimum_severity();
}

/* ******************************************* */

void Ntop::getUsers(lua_State* vm) {
  char** usernames;
  char* username;
  char *key, *val;
  int rc, i;
  size_t len;

  lua_newtable(vm);

  if ((rc = ntop->getRedis()->keys("ntopng.user.*.password", &usernames)) <= 0)
    return;

  if ((key = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL)
    return;
  else if ((val = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL) {
    free(key);
    return;
  }

  for (i = 0; i < rc; i++) {
    if (usernames[i] == NULL) goto next_username; /* safety check */
    if ((username = strchr(usernames[i], '.')) == NULL) goto next_username;
    if ((username = strchr(username + 1, '.')) == NULL) goto next_username;
    len = strlen(++username);

    if (len < sizeof(".password")) goto next_username;
    username[len - sizeof(".password") + 1] = '\0';

    lua_newtable(vm);

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_FULL_NAME,
             username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, "full_name", val);
    else
      lua_push_str_table_entry(vm, "full_name", (char*)"unknown");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_PASSWORD, username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, "password", val);
    else
      lua_push_str_table_entry(vm, "password", (char*)"unknown");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_GROUP, username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, "group", val);
    else
      lua_push_str_table_entry(vm, "group", (char*)NTOP_UNKNOWN_GROUP);

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_LANGUAGE, username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, "language", val);
    else
      lua_push_str_table_entry(vm, "language", (char*)"");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_ALLOW_PCAP,
             username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_bool_table_entry(vm, "allow_pcap_download", true);

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE,
             CONST_STR_USER_ALLOW_HISTORICAL_FLOW, username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_bool_table_entry(vm, "allow_historical_flows", true);

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_ALLOW_ALERTS,
             username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_bool_table_entry(vm, "allow_alerts", true);

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_NETS, username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, CONST_ALLOWED_NETS, val);
    else
      lua_push_str_table_entry(vm, CONST_ALLOWED_NETS, (char*)"");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_ALLOWED_IFNAME,
             username);
    if ((ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0) &&
        val[0] != '\0')
      lua_push_str_table_entry(vm, CONST_ALLOWED_IFNAME, val);
    else
      lua_push_str_table_entry(vm, CONST_ALLOWED_IFNAME, (char*)"");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_HOST_POOL_ID,
             username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_uint64_table_entry(vm, "host_pool_id", atoi(val));

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_ALLOWED_HOST_POOLS,
             username);
    if (ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0 &&
        val[0] != '\0')
      lua_push_str_table_entry(vm, "allowed_host_pools", val);
    else
      lua_push_str_table_entry(vm, "allowed_host_pools", (char*)"");

    lua_pushstring(vm, username);
    lua_insert(vm, -2);
    lua_settable(vm, -3);

  next_username:

    if (usernames[i]) free(usernames[i]);
  }

  free(usernames);
  free(key), free(val);
}

/* ******************************************* */

/**
 * @brief Check if the current user is an administrator
 *
 * @param vm   The lua state.
 * @return true if the current user is an administrator, false otherwise.
 */
bool Ntop::isUserAdministrator(lua_State* vm) {
  struct mg_connection* conn;
  char *username, *group;

  if (!ntop->getPrefs()->is_users_login_enabled())
    return (true); /* login disabled for all users, everyone's an admin */

  if ((conn = getLuaVMUservalue(vm, conn)) == NULL) {
    /* this is an internal script (e.g. periodic script), admin check should
     * pass */
    return (true);
  } else if (HTTPserver::authorized_localhost_user_login(conn))
    return (true); /* login disabled from localhost, everyone's connecting from
                      localhost is an admin */

  if ((username = getLuaVMUserdata(vm, user)) == NULL) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(%s): NO", __FUNCTION__,
    // "???");
    return (false); /* Unknown */
  }

  if (!strncmp(username, NTOP_NOLOGIN_USER, strlen(username))) return (true);

  if ((group = getLuaVMUserdata(vm, group)) != NULL) {
    return (!strcmp(group, NTOP_NOLOGIN_USER) ||
            !strcmp(group, CONST_ADMINISTRATOR_USER));
  } else {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(%s): NO", __FUNCTION__,
    // username);
    return (false); /* Unknown */
  }
}

/* ******************************************* */

void Ntop::getAllowedInterface(lua_State* vm) {
  char* allowed_ifname;

  allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);

  lua_pushstring(vm, allowed_ifname != NULL ? allowed_ifname : (char*)"");
}

/* ******************************************* */

void Ntop::getAllowedNetworks(lua_State* vm) {
  char key[64], val[64];
  const char* username = getLuaVMUservalue(vm, user);

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, username ? username : "");
  lua_pushstring(vm, (ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
                         ? val
                         : CONST_DEFAULT_ALL_NETS);
}

/* ******************************************* */

// NOTE: ifname must be of size MAX_INTERFACE_NAME_LEN
bool Ntop::getInterfaceAllowed(lua_State* vm, char* ifname) const {
  char* allowed_ifname;

  allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);

  if (ifname == NULL) return false;

  if ((allowed_ifname == NULL) || (allowed_ifname[0] == '\0')) {
    ifname = NULL;
    return false;
  }

  strncpy(ifname, allowed_ifname, MAX_INTERFACE_NAME_LEN - 1);
  ifname[MAX_INTERFACE_NAME_LEN - 1] = '\0';
  return true;
}

/* ******************************************* */

bool Ntop::isInterfaceAllowed(lua_State* vm, const char* ifname) const {
  char* allowed_ifname;
  bool ret;

  if (vm == NULL || ifname == NULL)
    return true; /* Always return true when no lua state is passed */

  allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);

  if ((allowed_ifname == NULL) || (allowed_ifname[0] == '\0')) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG,
                                 "No allowed interface found for %s", ifname);
    // this is a lua script called within ntopng (no HTTP UI and user
    // interaction, e.g. startup.lua)
    ret = true;
  } else {
    ntop->getTrace()->traceEvent(TRACE_DEBUG,
                                 "Allowed interface %s, requested %s",
                                 allowed_ifname, ifname);
    ret = !strncmp(allowed_ifname, ifname, strlen(allowed_ifname));
  }

  return ret;
}

/* ******************************************* */

bool Ntop::isLocalUser(lua_State* vm) {
  struct mg_connection* conn;

  if ((conn = getLuaVMUservalue(vm, conn)) == NULL) {
    /* this is an internal script (e.g. periodic script), admin check should
     * pass */
    return (true);
  }

  return getLuaVMUservalue(vm, localuser);
}

/* ******************************************* */

bool Ntop::isInterfaceAllowed(lua_State* vm, int ifid) const {
  return isInterfaceAllowed(vm, prefs->get_if_name(ifid));
}

/* ******************************************* */

bool Ntop::isPcapDownloadAllowed(lua_State* vm, const char* ifname) {
  bool allow_pcap_download = false;

  if (isUserAdministrator(vm)) return true;

  if (isInterfaceAllowed(vm, ifname)) {
    char* username = getLuaVMUserdata(vm, user);
    bool allow_historical_flows;
    bool allow_alerts;

    ntop->getUserCapabilities(username, &allow_pcap_download,
                              &allow_historical_flows, &allow_alerts);
  }

  return (allow_pcap_download);
}

/* ******************************************* */

char* Ntop::preparePcapDownloadFilter(lua_State* vm, char* filter) {
  char* username;
  char* restricted_filter = NULL;
  char key[64], nets[MAX_USER_NETS_VAL_LEN], nets_cpy[MAX_USER_NETS_VAL_LEN];
  char *tmp, *net;
  int filter_len = 0, len = 0, off = 0, num_nets = 0;

  /* check user */

  if (isUserAdministrator(vm)) /* keep the original filter */
    goto no_restriction;

  username = getLuaVMUserdata(vm, user);
  if (username == NULL || username[0] == '\0') return (NULL);

  /* read networks */

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);
  if (ntop->getRedis()->get(key, nets, sizeof(nets)) < 0 || strlen(nets) == 0)
    goto no_restriction; /* no subnet configured for this user */

  if (filter != NULL) filter_len = strlen(filter);

  num_nets = 0;
  tmp = NULL;
  strcpy(nets_cpy, nets);
  net = strtok_r(nets_cpy, ",", &tmp);
  while (net != NULL) {
    if (strcmp(net, "0.0.0.0/0") != 0 && strcmp(net, "::/0") != 0) num_nets++;
    net = strtok_r(NULL, ",", &tmp);
  }

  if (num_nets == 0) goto no_restriction;

  /* build final/restricted filter */

  len = filter_len + strlen(nets) + num_nets * strlen(" or net ") +
        strlen("() and ()") + 1;

  restricted_filter = (char*)malloc(len + 1);
  if (restricted_filter == NULL) return (NULL);
  restricted_filter[0] = '\0';

  if (filter_len > 0) off += snprintf(&restricted_filter[off], len - off, "(");

  num_nets = 0;
  tmp = NULL;
  strcpy(nets_cpy, nets);
  net = strtok_r(nets_cpy, ",", &tmp);
  while (net != NULL) {
    if (strcmp(net, "0.0.0.0/0") != 0 && strcmp(net, "::/0") != 0) {
      if (num_nets > 0)
        off += snprintf(&restricted_filter[off], len - off, " or ");
      off += snprintf(&restricted_filter[off], len - off, "net %s", net);
      num_nets++;
    }
    net = strtok_r(NULL, ",", &tmp);
  }

  if (filter_len > 0)
    off += snprintf(&restricted_filter[off], len - off, ") and (%s)", filter);

  return (restricted_filter);

no_restriction:
  return (strdup(filter == NULL ? "" : filter));
}

/* ******************************************* */

bool Ntop::checkUserInterfaces(const char* user) const {
  char ifbuf[MAX_INTERFACE_NAME_LEN];

  /* Check if the user has an allowed interface and that interface has not yet
     been instantiated in ntopng (e.g, this can happen with dynamic interfaces
     after ntopng has been restarted.) */
  getUserAllowedIfname(user, ifbuf, sizeof(ifbuf));
  if (ifbuf[0] != '\0' && !isExistingInterface(ifbuf)) return false;

  return true;
}

/* ******************************************* */

bool Ntop::getUserPasswordHashLocal(const char* user, char* password_hash,
                                    u_int password_hash_len) const {
  char key[64], val[64];

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, user);

  if (ntop->getRedis()->get(key, val, sizeof(val)) < 0) {
    return (false);
  }

  snprintf(password_hash, password_hash_len, "%s", val);
  return (true);
}

/* ******************************************* */

void Ntop::getUserGroupLocal(const char* user, char* group) const {
  char key[64], val[64];

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, user);

  strncpy(group,
          ((ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
               ? val
               : NTOP_UNKNOWN_GROUP),
          NTOP_GROUP_MAXLEN - 1);
  group[NTOP_GROUP_MAXLEN - 1] = '\0';
}

/* ******************************************* */

bool Ntop::isLocalAuthEnabled() const {
  char val[64];

  if ((ntop->getRedis()->get((char*)PREF_NTOP_LOCAL_AUTH, val, sizeof(val)) >=
       0) &&
      val[0] == '0')
    return (false);

  return (true);
}

/* ******************************************* */

bool Ntop::checkLocalAuth(const char* user, const char* password,
                          char* group) const {
  char val[64], password_hash[33];

  if (!isLocalAuthEnabled()) return (false);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Checking Local auth");

  if ((!strcmp(user, "admin")) &&
      (ntop->getRedis()->get((char*)TEMP_ADMIN_PASSWORD, val, sizeof(val)) >=
       0) &&
      (val[0] != '\0') && (!strcmp(val, password)))
    goto valid_local_user;

  if (!getUserPasswordHashLocal(user, val, sizeof(val))) {
    return (false);
  } else {
    mg_md5(password_hash, password, NULL);

    if (strcmp(password_hash, val) != 0) {
      return (false);
    }
  }

valid_local_user:
  getUserGroupLocal(user, group);

  return (true);
}

/* ******************************************* */

bool Ntop::checkHTTPAuth(const char* user, const char* password,
                         char* group) const {
  int postLen;
  char *httpUrl = NULL, *postData = NULL, *returnData = NULL;
  bool http_ret = false;
  int rc = 0;
  HTTPTranferStats stats;
  HTTPAuthenticator auth;
  char val[64];

  if (ntop->getRedis()->get((char*)PREF_NTOP_HTTP_AUTH, val, sizeof(val)) < 0 ||
      val[0] != '1')
    return false;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Checking HTTP auth");

  memset(&auth, 0, sizeof(auth));

  if (!password || !password[0]) return false;

  postLen = 100 + strlen(user) + strlen(password);
  if (!(httpUrl = (char*)calloc(sizeof(char), MAX_HTTP_AUTHENTICATOR_LEN)) ||
      !(postData = (char*)calloc(sizeof(char), postLen + 1)) ||
      !(returnData = (char*)calloc(
            sizeof(char), MAX_HTTP_AUTHENTICATOR_RETURN_DATA_LEN + 1))) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
                                 "HTTP: unable to allocate memory");
    goto http_auth_out;
  }
  ntop->getRedis()->get((char*)PREF_HTTP_AUTHENTICATOR_URL, httpUrl,
                        MAX_HTTP_AUTHENTICATOR_LEN);
  if (!httpUrl[0]) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "HTTP: no http url set !");
    goto http_auth_out;
  }
  snprintf(postData, postLen, "{\"user\": \"%s\", \"password\": \"%s\"}", user,
           password);

  if (Utils::postHTTPJsonData(NULL,  // no token
                              NULL,  // no digest user
                              NULL,  // no digest password
                              httpUrl, postData, 0, 0, &stats, returnData,
                              MAX_HTTP_AUTHENTICATOR_RETURN_DATA_LEN, &rc)) {
    if (rc == 200) {
      // parse JSON
      if (!Utils::parseAuthenticatorJson(&auth, returnData)) {
        ntop->getTrace()->traceEvent(
            TRACE_ERROR, "HTTP: unable to parse json answer data !");
        goto http_auth_out;
      }

      strncpy(
          group,
          auth.admin ? CONST_USER_GROUP_ADMIN : CONST_USER_GROUP_UNPRIVILEGED,
          NTOP_GROUP_MAXLEN);
      group[NTOP_GROUP_MAXLEN - 1] = '\0';
      if (auth.allowedNets != NULL) {
        if (!Ntop::changeAllowedNets((char*)user, auth.allowedNets)) {
          ntop->getTrace()->traceEvent(
              TRACE_ERROR, "HTTP: unable to set allowed nets for user %s",
              user);
          goto http_auth_out;
        }
      }
      if (auth.allowedIfname != NULL) {
        if (!Ntop::changeAllowedIfname((char*)user, auth.allowedIfname)) {
          ntop->getTrace()->traceEvent(
              TRACE_ERROR, "HTTP: unable to set allowed ifname for user %s",
              user);
          goto http_auth_out;
        }
      }
      if (auth.language != NULL) {
        if (!Ntop::changeUserLanguage((char*)user, auth.language)) {
          ntop->getTrace()->traceEvent(
              TRACE_ERROR, "HTTP: unable to set language for user %s", user);
          goto http_auth_out;
        }
      }

      http_ret = true;
    } else
      ntop->getTrace()->traceEvent(
          TRACE_WARNING, "HTTP: authentication rejected [code=%d]", rc);
  } else
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "HTTP: could not contact the HTTP authenticator");

http_auth_out:
  Utils::freeAuthenticator(&auth);
  if (httpUrl) free(httpUrl);
  if (postData) free(postData);
  if (returnData) free(returnData);

  return (http_ret);
}

/* ******************************************* */

bool Ntop::checkLDAPAuth(const char* user, const char* password,
                         char* group) const {
  bool ldap_ret = false;
#if defined(NTOPNG_PRO) && defined(HAVE_LDAP)
  char val[64];

  if (!ntop->getPro()->has_valid_license() ||
      ntop->getPrefs()->limitResourcesUsage())
    return false;

  if (ntop->getRedis()->get((char*)PREF_NTOP_LDAP_AUTH, val, sizeof(val)) < 0 ||
      val[0] != '1')
    return false;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Checking LDAP auth");

  bool is_admin = false, has_unprivileged_capabilities = false;
  char *ldapServer = NULL, *ldapAccountType = NULL, *ldapAnonymousBind = NULL,
       *bind_dn = NULL, *bind_pwd = NULL, *user_group = NULL,
       *search_path = NULL, *admin_group = NULL;

  if (!(ldapServer = (char*)calloc(sizeof(char), MAX_LDAP_LEN)) ||
      !(ldapAccountType = (char*)calloc(
            sizeof(char), MAX_LDAP_LEN)) /* either 'posix' or 'samaccount' */
      || !(ldapAnonymousBind = (char*)calloc(
               sizeof(char), MAX_LDAP_LEN)) /* either '1' or '0' */
      || !(bind_dn = (char*)calloc(sizeof(char), MAX_LDAP_LEN)) ||
      !(bind_pwd = (char*)calloc(sizeof(char), MAX_LDAP_LEN)) ||
      !(user_group = (char*)calloc(sizeof(char), MAX_LDAP_LEN)) ||
      !(search_path = (char*)calloc(sizeof(char), MAX_LDAP_LEN)) ||
      !(admin_group = (char*)calloc(sizeof(char), MAX_LDAP_LEN))) {
    static bool ldap_nomem = false;

    if (!ldap_nomem) {
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Unable to allocate memory for the LDAP authentication");
      ldap_nomem = true;
    }

    goto ldap_auth_out;
  }

  ntop->getRedis()->get((char*)PREF_LDAP_SERVER, ldapServer, MAX_LDAP_LEN);
  ntop->getRedis()->get((char*)PREF_LDAP_ACCOUNT_TYPE, ldapAccountType,
                        MAX_LDAP_LEN);
  ntop->getRedis()->get((char*)PREF_LDAP_BIND_ANONYMOUS, ldapAnonymousBind,
                        MAX_LDAP_LEN);
  ntop->getRedis()->get((char*)PREF_LDAP_BIND_DN, bind_dn, MAX_LDAP_LEN);
  ntop->getRedis()->get((char*)PREF_LDAP_BIND_PWD, bind_pwd, MAX_LDAP_LEN);
  ntop->getRedis()->get((char*)PREF_LDAP_SEARCH_PATH, search_path,
                        MAX_LDAP_LEN);
  ntop->getRedis()->get((char*)PREF_LDAP_USER_GROUP, user_group, MAX_LDAP_LEN);
  ntop->getRedis()->get((char*)PREF_LDAP_ADMIN_GROUP, admin_group,
                        MAX_LDAP_LEN);

  if (ldapServer[0]) {
    ldap_ret = LdapAuthenticator::validUserLogin(
        ldapServer, ldapAccountType,
        (atoi(ldapAnonymousBind) == 0) ? false : true,
        bind_dn[0] != '\0' ? bind_dn : NULL,
        bind_pwd[0] != '\0' ? bind_pwd : NULL,
        search_path[0] != '\0' ? search_path : NULL, user,
        password[0] != '\0' ? password : NULL,
        user_group[0] != '\0' ? user_group : NULL,
        admin_group[0] != '\0' ? admin_group : NULL,
        &has_unprivileged_capabilities, &is_admin);

    if (ldap_ret) {
      if (!is_admin) {
        /* Set permissions */
        if (has_unprivileged_capabilities) {
          changeUserPcapDownloadPermission(user, true, 86400 /* 1 day */);
          changeUserHistoricalFlowPermission(user, true, 86400 /* 1 day */);
          changeUserAlertsPermission(user, true, 86400 /* 1 day */);
        } else {
          resetUserPermissions(user);
        }
      }

      strncpy(group,
              is_admin ? CONST_USER_GROUP_ADMIN : CONST_USER_GROUP_UNPRIVILEGED,
              NTOP_GROUP_MAXLEN);
      group[NTOP_GROUP_MAXLEN - 1] = '\0';
    }
  }

ldap_auth_out:
  if (ldapServer) free(ldapServer);
  if (ldapAnonymousBind) free(ldapAnonymousBind);
  if (bind_dn) free(bind_dn);
  if (bind_pwd) free(bind_pwd);
  if (user_group) free(user_group);
  if (search_path) free(search_path);
  if (admin_group) free(admin_group);
#endif

  return ldap_ret;
}

/* ******************************************* */

bool Ntop::checkRadiusAuth(const char* user, const char* password,
                           char* group) const {
  bool radius_ret = false;
#ifdef HAVE_RADIUS
  bool is_admin = false, has_unprivileged_capabilities = false;
  bool external_auth_for_local_users = false;
  char key[64], val[64];

  /*
     NOTE

     Use https://idblender.com/tools/public-radius for testing
     the implementation with a public server
  */

  if (ntop->getPrefs()->limitResourcesUsage()) return false;

  if (ntop->getRedis()->get((char*)PREF_NTOP_RADIUS_AUTH, val, sizeof(val)) <
          0 ||
      val[0] != '1')
    return false;

  ntop->getTrace()->traceEvent(TRACE_INFO, "Checking RADIUS auth");

  if (!password || !password[0]) return false;

  if (!radiusAcc) return false;

  if (radiusAcc->authenticate(user, password, &has_unprivileged_capabilities,
                              &is_admin)) {
    if (ntop->getRedis()->get((char*)PREF_RADIUS_EXT_AUTHE_LOCAL_AUTHO, val,
                              sizeof(val)) >= 0 &&
        val[0] == '1')
      external_auth_for_local_users = true;

    if (external_auth_for_local_users) {
      snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, user);
      if (ntop->getRedis()->get(key, val, sizeof(val)) < 0)
        return false; /* Local user with same name does not exist */

      getUserGroupLocal(user, group);

    } else {
      if (!is_admin) {
        /* Set permissions */
        if (has_unprivileged_capabilities) {
          changeUserPcapDownloadPermission(user, true, 86400 /* 1 day */);
          changeUserHistoricalFlowPermission(user, true, 86400 /* 1 day */);
          changeUserAlertsPermission(user, true, 86400 /* 1 day */);
        } else {
          resetUserPermissions(user);
        }
      }

      strncpy(group,
              is_admin ? CONST_USER_GROUP_ADMIN : CONST_USER_GROUP_UNPRIVILEGED,
              NTOP_GROUP_MAXLEN);
      group[NTOP_GROUP_MAXLEN - 1] = '\0';
    }

    radius_ret = true;
  }
#endif

  return radius_ret;
}

/* ******************************************* */

// Return 1 if username/password is allowed, 0 otherwise.
bool Ntop::checkUserPassword(const char* user, const char* password,
                             char* group, bool* localuser,
                             bool* redirect_to_change_pwd) const {
  *localuser = false;

  if (!user || user[0] == '\0' || !password || password[0] == '\0')
    return (false);

  /* First of all let's check the local user authentication */
  if (checkHTTPAuth(user, password, group)) {
    return (true);
  }

  /* Check local auth */
  if (checkLocalAuth(user, password, group)) {
    if ((strcmp(user, "admin") == 0) && (strcmp(password, "admin") == 0)) {
      /* Force user to change password */
      ntop->getRedis()->set((char*)CONST_DEFAULT_PASSWORD_CHANGED, (char*)"0");
      *redirect_to_change_pwd = true;
    }

    /* mark the user as local */
    *localuser = true;
    return (true);
  }

  /* Now let's check the user by using LDAP (if available) */
  if (checkLDAPAuth(user, password, group)) {
    return (true);
  }

  /* If the user is not a local user and not LDAP user,
    let's check Radius (if available) */
  if (checkRadiusAuth(user, password, group)) {
    return (true);
  }

  return (false);
}

/* ******************************************* */

static int getLoginAttempts(struct mg_connection* conn) {
  char ipbuf[32], key[128], val[16];
  int cur_attempts = 0;
  IpAddress client_addr;

  client_addr.set(mg_get_client_address(conn));
  snprintf(key, sizeof(key), CONST_STR_FAILED_LOGIN_KEY,
           client_addr.print(ipbuf, sizeof(ipbuf)));

  if ((ntop->getRedis()->get(key, val, sizeof(val)) >= 0) && val[0])
    cur_attempts = atoi(val);

  return (cur_attempts);
}

/* ******************************************* */

bool Ntop::isBlacklistedLogin(struct mg_connection* conn) const {
  return (getLoginAttempts(conn) >= MAX_FAILED_LOGIN_ATTEMPTS);
}

/* ******************************************* */

bool Ntop::checkGuiUserPassword(struct mg_connection* conn, const char* user,
                                const char* password, char* group,
                                bool* localuser,
                                bool* redirect_to_change_pwd) const {
  char *remote_ip, ipbuf[64], key[128], val[16];
  int cur_attempts = 0;
  bool rv;
  IpAddress client_addr;

  *redirect_to_change_pwd = false;

  client_addr.set(mg_get_client_address(conn));

  if (ntop->isCaptivePortalUser(user)) {
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "User %s is not a gui user. Login is denied.", user);
    rv = false;
    goto failure;
  }

  remote_ip = client_addr.print(ipbuf, sizeof(ipbuf));

  if ((cur_attempts = getLoginAttempts(conn)) >= MAX_FAILED_LOGIN_ATTEMPTS) {
    ntop->getTrace()->traceEvent(TRACE_INFO,
                                 "Login denied for '%s' from blacklisted IP %s",
                                 user, remote_ip);
    return false;
  }

  rv = checkUserPassword(user, password, group, localuser,
                         redirect_to_change_pwd);
  snprintf(key, sizeof(key), CONST_STR_FAILED_LOGIN_KEY, remote_ip);

  if (!rv) {
    cur_attempts++;
    snprintf(val, sizeof(val), "%d", cur_attempts);
    ntop->getRedis()->set(key, val, FAILED_LOGIN_ATTEMPTS_INTERVAL);

    if (cur_attempts >= MAX_FAILED_LOGIN_ATTEMPTS)
      ntop->getTrace()->traceEvent(
          TRACE_INFO, "IP %s is now blacklisted from login for %d seconds",
          remote_ip, FAILED_LOGIN_ATTEMPTS_INTERVAL);

  } else {
    ntop->getRedis()->del(key);
  }

failure:
  if (!rv) HTTPserver::traceLogin(user, NULL, false);

  return (rv);
}

/* ******************************************* */

bool Ntop::checkCaptiveUserPassword(const char* user, const char* password,
                                    char* group) const {
  bool localuser = false;
  bool rv, redirect_to_change_pwd = false;

  if (!ntop->isCaptivePortalUser(user)) {
    ntop->getTrace()->traceEvent(
        TRACE_WARNING, "User %s is not a captive portal user. Login is denied.",
        user);
    return false;
  }

  rv = checkUserPassword(user, password, group, &localuser,
                         &redirect_to_change_pwd);

  return (rv);
}

/* ******************************************* */

bool Ntop::mustChangePassword(const char* user) {
  char val[8];

  if ((strcmp(user, "admin") == 0) &&
      ((ntop->getRedis()->get((char*)CONST_DEFAULT_PASSWORD_CHANGED, val,
                              sizeof(val)) < 0) ||
       val[0] == '0'))
    return true;

  return false;
}

/* ******************************************* */

/* NOTE: the admin vs local user checks must be performed by the caller */
bool Ntop::resetUserPassword(char* username, char* old_password,
                             char* new_password) {
  char key[64];
  char password_hash[33];
  char group[NTOP_GROUP_MAXLEN];

  if ((old_password != NULL) && (old_password[0] != '\0')) {
    bool localuser = false, redirect_to_change_pwd = false;

    if (!checkUserPassword(username, old_password, group, &localuser,
                           &redirect_to_change_pwd))
      return (false);

    if (!localuser) return (false);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, username);
  mg_md5(password_hash, new_password, NULL);

  if (ntop->getRedis()->set(key, password_hash, 0) < 0) return (false);

  return (true);
}

/* ******************************************* */

bool Ntop::changeUserFullName(const char* username,
                              const char* full_name) const {
  char key[64];

  if (username == NULL || username[0] == '\0' || full_name == NULL ||
      !existsUser(username))
    return false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Changing full name to %s for %s",
                               full_name, username);

  snprintf(key, sizeof(key), CONST_STR_USER_FULL_NAME, username);
  ntop->getRedis()->set(key, full_name, 0);

  return (ntop->getRedis()->set(key, (char*)full_name, 0) >= 0);
}

/* ******************************************* */

bool Ntop::changeUserRole(char* username, char* usertype) const {
  if (usertype != NULL) {
    char key[64];

    snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);

    if (ntop->getRedis()->set(key, usertype, 0) < 0) return (false);
  }

  return (true);
}

/* ******************************************* */

bool Ntop::changeAllowedNets(char* username, char* allowed_nets) const {
  if (allowed_nets != NULL) {
    char key[64];

    snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);

    if (ntop->getRedis()->set(key, allowed_nets, 0) < 0) return (false);
  }

  return (true);
}

/* ******************************************* */

bool Ntop::changeAllowedIfname(char* username, char* allowed_ifname) const {
  /* Add as exception :// */
  char* column_slash = strstr(allowed_ifname, ":__");

  if (username == NULL || username[0] == '\0') return false;

  if (column_slash) column_slash[1] = column_slash[2] = '/';

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
                               "Changing allowed ifname to %s for %s",
                               allowed_ifname, username);

  char key[64];
  snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, username);

  if (allowed_ifname != NULL && allowed_ifname[0] != '\0') {
    return (ntop->getRedis()->set(key, allowed_ifname, 0) >= 0);
  } else {
    ntop->getRedis()->del(key);
  }

  return (true);
}

/* ******************************************* */

/*
 * Set the host pool for a captive portal user on authentication
 * (this is a 1-1 user-pool binding used for policy enforcement)
 */
bool Ntop::changeUserHostPool(const char* username,
                              const char* host_pool_id) const {
  if (username == NULL || username[0] == '\0') return false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
                               "Changing host pool id to %s for %s",
                               host_pool_id, username);

  char key[64];
  snprintf(key, sizeof(key), CONST_STR_USER_HOST_POOL_ID, username);

  if (host_pool_id != NULL && host_pool_id[0] != '\0') {
    return (ntop->getRedis()->set(key, (char*)host_pool_id, 0) >= 0);
  } else {
    ntop->getRedis()->del(key);
  }

  return (true);
}

/* ******************************************* */

/* Set which pools an unprivileged user is allowed to view */
bool Ntop::changeAllowedHostPools(const char* username,
                                  const char* allowed_host_pools) const {
  if (username == NULL || username[0] == '\0') return false;

  char key[CONST_MAX_LEN_REDIS_KEY];
  snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_HOST_POOLS, username);

  if (allowed_host_pools != NULL && allowed_host_pools[0] != '\0')
    return (ntop->getRedis()->set(key, (char*)allowed_host_pools, 0) >= 0);
  else
    ntop->getRedis()->del(key);

  return (true);
}

/* ******************************************* */

void Ntop::getAllowedHostPools(lua_State* vm) {
  Bitmap4096* pools = getLuaVMUservalue(vm, allowed_pools);

  lua_newtable(vm);

  if (!pools) return;

  int bit = pools->getNext(0);
  while (bit >= 0) {
    lua_pushinteger(vm, bit);
    lua_pushboolean(vm, true);
    lua_rawset(vm, -3);
    bit = pools->getNext(bit + 1);
  }
}

/* ******************************************* */

bool Ntop::changeUserLanguage(const char* username,
                              const char* language) const {
  if (username == NULL || username[0] == '\0') return false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Changing user language %s for %s",
                               language, username);

  char key[64];
  snprintf(key, sizeof(key), CONST_STR_USER_LANGUAGE, username);

  if (language != NULL && language[0] != '\0')
    return (ntop->getRedis()->set(key, (char*)language, 0) >= 0);
  else
    ntop->getRedis()->del(key);

  return (true);
}

/* ******************************************* */

bool Ntop::changeUserPcapDownloadPermission(const char* username,
                                            bool allow_pcap_download,
                                            u_int32_t ttl) const {
  char key[64];

  if (username == NULL || username[0] == '\0') return false;

  ntop->getTrace()->traceEvent(
      TRACE_DEBUG, "Changing user permission [allow-pcap-download: %s] for %s",
      allow_pcap_download ? "true" : "false", username);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_PCAP, username);

  if (allow_pcap_download)
    return (ntop->getRedis()->set(key, "1", ttl) >= 0);
  else
    ntop->getRedis()->del(key);

  return (true);
}

/* ******************************************* */

bool Ntop::changeUserHistoricalFlowPermission(const char* username,
                                              bool allow_historical_flows,
                                              u_int32_t ttl) const {
  char key[64];

  if (username == NULL || username[0] == '\0') return false;

  ntop->getTrace()->traceEvent(
      TRACE_DEBUG,
      "Changing user permission [allow-historical-flow: %s] for %s",
      allow_historical_flows ? "true" : "false", username);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_HISTORICAL_FLOW, username);

  if (allow_historical_flows)
    return (ntop->getRedis()->set(key, "1", ttl) >= 0);
  else
    ntop->getRedis()->del(key);

  return (true);
}

/* ******************************************* */

bool Ntop::changeUserAlertsPermission(const char* username, bool allow_alerts,
                                      u_int32_t ttl) const {
  char key[64];

  if (username == NULL || username[0] == '\0') return false;

  ntop->getTrace()->traceEvent(
      TRACE_DEBUG, "Changing user permission [allow-alerts: %s] for %s",
      allow_alerts ? "true" : "false", username);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_ALERTS, username);

  if (allow_alerts)
    return (ntop->getRedis()->set(key, "1", ttl) >= 0);
  else
    ntop->getRedis()->del(key);

  return (true);
}

/* ******************************************* */

void Ntop::resetUserPermissions(const char* user) const {
  char key[64];

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_PCAP, user);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_HISTORICAL_FLOW, user);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_ALERTS, user);
  ntop->getRedis()->del(key);
}

/* ******************************************* */

bool Ntop::hasCapability(lua_State* vm, UserCapabilities capability) {
  u_int64_t capabilities = getLuaVMUservalue(vm, capabilities);
  return !!(capabilities & (1 << capability));
}

/* ******************************************* */

bool Ntop::getUserCapabilities(const char* username, bool* allow_pcap_download,
                               bool* allow_historical_flows,
                               bool* allow_alerts) const {
  char key[64], val[2];

  *allow_pcap_download = *allow_historical_flows = *allow_alerts = false;

  if (username == NULL || username[0] == '\0') return (false);

  /* ************** */
  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_PCAP, username);

  if (ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
    if (strcmp(val, "1") == 0) *allow_pcap_download = true;

  /* ************** */
  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_HISTORICAL_FLOW, username);

  if (ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
    if (strcmp(val, "1") == 0) *allow_historical_flows = true;

  /* ************** */
  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_ALERTS, username);

  if (ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
    if (strcmp(val, "1") == 0) *allow_alerts = true;

  return (true);
}

/* ******************************************* */

/*
  Assigns a unique user id to be assigned to a new ntopng user. Callers must
  lock. Assigned user id, if assignment is successful, is returned in the first
  param.
 */
bool Ntop::assignUserId(u_int8_t* new_user_id) {
  char cur_id_buf[8];
  int cur_id;

  for (cur_id = 0; cur_id < NTOP_MAX_NUM_USERS; cur_id++) {
    snprintf(cur_id_buf, sizeof(cur_id_buf), "%d", cur_id);

    if (!ntop->getRedis()->sismember(PREF_NTOP_USER_IDS, cur_id_buf)) break;
  }

  if (cur_id == NTOP_MAX_NUM_USERS) return false; /* No more ids available */

  if (ntop->getRedis()->sadd(PREF_NTOP_USER_IDS, cur_id_buf) < 0)
    return false; /* Unable to add the newly assigned user id to the set of all
                     user ids */

  *new_user_id = cur_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Assigned user id %u",
                               *new_user_id);

  return true;
}

/* ******************************************* */

bool Ntop::existsUser(const char* username) const {
  char key[CONST_MAX_LEN_REDIS_KEY], val[2] /* Don't care about the content */;

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  if (ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
    return (true);  // user already exists

  return (false);
}

/* ******************************************* */

bool Ntop::addUser(char* username, char* full_name, char* password,
                   char* host_role, char* allowed_networks,
                   char* allowed_ifname, char* host_pool_id, char* language,
                   bool allow_pcap_download, bool allow_historical_flows,
                   bool allow_alerts, char* allowed_host_pools) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  char password_hash[33];
  char new_user_id_buf[8];
  u_int8_t new_user_id = 0;

  users_m.lock(__FILE__, __LINE__);

  if (existsUser(username) /* User already existing */
      || !assignUserId(&new_user_id) /* Unable to assign a user id */) {
    users_m.unlock(__FILE__, __LINE__);
    return (false);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_FULL_NAME, username);
  ntop->getRedis()->set(key, full_name, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  ntop->getRedis()->set(key, (char*)host_role, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_ID, username);
  snprintf(new_user_id_buf, sizeof(new_user_id_buf), "%d", new_user_id);
  ntop->getRedis()->set(key, new_user_id_buf, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, username);
  mg_md5(password_hash, password, NULL);
  ntop->getRedis()->set(key, password_hash, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);
  ntop->getRedis()->set(key, allowed_networks, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_THEME, username);
  ntop->getRedis()->set(key, "", 0);

  snprintf(key, sizeof(key), CONST_STR_USER_DATE_FORMAT, username);
  ntop->getRedis()->set(key, "", 0);

  if (language && language[0] != '\0') {
    snprintf(key, sizeof(key), CONST_STR_USER_LANGUAGE, username);
    ntop->getRedis()->set(key, language, 0);
  }

  if (allow_pcap_download) {
    snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_PCAP, username);
    ntop->getRedis()->set(key, "1", 0);
  }

  if (allow_historical_flows) {
    snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_HISTORICAL_FLOW, username);
    ntop->getRedis()->set(key, "1", 0);
  }

  if (allow_alerts) {
    snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_ALERTS, username);
    ntop->getRedis()->set(key, "1", 0);
  }

  if (allowed_ifname && allowed_ifname[0] != '\0') {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Setting allowed ifname: %s",
                                 allowed_ifname);
    snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, username);
    ntop->getRedis()->set(key, allowed_ifname, 0);
  }

  if (host_pool_id && host_pool_id[0] != '\0') {
    snprintf(key, sizeof(key), CONST_STR_USER_HOST_POOL_ID, username);
    ntop->getRedis()->set(key, host_pool_id, 0);
  }

  if (allowed_host_pools && allowed_host_pools[0] != '\0') {
    snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_HOST_POOLS, username);
    ntop->getRedis()->set(key, allowed_host_pools, 0);
  }

  users_m.unlock(__FILE__, __LINE__);

  return (true);
}

/* ******************************************* */

bool Ntop::addUserAPIToken(const char* username, const char* api_token) {
  char key[CONST_MAX_LEN_REDIS_KEY];

  snprintf(key, sizeof(key), CONST_STR_USER_API_TOKEN, username);
  ntop->getRedis()->set(key, api_token);

  return (true);
}

/* ******************************************* */

/* TOTP/MFA implementation based on RFC 6238 (TOTP) and RFC 4226 (HOTP).
 * Uses OpenSSL HMAC-SHA1 which is already a dependency of ntopng.
 * Secrets are Base32-encoded (RFC 4648) as required by the otpauth:// URI
 * scheme.
 */

static const char* base32_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

/* Encode binary data to Base32 string. Returns the number of bytes written. */
static int base32_encode(const uint8_t* src, int src_len, char* dst,
                         int dst_len) {
  int i, written = 0;
  int bits = 0, val = 0;

  for (i = 0; i < src_len && written < dst_len - 1; i++) {
    val = (val << 8) | src[i];
    bits += 8;
    while (bits >= 5 && written < dst_len - 1) {
      dst[written++] = base32_alphabet[(val >> (bits - 5)) & 0x1F];
      bits -= 5;
    }
  }
  if (bits > 0 && written < dst_len - 1)
    dst[written++] = base32_alphabet[(val << (5 - bits)) & 0x1F];
  dst[written] = '\0';
  return written;
}

/* Decode Base32 string to binary. Returns number of bytes decoded, or -1 on
 * error. */
static int base32_decode(const char* src, uint8_t* dst, int dst_len) {
  int val = 0, bits = 0, written = 0;
  for (int i = 0; src[i] != '\0'; i++) {
    char c = toupper((unsigned char)src[i]);
    const char* p = strchr(base32_alphabet, c);
    if (!p) {
      if (c == '=') break; /* padding */
      return -1;           /* invalid character */
    }
    val = (val << 5) | (int)(p - base32_alphabet);
    bits += 5;
    if (bits >= 8) {
      if (written >= dst_len) return -1;
      dst[written++] = (uint8_t)((val >> (bits - 8)) & 0xFF);
      bits -= 8;
    }
  }
  return written;
}

/* Compute TOTP code for the given secret (Base32) and time counter.
 * Returns a 6-digit code or -1 on error.
 */
static int compute_totp(const char* secret_b32, uint64_t counter) {
  uint8_t secret[64];
  int secret_len = base32_decode(secret_b32, secret, sizeof(secret));
  if (secret_len <= 0) return -1;

  /* Build 8-byte big-endian counter */
  uint8_t msg[8];
  for (int i = 7; i >= 0; i--) {
    msg[i] = counter & 0xFF;
    counter >>= 8;
  }

  /* HMAC-SHA1 */
  unsigned char hmac[20];
  unsigned int hmac_len = sizeof(hmac);
  if (!HMAC(EVP_sha1(), secret, secret_len, msg, sizeof(msg), hmac, &hmac_len))
    return -1;

  /* Dynamic truncation (RFC 4226 §5.3) */
  int offset = hmac[19] & 0x0F;
  uint32_t code =
      ((hmac[offset] & 0x7F) << 24) | ((hmac[offset + 1] & 0xFF) << 16) |
      ((hmac[offset + 2] & 0xFF) << 8) | ((hmac[offset + 3] & 0xFF));

  return (int)(code % 1000000);
}

/* ******************************************* */

bool Ntop::generateTOTPSecret(char* secret, size_t secret_len) const {
  /* Generate 20 random bytes and Base32-encode them */
  uint8_t raw[20];
  if (RAND_bytes(raw, sizeof(raw)) != 1) return false;
  base32_encode(raw, sizeof(raw), secret, (int)secret_len);
  return true;
}

/* ******************************************* */

bool Ntop::setUserTOTPSecret(const char* username, const char* secret) const {
  char key[CONST_MAX_LEN_REDIS_KEY];
  snprintf(key, sizeof(key), CONST_STR_USER_TOTP_SECRET, username);
  return (ntop->getRedis()->set(key, (char*)secret, 0) >= 0);
}

/* ******************************************* */

bool Ntop::getUserTOTPSecret(const char* username, char* secret,
                             size_t secret_len) const {
  char key[CONST_MAX_LEN_REDIS_KEY];
  snprintf(key, sizeof(key), CONST_STR_USER_TOTP_SECRET, username);
  return (ntop->getRedis()->get(key, secret, (u_int)secret_len) >= 0);
}

/* ******************************************* */

bool Ntop::isTOTPEnabled(const char* username) const {
  char key[CONST_MAX_LEN_REDIS_KEY], val[4];
  snprintf(key, sizeof(key), CONST_STR_USER_TOTP_ENABLED, username);
  if (ntop->getRedis()->get(key, val, sizeof(val)) < 0) return false;
  return (val[0] == '1');
}

/* ******************************************* */

bool Ntop::setUserTOTPEnabled(const char* username, bool enabled) const {
  char key[CONST_MAX_LEN_REDIS_KEY];
  snprintf(key, sizeof(key), CONST_STR_USER_TOTP_ENABLED, username);
  return (ntop->getRedis()->set(key, enabled ? (char*)"1" : (char*)"0", 0) >=
          0);
}

/* ******************************************* */

bool Ntop::validateTOTPCode(const char* username, const char* code) const {
  char secret[64];
  if (!getUserTOTPSecret(username, secret, sizeof(secret))) return false;
  if (strlen(code) != 6) return false;
  for (int i = 0; code[i]; i++)
    if (!isdigit((unsigned char)code[i])) return false;

  int input_code = atoi(code);
  uint64_t counter = (uint64_t)(time(NULL) / 30);

  /* Allow ±1 window (90 seconds total) to handle clock skew */
  for (int delta = -1; delta <= 1; delta++) {
    if (compute_totp(secret, counter + (uint64_t)delta) == input_code)
      return true;
  }
  return false;
}

/* ******************************************* */

void Ntop::getTOTPProvisioningUri(const char* username, char* uri,
                                  size_t uri_len) const {
  char secret[64];
  if (!getUserTOTPSecret(username, secret, sizeof(secret))) {
    uri[0] = '\0';
    return;
  }
  const char* issuer = "ntopng";
  snprintf(uri, uri_len,
           "otpauth://totp/%s:%s?secret=%s&issuer=%s&digits=6&period=30",
           issuer, username, secret, issuer);
}

/* ******************************************* */

bool Ntop::createMFAPendingToken(const char* username, const char* referer,
                                 char* token, size_t token_len) const {
  char val[512], key[128];
  char random[64], tmp_token[33];
  srand((int)time(0) ^ (int)getpid());
  snprintf(random, sizeof(random), "%d%s", rand(), username);
  /* mg_md5 produces a 33-char (32 hex + NUL) string */
  mg_md5(tmp_token, random, NULL);
  strncpy(token, tmp_token, token_len - 1);
  token[token_len - 1] = '\0';

  snprintf(key, sizeof(key), "%s.%s", MFA_PENDING_PREFIX, token);
  snprintf(val, sizeof(val), "%s|%s", username, referer ? referer : "/");
  return (ntop->getRedis()->set(key, val, MFA_PENDING_TTL) >= 0);
}

/* ******************************************* */

bool Ntop::getMFAPendingToken(const char* token, char* username,
                              size_t username_len, char* referer,
                              size_t referer_len) const {
  char key[128], val[512];
  snprintf(key, sizeof(key), "%s.%s", MFA_PENDING_PREFIX, token);
  if (ntop->getRedis()->get(key, val, sizeof(val)) < 0) return false;

  char* sep = strchr(val, '|');
  if (!sep) return false;
  *sep = '\0';
  strncpy(username, val, username_len - 1);
  username[username_len - 1] = '\0';
  strncpy(referer, sep + 1, referer_len - 1);
  referer[referer_len - 1] = '\0';
  return true;
}

/* ******************************************* */

void Ntop::deleteMFAPendingToken(const char* token) const {
  char key[128];
  snprintf(key, sizeof(key), "%s.%s", MFA_PENDING_PREFIX, token);
  ntop->getRedis()->del(key);
}

/* ******************************************* */

/* ========================================================================
 * WebAuthn / Passkey implementation
 * Supports ES256 (P-256 / secp256r1) credentials.
 * Requires OpenSSL (already a project dependency) for:
 *   - RAND_bytes (random challenge generation)
 *   - SHA256 (rpId hash + clientDataJSON hash)
 *   - EC_KEY, ECDSA_verify (P-256 signature verification)
 * ======================================================================== */

/* ---------- Base64url helpers ---------- */

static std::string webauthn_b64url_encode(const uint8_t* data, size_t len) {
  static const char T[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  std::string out;
  out.reserve((len + 2) / 3 * 4);
  for (size_t i = 0; i < len; i += 3) {
    uint32_t b = (uint32_t)data[i] << 16;
    if (i + 1 < len) b |= (uint32_t)data[i + 1] << 8;
    if (i + 2 < len) b |= data[i + 2];
    int n = (i + 1 < len) ? ((i + 2 < len) ? 4 : 3) : 2;
    out += T[(b >> 18) & 0x3F];
    out += T[(b >> 12) & 0x3F];
    if (n >= 3) out += T[(b >> 6) & 0x3F];
    if (n >= 4) out += T[b & 0x3F];
  }
  return out;
}

/* Returns number of decoded bytes or -1 on error. */
static int webauthn_b64url_decode(const char* src, uint8_t* dst,
                                   int dst_max) {
  int8_t V[256];
  memset(V, -1, sizeof(V));
  for (int i = 0; i < 26; i++) V[(uint8_t)('A' + i)] = (int8_t)i;
  for (int i = 0; i < 26; i++) V[(uint8_t)('a' + i)] = (int8_t)(26 + i);
  for (int i = 0; i < 10; i++) V[(uint8_t)('0' + i)] = (int8_t)(52 + i);
  V[(uint8_t)'+'] = 62; V[(uint8_t)'-'] = 62;
  V[(uint8_t)'/'] = 63; V[(uint8_t)'_'] = 63;
  V[(uint8_t)'='] = -2; /* padding - stop */

  int out = 0;
  uint32_t acc = 0;
  int bits = 0;
  for (int i = 0; src[i]; i++) {
    unsigned char c = (unsigned char)src[i];
    if (c >= 128) return -1;
    int8_t v = V[c];
    if (v == -2) break;
    if (v < 0) return -1;
    acc = (acc << 6) | (uint32_t)v;
    bits += 6;
    if (bits >= 8) {
      if (out >= dst_max) return -1;
      dst[out++] = (uint8_t)((acc >> (bits - 8)) & 0xFF);
      bits -= 8;
    }
  }
  return out;
}

/* ---------- Minimal CBOR parser ---------- */
/* Supports: uint (0), negint (1), bytes (2), text (3), array (4), map (5) */

struct cbor_val {
  uint8_t  type;   /* major type 0-7 */
  int64_t  i;      /* for uint/negint */
  const uint8_t* p; /* pointer into source for bytes/text */
  size_t   n;      /* byte length for bytes/text; item count for array/map */
};

static uint64_t cbor_get_arg(const uint8_t* buf, size_t buf_len, size_t* off) {
  if (*off >= buf_len) return UINT64_MAX;
  uint8_t ai = buf[*off] & 0x1F;
  (*off)++;
  if (ai < 24) return ai;
  if (ai == 24) {
    if (*off >= buf_len) return UINT64_MAX;
    return buf[(*off)++];
  }
  if (ai == 25) {
    if (*off + 2 > buf_len) return UINT64_MAX;
    uint64_t v = ((uint64_t)buf[*off] << 8) | buf[*off + 1];
    *off += 2;
    return v;
  }
  if (ai == 26) {
    if (*off + 4 > buf_len) return UINT64_MAX;
    uint64_t v = ((uint64_t)buf[*off] << 24) | ((uint64_t)buf[*off + 1] << 16) |
                 ((uint64_t)buf[*off + 2] << 8) | buf[*off + 3];
    *off += 4;
    return v;
  }
  return UINT64_MAX; /* 8-byte or indefinite: not supported */
}

static bool cbor_next(const uint8_t* buf, size_t buf_len, size_t* off,
                       cbor_val* v) {
  if (*off >= buf_len) return false;
  v->type = (buf[*off] >> 5) & 7;
  uint64_t n = cbor_get_arg(buf, buf_len, off);
  if (n == UINT64_MAX) return false;
  switch (v->type) {
    case 0: v->i = (int64_t)n; return true;
    case 1: v->i = -(int64_t)n - 1; return true;
    case 2: case 3:
      if (*off + n > buf_len) return false;
      v->p = buf + *off; v->n = (size_t)n; *off += n; return true;
    case 4: case 5:
      v->n = (size_t)n; return true;
    default: return false;
  }
}

static bool cbor_skip(const uint8_t* buf, size_t buf_len, size_t* off) {
  cbor_val v;
  if (!cbor_next(buf, buf_len, off, &v)) return false;
  size_t count = (v.type == 4) ? v.n : (v.type == 5) ? v.n * 2 : 0;
  for (size_t i = 0; i < count; i++)
    if (!cbor_skip(buf, buf_len, off)) return false;
  return true;
}

/* ---------- COSE / authenticatorData parsing ---------- */

/* Parse a COSE EC2 public key (P-256 / ES256).
 * Expected CBOR map: {1:2, 3:-7, -1:1, -2:<x 32B>, -3:<y 32B>}
 * Returns true and sets x_out/y_out (each 32 bytes) on success. */
static bool parse_cose_ec2(const uint8_t* cbor, size_t cbor_len,
                             uint8_t* x_out, uint8_t* y_out) {
  size_t off = 0;
  cbor_val v;
  if (!cbor_next(cbor, cbor_len, &off, &v) || v.type != 5) return false;
  size_t map_items = v.n;
  bool got_x = false, got_y = false;
  for (size_t i = 0; i < map_items; i++) {
    cbor_val key, val;
    if (!cbor_next(cbor, cbor_len, &off, &key)) return false;
    if (!cbor_next(cbor, cbor_len, &off, &val)) return false;
    if (key.type == 0 || key.type == 1) {
      if (key.i == -2 && val.type == 2 && val.n == 32) {
        memcpy(x_out, val.p, 32); got_x = true;
      } else if (key.i == -3 && val.type == 2 && val.n == 32) {
        memcpy(y_out, val.p, 32); got_y = true;
      }
    }
  }
  return got_x && got_y;
}

/* Extract the authData bytes from a CBOR-encoded attestationObject.
 * Returns a pointer into the cbor buffer and sets *len on success. */
static bool extract_auth_data(const uint8_t* cbor, size_t cbor_len,
                               const uint8_t** auth_data_out,
                               size_t* auth_data_len_out) {
  size_t off = 0;
  cbor_val v;
  if (!cbor_next(cbor, cbor_len, &off, &v) || v.type != 5) return false;
  size_t map_items = v.n;
  for (size_t i = 0; i < map_items; i++) {
    cbor_val key;
    if (!cbor_next(cbor, cbor_len, &off, &key)) return false;
    if (key.type == 3 && key.n == 8 &&
        memcmp(key.p, "authData", 8) == 0) {
      cbor_val val;
      if (!cbor_next(cbor, cbor_len, &off, &val) || val.type != 2)
        return false;
      *auth_data_out = val.p;
      *auth_data_len_out = val.n;
      return true;
    }
    if (!cbor_skip(cbor, cbor_len, &off)) return false;
  }
  return false;
}

struct wa_auth_data {
  uint8_t  rp_id_hash[32];
  uint8_t  flags;
  uint32_t sign_count;
  uint8_t  cred_id[512];
  size_t   cred_id_len;
  uint8_t  pk_x[32];
  uint8_t  pk_y[32];
  bool     has_cred;
};

/* Parse the binary authenticatorData structure. */
static bool parse_auth_data(const uint8_t* d, size_t len, wa_auth_data* out) {
  if (len < 37) return false;
  memcpy(out->rp_id_hash, d, 32);
  out->flags = d[32];
  out->sign_count = ((uint32_t)d[33] << 24) | ((uint32_t)d[34] << 16) |
                    ((uint32_t)d[35] << 8) | d[36];
  out->has_cred = (out->flags & 0x40) != 0;
  out->cred_id_len = 0;
  if (out->has_cred) {
    if (len < 37 + 18) return false;          /* aaguid(16) + credIdLen(2) */
    size_t pos = 37 + 16;                      /* skip aaguid */
    uint16_t cid_len = ((uint16_t)d[pos] << 8) | d[pos + 1];
    pos += 2;
    if (len < pos + cid_len || cid_len > sizeof(out->cred_id)) return false;
    memcpy(out->cred_id, d + pos, cid_len);
    out->cred_id_len = cid_len;
    pos += cid_len;
    if (!parse_cose_ec2(d + pos, len - pos, out->pk_x, out->pk_y))
      return false;
  }
  return true;
}

/* ---------- Minimal JSON field extractor ---------- */

/* Extract a JSON string value for key from a compact JSON object.
 * Works for browser-generated clientDataJSON which is compact and ASCII. */
static bool json_get_str(const char* json, const char* key,
                          char* out, size_t out_len) {
  char needle[128];
  snprintf(needle, sizeof(needle), "\"%s\":\"", key);
  const char* p = strstr(json, needle);
  if (!p) return false;
  p += strlen(needle);
  size_t i = 0;
  while (*p && *p != '"' && i < out_len - 1) {
    if (*p == '\\') { p++; if (!*p) break; }
    out[i++] = *p++;
  }
  out[i] = '\0';
  return *p == '"';
}

/* ---------- ECDSA P-256 verification ---------- */

/* Verify a DER-encoded ECDSA-P256 signature over data using public key (x,y).
 * Internally hashes data with SHA-256 before verifying. */
static bool verify_ecdsa_p256(const uint8_t* pk_x, const uint8_t* pk_y,
			      const uint8_t* data, size_t data_len,
			      const uint8_t* sig, size_t sig_len) {
#ifdef HAVE_OPENSSL_CORE_NAMES_H
  /* OpenSSL 3 or later */
  bool ok = false;
  EVP_PKEY* pkey = NULL;
  EVP_PKEY_CTX* ctx = NULL;
  OSSL_PARAM_BLD* param_bld = OSSL_PARAM_BLD_new();
  OSSL_PARAM* params = NULL;

  // ui public key parameters (P-256)
  OSSL_PARAM_BLD_push_utf8_string(param_bld, OSSL_PKEY_PARAM_GROUP_NAME, "prime256v1", 0);
  OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_EC_PUB_X, BN_bin2bn(pk_x, 32, NULL));
  OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_EC_PUB_Y, BN_bin2bn(pk_y, 32, NULL));

  params = OSSL_PARAM_BLD_to_param(param_bld);
  ctx = EVP_PKEY_CTX_new_from_name(NULL, "EC", NULL);

  if (!ctx || EVP_PKEY_fromdata_init(ctx) <= 0 ||
      EVP_PKEY_fromdata(ctx, &pkey, EVP_PKEY_PUBLIC_KEY, params) <= 0) {
    goto cleanup;
  }

  // Check signature
  {
    EVP_MD_CTX* mctx = EVP_MD_CTX_new();
    
    if (EVP_DigestVerifyInit(mctx, NULL, EVP_sha256(), NULL, pkey) > 0) {
      ok = (EVP_DigestVerify(mctx, sig, sig_len, data, data_len) == 1);
    }
    
    EVP_MD_CTX_free(mctx);
  }

 cleanup:
  OSSL_PARAM_BLD_free(param_bld);
  OSSL_PARAM_free(params);
  EVP_PKEY_free(pkey);
  EVP_PKEY_CTX_free(ctx);

  return ok;
#else
  bool ok = false;
  EC_KEY* key = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);
  if (!key) return false;

  BIGNUM* bx = BN_bin2bn(pk_x, 32, NULL);
  BIGNUM* by = BN_bin2bn(pk_y, 32, NULL);
  if (!bx || !by) goto done;
  if (!EC_KEY_set_public_key_affine_coordinates(key, bx, by)) goto done;

  {
    uint8_t hash[32];
    SHA256(data, data_len, hash);
    ok = (ECDSA_verify(0, hash, (int)sizeof(hash), sig, sig_len, key) == 1);
  }
 done:
  if (bx) BN_free(bx);
  if (by) BN_free(by);
  EC_KEY_free(key);

  return ok;
#endif
}
			      

/* ---------- Ntop WebAuthn method implementations ---------- */

bool Ntop::generateWebAuthnChallenge(char* challenge_b64, size_t len) const {
  uint8_t raw[32];
  if (RAND_bytes(raw, sizeof(raw)) != 1) return false;
  std::string enc = webauthn_b64url_encode(raw, sizeof(raw));
  strncpy(challenge_b64, enc.c_str(), len - 1);
  challenge_b64[len - 1] = '\0';
  return true;
}

/* ---------------------------------------- */

bool Ntop::createWebAuthnPendingToken(const char* username, const char* referer,
                                       char* token, size_t token_len,
                                       char* challenge_b64,
                                       size_t challenge_len) const {
  if (!generateWebAuthnChallenge(challenge_b64, challenge_len)) return false;

  char rand_str[64], tmp_token[33];
  srand((int)time(0) ^ (int)getpid());
  snprintf(rand_str, sizeof(rand_str), "%d%s", rand(), username);
  mg_md5(tmp_token, rand_str, NULL);
  strncpy(token, tmp_token, token_len - 1);
  token[token_len - 1] = '\0';

  char key[128], val[768];
  snprintf(key, sizeof(key), "%s.%s", WEBAUTHN_PENDING_PREFIX, token);
  snprintf(val, sizeof(val), "%s|%s|%s", username,
           referer ? referer : "/", challenge_b64);
  return (ntop->getRedis()->set(key, val, WEBAUTHN_PENDING_TTL) >= 0);
}

/* ---------------------------------------- */

bool Ntop::getWebAuthnPendingToken(const char* token, char* username,
                                    size_t username_len, char* referer,
                                    size_t referer_len, char* challenge_b64,
                                    size_t challenge_len) const {
  char key[128], val[768];
  snprintf(key, sizeof(key), "%s.%s", WEBAUTHN_PENDING_PREFIX, token);
  if (ntop->getRedis()->get(key, val, sizeof(val)) < 0) return false;

  /* val = "username|referer|challenge" */
  char* p1 = strchr(val, '|');
  if (!p1) return false;
  *p1 = '\0';
  char* p2 = strchr(p1 + 1, '|');
  if (!p2) return false;
  *p2 = '\0';

  strncpy(username, val, username_len - 1);
  username[username_len - 1] = '\0';
  strncpy(referer, p1 + 1, referer_len - 1);
  referer[referer_len - 1] = '\0';
  strncpy(challenge_b64, p2 + 1, challenge_len - 1);
  challenge_b64[challenge_len - 1] = '\0';
  return true;
}

/* ---------------------------------------- */

void Ntop::deleteWebAuthnPendingToken(const char* token) const {
  char key[128];
  snprintf(key, sizeof(key), "%s.%s", WEBAUTHN_PENDING_PREFIX, token);
  ntop->getRedis()->del(key);
}

/* ---------------------------------------- */

bool Ntop::isWebAuthnEnabled(const char* username) const {
  return (getWebAuthnCredentialCount(username) > 0);
}

/* ---------------------------------------- */

int Ntop::getWebAuthnCredentialCount(const char* username) const {
  char key[CONST_MAX_LEN_REDIS_KEY], val[16];
  snprintf(key, sizeof(key), CONST_STR_USER_WEBAUTHN_CRED_COUNT, username);
  if (ntop->getRedis()->get(key, val, sizeof(val)) < 0) return 0;
  int n = atoi(val);
  return (n > 0 && n <= WEBAUTHN_MAX_CREDS) ? n : 0;
}

/* Credential storage format (pipe-separated):
 *   <cred_id_b64url>|<pk_x_hex>|<pk_y_hex>|<sign_count>|<name> */

static void webauthn_bytes_to_hex(const uint8_t* b, size_t len, char* hex) {
  for (size_t i = 0; i < len; i++)
    snprintf(hex + i * 2, 3, "%02x", b[i]);
}

static bool webauthn_hex_to_bytes(const char* hex, uint8_t* out, size_t out_len) {
  size_t hlen = strlen(hex);
  if (hlen != out_len * 2) return false;
  for (size_t i = 0; i < out_len; i++) {
    char byte_str[3] = { hex[i*2], hex[i*2+1], '\0' };
    char* end;
    out[i] = (uint8_t)strtoul(byte_str, &end, 16);
    if (end != byte_str + 2) return false;
  }
  return true;
}

bool Ntop::getWebAuthnCredential(const char* username, int idx,
                                   char* cred_id_b64, size_t cred_id_len,
                                   uint8_t* pk_x, uint8_t* pk_y,
                                   uint32_t* sign_count,
                                   char* name, size_t name_len) const {
  char key[CONST_MAX_LEN_REDIS_KEY], val[1024];
  snprintf(key, sizeof(key), CONST_STR_USER_WEBAUTHN_CRED, username, idx);
  if (ntop->getRedis()->get(key, val, sizeof(val)) < 0) return false;

  /* Parse: cred_id|pk_x_hex|pk_y_hex|sign_count|name */
  char* fields[5];
  char* p = val;
  for (int f = 0; f < 5; f++) {
    fields[f] = p;
    if (f < 4) {
      char* sep = strchr(p, '|');
      if (!sep) return false;
      *sep = '\0';
      p = sep + 1;
    }
  }
  strncpy(cred_id_b64, fields[0], cred_id_len - 1);
  cred_id_b64[cred_id_len - 1] = '\0';
  if (!webauthn_hex_to_bytes(fields[1], pk_x, 32)) return false;
  if (!webauthn_hex_to_bytes(fields[2], pk_y, 32)) return false;
  *sign_count = (uint32_t)strtoul(fields[3], NULL, 10);
  strncpy(name, fields[4], name_len - 1);
  name[name_len - 1] = '\0';
  return true;
}

/* ---------------------------------------- */

bool Ntop::storeWebAuthnCredential(const char* username,
                                     const char* cred_id_b64,
                                     const uint8_t* pk_x, const uint8_t* pk_y,
                                     uint32_t sign_count,
                                     const char* name) const {
  int n = getWebAuthnCredentialCount(username);
  if (n >= WEBAUTHN_MAX_CREDS) return false; /* Limit reached */

  char x_hex[65], y_hex[65];
  webauthn_bytes_to_hex(pk_x, 32, x_hex);
  webauthn_bytes_to_hex(pk_y, 32, y_hex);

  char key[CONST_MAX_LEN_REDIS_KEY], val[1024];
  snprintf(key, sizeof(key), CONST_STR_USER_WEBAUTHN_CRED, username, n);
  snprintf(val, sizeof(val), "%s|%s|%s|%u|%s",
           cred_id_b64, x_hex, y_hex, sign_count, name ? name : "Passkey");
  if (ntop->getRedis()->set(key, val, 0) < 0) return false;

  char cnt_key[CONST_MAX_LEN_REDIS_KEY], cnt_val[16];
  snprintf(cnt_key, sizeof(cnt_key), CONST_STR_USER_WEBAUTHN_CRED_COUNT, username);
  snprintf(cnt_val, sizeof(cnt_val), "%d", n + 1);
  return (ntop->getRedis()->set(cnt_key, cnt_val, 0) >= 0);
}

/* ---------------------------------------- */

bool Ntop::deleteWebAuthnCredential(const char* username,
                                     const char* cred_id_b64) const {
  int n = getWebAuthnCredentialCount(username);
  int found = -1;
  for (int i = 0; i < n; i++) {
    char id[512]; uint8_t x[32], y[32]; uint32_t sc; char nm[64];
    if (getWebAuthnCredential(username, i, id, sizeof(id), x, y, &sc,
                              nm, sizeof(nm)) &&
        strcmp(id, cred_id_b64) == 0) {
      found = i;
      break;
    }
  }
  if (found < 0) return false;

  char key[CONST_MAX_LEN_REDIS_KEY];

  /* Swap with last entry if not already the last */
  if (found < n - 1) {
    char last_val[1024];
    snprintf(key, sizeof(key), CONST_STR_USER_WEBAUTHN_CRED, username, n - 1);
    if (ntop->getRedis()->get(key, last_val, sizeof(last_val)) < 0) return false;
    char found_key[CONST_MAX_LEN_REDIS_KEY];
    snprintf(found_key, sizeof(found_key), CONST_STR_USER_WEBAUTHN_CRED, username, found);
    ntop->getRedis()->set(found_key, last_val, 0);
  }

  /* Delete the last slot */
  snprintf(key, sizeof(key), CONST_STR_USER_WEBAUTHN_CRED, username, n - 1);
  ntop->getRedis()->del(key);

  /* Update count */
  char cnt_key[CONST_MAX_LEN_REDIS_KEY], cnt_val[16];
  snprintf(cnt_key, sizeof(cnt_key), CONST_STR_USER_WEBAUTHN_CRED_COUNT, username);
  snprintf(cnt_val, sizeof(cnt_val), "%d", n - 1);
  ntop->getRedis()->set(cnt_key, cnt_val, 0);
  return true;
}

/* ---------------------------------------- */

bool Ntop::getWebAuthnCredentialsJSON(const char* username,
                                       char* json_out, size_t len) const {
  int n = getWebAuthnCredentialCount(username);
  std::string out = "[";
  for (int i = 0; i < n; i++) {
    char id[512]; uint8_t x[32], y[32]; uint32_t sc; char nm[64];
    if (!getWebAuthnCredential(username, i, id, sizeof(id), x, y, &sc,
                               nm, sizeof(nm)))
      continue;
    if (out.size() > 1) out += ",";
    char entry[768];
    snprintf(entry, sizeof(entry),
             "{\"id\":\"%s\",\"name\":\"%s\",\"sign_count\":%u}", id, nm, sc);
    out += entry;
  }
  out += "]";
  strncpy(json_out, out.c_str(), len - 1);
  json_out[len - 1] = '\0';
  return true;
}

/* ---------------------------------------- */

bool Ntop::verifyWebAuthnAssertion(const char* username,
                                    const char* cred_id_b64url,
                                    const char* client_data_json_b64url,
                                    const char* auth_data_b64url,
                                    const char* signature_b64url,
                                    const char* expected_challenge_b64url,
                                    const char* expected_origin,
                                    const char* rp_id) const {
  /* 1. Decode base64url inputs */
  uint8_t cdj_raw[8192]; int cdj_len;
  uint8_t ad_raw[1024];  int ad_len;
  uint8_t sig_raw[512];  int sig_len;

  cdj_len = webauthn_b64url_decode(client_data_json_b64url, cdj_raw,
                                    (int)sizeof(cdj_raw) - 1);
  ad_len  = webauthn_b64url_decode(auth_data_b64url, ad_raw, (int)sizeof(ad_raw));
  sig_len = webauthn_b64url_decode(signature_b64url, sig_raw, (int)sizeof(sig_raw));
  if (cdj_len <= 0 || ad_len <= 0 || sig_len <= 0) return false;
  cdj_raw[cdj_len] = '\0'; /* null-terminate for JSON parsing */

  /* 2. Parse clientDataJSON */
  char type_val[64], challenge_val[256], origin_val[256];
  if (!json_get_str((char*)cdj_raw, "type",      type_val,      sizeof(type_val)))      return false;
  if (!json_get_str((char*)cdj_raw, "challenge", challenge_val, sizeof(challenge_val))) return false;
  if (!json_get_str((char*)cdj_raw, "origin",    origin_val,    sizeof(origin_val)))    return false;

  if (strcmp(type_val, "webauthn.get") != 0) return false;

  /* Compare challenges: decode both and compare bytes */
  uint8_t ch_got[256], ch_exp[256];
  int ch_got_len = webauthn_b64url_decode(challenge_val, ch_got, (int)sizeof(ch_got));
  int ch_exp_len = webauthn_b64url_decode(expected_challenge_b64url, ch_exp, (int)sizeof(ch_exp));
  if (ch_got_len <= 0 || ch_exp_len <= 0 || ch_got_len != ch_exp_len) return false;
  if (memcmp(ch_got, ch_exp, ch_got_len) != 0) return false;

  /* Compare origins */
  if (strcmp(origin_val, expected_origin) != 0) return false;

  /* 3. Verify rpIdHash */
  uint8_t rp_hash[32];
  SHA256((const uint8_t*)rp_id, strlen(rp_id), rp_hash);
  if (ad_len < 37 || memcmp(ad_raw, rp_hash, 32) != 0) return false;

  /* 4. Check UP (User Present) flag */
  if (!(ad_raw[32] & 0x01)) return false;

  /* 5. Extract signCount from authData */
  uint32_t sign_count = ((uint32_t)ad_raw[33] << 24) | ((uint32_t)ad_raw[34] << 16) |
                        ((uint32_t)ad_raw[35] << 8) | ad_raw[36];

  /* 6. Find the credential by ID, saving pk and name for later */
  int n = getWebAuthnCredentialCount(username);
  uint8_t pk_x[32], pk_y[32];
  uint32_t stored_sc = 0;
  char found_name[64] = "Passkey";
  bool found = false;
  int found_idx = -1;
  for (int i = 0; i < n && !found; i++) {
    char id[512]; uint8_t x[32], y[32]; uint32_t sc; char nm[64];
    if (getWebAuthnCredential(username, i, id, sizeof(id), x, y, &sc,
                              nm, sizeof(nm)) &&
        strcmp(id, cred_id_b64url) == 0) {
      memcpy(pk_x, x, 32); memcpy(pk_y, y, 32);
      stored_sc = sc;
      found_idx = i;
      strncpy(found_name, nm, sizeof(found_name) - 1);
      found_name[sizeof(found_name) - 1] = '\0';
      found = true;
    }
  }
  if (!found) return false;

  /* Sign count check: reject if stored > 0 and new <= stored (replay) */
  if (stored_sc > 0 && sign_count <= stored_sc) return false;

  /* 7. Verify ECDSA signature: msg = authData || SHA256(clientDataJSON) */
  uint8_t cdj_hash[32];
  SHA256(cdj_raw, (size_t)cdj_len, cdj_hash);

  std::vector<uint8_t> msg((size_t)ad_len + 32);
  memcpy(msg.data(), ad_raw, (size_t)ad_len);
  memcpy(msg.data() + ad_len, cdj_hash, 32);

  if (!verify_ecdsa_p256(pk_x, pk_y, msg.data(), msg.size(), sig_raw, sig_len))
    return false;

  /* 8. Update signCount in Redis using the saved name */
  char key[CONST_MAX_LEN_REDIS_KEY], val[1024];
  char x_hex[65], y_hex[65];
  webauthn_bytes_to_hex(pk_x, 32, x_hex);
  webauthn_bytes_to_hex(pk_y, 32, y_hex);
  snprintf(key, sizeof(key), CONST_STR_USER_WEBAUTHN_CRED, username, found_idx);
  snprintf(val, sizeof(val), "%s|%s|%s|%u|%s",
           cred_id_b64url, x_hex, y_hex, sign_count, found_name);
  ntop->getRedis()->set(key, val, 0);

  return true;
}

/* ---------------------------------------- */

bool Ntop::verifyAndStoreWebAuthnRegistration(
    const char* username, const char* cred_name,
    const char* cred_id_b64url, const char* client_data_json_b64url,
    const char* attestation_obj_b64url, const char* expected_challenge_b64url,
    const char* expected_origin, const char* rp_id) const {

  /* 1. Decode inputs */
  uint8_t cdj_raw[8192]; int cdj_len;
  uint8_t ao_raw[8192];  int ao_len;

  cdj_len = webauthn_b64url_decode(client_data_json_b64url, cdj_raw,
                                    (int)sizeof(cdj_raw) - 1);
  ao_len  = webauthn_b64url_decode(attestation_obj_b64url, ao_raw,
                                    (int)sizeof(ao_raw));
  if (cdj_len <= 0 || ao_len <= 0) return false;
  cdj_raw[cdj_len] = '\0';

  /* 2. Verify clientDataJSON */
  char type_val[64], challenge_val[256], origin_val[256];
  if (!json_get_str((char*)cdj_raw, "type",      type_val,      sizeof(type_val)))      return false;
  if (!json_get_str((char*)cdj_raw, "challenge", challenge_val, sizeof(challenge_val))) return false;
  if (!json_get_str((char*)cdj_raw, "origin",    origin_val,    sizeof(origin_val)))    return false;
  if (strcmp(type_val, "webauthn.create") != 0) return false;

  uint8_t ch_got[256], ch_exp[256];
  int ch_got_len = webauthn_b64url_decode(challenge_val, ch_got, (int)sizeof(ch_got));
  int ch_exp_len = webauthn_b64url_decode(expected_challenge_b64url, ch_exp, (int)sizeof(ch_exp));
  if (ch_got_len <= 0 || ch_exp_len <= 0 || ch_got_len != ch_exp_len) return false;
  if (memcmp(ch_got, ch_exp, ch_got_len) != 0) return false;
  if (strcmp(origin_val, expected_origin) != 0) return false;

  /* 3. Extract authData from attestationObject */
  const uint8_t* auth_data;
  size_t auth_data_len;
  if (!extract_auth_data(ao_raw, (size_t)ao_len, &auth_data, &auth_data_len))
    return false;

  /* 4. Parse authenticatorData */
  wa_auth_data ad;
  if (!parse_auth_data(auth_data, auth_data_len, &ad)) return false;
  if (!ad.has_cred) return false;

  /* 5. Verify rpIdHash */
  uint8_t rp_hash[32];
  SHA256((const uint8_t*)rp_id, strlen(rp_id), rp_hash);
  if (memcmp(ad.rp_id_hash, rp_hash, 32) != 0) return false;

  /* 6. Check UP flag */
  if (!(ad.flags & 0x01)) return false;

  /* 7. Store the credential (cred_id comes from the client as b64url) */
  return storeWebAuthnCredential(username, cred_id_b64url,
                                 ad.pk_x, ad.pk_y, ad.sign_count,
                                 cred_name && cred_name[0] ? cred_name : "Passkey");
}

/* ******************************************* */

bool Ntop::isCaptivePortalUser(const char* username) {
  char key[64], val[64];

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);

  if ((ntop->getRedis()->get(key, val, sizeof(val)) >= 0) &&
      (!strcmp(val, CONST_USER_GROUP_CAPTIVE_PORTAL))) {
    return (true);
  }

  return (false);
}

/* ******************************************* */

bool Ntop::deleteUser(char* username) {
  char user_id_buf[8];
  char key[64];

  users_m.lock(__FILE__, __LINE__);

  if (!existsUser(username)) {
    users_m.unlock(__FILE__, __LINE__);
    return (false);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_ID, username);

  /* Dispose the currently assigned user id so that it can be recycled */
  if ((ntop->getRedis()->get(key, user_id_buf, sizeof(user_id_buf)) >= 0)) {
    ntop->getRedis()->srem(PREF_NTOP_USER_IDS, user_id_buf);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_FULL_NAME, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_ID, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_LANGUAGE, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_PCAP, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_HOST_POOL_ID, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_THEME, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_DATE_FORMAT, username);
  ntop->getRedis()->del(key);

  /*
     Delete the API Token, first from the hash of all tokens,
     then from the user
  */
  char api_token[NTOP_SESSION_ID_LENGTH];
  if (getUserAPIToken(username, api_token, sizeof(api_token))) {
    ntop->getRedis()->hashDel(NTOPNG_API_TOKEN_PREFIX, api_token);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_API_TOKEN, username);
  ntop->getRedis()->del(key);

  users_m.unlock(__FILE__, __LINE__);

  return true;
}

/* ******************************************* */

bool Ntop::getUserHostPool(char* username, u_int16_t* host_pool_id) {
  char key[64], val[64];

  snprintf(key, sizeof(key), CONST_STR_USER_HOST_POOL_ID,
           username ? username : "");
  if (ntop->getRedis()->get(key, val, sizeof(val)) >= 0) {
    if (host_pool_id) *host_pool_id = atoi(val);
    return true;
  }

  if (host_pool_id) *host_pool_id = NO_HOST_POOL_ID;
  return false;
}

/* ******************************************* */

bool Ntop::getUserAllowedIfname(const char* username, char* buf,
                                size_t buflen) const {
  char key[64];

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME,
           username ? username : "");

  if (ntop->getRedis()->get(key, buf, buflen) >= 0) return true;

  return false;
}

/* ******************************************* */

bool Ntop::getUserAPIToken(const char* username, char* buf,
                           size_t buflen) const {
  char key[CONST_MAX_LEN_REDIS_KEY];

  snprintf(key, sizeof(key), CONST_STR_USER_API_TOKEN, username);

  if (ntop->getRedis()->get(key, buf, buflen) >= 0) return true;

  return false;
}

/* ******************************************* */

void Ntop::fixPath(char* str, bool replaceDots) {
  for (int i = 0; str[i] != '\0'; i++) {
#ifdef WIN32
    /*
      Allowed windows path and file characters:
      https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx#win32_file_namespaces
    */
    if (str[i] == '/')
      str[i] = '\\';
    else if (str[i] == '\\')
      continue;
    else if ((i == 1) && (str[i] == ':'))  // c:\\...
      continue;
    else if (str[i] == ':' || str[i] == '"' || str[i] == '|' || str[i] == '?' ||
             str[i] == '*')
      str[i] = '_';
#endif

    if (replaceDots) {
      if ((i > 0) && (str[i] == '.') && (str[i - 1] == '.')) {
        // ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid path detected
        // %s", str);
        str[i - 1] = '_', str[i] = '_'; /* Invalidate the path */
      }
    }
  }
}

/* ******************************************* */

char* Ntop::getValidPath(char* __path) {
  char _path[MAX_PATH + 8];
  struct stat buf;

#ifdef WIN32
  const char* install_dir = (const char*)get_install_dir();
#endif
  bool has_drive_colon = 0;

  if (strncmp(__path, "./", 2) == 0) {
    snprintf(_path, sizeof(_path), "%s/%s", startup_dir, &__path[2]);
    fixPath(_path);

    if (stat(_path, &buf) == 0) {
      free(__path);
      return (strdup(_path));
    }
  }

#ifdef WIN32
  has_drive_colon =
      (isalpha((int)__path[0]) &&
       (__path[1] == ':' && (__path[2] == '\\' || __path[2] == '/')));
#endif

  if ((__path[0] == '/') || (__path[0] == '\\') || has_drive_colon) {
    /* Absolute paths */

    if (stat(__path, &buf) == 0) {
      return (__path);
    }
  } else
    snprintf(_path, MAX_PATH, "%s", __path);

  /* relative paths */
  for (int i = 0; i < (int)COUNT_OF(dirs); i++) {
    if (dirs[i]
        /*
           Ignore / as when you start ntopng as a
           service you might have /scripts or /httpdocs
           on your filesystem fooling ntopng
           initialization and thus breaking averything
        */
        && strcmp(dirs[i], "/")) {
      char path[2 * MAX_PATH];

      snprintf(path, sizeof(path), "%s/%s", dirs[i], _path);
      fixPath(path);

      if (stat(path, &buf) == 0) {
        free(__path);
        return (strdup(path));
      }
    }
  }

  free(__path);
  return (strdup(""));
}

/* ******************************************* */

void Ntop::daemonize() {
#ifndef WIN32
  int childpid;

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
                               "Parent process is exiting (this is normal)");

  signal(SIGPIPE, SIG_IGN);
  signal(SIGHUP, SIG_IGN);
  /*
    IMPORTANT

    SIGCHLD should NOT be masked as otherwise
    with popen()/pclose() we receive an error
    when closing the pipe on FreeBSD

    signal(SIGCHLD, SIG_IGN);
  */
  signal(SIGQUIT, SIG_IGN);

  if ((childpid = fork()) < 0)
    ntop->getTrace()->traceEvent(
        TRACE_ERROR, "Occurred while daemonizing (errno=%d)", errno);
  else {
    if (!childpid) {
      /* child */
      int rc;

      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Bye bye: I'm becoming a
      // daemon...");
      rc = chdir("/");
      if (rc != 0)
        ntop->getTrace()->traceEvent(TRACE_ERROR,
                                     "Error while moving to / directory");

      setsid(); /* detach from the terminal */

      fclose(stdin);
      fclose(stdout);
      /* fclose(stderr); */

      /*
       * clear any inherited file mode creation mask
       */
      // umask(0);

      /*
       * Use line buffered stdout
       */
      /* setlinebuf (stdout); */
      setvbuf(stdout, (char*)NULL, _IOLBF, 0);
    } else /* father */
      exit(0);
  }
#endif
}

/* ******************************************* */

void Ntop::setLocalNetworks(char* _nets) {
  char* nets;
  u_int len;

  if (_nets == NULL) return;

  len = (u_int)strlen(_nets);

  if ((len > 2) && (_nets[0] == '"') && (_nets[len - 1] == '"')) {
    nets = strdup(&_nets[1]);
    nets[len - 2] = '\0';
  } else
    nets = strdup(_nets);

  addLocalNetworkList(nets);
  free(nets);
};

/* ******************************************* */

NetworkInterface* Ntop::getInterfaceById(int if_id) {
  if (if_id == SYSTEM_INTERFACE_ID) return (system_interface);

  for (int i = 0; i < num_defined_interfaces; i++) {
    if (!iface[i]->isEnabled()) continue;
    if (iface[i] && iface[i]->get_id() == if_id) return (iface[i]);
  }

  return (NULL);
}

/* ******************************************* */

bool Ntop::isExistingInterface(const char* name) const {
  if (name == NULL) return (false);

  for (int i = 0; i < num_defined_interfaces; i++) {
    if (!iface[i]->isEnabled()) continue;
    if (!strcmp(iface[i]->get_name(), name)) return (true);
  }

  if (!strcmp(name, getSystemInterface()->get_name())) return (true);

  return (false);
}

/* ******************************************* */

NetworkInterface* Ntop::getNetworkInterface(const char* name, lua_State* vm) {
  char allowed_ifname[MAX_INTERFACE_NAME_LEN] = {0};
  char* bad_num = NULL;
  int if_id;

  if (vm && getInterfaceAllowed(vm, allowed_ifname)) {
    ntop->getTrace()->traceEvent(
        TRACE_DEBUG, "Forcing allowed interface. [requested: %s][selected: %s]",
        name, allowed_ifname);
    return getNetworkInterface(allowed_ifname);
  }

  if (name == NULL) return (NULL);

  /* This method accepts both interface names or Ids.
   * Due to bad Lua number formatting, a float number may be received. */
  if_id = strtof(name, &bad_num);

  if ((if_id == SYSTEM_INTERFACE_ID) || !strcmp(name, SYSTEM_INTERFACE_NAME))
    return (getSystemInterface());

  if ((bad_num == NULL) || (*bad_num == '\0')) {
    /* name is a number */
    return (getInterfaceById(if_id));
  }

  /* if here, name is a string */
  for (int i = 0; i < num_defined_interfaces; i++) {
    if (!iface[i]->isEnabled()) continue;
    if (!strcmp(name, iface[i]->get_name())) {
      NetworkInterface* ret_iface =
          isInterfaceAllowed(vm, iface[i]->get_name()) ? iface[i] : NULL;

      if (ret_iface) return (ret_iface);
    }
  }

  return (NULL);
};

/* ******************************************* */

int Ntop::getInterfaceIdByName(lua_State* vm, const char* name) {
  NetworkInterface* res = getNetworkInterface(name, vm);

  if (res) return res->get_id();

  return (-1);
}

/* ****************************************** */

/* NOTE: the interface is deleted when this method returns false */
bool Ntop::registerInterface(NetworkInterface* _if) {
  bool rv = true;

  /* Needed as can be called concurrently by
   * NetworkInterface::registerSubInterface */
  m.lock(__FILE__, __LINE__);

  for (int i = 0; i < num_defined_interfaces; i++) {
    if (strcmp(iface[i]->get_name(), _if->get_name()) == 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Skipping duplicated interface %s",
                                   _if->get_description());

      rv = false;
      goto out;
    }
  }

  if (num_defined_interfaces < MAX_NUM_DEFINED_INTERFACES) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                 "Registered interface '%s' [id: %d]",
                                 _if->get_description(), _if->get_id());
    iface[num_defined_interfaces++] = _if;

    rv = true;
    goto out;
  } else {
    static bool too_many_interfaces_error = false;
    if (!too_many_interfaces_error) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many interfaces defined");
      too_many_interfaces_error = true;
    }

    rv = false;
    goto out;
  }

out:
  if (!rv) delete _if;

  m.unlock(__FILE__, __LINE__);

  return (rv);
};

/* ******************************************* */

void Ntop::initInterface(NetworkInterface* _if, bool disable_dump) {
  /* Initialization related to flow-dump */
  if ((ntop->getPrefs()->do_dump_flows()
#ifdef HAVE_ZMQ
#ifndef HAVE_NEDGE
       || ntop->get_export_interface()
#endif
#endif
           ) &&
      !disable_dump) {
    _if->initFlowDump();
  }

  /* Other initialization activities */
  _if->initFlowChecksLoop();
  _if->initHostChecksLoop();
  _if->checkDisaggregationMode();
}

/* *************************************** */

void Ntop::addToPool(char* host_or_mac, u_int16_t user_pool_id) {
  char key[128], pool_buf[16];

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_INFO,
                               "Adding %s as host pool member [pool id: %i]",
                               host_or_mac, user_pool_id);
#endif

  snprintf(pool_buf, sizeof(pool_buf), "%u", user_pool_id);
  snprintf(key, sizeof(key), HOST_POOL_MEMBERS_KEY, pool_buf);
  ntop->getRedis()->sadd(key, host_or_mac); /* New member added */

  reloadHostPools();
}

/* ******************************************* */

void Ntop::checkReloadHostPools() {
  if (hostPoolsReloadInProgress /* Check if a reload has been requested */) {
    /* Leave this BEFORE the actual swap and new allocation to guarantee changes
     * are always seen */
    hostPoolsReloadInProgress = false;

    for (int i = 0; i < get_num_interfaces(); i++) {
      NetworkInterface* iface;

      if ((iface = ntop->getInterface(i)) != NULL) iface->reloadHostPools();
    }
  }
}

/* ******************************************* */

u_int16_t Ntop::getNumberHostPools() {
  u_int16_t pools_number = 0;
  for (int i = 0; i < get_num_interfaces(); i++) {
    NetworkInterface* iface;

    if ((iface = ntop->getInterface(i)) != NULL) {
      pools_number = pools_number + iface->getNumberHostPools();
      break;
    }
  }
  return pools_number;
}

/* ******************************************* */

u_int32_t Ntop::getNumberHostPoolsMembers() {
  hostPoolsReloadInProgress = false;
  u_int32_t max_members_number = 0;

  for (int i = 0; i < get_num_interfaces(); i++) {
    NetworkInterface* iface;
    u_int32_t pool_member_number = 0;

    if ((iface = ntop->getInterface(i)) != NULL)
      pool_member_number = iface->getNumberHostPoolsMembers();

    if (pool_member_number > max_members_number)
      max_members_number = pool_member_number;
  }
  return max_members_number;
}

/* ******************************************* */

u_int8_t Ntop::getNumberProfiles() {
  u_int8_t num_profiles = 0;
#ifdef NTOPNG_PRO
#ifndef HAVE_NEDGE
#ifdef HAVE_NBPF
  for (int i = 0; i < get_num_interfaces(); i++) {
    NetworkInterface* iface;

    if ((iface = ntop->getInterface(i)) != NULL)
      num_profiles = iface->getNumProfiles();
  }
#endif
#endif
#endif

  return num_profiles;
}

/* ******************************************* */

void Ntop::checkReloadAlertExclusions() {
#ifdef NTOPNG_PRO
  if (alert_exclusions_shadow) { /* Dispose old memory if necessary */
    delete alert_exclusions_shadow;
    alert_exclusions_shadow = NULL;
  }

  if (alertExclusionsReloadInProgress /* Check if a reload has been requested */
      || !alert_exclusions /* Control groups are not allocated */) {
    alertExclusionsReloadInProgress =
        false; /* Leave this BEFORE the actual swap and new allocation to
                  guarantee changes are always seen */

    alert_exclusions_shadow = alert_exclusions; /* Save the existing instance */
    alert_exclusions =
        new (std::nothrow) AlertExclusions(); /* Allocate a new instance */

    if (!alert_exclusions)
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Unable to allocate memory for control groups.");
  }
#endif
}

/* ******************************************* */

void Ntop::checkReloadFlowChecks() {
  if (!ntop->getPrefs()->is_pro_edition() /* Community mode */ &&
      flow_checks_loader &&
      flow_checks_loader->getChecksEdition() != ntopng_edition_community) {
    /* Force a reload when switching to community (demo mode) */
    reloadFlowChecks();
  }

  if(flowChecksReloadInProgress /* Reload requested from the UI upon configuration changes */) {
    FlowChecksLoader *old,
        *tmp_flow_checks_loader = new (std::nothrow) FlowChecksLoader();

    if (!tmp_flow_checks_loader) {
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Unable to allocate memory for flow checks.");
      return;
    }

    tmp_flow_checks_loader->initialize();
    old = flow_checks_loader;

    /* Pass the newly allocated loader to all interfaces so they will update
     * their checks */
    for (int i = 0; i < get_num_interfaces(); i++)
      iface[i]->reloadFlowChecks(tmp_flow_checks_loader);

    flow_checks_loader = tmp_flow_checks_loader;

    if (old) {
      sleep(2); /* Make sure nobody is using the old one */

      delete old;
    }

    flowChecksReloadInProgress = false;
  }
}

/* ******************************************* */

void Ntop::checkReloadHostChecks() {
  if (!ntop->getPrefs()->is_pro_edition() /* Community mode */ &&
      host_checks_loader &&
      host_checks_loader->getChecksEdition() != ntopng_edition_community) {
    /* Force a reload when switching to community (demo mode) */
    reloadHostChecks();
  }

  if(hostChecksReloadInProgress /* Reload requested from the UI upon configuration changes */) {
    HostChecksLoader *old,
        *tmp_host_checks_loader = new (std::nothrow) HostChecksLoader();

    if (!tmp_host_checks_loader) {
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Unable to allocate memory for host checks.");
      return;
    }

    tmp_host_checks_loader->initialize();
    old = host_checks_loader;

    /* Pass the newly allocated loader to all interfaces so they will update
     * their checks */
    for (int i = 0; i < get_num_interfaces(); i++)
      iface[i]->reloadHostChecks(tmp_host_checks_loader);

    host_checks_loader = tmp_host_checks_loader;

    if (old) {
      sleep(2); /* Make sure nobody is using the old one */

      delete old;
    }

    hostChecksReloadInProgress = false;
  }
}

/* ******************************************* */

void Ntop::registerThread(const char* name, pthread_t id) {
  Utils::setThreadName(name);

  ThreadInfo ti;
  ti.name = name;
  ti.last_cpu_ts.tv_sec = ti.last_cpu_ts.tv_nsec = 0;
  ti.last_elapsed_ts.tv_sec = ti.last_elapsed_ts.tv_nsec = 0;

  threads_info_m.lock(__FILE__, __LINE__);
  threads_info[id] = ti;
  threads_info_m.unlock(__FILE__, __LINE__);
}

/* ******************************************* */

void Ntop::lua_threadsInfo(lua_State* vm) {
#if defined(__linux__)
  std::map<pthread_t, ThreadInfo>::iterator it;
  struct timespec elapsed_now;

  clock_gettime(CLOCK_MONOTONIC, &elapsed_now);

  threads_info_m.lock(__FILE__, __LINE__);

  for (it = threads_info.begin(); it != threads_info.end(); ++it) {
    pthread_t tid = it->first;
    ThreadInfo& ti = it->second;
    clockid_t cpu_clock_id;

    if (pthread_getcpuclockid(tid, &cpu_clock_id) == 0) {
      struct timespec cpu_now;

      if (clock_gettime(cpu_clock_id, &cpu_now) == 0) {
        float utilization = 0;

        if (ti.last_elapsed_ts.tv_sec > 0 || ti.last_elapsed_ts.tv_nsec > 0) {
          int64_t delta_cpu_ns =
              ((int64_t)cpu_now.tv_sec - (int64_t)ti.last_cpu_ts.tv_sec) *
                  1000000000 +
              (cpu_now.tv_nsec - ti.last_cpu_ts.tv_nsec);
          int64_t delta_elapsed_ns =
              ((int64_t)elapsed_now.tv_sec -
               (int64_t)ti.last_elapsed_ts.tv_sec) *
                  1000000000 +
              (elapsed_now.tv_nsec - ti.last_elapsed_ts.tv_nsec);
          if (delta_elapsed_ns > 0)
            utilization = (float)delta_cpu_ns * 100 / (float)delta_elapsed_ns;
        }

        ti.last_cpu_ts = cpu_now;
        ti.last_elapsed_ts = elapsed_now;

        u_int64_t total_ms =
            (u_int64_t)cpu_now.tv_sec * 1000 + cpu_now.tv_nsec / 1000000;

        lua_pushstring(vm, ti.name.c_str());
        lua_gettable(vm, -2);

        if (lua_istable(vm, -1)) {
          /* If another thread with the same name was already added, sum it */
          lua_getfield(vm, -1, "cpu_utilization_pct");
          float existing_pct = (float)lua_tonumber(vm, -1);
          lua_pop(vm, 1);
          lua_pushnumber(vm, existing_pct + utilization);
          lua_setfield(vm, -2, "cpu_utilization_pct");

          lua_getfield(vm, -1, "cpu_total_ms");
          u_int64_t existing_ms = (u_int64_t)lua_tonumber(vm, -1);
          lua_pop(vm, 1);
          lua_pushnumber(vm, (lua_Number)(existing_ms + total_ms));
          lua_setfield(vm, -2, "cpu_total_ms");

          lua_pop(vm, 1);
        } else {
          lua_pop(vm, 1);

          lua_newtable(vm);
          lua_push_float_table_entry(vm, "cpu_utilization_pct", utilization);
          lua_push_uint64_table_entry(vm, "cpu_total_ms", total_ms);

          lua_pushstring(vm, ti.name.c_str());
          lua_insert(vm, -2);
          lua_settable(vm, -3);
        }
      }
    }
  }

  threads_info_m.unlock(__FILE__, __LINE__);
#endif
}

/* ******************************************* */

/* Execute lightweigth tasks with high frequency */
void Ntop::runHousekeepingTasks() {
  checkReloadHostPools();

#ifdef NTOPNG_PRO
  pro->runHousekeepingTasks();
#endif
}

/* ******************************************* */

/* Execute tasks periodically (5 sec freq)
 * NOTE: the multiple isShutdown checks below are necessary to reduce the
 * shutdown time */
void Ntop::runPeriodicHousekeepingTasks() {
  runHousekeepingTasks();

  checkReloadAlertExclusions();
  checkReloadFlowChecks();
  checkReloadHostChecks();

  for (int i = 0; i < get_num_interfaces(); i++) {
    if (!iface[i]->isStartingUp()) {
      iface[i]->runPeriodicHousekeepingTasks();
      iface[i]->purgeQueuedIdleEntries();
    }
  }

  jobsQueue.idleTask();
}

/* ******************************************* */

void Ntop::runShutdownTasks() {
  /* Final shut down tasks for all interfaces */
  for (int i = 0; i < num_defined_interfaces; i++) {
    if (!iface[i]->isView()) iface[i]->runShutdownTasks();
  }

  for (int i = 0; i < num_defined_interfaces; i++) {
    if (iface[i]->isView()) iface[i]->runShutdownTasks();
  }
}

/* ******************************************* */

/*
  Checks if all the activities are completed (e.g., all packets processed,
  notifications sent) and possibly sends a shutdown signal to terminate. NOTE:
  Only effective when ntopng is started with --shutdown-when-done. Without that
  options ntopng keeps running and doesn't terminate.
*/
void Ntop::checkShutdownWhenDone() {
  if (ntop->getPrefs()->shutdownWhenDone()) {
    for (int i = 0; i < get_num_interfaces(); i++) {
      NetworkInterface* iface = getInterface(i);

      /* Check all the interfaces reading from pcap files if they are done with
       * their activities. */
      if (iface->read_from_pcap_dump() && !iface->read_from_pcap_dump_done())
        /* iface isn't done yet */
        return;
    }

    /* Here all interface reading from pcap files are done. */

    if (!recipients_are_empty()) {
      /* Recipients are still processing notifications, wait until they're done.
       */
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                   "Waiting for pending notifications..");
      return;
    }

    /* When they are done, signal ntopng to shutdown */

    /* One extra housekeeping before executing tests (this assumes all flows
     * have been walked) */
    runPeriodicHousekeepingTasks();

    runShutdownTasks();

    /* Test Script (Runtime Analysis) */
    if (ntop->getPrefs()->get_test_runtime_script_path()) {
      const char* test_runtime_script_path =
          ntop->getPrefs()->get_test_runtime_script_path();

      /* Execute as Bash script */
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                   "> Running Runtime Script '%s'",
                                   test_runtime_script_path);
      sleep(10); /* Allow concurrent activities and flushing to complete before
                    running the test */
      Utils::exec(test_runtime_script_path);
    }

    /* Perform shutdown operations on all active interfaces - this also flushes
     * all active flows */
    ntop->shutdownInterfaces();

    /* Make sure all flushed flows are also dumped to the database for post
     * analysis (e.g. historical data) */

    /* Test Script (Post Analysis) */
    if (ntop->getPrefs()->get_test_post_script_path()) {
      const char* test_post_script_path =
          ntop->getPrefs()->get_test_post_script_path();

      sleep(1); /* Give some time to alerts to get dequeued */

      /* Execute as Bash script */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "> Running Post Script '%s'",
                                   test_post_script_path);
      Utils::exec(test_post_script_path);
    }

    ntop->getGlobals()->shutdown();
  }
}

/* ******************************************* */

void Ntop::shutdownPeriodicActivities() {
  if (pa) {
    while (pa->isRunning()) sleep(1);

    delete pa;
    pa = NULL;
  }
}

/* ******************************************* */

void Ntop::shutdownInterfaces() {
  /* First, shutdown all view interfaces so they can release counters from the
   * viewed interfaces */

  if (interfacesShuttedDown) return;

  for (int i = 0; i < num_defined_interfaces; i++) {
    if (iface[i]->isView()) {
      EthStats* stats = iface[i]->getStats();

      stats->print();
      iface[i]->shutdown();
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                   "Polling shut down [interface: %s]",
                                   iface[i]->get_description());
    }
  }

  /* Now, shutdown all other non-view interfaces */
  for (int i = 0; i < num_defined_interfaces; i++) {
    if (!iface[i]->isView()) {
      EthStats* stats = iface[i]->getStats();

      stats->print();
      iface[i]->shutdown();
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                   "Polling shut down [interface: %s]",
                                   iface[i]->get_description());
    }
  }

  interfacesShuttedDown = true;
}

/* ******************************************* */

void Ntop::shutdownAll() {
  ThreadedActivity* shutdown_activity;

  /* Wait until currently executing periodic activities are completed,
   * Periodic activites should not run during interfaces shutdown */
  ntop->shutdownPeriodicActivities();

  /* Perform shutdown operations on all active interfaces,
   * including purging all active flows, hosts, etc */
  ntop->shutdownInterfaces();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Executing shutdown script [%s]",
                               SHUTDOWN_SCRIPT_PATH);

  /* Exec shutdown script before shutting down ntopng */
  if ((shutdown_activity =
           new (std::nothrow) ThreadedActivity(SHUTDOWN_SCRIPT_PATH))) {
    /* Don't call run() as by the time the script will be run the delete below
     * will free the memory */
    shutdown_activity->runSystemScript(time(NULL));
    delete shutdown_activity;
  }

  /* Complete the shutdown */
  ntop->getGlobals()->shutdown();

#ifndef WIN32
  /*
    PID file cannot be deleted as it is under `/var/run` which, in turn, is a
    symlink to `/run`, which is not writable by user `ntopng`. As user `ntopng`
    has no write privileges on `/run`, the PID file cannot be deleted from
    inside this process. Deletion is performed as part of the ExecStopPost in
    the systemd ntopng.service file
  */
#if 0
  if(ntop->getPrefs()->get_pid_path() != NULL) {
    int rc = unlink(ntop->getPrefs()->get_pid_path());

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted PID %s: [rc: %d][%s]",
                                 ntop->getPrefs()->get_pid_path(),
                                 rc, strerror(errno));
  }
#endif
#endif

#ifdef HAVE_NEDGE
  for (auto it = multicastForwarders.begin(); it != multicastForwarders.end();
       ++it) {
    (*it)->stop();
  }
#endif
}

/* ******************************************* */

void Ntop::loadTrackers() {
  FILE* fd;
  char line[MAX_PATH];

  snprintf(line, sizeof(line), "%s/other/trackers.txt", prefs->get_docs_dir());

  if ((fd = fopen(line, "r")) != NULL) {
    if ((trackers_automa = ndpi_init_automa()) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
                                   "Unable to initialize trackers");
      fclose(fd);
      return;
    }

    while (fgets(line, MAX_PATH, fd) != NULL) {
      char* str = strdup(line);
      if (str) ndpi_add_string_to_automa(trackers_automa, str);
    }

    fclose(fd);
    ndpi_finalize_automa(trackers_automa);
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Unable to load trackers file %s", line);
}

/* ******************************************* */

bool Ntop::isATrackerHost(char* host) {
  return trackers_automa && ndpi_match_string(trackers_automa, host) > 0;
}

/* ******************************************* */

void Ntop::initAllowedProtocolPresets() {
  struct ndpi_detection_module_struct* ndpi_struct =
      ndpi_init_detection_module(NULL);
  u_int num_protocols;

  if (ndpi_struct) {
    ndpi_finalize_initialization(ndpi_struct);
    num_protocols = ndpi_get_num_protocols(ndpi_struct);
    ndpi_exit_detection_module(ndpi_struct);
  } else
    throw "Allocation error";

  for (u_int i = 0; i < device_max_type; i++) {
    DeviceProtocolBitmask* b = getDeviceAllowedProtocols((DeviceType)i);

    ndpi_bitmask_alloc(&b->clientAllowed, num_protocols);
    ndpi_bitmask_alloc(&b->serverAllowed, num_protocols);

    ndpi_bitmask_set_all(&b->clientAllowed);
    ndpi_bitmask_set_all(&b->serverAllowed);
  }
}

/* ******************************************* */

void Ntop::refreshAllowedProtocolPresets(DeviceType device_type, bool client,
                                         lua_State* L, int index) {
  DeviceProtocolBitmask* b = getDeviceAllowedProtocols(device_type);

  lua_pushnil(L);

  if (b == NULL) return;

  if (client)
    ndpi_bitmask_reset(&b->clientAllowed);
  else
    ndpi_bitmask_reset(&b->serverAllowed);

  while (lua_next(L, index) != 0) {
    u_int key_proto = lua_tointeger(L, -2);
    int t = lua_type(L, -1);

    if ((int)key_proto < 0) continue;

    switch (t) {
      case LUA_TNUMBER: {
        u_int value_action = lua_tointeger(L, -1);

        if (value_action) {
          u_int32_t mapped_key_proto = ndpi_map_user_proto_id_to_ndpi_id(
              iface[0]->get_ndpi_struct(), key_proto);

          /* ntop->getTrace()->traceEvent(TRACE_INFO, "%u -> %u", key_proto,
           * mapped_key_proto); */

          if (client)
            ndpi_bitmask_set(&b->clientAllowed, mapped_key_proto);
          else
            ndpi_bitmask_set(&b->serverAllowed, mapped_key_proto);
        }
      } break;

      default:
        ntop->getTrace()->traceEvent(TRACE_ERROR,
                                     "Internal error: type %d not handled", t);
        break;
    }

    lua_pop(L, 1);
  }
}

/* ******************************************* */

#ifdef HAVE_NEDGE
bool Ntop::addIPToLRUMatches(u_int32_t client_ip, u_int16_t user_pool_id,
                             char* label, char* ifname) {
  for (int i = 0; i < num_defined_interfaces; i++) {
    if (iface[i]->is_bridge_interface() &&
        (strcmp(iface[i]->get_name(), ifname) == 0)) {
      iface[i]->addIPToLRUMatches(client_ip, user_pool_id, label);
      return true;
    }
  }

  return false;
}

/* ******************************************* */

void Ntop::addToNotifiedInformativeCaptivePortal(u_int32_t client_ip) {
  for (int i = 0; i < num_defined_interfaces; i++) {
    if (iface[i]->is_bridge_interface()) /* TODO: handle multiple interfaces
                                            separately */
      iface[i]->addToNotifiedInformativeCaptivePortal(client_ip);
  }
}
#endif

/* ******************************************* */

DeviceProtoStatus Ntop::getDeviceAllowedProtocolStatus(DeviceType dev_type,
                                                       ndpi_protocol proto,
                                                       u_int16_t pool_id,
                                                       bool as_client) {
  /* Check if this application protocol is allowd for the specified device type
   */
  DeviceProtocolBitmask* bitmask = getDeviceAllowedProtocols(dev_type);
  struct ndpi_bitmask* direction_bitmask =
      as_client ? (&bitmask->clientAllowed) : (&bitmask->serverAllowed);
  u_int16_t master_proto = ndpi_map_user_proto_id_to_ndpi_id(
      iface[0]->get_ndpi_struct(), proto.proto.master_protocol);
  u_int16_t app_proto = ndpi_map_user_proto_id_to_ndpi_id(
      iface[0]->get_ndpi_struct(), proto.proto.app_protocol);

#ifdef HAVE_NEDGE
  /* On nEdge the concept of device protocol policies is only applied to
   * unassigned devices on LAN */
  if (pool_id != NO_HOST_POOL_ID) return device_proto_allowed;
#endif

  /* Always allow network critical protocols */
  if (Utils::isCriticalNetworkProtocol(master_proto) ||
      Utils::isCriticalNetworkProtocol(app_proto))
    return device_proto_allowed;

  if ((master_proto != NDPI_PROTOCOL_UNKNOWN) &&
      (!ndpi_bitmask_is_set(direction_bitmask, master_proto))) {
    return device_proto_forbidden_master;
  } else if ((!ndpi_bitmask_is_set(direction_bitmask, app_proto))) {
    /* We consider NDPI_PROTOCOL_UNKNOWN as a protocol to be allowed */
    return device_proto_forbidden_app;
  }

  return device_proto_allowed;
}

/* ******************************************* */

void Ntop::resetStats() {
  char buf[32];
  last_stats_reset = time(NULL);

  snprintf(buf, sizeof(buf), "%ld", last_stats_reset);

  /* Saving this is essential to reset inactive hosts across ntopng restarts */
  getRedis()->set(LAST_RESET_TIME, buf);
}

/* ******************************************* */

void Ntop::refreshCPULoad() {
  if (Utils::getCPULoad(&cpu_stats))
    cpu_load = cpu_stats.load;
  else
    cpu_load = -1;
}

/* ******************************************* */

bool Ntop::getCPULoad(float* out) {
  bool rv;

  if (cpu_load >= 0) {
    *out = cpu_load;
    rv = true;
  } else
    rv = false;

  return (rv);
}

/* ******************************************* */

bool Ntop::initnDPIReload() {
  bool rc = false;

  for (u_int i = 0; i < get_num_interfaces(); i++)
    if (getInterface(i)) rc |= getInterface(i)->initnDPIReload();

  return (rc);
}

/* ******************************************* */

bool Ntop::isnDPIReloadInProgress() {
  bool rc = false;

  for (u_int i = 0; i < get_num_interfaces(); i++)
    if (getInterface(i)) rc |= getInterface(i)->isnDPIReloadInProgress();

  return (rc);
}

/* ******************************************* */

void Ntop::finalizenDPIReload() {
  for (u_int i = 0; i < get_num_interfaces(); i++)
    if (getInterface(i)) getInterface(i)->finalizenDPIReload();
}

/* ******************************************* */

bool Ntop::nDPILoadIPCategory(char* what, ndpi_protocol_category_t cat_id,
                              char* list_name) {
  u_int8_t list_id;
  char* persistent_name = getPersistentCustomListName(list_name, &list_id);
  bool success = true;
  u_int16_t id = (((u_int16_t)list_id) << 8) + (u_int8_t)cat_id;

  for (u_int i = 0; i < get_num_interfaces(); i++) {
    if (getInterface(i)) {
      if (!getInterface(i)->nDPILoadIPCategory(what, id, persistent_name))
        success = false;
    }
  }

  return success;
}

/* ******************************************* */

bool Ntop::nDPILoadHostnameCategory(char* what, ndpi_protocol_category_t cat_id,
                                    char* list_name) {
  u_int8_t list_id;
  char* persistent_name = getPersistentCustomListName(list_name, &list_id);
  bool success = true;
  u_int16_t id = (((u_int16_t)list_id) << 8) +
                 (u_int8_t)cat_id; /* Merge list_id and cat_id on a u_int16_t */

  for (u_int i = 0; i < get_num_interfaces(); i++) {
    if (getInterface(i)) {
      if (!getInterface(i)->nDPILoadHostnameCategory(what, id, persistent_name))
        success = false;
    }
  }

  return success;
}

/* ******************************************* */

int Ntop::nDPISetDomainMask(const char* domain, u_int64_t domain_mask) {
  int rc = 0;

  for (u_int i = 0; i < get_num_interfaces(); i++)
    if (getInterface(i))
      rc = getInterface(i)->setDomainMask(domain, domain_mask);

  return (rc /* last one returned */);
}

/* ******************************************* */

ndpi_protocol_category_t Ntop::get_ndpi_proto_category(u_int protoid) {
  for (u_int i = 0; i < get_num_interfaces(); i++)
    if (getInterface(i))
      return (getInterface(i)->get_ndpi_proto_category(protoid));

  return (NDPI_PROTOCOL_CATEGORY_UNSPECIFIED);
}

/* ******************************************* */

void Ntop::setnDPIProtocolCategory(u_int16_t protoId,
                                   ndpi_protocol_category_t protoCategory) {
  for (u_int i = 0; i < get_num_interfaces(); i++) {
    NetworkInterface* iface = getInterface(i);

    if (iface)
      iface->setnDPIProtocolCategory(iface->get_ndpi_struct(), protoId,
                                     protoCategory);
  }
}

/* *************************************** */

void Ntop::setLastInterfacenDPIReload(time_t now) {
  for (u_int i = 0; i < get_num_interfaces(); i++)
    if (getInterface(i)) getInterface(i)->setLastInterfacenDPIReload(now);
}

/* *************************************** */

bool Ntop::needsnDPICleanup() {
  bool rc = false;

  for (u_int i = 0; i < get_num_interfaces(); i++)
    if (getInterface(i)) rc |= getInterface(i)->needsnDPICleanup();

  return (rc);
}

/* *************************************** */

u_int16_t Ntop::getnDPIProtoByName(const char* name) {
  NetworkInterface* iface = getFirstInterface();

  if (iface) return iface->getnDPIProtoByName(name);

  return (NDPI_PROTOCOL_UNKNOWN);
}

/* *************************************** */

void Ntop::setnDPICleanupNeeded(bool needed) {
  for (u_int i = 0; i < get_num_interfaces(); i++)
    if (getInterface(i)) getInterface(i)->setnDPICleanupNeeded(needed);
}

/* *************************************** */

void Ntop::setScriptsDir() {
#ifdef WIN32
  snprintf(scripts_dir, sizeof(scripts_dir), "%s\\scripts", get_working_dir());
#else
  snprintf(scripts_dir, sizeof(scripts_dir), "%s/scripts", get_working_dir());
#endif
}

/* ******************************************* */

inline int32_t Ntop::localNetworkLookup(int family, void* addr,
                                        u_int8_t* network_mask_bits) {
  return (local_network_tree.findAddress(family, addr, network_mask_bits));
}

/* ******************************************* */

inline int32_t Ntop::cloudNetworkLookup(int family, void* addr,
                                        u_int8_t* network_mask_bits) {
  return (
      cloud_local_network_tree.findAddress(family, addr, network_mask_bits));
}

/* **************************************** */

u_int32_t Ntop::getLocalNetworkId(const char* address_str) {
  u_int32_t i;

  for (i = 0; i < local_network_tree.getNumAddresses(); i++) {
    if (local_network_names[i] &&
        (!strcmp(address_str, local_network_names[i])))
      return (i);
  }

  return ((u_int32_t)-1);
}

/* ******************************************* */

bool Ntop::addLocalNetwork(char* _net) {
  if (strncmp(_net, "asn", 3) == 0) {
    /* ASN */
    u_int32_t asn = (u_int32_t)atoi(&_net[3]);

    if (local_asn.find(asn) == local_asn.end()) {
      local_asn[asn] = true;
      ntop->getTrace()->traceEvent(TRACE_INFO, "Added Autonomous System %u",
                                   asn);
      return (true);
    } else
      return (false); /* Already present */
  } else {
    /* Network */
    char *net, *position_ptr;
    char alias[64] = "";
    u_int32_t id = local_network_tree.getNumAddresses();
    u_int32_t i, pos = 0;
    char out[128] = {'\0'};

    if (id >= getMaxNumLocalNetworks()) {
      ntop->getTrace()->traceEvent(
          TRACE_ERROR, "Too many networks defined (%d): ignored %s", id, _net);
      return (false);
    }

    // Getting the pointer and the position to the "=" indicator
    position_ptr = strstr(_net, "=");
    pos = (position_ptr == NULL ? 0 : position_ptr - _net);

    if (pos) {
      // "=" indicator is present inside the string
      // Separating the alias from the network
      net = strndup(_net, pos);
      memcpy(alias, position_ptr + 1, strlen(_net) - pos - 1);
    } else {
      net = strdup(_net);
    }

    if (net == NULL) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
      return (false);
    }

    for (i = 0; i < id; i++) {
      if (strcmp(local_network_names[i], net) == 0) {
        /* Already present */
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "Network %s already present",
                                     net);
        free(net);
        return (false);
      }
    }

    // Adding the Network to the local Networks
    if (!local_network_tree.addAddresses(net)) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Failure adding address %s",
                                   net);
      free(net);
      return (false);
    }

    local_network_names[id] = net;

    // Adding, if available, the alias
    out[0] = '\0';
    if (pos) {
      u_int len = ndpi_min(strlen(alias), sizeof(out) - 2);

      for (u_int i = 0, j = 0; i < len; i++) {
        if (isprint(alias[i])) out[j++] = alias[i];
      }

      local_network_aliases[id] = strdup(out);
    }

    ntop->getTrace()->traceEvent(TRACE_INFO, "Added Local Network #%u %s %s",
                                 id, net, out);

    return (true);
  }
}

/* ******************************************* */

bool Ntop::getLocalNetworkAlias(lua_State* vm, u_int32_t network_id) {
  char* alias = NULL;

  if (network_id < getMaxNumLocalNetworks())
    alias = local_network_aliases[network_id];

  // Checking if the network has an alias
  if (!alias) return false;

  lua_pushstring(vm, alias);

  return true;
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
void Ntop::addLocalNetworkList(const char* rule) {
  char *tmp, *net = strtok_r((char*)rule, ",", &tmp);

  while (net != NULL) {
    if (!addLocalNetwork(net))
      ntop->getTrace()->traceEvent(
          TRACE_INFO,
          "Unable to parse network %s or already defined: skipping it", net);
    else
      ntop->getTrace()->traceEvent(TRACE_INFO, "Added network %s", net);

    net = strtok_r(NULL, ",", &tmp);
  }
}

/* ******************************************* */

bool Ntop::luaFlowCheckInfo(lua_State* vm, std::string check_name) const {
  FlowChecksLoader* fcl = flow_checks_loader;
  if (fcl) return fcl->luaCheckInfo(vm, check_name);

  return false;
}

/* ******************************************* */

bool Ntop::luaHostCheckInfo(lua_State* vm, std::string check_name) const {
  HostChecksLoader* hcl = host_checks_loader;
  if (hcl) return hcl->luaCheckInfo(vm, check_name);

  return false;
}

/* ******************************************* */

bool Ntop::isDbCreated() {
  for (int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
    NetworkInterface* iface = ntop->getInterface(i);

    if (iface && (!iface->isDbCreated())) return (false);
  }

  return (true);
}

/* ******************************************* */

#ifndef HAVE_NEDGE

bool Ntop::initPublisher() {
#ifdef HAVE_ZMQ
  if (zmqPublisher == NULL) {
    if (prefs->getZMQPublishEventsURL() == NULL) return (false);

    try {
      zmqPublisher = new ZMQPublisher(prefs->getZMQPublishEventsURL());
    } catch (...) {
      zmqPublisher = NULL;
    }
  }

  if (zmqPublisher == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Unable to create ZMQ publisher");

  return !!zmqPublisher;
#else
  return (false);
#endif
}

/* ******************************************* */

bool Ntop::broadcastIPSMessage(char* msg) {
  bool rc = false;

  if (!msg) return (false);

#ifdef HAVE_ZMQ
  /* Jeopardized users_m lock :-) */
  users_m.lock(__FILE__, __LINE__);

  if (!initPublisher()) {
    users_m.unlock(__FILE__, __LINE__);
    return (false);
  }

  rc = zmqPublisher->sendIPSMessage(msg);

  users_m.unlock(__FILE__, __LINE__);
#endif

  return (rc);
}

/* ******************************************* */

bool Ntop::broadcastControlMessage(char* msg) {
  bool rc = false;

  if (!msg) return (false);

#ifdef HAVE_ZMQ
  /* Jeopardized users_m lock :-) */
  users_m.lock(__FILE__, __LINE__);

  if (!initPublisher()) {
    users_m.unlock(__FILE__, __LINE__);
    return (false);
  }

  rc = zmqPublisher->sendControlMessage(msg);

  users_m.unlock(__FILE__, __LINE__);
#endif

  return (rc);
}

#endif

/* ******************************************* */

u_int64_t Ntop::getNumActiveProbes() const {
  u_int64_t n = 0;

  for (int i = 0; i < num_defined_interfaces; i++)
    n += iface[i]->getNumActiveProbes();

  return n;
}

/* ******************************************* */

#ifndef WIN32

/* ******************************************* */

Ping* Ntop::getPing(char* ifname) {
  if (!can_send_icmp) return (NULL);

  if ((ifname == NULL) || (ifname[0] == '\0'))
    return (default_ping);
  else {
    std::map<std::string /* ifname */, Ping*>::iterator it =
        ping.find(std::string(ifname));
    if (it == ping.end()) {
      /* Pinger not found */
      struct sockaddr_in6 sin6;
      Ping* pinger = NULL;
      if (Utils::readIPv4(ifname) || Utils::readIPv6(ifname, &sin6.sin6_addr)) {
        /* Create pinger for the interface */
        try {
          pinger = new Ping(ifname);
        } catch (...) {
          ntop->getTrace()->traceEvent(
              TRACE_ERROR, "Unable to create continuous pinger for %s", ifname);
          pinger = NULL;
        }

        if (pinger) ping[std::string(ifname)] = pinger;
      }
      return (pinger);
    } else
      return (it->second);
  }
}

/* ******************************************* */

void Ntop::initPing() {
  if (!can_send_icmp) return;

  if (ntop->getPrefs()->get_active_monitoring_pref()) {

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Initializing Continuous Ping");

    cping = new (std::nothrow) ContinuousPing();

    /* Default */
    default_ping = new (std::nothrow) Ping(NULL /* System interface */);

    /* Pinger per interface */
    ntop_if_t *devpointer, *cur;
    if (Utils::ntop_findalldevs(&devpointer) == 0) {
      for (cur = devpointer; cur; cur = cur->next) {
        if (cur->name) {
          struct sockaddr_in6 sin6;
          char* real_name = Utils::get_real_name(cur->name, devpointer);
          if (real_name == NULL /* real interface (not an alias) */ ||
              /* Check if there is an IP for the interface */
              Utils::readIPv4(cur->name) ||
              Utils::readIPv6(cur->name, &sin6.sin6_addr)) {
            getPing(cur->name);
          }

          if (real_name) free(real_name);
        }
      }
      Utils::ntop_freealldevs(devpointer);
    }

    ping_initialized = true;
  }

  for (int i = 0; i < num_defined_interfaces; i++) {
    switch (iface[i]->getIfType()) {
      case interface_type_PF_RING:
      case interface_type_PCAP: {
        char* name = iface[i]->get_name();
        Ping* p = new (std::nothrow) Ping(name);

        if (p) {
          ping[std::string(name)] = p;
          ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created pinger for %s",
                                       name);
        } else
          ntop->getTrace()->traceEvent(
              TRACE_WARNING, "Unable to create ping for interface %s", name);
      } break;

      default:
        ntop->getTrace()->traceEvent(
            TRACE_NORMAL, "Skipping pinger for %s [ifType: %u]",
            iface[i]->get_name(), iface[i]->getIfType());
        /* Nothing to do for other interface types */
        break;
    }
  }
}

/* ******************************************* */

void Ntop::collectResponses(lua_State* vm) {
  lua_newtable(vm);

  default_ping->collectResponses(vm, false /* IPv4 */);
  default_ping->collectResponses(vm, true /* IPv6 */);

  for (std::map<std::string /* ifname */, Ping*>::iterator it = ping.begin();
       it != ping.end(); ++it) {
    it->second->collectResponses(vm, false /* IPv4 */);
    it->second->collectResponses(vm, true /* IPv6 */);
  }
}

/* ******************************************* */

void Ntop::collectContinuousResponses(lua_State* vm) {
  lua_newtable(vm);

  cping->collectResponses(vm, false /* IPv4 */);
  cping->collectResponses(vm, true /* IPv6 */);
}

#endif

/* ******************************************* */

/*
  This method is needed to have a string that is not deallocated
  after a call, but that is persistent inside nDPI
*/
char* Ntop::getPersistentCustomListName(char* list_name /* in */,
                                        u_int8_t* list_id /* out */) {
  std::string key(list_name);
  std::map<std::string, u_int8_t>::iterator it = cachedCustomLists.find(key);

  if (it == cachedCustomLists.end()) {
    /* Not found */
    *list_id =
        cachedCustomLists.size() + 1; /* Avoid 0 (= not found) as identifier */
    cachedCustomLists[key] = *list_id;
    it = cachedCustomLists.find(key);
  } else
    *list_id = it->second;

  return ((char*)it->first.c_str());
}

/* ******************************************* */

const char* Ntop::getPersistentCustomListNameById(u_int8_t list_id) {
  std::map<std::string, u_int8_t>::iterator it;

  if (list_id > 0) {
    for (it = cachedCustomLists.begin(); it != cachedCustomLists.end(); it++) {
      if (it->second == list_id) return (it->first.c_str());
    }
  }

  return (NULL);
}

/* ******************************************* */

void Ntop::setZoneInfo() {
#ifndef WIN32
  char* tz = NULL;
  u_int num_slash = 0;
  char buf[128];

  buf[0] = '\0';
  zoneinfo = NULL;

  /* Read timezone from TZ env var */
  tz = getenv("TZ");
  if (tz != NULL) {
    if (strlen(tz) > 0)
      zoneinfo = strdup(tz);
    else
      tz = NULL;
  }

  /* Read timezone from /etc/localtime (if TZ is not set) */
  if (tz == NULL) {
    /* Check if the softlink is defined */
    ssize_t rc = readlink("/etc/localtime", buf, sizeof(buf));

    if (rc > 0) {
      buf[rc] = '\0';

      rc--;

      while (rc > 0) {
        if (buf[rc] == '/') {
          if (++num_slash == 2) break;
        }

        rc--;
      }

      if (num_slash == 2) {
        rc++;
        zoneinfo = strdup(&buf[rc]);
      }
    }
  }
#ifdef __FreeBSD__
  /* Last resort, in FreeBSD, it is possible the tz is inside /var/db/zoneinfo
   */
  if (!zoneinfo) {
    FILE* fd = fopen("/var/db/zoneinfo", "r");
    if (fd != NULL) {
      char timezone[128];

      if (fgets(timezone, sizeof(timezone), fd)) {
        int len = strlen(timezone);

        if (len > 0) timezone[len - 1] = '\0';
        zoneinfo = strdup(timezone);
      }

      fclose(fd);
    }
  }
#endif /* FreeBSD */
#else
  zoneinfo = getWindowsTimezone();
#endif /* WIN32 */

  if (zoneinfo == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Unable to find timezone: using UTC");
    zoneinfo = strdup("UTC");
  } else {
    const char* const_zoneinfo = "zoneinfo/";
    u_int len = strlen(const_zoneinfo);

    if (strncmp(zoneinfo, const_zoneinfo, len) == 0) {
      char* tmp = zoneinfo;
      zoneinfo = strdup(&zoneinfo[len]);
      free(tmp);
    }
  }

  if (zoneinfo)
    ntop->getTrace()->traceEvent(TRACE_INFO, "ntopng timezone set to %s",
                                 zoneinfo);
}

/* ******************************************* */

// #define DEBUG_SPEEDTEST
#include "../third-party/speedtest.c"

void Ntop::speedtest(lua_State* vm) {
  json_object* rc;

  /*
     We need to make sure that only one caller
     at time calls speedtest as
     - the speedtest code is not reentrant
     - running multiple tests concurrently reports wrong results
       as clients compete for the same bandwidth
  */

  speedtest_m.lock(__FILE__, __LINE__);

  rc = ::speedtest();

  if (rc) {
    lua_pushstring(vm, json_object_to_json_string(rc));
    json_object_put(rc); /* Free memory */
  } else
    lua_pushnil(vm);

  speedtest_m.unlock(__FILE__, __LINE__);
}

/* ******************************************* */

bool Ntop::createRuntimeInterface(char* name, char* source, int* iface_id) {
  bool ret = false;
#ifndef HAVE_NEDGE
  bool disable_dump = true;
  NetworkInterface *new_iface, *old_iface = NULL;
  int slot_id = -1;

  if (old_iface_to_purge != NULL) {
    delete old_iface_to_purge;
    old_iface_to_purge = NULL;
  }

  if (*iface_id != -1) {
    for (int i = 0; i < num_defined_interfaces; i++) {
      if (iface[i]->get_id() == *iface_id) {
        old_iface = iface[i], slot_id = i;
        break;
      }
    }
  }

  if (strncmp(source, "pcap:", 5) == 0) {
    source = &source[5];

    ntop->fixPath(source);

    try {
      errno = 0;
      new_iface = new PcapInterface((const char*)source,
                                    (u_int8_t)ntop->get_num_interfaces(),
                                    true /* delete pcap when done */);
    } catch (int err) {
      getTrace()->traceEvent(TRACE_ERROR,
                             "Unable to open interface %s with pcap [%d]: %s",
                             source, err, strerror(err));
      return false;
    }

    /* In case the preference is enabled,
     * dump the flows from the pcap into clickhouse
     */
    if (ntop->getPrefs()->dump_pcap_to_clickhouse_enabled()) {
      disable_dump = false;
    }
  } else if (strncmp(source, "db:", 3) == 0) {
    source = &source[3];

#if defined(NTOPNG_PRO) && defined(HAVE_CLICKHOUSE)
    if (ntop->getPrefs()->do_dump_flows_on_clickhouse()) {
      try {
        new_iface =
            new ClickHouseInterface((const char*)source, (const char*)name);
      } catch (int err) {
        getTrace()->traceEvent(TRACE_ERROR, "Unable to open database on '%s'",
                               source);
        return false;
      }
    } else
#endif
    {
      getTrace()->traceEvent(TRACE_WARNING,
                             "Unable to create runtime interface on database "
                             "(database support not enabled)");
      return false;
    }

  } else {
    getTrace()->traceEvent(TRACE_WARNING,
                           "Unrecognized runtime interface type '%s'", source);
    return false;
  }

  if (old_iface == NULL) {
    /* Register new interface */
    if (!registerInterface(new_iface)) return false;
  }

  initInterface(new_iface, disable_dump /* disable flow dump to db */);
  new_iface->reloadFlowChecks(flow_checks_loader);
  new_iface->reloadHostChecks(host_checks_loader);
  new_iface->allocateStructures(true /* disable flow dump to db */);
  new_iface->startPacketPolling();

  if (old_iface != NULL) {
    m.lock(__FILE__, __LINE__);

    iface[slot_id] = new_iface; /* Swap interfaces */

    old_iface->shutdown();

    /* Wait until the interface is shutdown */
    while (old_iface->isRunning()) sleep(1);

    /* Trick to avoid crashing while using the same interface we want to free */
    old_iface_to_purge = old_iface;

    m.unlock(__FILE__, __LINE__);
  }

  *iface_id = new_iface->get_id();

  ret = true;

#endif

  return (ret);
}

/* ******************************************* */

void Ntop::incBlacklisHits(std::string listname) { blStats.incHits(listname); }

/* ******************************************* */

#ifdef NTOPNG_PRO
void Ntop::connectMessageBroker() {
#ifdef HAVE_NATS
  if (getPrefs() && getPrefs()->is_message_broker_enabled()) {
    const char* m_broker_id = prefs->get_message_broker();

    if (!strcmp(m_broker_id, CONST_NATS_M_BROKER_ID)) {
      message_broker = new (std::nothrow) NatsBroker();
    }
  }
#endif /* HAVE NATS */
  // TODO: add MQTT
}

/* ******************************************* */

void Ntop::reloadMessageBroker() {
  if (message_broker) {
    delete (message_broker);
    message_broker = NULL;
  }

  connectMessageBroker();
}

/* ******************************************* */

bool Ntop::incNumFlowExporters() {
  bool ok = (num_flow_exporters < get_max_num_flow_exporters());

  if (ok) num_flow_exporters++;
  return ok;
}

/* ******************************************* */

bool Ntop::incNumFlowExportersInterfaces() {
  bool ok = (num_flow_interfaces < get_max_num_flow_exporters_interfaces());
  if (ok) num_flow_interfaces++;
  return ok;
}

/* ******************************************* */

void Ntop::decNumFlowExporters() {
  if (num_flow_exporters > 0) num_flow_exporters--;
}

/* ******************************************* */

void Ntop::decNumFlowExportersInterfaces() {
  if (num_flow_interfaces > 0) num_flow_interfaces--;
}

/* ******************************************* */

u_int32_t Ntop::getMaxNumFlowExporters() {
  return get_max_num_flow_exporters();
}

/* ******************************************* */

u_int32_t Ntop::getMaxNumFlowExportersInterfaces() {
  return get_max_num_flow_exporters_interfaces();
}
#endif /* NTOPNG_PRO */

/* ******************************************* */

u_int32_t Ntop::getMaxNumLocalNetworks() {
#ifdef NTOPNG_PRO
  return get_max_num_local_networks();
#else
  return MAX_NUM_LOCAL_NETWORKS;
#endif /* NTOPNG_PRO */
}

/* ******************************************* */

bool Ntop::isInLocalASN(IpAddress* ip) {
  u_int32_t asn;

  if ((geo == NULL) || (local_asn.size() == 0 /* No ASN defined */))
    return (false);

  if (geo->getAS(ip, &asn, NULL)) {
    if (local_asn.find(asn) != local_asn.end()) return (true);
  }

  return (false);
}

/* ******************************************* */

#define TMP_PROTOS_FILE "/tmp/ntopng-ndpi-protocols-file"

bool Ntop::downloadCustomnDPIProtos(char* url, char* dest_file) {
  struct stat statbuf;

  if (stat(dest_file, &statbuf) == 0) {
    /* File exists */
    time_t tdiff = time(NULL) - statbuf.st_mtime;

    // ntop->getTrace()->traceEvent(TRACE_WARNING, "-> %u", tdiff);

    if (tdiff <= 5 /* sec */)
      return (true); /* Fresh file: no need to re-download it */
  }

  HttpGetPostOptions opts;
  memset(&opts, 0, sizeof(opts));
  opts.connect_timeout      = 10;
  opts.max_duration_timeout = 30;
  opts.write_fname          = dest_file;
  opts.follow_redirects     = true;
  opts.ip_version           = 4;
  bool rc = Utils::httpGetPostPutPatch(NULL, custom_ndpi_protos, method_get, opts);

  if (rc == false) {
    ntop->getTrace()->traceEvent(TRACE_WARNING,
                                 "Unable to access URL %s: ignored", url);
    return (false);
  } else {
    ntop->getTrace()->traceEvent(
        TRACE_NORMAL, "Successfully downloaded nDPI protocols file from URL %s",
        url);
    return (true);
  }
}

/* ******************************************* */

char* Ntop::getCustomnDPIProtos() {
  if (custom_ndpi_protos != NULL) {
    if ((strncmp(custom_ndpi_protos, "http://", 7) == 0) ||
        (strncmp(custom_ndpi_protos, "https://", 8) == 0)) {
      downloadCustomnDPIProtos(custom_ndpi_protos, (char*)TMP_PROTOS_FILE);

      return ((char*)TMP_PROTOS_FILE);
    }
  }

  return (custom_ndpi_protos);
}

/* ******************************************* */

void Ntop::trackAssetChange(const char* protocol, const char* action, Mac* mac,
                            IpAddress* target_ip, Host* target, Flow* flow,
                            char* note) {
#ifdef TRACK_ASSET_CHANGE
  char buf[64], buf1[256], buf2[256];

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL, "[%s] %s [%s][%s][%s][%s]", protocol, action,
      mac ? mac->print(buf, sizeof(buf)) : "",
      target_ip ? target_ip->print(buf1, sizeof(buf1)) : "",
      target ? target->print(buf1, sizeof(buf1)) : "",
      flow ? flow->print(buf2, sizeof(buf2), false) : "", note ? note : "");
#endif
}

/* ******************************************* */

void Ntop::reloadASNConfiguration() {
  getPrefs()->reloadASNConfiguration();
  for (int i = 0; i < MAX_NUM_INTERFACE_IDS; i++) {
    NetworkInterface* iface = ntop->getInterface(i);
    if (iface && iface->isZMQInterface()) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
                                   "Updating ASN Exporter Prefs [ifid: %d]",
                                   iface->get_id());
      iface->updateASNExportersPrefs();
    }
  }
}

/* ******************************************* */

bool Ntop::viewHasZMQInterface(NetworkInterface* viewInterface) {
#ifdef NTOPNG_PRO
  for (int i = 0; i < num_defined_interfaces; i++) {
    if (iface[i] && (iface[i]->viewedBy() == viewInterface) &&
        (iface[i]->getIfType() == interface_type_ZMQ))
      return (true);
  }
#endif

  return (false);
}

/* ******************************************* */

std::string Ntop::getLuaCache(std::string key) {
  std::map<std::string, std::string>::iterator it;

  luaCacheLock.rdlock(__FILE__, __LINE__);
  it = luaCache.find(key);
  luaCacheLock.unlock(__FILE__, __LINE__);

  if (it == luaCache.end())
    return ("");
  else
    return (it->second);
}

/* ******************************************* */

void Ntop::setLuaCache(std::string key, std::string val) {
  luaCacheLock.wrlock(__FILE__, __LINE__);
  luaCache[key] = val;
  luaCacheLock.unlock(__FILE__, __LINE__);
}

/* ******************************************* */

void Ntop::dumpLuaCache(lua_State* vm) {
  std::map<std::string, std::string>::iterator it;

  lua_newtable(vm);

  luaCacheLock.rdlock(__FILE__, __LINE__);

  for (it = luaCache.begin(); it != luaCache.end(); ++it)
    lua_push_str_table_entry(vm, it->first.c_str(), it->second.c_str());

  luaCacheLock.unlock(__FILE__, __LINE__);
}

/* ******************************************* */

#ifdef NTOPNG_PRO

void Ntop::initSnmpInterfaceRole() {
  if(ifRoles_shadow != NULL) {
    delete ifRoles_shadow;
    ifRoles_shadow = NULL;
  }
  
  ifRoles_shadow = new (std::nothrow) std::map<std::tuple<struct ndpi_in6_addr, u_int32_t>, SNMPInterfaceRole, InterfaceKeyCompare>;
}

/* ******************************************* */

void Ntop::activateSnmpInterfaceRoles() {
  if(ifRoles_shadow != NULL) {
    std::map<std::tuple<struct ndpi_in6_addr, u_int32_t>, SNMPInterfaceRole, InterfaceKeyCompare> *tmp = ifRoles;

    ifRoles = ifRoles_shadow;
    ifRoles_shadow = tmp;
  } else
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid state");
}

/* ******************************************* */

void Ntop::snmpSetInterfaceRole(struct ndpi_in6_addr *exporter_device_ip,
                                u_int32_t interface_id,
                                SNMPInterfaceRole interface_role) {
  if(ifRoles_shadow == NULL) initSnmpInterfaceRole();

  if(ifRoles_shadow)
    ifRoles_shadow->emplace(std::make_tuple(*exporter_device_ip, interface_id), interface_role);
}

/* ******************************************* */

/* NOTE: add a mutex or another trick if dynamic interface reload is implemented */
SNMPInterfaceRole Ntop::snmpGetInterfaceRole(struct ndpi_in6_addr *exporter_device_ip,
                                             u_int32_t interface_id) {
  if(ifRoles != NULL) {
    std::tuple<struct ndpi_in6_addr, u_int32_t> searchKey = {*exporter_device_ip, interface_id};
    std::map<std::tuple<struct ndpi_in6_addr, u_int32_t>, SNMPInterfaceRole, InterfaceKeyCompare>::iterator it =
      ifRoles->find(searchKey);

    if (it != ifRoles->end())
      return (it->second);    
  }
  
  return (role_other);
}
#endif
