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

#ifndef _NTOP_CLASS_H_
#define _NTOP_CLASS_H_

#include "ntop_includes.h"

/** @defgroup Ntop Ntop
 * Main ntopng group.
 */

class NtopPro;

/** @class Ntop
 *  @brief Main class of ntopng.
 *
 *  @ingroup Ntop
 *
 */
class Ntop {
 private:
  AddressTree local_interface_addresses;
  char epoch_buf[11];
  char working_dir[MAX_PATH]; /**< Array of working directory. */
  char install_dir[MAX_PATH]; /**< Array of install directory. */
  char startup_dir[MAX_PATH]; /**< Array of startup directory. */
  char *custom_ndpi_protos; /**< Pointer of a custom protocol for nDPI. */
  NetworkInterface **iface; /**< Array of network interfaces. */
  u_int8_t num_defined_interfaces; /**< Number of defined interfaces. */
  HTTPserver *httpd; /**< Pointer of httpd server. */
  NtopGlobals *globals; /**< Pointer of Ntop globals info and variables. */
  u_int num_cpus; /**< Number of physical CPU cores. */
  Redis *redis; /**< Pointer to the Redis server. */
#ifndef HAVE_NEDGE
  ElasticSearch *elastic_search; /**< Pointer of Elastic Search. */
  Logstash *logstash; /**< Pointer of Logstash. */
  ExportInterface *export_interface;
#endif
  PeriodicActivities *pa; /**< Instance of periodical activities. */
  AddressResolution *address;
  Prefs *prefs;
  Geolocation *geo;
  MacManufacturers *mac_manufacturers;
  void *trackers_automa;
  HTTPBL *httpbl;
  long time_offset;
  time_t start_time; /**< Time when start() was called */
  int udp_socket;
  NtopPro *pro;
  DeviceProtocolBitmask deviceProtocolPresets[device_max_type];
  
#ifdef NTOPNG_PRO
#ifndef WIN32
  NagiosManager *nagios_manager;
#endif
  FlowChecker *flow_checker;
#endif
  AddressTree *hostBlacklist, *hostBlacklistShadow;

  void loadLocalInterfaceAddress();
  void initAllowedProtocolPresets();

 public:
  /**
   * @brief A Constructor
   * @details Creating a new Ntop.
   *
   * @param appName  Describe the application name.
   * @return A new instance of Ntop.
   */
  Ntop(char *appName);
  /**
   * @brief A Destructor.
   *
   */
  ~Ntop();
  /**
   * @brief Register the ntopng preferences.
   * @details Setting the ntopng preferences defined in a Prefs instance.
   *
   * @param _prefs Prefs instance containing the ntopng preferences.
   * @param quick_registration Set it to true to do a limited initialization
   */
  void registerPrefs(Prefs *_prefs, bool quick_registration);

  /**
   * @brief Register an ntopng log file
   * @details Log file is used under windows and in daemon mode
   *
   * @param logFile A valid path to a log file
   */
  inline void registerLogFile(const char* logFile) { getTrace()->set_log_file(logFile); };
  inline void rotateLogs(bool mode)                { getTrace()->rotate_logs(mode);     };
#ifdef NTOPNG_PRO
  void registerNagios(void);
  inline FlowChecker *getFlowChecker() { return(flow_checker); };
#endif

  /**
   * @brief Set the path of custom nDPI protocols file.
   * @details Set the path of protos.txt containing the defined custom protocols. For more information please read the nDPI quick start (cd ntopng source code directory/nDPI/doc/).
   *
   * @param path Path of protos.file.
   */
  void setCustomnDPIProtos(char *path);
  /**
   * @brief Get the custom nDPI protocols.
   * @details Inline function.
   *
   * @return The path of custom nDPI protocols file.
   */
  inline char* getCustomnDPIProtos()                 { return(custom_ndpi_protos);                 };
  /**
   * @brief Get the offset time.
   * @details ....
   *
   * @return The timezone offset.
   */
  inline long get_time_offset()                      { return(time_offset);                        };
  /**
   * @brief Initialize the Timezone.
   * @details Use the localtime function to initialize the variable @ref time_offset.
   *
   */
  void initTimezone();
  /**
   * @brief Get a valid path.
   * @details Processes the input path and return a valid path.
   *
   * @param path String path to validate.
   * @return A valid path.
   */
  char* getValidPath(char *path);
  /**
   * @brief Load the @ref Geolocation module.
   * @details Initialize the variable @ref geo with the input directory.
   *
   * @param dir Path to database home directory.
   */
  void loadGeolocation(char *dir);
  /**
   * @brief Load the @ref MacManufacturers module.
   * @details Initialize the variable @ref dir with the input directory.
   *
   * @param dir Path to database home directory.
   */
  void loadMacManufacturers(char *dir);

  inline void getMacManufacturer(const char *mac, lua_State *vm) {
    u_int8_t mac_bytes[6];
    Utils::parseMac(mac_bytes, mac);
    if(mac_manufacturers)
      mac_manufacturers->getMacManufacturer(mac_bytes, vm);
    else
      lua_pushnil(vm);
  }

  /**
   * @brief Set the local networks.
   * @details Set the local networks to @ref AddressResolution instance.
   *
   * @param nets String that defined the local network with this Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 .
   */
  void setLocalNetworks(char *nets);
  /**
   * @brief Check if the ingress parameter is in the local networks.
   * @details Inline method.
   *
   * @param family Internetwork: UDP, TCP, etc.
   * @param addr Internet Address.
   * @param network_id It returns the networkId to which the host belongs to
   * @param network_mask_bits It returns the number of bits of the network mask
   * @return True if the address is in the local networks, false otherwise.
   */
  bool isLocalAddress(int family, void *addr, int16_t *network_id, u_int8_t *network_mask_bits = NULL);

  /**
   * @brief Start ntopng packet processing.
   */
  void start();
  /**
   * @brief Resolve the host name.
   * @details Use the redis database to resolve the IP address and get the host name.
   *
   * @param numeric_ip Address IP.
   * @param symbolic Symbolic name.
   * @param symbolic_len Length of symbolic name.
   */
  inline void resolveHostName(char *numeric_ip, char *symbolic, u_int symbolic_len) {
    address->resolveHostName(numeric_ip, symbolic, symbolic_len);
  }
  /**
   * @brief Get the geolocation instance.
   *
   * @return Current geolocation instance.
   */
  inline Geolocation* getGeolocation()               { return(geo);                };
  /**
   * @brief Get the mac manufacturers instance.
   *
   * @return Current mac manufacturers instance.
   */
  inline MacManufacturers* getMacManufacturers()     { return(mac_manufacturers); };
  /**
   * @brief Get the ifName.
   * @details Find the ifName by id parameter.
   *
   * @param id Index of ifName.
   * @return ....
   */
  inline char* get_if_name(int id)                   { return(prefs->get_if_name(id));     };
  inline char* get_if_descr(int id)                  { return(prefs->get_if_descr(id));    };
  inline char* get_data_dir()                        { return(prefs->get_data_dir());      };
  inline char* get_callbacks_dir()                   { return(prefs->get_callbacks_dir()); };
  /**
   * @brief Get the current httpdocs directory.
   *
   * @return The absolute path of the httpdocs directory.
   */
  inline char* get_docs_dir()                     { return(prefs->get_docs_dir());      };

  /**
   * @brief Get httpbl.
   *
   * @return Current httpbl instance.
   */
  inline HTTPBL* get_httpbl()                        { return(httpbl);             };

  /**
   * @brief Register the network interface.
   * @details Check for duplicated interface and add the network interface in to @ref iface.
   *
   * @param i Network interface.
   */
  void registerInterface(NetworkInterface *i);

  /**
   * @brief Get the number of defined network interfaces.
   *
   * @return Number of defined network interfaces.
   */
  inline u_int8_t get_num_interfaces()               { return(num_defined_interfaces); }

  /**
   * @brief Get the i-th network interface.
   * @details Retrieves the pointer the network interface
   *  identified by id i and enforces constraints on
   *  user allowed interfaces.
   *
   * @param i The i-th network interface.
   * @return The network interface instance if exists, NULL otherwise.
   */
  inline NetworkInterface* getInterfaceAtId(lua_State *vm, int i) const {
    if(i >= 0 && i < num_defined_interfaces && iface[i]) {
      return isInterfaceAllowed(vm, iface[i]->get_name()) ? iface[i] : NULL;
    }
    return NULL;
  }
  /**
   * @brief Get the i-th network interface.
   * @details Retrieves the pointer the network interface
   *  identified by id i WITHOUT ENFORCING constraints on
   *  user allowed interfaces.
   *
   * @param i The i-th network interface.
   * @return The network interface instance if exists, NULL otherwise.
   */
  inline NetworkInterface* getInterfaceAtId(int i) const {
    return getInterfaceAtId(NULL, i);
  }

  /**
   * @brief Get the Id of network interface.
   * @details This method accepts both interface names or Ids.
   *
   * @param name Name of network interface.
   * @return The network interface Id if exists, -1 otherwise.
   */
  int getInterfaceIdByName(lua_State *vm, const char * const name);

  /**
   * @brief Get the network interface with the specified Id
   *
   * @param if_id Id of network interface.
   * @return Pointer to the network interface, NULL otherwise.
   */
  NetworkInterface* getInterfaceById(int if_id);

  /**
   * @brief Register the HTTP server.
   *
   * @param h HTTP server instance.
   */
  inline void registerHTTPserver(HTTPserver *h)      { httpd = h;              };
  /**
   * @brief Set httpbl.
   *
   * @param h The categorization instance.
   */
  inline void setHTTPBL(HTTPBL *h)                   { httpbl = h; };

  /**
   * @brief Get the network interface identified by name or Id.
   * @details This method accepts both interface names or Ids.
   *  This method shall be called from Lua-mapped methods
   *  especially where constraints on user allowed interfaces
   *  must be enforced.
   * @param name Names or Id of network interface.
   * @return The network interface instance if exists, NULL otherwise.
   */
  NetworkInterface* getNetworkInterface(lua_State *vm, const char *name);
  /**
   * @brief Get the network interface identified by name or Id.
   * @details This method accepts both interface names or Ids.
   *  No checks on user allowed interfaces are performed by this method.
   *  Therefore is should not be used when forwarding UI requests
   *  for security reasons.
   * @param name Names or Id of network interface.
   * @return The network interface instance if exists, NULL otherwise.
   */
  inline NetworkInterface* getNetworkInterface(const char *name) {
    return getNetworkInterface(NULL /* don't enforce the check on the allowed interface */,
			       name);
  };
  inline NetworkInterface* getNetworkInterface(lua_State *vm, int ifid) {
    char ifname[MAX_INTERFACE_NAME_LEN];
    snprintf(ifname, sizeof(ifname), "%d", ifid);
    return getNetworkInterface(vm /* enforce the check on the allowed interface */,
			       ifname);
  };
  inline NetworkInterface* getNetworkInterface(int ifid) {
    char ifname[MAX_INTERFACE_NAME_LEN];
    snprintf(ifname, sizeof(ifname), "%d", ifid);
    return getNetworkInterface(NULL /* don't enforce the check on the allowed interface */,
			       ifname);
  };

  /**
   * @brief Get the current HTTPserver instance.
   *
   * @return The current instance of HTTP server.
   */
  inline HTTPserver*       get_HTTPserver()          { return(httpd);            };
  /**
   * @brief Get the current working directory.
   *
   * @return The absolute path of working directory.
   */
  inline char* get_working_dir()                     { return(working_dir);      };
  /**
   * @brief Get the installation path of ntopng.
   *
   * @return The path of installed directory.
   */
  inline char* get_install_dir()                     { return(install_dir);      };
  inline void  set_install_dir(char *id)             { snprintf(install_dir, MAX_PATH, "%s", id); };

  inline NtopGlobals*      getGlobals()              { return(globals); };
  inline Trace*            getTrace()                { return(globals->getTrace()); };
  inline Redis*            getRedis()                { return(redis);               };
#ifndef HAVE_NEDGE
  inline ElasticSearch*    getElasticSearch()        { return(elastic_search);      };
  inline Logstash*         getLogstash()             { return(logstash);            };
  inline ExportInterface*  get_export_interface()    { return(export_interface);    };
#endif

  inline Prefs*            getPrefs()                { return(prefs);               };
  
#ifdef NTOPNG_PRO
#ifdef WIN32
  char* getIfName(int if_id, char *name, u_int name_len);
#else
  inline NagiosManager*    getNagios()               { return(nagios_manager);      };
#endif
#endif

  void getUsers(lua_State* vm);
  void getUserGroup(lua_State* vm);
  void getAllowedNetworks(lua_State* vm);
  bool getInterfaceAllowed(lua_State* vm, char *ifname)         const;
  bool isInterfaceAllowed(lua_State* vm, const char *ifname)    const;
  bool isInterfaceAllowed(lua_State* vm, int ifid)              const;
  bool checkUserPassword(const char * const user, const char * const password) const;
  bool checkUserInterfaces(const char * const user)             const;
  bool resetUserPassword(char *username, char *old_password, char *new_password);
  bool mustChangePassword(const char *user);
  bool changeUserRole(char *username, char *user_role) const;
  bool changeAllowedNets(char *username, char *allowed_nets)     const;
  bool changeAllowedIfname(char *username, char *allowed_ifname) const;
  bool changeUserHostPool(const char * const username, const char * const host_pool_id) const;
  bool changeUserLanguage(const char * const username, const char * const language) const;
  bool addUser(char *username, char *full_name, char *password, char *host_role,
	       char *allowed_networks, char *allowed_ifname, char *host_pool_id,
	       char *language);
  bool addUserLifetime(const char * const username, u_int32_t lifetime_secs); /* Captive portal users may expire */
  bool clearUserLifetime(const char * const username);
  bool isCaptivePortalUser(const char * const username);
  bool deleteUser(char *username);
  bool getUserHostPool(char *username, u_int16_t *host_pool_id);
  bool getUserAllowedIfname(const char * const username, char *buf, size_t buflen) const;
  bool hasUserLimitedLifetime(const char * const username, int32_t *lifetime_secs);
  void setWorkingDir(char *dir);
  void fixPath(char *str, bool replaceDots = true);
  void removeTrailingSlash(char *str);
  void daemonize();
  void shutdownPeriodicActivities();
  void shutdown();
  void shutdownAll();
  void runHousekeepingTasks();
  bool isLocalInterfaceAddress(int family, void *addr)       { return(local_interface_addresses.findAddress(family, addr) == -1 ? false : true);    };
  inline char* getLocalNetworkName(int16_t local_network_id) {
    return(address->get_local_network((u_int8_t)local_network_id));
  };
  void getLocalNetworkIp(int16_t local_network_id, IpAddress **network_ip, u_int8_t *network_prefix);
  inline void addLocalNetwork(const char *network)           { address->setLocalNetwork((char*)network); }
  void createExportInterface();
  void initNetworkInterfaces();
  void initElasticSearch();
  void initLogstash(); 

  inline u_int32_t getStarttime()        { return((u_int32_t)start_time); }
  inline char*     getStarttimeString()  { return(epoch_buf);             }
  inline u_int32_t getUptime()          { return((u_int32_t)((start_time > 0) ? (time(NULL)-start_time) : 0)); }
  inline int getUdpSock()               { return(udp_socket); }

  inline u_int getNumCPUs()             { return(num_cpus); }
  inline void setNumCPUs(u_int num)     { num_cpus = num; }

  inline NtopPro* getPro()              { return((NtopPro*)pro); };

  inline void getLocalNetworks(lua_State* vm) { address->getLocalNetworks(vm);          };
  inline u_int8_t getNumLocalNetworks()       { return(address->getNumLocalNetworks()); };
  void loadTrackers();
  bool isATrackerHost(char *host);
  void allocHostBlacklist();
  void swapHostBlacklist();
  void addToHostBlacklist(char *net);
  bool isBlacklistedIP(IpAddress *ip);
  bool isExistingInterface(const char * const name) const;
  inline NetworkInterface* getFirstInterface() { return(iface[0]);         }
  inline NetworkInterface* getInterface(int i) { return(((i < num_defined_interfaces) && iface[i]) ? iface[i] : NULL); }
#ifdef NTOPNG_PRO
  bool addToNotifiedInformativeCaptivePortal(u_int32_t client_ip);
  bool addIPToLRUMatches(u_int32_t client_ip, u_int16_t user_pool_id,
			 char *label, int32_t lifetime_secs, char *ifname);
#endif /* NTOPNG_PRO */
  
  DeviceProtocolBitmask* getDeviceAllowedProtocols(DeviceType t) { return(&deviceProtocolPresets[t]); }
  void sendNetworkInterfacesTermination();
};

extern Ntop *ntop;

#ifdef NTOPNG_PRO
#include "ntoppro_defines.h"
#endif

#endif /* _NTOP_CLASS_H_ */
