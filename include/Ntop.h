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
#ifndef WIN32
  int startupLockFile;
#endif
  pthread_t purgeLoop;    /* Loop which iterates on active interfaces to delete idle hash table entries */
  bool purgeLoop_started; /* Flag that indicates whether the purgeLoop has been started */
  bool ndpiReloadInProgress;
  bool flowChecksReloadInProgress, hostChecksReloadInProgress;
  bool hostPoolsReloadInProgress;
  bool offline;
  Bloom *resolvedHostsBloom; /* Used by all redis class instances */
  AddressTree local_interface_addresses;
  char epoch_buf[11];
  char working_dir[MAX_PATH]; /**< Working directory. */
  char install_dir[MAX_PATH]; /**< Install directory. */
  char startup_dir[MAX_PATH]; /**< Startup directory. */
  char plugins0_dir[MAX_PATH];
  char plugins1_dir[MAX_PATH];
  char *custom_ndpi_protos; /**< Pointer of a custom protocol for nDPI. */
  NetworkInterface **iface; /**< Array of network interfaces. */
  NetworkInterface *system_interface; /** The system interface */
  u_int8_t num_defined_interfaces; /**< Number of defined interfaces. */
  u_int8_t num_dump_interfaces;
  HTTPserver *httpd; /**< Pointer of httpd server. */
  NtopGlobals *globals; /**< Pointer of Ntop globals info and variables. */
  u_int num_cpus; /**< Number of physical CPU cores. */
  Redis *redis; /**< Pointer to the Redis server. */
  Mutex m, users_m;
  struct ndpi_detection_module_struct *ndpi_struct, *ndpi_struct_shadow;
#ifndef HAVE_NEDGE
  ElasticSearch *elastic_search; /**< Pointer of Elastic Search. */
  ZMQPublisher *zmqPublisher;
#ifndef WIN32
  SyslogDump *syslog; /**< Pointer of Logstash. */
#endif
  ExportInterface *export_interface;
#endif
  TimelineExtract *extract;
  PeriodicActivities *pa; /**< Instance of periodical activities. */
  AddressResolution *address;
  Prefs *prefs;
  Geolocation *geo;
  MacManufacturers *mac_manufacturers;
  void *trackers_automa;
  long time_offset;
  time_t start_time; /**< Time when start() was called */
  time_t last_stats_reset, last_ndpi_reload;
  u_int32_t last_modified_static_file_epoch;
  bool ndpi_cleanup_needed;
  int udp_socket;
  NtopPro *pro;
  DeviceProtocolBitmask deviceProtocolPresets[device_max_type];
  cpu_load_stats cpu_stats;
  float cpu_load;
  bool plugins0_active, can_send_icmp, privileges_dropped;
#ifndef HAVE_NEDGE
  bool refresh_ips_rules;
#endif
  FifoSerializerQueue *internal_alerts_queue;
  Recipients recipients; /* Handle notification recipients */
  
  /* Local network address list */
  char *local_network_names[CONST_MAX_NUM_NETWORKS];
  char *local_network_aliases[CONST_MAX_NUM_NETWORKS];
  AddressTree local_network_tree;

  /* Alerts */
  FlowAlertsLoader flow_alerts_loader;

  /* Checks */
  FlowChecksLoader *flow_checks_loader;
  HostChecksLoader *host_checks_loader;

  /* Hosts Control (e.g., disabled alerts) */
#ifdef NTOPNG_PRO
  bool alertExclusionsReloadInProgress;
  AlertExclusions *alert_exclusions, *alert_exclusions_shadow;
#endif
  bool assignUserId(u_int8_t *new_user_id);

#ifndef WIN32
  ContinuousPing *cping;
  Ping *ping;
#endif
  
#ifdef __linux__
  int inotify_fd;
#endif

  /* For local network */
  inline int16_t localNetworkLookup(int family, void *addr, u_int8_t *network_mask_bits = NULL);
  bool addLocalNetwork(char *_net);

  void loadLocalInterfaceAddress();
  void initAllowedProtocolPresets();
  void loadProtocolsAssociations(struct ndpi_detection_module_struct *ndpi_str);
  void cleanShadownDPI();
  void refreshPluginsDir();

  bool getUserPasswordHashLocal(const char * const user, char *password_hash) const;
  bool checkUserPasswordLocal(const char * const user, const char * const password, char *group) const;
  bool checkUserPassword(const char * const user, const char * const password, char *group, bool *localuser) const;
  bool startPurgeLoop();

  void checkReloadFlowChecks();
  void checkReloadHostChecks();
  void checkReloadAlertExclusions();
  void checkReloadHostPools();
  
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
   */
  void loadGeolocation();
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

  inline bool resolveHost(char *host, char *rsp, u_int rsp_len, bool v4) {
    return address->resolveHost(host, rsp, rsp_len, v4);
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
  inline char* get_if_name(int id)                         { return(prefs->get_if_name(id));     };
  inline const char* get_if_descr(int id)                  { return(prefs->get_if_descr(id));    };
  inline char* get_data_dir()                              { return(prefs->get_data_dir());      };
  inline const char* get_callbacks_dir()                   { return(prefs->get_callbacks_dir()); };
  /**
   * @brief Get the current httpdocs directory.
   *
   * @return The absolute path of the httpdocs directory.
   */
  inline const char* get_docs_dir()                     { return(prefs->get_docs_dir());      };

  /**
   * @brief Register the network interface.
   * @details Check for duplicated interface and add the network interface in to @ref iface.
   *
   * @param i Network interface.
   * @return true on success, false otherwise
   */
  bool registerInterface(NetworkInterface *i);

  /**
   * @brief Finalize the network interface initialization.
   *
   * @param i Network interface.
   */
  void initInterface(NetworkInterface *i);

  /**
   * @brief Get the number of defined network interfaces.
   *
   * @return Number of defined network interfaces.
   */
  inline u_int8_t get_num_interfaces()               { return(num_defined_interfaces); }

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
   * @brief Get the network interface identified by name or Id.
   * @details This method accepts both interface names or Ids.
   *  This method shall be called from Lua-mapped methods
   *  especially where constraints on user allowed interfaces
   *  must be enforced.
   * @param name Names or Id of network interface.
   * @return The network interface instance if exists, NULL otherwise.
   */
  NetworkInterface* getNetworkInterface(const char *name, lua_State *vm = NULL);
  inline NetworkInterface* getNetworkInterface(lua_State *vm, int ifid) {
    char ifname[MAX_INTERFACE_NAME_LEN];
    snprintf(ifname, sizeof(ifname), "%d", ifid);
    return getNetworkInterface(ifname, vm /* enforce the check on the allowed interface */);
  };

  /**
   * @brief Get the current HTTPserver instance.
   *
   * @return The current instance of HTTP server.
   */
  inline HTTPserver*       get_HTTPserver()          { return(httpd);            };

  inline const char* get_bin_dir()                   { return(CONST_BIN_DIR);    };

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
  inline char* get_install_dir()                     { return(install_dir);         };
  inline void  set_install_dir(char *id)             { snprintf(install_dir, MAX_PATH, "%s", id); };

  inline char* get_plugins_dir()                     { return(plugins0_active ? plugins0_dir : plugins1_dir); };
  inline char* get_shadow_plugins_dir()              { return(plugins0_active ? plugins1_dir : plugins0_dir); };
  inline char* get_plugins0_dir()                    { return(plugins0_dir); };
  inline char* get_plugins1_dir()                    { return(plugins1_dir); };
  inline bool is_plugins0_dir()                      { return(plugins0_active); };
  inline void swap_plugins_dir()                     { plugins0_active = !plugins0_active; };

  inline Bloom*            getResolutionBloom()      { return(resolvedHostsBloom);  };
  inline NtopGlobals*      getGlobals()              { return(globals);             };
  inline Trace*            getTrace()                { return(globals->getTrace()); };
  inline Redis*            getRedis()                { return(redis);               };
  inline TimelineExtract*  getTimelineExtract()      { return(extract);             };
#ifndef HAVE_NEDGE
  inline ExportInterface*  get_export_interface()    { return(export_interface);    };
#endif

  inline Prefs*            getPrefs()                { return(prefs);               };

#ifndef WIN32
  void  lockNtopInstance();
#endif
#ifdef NTOPNG_PRO
#ifdef WIN32
  char* getIfName(int if_id, char *name, u_int name_len);
#endif
#endif
  void checkSystemScripts(ScriptPeriodicity p, lua_State *vm);
  void checkSNMPDeviceAlerts(ScriptPeriodicity p, lua_State *vm);
  void lua_periodic_activities_stats(NetworkInterface *iface, lua_State* vm);
  void getUsers(lua_State* vm);
  bool getLocalNetworkAlias(lua_State *vm, u_int8_t network_id);
  bool isUserAdministrator(lua_State* vm);
  void getAllowedInterface(lua_State* vm);
  void getAllowedNetworks(lua_State* vm);
  bool getInterfaceAllowed(lua_State* vm, char *ifname)         const;
  bool isInterfaceAllowed(lua_State* vm, const char *ifname)    const;
  bool isInterfaceAllowed(lua_State* vm, int ifid)              const;
  bool isPcapDownloadAllowed(lua_State* vm, const char *ifname);
  char *preparePcapDownloadFilter(lua_State* vm, char *filter);
  bool isLocalAuthEnabled() const;
  bool isLocalUser(lua_State* vm);
  bool checkCaptiveUserPassword(const char * const user, const char * const password, char *group) const;
  bool checkGuiUserPassword(struct mg_connection *conn, const char * const user, const char * const password, char *group, bool *localuser) const;
  bool isBlacklistedLogin(struct mg_connection *conn) const;
  bool checkUserInterfaces(const char * const user)             const;
  bool resetUserPassword(char *username, char *old_password, char *new_password);
  bool mustChangePassword(const char *user);
  bool changeUserFullName(const char * const username, const char * const full_name) const;
  bool changeUserRole(char *username, char *user_role) const;
  bool changeAllowedNets(char *username, char *allowed_nets)     const;
  bool changeAllowedIfname(char *username, char *allowed_ifname) const;
  bool changeUserHostPool(const char * const username, const char * const host_pool_id) const;
  bool changeUserLanguage(const char * const username, const char * const language) const;
  bool changeUserPermission(const char * const username, bool allow_pcap_download) const;
  bool getUserPermission(const char * const username, bool *allow_pcap_download) const;
  bool existsUser(const char * const username) const;
  bool addUser(char *username, char *full_name, char *password, char *host_role,
	       char *allowed_networks, char *allowed_ifname, char *host_pool_id,
	       char *language, bool allow_pcap_download);
  bool addUserAPIToken(const char * const username, const char *api_token);
  bool isCaptivePortalUser(const char * const username);
  bool deleteUser(char *username);
  bool getUserHostPool(char *username, u_int16_t *host_pool_id);
  bool getUserAllowedIfname(const char * const username, char *buf, size_t buflen) const;
  bool getUserAPIToken(const char * const username, char *buf, size_t buflen) const;
  void setWorkingDir(char *dir);
  void fixPath(char *str, bool replaceDots = true);
  void removeTrailingSlash(char *str);
  void daemonize();
  void shutdownPeriodicActivities();
  void shutdownInterfaces();
  void shutdownAll();
  void runHousekeepingTasks();
  void runShutdownTasks();
  bool isLocalInterfaceAddress(int family, void *addr)       { return(local_interface_addresses.findAddress(family, addr) == -1 ? false : true);    }; 
  void getLocalNetworkIp(int16_t local_network_id, IpAddress **network_ip, u_int8_t *network_prefix);
  void addLocalNetworkList(const char *network);
  void createExportInterface();
  void resetNetworkInterfaces();
  void initElasticSearch();

  inline u_int32_t getStartTime()       { return((u_int32_t)start_time); }
  inline char*     getStartTimeString() { return(epoch_buf);             }
  inline u_int32_t getLastModifiedStaticFileEpoch()         { return(last_modified_static_file_epoch); }
  inline void      setLastModifiedStaticFileEpoch(u_int32_t t) { if(t > last_modified_static_file_epoch) last_modified_static_file_epoch = t; }
  inline u_int32_t getUptime()                 { return((u_int32_t)((start_time > 0) ? (time(NULL)-start_time) : 0)); }
  inline int getUdpSock()                      { return(udp_socket); }
#ifdef NTOPNG_PRO
  inline AlertExclusions *getAlertExclusions() { return alert_exclusions; }
#endif

  inline u_int getNumCPUs()             { return(num_cpus); }
  inline void setNumCPUs(u_int num)     { num_cpus = num; }
  inline bool canSendICMP()               { return(can_send_icmp); }
  inline bool canSelectNetworkIfaceICMP() {
#ifdef __linux__
    return(can_send_icmp);
#else
    return(false);
#endif
  }  

  inline NtopPro* getPro()              { return((NtopPro*)pro); };

  void loadTrackers();
  bool isATrackerHost(char *host);
  bool isExistingInterface(const char * const name) const;
  inline NetworkInterface* getFirstInterface()  const { return(iface[0]);         }
  inline NetworkInterface* getInterface(int i)  const { return(((i < num_defined_interfaces) && iface[i]) ? iface[i] : NULL); }
  inline NetworkInterface* getSystemInterface() const { return(system_interface); }
#ifdef NTOPNG_PRO
  bool addToNotifiedInformativeCaptivePortal(u_int32_t client_ip);
  bool addIPToLRUMatches(u_int32_t client_ip, u_int16_t user_pool_id, char *label, char *ifname);
#endif /* NTOPNG_PRO */
  
  DeviceProtocolBitmask* getDeviceAllowedProtocols(DeviceType t) { return(&deviceProtocolPresets[t]); }
  void refreshAllowedProtocolPresets(DeviceType t, bool client, lua_State *L, int index);
  DeviceProtoStatus getDeviceAllowedProtocolStatus(DeviceType dev_type, ndpi_protocol proto, u_int16_t pool_id, bool as_client);
  void refreshCPULoad();
  bool getCPULoad(float *out);
  inline void setLastInterfacenDPIReload(time_t now)      { last_ndpi_reload = now;   }
  inline bool needsnDPICleanup()                          { return(ndpi_cleanup_needed); }
  inline void setnDPICleanupNeeded(bool needed)           { ndpi_cleanup_needed = needed; }
  inline FifoSerializerQueue* getInternalAlertsQueue()    { return(internal_alerts_queue);  }
  void lua_alert_queues_stats(lua_State* vm);
  bool   recipients_enqueue(RecipientNotificationPriority prio, AlertFifoItem *notification, AlertEntity alert_entity);
  bool   recipient_enqueue(u_int16_t recipient_id, RecipientNotificationPriority prio, const AlertFifoItem* const notification);
  bool   recipient_dequeue(u_int16_t recipient_id, RecipientNotificationPriority prio, AlertFifoItem *notification);
  void   recipient_stats(u_int16_t recipient_id, lua_State* vm);
  time_t recipient_last_use(u_int16_t recipient_id);
  void   recipient_delete(u_int16_t recipient_id);
  void   recipient_register(u_int16_t recipient_id, AlertLevel minimum_severity, u_int8_t enabled_categories);
  void   recipient_set_flow_recipients(u_int64_t flow_recipients);
  void   recipient_set_host_recipients(u_int64_t host_recipients);


  void sendNetworkInterfacesTermination();
  inline time_t getLastStatsReset() { return(last_stats_reset); }
  void resetStats();

  bool isMaliciousJA3Hash(std::string md5_hash);
  struct ndpi_detection_module_struct* initnDPIStruct();    

  inline struct ndpi_detection_module_struct* get_ndpi_struct() const { return(ndpi_struct); };
  bool initnDPIReload();
  void finalizenDPIReload();
  inline bool isnDPIReloadInProgress()  { return(ndpiReloadInProgress);     }

  void checkReloadHostsBroadcastDomain();

  void nDPILoadIPCategory(char *what, ndpi_protocol_category_t id);
  void nDPILoadHostnameCategory(char *what, ndpi_protocol_category_t id);
  int nDPILoadMaliciousJA3Signatures(const char *file_path);

  inline ndpi_protocol_category_t get_ndpi_proto_category(ndpi_protocol proto) { return(ndpi_get_proto_category(get_ndpi_struct(), proto)); };
  ndpi_protocol_category_t get_ndpi_proto_category(u_int protoid);
  void setnDPIProtocolCategory(u_int16_t protoId, ndpi_protocol_category_t protoCategory);
  void reloadPeriodicScripts();
  inline void reloadFlowChecks()   { flowChecksReloadInProgress = true;    };
  inline void reloadHostChecks()   { hostChecksReloadInProgress = true;    };
  inline void reloadAlertExclusions() {
#ifdef NTOPNG_PRO
    alertExclusionsReloadInProgress = true;
#endif
  };
  inline void reloadHostPools()       { hostPoolsReloadInProgress = true;        };

  void addToPool(char *host_or_mac, u_int16_t user_pool_id);

  char *getAlertJSON(FlowAlertType fat, Flow *f) const;
  ndpi_serializer *getAlertSerializer(FlowAlertType fat, Flow *f) const;
  
#ifndef WIN32
  inline ContinuousPing* getContinuousPing() { return(cping); }
  inline Ping*           getPing()           { return(ping);  }
#endif
  inline bool hasDroppedPrivileges()         { return(privileges_dropped); }
  inline void setDroppedPrivileges()         { privileges_dropped = true; }

  void getUserGroupLocal(const char * const user, char *group) const;
  bool existsUserLocal(const char * const user) { char val[64]; return getUserPasswordHashLocal(user, val); }
  void purgeLoopBody();

  /* Local network address list methods */
  inline u_int8_t getNumLocalNetworks()       { return local_network_tree.getNumAddresses();    };
  inline const char* getLocalNetworkName(int16_t local_network_id) {
    return(((u_int8_t)local_network_id < local_network_tree.getNumAddresses()) ? local_network_names[(u_int8_t)local_network_id] : NULL);
  };
  
  u_int8_t getLocalNetworkId(const char *network_name);
  
  //void getLocalAddresses(lua_State* vm) { return(local_network_tree.getAddresses(vm)); };

  inline FlowChecksLoader* getFlowChecksLoader() { return(flow_checks_loader); }
  inline HostChecksLoader* getHostChecksLoader() { return(host_checks_loader); }
  inline u_int8_t getFlowAlertScore(FlowAlertTypeEnum alert_id) const { return flow_alerts_loader.getAlertScore(alert_id); };
  bool luaFlowCheckInfo(lua_State *vm, std::string check_name) const;
  bool luaHostCheckInfo(lua_State *vm, std::string check_name) const;
  inline ndpi_risk getUnhandledRisks() const { return flow_checks_loader ? flow_checks_loader->getUnhandledRisks() : 0; };
#ifndef HAVE_NEDGE
  bool broadcastIPSMessage(char *msg);
  inline void askToRefreshIPSRules()  { refresh_ips_rules = true; }
  inline bool timeToRefreshIPSRules() { bool rc = refresh_ips_rules; refresh_ips_rules = false; return(rc); }
#endif

  inline bool isOffline() { return offline; }
  inline void toggleOffline(bool off) { offline = off; }
};

extern Ntop *ntop;

#ifdef NTOPNG_PRO
#include "ntoppro_defines.h"
#endif

#endif /* _NTOP_CLASS_H_ */
