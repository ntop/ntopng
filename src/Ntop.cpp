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

#ifdef __linux__
#include <sys/inotify.h>
#define EVENT_SIZE  ( sizeof (struct inotify_event) )
#define EVENT_BUF_LEN     ( 1024 * ( EVENT_SIZE + 16 ) )
#endif

#ifdef WIN32
#include <shlobj.h> /* SHGetFolderPath() */
#else
#include <ifaddrs.h>
#include <sys/file.h>
#endif

Ntop *ntop;

static const char* dirs[] = {
  NULL,                      /* Populated at runtime */
  NULL,                      /* Populated at runtime for WIN32 builds */
  CONST_ALT_INSTALL_DIR,
  CONST_ALT2_INSTALL_DIR,
#ifndef WIN32
  CONST_DEFAULT_INSTALL_DIR, /* Last is the <path> specified with ./configure --prefix <path>, defaulting to /usr/local */
#endif
  NULL
};

extern struct keyval string_to_replace[]; /* LuaEngine.cpp */

/* ******************************************* */

Ntop::Ntop(char *appName) {
  ntop = this;
  globals = new (std::nothrow) NtopGlobals();
  extract = new (std::nothrow) TimelineExtract();
  pa      = new (std::nothrow) PeriodicActivities();
  address = new (std::nothrow) AddressResolution();
  offline = false;
  custom_ndpi_protos = NULL;
  prefs = NULL, redis = NULL;
#ifndef HAVE_NEDGE
  export_interface = NULL;
  zmqPublisher = NULL;
#endif
  trackers_automa = NULL;
  num_cpus = -1;
  num_defined_interfaces = 0;
  num_dump_interfaces = 0;
  iface = NULL;
  start_time = last_modified_static_file_epoch = 0, epoch_buf[0] = '\0'; /* It will be initialized by start() */
  last_stats_reset = 0;
  ndpiReloadInProgress = false;
  
  /* Checks loader */
  flowChecksReloadInProgress = true; /* Lazy, will be reloaded the first time this condition is evaluated */
  hostChecksReloadInProgress = true;
  flow_checks_loader = NULL;
  host_checks_loader = NULL;

  /* Flow alerts exclusions */
#ifdef NTOPNG_PRO
  alertExclusionsReloadInProgress = true;
  alert_exclusions = alert_exclusions_shadow = NULL;
#endif

  /* Host Pools reload - Interfaces initialize their pools inside the constructor */
  hostPoolsReloadInProgress = false;

  httpd = NULL, geo = NULL, mac_manufacturers = NULL;
  memset(&cpu_stats, 0, sizeof(cpu_stats));
  cpu_load = 0;
  system_interface = NULL;
  purgeLoop_started = false;
#ifndef WIN32
  cping = NULL, ping = NULL;
#endif
  privileges_dropped = false;
  can_send_icmp = Utils::isPingSupported();

  for (int i = 0; i < CONST_MAX_NUM_NETWORKS; i++)
    local_network_names[i] = local_network_aliases[i] = NULL;

#ifndef WIN32
  if(can_send_icmp) {
    cping = new (std::nothrow) ContinuousPing();

#ifndef __linux__
    ping = new (std::nothrow)Ping(NULL /* System interface */);
#endif
  }
#endif

  /* nDPI handling */
  last_ndpi_reload = 0;
  ndpi_struct_shadow = NULL;
  ndpi_struct = initnDPIStruct();
  ndpi_finalize_initialization(ndpi_struct);

  internal_alerts_queue = new (std::nothrow) FifoSerializerQueue(INTERNAL_ALERTS_QUEUE_SIZE);

  resolvedHostsBloom = new (std::nothrow) Bloom(NUM_HOSTS_RESOLVED_BITS);

#ifdef WIN32
  if(SHGetFolderPath(NULL, CSIDL_PERSONAL, NULL, SHGFP_TYPE_CURRENT, working_dir) != S_OK) {
    strncpy(working_dir, "C:\\Windows\\Temp\\ntopng", sizeof(working_dir)); // Fallback: it should never happen
    working_dir[sizeof(working_dir) - 1] = '\0';
  } else {
    int l = strlen(working_dir);

    snprintf(&working_dir[l], sizeof(working_dir), "%s", "\\ntopng");
  }

  // Get the full path and filename of this program
  if(GetModuleFileName(NULL, startup_dir, sizeof(startup_dir)) == 0) {
    startup_dir[0] = '\0';
  } else {
    for(int i=(int)strlen(startup_dir)-1; i>0; i--) {
      if(startup_dir[i] == '\\') {
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
  if (Utils::dir_exists(CONST_OLD_DEFAULT_DATA_DIR)) /* keep using the old dir */
    snprintf(working_dir, sizeof(working_dir), CONST_OLD_DEFAULT_DATA_DIR);
  else
    snprintf(working_dir, sizeof(working_dir), CONST_DEFAULT_DATA_DIR);

  plugins0_active = 0;

  //umask(0);

  if(getcwd(startup_dir, sizeof(startup_dir)) == NULL)
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Occurred while checking the current directory (errno=%d)", errno);

  dirs[0] = startup_dir;

  install_dir[0] = '\0';

  for(int i = 0; i < (int)COUNT_OF(dirs); i++) {
    if(dirs[i]) {
      char path[MAX_PATH];
      struct stat statbuf;

      snprintf(path, sizeof(path), "%s/scripts/lua/index.lua", dirs[i]);
      fixPath(path);

      if(stat(path, &statbuf) == 0) {
	snprintf(install_dir, sizeof(install_dir), "%s", dirs[i]);
	break;
      }
    }
  }
#endif

  refreshPluginsDir();

#ifdef NTOPNG_PRO
  pro = new (std::nothrow) NtopPro();
#else
  pro = NULL;
#endif

#ifdef __linux__
  inotify_fd = -1;
#endif

#ifndef HAVE_NEDGE
  refresh_ips_rules = false;
#endif
  
  // printf("--> %s [%s]\n", startup_dir, appName);

  initTimezone();
  ntop->getTrace()->traceEvent(TRACE_INFO, "System Timezone offset: %+ld", time_offset);

  initAllowedProtocolPresets();

  udp_socket = socket(AF_INET, SOCK_DGRAM, 0);

#ifndef WIN32
  setservent(1);

  startupLockFile = -1;
#endif
}

/* ******************************************* */

#ifndef WIN32

void Ntop::lockNtopInstance() {
  char lockPath[MAX_PATH+8];
  struct flock lock;
  struct stat st;

  if((stat(working_dir, &st) != 0) || !S_ISDIR(st.st_mode)) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Working dir does not exist yet");
    return;
  }

  snprintf(lockPath, sizeof(lockPath), "%s/.lock", working_dir);

  lock.l_type   = F_WRLCK;  /* read/write (exclusive versus shared) lock */
  lock.l_whence = SEEK_SET; /* base for seek offsets */
  lock.l_start  = 0;        /* 1st byte in file */
  lock.l_len    = 0;        /* 0 here means 'until EOF' */
  lock.l_pid    = getpid(); /* process id */

  if((startupLockFile = open(lockPath, O_RDWR | O_CREAT, 0666)) < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open lock file %s [%s]",
				 lockPath, strerror(errno));
    exit(EXIT_FAILURE);
  }

  if(fcntl(startupLockFile, F_SETLK, &lock) < 0) { /** F_SETLK doesn't block, F_SETLKW does **/
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Another ntopng instance is running...");
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
  struct tm *l = localtime(&t);

  time_offset = l->tm_gmtoff;
#endif
}

/* ******************************************* */

Ntop::~Ntop() {
  int num_local_networks = local_network_tree.getNumAddresses();

  for (int i = 0; i < num_local_networks; i++) {
    if (local_network_names[i] != NULL) free(local_network_names[i]);
    if (local_network_aliases[i] != NULL) free(local_network_aliases[i]);
  }

  if(httpd)
    delete httpd; /* Stop the http server before tearing down network interfaces */

  if(purgeLoop_started)
    pthread_join(purgeLoop, NULL);

  for(int i = 0; i < num_defined_interfaces; i++) {
    if(iface[i]) {
      delete iface[i];
      iface[i] = NULL;
    }
  }

  delete []iface;
  if(system_interface)    delete system_interface;
  if(extract)             delete extract;

#ifndef WIN32
  if(cping)               delete cping;
  if(ping)                delete ping;
#endif

  if(udp_socket != -1)    closesocket(udp_socket);

  if(trackers_automa)     ndpi_free_automa(trackers_automa);
  if(custom_ndpi_protos)  free(custom_ndpi_protos);

  delete address;
  if(pa)    delete pa;
  if(geo)   delete geo;
  if(mac_manufacturers) delete mac_manufacturers;

#ifdef NTOPNG_PRO
  if(pro) delete pro;
  if(alert_exclusions)          delete alert_exclusions;
  if(alert_exclusions_shadow)   delete alert_exclusions_shadow;
#endif

  if(resolvedHostsBloom) delete resolvedHostsBloom;
  delete internal_alerts_queue;

  if(ndpi_struct) {
    ndpi_exit_detection_module(ndpi_struct);
    ndpi_struct = NULL;
  }

  cleanShadownDPI();

  if(redis)   { delete redis; redis = NULL;     }
  if(prefs)   { delete prefs; prefs = NULL;     }
  if(globals) { delete globals; globals = NULL; }

  if(flow_checks_loader)     delete flow_checks_loader;
  if(host_checks_loader)     delete host_checks_loader;

#ifdef __linux__
  if(inotify_fd > 0)  close(inotify_fd);
#endif
}

/* ******************************************* */

void Ntop::registerPrefs(Prefs *_prefs, bool quick_registration) {
  char value[32];
  struct stat buf;

  prefs = _prefs;

  if(!quick_registration) {
    if(stat(prefs->get_data_dir(), &buf)
       || (!(buf.st_mode & S_IFDIR))  /* It's not a directory */
       || (!(buf.st_mode & S_IWRITE)) /* It's not writable    */) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid directory %s specified",
				   prefs->get_data_dir());
      exit(-1);
    }

    if(stat(prefs->get_callbacks_dir(), &buf)
       || (!(buf.st_mode & S_IFDIR))  /* It's not a directory */
       || (!(buf.st_mode & S_IREAD)) /* It's not readable    */) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid directory %s specified",
				   prefs->get_callbacks_dir());
      exit(-1);
    }

    if(prefs->get_local_networks()) {
      setLocalNetworks(prefs->get_local_networks());
    } else {
      /* Add defaults */
      /* http://www.networksorcery.com/enp/protocol/ip/multicast.htm */
      setLocalNetworks((char*)CONST_DEFAULT_LOCAL_NETS);
    }
  }

  /* Initialize redis and populate some default values */
  Utils::initRedis(&redis, prefs->get_redis_host(), prefs->get_redis_password(),
		   prefs->get_redis_port(), prefs->get_redis_db_id(), quick_registration);
  if(redis) redis->setDefaults();

  if(!quick_registration) {
    /* Initialize another redis instance for the trace of events */
    ntop->getTrace()->initRedis(prefs->get_redis_host(), prefs->get_redis_password(),
				prefs->get_redis_port(), prefs->get_redis_db_id());

    if(ntop->getRedis() == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to initialize redis. Quitting...");
      exit(-1);
    }
  }

#ifdef NTOPNG_PRO
  pro->init_license();

  if(!ntop->getPro()->has_unlimited_enterprise_l_license())
    prefs->toggle_dump_flows_direct(false);
#endif

  if(quick_registration) return;

  system_interface = new (std::nothrow) NetworkInterface(SYSTEM_INTERFACE_NAME, SYSTEM_INTERFACE_NAME);

  /* License check could have increased the number of interfaces available */
  resetNetworkInterfaces();

  /* Read the old last_stats_reset */
  if(ntop->getRedis()->get((char*)LAST_RESET_TIME, value, sizeof(value)) >= 0)
    last_stats_reset = atol(value);

#if defined(NTOPNG_PRO) && defined(HAVE_NINDEX)
#if 0
  if(ntop->getPro()->is_nindex_in_use()) {
    for(int i=0; i<NUM_NSERIES; i++) {
      char path[MAX_PATH];
      const char *base;

      switch(i) {
      case 0: base = "sec"; break;
      case 1: base = "min"; break;
      case 2: base = "5min"; break;
      default:
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Internal error");
      }

      snprintf(path, sizeof(path), "%s/nseries/%s", ntop->get_working_dir(), base);

      if(!Utils::mkdir_tree(path))
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Unable to create directory %s: nSeries will be disabled", path);
      else {
	try {
	  nseries[i] = new Nseries(path, NSERIES_DATA_RETENTION, true /* readWrite */);
	} catch(...) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate nSeries db %s", path);
	  nseries[i] = NULL;
	}
      }
    }
  }
#endif
#endif

  redis->setInitializationComplete();
}

/* ******************************************* */

void Ntop::resetNetworkInterfaces() {
  if(iface) delete []iface;

  if((iface = new (std::nothrow) NetworkInterface*[MAX_NUM_DEFINED_INTERFACES]()) == NULL)
    throw "Not enough memory";

  ntop->getTrace()->traceEvent(TRACE_INFO, "Interfaces Available: %u", MAX_NUM_DEFINED_INTERFACES);
}

/* ******************************************* */

void Ntop::createExportInterface() {
#ifndef HAVE_NEDGE
  if(prefs->get_export_endpoint())
    export_interface = new (std::nothrow) ExportInterface(prefs->get_export_endpoint());
  else
    export_interface = NULL;
#endif
}

/* ******************************************* */

void Ntop::start() {
  struct timeval begin, end;
  u_long usec_diff;
  char daybuf[64], buf[128];
  time_t when = time(NULL);
  int i = 0;

  getTrace()->traceEvent(TRACE_NORMAL,
			 "Welcome to %s %s v.%s - (C) 1998-21 ntop.org",
#ifdef HAVE_NEDGE
			 "ntopng edge",
#else
			 "ntopng",
#endif
			 PACKAGE_MACHINE, PACKAGE_VERSION);

  if(PACKAGE_OS[0] != '\0')
    getTrace()->traceEvent(TRACE_NORMAL, "Built on %s", PACKAGE_OS);

  last_modified_static_file_epoch = start_time = time(NULL);
  snprintf(epoch_buf, sizeof(epoch_buf), "%u", (u_int32_t)start_time);

  string_to_replace[i].key = CONST_HTTP_PREFIX_STRING, string_to_replace[i].val = ntop->getPrefs()->get_http_prefix(); i++;
  string_to_replace[i].key = CONST_NTOP_STARTUP_EPOCH, string_to_replace[i].val = ntop->getStartTimeString(); i++;
  string_to_replace[i].key = CONST_NTOP_PRODUCT_NAME, string_to_replace[i].val =
#ifdef HAVE_NEDGE
    ntop->getPro()->get_product_name()
#else
    (char*)"ntopng"
#endif
			 ; i++;
  string_to_replace[i].key = NULL, string_to_replace[i].val = NULL;

  strftime(daybuf, sizeof(daybuf), CONST_DB_DAY_FORMAT, localtime(&when));
  snprintf(buf, sizeof(buf), "ntopng.%s.hostkeys", daybuf);

#ifdef NTOPNG_PRO
  if(!pro->forced_community_edition())
    pro->printLicenseInfo();
#endif

  prefs->loadInstanceNameDefaults();

  loadLocalInterfaceAddress();

  address->startResolveAddressLoop();

  system_interface->allocateStructures();

  for(int i=0; i<num_defined_interfaces; i++)
    iface[i]->allocateStructures();

#ifdef __linux__
  inotify_fd = inotify_init();

  if(inotify_fd < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "inotify_init failed[%d]: %s", errno, strerror(errno));
  else {
    uint32_t mask = IN_CREATE | IN_DELETE | IN_MODIFY;
    char path[MAX_PATH];

    /* Watch some directories. TODO: recursive watch */
    snprintf(path, sizeof(path), "%s/system", ntop->get_callbacks_dir());
    inotify_add_watch(inotify_fd, path, mask);

    snprintf(path, sizeof(path), "%s/interface", ntop->get_callbacks_dir());
    inotify_add_watch(inotify_fd, path, mask);

    snprintf(path, sizeof(path), "%s/lua/modules", prefs->get_scripts_dir());
    inotify_add_watch(inotify_fd, path, mask);

#ifdef NTOPNG_PRO
    snprintf(path, sizeof(path), "%s/lua/pro/modules", prefs->get_scripts_dir());
    inotify_add_watch(inotify_fd, path, mask);
#endif
  }
#endif

  /* Note: must start periodic activities loop only *after* interfaces have been
   * completely initialized.
   *
   * Note: this will also run the startup.lua script sequentially.
   * After this call, startup.lua has completed. */
  pa->startPeriodicActivitiesLoop();

  if(get_HTTPserver())
    get_HTTPserver()->start_accepting_requests();

#ifdef HAVE_NEDGE
  /* TODO: enable start/stop of the captive portal webserver directly from Lua */
  if(get_HTTPserver() && prefs->isCaptivePortalEnabled())
    get_HTTPserver()->startCaptiveServer();
#endif

  checkReloadHostPools();
  checkReloadAlertExclusions();
  checkReloadFlowChecks();
  checkReloadHostChecks();

  for(int i=0; i<num_defined_interfaces; i++)
    iface[i]->startPacketPolling();

  startPurgeLoop();

  // sleep(2);

  for(int i=0; i<num_defined_interfaces; i++)
    iface[i]->checkPointCounters(true); /* Reset drop counters */

  /* Align to the next 5-th second of the clock to make sure
     housekeeping starts alinged (and remains aligned when
     the housekeeping frequency is a multiple of 5 seconds) */
  gettimeofday(&begin, NULL);
  _usleep((5 - begin.tv_sec % 5) * 1e6 - begin.tv_usec);

  while((!globals->isShutdown()) && (!globals->isShutdownRequested())) {
    const u_int32_t nap_usec = ntop->getPrefs()->get_housekeeping_frequency() * 1e6;

    gettimeofday(&begin, NULL);

#ifdef HOUSEKEEPING_DEBUG
    char tmbuf[64], buf[64];
    time_t nowtime;
    struct tm *nowtm;

    nowtime = begin.tv_sec;
    nowtm = localtime(&nowtime);
    strftime(tmbuf, sizeof tmbuf, "%Y-%m-%d %H:%M:%S", nowtm);
    snprintf(buf, sizeof buf, "%s.%06ld", tmbuf, begin.tv_usec);

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Housekeeping: %s", buf);
#endif

    runHousekeepingTasks();

    /*
      Check if it is time to signal the shutdown, depending on the configuration.
      NOTE: Shutdown when done is only meaningful for pcap-dump interfaces when
      the file has been read.
    */
    if(ntop->getPrefs()->shutdownWhenDone()) {
      u_int i;

      /* Make sure all the interfaces are done with their respective packets */
      for(i = 0; i < get_num_interfaces() && getInterface(i)->read_from_pcap_dump_done(); i++) ;

      /* When they are done, signal ntopng to shutdown */
      if(i == get_num_interfaces()) {
	/* One extra housekeeping before executing tests (this assumes all flows have been walked) */
	runHousekeepingTasks();

	/* Allow host and flow checks to be executed, allow notifications to be processed (notifications.lua) */
	sleep(3);

	/* Test Script (Post Analysis) */
	if(ntop->getPrefs()->get_test_post_script_path()) {
	  const char *test_post_script_path = ntop->getPrefs()->get_test_post_script_path();

	  /* Execute as Bash script */
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "> Running Post Script '%s'", test_post_script_path);
	  Utils::exec(test_post_script_path);
	}

	ntop->getGlobals()->shutdown();
      }
    }

#ifndef __linux__
    gettimeofday(&end, NULL);

    usec_diff = Utils::usecTimevalDiff(&end, &begin);

    if(usec_diff < nap_usec)
      _usleep(nap_usec-usec_diff);
#else
    do {
      gettimeofday(&end, NULL);
      usec_diff = Utils::usecTimevalDiff(&end, &begin);

      if(usec_diff < nap_usec) {
        int maxfd = 0;
        fd_set rset;
        struct timeval tv;

#if 0
        ntop->getTrace()->traceEvent(TRACE_NORMAL,
            "Sleeping %i microsecods before doing the chores.",
            (nap_usec - usec_diff));
#endif

        FD_ZERO(&rset);

        if(inotify_fd > 0) {
          FD_SET(inotify_fd, &rset);
          maxfd = inotify_fd;
        }

        tv.tv_sec = 0, tv.tv_usec = (nap_usec - usec_diff);

        if(select(maxfd + 1, &rset, NULL, NULL, &tv) > 0) {
          if(FD_ISSET(inotify_fd, &rset)) {
            char buffer[EVENT_BUF_LEN];

            /* Consume the event */
            (void)read(inotify_fd, buffer, sizeof(buffer));

            ntop->getTrace()->traceEvent(TRACE_DEBUG, "Directory changed");
            reloadPeriodicScripts();
          }
        }
      }
    } while(usec_diff < nap_usec);
#endif
  }
}

/* ******************************************* */

bool Ntop::isLocalAddress(int family, void *addr, int16_t *network_id, u_int8_t *network_mask_bits) {
  u_int8_t nmask_bits;
  *network_id = this->localNetworkLookup(family, addr, &nmask_bits);

  if(*network_id != -1 && network_mask_bits)
    *network_mask_bits = nmask_bits;

  return(((*network_id) == -1) ? false : true);
};

/* ******************************************* */

void Ntop::getLocalNetworkIp(int16_t local_network_id, IpAddress **network_ip, u_int8_t *network_prefix) {
  char *network_address, *slash;
  *network_ip = new (std::nothrow) IpAddress();
  *network_prefix = 0;

  if (local_network_id >= 0)
    network_address = strdup(getLocalNetworkName(local_network_id));
  else
    network_address = strdup((char*)"0.0.0.0/0"); /* Remote networks */

  if((slash = strchr(network_address, '/'))) {
    *network_prefix = atoi(slash + 1);
    *slash = '\0';
  }

  if(*network_ip)
    (*network_ip)->set(network_address);
  if(network_address)
    free(network_address);
};

/* ******************************************* */

#ifdef WIN32

#include <ws2tcpip.h>
#include <iphlpapi.h>

#define MALLOC(x) HeapAlloc(GetProcessHeap(), 0, (x))
#define FREE(x)   HeapFree(GetProcessHeap(), 0, (x))

/* Note: could also use malloc() and free() */

char* Ntop::getIfName(int if_id, char *name, u_int name_len) {
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
  if(dwRetVal == ERROR_INSUFFICIENT_BUFFER) {
    pInfo = (IP_INTERFACE_INFO *)MALLOC(ulOutBufLen);
    if(pInfo == NULL) {
      return(name);
    }
  }

  // Make a second call to GetInterfaceInfo to get
  // the actual data we need
  dwRetVal = GetInterfaceInfo(pInfo, &ulOutBufLen);
  if(dwRetVal == NO_ERROR) {
    for(i = 0; i < pInfo->NumAdapters; i++) {
      if(pInfo->Adapter[i].Index == if_id) {
	int j, k, begin = 0;

	for(j = 0, k = 0; (k < name_len) && (pInfo->Adapter[i].Name[j] != '\0'); j++) {
	  if(begin) {
	    if((char)pInfo->Adapter[i].Name[j] == '}') break;
	    name[k++] = (char)pInfo->Adapter[i].Name[j];
	  } else if((char)pInfo->Adapter[i].Name[j] == '{')
	    begin = 1;
	}

	name[k] = '\0';
      }
      break;
    }
  }

  FREE(pInfo);
  return(name);
}

#endif

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
  pIPAddrTable = (MIB_IPADDRTABLE *)MALLOC(sizeof(MIB_IPADDRTABLE));

  if(pIPAddrTable) {
    // Make an initial call to GetIpAddrTable to get the
    // necessary size into the dwSize variable
    if(GetIpAddrTable(pIPAddrTable, &dwSize, 0) ==
	ERROR_INSUFFICIENT_BUFFER) {
      FREE(pIPAddrTable);
      pIPAddrTable = (MIB_IPADDRTABLE *)MALLOC(dwSize);

    }
    if(pIPAddrTable == NULL) {
      return;
    }
  }

  // Make a second call to GetIpAddrTable to get the
  // actual data we want
  if((dwRetVal = GetIpAddrTable(pIPAddrTable, &dwSize, 0)) != NO_ERROR) {
    if(FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
		     NULL, dwRetVal, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		      (LPTSTR)& lpMsgBuf, 0, NULL)) {
      LocalFree(lpMsgBuf);
    }

    return;
  }

  for(int ifIdx = 0; ifIdx < (int)pIPAddrTable->dwNumEntries; ifIdx++) {
    char name[256];

    getIfName(pIPAddrTable->table[ifIdx].dwIndex, name, sizeof(name));

    for(int id = 0; id < num_defined_interfaces; id++) {
      if((name[0] != '\0') && (strstr(iface[id]->get_name(), name) != NULL)) {
	u_int32_t bits = Utils::numberOfSetBits((u_int32_t)pIPAddrTable->table[ifIdx].dwMask);

	IPAddr.S_un.S_addr = (u_long)pIPAddrTable->table[ifIdx].dwAddr;
	snprintf(buf, bufsize, "%s/32", inet_ntoa(IPAddr));
	local_interface_addresses.addAddress(buf);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv4 NIC addr. [%s]",
				     buf, iface[id]->get_description());
	iface[id]->addInterfaceAddress(buf);

	IPAddr.S_un.S_addr = (u_long)(pIPAddrTable->table[ifIdx].dwAddr & pIPAddrTable->table[ifIdx].dwMask);
	snprintf(buf2, bufsize, "%s/%u", inet_ntoa(IPAddr), bits);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv4 local nw [%s]",
				     buf2, iface[id]->get_description());
	addLocalNetworkList(buf2);
	iface[id]->addInterfaceNetwork(buf2, buf);
      }
    }
  }

  /* TODO: add IPv6 support */
  if(pIPAddrTable) {
    FREE(pIPAddrTable);
    pIPAddrTable = NULL;
  }
#else
  struct ifaddrs *local_addresses, *ifa;
  /* buf must be big enough for an IPv6 address(e.g. 3ffe:2fa0:1010:ca22:020a:95ff:fe8a:1cf8) */
  char buf_orig[bufsize+32];
  char net_buf[bufsize+32];
  int sock = socket(AF_INET, SOCK_STREAM, 0);

  if(getifaddrs(&local_addresses) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read interface addresses");
    return;
  }

  for(ifa = local_addresses; ifa != NULL; ifa = ifa->ifa_next) {
    struct ifreq ifr;
    u_int32_t netmask;
    int cidr, ifId = -1;

    if((ifa->ifa_addr == NULL)
       || ((ifa->ifa_addr->sa_family != AF_INET)
	   && (ifa->ifa_addr->sa_family != AF_INET6))
       || ((ifa->ifa_flags & IFF_UP) == 0))
      continue;

    for(int i = 0; i < num_defined_interfaces; i++) {
      if(strstr(iface[i]->get_name(), ifa->ifa_name)) {
	ifId = i;
	break;
      }
    }

    if(ifId == -1)
      continue;

    if(ifa->ifa_addr->sa_family == AF_INET) {
      struct sockaddr_in* s4 =(struct sockaddr_in *)(ifa->ifa_addr);
      u_int32_t nm;

      memset(&ifr, 0, sizeof(ifr));
      ifr.ifr_addr.sa_family = AF_INET;
      strncpy(ifr.ifr_name, ifa->ifa_name, sizeof(ifr.ifr_name));
      ioctl(sock, SIOCGIFNETMASK, &ifr);
      netmask = ((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr.s_addr;

      cidr = 0, nm = netmask;

      while(nm) {
	cidr += (nm & 0x01);
	nm >>= 1;
      }

      if(inet_ntop(ifa->ifa_addr->sa_family, (void *)&(s4->sin_addr), buf, sizeof(buf)) != NULL) {
	char buf_orig2[bufsize+32];

	snprintf(buf_orig2, sizeof(buf_orig2), "%s/%d", buf, 32);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv4 interface address for %s",
				     buf_orig2, iface[ifId]->get_name());
	local_interface_addresses.addAddress(buf_orig2);
	iface[ifId]->addInterfaceAddress(buf_orig2);

	/* Set to zero non network bits */
	s4->sin_addr.s_addr = htonl(ntohl(s4->sin_addr.s_addr) & ntohl(netmask));
	inet_ntop(ifa->ifa_addr->sa_family, (void *)&(s4->sin_addr), buf, sizeof(buf));
	snprintf(net_buf, sizeof(net_buf), "%s/%d", buf, cidr);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv4 local network for %s",
				     net_buf, iface[ifId]->get_name());
	iface[ifId]->addInterfaceNetwork(net_buf, buf_orig2);
	addLocalNetworkList(net_buf);
      }
    } else if(ifa->ifa_addr->sa_family == AF_INET6) {
      struct sockaddr_in6 *s6 =(struct sockaddr_in6 *)(ifa->ifa_netmask);
      u_int8_t *b = (u_int8_t *)&(s6->sin6_addr);

      cidr = 0;

      for(int i=0; i<16; i++) {
	u_int8_t num_bits = __builtin_popcount(b[i]);

	if(num_bits == 0) break;
	cidr += num_bits;
      }

      s6 = (struct sockaddr_in6 *)(ifa->ifa_addr);
      if(inet_ntop(ifa->ifa_addr->sa_family,(void *)&(s6->sin6_addr), buf, sizeof(buf)) != NULL) {
	snprintf(buf_orig, sizeof(buf_orig), "%s/%d", buf, 128);

	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv6 interface address for %s",
				     buf_orig, iface[ifId]->get_name());
	local_interface_addresses.addAddresses(buf_orig);
	iface[ifId]->addInterfaceAddress(buf_orig);

	for(int i = cidr, j = 0; i > 0; i -= 8, ++j)
	  s6->sin6_addr.s6_addr[j] &= i >= 8 ? 0xff : (u_int32_t)(( 0xffU << ( 8 - i ) ) & 0xffU );

	inet_ntop(ifa->ifa_addr->sa_family,(void *)&(s6->sin6_addr), buf, sizeof(buf));
	snprintf(net_buf, sizeof(net_buf), "%s/%d", buf, cidr);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv6 local network for %s",
				     net_buf, iface[ifId]->get_name());

	iface[ifId]->addInterfaceNetwork(net_buf, buf_orig);
	addLocalNetworkList(net_buf);
      }
    }
  }

  freeifaddrs(local_addresses);

  closesocket(sock);
#endif

  ntop->getTrace()->traceEvent(TRACE_INFO, "Local Interface Addresses (System Host)");
  ntop->getTrace()->traceEvent(TRACE_INFO, "Local Networks");
}

/* ******************************************* */

void Ntop::loadGeolocation() {
  if(geo != NULL) delete geo;
  geo = new (std::nothrow) Geolocation();
}

/* ******************************************* */

void Ntop::loadMacManufacturers(char *dir) {
  if(mac_manufacturers != NULL) delete mac_manufacturers;
  if((mac_manufacturers = new (std::nothrow) MacManufacturers(dir)) == NULL)
    throw "Not enough memory";
}

/* ******************************************* */

void Ntop::setWorkingDir(char *dir) {
  snprintf(working_dir, sizeof(working_dir), "%s", dir);
  removeTrailingSlash(working_dir);
  refreshPluginsDir();
};

/* ******************************************* */

void Ntop::removeTrailingSlash(char *str) {
  int len = (int)strlen(str)-1;

  if((len > 0)
     && ((str[len] == '/') || (str[len] == '\\')))
    str[len] = '\0';
}

/* ******************************************* */

void Ntop::setCustomnDPIProtos(char *path) {
  if(path != NULL) {
    if(custom_ndpi_protos != NULL) free(custom_ndpi_protos);
    custom_ndpi_protos = strdup(path);
  }
}

/* *************************************** */

void Ntop::checkSystemScripts(ScriptPeriodicity p, lua_State *vm) {
  AlertCheckLuaEngine acle(alert_entity_system, p, NULL, vm);
  lua_State *L = acle.getState();

  lua_getglobal(L, USER_SCRIPTS_RUN_CALLBACK); /* Called function */
  lua_pushstring(L, acle.getGranularity());              /* push 1st argument */
  acle.pcall(1 /* num args */, 0);
}

/* *************************************** */

void Ntop::checkSNMPDeviceAlerts(ScriptPeriodicity p, lua_State *vm) {
  AlertCheckLuaEngine acle(alert_entity_snmp_device, p, NULL, vm);
  lua_State *L = acle.getState();

  lua_getglobal(L, USER_SCRIPTS_RUN_CALLBACK); /* Called function */
  lua_pushstring(L, acle.getGranularity());              /* push 1st argument */
  acle.pcall(1 /* num args */, 0);
}

/* ******************************************* */

void Ntop::lua_periodic_activities_stats(NetworkInterface *iface, lua_State* vm) {
  if(pa)
    pa->lua(iface, vm);
}

/* ******************************************* */

void Ntop::lua_alert_queues_stats(lua_State* vm) {
  lua_newtable(vm);

  if(getInternalAlertsQueue()) getInternalAlertsQueue()->lua(vm, "internal_alerts_queue");

  lua_pushstring(vm, "alert_queues");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

/* ******************************************* */

bool Ntop::recipients_enqueue(RecipientNotificationPriority prio, AlertFifoItem *notification, AlertEntity alert_entity) {
  return recipients.enqueue(prio, notification, alert_entity);
}

/* ******************************************* */

bool Ntop::recipient_enqueue(u_int16_t recipient_id, RecipientNotificationPriority prio, const AlertFifoItem* const notification) {
  return recipients.enqueue(recipient_id, prio, notification);
}

/* ******************************************* */

bool Ntop::recipient_dequeue(u_int16_t recipient_id, RecipientNotificationPriority prio, AlertFifoItem *notification) {
  return recipients.dequeue(recipient_id, prio, notification);
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

void Ntop::recipient_delete(u_int16_t recipient_id) {
  recipients.delete_recipient(recipient_id);
  /* Trigger a reload of periodic scripts to refresh them with new recipients */
  reloadPeriodicScripts();
}

/* ******************************************* */

void Ntop::recipient_register(u_int16_t recipient_id, AlertLevel minimum_severity, u_int8_t enabled_categories) {
  recipients.register_recipient(recipient_id, minimum_severity, enabled_categories);
  /* Trigger a reload of periodic scripts to refresh them with new recipients */
  reloadPeriodicScripts();
}

/* ******************************************* */

void Ntop::recipient_set_flow_recipients(u_int64_t flow_recipients) {
  recipients.set_flow_recipients(flow_recipients);
}

/* ******************************************* */

void Ntop::recipient_set_host_recipients(u_int64_t host_recipients) {
  recipients.set_host_recipients(host_recipients);
}

/* ******************************************* */

void Ntop::getUsers(lua_State* vm) {
  char **usernames;
  char *username;
  char *key, *val;
  int rc, i;
  size_t len;

  lua_newtable(vm);

  if((rc = ntop->getRedis()->keys("ntopng.user.*.password", &usernames)) <= 0)
    return;

  if((key = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL)
    return;
  else if((val = (char*)malloc(CONST_MAX_LEN_REDIS_VALUE)) == NULL) {
    free(key);
    return;
  }

  for(i = 0; i < rc; i++) {
    if(usernames[i] == NULL) goto next_username; /* safety check */
    if((username = strchr(usernames[i], '.')) == NULL) goto next_username;
    if((username = strchr(username+1, '.')) == NULL) goto next_username;
    len = strlen(++username);

    if(len < sizeof(".password")) goto next_username;
    username[len - sizeof(".password") + 1] = '\0';

    lua_newtable(vm);

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_FULL_NAME, username);
    if(ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, "full_name", val);
    else
      lua_push_str_table_entry(vm, "full_name", (char*) "unknown");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_PASSWORD, username);
    if(ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, "password", val);
    else
      lua_push_str_table_entry(vm, "password", (char*) "unknown");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_GROUP, username);
    if(ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, "group", val);
    else
      lua_push_str_table_entry(vm, "group", (char*)NTOP_UNKNOWN_GROUP);

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_LANGUAGE, username);
    if(ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, "language", val);
    else
      lua_push_str_table_entry(vm, "language", (char*)"");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_ALLOW_PCAP, username);
    if(ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_bool_table_entry(vm, "allow_pcap_download", true);

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_NETS, username);
    if(ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_str_table_entry(vm, CONST_ALLOWED_NETS, val);
    else
      lua_push_str_table_entry(vm, CONST_ALLOWED_NETS, (char*)"");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_ALLOWED_IFNAME, username);
    if((ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
       && val[0] != '\0')
      lua_push_str_table_entry(vm, CONST_ALLOWED_IFNAME, val);
    else
      lua_push_str_table_entry(vm, CONST_ALLOWED_IFNAME, (char*)"");

    snprintf(key, CONST_MAX_LEN_REDIS_VALUE, CONST_STR_USER_HOST_POOL_ID, username);
    if(ntop->getRedis()->get(key, val, CONST_MAX_LEN_REDIS_VALUE) >= 0)
      lua_push_uint64_table_entry(vm, "host_pool_id", atoi(val));

    lua_pushstring(vm, username);
    lua_insert(vm, -2);
    lua_settable(vm, -3);

next_username:

    if(usernames[i])
      free(usernames[i]);
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
  struct mg_connection *conn;
  char *username, *group;

  if(!ntop->getPrefs()->is_users_login_enabled())
    return(true); /* login disabled for all users, everyone's an admin */

  if((conn = getLuaVMUservalue(vm,conn)) == NULL) {
    /* this is an internal script (e.g. periodic script), admin check should pass */
    return(true);
  } else if(HTTPserver::authorized_localhost_user_login(conn))
    return(true); /* login disabled from localhost, everyone's connecting from localhost is an admin */

  if((username = getLuaVMUserdata(vm, user)) == NULL) {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(%s): NO", __FUNCTION__, "???");
    return(false); /* Unknown */
  }

  if(!strncmp(username, NTOP_NOLOGIN_USER, strlen(username)))
    return(true);

  if((group = getLuaVMUserdata(vm,group)) != NULL) {
    return(!strcmp(group, NTOP_NOLOGIN_USER) ||
           !strcmp(group, CONST_ADMINISTRATOR_USER));
  } else {
    // ntop->getTrace()->traceEvent(TRACE_WARNING, "%s(%s): NO", __FUNCTION__, username);
    return(false); /* Unknown */
  }
}

/* ******************************************* */

void Ntop::getAllowedInterface(lua_State* vm) {
  char *allowed_ifname;

  allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);

  lua_pushstring(vm, allowed_ifname != NULL ? allowed_ifname : (char*)"");
}

/* ******************************************* */

void Ntop::getAllowedNetworks(lua_State* vm) {
  char key[64], val[64];
  const char *username = getLuaVMUservalue(vm, user);

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, username ? username : "");
  lua_pushstring(vm, (ntop->getRedis()->get(key, val, sizeof(val)) >= 0) ? val : CONST_DEFAULT_ALL_NETS);
}

/* ******************************************* */

// NOTE: ifname must be of size MAX_INTERFACE_NAME_LEN
bool Ntop::getInterfaceAllowed(lua_State* vm, char *ifname) const {
  char *allowed_ifname;

  allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);

  if(ifname == NULL)
    return false;

  if((allowed_ifname == NULL) || (allowed_ifname[0] == '\0')) {
    ifname = NULL;
    return false;
  }

  strncpy(ifname, allowed_ifname, MAX_INTERFACE_NAME_LEN);
  ifname[MAX_INTERFACE_NAME_LEN - 1] = '\0';
  return true;
}

/* ******************************************* */

bool Ntop::isInterfaceAllowed(lua_State* vm, const char *ifname) const {
  char *allowed_ifname;
  bool ret;

  if(vm == NULL || ifname == NULL)
    return true; /* Always return true when no lua state is passed */

  allowed_ifname = getLuaVMUserdata(vm, allowed_ifname);

  if((allowed_ifname == NULL) || (allowed_ifname[0] == '\0')) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG,
				 "No allowed interface found for %s", ifname);
    // this is a lua script called within ntopng (no HTTP UI and user interaction, e.g. startup.lua)
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
  struct mg_connection *conn;

  if((conn = getLuaVMUservalue(vm,conn)) == NULL) {
    /* this is an internal script (e.g. periodic script), admin check should pass */
    return(true);
  }

  return getLuaVMUservalue(vm,localuser);
}

/* ******************************************* */

bool Ntop::isInterfaceAllowed(lua_State* vm, int ifid) const {
  return isInterfaceAllowed(vm, prefs->get_if_name(ifid));
}

/* ******************************************* */

bool Ntop::isPcapDownloadAllowed(lua_State* vm, const char *ifname) {
  bool allow_pcap_download = false;

  if(isUserAdministrator(vm))
    return true;

  if (isInterfaceAllowed(vm, ifname)) {
    char *username = getLuaVMUserdata(vm,user);
    ntop->getUserPermission(username, &allow_pcap_download);
  }

  return allow_pcap_download;
}

/* ******************************************* */

char *Ntop::preparePcapDownloadFilter(lua_State* vm, char *filter) {
  char *username;
  char *restricted_filter = NULL;
  char key[64], val[MAX_USER_NETS_VAL_LEN], val_cpy[MAX_USER_NETS_VAL_LEN];
  char *tmp, *net;
  int filter_len, len = 0, off = 0, num_nets = 0;

  if(isUserAdministrator(vm)) /* keep the original filter */
    goto no_restriction;

  username = getLuaVMUserdata(vm,user);
  if (username == NULL || username[0] == '\0')
    return(NULL);

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);

  if(ntop->getRedis()->get(key, val, sizeof(val)) == -1)
    goto no_restriction; /* no subnet configured for this user */

  if (strlen(val) == 0)
    goto no_restriction; /* no subnet configured for this user */

  /* compute final filter length */

  if (filter != NULL) filter_len = strlen(filter);
  else filter_len = 0;

  if (filter_len > 0)
    len = filter_len + strlen("() and ()");

  tmp = NULL;
  strcpy(val_cpy, val);
  net = strtok_r(val_cpy, ",", &tmp);
  while(net != NULL) {
    len += strlen(" or net ") + strlen(net);
    net = strtok_r(NULL, ",", &tmp);
  }

  /* build final/restricted filter */

  restricted_filter = (char*)malloc(len+1);
  if (restricted_filter == NULL)
    return(NULL);

  if (filter_len > 0)
    off += snprintf(&restricted_filter[off], len-off, "(");

  tmp = NULL;
  net = strtok_r(val, ",", &tmp);
  while(net != NULL) {
    if (strcmp(net, "0.0.0.0/0") != 0
        && strcmp(net, "::/0") != 0) {
      if (num_nets > 0) off += snprintf(&restricted_filter[off], len-off, " or ");
      off += snprintf(&restricted_filter[off], len-off, "net %s", net);
      num_nets++;
    }
    net = strtok_r(NULL, ",", &tmp);
  }

  if (filter_len > 0)
    off += snprintf(&restricted_filter[off], len-off, ") and (%s)", filter);

  return(restricted_filter);

no_restriction:
  return(strdup(filter == NULL ? "" : filter));
}

/* ******************************************* */

bool Ntop::checkUserInterfaces(const char * const user) const {
  char ifbuf[MAX_INTERFACE_NAME_LEN];

  /* Check if the user has an allowed interface and that interface has not yet been
     instantiated in ntopng (e.g, this can happen with dynamic interfaces after ntopng
     has been restarted.) */
  getUserAllowedIfname(user, ifbuf, sizeof(ifbuf));
  if(ifbuf[0] != '\0' && !isExistingInterface(ifbuf))
    return false;

  return true;
}

/* ******************************************* */

bool Ntop::getUserPasswordHashLocal(const char * const user, char *password_hash) const {
  char key[64], val[64];

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, user);

  if(ntop->getRedis()->get(key, val, sizeof(val)) < 0) {
    return(false);
  }

  sprintf(password_hash, "%s", val);
  return(true);
}

/* ******************************************* */

void Ntop::getUserGroupLocal(const char * const user, char *group) const {
  char key[64], val[64];

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, user);

  strncpy(group, ((ntop->getRedis()->get(key, val, sizeof(val)) >= 0) ? val : NTOP_UNKNOWN_GROUP), NTOP_GROUP_MAXLEN);
  group[NTOP_GROUP_MAXLEN - 1] = '\0';
}

/* ******************************************* */

bool Ntop::isLocalAuthEnabled() const {
  char val[64];

  if((ntop->getRedis()->get((char*)PREF_NTOP_LOCAL_AUTH, val, sizeof(val)) >= 0) && val[0] == '0')
    return(false);

  return(true);
}

/* ******************************************* */

bool Ntop::checkUserPasswordLocal(const char * const user, const char * const password, char *group) const {
  char val[64], password_hash[33];

  if(!isLocalAuthEnabled())
    return(false);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Checking Local auth");

  if((!strcmp(user, "admin")) &&
     (ntop->getRedis()->get((char*)TEMP_ADMIN_PASSWORD, val, sizeof(val)) >= 0) &&
     (val[0] != '\0') &&
     (!strcmp(val, password)))
    goto valid_local_user;

  if (!getUserPasswordHashLocal(user, val)) {
    return(false);
  } else {
    mg_md5(password_hash, password, NULL);

    if(strcmp(password_hash, val) != 0) {
      return(false);
    }
  }

valid_local_user:
  getUserGroupLocal(user, group);

  return(true);
}

/* ******************************************* */

// Return 1 if username/password is allowed, 0 otherwise.
bool Ntop::checkUserPassword(const char * const user, const char * const password, char *group, bool *localuser) const {
  char val[64];
  *localuser = false;

  if(!user || user[0] == '\0' || !password || password[0] == '\0')
    return(false);

#if defined(NTOPNG_PRO) && defined(HAVE_LDAP)
  if(ntop->getPro()->has_valid_license()) {
    if(ntop->getRedis()->get((char*)PREF_NTOP_LDAP_AUTH, val, sizeof(val)) >= 0) {
      if(val[0] == '1') {
        ntop->getTrace()->traceEvent(TRACE_INFO, "Checking LDAP auth");

	bool ldap_ret = false;
        bool is_admin;
	char *ldapServer = NULL, *ldapAccountType = NULL,  *ldapAnonymousBind = NULL,
	  *bind_dn = NULL, *bind_pwd = NULL, *user_group = NULL,
	  *search_path = NULL, *admin_group = NULL;

 	if(!(ldapServer = (char*)calloc(sizeof(char), MAX_LDAP_LEN))
	   || !(ldapAccountType = (char*)calloc(sizeof(char), MAX_LDAP_LEN)) /* either 'posix' or 'samaccount' */
	   || !(ldapAnonymousBind = (char*)calloc(sizeof(char), MAX_LDAP_LEN)) /* either '1' or '0' */
	   || !(bind_dn = (char*)calloc(sizeof(char), MAX_LDAP_LEN))
	   || !(bind_pwd = (char*)calloc(sizeof(char), MAX_LDAP_LEN))
	   || !(user_group = (char*)calloc(sizeof(char), MAX_LDAP_LEN))
	   || !(search_path = (char*)calloc(sizeof(char), MAX_LDAP_LEN))
	   || !(admin_group = (char*)calloc(sizeof(char), MAX_LDAP_LEN))) {
	  static bool ldap_nomem = false;

	  if(!ldap_nomem) {
	    ntop->getTrace()->traceEvent(TRACE_ERROR,
					 "Unable to allocate memory for the LDAP authentication");
	    ldap_nomem = true;
	  }

 	  goto ldap_auth_out;
	}

        ntop->getRedis()->get((char*)PREF_LDAP_SERVER, ldapServer, MAX_LDAP_LEN);
        ntop->getRedis()->get((char*)PREF_LDAP_ACCOUNT_TYPE, ldapAccountType, MAX_LDAP_LEN);
        ntop->getRedis()->get((char*)PREF_LDAP_BIND_ANONYMOUS, ldapAnonymousBind, MAX_LDAP_LEN);
        ntop->getRedis()->get((char*)PREF_LDAP_BIND_DN, bind_dn, MAX_LDAP_LEN);
        ntop->getRedis()->get((char*)PREF_LDAP_BIND_PWD, bind_pwd, MAX_LDAP_LEN);
        ntop->getRedis()->get((char*)PREF_LDAP_SEARCH_PATH, search_path, MAX_LDAP_LEN);
        ntop->getRedis()->get((char*)PREF_LDAP_USER_GROUP, user_group, MAX_LDAP_LEN);
        ntop->getRedis()->get((char*)PREF_LDAP_ADMIN_GROUP, admin_group, MAX_LDAP_LEN);

        if(ldapServer[0]) {
	  ldap_ret = LdapAuthenticator::validUserLogin(ldapServer, ldapAccountType,
						       (atoi(ldapAnonymousBind) == 0) ? false : true,
						       bind_dn[0] != '\0' ? bind_dn : NULL,
						       bind_pwd[0] != '\0' ? bind_pwd : NULL,
						       search_path[0] != '\0' ? search_path : NULL,
						       user,
						       password[0] != '\0' ? password : NULL,
						       user_group[0] != '\0' ? user_group : NULL,
						       admin_group[0] != '\0' ? admin_group : NULL,
						       &is_admin);

	  if(ldap_ret) {
            strncpy(group, is_admin ? CONST_USER_GROUP_ADMIN : CONST_USER_GROUP_UNPRIVILEGED, NTOP_GROUP_MAXLEN);
            group[NTOP_GROUP_MAXLEN - 1] = '\0';
	  }
        }

      ldap_auth_out:
	if(ldapServer) free(ldapServer);
	if(ldapAnonymousBind) free(ldapAnonymousBind);
	if(bind_dn) free(bind_dn);
	if(bind_pwd) free(bind_pwd);
	if(user_group) free(user_group);
	if(search_path) free(search_path);
	if(admin_group) free(admin_group);

	if(ldap_ret)
	  return(true);
      }
    }
  }
#endif

#ifdef HAVE_RADIUS
  if(ntop->getRedis()->get((char*)PREF_NTOP_RADIUS_AUTH, val, sizeof(val)) >= 0) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Checking RADIUS auth");

    if(val[0] == '1') {
      int result;
      bool radius_ret = false;
      char dict_path[MAX_RADIUS_LEN];
      char *radiusServer = NULL, *radiusSecret = NULL, *authServer = NULL, *radiusAdminGroup = NULL;
      rc_handle       *rh = NULL;
      VALUE_PAIR      *send = NULL, *received = NULL;

      if(!password || !password[0])
        return false;

      if(!(radiusServer = (char*)calloc(sizeof(char), MAX_RADIUS_LEN)) ||
          !(radiusSecret = (char*)calloc(sizeof(char), MAX_SECRET_LENGTH + 1)) ||
          !(radiusAdminGroup = (char*)calloc(sizeof(char), MAX_RADIUS_LEN)) ||
          !(authServer = (char*)calloc(sizeof(char), MAX_RADIUS_LEN))) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to allocate memory");
        goto radius_auth_out;
      }
      ntop->getRedis()->get((char*)PREF_RADIUS_SERVER, radiusServer, MAX_RADIUS_LEN);
      ntop->getRedis()->get((char*)PREF_RADIUS_SECRET, radiusSecret, MAX_SECRET_LENGTH + 1);
      ntop->getRedis()->get((char*)PREF_RADIUS_ADMIN_GROUP, radiusAdminGroup, MAX_RADIUS_LEN);
      if(!radiusServer[0] || !radiusSecret[0]) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: no radius server or secret set !");
        goto radius_auth_out;
      }
      snprintf(authServer, MAX_RADIUS_LEN - 1, "%s:%s", radiusServer, radiusSecret);

      /* NOTE: this is an handle to the radius lib. It will be passed to multiple functions and cleaned up at the end.
       * https://github.com/FreeRADIUS/freeradius-client/blob/master/src/radembedded.c
       */
      rh = rc_new();
      if(rh == NULL) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to allocate memory");
        goto radius_auth_out;
      }

      /* ********* */

      rh = rc_config_init(rh);

      if(rh == NULL) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: failed to init configuration");
        goto radius_auth_out;
      }

      /* RADIUS only auth */
      if(rc_add_config(rh, "auth_order", "radius", "config", 0) != 0) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Unable to set auth_order");
        goto radius_auth_out;
      }

      if(rc_add_config(rh, "radius_retries", "3", "config", 0) != 0) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Unable to set retries config");
        goto radius_auth_out;
      }

      if(rc_add_config(rh, "radius_timeout", "5", "config", 0)  != 0) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Unable to set timeout config");
        goto radius_auth_out;
      }

      snprintf(dict_path, sizeof(dict_path), "%s/other/radcli_dictionary.txt", ntop->getPrefs()->get_docs_dir());
      if(rc_add_config(rh, "dictionary", dict_path, "config", 0) != 0) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Unable to set dictionary config");
        goto radius_auth_out;
      }

      if(rc_add_config(rh, "authserver", authServer, "config", 0) != 0) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: Unable to set authserver config: \"%s\"", authServer);
        goto radius_auth_out;
      }

#ifdef HAVE_RC_TEST_CONFIG
      /* Necessary since radcli release 1.2.10 */
      if(rc_test_config(rh, "ntopng") != 0) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: rc_test_config failed");
        goto radius_auth_out;
      }
#endif

      /* ********* */

      if(rc_read_dictionary(rh, rc_conf_str(rh, "dictionary")) != 0) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to read dictionary");
        goto radius_auth_out;
      }

      if(rc_avpair_add(rh, &send, PW_USER_NAME, user, -1, 0) == NULL) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set username");
        goto radius_auth_out;
      }
      if(rc_avpair_add(rh, &send, PW_USER_PASSWORD, password, -1, 0) == NULL) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Radius: unable to set password");
        goto radius_auth_out;
      }

      ntop->getTrace()->traceEvent(TRACE_INFO, "Radius: performing auth for user %s\n", user);

      result = rc_auth(rh, 0, send, &received, NULL);
      if(result == OK_RC) {
        bool is_admin = false;

        if(radiusAdminGroup[0] != '\0') {
          VALUE_PAIR *vp = received;
          char name[sizeof(vp->name)];
          char value[sizeof(vp->strvalue)];

          while(vp != NULL) {
            if(rc_avpair_tostr(rh, vp, name, sizeof(name), value, sizeof(value)) == 0) {
              if((strcmp(name, "Filter-Id") == 0) && (strcmp(value, radiusAdminGroup) == 0))
                is_admin = true;
            }

            vp = vp->next;
          }
        }

        strncpy(group, is_admin ? CONST_USER_GROUP_ADMIN : CONST_USER_GROUP_UNPRIVILEGED, NTOP_GROUP_MAXLEN);
        group[NTOP_GROUP_MAXLEN - 1] = '\0';
        radius_ret = true;
      } else {
        switch(result) {
          case TIMEOUT_RC:
            ntop->getTrace()->traceEvent(TRACE_WARNING, "Radius Authentication timeout for user \"%s\"", user);
            break;
          case REJECT_RC:
            ntop->getTrace()->traceEvent(TRACE_WARNING, "Radius Authentication rejected for user \"%s\"", user);
            break;
          default:
            ntop->getTrace()->traceEvent(TRACE_WARNING, "Radius Authentication failure[%d]: user \"%s\"", result, user);
        }
      }

    radius_auth_out:
      if(send) rc_avpair_free(send);
      if(received) rc_avpair_free(received);
      if(rh) rc_destroy(rh);
      if(radiusAdminGroup) free(radiusAdminGroup);
      if(radiusServer) free(radiusServer);
      if(radiusSecret) free(radiusSecret);
      if(authServer) free(authServer);
      if(radius_ret)
        return(true);
    }
  }
#endif

  if(ntop->getRedis()->get((char*)PREF_NTOP_HTTP_AUTH, val, sizeof(val)) >= 0) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Checking HTTP auth");

    if(val[0] == '1') {
      int postLen;
      char *httpUrl = NULL, *postData = NULL, *returnData = NULL;
      bool http_ret = false;
      int rc = 0;
      HTTPTranferStats stats;
      HTTPAuthenticator auth;

      memset(&auth, 0, sizeof(auth));
      if(!password || !password[0])
        return false;

      postLen = 100 + strlen(user) + strlen(password);
      if(!(httpUrl = (char*)calloc(sizeof(char), MAX_HTTP_AUTHENTICATOR_LEN)) ||
          !(postData = (char*)calloc(sizeof(char), postLen + 1)) ||
          !(returnData = (char*)calloc(sizeof(char), MAX_HTTP_AUTHENTICATOR_RETURN_DATA_LEN + 1))) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "HTTP: unable to allocate memory");
        goto http_auth_out;
      }
      ntop->getRedis()->get((char*)PREF_HTTP_AUTHENTICATOR_URL, httpUrl, MAX_HTTP_AUTHENTICATOR_LEN);
      if(!httpUrl[0]) {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "HTTP: no http url set !");
        goto http_auth_out;
      }
      snprintf(postData, postLen, "{\"user\": \"%s\", \"password\": \"%s\"}",
               user, password);

      if(Utils::postHTTPJsonData(NULL, // no digest user
                                 NULL, // no digest password
                                 httpUrl,
                                 postData, 0, &stats,
                                 returnData, MAX_HTTP_AUTHENTICATOR_RETURN_DATA_LEN, &rc)) {
        if(rc == 200) {
          // parse JSON
          if(!Utils::parseAuthenticatorJson(&auth, returnData)) {
            ntop->getTrace()->traceEvent(TRACE_ERROR, "HTTP: unable to parse json answer data !");
            goto http_auth_out;
          }

          strncpy(group, auth.admin ? CONST_USER_GROUP_ADMIN : CONST_USER_GROUP_UNPRIVILEGED, NTOP_GROUP_MAXLEN);
          group[NTOP_GROUP_MAXLEN - 1] = '\0';
          if(auth.allowedNets != NULL) {
            if(!Ntop::changeAllowedNets((char*)user, auth.allowedNets)) {
              ntop->getTrace()->traceEvent(TRACE_ERROR, "HTTP: unable to set allowed nets for user %s", user);
              goto http_auth_out;
            }
          }
          if(auth.allowedIfname != NULL) {
            if(!Ntop::changeAllowedIfname((char*)user, auth.allowedIfname)) {
              ntop->getTrace()->traceEvent(TRACE_ERROR, "HTTP: unable to set allowed ifname for user %s", user);
              goto http_auth_out;
            }
          }
          if(auth.language != NULL) {
            if(!Ntop::changeUserLanguage((char*)user, auth.language)) {
              ntop->getTrace()->traceEvent(TRACE_ERROR, "HTTP: unable to set language for user %s", user);
              goto http_auth_out;
            }
          }

          http_ret = true;
        } else
          ntop->getTrace()->traceEvent(TRACE_WARNING, "HTTP: authentication rejected [code=%d]", rc);
      } else
        ntop->getTrace()->traceEvent(TRACE_WARNING, "HTTP: could not contact the HTTP authenticator");

    http_auth_out:
      Utils::freeAuthenticator(&auth);
      if(httpUrl) free(httpUrl);
      if(postData) free(postData);
      if(returnData) free(returnData);
      if(http_ret)
        return(true);
    }
  }

  /* Check local auth */
  if (checkUserPasswordLocal(user, password, group)) {
    /* mark the user as local */
    *localuser = true;
    return(true);
  }

  return(false);
}

/* ******************************************* */

static int getLoginAttempts(struct mg_connection *conn) {
  char ipbuf[32], key[128], val[16];
  int cur_attempts = 0;
  IpAddress client_addr;

  client_addr.set(mg_get_client_address(conn));
  snprintf(key, sizeof(key), CONST_STR_FAILED_LOGIN_KEY, client_addr.print(ipbuf, sizeof(ipbuf)));

  if((ntop->getRedis()->get(key, val, sizeof(val)) >= 0) && val[0])
    cur_attempts = atoi(val);

  return(cur_attempts);
}

/* ******************************************* */

bool Ntop::isBlacklistedLogin(struct mg_connection *conn) const {
  return(getLoginAttempts(conn) >= MAX_FAILED_LOGIN_ATTEMPTS);
}

/* ******************************************* */

bool Ntop::checkGuiUserPassword(struct mg_connection *conn,
          const char * const user, const char * const password,
          char *group, bool *localuser) const {
  char *remote_ip, ipbuf[64], key[128], val[16];
  int cur_attempts = 0;
  bool rv;
  IpAddress client_addr;

  client_addr.set(mg_get_client_address(conn));

  if(ntop->isCaptivePortalUser(user)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "User %s is not a gui user. Login is denied.", user);
    return false;
  }

  remote_ip = client_addr.print(ipbuf, sizeof(ipbuf));

  if((cur_attempts = getLoginAttempts(conn)) >= MAX_FAILED_LOGIN_ATTEMPTS) {
    ntop->getTrace()->traceEvent(TRACE_INFO, "Login denied for '%s' from blacklisted IP %s", user, remote_ip);
    return false;
  }

  rv = checkUserPassword(user, password, group, localuser);
  snprintf(key, sizeof(key), CONST_STR_FAILED_LOGIN_KEY, remote_ip);

  if(!rv) {
    cur_attempts++;
    snprintf(val, sizeof(val), "%d", cur_attempts);
    ntop->getRedis()->set(key, val, FAILED_LOGIN_ATTEMPTS_INTERVAL);

    if(cur_attempts >= MAX_FAILED_LOGIN_ATTEMPTS)
      ntop->getTrace()->traceEvent(TRACE_INFO, "IP %s is now blacklisted from login for %d seconds",
          remote_ip, FAILED_LOGIN_ATTEMPTS_INTERVAL);

    HTTPserver::traceLogin(user, false);
  } else
    ntop->getRedis()->del(key);

  return(rv);
}

/* ******************************************* */

bool Ntop::checkCaptiveUserPassword(const char * const user, const char * const password, char *group) const {
  bool localuser = false;
  bool rv;

  if(!ntop->isCaptivePortalUser(user)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "User %s is not a captive portal user. Login is denied.", user);
    return false;
  }

  rv = checkUserPassword(user, password, group, &localuser);

  return(rv);
}

/* ******************************************* */

bool Ntop::mustChangePassword(const char *user) {
  char val[8];

  if ((strcmp(user, "admin") == 0)
      && (ntop->getRedis()->get((char *)CONST_DEFAULT_PASSWORD_CHANGED, val, sizeof(val)) < 0
	  || val[0] == '0'))
    return true;

  return false;
}

/* ******************************************* */

/* NOTE: the admin vs local user checks must be performed by the caller */
bool Ntop::resetUserPassword(char *username, char *old_password, char *new_password) {
  char key[64];
  char password_hash[33];
  char group[NTOP_GROUP_MAXLEN];

  if((old_password != NULL) && (old_password[0] != '\0')) {
    bool localuser = false;

    if(!checkUserPassword(username, old_password, group, &localuser))
      return(false);

    if(!localuser)
      return(false);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, username);
  mg_md5(password_hash, new_password, NULL);

  if(ntop->getRedis()->set(key, password_hash, 0) < 0)
    return(false);

  return(true);
}

/* ******************************************* */

bool Ntop::changeUserFullName(const char * const username, const char * const full_name) const {
  char key[64];

  if (username == NULL || username[0] == '\0' || full_name == NULL ||
      !existsUser(username))
    return false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Changing full name to %s for %s",
			       full_name, username);

  snprintf(key, sizeof(key), CONST_STR_USER_FULL_NAME, username);
  ntop->getRedis()->set(key, full_name, 0);

  return (ntop->getRedis()->set(key, (char*) full_name, 0) >= 0);
}

/* ******************************************* */

bool Ntop::changeUserRole(char *username, char *usertype) const {
  if(usertype != NULL) {
    char key[64];

    snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);

    if(ntop->getRedis()->set(key, usertype, 0) < 0)
      return(false);
  }

  return(true);
}

/* ******************************************* */

bool Ntop::changeAllowedNets(char *username, char *allowed_nets) const {
  if(allowed_nets != NULL) {
    char key[64];

    snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);

    if(ntop->getRedis()->set(key, allowed_nets, 0) < 0)
      return(false);
  }

  return(true);
}

/* ******************************************* */

bool Ntop::changeAllowedIfname(char *username, char *allowed_ifname) const {
  /* Add as exception :// */
  char *column_slash = strstr(allowed_ifname, ":__");

  if (username == NULL || username[0] == '\0')
    return false;

  if(column_slash)
    column_slash[1] = column_slash[2] = '/';

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Changing allowed ifname to %s for %s",
			       allowed_ifname, username);

  char key[64];
  snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, username);

  if(allowed_ifname != NULL && allowed_ifname[0] != '\0') {
    return (ntop->getRedis()->set(key, allowed_ifname, 0) >= 0);
  } else {
    ntop->getRedis()->del(key);
  }

  return(true);
}

/* ******************************************* */

bool Ntop::changeUserHostPool(const char * const username, const char * const host_pool_id) const {
  if (username == NULL || username[0] == '\0')
    return false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Changing host pool id to %s for %s",
			       host_pool_id, username);

  char key[64];
  snprintf(key, sizeof(key), CONST_STR_USER_HOST_POOL_ID, username);

  if(host_pool_id != NULL && host_pool_id[0] != '\0') {
    return (ntop->getRedis()->set(key, (char*)host_pool_id, 0) >= 0);
  } else {
    ntop->getRedis()->del(key);
  }

  return(true);
}

/* ******************************************* */

bool Ntop::changeUserLanguage(const char * const username, const char * const language) const {
  if (username == NULL || username[0] == '\0')
    return false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Changing user language %s for %s",
			       language, username);

  char key[64];
  snprintf(key, sizeof(key), CONST_STR_USER_LANGUAGE, username);

  if(language != NULL && language[0] != '\0')
    return (ntop->getRedis()->set(key, (char*)language, 0) >= 0);
  else
    ntop->getRedis()->del(key);

  return(true);
}

/* ******************************************* */

bool Ntop::changeUserPermission(const char * const username, bool allow_pcap_download) const {
  char key[64];

  if (username == NULL || username[0] == '\0')
    return false;

  ntop->getTrace()->traceEvent(TRACE_DEBUG,
			       "Changing user permission [allow-pcap-download: %s] for %s",
			       allow_pcap_download ? "true" : "false", username);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_PCAP, username);

  if(allow_pcap_download)
    return (ntop->getRedis()->set(key, "1", 0) >= 0);
  else
    ntop->getRedis()->del(key);

  return(true);
}

/* ******************************************* */

bool Ntop::getUserPermission(const char * const username, bool *allow_pcap_download) const {
  char key[64], val[2];

  *allow_pcap_download = false;

  if(username == NULL || username[0] == '\0')
    return(false);

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_PCAP, username);

  if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
    if(strcmp(val, "1") == 0) *allow_pcap_download = true;

  return(true);
}

/* ******************************************* */

/*
  Assigns a unique user id to be assigned to a new ntopng user. Callers must lock.
  Assigned user id, if assignment is successful, is returned in the first param.
 */
bool Ntop::assignUserId(u_int8_t *new_user_id) {
  char cur_id_buf[8];
  int cur_id;

  for(cur_id = 0; cur_id < NTOP_MAX_NUM_USERS; cur_id++) {
    snprintf(cur_id_buf, sizeof(cur_id_buf), "%d", cur_id);

    if(!ntop->getRedis()->sismember(PREF_NTOP_USER_IDS, cur_id_buf))
      break;
  }

  if(cur_id == NTOP_MAX_NUM_USERS)
    return false; /* No more ids available */

  if(ntop->getRedis()->sadd(PREF_NTOP_USER_IDS, cur_id_buf) < 0)
    return false; /* Unable to add the newly assigned user id to the set of all user ids */

  *new_user_id = cur_id;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Assigned user id %u", *new_user_id);

  return true;
}

/* ******************************************* */

bool Ntop::existsUser(const char * const username) const {
  char key[CONST_MAX_LEN_REDIS_KEY], val[2] /* Don't care about the content */;

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
    return(true); // user already exists

  return(false);
}

/* ******************************************* */

bool Ntop::addUser(char *username, char *full_name, char *password, char *host_role,
		   char *allowed_networks, char *allowed_ifname, char *host_pool_id,
		   char *language, bool allow_pcap_download) {
  char key[CONST_MAX_LEN_REDIS_KEY];
  char password_hash[33];
  char new_user_id_buf[8];
  u_int8_t new_user_id = 0;

  users_m.lock(__FILE__, __LINE__);

  if(existsUser(username) /* User already existing */
     || !assignUserId(&new_user_id) /* Unable to assign a user id */) {
    users_m.unlock(__FILE__, __LINE__);
    return(false);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_FULL_NAME, username);
  ntop->getRedis()->set(key, full_name, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  ntop->getRedis()->set(key, (char*) host_role, 0);

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

  if(language && language[0] != '\0') {
    snprintf(key, sizeof(key), CONST_STR_USER_LANGUAGE, username);
    ntop->getRedis()->set(key, language, 0);
  }

  if(allow_pcap_download) {
    snprintf(key, sizeof(key), CONST_STR_USER_ALLOW_PCAP, username);
    ntop->getRedis()->set(key, "1", 0);
  }

  if(allowed_ifname && allowed_ifname[0] != '\0'){
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Setting allowed ifname: %s", allowed_ifname);
    snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, username);
    ntop->getRedis()->set(key, allowed_ifname, 0);
  }

  if(host_pool_id && host_pool_id[0] != '\0') {
    snprintf(key, sizeof(key), CONST_STR_USER_HOST_POOL_ID, username);
    ntop->getRedis()->set(key, host_pool_id, 0);
  }

  users_m.unlock(__FILE__, __LINE__);

  return(true);
}

/* ******************************************* */

bool Ntop::addUserAPIToken(const char * const username, const char *api_token) {
  char key[CONST_MAX_LEN_REDIS_KEY];

  snprintf(key, sizeof(key), CONST_STR_USER_API_TOKEN, username);
  ntop->getRedis()->set(key, api_token);

  return(true);
}

/* ******************************************* */

bool Ntop::isCaptivePortalUser(const char * const username) {
  char key[64], val[64];

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);

  if((ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
     && (!strcmp(val, CONST_USER_GROUP_CAPTIVE_PORTAL))) {
    return(true);
  }

  return(false);
}

/* ******************************************* */

bool Ntop::deleteUser(char *username) {
  char user_id_buf[8];
  char key[64];

  users_m.lock(__FILE__, __LINE__);

  if(!existsUser(username)) {
    users_m.unlock(__FILE__, __LINE__);
    return(false);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_ID, username);

  /* Dispose the currently assigned user id so that it can be recycled */
  if((ntop->getRedis()->get(key, user_id_buf, sizeof(user_id_buf)) >= 0)) {
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

  /*
     Delete the API Token, first from the hash of all tokens,
     then from the user
  */
  char api_token[NTOP_SESSION_ID_LENGTH];
  if(getUserAPIToken(username, api_token, sizeof(api_token))) {
    ntop->getRedis()->hashDel(NTOPNG_API_TOKEN_PREFIX, api_token);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_API_TOKEN, username);
  ntop->getRedis()->del(key);

  users_m.unlock(__FILE__, __LINE__);

  return true;
}

/* ******************************************* */

bool Ntop::getUserHostPool(char *username, u_int16_t *host_pool_id) {
  char key[64], val[64];

  snprintf(key, sizeof(key), CONST_STR_USER_HOST_POOL_ID, username ? username : "");
  if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0) {
    if(host_pool_id)
      *host_pool_id = atoi(val);
    return true;
  }

  if(host_pool_id)
    *host_pool_id = NO_HOST_POOL_ID;
  return false;
}

/* ******************************************* */

bool Ntop::getUserAllowedIfname(const char * const username, char *buf, size_t buflen) const {
  char key[64];

  snprintf(key, sizeof(key), CONST_STR_USER_ALLOWED_IFNAME, username ? username : "");

  if(ntop->getRedis()->get(key, buf, buflen) >= 0)
    return true;

  return false;
}

/* ******************************************* */

bool Ntop::getUserAPIToken(const char * const username, char *buf, size_t buflen) const {
  char key[CONST_MAX_LEN_REDIS_KEY];

  snprintf(key, sizeof(key), CONST_STR_USER_API_TOKEN, username);

  if(ntop->getRedis()->get(key, buf, buflen) >= 0)
    return true;

  return false;
}

/* ******************************************* */

void Ntop::fixPath(char *str, bool replaceDots) {
  for(int i=0; str[i] != '\0'; i++) {
#ifdef WIN32
    /*
      Allowed windows path and file characters:
      https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx#win32_file_namespaces
    */
	  if (str[i] == '/')
		  str[i] = '\\';
	  else if (str[i] == '\\')
		  continue;
	  else if ((i == 1) && (str[i] == ':')) // c:\\...
		  continue;
	  else if (str[i] == ':' || str[i] == '"' || str[i] == '|' || str[i] == '?' || str[i] == '*')
      str[i] = '_';
#endif

    if(replaceDots) {
      if((i > 0) && (str[i] == '.') && (str[i-1] == '.')) {
	// ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid path detected %s", str);
	str[i-1] = '_', str[i] = '_'; /* Invalidate the path */
      }
    }
  }
}

/* ******************************************* */

char* Ntop::getValidPath(char *__path) {
  char _path[MAX_PATH+8];
  struct stat buf;

#ifdef WIN32
  const char *install_dir = (const char *)get_install_dir();
#endif
  bool has_drive_colon = 0;

  if(strncmp(__path, "./", 2) == 0) {
    snprintf(_path, sizeof(_path), "%s/%s", startup_dir, &__path[2]);
    fixPath(_path);

    if(stat(_path, &buf) == 0) {
      free(__path);
      return(strdup(_path));
    }
  }

#ifdef WIN32
  has_drive_colon = (isalpha((int)__path[0]) && (__path[1] == ':' && (__path[2] == '\\' || __path[2] == '/')));
#endif

  if((__path[0] == '/') || (__path[0] == '\\') || has_drive_colon) {
    /* Absolute paths */

    if(stat(__path, &buf) == 0) {
      return(__path);
    }
  } else
    snprintf(_path, MAX_PATH, "%s", __path);

  /* relative paths */
  for(int i = 0; i < (int)COUNT_OF(dirs); i++) {
    if(dirs[i]) {
      char path[2*MAX_PATH];

      snprintf(path, sizeof(path), "%s/%s", dirs[i], _path);
      fixPath(path);

      if(stat(path, &buf) == 0) {
	free(__path);
	return(strdup(path));
      }
    }
  }

  free(__path);
  return(strdup(""));
}

/* ******************************************* */

void Ntop::daemonize() {
#ifndef WIN32
  int childpid;

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Parent process is exiting (this is normal)");

  signal(SIGPIPE, SIG_IGN);
  signal(SIGHUP,  SIG_IGN);
  signal(SIGCHLD, SIG_IGN);
  signal(SIGQUIT, SIG_IGN);

  if((childpid = fork()) < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Occurred while daemonizing (errno=%d)",
				 errno);
  else {
    if(!childpid) { /* child */
      int rc;

      //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Bye bye: I'm becoming a daemon...");
      rc = chdir("/");
      if(rc != 0)
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Error while moving to / directory");

      setsid();  /* detach from the terminal */

      fclose(stdin);
      fclose(stdout);
      /* fclose(stderr); */

      /*
       * clear any inherited file mode creation mask
       */
      //umask(0);

      /*
       * Use line buffered stdout
       */
      /* setlinebuf (stdout); */
      setvbuf(stdout, (char *)NULL, _IOLBF, 0);
    } else /* father */
      exit(0);
  }
#endif
}

/* ******************************************* */

void Ntop::setLocalNetworks(char *_nets) {
  char *nets;
  u_int len;

  if(_nets == NULL) return;

  len = (u_int)strlen(_nets);

  if((len > 2)
     && (_nets[0] == '"')
     && (_nets[len-1] == '"')) {
    nets = strdup(&_nets[1]);
    nets[len-2] = '\0';
  } else
    nets = strdup(_nets);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Setting local networks to %s", nets);
  addLocalNetworkList(nets);
  free(nets);
};

/* ******************************************* */

NetworkInterface* Ntop::getInterfaceById(int if_id) {
  if(if_id == SYSTEM_INTERFACE_ID)
    return(system_interface);

  for(int i=0; i<num_defined_interfaces; i++) {
    if(iface[i] && iface[i]->get_id() == if_id)
      return(iface[i]);
  }

  return(NULL);
}


/* ******************************************* */

bool Ntop::isExistingInterface(const char * const name) const {
  if(name == NULL) return(false);

  for(int i=0; i<num_defined_interfaces; i++) {
    if(!strcmp(iface[i]->get_name(), name))
      return(true);
  }

  if(!strcmp(name, getSystemInterface()->get_name()))
     return(true);

  return(false);
}

/* ******************************************* */

NetworkInterface* Ntop::getNetworkInterface(const char *name, lua_State* vm) {
  char allowed_ifname[MAX_INTERFACE_NAME_LEN] = {0};
  char *bad_num = NULL;
  int if_id;

  if(vm && getInterfaceAllowed(vm, allowed_ifname)) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "Forcing allowed interface. [requested: %s][selected: %s]",
				 name, allowed_ifname);
    return getNetworkInterface(allowed_ifname);
  }

  if(name == NULL)
    return(NULL);

  /* This method accepts both interface names or Ids.
   * Due to bad Lua number formatting, a float number may be received. */
  if_id = strtof(name, &bad_num);

  if((if_id == SYSTEM_INTERFACE_ID) || !strcmp(name, SYSTEM_INTERFACE_NAME))
    return(getSystemInterface());

  if((bad_num == NULL) || (*bad_num == '\0')) {
    /* name is a number */
    return(getInterfaceById(if_id));
  }

  /* if here, name is a string */
  for(int i = 0; i<num_defined_interfaces; i++) {
    if (!strcmp(name, iface[i]->get_name())) {
      NetworkInterface *ret_iface = isInterfaceAllowed(vm, iface[i]->get_name()) ? iface[i] : NULL;

      if(ret_iface)
	return(ret_iface);
    }
  }

  return(NULL);
};

/* ******************************************* */

int Ntop::getInterfaceIdByName(lua_State *vm, const char * const name) {
  NetworkInterface * res = getNetworkInterface(name, vm);

  if(res)
    return res->get_id();

  return(-1);
}

/* ****************************************** */

/* NOTE: the interface is deleted when this method returns false */
bool Ntop::registerInterface(NetworkInterface *_if) {
  bool rv = true;

  /* Needed as can be called concurrently by NetworkInterface::registerSubInterface */
  m.lock(__FILE__, __LINE__);

  for(int i = 0; i < num_defined_interfaces; i++) {
    if(strcmp(iface[i]->get_name(), _if->get_name()) == 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Skipping duplicated interface %s", _if->get_description());

      rv = false;
      goto out;
    }
  }

  if(num_defined_interfaces < MAX_NUM_DEFINED_INTERFACES) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Registered interface %s [id: %d]",
				 _if->get_description(), _if->get_id());
    iface[num_defined_interfaces++] = _if;

    rv = true;
    goto out;
  } else {
    static bool too_many_interfaces_error = false;
    if(!too_many_interfaces_error) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many interfaces defined");
      too_many_interfaces_error = true;
    }

    rv = false;
    goto out;
  }

out:
  if(!rv)
    delete _if;

  m.unlock(__FILE__, __LINE__);

  return(rv);
};

/* ******************************************* */

void Ntop::initInterface(NetworkInterface *_if) {
  /* Initialization related to flow-dump */
  if(ntop->getPrefs()->do_dump_flows()) {
    if(_if->initFlowDump(num_dump_interfaces))
      num_dump_interfaces++;
    _if->startDBLoop();
  }

  /* Other initialization activities */
  _if->initFlowChecksLoop();
  _if->initHostChecksLoop();
  _if->checkDisaggregationMode();
}

/* *************************************** */

void Ntop::addToPool(char *host_or_mac, u_int16_t user_pool_id) {
  char key[128], pool_buf[16];

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Adding %s as host pool member [pool id: %i]",
			       host_or_mac,
			       user_pool_id);
#endif

  snprintf(pool_buf, sizeof(pool_buf), "%u", user_pool_id);
  snprintf(key, sizeof(key), HOST_POOL_MEMBERS_KEY, pool_buf);
  ntop->getRedis()->sadd(key, host_or_mac); /* New member added */

  reloadHostPools();
}

/* ******************************************* */

void Ntop::checkReloadHostPools() {
  if(hostPoolsReloadInProgress /* Check if a reload has been requested */) {
    /* Leave this BEFORE the actual swap and new allocation to guarantee changes are always seen */
    hostPoolsReloadInProgress = false; 

    for(int i = 0; i < get_num_interfaces(); i++) {
      NetworkInterface *iface;

      if((iface = ntop->getInterface(i)) != NULL)
	iface->reloadHostPools();
    }
  }
}

/* ******************************************* */

void Ntop::checkReloadAlertExclusions() {
#ifdef NTOPNG_PRO
  if(alert_exclusions_shadow) { /* Dispose old memory if necessary */
    delete alert_exclusions_shadow;
    alert_exclusions_shadow = NULL;
  }

  if(alertExclusionsReloadInProgress /* Check if a reload has been requested */
     || !alert_exclusions /* Control groups are not allocated */) {
    alertExclusionsReloadInProgress = false; /* Leave this BEFORE the actual swap and new allocation to guarantee changes are always seen */

    alert_exclusions_shadow = alert_exclusions; /* Save the existing instance */
    alert_exclusions = new (std::nothrow) AlertExclusions(); /* Allocate a new instance */

    if(!alert_exclusions)
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory for control groups.");
  }
#endif
}

/* ******************************************* */

void Ntop::checkReloadFlowChecks() {
  if (!ntop->getPrefs()->is_pro_edition() /* Community mode */ &&
      flow_checks_loader && flow_checks_loader->getChecksEdition() != ntopng_edition_community) {
    /* Force a reload when switching to community (demo mode) */
    reloadFlowChecks();
  }

  if(flowChecksReloadInProgress /* Reload requested from the UI upon configuration changes */) {
    FlowChecksLoader *old, *tmp_flow_checks_loader = new (std::nothrow) FlowChecksLoader();

    if(!tmp_flow_checks_loader) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory for flow checks.");
      return;
    }

    tmp_flow_checks_loader->initialize();
    old = flow_checks_loader;

    /* Pass the newly allocated loader to all interfaces so they will update their checks */
    for(int i = 0; i < get_num_interfaces(); i++)
      iface[i]->reloadFlowChecks(tmp_flow_checks_loader);

    flow_checks_loader = tmp_flow_checks_loader;

    if(old) {
      sleep(2); /* Make sure nobody is using the old one */

      delete old;
    }

    flowChecksReloadInProgress = false;
  }
}

/* ******************************************* */

void Ntop::checkReloadHostChecks() {
  if (!ntop->getPrefs()->is_pro_edition() /* Community mode */ &&
      host_checks_loader && host_checks_loader->getChecksEdition() != ntopng_edition_community) {
    /* Force a reload when switching to community (demo mode) */
    reloadHostChecks();
  }

  if(hostChecksReloadInProgress /* Reload requested from the UI upon configuration changes */) {
    HostChecksLoader *old, *tmp_host_checks_loader = new (std::nothrow) HostChecksLoader();

    if(!tmp_host_checks_loader) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory for host checks.");
      return;
    }

    tmp_host_checks_loader->initialize();
    old = host_checks_loader;

    /* Pass the newly allocated loader to all interfaces so they will update their checks */
    for(int i = 0; i < get_num_interfaces(); i++)
      iface[i]->reloadHostChecks(tmp_host_checks_loader);

    host_checks_loader = tmp_host_checks_loader;

    if(old) {
      sleep(2); /* Make sure nobody is using the old one */

      delete old;
    }

    hostChecksReloadInProgress = false;
  }
}

/* ******************************************* */

/* NOTE: the multiple isShutdown checks below are necessary to reduce the shutdown time */
void Ntop::runHousekeepingTasks() {
  checkReloadHostPools();
  checkReloadAlertExclusions();
  checkReloadFlowChecks();
  checkReloadHostChecks();

  for(int i = 0; i < get_num_interfaces(); i++)
    iface[i]->runHousekeepingTasks();

#ifdef NTOPNG_PRO
  pro->runHousekeepingTasks();
#endif
}

/* ******************************************* */

void Ntop::runShutdownTasks() {
  for(int i=0; i<num_defined_interfaces; i++) {
    if(!iface[i]->isView())
      iface[i]->runShutdownTasks();
  }

  for(int i=0; i<num_defined_interfaces; i++) {
    if(iface[i]->isView())
      iface[i]->runShutdownTasks();
  }
}

/* ******************************************* */

void Ntop::shutdownPeriodicActivities() {
  if(pa) {
    delete pa;
    pa = NULL;
  }
}

/* ******************************************* */

void Ntop::shutdownInterfaces() {
  for(int i=0; i<num_defined_interfaces; i++) {
    EthStats *stats = iface[i]->getStats();

    stats->print();
    iface[i]->shutdown();
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Polling shut down [interface: %s]",
				 iface[i]->get_description());
  }
}

/* ******************************************* */

void Ntop::shutdownAll() {
  ThreadedActivity *shutdown_activity;

  if(pa) pa->sendShutdownSignal();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminating periodic activities");

  /* Wait until currently executing periodic activities are completed,
   Periodic activites should not run during interfaces shutdown */
  ntop->shutdownPeriodicActivities();

  /* Perform shutdown operations on all active interfaces */
  ntop->shutdownInterfaces();

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Executing shutdown script");

  /* Exec shutdown script before shutting down ntopng */
  if((shutdown_activity = new (std::nothrow) ThreadedActivity(SHUTDOWN_SCRIPT_PATH))) {
    /* Don't call run() as by the time the script will be run the delete below will free the memory */
    shutdown_activity->runSystemScript(time(NULL));
    delete shutdown_activity;
  }

  ntop->getGlobals()->shutdown();

#ifndef WIN32
  /*
    PID file cannot be deleted as it is under `/var/run` which, in turn, is a symlink to `/run`, which is not writable by user `ntopng`.
    As user `ntopng` has no write privileges on `/run`, the PID file cannot be deleted from inside this process. Deletion is performed
    as part of the ExecStopPost in the systemd ntopng.service file
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
}

/* **************************************************** */

void Ntop::purgeLoopBody() {
  while(!globals->isShutdown()) {
    for(u_int i = 0; i < get_num_interfaces(); i++) {
      NetworkInterface *cur_iface = getInterface(i);
      if(cur_iface) cur_iface->purgeQueuedIdleEntries();
    }

    /* Safe to sleep 100ms as entries are marked as idle by interfaces purgeIdle
     which runs every second on 1/24th of the hash table. This is run faster that 1 second
     as there may be idle entries not deleted (number of uses greater than 0) */
    _usleep(100000);
  }
}

/* **************************************************** */

static void* purgeLoop(void *arg) {
  ntop->purgeLoopBody();
  return NULL;
}

/* **************************************************** */

/*
  Thread which iterates on all available interfaces and perform the delete operations on idle hash table entries
 */
bool Ntop::startPurgeLoop() {
  if(!purgeLoop_started) {
    pthread_create(&purgeLoop, NULL, ::purgeLoop, NULL);
    purgeLoop_started = true;
  }

  return purgeLoop_started;
}

/* ******************************************* */

void Ntop::loadTrackers() {
  FILE *fd;
  char line[MAX_PATH];

  snprintf(line, sizeof(line), "%s/other/trackers.txt", prefs->get_docs_dir());

  if((fd = fopen(line, "r")) != NULL) {
    if((trackers_automa = ndpi_init_automa()) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to initialize trackers");
      fclose(fd);
      return;
    }

    while(fgets(line, MAX_PATH, fd) != NULL) {
      char *str = strdup(line);
      if (str)
        ndpi_add_string_to_automa(trackers_automa, str);
    }

    fclose(fd);
    ndpi_finalize_automa(trackers_automa);
  } else
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to load trackers file %s", line);
}

/* ******************************************* */

bool Ntop::isATrackerHost(char *host) {
  return trackers_automa && ndpi_match_string(trackers_automa, host) > 0;
}

/* ******************************************* */

void Ntop::initAllowedProtocolPresets() {
  for(u_int i=0; i<device_max_type; i++) {
    DeviceProtocolBitmask *b = ntop->getDeviceAllowedProtocols((DeviceType) i);
    NDPI_BITMASK_SET_ALL(b->clientAllowed);
    NDPI_BITMASK_SET_ALL(b->serverAllowed);
  }
}

/* ******************************************* */

void Ntop::refreshAllowedProtocolPresets(DeviceType device_type, bool client, lua_State *L, int index) {
  DeviceProtocolBitmask *b = ntop->getDeviceAllowedProtocols(device_type);

  lua_pushnil(L);

  if (b == NULL)
    return;

  if (client) NDPI_BITMASK_RESET(b->clientAllowed);
  else        NDPI_BITMASK_RESET(b->serverAllowed);

  while(lua_next(L, index) != 0) {
    u_int key_proto = lua_tointeger(L, -2);
    int t = lua_type(L, -1);

    if((int)key_proto < 0) continue;

    switch (t) {
      case LUA_TNUMBER:
      {
        u_int value_action = lua_tointeger(L, -1);
        if (value_action) {
          if (client) NDPI_BITMASK_ADD(b->clientAllowed, key_proto);
          else        NDPI_BITMASK_ADD(b->serverAllowed, key_proto);
        }
      }
      break;
      default:
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error: type %d not handled", t);
      break;
    }

    lua_pop(L, 1);
  }
}

/* ******************************************* */

#ifdef NTOPNG_PRO

bool Ntop::addIPToLRUMatches(u_int32_t client_ip,
			     u_int16_t user_pool_id,
			     char *label, char *ifname) {
  for(int i=0; i<num_defined_interfaces; i++) {
    if(iface[i]->is_bridge_interface() && (strcmp(iface[i]->get_name(), ifname) == 0)) {
      iface[i]->addIPToLRUMatches(client_ip, user_pool_id, label);
      return true;
    }
  }

  return false;
}

/* ******************************************* */

bool Ntop::addToNotifiedInformativeCaptivePortal(u_int32_t client_ip) {
  for(int i = 0; i < num_defined_interfaces; i++) {
    if(iface[i]->is_bridge_interface()) /* TODO: handle multiple interfaces separately */
      iface[i]->addToNotifiedInformativeCaptivePortal(client_ip);
  }

  return true;
}

#endif

/* ******************************************* */

DeviceProtoStatus Ntop::getDeviceAllowedProtocolStatus(DeviceType dev_type, ndpi_protocol proto, u_int16_t pool_id, bool as_client) {
  /* Check if this application protocol is allowd for the specified device type */
  DeviceProtocolBitmask *bitmask = getDeviceAllowedProtocols(dev_type);
  NDPI_PROTOCOL_BITMASK *direction_bitmask = as_client ? (&bitmask->clientAllowed) : (&bitmask->serverAllowed);

#ifdef HAVE_NEDGE
  /* On nEdge the concept of device protocol policies is only applied to unassigned devices on LAN */
  if(pool_id != NO_HOST_POOL_ID)
    return device_proto_allowed;
#endif

  /* Always allow network critical protocols */
  if(Utils::isCriticalNetworkProtocol(proto.master_protocol) ||
      Utils::isCriticalNetworkProtocol(proto.app_protocol))
    return device_proto_allowed;

  if((proto.master_protocol != NDPI_PROTOCOL_UNKNOWN) &&
      (!NDPI_ISSET(direction_bitmask, proto.master_protocol))) {
    return device_proto_forbidden_master;
  } else if((!NDPI_ISSET(direction_bitmask, proto.app_protocol))) {
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
  if(Utils::getCPULoad(&cpu_stats))
    cpu_load = cpu_stats.load;
  else
    cpu_load = -1;
}

/* ******************************************* */

bool Ntop::getCPULoad(float *out) {
  bool rv;

  if(cpu_load >= 0) {
    *out = cpu_load;
    rv = true;
  } else
    rv = false;

  return(rv);
}

/* ******************************************* */

void Ntop::loadProtocolsAssociations(struct ndpi_detection_module_struct *ndpi_str) {
  char **keys, **values;
  Redis *redis = getRedis();
  int rc;

  if(!redis)
    return;

  rc = redis->hashGetAll(CUSTOM_NDPI_PROTOCOLS_ASSOCIATIONS_HASH, &keys, &values);

  if(rc > 0) {
    for(int i = 0; i < rc; i++) {
      u_int16_t protoId;
      ndpi_protocol_category_t protoCategory;

      if(keys[i] && values[i]) {
        protoId = atoi(keys[i]);
        protoCategory = (ndpi_protocol_category_t) atoi(values[i]);

        ntop->getTrace()->traceEvent(TRACE_INFO, "Loading protocol association: ID %d -> category %d", protoId, protoCategory);
        ndpi_set_proto_category(ndpi_str, protoId, protoCategory);
      }

      if(values[i]) free(values[i]);
      if(keys[i]) free(keys[i]);
    }

    free(keys);
    free(values);
  }
}

/* ******************************************* */

struct ndpi_detection_module_struct* Ntop::initnDPIStruct() {
  struct ndpi_detection_module_struct *ndpi_s = ndpi_init_detection_module(ndpi_no_prefs);
  ndpi_port_range d_port[MAX_DEFAULT_PORTS];
  NDPI_PROTOCOL_BITMASK all;

  if(ndpi_s == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to initialize nDPI");
    exit(-1);
  }

  if(getCustomnDPIProtos() != NULL)
    ndpi_load_protocols_file(ndpi_s, getCustomnDPIProtos());

  memset(d_port, 0, sizeof(d_port));
  ndpi_set_proto_defaults(ndpi_s, NDPI_PROTOCOL_UNRATED, NTOPNG_NDPI_OS_PROTO_ID,
			  (char*)"Operating System",
			  NDPI_PROTOCOL_CATEGORY_SYSTEM_OS, d_port, d_port);

  // enable all protocols
  NDPI_BITMASK_SET_ALL(all);
  ndpi_set_protocol_detection_bitmask2(ndpi_s, &all);

  // load custom protocols
  loadProtocolsAssociations(ndpi_s);

  return(ndpi_s);
}

/* **************************************************** */

void Ntop::cleanShadownDPI() {
  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%p)", __FUNCTION__, ndpi_struct_shadow);

  ndpi_exit_detection_module(ndpi_struct_shadow);
  ndpi_struct_shadow = NULL;
}

/* **************************************************** */

/* Operations are performed in the followin order:
 *
 * 1. initnDPIReload()
 * 2. ... nDPILoadIPCategory/nDPILoadHostnameCategory() ...
 * 3. finalizenDPIReload()
 * 4. cleanShadownDPI()
 */
bool Ntop::initnDPIReload() {
  ntop->getTrace()->traceEvent(TRACE_INFO, "Started nDPI reload %s",
			       ndpiReloadInProgress ? "[IN PROGRESS]" : "");

  if(ndpiReloadInProgress) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error: nested nDPI category reload");
    return(false);
  }

  ndpiReloadInProgress = true;
  cleanShadownDPI();

  /* No need to dedicate another variable for the reload, we can use the shadow itself */
  ndpi_struct_shadow = initnDPIStruct();
  return(true);
}

/* **************************************************** */

void Ntop::finalizenDPIReload() {
  ntop->getTrace()->traceEvent(TRACE_INFO, "%s(%p)", __FUNCTION__, ndpi_struct_shadow);

  if(!ndpiReloadInProgress) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Internal error: nested nDPI category reload");
    return;
  }

  if(ndpi_struct_shadow) {
    struct ndpi_detection_module_struct *old_struct;

    ntop->getTrace()->traceEvent(TRACE_INFO, "Going to reload custom categories");

    /* The new categories were loaded on the current ndpi_struct_shadow */
    ndpi_enable_loaded_categories(ndpi_struct_shadow);
    ndpi_finalize_initialization(ndpi_struct_shadow);

    ntop->getTrace()->traceEvent(TRACE_INFO, "nDPI finalizing reload...");

    old_struct = ndpi_struct;
    ndpi_struct = ndpi_struct_shadow;
    ndpi_struct_shadow = old_struct;

    /* Need to update the existing hosts */
    for(u_int i = 0; i<get_num_interfaces(); i++) {
      if(getInterface(i))
	getInterface(i)->reloadHostsBlacklist();
    }

    ntop->getTrace()->traceEvent(TRACE_INFO, "nDPI reload completed");
    ndpiReloadInProgress = false;
  }
}

/* *************************************** */

void Ntop::nDPILoadIPCategory(char *what, ndpi_protocol_category_t id) {
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p) [%s]", __FUNCTION__, ndpi_struct_shadow, what);

  if(what && ndpi_struct_shadow)
    ndpi_load_ip_category(ndpi_struct_shadow, what, id);
}

/* *************************************** */

void Ntop::nDPILoadHostnameCategory(char *what, ndpi_protocol_category_t id) {
  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p) [%s]", __FUNCTION__, ndpi_struct_shadow, what);

  if(what && ndpi_struct_shadow)
    ndpi_load_hostname_category(ndpi_struct_shadow, what, id);
}

/* *************************************** */

int Ntop::nDPILoadMaliciousJA3Signatures(const char *file_path) {
  int n = 0;

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s(%p) [%s]", __FUNCTION__, ndpi_struct_shadow, what);

  if(file_path && ndpi_struct_shadow)
    n = ndpi_load_malicious_ja3_file(ndpi_struct_shadow, file_path);

  return n;
}

/* *************************************** */

ndpi_protocol_category_t Ntop::get_ndpi_proto_category(u_int protoid) {
  ndpi_protocol proto;

  proto.app_protocol = NDPI_PROTOCOL_UNKNOWN;
  proto.master_protocol = protoid;
  proto.category = NDPI_PROTOCOL_CATEGORY_UNSPECIFIED;
  return get_ndpi_proto_category(proto);
}

/* *************************************** */

void Ntop::setnDPIProtocolCategory(u_int16_t protoId, ndpi_protocol_category_t protoCategory) {
  ndpi_set_proto_category(get_ndpi_struct(), protoId, protoCategory);
}

/* *************************************** */

void Ntop::reloadPeriodicScripts() {
  /*
    Request a reload of all the VMs currently executing periodic activities
   */
  if(pa) pa->reloadVMs();
};

/* *************************************** */

void Ntop::refreshPluginsDir() {
#ifdef WIN32
  snprintf(plugins0_dir, sizeof(plugins0_dir), "%s\\plugins0", get_working_dir());
  snprintf(plugins1_dir, sizeof(plugins1_dir), "%s\\plugins1", get_working_dir());
#else
  snprintf(plugins0_dir, sizeof(plugins0_dir), "%s/plugins0", get_working_dir());
  snprintf(plugins1_dir, sizeof(plugins1_dir), "%s/plugins1", get_working_dir());
#endif
}

/* ******************************************* */

inline int16_t Ntop::localNetworkLookup(int family, void *addr, u_int8_t *network_mask_bits) {
  return(local_network_tree.findAddress(family, addr, network_mask_bits));
}

/* **************************************** */

u_int8_t Ntop::getLocalNetworkId(const char *address_str) {
  u_int8_t i;

  for(i = 0; i< local_network_tree.getNumAddresses(); i++) {
    if(!strcmp(address_str, local_network_names[i]))
      return(i);
  }

  return((u_int8_t)-1);
}

/* ******************************************* */

bool Ntop::addLocalNetwork(char *_net) {
  char *net, *position_ptr;
  char alias[64] = "";

  int id = local_network_tree.getNumAddresses(), pos = 0;

  if(id >= CONST_MAX_NUM_NETWORKS) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many networks defined (%d): ignored %s",
				 id, _net);
    return(false);
  }

  // Getting the pointer and the position to the "=" indicator
  position_ptr = strstr(_net, "=");
	pos = (position_ptr == NULL ? 0 : position_ptr - _net);

  if(pos) {
    // "=" indicator is present inside the string
    // Separating the alias from the network
    net = strndup(_net, pos);
    memcpy(alias, position_ptr + 1, strlen(_net) - pos - 1);
  } else
    net = strdup(_net);

  if(net == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    return(false);
  }

  // Adding the Network to the local Networks
  local_network_tree.addAddresses(net);

  local_network_names[id] = strdup(net);

  // Adding, if available, the alias
  if(pos)
    local_network_aliases[id] = strdup(alias);

  if(net)
    free(net);  

  return(true);
}

/* ******************************************* */

bool Ntop::getLocalNetworkAlias(lua_State *vm, u_int8_t network_id) {
  char *alias = local_network_aliases[network_id];

  // Checking if the network has an alias
  if(!alias)
    return false;

  lua_pushstring(vm, alias);

  return true;
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
void Ntop::addLocalNetworkList(const char *rule) {
  char *tmp, *net = strtok_r((char *) rule, ",", &tmp);

  while(net != NULL) {
    if(!addLocalNetwork(net)) return;
    net = strtok_r(NULL, ",", &tmp);
  }
}

/* ******************************************* */

bool Ntop::luaFlowCheckInfo(lua_State *vm, std::string check_name) const {
  FlowChecksLoader *fcl = flow_checks_loader;
  if(fcl) return fcl->luaCheckInfo(vm, check_name);

  return false;
}

/* ******************************************* */

bool Ntop::luaHostCheckInfo(lua_State *vm, std::string check_name) const {
  HostChecksLoader *hcl = host_checks_loader;
  if(hcl) return hcl->luaCheckInfo(vm, check_name);

  return false;
}

/* ******************************************* */

#ifndef HAVE_NEDGE

bool Ntop::broadcastIPSMessage(char *msg) {
  bool rc = false;
  
  if(prefs->getZMQPublishEventsURL() == NULL)
    return(false);
  
  /* Jeopardized users_m lock :-) */
  users_m.lock(__FILE__, __LINE__);
  
  if(zmqPublisher == NULL) {
    try {
      zmqPublisher = new ZMQPublisher(prefs->getZMQPublishEventsURL());
    } catch(...) {
      zmqPublisher = NULL;
    }
  }
  
  if(!zmqPublisher) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to create ZMQ publisher");
    users_m.unlock(__FILE__, __LINE__);
    return(false);
  }

  if(msg)
    rc = zmqPublisher->sendIPSMessage(msg);
  
  users_m.unlock(__FILE__, __LINE__);

  return(rc);
}

#endif

