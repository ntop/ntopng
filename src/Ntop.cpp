/*
 *
 * (C) 2013-16 - ntop.org
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
  CONST_ALT2_INSTALL_DIR,
  NULL
};

/* ******************************************* */

Ntop::Ntop(char *appName) {
  ntop = this;
  globals = new NtopGlobals();
  pa = new PeriodicActivities();
  address = new AddressResolution();
  httpbl = NULL, flashstart = NULL;
  custom_ndpi_protos = NULL;
  prefs = NULL, redis = NULL;
  num_cpus = -1;
  num_defined_interfaces = num_defined_interface_views = 0;
  local_interface_addresses = New_Patricia(128);
  export_interface = NULL;
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

  umask(0);

  if(getcwd(startup_dir, sizeof(startup_dir)) == NULL)
    ntop->getTrace()->traceEvent(TRACE_ERROR,
				 "Occurred while checking the current directory (errno=%d)", errno);

  dirs[0] = startup_dir;

  install_dir[0] = '\0';

  for(int i=0; dirs[i] != NULL; i++) {
    char path[MAX_PATH];
    struct stat statbuf;

    snprintf(path, sizeof(path), "%s/scripts/lua/index.lua", dirs[i]);
    fixPath(path);

    if(stat(path, &statbuf) == 0) {
      snprintf(install_dir, sizeof(install_dir), "%s", dirs[i]);
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

#ifndef WIN32
  setservent(1);
#endif
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
    if(ifaceViews[i]) delete(ifaceViews[i]);
    ifaceViews[i] = NULL;
  }

  if(udp_socket != -1) closesocket(udp_socket);

  if(httpbl)     delete httpbl;
  if(flashstart) delete flashstart;
  if(httpd)      delete httpd;
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
#endif
}

/* ******************************************* */

void Ntop::registerPrefs(Prefs *_prefs, bool quick_registration) {
  struct stat statbuf;

  prefs = _prefs;

  if(!quick_registration) {
    if(stat(prefs->get_data_dir(), &statbuf)
       || (!(statbuf.st_mode & S_IFDIR))  /* It's not a directory */
       || (!(statbuf.st_mode & S_IWRITE)) /* It's not writable    */) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Invalid directory %s specified",
				   prefs->get_data_dir());
      exit(-1);
    }

    if(stat(prefs->get_callbacks_dir(), &statbuf)
       || (!(statbuf.st_mode & S_IFDIR))  /* It's not a directory */
       || (!(statbuf.st_mode & S_IREAD)) /* It's not readable    */) {
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

  memset(iface, 0, sizeof(iface));

  initRedis();

#ifdef NTOPNG_PRO
  pro->check_license(true, false);
#endif
}

/* ******************************************* */

#ifdef NTOPNG_PRO
void Ntop::registerNagios(void) {
  nagios_manager = new NagiosManager();
}
#endif

/* ******************************************* */

void Ntop::initRedis() {
  if(redis) delete(redis);

  redis = new Redis(prefs->get_redis_host(), prefs->get_redis_port(), prefs->get_redis_db_id());
}

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
			 "Welcome to ntopng %s v.%s - (C) 1998-16 ntop.org",
			 PACKAGE_MACHINE, PACKAGE_VERSION);

  if(PACKAGE_OS[0] != '\0')
    getTrace()->traceEvent(TRACE_NORMAL, "Built on %s", PACKAGE_OS);

  start_time = time(NULL);

  strftime(daybuf, sizeof(daybuf), CONST_DB_DAY_FORMAT, localtime(&when));
  snprintf(buf, sizeof(buf), "ntopng.%s.hostkeys", daybuf);

  pa->startPeriodicActivitiesLoop();
  if(httpbl) httpbl->startLoop();
  else if(flashstart) flashstart->startLoop();

  runtimeprefs = new RuntimePrefs();

  prefs->loadIdleDefaults();
#ifdef NTOPNG_PRO
  pro->printLicenseInfo();
#endif
  prefs->loadInstanceNameDefaults();
  loadLocalInterfaceAddress();

  for(int i=0; i<num_defined_interfaces; i++) {
    iface[i]->allocateNetworkStats();
    iface[i]->startPacketPolling();
  }

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

#ifdef WIN32

#include <ws2tcpip.h>
#include <iphlpapi.h>

#define MALLOC(x) HeapAlloc(GetProcessHeap(), 0, (x))
#define FREE(x) HeapFree(GetProcessHeap(), 0, (x))

/* Note: could also use malloc() and free() */

char* getIfName(int if_id, char *name, u_int name_len) {

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

/* ******************************************* */

int NumberOfSetBits(u_int32_t i) {
  // Java: use >>> instead of >>
  // C or C++: use uint32_t
  i = i - ((i >> 1) & 0x55555555);
  i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
  return (((i + (i >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
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
    if(FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, dwRetVal, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),       // Default language
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
	u_int32_t bits = NumberOfSetBits((u_int32_t)pIPAddrTable->table[ifIdx].dwMask);

	IPAddr.S_un.S_addr = (u_long)(pIPAddrTable->table[ifIdx].dwAddr & pIPAddrTable->table[ifIdx].dwMask);

	snprintf(buf, bufsize, "%s/%u", inet_ntoa(IPAddr), bits);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as local address for %s", buf, iface[id]->get_name());
	address->setLocalNetwork(buf);

	IPAddr.S_un.S_addr = (u_long)pIPAddrTable->table[ifIdx].dwAddr;
	snprintf(buf, bufsize, "%s/32", inet_ntoa(IPAddr));
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv4 interface address for %s", buf, iface[id]->get_name());
	iface[id]->addInterfaceAddress(buf);
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
  char buf_orig[bufsize];
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

    for(int i=0; i<num_defined_interfaces; i++) {
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
#ifdef ADD_INTERFACE_ADDRESSES
	snprintf(buf_orig, bufsize, "%s/%d", buf, 32);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv4 interface address for %s", buf_orig, iface[ifId]->get_name());
	ptree_add_rule(local_interface_addresses, buf_orig);
	iface[ifId]->addInterfaceAddress(buf_orig);
#endif

	/* Set to zero non network bits */
	s4->sin_addr.s_addr = htonl(ntohl(s4->sin_addr.s_addr) & ntohl(netmask));
	inet_ntop(ifa->ifa_addr->sa_family, (void *)&(s4->sin_addr), buf, sizeof(buf));
	snprintf(buf_orig, bufsize, "%s/%d", buf, cidr);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv4 local network for %s", buf_orig, iface[ifId]->get_name());
	address->setLocalNetwork(buf_orig);
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
#ifdef ADD_INTERFACE_ADDRESSES
	snprintf(buf_orig, bufsize, "%s/%d", buf, 128);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv6 interface address for %s", buf_orig, iface[ifId]->get_name());
	address->setLocalNetwork(buf_orig);
	iface[ifId]->addInterfaceAddress(buf_orig);
#endif

	for(u_int32_t i = cidr, j = 0; i > 0; i -= 8, ++j)
	  s6->sin6_addr.s6_addr[j] &= i >= 8 ? 0xff : (u_int32_t)(( 0xffU << ( 8 - i ) ) & 0xffU );

	inet_ntop(ifa->ifa_addr->sa_family,(void *)&(s6->sin6_addr), buf, sizeof(buf));
	snprintf(buf_orig, bufsize, "%s/%d", buf, cidr);
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Adding %s as IPv6 local network for %s", buf_orig, iface[ifId]->get_name());
	ptree_add_rule(local_interface_addresses, buf_orig);
      }
    }
  }

  freeifaddrs(local_addresses);

  closesocket(sock);
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

  for(i = 0; i < rc; i++) {
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

  if(!strncmp(username, NTOP_NOLOGIN_USER, sizeof(username))) {
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
  char key[64], val[64], password_hash[33];
#if defined(NTOPNG_PRO) && defined(HAVE_LDAP)
  bool localAuth = true;
#endif

  if((user == NULL) || (user[0] == '\0'))
    return(false);

#if defined(NTOPNG_PRO) && defined(HAVE_LDAP)
  if(ntop->getRedis()->get((char*)PREF_NTOP_AUTHENTICATION_TYPE, val, sizeof(val)) >= 0) {
    if(!strcmp(val, "ldap") /* LDAP only */) localAuth = false;

    if(strncmp(val, "ldap", 4) == 0) {
      bool is_admin;
      char ldapServer[64] = { 0 }, ldapAccountType[64] = { 0 }, ldapAnonymousBind[32] = { 0 },
           bind_dn[128] = { 0 }, bind_pwd[64] = { 0 }, group[64] = { 0 },
           search_path[128] = { 0 }, admin_group[64] = { 0 };

      if(!password || !password[0])
        return false;
      snprintf(key, sizeof(key), CONST_CACHED_USER_PASSWORD, user);
      mg_md5(password_hash, password, NULL);

      if(ntop->getRedis()->get(key, val, sizeof(val)) >= 0)
	return((strcmp(password_hash, val) == 0) ? true : false);

      ntop->getRedis()->get((char*)PREF_LDAP_SERVER, ldapServer, sizeof(ldapServer));
      ntop->getRedis()->get((char*)PREF_LDAP_ACCOUNT_TYPE, ldapAccountType, sizeof(ldapAccountType));
      ntop->getRedis()->get((char*)PREF_LDAP_BIND_ANONYMOUS, ldapAnonymousBind, sizeof(ldapAnonymousBind));
      ntop->getRedis()->get((char*)PREF_LDAP_BIND_DN, bind_dn, sizeof(bind_dn));
      ntop->getRedis()->get((char*)PREF_LDAP_BIND_PWD, bind_pwd, sizeof(bind_pwd));
      ntop->getRedis()->get((char*)PREF_LDAP_SEARCH_PATH, search_path, sizeof(search_path));
      ntop->getRedis()->get((char*)PREF_LDAP_USER_GROUP, group, sizeof(group));
      ntop->getRedis()->get((char*)PREF_LDAP_ADMIN_GROUP, admin_group, sizeof(admin_group));

      if(ldapServer[0]) {
	bool ret = LdapAuthenticator::validUserLogin(ldapServer, ldapAccountType, ldapAnonymousBind, bind_dn, bind_pwd,
						     search_path, user, password, group, admin_group, &is_admin);

	if(ret) {
	  /* Let's cache the password so we avoid talking to LDAP too often  */
	  ntop->getRedis()->set(key, password_hash, 600 /* 10 mins cache */);

	  snprintf(key, sizeof(key), CONST_CACHED_USER_GROUP, user);
	  ntop->getRedis()->set(key,
				is_admin ?  (char*)"administrator" : (char*)"unprivileged",
				600 /* 10 mins cache */);
	  return(true);
	}
      }
    }
  }

  if(!localAuth) return(false);
#endif

  snprintf(key, sizeof(key), CONST_STR_USER_PASSWORD, user);

  if(ntop->getRedis()->get(key, val, sizeof(val)) < 0) {
    return(false);
  } else {
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

void Ntop::fixPath(char *str, bool replaceDots) {
  for(int i=0; str[i] != '\0'; i++) {
#ifdef WIN32
    if(str[i] == '/') str[i] = '\\';
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
      exit(0);
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

  snprintf(str, sizeof(str), "%d", if_id);
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
    if(strstr(name, iface[i]->get_name()))
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

NetworkInterface* Ntop::getInterfaceById(int id) {
  for(int i=0; i<num_defined_interfaces; i++) {
    if(iface[i]->get_id() == id) {
      return(iface[i]);
    }
  }

  return(NULL);
}

/* ******************************************* */

NetworkInterfaceView* Ntop::getInterfaceViewById(int id) {
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

/* NOTUSED */
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
				 _if->get_name(), _if->get_id());
    iface[num_defined_interfaces++] = _if;
    return;
  }

  ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many interfaces defined");
};

/* ******************************************* */

void Ntop::registerInterfaceView(NetworkInterfaceView *_view) {
  if(num_defined_interface_views < MAX_NUM_DEFINED_INTERFACES) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Registered interface view %s [id: %d]",
				 _view->get_name(), _view->get_id());
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

void Ntop::shutdown() {
  for(int i=0; i<num_defined_interfaces; i++) {
    EthStats *stats = iface[i]->getStats();

    stats->print();
    iface[i]->shutdown();
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Interface %s [running: %d]",
				 iface[i]->get_name(), iface[i]->isRunning());
  }
}
