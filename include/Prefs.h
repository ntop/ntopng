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

#ifndef _PREFS_H_
#define _PREFS_H_

#include "ntop_includes.h"

class Ntop;

extern void usage();

typedef struct {
  char *name, *description;
} InterfaceInfo;

class Prefs {
 private:
  u_int8_t num_deferred_interfaces_to_register;
  char *deferred_interfaces_to_register[MAX_NUM_INTERFACES];
  const char *http_binding_address, *https_binding_address;
  Ntop *ntop;
  bool enable_dns_resolution, sniff_dns_responses, disable_host_persistency,
    categorization_enabled, httpbl_enabled, resolve_all_host_ip, change_user, daemonize,
    enable_auto_logout, use_promiscuous_mode,
    disable_alerts, enable_ixia_timestamps, enable_vss_apcon_timestamps,
    enable_users_login, disable_localhost_login;
  LocationPolicy dump_hosts_to_db, sticky_hosts;
  u_int16_t non_local_host_max_idle, local_host_max_idle, flow_max_idle;
  u_int16_t intf_rrd_raw_days, intf_rrd_1min_days, intf_rrd_1h_days, intf_rrd_1d_days;
  u_int16_t other_rrd_raw_days, other_rrd_1min_days, other_rrd_1h_days, other_rrd_1d_days;
  u_int32_t max_num_hosts, max_num_flows;
  u_int http_port, https_port;
  u_int8_t num_interfaces, num_interface_views;
  bool dump_flows_on_sqlite, dump_flows_on_es, dump_flows_on_mysql;
  bool enable_taps;
  InterfaceInfo ifNames[MAX_NUM_INTERFACES];
  InterfaceInfo ifViewNames[MAX_NUM_INTERFACES];
  char *local_networks;
  bool local_networks_set, shutdown_when_done;
  char *data_dir, *install_dir, *docs_dir, *scripts_dir, *callbacks_dir, *export_endpoint;
  char *categorization_key;
  char *communities_file;
  char *httpbl_key;
  char *http_prefix;
  char *config_file_path, *ndpi_proto_path;
  char *packet_filter;
  char *user;
  char *redis_host;
  char *pid_path;
  char *cpu_affinity;
  u_int8_t redis_db_id;
  int redis_port;
  int dns_mode;
  bool json_labels_string_format;
  FILE *logFd;
  char *es_type, *es_index, *es_url, *es_user, *es_pwd;
#ifdef HAVE_MYSQL
  char *mysql_host, *mysql_dbname, *mysql_tablename, *mysql_user, *mysql_pw;
#endif
#ifdef NTOPNG_PRO
  char *nagios_host, *nagios_port, *nagios_config;
  bool save_http_flows_traffic;
#endif

  inline void help() { usage(); };
  int setOption(int optkey, char *optarg);
  int checkOptions();
  u_int32_t getDefaultPrefsValue(const char *pref_key, u_int32_t default_value);
  void getDefaultStringPrefsValue(const char *pref_key, char **buffer, const char *default_value);

  void bind_http_to_loopback()  { http_binding_address  = CONST_LOOPBACK_ADDRESS; };
  void bind_https_to_loopback() { https_binding_address = CONST_LOOPBACK_ADDRESS; };

 public:
  Prefs(Ntop *_ntop);
  ~Prefs();

  bool is_pro_edition();
  inline bool is_embedded_edition() {
#ifdef NTOPNG_EMBEDDED_EDITION
    return(true);
#else
    return(false);
#endif
  }
  time_t pro_edition_demo_ends_at();
  inline char* get_local_networks()                     { if (!local_networks_set) return NULL; return(local_networks); };
  inline FILE* get_log_fd()                             { return(logFd);                  };
  inline LocationPolicy get_host_stickness()            { return(sticky_hosts);           };
  inline void disable_dns_resolution()                  { enable_dns_resolution = false;  };
  inline void resolve_all_hosts()                       { resolve_all_host_ip = true;     };
  inline bool is_dns_resolution_enabled_for_all_hosts() { return(resolve_all_host_ip);    };
  inline bool is_dns_resolution_enabled()               { return(enable_dns_resolution);  };
  inline bool is_users_login_enabled()                  { return(enable_users_login);     };
  inline bool is_localhost_users_login_disabled()       { return(disable_localhost_login);};
  inline void disable_dns_responses_decoding()          { sniff_dns_responses = false;    };
  inline bool decode_dns_responses()                    { return(sniff_dns_responses);    };
  inline void enable_categorization()                   { categorization_enabled = true;  };
  inline void enable_httpbl()                           { httpbl_enabled = true;  };
  inline bool is_categorization_enabled()               { return(categorization_enabled); };
  inline bool is_httpbl_enabled()                       { return(httpbl_enabled); };
  inline bool do_change_user()                          { return(change_user);            };
  inline bool are_ixia_timestamps_enabled()             { return(enable_ixia_timestamps); };
  inline bool are_vss_apcon_timestamps_enabled()        { return(enable_vss_apcon_timestamps); };
  inline char* get_user()                               { return(user);                   };
  inline u_int8_t get_num_user_specified_interfaces()   { return(num_interfaces);         };
  inline u_int8_t get_num_user_specified_interface_views()   { return(num_interface_views);         };
  inline bool  do_dump_flows_on_sqlite()                { return(dump_flows_on_sqlite);   };
  inline bool  do_dump_flows_on_es()                    { return(dump_flows_on_es);       };
  inline bool  do_dump_flows_on_mysql()                 { return(dump_flows_on_mysql);    };
  inline char* get_if_name(u_int id)                    { return((id < MAX_NUM_INTERFACES) ? ifNames[id].name : NULL); };
  inline char* get_if_descr(u_int id)                   { return((id < MAX_NUM_INTERFACES) ? ifNames[id].description : NULL); };
  inline char* get_data_dir()                           { return(data_dir);       };
  inline char* get_docs_dir()                           { return(docs_dir);       }; // HTTP docs
  inline char* get_scripts_dir()                        { return(scripts_dir);    };
  inline char* get_callbacks_dir()                      { return(callbacks_dir);  };
  inline char* get_export_endpoint()                    { return(export_endpoint);};
  inline char* get_categorization_key()                 { return(categorization_key); };
  inline char* get_httpbl_key()                         { return(httpbl_key);  };
  inline char* get_http_prefix()                        { return(http_prefix); };
  inline bool  are_alerts_disabled()                    { return(disable_alerts);     };
  inline bool  is_host_persistency_enabled()            { return(disable_host_persistency ? false : true); };
  inline bool  do_auto_logout()                         { return(enable_auto_logout);        };
  inline char *get_cpu_affinity()                       { return(cpu_affinity);   };
  inline u_int get_http_port()                          { return(http_port);      };
  inline u_int get_https_port()                         { return(https_port);     };
  inline char* get_redis_host()                         { return(redis_host);     }
  inline u_int get_redis_port()                         { return(redis_port);     };
  inline u_int get_redis_db_id()                        { return(redis_db_id);    };
#ifdef NTOPNG_PRO
  inline char * get_nagios_host()                       { return(nagios_host);    };
  inline char * get_nagios_port()                       { return(nagios_port);    };
  inline char * get_nagios_config()                     { return(nagios_config);    };
  inline bool get_save_http_flows_traffic()             { return(save_http_flows_traffic); };
#endif
  inline char* get_pid_path()                           { return(pid_path);       };
  inline char* get_packet_filter()                      { return(packet_filter);  };
  inline u_int16_t get_host_max_idle(bool localHost)    { return(localHost ? local_host_max_idle : non_local_host_max_idle);  };
  inline u_int16_t get_flow_max_idle()                  { return(flow_max_idle);  };
  inline u_int32_t get_max_num_hosts()                  { return(max_num_hosts);  };
  inline u_int32_t get_max_num_flows()                  { return(max_num_flows);  };
  inline bool daemonize_ntopng()                        { return(daemonize);                        };
  void add_default_interfaces();
  int loadFromCLI(int argc, char *argv[]);
  int loadFromFile(const char *path);
  inline void set_dump_hosts_to_db_policy(LocationPolicy p)   { dump_hosts_to_db = p;               };
  inline LocationPolicy get_dump_hosts_to_db_policy()         { return(dump_hosts_to_db);           };
  int save();
  void add_network_interface(char *name, char *description);
  void add_network_interface_view(char *name, char *description);
  char *getInterfaceViewAt(int id);
  inline bool json_labels_as_strings()                        { return(json_labels_string_format);       };
  inline void set_json_symbolic_labels_format(bool as_string) { json_labels_string_format = as_string;   };
  void lua(lua_State* vm);
  void loadIdleDefaults();
  char *getCommunitiesFile(void)                        { return(communities_file); }
#ifdef NTOPNG_PRO
  void loadNagiosDefaults();
#endif
  void registerNetworkInterfaces();
  bool isView(char *name);

  inline const char* get_http_binding_address()  { return(http_binding_address);  };
  inline const char* get_https_binding_address() { return(https_binding_address); };

  inline char* get_es_type()  { return(es_type);  };
  inline char* get_es_index() { return(es_index); };
  inline char* get_es_url()   { return(es_url);   };
  inline char* get_es_user()  { return(es_user);  };
  inline char* get_es_pwd()   { return(es_pwd);   };
  inline bool shutdownWhenDone() { return(shutdown_when_done); }
  inline bool are_taps_enabled() { return(enable_taps); };
  inline void set_promiscuous_mode(bool mode)  { use_promiscuous_mode = mode; };
  inline bool use_promiscuous()  { return(use_promiscuous_mode); };
};

#endif /* _PREFS_H_ */
