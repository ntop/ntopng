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

#ifndef _PREFS_H_
#define _PREFS_H_

#include "ntop_includes.h"

class Ntop;
class Flow;

extern void usage();
extern void nDPIusage();

typedef struct {
  char *name, *description;
} InterfaceInfo;

class Prefs {
 private:
  u_int8_t num_deferred_interfaces_to_register;
  pcap_direction_t captureDirection;
  char *deferred_interfaces_to_register[MAX_NUM_INTERFACES], *cli;
  char *http_binding_address1, *http_binding_address2;
  char *https_binding_address1, *https_binding_address2;
  char *lan_interface;
  Ntop *ntop;
  bool enable_dns_resolution, sniff_dns_responses,
    categorization_enabled, resolve_all_host_ip, change_user, daemonize,
    enable_auto_logout, enable_auto_logout_at_runtime, use_promiscuous_mode,
    enable_ixia_timestamps, enable_vss_apcon_timestamps,
    enable_users_login, disable_localhost_login, online_license_check,
    service_license_check, enable_sql_log, enable_access_log, log_to_file,
    flow_aggregation_enabled,
    enable_mac_ndpi_stats;

  u_int32_t non_local_host_max_idle, local_host_cache_duration,
	  local_host_max_idle, flow_max_idle;
  u_int32_t active_local_hosts_cache_interval;
  u_int32_t intf_rrd_raw_days, intf_rrd_1min_days, intf_rrd_1h_days, intf_rrd_1d_days;
  u_int32_t other_rrd_raw_days, other_rrd_1min_days, other_rrd_1h_days, other_rrd_1d_days;
  u_int32_t housekeeping_frequency;
  bool disable_alerts, enable_top_talkers, enable_idle_local_hosts_cache,
	  enable_active_local_hosts_cache;
  bool enable_tiny_flows_export, enable_flow_device_port_rrd_creation,
    enable_probing_alerts, enable_ssl_alerts, enable_ip_reassignment_alerts;
  bool enable_dns_alerts, enable_remote_to_remote_alerts;
  bool enable_mining_alerts;
  bool enable_dropped_flows_alerts;
  bool enable_syslog_alerts, external_notifications_enabled;
  bool enable_captive_portal, enable_informative_captive_portal;
  bool dump_flow_alerts_when_iface_alerted;
  bool override_dst_with_post_nat_dst, override_src_with_post_nat_src;
  bool routing_mode_enabled, global_dns_forging_enabled;
  int32_t max_num_alerts_per_entity, max_num_flow_alerts;
  u_int32_t safe_search_dns_ip, global_primary_dns_ip, global_secondary_dns_ip;
  u_int32_t max_num_packets_per_tiny_flow, max_num_bytes_per_tiny_flow;
  u_int32_t max_ui_strlen;
  u_int8_t default_l7policy;
  HostMask hostMask;

  LocationPolicy dump_hosts_to_db, sticky_hosts;
  bool enable_user_scripts;
  u_int32_t max_num_hosts, max_num_flows;
  u_int32_t attacker_max_num_flows_per_sec, victim_max_num_flows_per_sec;
  u_int32_t attacker_max_num_syn_per_sec, victim_max_num_syn_per_sec;
  u_int8_t ewma_alpha_percent;
  u_int http_port, https_port;
  u_int8_t num_interfaces;
  u_int16_t auto_assigned_pool_id;
  bool dump_flows_on_es, dump_flows_on_mysql, dump_flows_on_ls, dump_flows_on_nindex;
  bool read_flows_from_mysql;
  bool enable_taps;
  InterfaceInfo ifNames[MAX_NUM_INTERFACES];
  char *local_networks;
  bool local_networks_set, shutdown_when_done, simulate_vlans, ignore_vlans;
  char *data_dir, *install_dir, *docs_dir, *scripts_dir,
	  *callbacks_dir, *prefs_dir, *export_endpoint;
  char *categorization_key;
  char *httpbl_key;
  char *zmq_encryption_pwd;
  char *http_prefix;
  char *instance_name;
  char *config_file_path, *ndpi_proto_path;
  char *packet_filter;
  char *user;
  char *redis_host;
  char *redis_password;
  char *pid_path;
  char *cpu_affinity;
  u_int8_t redis_db_id;
  int redis_port;
  int dns_mode;
  bool json_labels_string_format;
  char *es_type, *es_index, *es_url, *es_user, *es_pwd;
  char *mysql_host, *mysql_dbname, *mysql_tablename, *mysql_user, *mysql_pw;
  int mysql_port;
  char *ls_host,*ls_port,*ls_proto;
  bool has_cmdl_trace_lvl; /**< Indicate whether a verbose level 
			      has been provided on the command line.*/

  inline void help()      { usage();     }
  inline void nDPIhelp()  { nDPIusage(); }
  void setCommandLineString(int optkey, const char * optarg);
  int setOption(int optkey, char *optarg);
  int checkOptions();

  void setTraceLevelFromRedis();
  void parseHTTPPort(char *arg);

  static inline void set_binding_address(char ** const dest, const char * const addr) {
    if(dest && addr && addr[0] != '\0') {
      if(*dest) free(*dest);
      *dest = strdup(addr);
    }
  };
  bool getDefaultBoolPrefsValue(const char *pref_key, const bool default_value);

 public:
  Prefs(Ntop *_ntop);
  virtual ~Prefs();

  bool is_pro_edition();
  bool is_enterprise_edition();
  bool is_nedge_edition();
  bool is_nedge_enterprise_edition();


  
  inline bool is_embedded_edition() {
#ifdef NTOPNG_EMBEDDED_EDITION
    return(true);
#else
    return(false);
#endif
  }
  time_t pro_edition_demo_ends_at();
  inline char* get_local_networks()                     { if (!local_networks_set) return NULL; return(local_networks); };
  inline LocationPolicy get_host_stickiness()            { return(sticky_hosts);           };
  inline void disable_dns_resolution()                  { enable_dns_resolution = false;  };
  inline void resolve_all_hosts()                       { resolve_all_host_ip = true;     };
  inline bool is_dns_resolution_enabled_for_all_hosts() { return(resolve_all_host_ip);    };
  inline bool is_dns_resolution_enabled()               { return(enable_dns_resolution);  };
  inline bool is_users_login_enabled()                  { return(enable_users_login);     };
  inline bool is_localhost_users_login_disabled()       { return(disable_localhost_login);};
  inline bool is_log_to_file_enabled()                  { return(log_to_file);            };
  inline void disable_dns_responses_decoding()          { sniff_dns_responses = false;    };  
  inline bool decode_dns_responses()                    { return(sniff_dns_responses);    };
  inline void enable_categorization()                   { categorization_enabled = true;  };
  inline bool is_categorization_enabled()               { return(categorization_enabled); };
  inline void enable_flow_aggregation()                 { flow_aggregation_enabled = true;                                  };
  inline bool is_flow_aggregation_enabled()             { return(flow_aggregation_enabled);                                 };
  inline bool is_httpbl_enabled()                       { return(httpbl_key ? true : false); };
  inline bool do_change_user()                          { return(change_user);            };
  inline void dont_change_user()                        { change_user = false;            };
  inline bool is_sql_log_enabled()                      { return(enable_sql_log);         };
  inline bool is_access_log_enabled()                   { return(enable_access_log);      };
  inline void do_enable_access_log(bool state = true)   { enable_access_log = state;      };
  inline bool are_ixia_timestamps_enabled()             { return(enable_ixia_timestamps); };
  inline bool are_vss_apcon_timestamps_enabled()        { return(enable_vss_apcon_timestamps); };
  inline char* get_user()                               { return(user);                   };
  inline u_int8_t get_num_user_specified_interfaces()   { return(num_interfaces);         };
  inline bool  do_read_flows_from_nprobe_mysql()        { return(read_flows_from_mysql);  };
  inline bool  do_dump_flows_on_es()                    { return(dump_flows_on_es);       };
  inline bool  do_dump_flows_on_mysql()                 { return(dump_flows_on_mysql);    };
  inline bool  do_dump_flows_on_ls()                    { return(dump_flows_on_ls);       };
  inline bool  do_dump_flows_on_nindex()                { return(dump_flows_on_nindex);   };
    
  int32_t getDefaultPrefsValue(const char *pref_key, int32_t default_value);
  void getDefaultStringPrefsValue(const char *pref_key, char **buffer, const char *default_value);
  inline char* get_if_name(u_int id)                    { return((id < MAX_NUM_INTERFACES) ? ifNames[id].name : NULL); };
  inline char* get_if_descr(u_int id)                   { return((id < MAX_NUM_INTERFACES) ? ifNames[id].description : NULL); };
  inline char* get_config_file_path()                   { return(config_file_path); };
  inline char* get_ndpi_proto_file_path()               { return(ndpi_proto_path); };
  inline char* get_data_dir()                           { return(data_dir);       };
  inline char* get_docs_dir()                           { return(docs_dir);       }; // HTTP docs
  inline char* get_scripts_dir()                        { return(scripts_dir);    };
  inline char* get_callbacks_dir()                      { return(callbacks_dir);  };
  inline char* get_prefs_dir()                          { return(prefs_dir);      };
  inline char* get_export_endpoint()                    { return(export_endpoint);};
  inline char* get_categorization_key()                 { return(categorization_key); };
  inline char* get_httpbl_key()                         { return(httpbl_key);  };
  inline char* get_http_prefix()                        { return(http_prefix); };
  inline char* get_instance_name()                      { return(instance_name); };

  inline bool  are_user_scripts_enabled()               { return(enable_user_scripts);              };
  inline bool  do_auto_logout()                         { return(enable_auto_logout);               };
  inline bool  do_auto_logout_at_runtime()              { return(enable_auto_logout_at_runtime);    };
  inline bool  do_ignore_vlans()                        { return(ignore_vlans);                     };
  inline bool  do_simulate_vlans()                      { return(simulate_vlans);                   };
  inline char* get_cpu_affinity()                       { return(cpu_affinity);   };
  inline u_int get_http_port()                          { return(http_port);      };
  inline u_int get_https_port()                         { return(https_port);     };
  inline char* get_redis_host()                         { return(redis_host);     }
  inline char* get_redis_password()                     { return(redis_password); }
  inline u_int get_redis_port()                         { return(redis_port);     };
  inline u_int get_redis_db_id()                        { return(redis_db_id);    };
  inline char* get_pid_path()                           { return(pid_path);       };
  inline char* get_packet_filter()                      { return(packet_filter);  };

  inline u_int32_t get_max_num_hosts()                  { return(max_num_hosts);          };
  inline u_int32_t get_max_num_flows()                  { return(max_num_flows);          };

  inline bool daemonize_ntopng()                        { return(daemonize);              };

  inline u_int32_t get_attacker_max_num_flows_per_sec() { return(attacker_max_num_flows_per_sec); };
  inline u_int32_t get_victim_max_num_flows_per_sec()   { return(victim_max_num_flows_per_sec);   };
  inline u_int32_t get_attacker_max_num_syn_per_sec()   { return(attacker_max_num_syn_per_sec);   };
  inline u_int32_t get_victim_max_num_syn_per_sec()     { return(victim_max_num_syn_per_sec);     };
  inline u_int8_t  get_ewma_alpha_percent()             { return(ewma_alpha_percent);             };

  void add_default_interfaces();
  int loadFromCLI(int argc, char *argv[]);
  int loadFromFile(const char *path);
  inline void set_dump_hosts_to_db_policy(LocationPolicy p)   { dump_hosts_to_db = p;               };
  inline LocationPolicy get_dump_hosts_to_db_policy()         { return(dump_hosts_to_db);           };
  void add_network_interface(char *name, char *description);
  inline bool json_labels_as_strings()                        { return(json_labels_string_format);       };
  inline void set_json_symbolic_labels_format(bool as_string) { json_labels_string_format = as_string;   };
  void set_routing_mode(bool enabled);
  virtual void lua(lua_State* vm);
  void reloadPrefsFromRedis();
  void loadInstanceNameDefaults();
  void registerNetworkInterfaces();
  void refreshHostsAlertsPrefs();

  void bind_http_to_address(const char * const addr1, const char * const addr2);
  void bind_https_to_address(const char * const addr1, const char * const addr2);
  void bind_http_to_loopback()  { bind_http_to_address((char*)CONST_LOOPBACK_ADDRESS, (char*)CONST_LOOPBACK_ADDRESS);  };
  inline void bind_https_to_loopback() { bind_https_to_address((char*)CONST_LOOPBACK_ADDRESS, (char*)CONST_LOOPBACK_ADDRESS); };
  inline void get_http_binding_addresses(const char** addr1, const char** addr2) { *addr1=http_binding_address1; *addr2=http_binding_address2; };
  inline void get_https_binding_addresses(const char** addr1, const char** addr2) { *addr1=https_binding_address1; *addr2=https_binding_address2; };

  inline bool checkLicenseOnline()               { return(online_license_check);  };
  inline bool checkServiceLicense()              { return(service_license_check); };
  inline void disableServiceLicense()            { service_license_check = false; };
  inline char* get_es_type()  { return(es_type);  };
  inline char* get_es_index() { return(es_index); };
  inline char* get_es_url()   { return(es_url);   };
  inline char* get_es_user()  { return(es_user);  };
  inline char* get_es_pwd()   { return(es_pwd);   };
  inline bool shutdownWhenDone() { return(shutdown_when_done); }
  inline bool are_taps_enabled() { return(enable_taps); };
  inline void set_promiscuous_mode(bool mode)  { use_promiscuous_mode = mode; };
  inline bool use_promiscuous()         { return(use_promiscuous_mode);  };
  inline char* get_mysql_host()         { return(mysql_host);            };
  inline int get_mysql_port()           { return(mysql_port);            };
  inline char* get_mysql_dbname()       { return(mysql_dbname);          };
  inline char* get_mysql_tablename()    { return(mysql_tablename);       };
  inline char* get_mysql_user()         { return(mysql_user);            };
  inline char* get_mysql_pw()           { return(mysql_pw);              };
  inline char* get_ls_host()            { return(ls_host);               };
  inline char* get_ls_port()		{ return(ls_port);		 };
  inline char* get_ls_proto()		{ return(ls_proto);		 };
  inline char* get_zmq_encryption_pwd() { return(zmq_encryption_pwd);    };
  inline char* get_command_line()       { return(cli ? cli : (char*)""); };
  inline char* get_lan_interface()      { return(lan_interface ? lan_interface : (char*)""); };
  inline void set_lan_interface(char *iface) { if(lan_interface) free(lan_interface); lan_interface = strdup(iface); };

  inline char* getInterfaceAt(int id)   { return((id >= MAX_NUM_INTERFACES) ? NULL : ifNames[id].name); };
  inline bool areMacNdpiStatsEnabled()  { return(enable_mac_ndpi_stats); };
  inline pcap_direction_t getCaptureDirection() { return(captureDirection); }
  inline void setCaptureDirection(pcap_direction_t dir) { captureDirection = dir; }
  inline bool hasCmdlTraceLevel()      { return has_cmdl_trace_lvl;      }

  inline u_int32_t get_housekeeping_frequency()         { return(housekeeping_frequency); };
  inline u_int32_t flow_aggregation_frequency()         { return(get_housekeeping_frequency() * FLOW_AGGREGATION_DURATION); };

  inline u_int32_t get_host_max_idle(bool localHost)    { return(localHost ? local_host_max_idle : non_local_host_max_idle);  };
  inline u_int32_t get_local_host_cache_duration()      { return(local_host_cache_duration);          };
  inline u_int32_t get_flow_max_idle()                  { return(flow_max_idle);          };
  inline bool  are_alerts_disabled()                    { return(disable_alerts);         };
  inline void  set_alerts_status(bool enabled)          { if(enabled) disable_alerts = false; else disable_alerts = true; };
  inline bool  are_top_talkers_enabled()                { return(enable_top_talkers);     };
  inline bool  is_idle_local_host_cache_enabled()       { return(enable_idle_local_hosts_cache);    };
  inline bool  is_active_local_host_cache_enabled()     { return(enable_active_local_hosts_cache);  };

  inline bool is_tiny_flows_export_enabled()             { return(enable_tiny_flows_export);  };
  inline bool is_flow_device_port_rrd_creation_enabled() { return(enable_flow_device_port_rrd_creation);};
  inline bool are_ip_reassignment_alerts_enabled()       { return(enable_ip_reassignment_alerts);       };
  inline bool are_probing_alerts_enabled()               { return(enable_probing_alerts);               };
  inline bool are_ssl_alerts_enabled()                   { return(enable_ssl_alerts);                   };
  inline bool are_dns_alerts_enabled()                   { return(enable_dns_alerts);                   };
  inline bool are_mining_alerts_enabled()                { return(enable_mining_alerts);                };
  inline bool are_remote_to_remote_alerts_enabled()      { return(enable_remote_to_remote_alerts);      };
  inline bool are_dropped_flows_alerts_enabled()         { return(enable_dropped_flows_alerts);         };
  inline bool are_alerts_syslog_enabled()                { return(enable_syslog_alerts);                };
  inline bool are_ext_alerts_notifications_enabled()     { return(external_notifications_enabled);      };
  inline bool do_dump_flow_alerts_when_iface_alerted()   { return(dump_flow_alerts_when_iface_alerted); };

  inline bool do_override_dst_with_post_nat_dst()   { return(override_dst_with_post_nat_dst); };
  inline bool do_override_src_with_post_nat_src()   { return(override_src_with_post_nat_src); };

  inline bool isCaptivePortalEnabled()                   { return(enable_captive_portal);              }
  inline bool isInformativeCaptivePortalEnabled()        { return(enable_informative_captive_portal);  }
  const char * const getCaptivePortalUrl();

  inline u_int8_t  getDefaultl7Policy()                  { return(default_l7policy);  }

  inline int32_t   get_max_num_alerts_per_entity()       { return(max_num_alerts_per_entity); };
  inline int32_t   get_max_num_flow_alerts()             { return(max_num_flow_alerts); };

  inline u_int32_t get_max_num_packets_per_tiny_flow()  { return(max_num_packets_per_tiny_flow); }
  inline u_int32_t get_max_num_bytes_per_tiny_flow()    { return(max_num_bytes_per_tiny_flow); }

  inline u_int32_t get_safe_search_dns_ip()      { return(safe_search_dns_ip);                          };
  inline u_int32_t get_global_primary_dns_ip()   { return(global_primary_dns_ip);                       };
  inline u_int32_t get_global_secondary_dns_ip() { return(global_secondary_dns_ip);                     };
  inline bool isGlobalDNSDefined()               { return(global_primary_dns_ip ? true : false);        };
  inline HostMask getHostMask()                  { return(hostMask);                                    };
  inline u_int16_t get_auto_assigned_pool_id()   { return(auto_assigned_pool_id);                       };
  inline u_int16_t is_routing_mode()             { return(routing_mode_enabled);                        };
  inline bool isGlobalDnsForgingEnabled()        { return(global_dns_forging_enabled);                  };

  void validate();
};

#endif /* _PREFS_H_ */

