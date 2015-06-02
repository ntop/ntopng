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

#ifdef WIN32
#include <shlobj.h> /* SHGetFolderPath() */
#else
#include <ifaddrs.h>
#endif

Ntop *ntop;

static const char* dirs[] = {
  NULL,
#ifndef WIN32
  CONST_DEFAULT_INSTALL_DIR,
#else
  NULL,
#endif
  CONST_ALT_INSTALL_DIR,
  NULL
};

/* ******************************************* */

Ntop::Ntop(char *appName) {
  ntop = this;
  globals = new NtopGlobals();
  pa = new PeriodicActivities();
  address = new AddressResolution();
  categorization = NULL;
  httpbl = NULL;
  custom_ndpi_protos = NULL;
  prefs = NULL, redis = NULL;
  num_cpus = -1;
#ifdef NTOPNG_PRO
  redis_pro = NULL;
#endif
  num_defined_interfaces = num_defined_interface_views = 0;
  local_interface_addresses = New_Patricia(128);
  export_interface = NULL;
  historical_interface_id = -1;
  start_time = 0; /* It will be initialized by start() */
  memset(iface, 0, sizeof(iface));
  httpd = NULL, runtimeprefs = NULL, geo = NULL;

#ifdef WIN32
  if(SHGetFolderPath(NULL, CSIDL_PERSONAL, NULL,
		     SHGFP_TYPE_CURRENT, working_dir) != S_OK) {
    strcpy(working_dir, "C:\\Windows\\Temp" /* "\\ntopng" */); // Fallback: it should never happen
  }

  // Get the full path and filename of this program
  if(GetModuleFileName(NULL, startup_dir, sizeof(startup_dir)) == 0) {
    startup_dir[0] = '\0';
  } else {
    for(int i=(int)strlen(startup_dir)-1; i>0; i--)
      if(startup_dir[i] == '\\') {
	startup_dir[i] = '\0';
	break;
      }
  }

  snprintf(install_dir, sizeof(install_dir), "%s", startup_dir);

  dirs[0] = startup_dir;
  dirs[1] = install_dir;
#else
  /* Folder will be created lazily, avoid creating it now */
  snprintf(working_dir, sizeof(working_dir), "%s/ntopng", CONST_DEFAULT_WRITABLE_DIR);

  umask (0);

  if(getcwd(startup_dir, sizeof(startup_dir)) == NULL)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Occurred while checking the current directory (errno=%d)", errno);

  dirs[0] = startup_dir;

  install_dir[0] = '\0';

  for(int i=0; dirs[i] != NULL; i++) {
    char path[MAX_PATH];
    struct stat statbuf;

    snprintf(path, sizeof(path), "%s/scripts/lua/index.lua", dirs[i]);
    fixPath(path);

    if(stat(path, &statbuf) == 0) {
#ifdef __OpenBSD__
      strlcpy(install_dir, dirs[i], sizeof(install_dir));
#else
      strcpy(install_dir, dirs[i]);
#endif
      break;
    }
  }
#endif

#ifdef NTOPNG_PRO
  pro = new NtopPro();
  nagios_manager = NULL;
  flow_checker = new FlowChecker();

  if((pro == NULL)
     || (flow_checker == NULL)) {
    throw "Not enough memory";
  }
#else
  pro = NULL;
#endif

  // printf("--> %s [%s]\n", startup_dir, appName);

  initTimezone();

  udp_socket = socket(AF_INET, SOCK_DGRAM, 0);
}

/* ******************************************* */

/*
  Setup timezone differences

  We call it all the time as daylight can change
  during the night and thus we need to have it "fresh"
*/

void Ntop::initTimezone() {
  time_t now = time(NULL);
  time_offset =(long)(mktime(localtime(&now)) - mktime(gmtime(&now)));
  memset(ifaceViews, 0, sizeof(ifaceViews));
}

/* ******************************************* */

Ntop::~Ntop() {
  for(int i=0; i<num_defined_interfaces; i++) {
    iface[i]->shutdown();
    delete(iface[i]);
  }
  for(int i = 0 ; i < num_defined_interface_views ; i++) {
    if (ifaceViews[i]) delete(ifaceViews[i]);
    ifaceViews[i] = NULL;
  }

  if(udp_socket != -1) close(udp_socket);

  if(httpbl) delete httpbl;
  if(httpd)  delete httpd;
  if(custom_ndpi_protos) delete(custom_ndpi_protos);

  Destroy_Patricia(local_interface_addresses, NULL);
  delete address;
  delete pa;
  if(geo)   delete geo;
  if(redis) delete redis;
  delete globals;
  delete prefs;
  delete runtimeprefs;

#ifdef NTOPNG_PRO
  if(pro) delete pro;
  if(nagios_manager) delete nagios_manager;
  if(flow_checker) delete flow_checker;
  if(redis_pro) delete redis_pro;
#endif
}

/* ******************************************* */

void Ntop::registerPrefs(Prefs *_prefs) {
  struct stat statbuf;

  prefs = _prefs;

  if(stat(prefs->get_data_dir(), &statbuf)
     || (!(statbuf.st_mode & S_IFDIR))  /* It's not a directory */
     || (!(statbuf.st_mode & S_IWRITE)) /* It's not writable    */) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid directory %s specified",
				 prefs->get_data_dir());
    _exit(-1);
  }

  if(stat(prefs->get_callbacks_dir(), &statbuf)
     || (!(statbuf.st_mode & S_IFDIR))  /* It's not a directory */
     || (!(statbuf.st_mode & S_IWRITE)) /* It's not writable    */) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid directory %s specified",
				 prefs->get_callbacks_dir());
    _exit(-1);
  }

  if(prefs->get_local_networks()) {
    setLocalNetworks(prefs->get_local_networks());
  } else {
    /* Add defaults */
    /* http://www.networksorcery.com/enp/protocol/ip/multicast.htm */
    char *local_nets, buf[512];

    snprintf(buf, sizeof(buf), "%s,%s", CONST_DEFAULT_PRIVATE_NETS,
	     CONST_DEFAULT_LOCAL_NETS);
    local_nets = strdup(buf);
    setLocalNetworks(local_nets);
    free(local_nets);
  }

  memset(iface, 0, sizeof(iface));

  redis = new Redis(prefs->get_redis_host(), prefs->get_redis_port(), prefs->get_redis_db_id());
#ifdef NTOPNG_PRO
  redis_pro = new RedisPro();
  pro->check_license(true);
#endif
}
/* ******************************************* */

#ifdef NTOPNG_PRO
void Ntop::registerNagios(void) {
  nagios_manager = new NagiosManager();
}
#endif

/* ******************************************* */

void Ntop::createHistoricalInterface() {
  HistoricalInterface *iface = new HistoricalInterface("Historical");
  prefs->add_network_interface((char *)"Historical", NULL);
  ntop->registerInterface(iface);
  historical_interface_id = iface->get_id();
}

/* ******************************************* */

NetworkInterface* Ntop::getHistoricalInterface() {
  return (getInterface(get_if_name(historical_interface_id)));
};

/* ******************************************* */

void Ntop::createExportInterface() {
  if(prefs->get_export_endpoint())
    export_interface = new ExportInterface(prefs->get_export_endpoint());
  else
    export_interface = NULL;
}

/* ******************************************* */

void Ntop::start() {
  char daybuf[64], buf[32];
  time_t when = time(NULL);

  getTrace()->traceEvent(TRACE_NORMAL, 
			 "Welcome to ntopng %s v.%s - (C) 1998-15 ntop.org",
			 PACKAGE_MACHINE, PACKAGE_VERSION);

  start_time = time(NULL);

  strftime(daybuf, sizeof(daybuf), CONST_DB_DAY_FORMAT, localtime(&when));
  snprintf(buf, sizeof(buf), "ntopng.%s.hostkeys", daybuf);

  pa->startPeriodicActivitiesLoop();
  if(categorization) categorization->startCategorizeCategorizationLoop();
  if(httpbl) httpbl->startHTTPBLLoop();

  runtimeprefs = new RuntimePrefs();

  prefs->loadIdleDefaults();
#ifdef NTOPNG_PRO
  prefs->loadNagiosDefaults();
#endif
  loadLocalInterfaceAddress();

  for(int i=0; i<num_defined_interfaces; i++)
    iface[i]->startPacketPolling();

  sleep(2);
  address->startResolveAddressLoop();

  while(!globals->isShutdown()) {
    sleep(HOUSEKEEPING_FREQUENCY);
    runHousekeepingTasks();
    // break;
  }
}

/* ******************************************* */

bool Ntop::isLocalAddress(int family, void *addr, int16_t *network_id) {
  *network_id = address->findAddress(family, addr);
  return(((*network_id) == -1) ? false : true);
};

/* ******************************************* */

bool Ntop::isLocalInterfaceAddress(int family, void *addr) {
  return((ptree_match(local_interface_addresses, family, addr,
		      (family == AF_INET) ? 32 : 128) != NULL) ? true /* found */ : false /* not found */);
}

/* ******************************************* */

void Ntop::loadLocalInterfaceAddress() {
#ifndef WIN32
  struct ifaddrs *local_addresses, *ifa;
  /* buf must be big enough for an IPv6 address(e.g. 3ffe:2fa0:1010:ca22:020a:95ff:fe8a:1cf8) */
  const int bufsize = 128;
  char buf[bufsize], buf2[bufsize], buf_orig[bufsize];
  int sock = socket(AF_INET, SOCK_STREAM, 0);

  if(getifaddrs(&local_addresses) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to read interface addresses");
    return;
  }

  for(ifa = local_addresses; ifa != NULL; ifa = ifa->ifa_next) {
    struct ifreq ifr;
    u_int32_t netmask;
    int cidr;

    if((ifa->ifa_addr == NULL)
       || ((ifa->ifa_flags & IFF_UP) == 0))
      continue;

    if(ifa->ifa_addr->sa_family == AF_INET) {
      struct sockaddr_in* s4 =(struct sockaddr_in *)(ifa->ifa_addr);

      if(inet_ntop(ifa->ifa_addr->sa_family,(void *)&(s4->sin_addr), buf, sizeof(buf)) != NULL) {
	int l = strlen(buf);
	int16_t network_id;

	memset(&ifr, 0, sizeof(ifr));
	ifr.ifr_addr.sa_family = AF_INET;
	strncpy(ifr.ifr_name, ifa->ifa_name, sizeof(ifr.ifr_name));
	ioctl(sock, SIOCGIFNETMASK, &ifr);
	netmask = ((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr.s_addr;
	cidr = 0;

	while(netmask) {
	  cidr += (netmask & 0x01);
	  netmask >>= 1;
	}

	strncpy(buf_orig, buf, bufsize);
	snprintf(&buf[l], sizeof(buf)-l, "/%u", cidr);
	ntop->getTrace()->traceEvent(TRACE_INFO, "Adding %s as IPv4 interface address", buf);
	strncpy(buf2, buf, bufsize);
	ptree_add_rule(local_interface_addresses, buf_orig);

	/* Add the net unless a larger one already exists */
	if((prefs->get_local_networks() == NULL)
	   && (!isLocalAddress(AF_INET, (void *)&(s4->sin_addr), &network_id))) {
	  address->addLocalNetwork(buf2);
	}
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

      s6 =(struct sockaddr_in6 *)(ifa->ifa_addr);
      if(inet_ntop(ifa->ifa_addr->sa_family,(void *)&(s6->sin6_addr), buf, sizeof(buf)) != NULL) {
	int l = strlen(buf);
	int16_t network_id;

	strncpy(buf_orig, buf, bufsize);
	snprintf(&buf[l], sizeof(buf)-l, "/%u", cidr);
	ntop->getTrace()->traceEvent(TRACE_INFO, "Adding %s as IPv6 interface address for %s", buf, ifr.ifr_name);
	strncpy(buf2, buf, bufsize);
	ptree_add_rule(local_interface_addresses, buf_orig);

	/* Add the net unless a larger one already exists */
	if((prefs->get_local_networks() == NULL)
	   && (!isLocalAddress(AF_INET6, (void *)&(s6->sin6_addr), &network_id))) {
	  address->addLocalNetwork(buf2);
	}
      }
    }
  }

  freeifaddrs(local_addresses);

  close(sock);
#endif
}

/* ******************************************* */

void Ntop::loadGeolocation(char *dir) {
  if(geo != NULL) delete geo;
  geo = new Geolocation(dir);
}

/* ******************************************* */

void Ntop::setWorkingDir(char *dir) {
  snprintf(working_dir, sizeof(working_dir), "%s", dir);
  removeTrailingSlash(working_dir);
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

/* ******************************************* */

void Ntop::getUsers(lua_State* vm) {
  char **usernames;
  char *username, *holder;
  char key[CONST_MAX_LEN_REDIS_KEY], val[CONST_MAX_LEN_REDIS_VALUE];
  int rc, i;

  lua_newtable(vm);

  if((rc = ntop->getRedis()->keys("ntopng.user.*.password", &usernames)) <= 0) {
    return;
  }

  for (i = 0; i < rc; i++) {
    if(usernames[i] == NULL) continue; /* safety check */
    if(strtok_r(usernames[i], ".", &holder) == NULL) continue;
    if(strtok_r(NULL, ".", &holder) == NULL) continue;
    if((username = strtok_r(NULL, ".", &holder)) == NULL) continue;

    lua_newtable(vm);

    snprintf(key, sizeof(key), CONST_STR_USER_FULL_NAME, username);
    if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
      lua_push_str_table_entry(vm, "full_name", val);
    else
      lua_push_str_table_entry(vm, "full_name", (char*) "unknown");

    snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, username);
    if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
      lua_push_str_table_entry(vm, "password", val);
    else
      lua_push_str_table_entry(vm, "password", (char*) "unknown");

    snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
    if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
      lua_push_str_table_entry(vm, "group", val);
    else
      lua_push_str_table_entry(vm, "group", (char*)"unknown");

    snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);
    if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
      lua_push_str_table_entry(vm, CONST_ALLOWED_NETS, val);
    else
      lua_push_str_table_entry(vm, CONST_ALLOWED_NETS, (char*)"");

    lua_pushstring(vm, username);
    lua_insert(vm, -2);
    lua_settable(vm, -3);

    free(usernames[i]);
  }

  free(usernames);
}

/* ******************************************* */

void Ntop::getUserGroup(lua_State* vm) {
  char key[64], val[64];
  char username[33];
  struct mg_connection *conn;

  lua_getglobal(vm, CONST_HTTP_CONN);
  if((conn = (struct mg_connection*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "INTERNAL ERROR: null HTTP connection");
    lua_pushstring(vm, (char*)"unknown");
    return;
  }

  mg_get_cookie(conn, CONST_USER, username, sizeof(username));

  if (!strncmp(username, NTOP_NOLOGIN_USER, sizeof(username))) {
    lua_pushstring(vm, "administrator");
    return;
  }

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  lua_pushstring(vm,
		 (ntop->getRedis()->get(key, val, sizeof(val)) >= 0) ? val : (char*)"unknown");
}

/* ******************************************* */

void Ntop::getAllowedNetworks(lua_State* vm) {
  char key[64], val[64];
  char username[33];
  struct mg_connection *conn;

  lua_getglobal(vm, CONST_HTTP_CONN);
  if((conn = (struct mg_connection*)lua_touserdata(vm, lua_gettop(vm))) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "INTERNAL ERROR: null HTTP connection");
    lua_pushstring(vm, (char*)"");
    return;
  }

  mg_get_cookie(conn, CONST_USER, username, sizeof(username));

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);
  lua_pushstring(vm, (ntop->getRedis()->get(key, val, sizeof(val)) >= 0) ? val : (char*)"");
}
/* ******************************************* */

// Return 1 if username/password is allowed, 0 otherwise.
bool Ntop::checkUserPassword(const char *user, const char *password) {
  char key[64], val[64];

  if((user == NULL) || (user[0] == '\0'))
    return(false);

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, user);

  if(ntop->getRedis()->get(key, val, sizeof(val)) < 0) {
    return(false);
  } else {
    char password_hash[33];

    mg_md5(password_hash, password, NULL);
    return((strcmp(password_hash, val) == 0) ? true : false);
  }
}

/* ******************************************* */

bool Ntop::resetUserPassword(char *username, char *old_password, char *new_password) {
  char key[64];
  char password_hash[33];

  if((old_password != NULL) && (old_password[0] != '\0')) {
    if(!checkUserPassword(username, old_password))
      return(false);
  }

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, username);
  mg_md5(password_hash, new_password, NULL);

  if(ntop->getRedis()->set(key, password_hash, 0) < 0)
    return(false);

  return(true);
}

/* ******************************************* */

bool Ntop::changeUserRole(char *username, char *usertype) const {
  char key[64];

  if(usertype != NULL) {
    snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);

    if(ntop->getRedis()->set(key, usertype, 0) < 0)
      return(false);
  }

  return(true);
}

/* ******************************************* */

bool Ntop::changeAllowedNets(char *username, char *allowed_nets) const {
  char key[64];

  if(allowed_nets != NULL) {
    snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);

    if(ntop->getRedis()->set(key, allowed_nets, 0) < 0)
      return(false);
  }

  return(true);
}

/* ******************************************* */

bool Ntop::addUser(char *username, char *full_name, char *password, char *host_role, char *allowed_networks) {
  char key[64], val[64];
  char password_hash[33];

  snprintf(key, sizeof(key), CONST_STR_USER_FULL_NAME, username);
  if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
    return(false); // user already exists

  ntop->getRedis()->set(key, full_name, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  ntop->getRedis()->set(key, (char*) host_role, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, username);
  mg_md5(password_hash, password, NULL);
  ntop->getRedis()->set(key, password_hash, 0);

  snprintf(key, sizeof(key), CONST_STR_USER_NETS, username);
  ntop->getRedis()->set(key, allowed_networks, 0);

  return(true);
}

/* ******************************************* */

bool Ntop::deleteUser(char *username) {
  char key[64];

  snprintf(key, sizeof(key), CONST_STR_USER_FULL_NAME, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_GROUP, username);
  ntop->getRedis()->del(key);

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, username);
  return((ntop->getRedis()->del(key) >= 0) ? true : false);
}

/* ******************************************* */

void Ntop::fixPath(char *str) {
  for(int i=0; str[i] != '\0'; i++) {
#ifdef WIN32
    if(str[i] == '/') str[i] = '\\';
#endif

    if((i > 0) && (str[i] == '.') && (str[i-1] == '.')) {
      // ntop->getTrace()->traceEvent(TRACE_WARNING, "Invalid path detected %s", str);
      str[i-1] = '_', str[i] = '_'; /* Invalidate the path */
    }
  }
}

/* ******************************************* */

char* Ntop::getValidPath(char *__path) {
  char _path[MAX_PATH];
  struct stat buf;
#ifdef WIN32
  const char *install_dir = (const char *)get_install_dir();
#endif

  if(strncmp(__path, "./", 2) == 0) {
    snprintf(_path, MAX_PATH, "%s/%s", startup_dir, &__path[2]);
    fixPath(_path);

    if(stat(_path, &buf) == 0) {
      free(__path);
      return(strdup(_path));
    }
  }

  if((__path[0] == '/') || (__path[0] == '\\')) {
    /* Absolute paths */

    if(stat(__path, &buf) == 0) {
      return(__path);
    }
  } else
    snprintf(_path, MAX_PATH, "%s", __path);

  /* relative paths */
  for(int i=0; dirs[i] != NULL; i++) {
    char path[MAX_PATH];

    snprintf(path, sizeof(path), "%s/%s", dirs[i], _path);
    fixPath(path);

    if(stat(path, &buf) == 0) {
      free(__path);
      return(strdup(path));
    }
  }

  free(__path);
  return(strdup(""));
}

/* ******************************************* */

void Ntop::daemonize() {
#ifndef WIN32
  int childpid;

  signal(SIGHUP, SIG_IGN);
  signal(SIGCHLD, SIG_IGN);
  signal(SIGQUIT, SIG_IGN);

  if((childpid = fork()) < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Occurred while daemonizing (errno=%d)",
				 errno);
  else {
    if(!childpid) { /* child */
      int rc;

      //ntop->getTrace()->traceEvent(TRACE_NORMAL, "Bye bye: I'm becoming a daemon...");

#if 1
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
      umask(0);

      /*
       * Use line buffered stdout
       */
      /* setlinebuf (stdout); */
      setvbuf(stdout, (char *)NULL, _IOLBF, 0);
#endif
    } else { /* father */
      ntop->getTrace()->traceEvent(TRACE_NORMAL,
				   "Parent process is exiting (this is normal)");
      _exit(0);
    }
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
  address->setLocalNetworks(nets);
  free(nets);
};

/* ******************************************* */

NetworkInterface* Ntop::getNetworkInterface(const char *name) {
  /* This method accepts both interface names or Ids */
  int if_id = atoi(name);
  char str[8];

  snprintf(str, sizeof(str), "%u", if_id);
  if(strcmp(name, str) == 0) {
    /* name is a number */

    for(int i=0; i<num_defined_interfaces; i++) {
      if(iface[i]->get_id() == if_id)
	return(iface[i]);
    }

    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to find interface Id %d", if_id);

    return(NULL);
  }

  for(int i=0; i<num_defined_interfaces; i++) {
    if(strcmp(iface[i]->get_name(), name) == 0)
      return(iface[i]);
  }

  /* FIX: remove this for at some point, when endpoint is passed */
  for(int i=0; i<num_defined_interfaces; i++) {
    char *script = iface[i]->getScriptName();
    if(script != NULL && strcmp(script, name) == 0)
      return(iface[i]);
  }

  /* Not found */
  if(!strcmp(name, "any"))
    return(iface[0]); /* FIX: remove at some point */

  return(NULL);
};

/* ******************************************* */

NetworkInterfaceView* Ntop::getNetworkInterfaceView(const char *name) {
  /* This method accepts both interface names or Ids */
  int if_id = atoi(name);
  char str[8];

  snprintf(str, sizeof(str), "%d", if_id);
  if(strcmp(name, str) == 0) {
    /* name is a number */

    for(int i=0; i<num_defined_interface_views; i++) {
      if(ifaceViews[i]->get_id() == if_id)
	return(ifaceViews[i]);
    }

    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to find interface view Id %d", if_id);

    return(NULL);
  }

  for(int i=0; i<num_defined_interface_views; i++) {
    if(strcmp(ifaceViews[i]->get_name(), name) == 0)
      return(ifaceViews[i]);
  }

  return(ifaceViews[0]); /* FIX: remove at some point */
};

/* ******************************************* */

NetworkInterface* Ntop::getInterfaceById(int id){
  for(int i=0; i<num_defined_interfaces; i++) {
    if(iface[i]->get_id() == id) {
      return(iface[i]);
    }
  }

  return(NULL);
}

/* ******************************************* */

NetworkInterfaceView* Ntop::getInterfaceViewById(int id){
  for(int i=0; i<num_defined_interface_views; i++) {
    if(ifaceViews[i]->get_id() == id)
      return(ifaceViews[i]);
  }

  return(NULL);
}

/* ******************************************* */

NetworkInterface* Ntop::getInterface(char *name) {
 /* This method accepts both interface names or Ids */
  int if_id;
  char str[8];

  if(name == NULL) return(NULL);

  if_id = atoi(name);

  snprintf(str, sizeof(str), "%d", if_id);
  if(strcmp(name, str) == 0) {
    /* name is a number */

    return(getInterfaceById(if_id));
  }

  for(int i=0; i<num_defined_interfaces; i++) {
    if(strcmp(iface[i]->get_name(), name) == 0) {
      return(iface[i]);
    }
  }

  return(NULL);
}

/* ******************************************* */

NetworkInterfaceView* Ntop::getInterfaceView(char *name) {
 /* This method accepts both interface names or Ids */
  int if_id;
  char str[8];

  if(name == NULL) return(NULL);

  if_id = atoi(name);

  snprintf(str, sizeof(str), "%d", if_id);
  if(strcmp(name, str) == 0) {
    /* name is a number */

    return(getInterfaceViewById(if_id));
  }

  for(int i=0; i<num_defined_interface_views; i++) {
    if(strcmp(ifaceViews[i]->get_name(), name) == 0) {
      return(ifaceViews[i]);
    }
  }

  return(NULL);
}

/* ******************************************* */

int Ntop::getInterfaceIdByName(char *name) {
   /* This method accepts both interface names or Ids */
  int if_id = atoi(name);
  char str[8];

  snprintf(str, sizeof(str), "%d", if_id);
  if(strcmp(name, str) == 0) {
    /* name is a number */
    NetworkInterface *iface = getInterfaceById(if_id);

    if(iface != NULL)
      return(iface->get_id());
    else
      return(-1);
  }

  for(int i=0; i<num_defined_interfaces; i++) {
    if(strcmp(iface[i]->get_name(), name) == 0) {
      return(iface[i]->get_id());
    }
  }

  return(-1);
}

/* ******************************************* */

int Ntop::getInterfaceViewIdByName(char *name) {
   /* This method accepts both interface names or Ids */
  int if_id = atoi(name);
  char str[8];

  snprintf(str, sizeof(str), "%d", if_id);
  if(strcmp(name, str) == 0) {
    /* name is a number */
    NetworkInterfaceView *iface = getInterfaceViewById(if_id);

    if(iface != NULL)
      return(iface->get_id());
    else
      return(-1);
  }

  for(int i=0; i<num_defined_interface_views; i++) {
    if(strcmp(ifaceViews[i]->get_name(), name) == 0) {
      return(ifaceViews[i]->get_id());
    }
  }

  return(-1);
}

/* ******************************************* */

void Ntop::registerInterface(NetworkInterface *_if) {
  for(int i=0; i<num_defined_interfaces; i++) {
    if(strcmp(iface[i]->get_name(), _if->get_name()) == 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Skipping duplicated interface %s", _if->get_name());
      delete _if;
      return;
    }
  }

  if(num_defined_interfaces < MAX_NUM_DEFINED_INTERFACES) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Registered interface %s [id: %d]",
				 _if->get_name(), num_defined_interfaces);
    iface[num_defined_interfaces++] = _if;
    return;
  }

  ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many interfaces defined");
};

/* ******************************************* */

void Ntop::registerInterfaceView(NetworkInterfaceView *_view) {
  int id = Utils::ifname2id(_view->get_name());

  for(int i=0; i<num_defined_interface_views; i++) {
    if((ifaceViews[i] == NULL)
       || (ifaceViews[i]->get_name() == NULL))
      continue;

    if(strcmp(ifaceViews[i]->get_name(), _view->get_name()) == 0) {
      ntop->getTrace()->traceEvent(TRACE_WARNING,
				   "Skipping duplicated interface %s", _view->get_name());
      if (_view->get_num_intfs() == 1 && _view->get_iface()) /* per-interface view */
        _view->get_iface()->set_view(ifaceViews[i]); /* redirect before clearing */
      delete _view;
      return;
    }
  }

  if(num_defined_interface_views < MAX_NUM_DEFINED_INTERFACES) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Registered interface view %s [id: %d]",
				 _view->get_name(), id);
    _view->set_id(id);
    ifaceViews[num_defined_interface_views++] = _view;
    return;
  }

  ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many network interface views defined");
};

/* ******************************************* */

void Ntop::runHousekeepingTasks() {
  if(globals->isShutdown()) return;

  for(int i=0; i<num_defined_interfaces; i++)
    iface[i]->runHousekeepingTasks();
}

/* ******************************************* */

void Ntop::sanitizeInterfaceView(NetworkInterfaceView *view) {
  for (int i = 0 ; i < num_defined_interface_views ; i++)
    if (strcmp(ifaceViews[i]->get_name(), view->get_name()) == 0)
      ifaceViews[i] = NULL;
  num_defined_interface_views--;
}

/* ******************************************* */

void Ntop::shutdown() {
  for(int i=0; i<num_defined_interfaces; i++) {
    EthStats *stats = iface[i]->getStats();

    stats->print();
    iface[i]->shutdown();
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Interface %s [running: %d]",
				 iface[i]->get_name(), iface[i]->isRunning());
  }
}
