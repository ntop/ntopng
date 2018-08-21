/*
 *
 * (C) 2013-18 - ntop.org
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

extern "C" {
  extern char* rrd_strversion(void);
};

AfterShutdownAction afterShutdownAction = after_shutdown_nop;

/* ******************************** */

void sighup(int sig) {
  ;
}

/* ******************************** */

void sigproc(int sig) {
  static int called = 0;
  
  if(called) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Ok I am leaving now");
    _exit(0);
  } else {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Shutting down...");
    called = 1;
    ntop->getGlobals()->requestShutdown();
  }
  
  ntop->shutdownAll();

  delete ntop;

#ifdef __linux__
  switch(afterShutdownAction) {
    case after_shutdown_nop: break;
    case after_shutdown_reboot: system("systemctl start systemd-reboot"); break;
    case after_shutdown_poweroff: system("systemctl start systemd-poweroff"); break;
    default: break;
  }
#endif
  
  _exit(0);
}

/* ******************************************* */

#ifdef WIN32

void initWinsock32() {
  WORD wVersionRequested;
  WSADATA wsaData;
  int err;

  wVersionRequested = MAKEWORD(2, 0);
  err = WSAStartup( wVersionRequested, &wsaData );
  if( err != 0 ) {
    /* Tell the user that we could not find a usable */
    /* WinSock DLL.                                  */
    printf("FATAL ERROR: unable to initialize Winsock 2.x.\n");
    exit(-1);
  }
}

/* ******************************** */

extern "C" {
int ntop_main(int argc, char *argv[])
#else
int main(int argc, char *argv[])
#endif
{
  Prefs *prefs = NULL;
  char *ifName;
  int rc;
  char *affinity;
  int indexAffinity = 0;
  char *core_id_s = NULL;
  int core_id;
  char path[MAX_PATH];
  FILE *fd;
  ThreadedActivity *boot_activity;
    
#ifdef WIN32
  initWinsock32();
#endif

  if((ntop = new(std::nothrow)  Ntop(argv[0])) == NULL) _exit(0);
  if((prefs = new(std::nothrow) Prefs(ntop)) == NULL)   _exit(0);

#ifndef WIN32
  if((argc >= 2) && (argv[1][0] != '-')) {
    rc = prefs->loadFromFile(argv[1]);
    if(argc > 2)
      rc = prefs->loadFromCLI(argc, argv);
  } else
#endif
    rc = prefs->loadFromCLI(argc, argv);

  if(rc < 0) return(-1);

  ntop->registerPrefs(prefs, false);

  if((boot_activity = new ThreadedActivity(BOOT_SCRIPT_PATH))) {
    /* Don't call run() as by the time the script will be run the delete below will free the memory */
    /* NOTE: preferences restore from file is handled here */
    boot_activity->runScript();
    delete boot_activity;
  }
  
  prefs->registerNetworkInterfaces();

  if(prefs->get_num_user_specified_interfaces() == 0) {
    /* We add all interfaces available on this host */
    prefs->add_default_interfaces();
  }

#ifdef NTOPNG_PRO
  ntop->registerNagios();
#endif

  prefs->reloadPrefsFromRedis();
  prefs->validate();
  
  if(prefs->daemonize_ntopng())
    ntop->daemonize();

#ifdef __linux__
  /* Store number of CPUs before dropping privileges */
  ntop->setNumCPUs(sysconf(_SC_NPROCESSORS_ONLN));
  ntop->getTrace()->traceEvent(TRACE_INFO, "System has %d CPU cores", ntop->getNumCPUs());
#endif

  affinity = prefs->get_cpu_affinity();

  for(int i=0; i<MAX_NUM_INTERFACES; i++) {
    NetworkInterface *iface = NULL;

    if((ifName = ntop->get_if_name(i)) == NULL
       || !strncmp(ifName, "view:", 5) /* Defer view interfaces init */)
      continue;

    try {
      /* [ zmq-collector.lua@tcp://127.0.0.1:5556 ] */
#ifndef HAVE_NEDGE
      if(!strcmp(ifName, "dummy")) {
	iface = new DummyInterface();
      } else if((strstr(ifName, "tcp://") || strstr(ifName, "ipc://"))) {
	char *at = strchr(ifName, '@');
	char *endpoint;

	if(at != NULL)
	  endpoint = &at[1];
	else
	  endpoint = ifName;

	iface = new CollectorInterface(endpoint);
#if defined(HAVE_PF_RING) && (!defined(NTOPNG_EMBEDDED_EDITION)) && (!defined(__i686__)) && (!defined(__ARM_ARCH))
      } else if(strstr(ifName, "zcflow:")) {
	iface = new ZCCollectorInterface(ifName);
#endif
      } else
#endif
	{
	iface = NULL;

#if defined(NTOPNG_PRO) && !defined(WIN32)
	if(strncmp(ifName, "bridge:", 7) == 0) {
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "\n");
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Inline/bridge capabilities have now been moved in ntopng Edge (nEdge)");
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "For more information and free migration see:");
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "https://www.ntop.org/support/faq/migration-of-ntopng-inline-pro-enterprises-licenses-to-ntopng-edge-nedge/");
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "\n");
	}
#endif

#if defined(HAVE_NEDGE)
        if(iface == NULL && strncmp(ifName, "nf:", 3) == 0)
          iface = new NetfilterInterface(ifName);
#endif
	
#ifdef HAVE_PF_RING
	if((iface == NULL) && (!strstr(ifName, ".pcap"))) {
	  errno = 0;
	  iface = new PF_RINGInterface(ifName);
	}
#endif
      }
    } catch(int err) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "An exception occurred during %s interface creation[%d]: %s. Falling back to pcap",
				   ifName, err, strerror(err));
      if(iface) delete iface;
      iface = NULL;
    } catch(...) {
      ntop->getTrace()->traceEvent(TRACE_INFO, "An exception occurred during %s interface creation. Falling back to pcap", ifName);
      if(iface) delete iface;
      iface = NULL;
    }

#ifndef HAVE_NEDGE
    if(iface == NULL) {
      try {
	errno = 0;
	iface = new PcapInterface(ifName);
      } catch(int err) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "An exception occurred during %s interface creation[%d]: %s",
				     ifName, err, strerror(err));
	if(iface) delete iface;
	iface = NULL;
      }
    }
#endif

    if(iface) {
      /* NOTE: allocate the PacketDumper only after setting the pcap_datalink_type */
      iface->loadDumpPrefs();

      if(affinity != NULL) {
	char *tmp;
	
	if(indexAffinity == 0)
	  core_id_s = strtok_r(affinity, ",", &tmp);
	else 
	  core_id_s = strtok_r(NULL, ",", &tmp);
            
	if(core_id_s != NULL)
	  core_id = atoi(core_id_s);
	else
	  core_id = indexAffinity;
      
	indexAffinity++;
	iface->setCPUAffinity(core_id);
      }

      if(prefs->get_packet_filter())
	iface->set_packet_filter(prefs->get_packet_filter());

      ntop->registerInterface(iface);
    }
  } /* for */

  /* Instantiated deferred view interfaces */
  for(int i = 0; i < MAX_NUM_INTERFACES; i++) {
    NetworkInterface *iface = NULL;

    if((ifName = ntop->get_if_name(i)) == NULL || strncmp(ifName, "view:", 5))
      continue;

    if((iface = new ViewInterface(ifName)))
      ntop->registerInterface(iface);
  }

#ifndef HAVE_NEDGE
  ntop->createExportInterface();
  ntop->getElasticSearch()->startFlowDump();
  ntop->getLogstash()->startFlowDump();
#endif
  
  if(ntop->getFirstInterface() == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Startup error: missing super-user privileges ?");
    exit(0);
  }

#ifndef WIN32
  if(prefs->get_pid_path() != NULL) {
    FILE *fd;

    fd = fopen(prefs->get_pid_path(), "w");
    if(fd != NULL) {
      int n;

      chmod(prefs->get_pid_path(), CONST_DEFAULT_FILE_MODE);
      n = fprintf(fd, "%u\n", getpid());
      fclose(fd);

      if(n > 0) {
	chmod(prefs->get_pid_path(), 0644);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "PID stored in file %s",
				     prefs->get_pid_path());
      } else
	ntop->getTrace()->traceEvent(TRACE_ERROR, "The PID file %s is empty: is your disk full perhaps ?",
				     prefs->get_pid_path());
    } else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to store PID in file %s: %s",
				   prefs->get_pid_path(), strerror(errno));
  }
#endif

  /*
    It's safe to drop privileges now if http and https ports
    are non-privileged. Otherwise it is necessary to delay
    the privilege drop after the web server bind()
   */
  if(prefs->do_change_user()
     && (prefs->get_http_port()  >= 1024)
     && (prefs->get_https_port() >= 1024))
    Utils::dropPrivileges();

  ntop->loadGeolocation(prefs->get_docs_dir());
  ntop->loadMacManufacturers(prefs->get_docs_dir());
  ntop->loadTrackers();
  ntop->registerHTTPserver(new HTTPserver(prefs->get_docs_dir(), prefs->get_scripts_dir()));

  /*
    If mysql flows dump is enabled, then it is necessary to create
    and update the database schema
   */
  if(prefs->do_dump_flows_on_mysql()) {
    /* create the schema only one time, no need to call it for every interface */
    if(!ntop->getFirstInterface()->createDBSchema()){
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to create database schema, quitting.");
      exit(EXIT_FAILURE);
    }
  } else if(prefs->do_read_flows_from_nprobe_mysql()) {
    /* Create a view only one time for the first interface */
    if(!ntop->getFirstInterface()->createNprobeDBView()){
      ntop->getTrace()->traceEvent(TRACE_ERROR,
				   "Unable to create a view on the nProbe database.");
      exit(EXIT_FAILURE);
    }
  }

  /*
    We have created the network interface and thus changed user. Let's now check
    if we can write on the data directory
  */
  Utils::mkdir_tree(ntop->get_working_dir());

  snprintf(path, sizeof(path), "%s/.test", ntop->get_working_dir());
  ntop->fixPath(path);
  
  if((fd = fopen(path, "w")) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Unable to write on %s [%s]: %s. Please specify a different directory (-d)",
				 ntop->get_working_dir(), path, strerror(errno));
    exit(EXIT_FAILURE);
  } else {
    chmod(path, CONST_DEFAULT_FILE_MODE);
    fclose(fd); /* All right */
    unlink(path);
  }

  if(prefs->is_log_to_file_enabled()
#ifndef WIN32
     || prefs->daemonize_ntopng()
#endif
     ) {
      char path[MAX_PATH];

      Utils::mkdir_tree(ntop->get_data_dir());
      Utils::mkdir_tree(ntop->get_working_dir());
      snprintf(path, sizeof(path), "%s/ntopng.log", ntop->get_working_dir() /* "C:\\Windows\\Temp" */);
      ntop->fixPath(path);      
      ntop->registerLogFile(path);
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Logging onto %s", path);
    }

  if(prefs->get_httpbl_key() != NULL)
    ntop->setHTTPBL(new HTTPBL(prefs->get_httpbl_key()));

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Working directory: %s",
			       ntop->get_working_dir());
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Scripts/HTML pages directory: %s",
			       ntop->get_install_dir());

#ifndef WIN32
  signal(SIGHUP,  sighup);
  signal(SIGINT,  sigproc);
  signal(SIGTERM, sigproc);
  signal(SIGINT,  sigproc);
#endif

#if defined(WIN32) && defined(DEMO_WIN32)
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "-----------------------------------------------------------");
  ntop->getTrace()->traceEvent(TRACE_WARNING, "This is a demo version of ntopng limited to %d packets", MAX_NUM_PACKETS);
  ntop->getTrace()->traceEvent(TRACE_WARNING, "Please go to http://shop.ntop.org for getting the full version");
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "-----------------------------------------------------------");
#endif

  ntop->start();

  if(ntop->getGlobals()->isShutdownRequested()) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Shutdown requested: hold on");
    sleep(3); /* Wait until all open activities have been completed */
    ntop->shutdown();
  }
  
  sigproc(0);
  delete ntop;
 
  return(0);
}

#ifdef WIN32
}
#endif
