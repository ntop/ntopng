/*
 *
 * (C) 2013-17 - ntop.org
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

#ifndef _RUNTIME_PREFS_H_
#define _RUNTIME_PREFS_H_

#include "ntop_includes.h"

typedef enum {
  /* Dynamically allocated string */
  str = 0,
  /* Pointers to class members */
  str_ptr,
  ipv4_addr_ptr,
  u_int32_t_ptr,
  int32_t_ptr,
  bool_ptr,
  hostmask_ptr
} prefsptr_t;

typedef struct {
  char *key;
  prefsptr_t value_ptr;
  void* value;
  RwLock *rwlock;
  
  UT_hash_handle hh; /* makes this structure hashable */
} prefscache_t;

/** @defgroup Preferences Preferences
 * Ntopng preferences
 */


/** @class RuntimePrefs
 *  @brief Implement the user runtime preference for ntopng.
 *
 *  @ingroup Preferences
 *
 */
class RuntimePrefs {
 private:
  char path[MAX_PATH], tmp_path[MAX_PATH];

  prefscache_t *prefscache;
  bool prefscache_refreshed;
  RwLock *rwlock;

  u_int32_t non_local_host_max_idle, local_host_cache_duration, local_host_max_idle, flow_max_idle;
  u_int32_t active_local_hosts_cache_interval;
  u_int32_t intf_rrd_raw_days, intf_rrd_1min_days, intf_rrd_1h_days, intf_rrd_1d_days;
  u_int32_t other_rrd_raw_days, other_rrd_1min_days, other_rrd_1h_days, other_rrd_1d_days;
  u_int32_t housekeeping_frequency;
  bool disable_alerts, enable_top_talkers, enable_idle_local_hosts_cache, enable_active_local_hosts_cache;
  bool enable_tiny_flows_export, enable_flow_device_port_rrd_creation, enable_probing_alerts, enable_ssl_alerts;
  bool enable_syslog_alerts, enable_captive_portal, slack_notifications_enabled;
  bool dump_flow_alerts_when_iface_alerted;
  int32_t max_num_alerts_per_entity, max_num_flow_alerts;
  u_int32_t safe_search_dns_ip, global_primary_dns_ip, global_secondary_dns_ip;
  prefscache_t *redirection_url;
  u_int32_t max_num_packets_per_tiny_flow, max_num_bytes_per_tiny_flow;
  u_int32_t max_ui_strlen;
  HostMask hostMask;

  prefscache_t *addToCache(const char *key, prefsptr_t value_ptr, void *value);
 public:
  /**
   * @brief A Constructor.
   * @details Creating a new Runtime preference instance.
   *
   * @return A new instance of RuntimePrefs.
   */
  RuntimePrefs();
  virtual ~RuntimePrefs();

  int hashGet(char *key, char *rsp, u_int rsp_len);
  int refresh(const char *pref_name, const char *pref_value);

  inline void dumpIfRefreshed()                         { if(prefscache_refreshed) writeDump(); };
  virtual bool writeDump();
  virtual bool readDump();

  virtual void lua(lua_State* vm);

  virtual void setDumpPath(char *_path);
  json_object* getJSONObject();
  char *serialize();
  bool deserialize(char *json_str);

  inline u_int32_t get_housekeeping_frequency()         { return(housekeeping_frequency); };
  inline u_int32_t flow_aggregation_frequency()         { return(get_housekeeping_frequency() * FLOW_AGGREGATION_DURATION); };

  inline u_int32_t get_host_max_idle(bool localHost)    { return(localHost ? local_host_max_idle : non_local_host_max_idle);  };
  inline u_int32_t get_local_host_cache_duration()      { return(local_host_cache_duration);          };
  inline u_int32_t get_flow_max_idle()                  { return(flow_max_idle);          };
  inline bool  are_alerts_disabled()                    { return(disable_alerts);     };
  inline void  set_alerts_status(bool enabled)          { if(enabled) disable_alerts = false; else disable_alerts = true; };
  inline bool  are_top_talkers_enabled()                { return(enable_top_talkers);     };
  inline bool  is_idle_local_host_cache_enabled()       { return(enable_idle_local_hosts_cache);    };
  inline bool  is_active_local_host_cache_enabled()     { return(enable_active_local_hosts_cache);  };

  inline bool is_tiny_flows_export_enabled()             { return(enable_tiny_flows_export);  };
  inline bool is_flow_device_port_rrd_creation_enabled() { return(enable_flow_device_port_rrd_creation); };

  inline bool  are_probing_alerts_enabled()              { return(enable_probing_alerts);            };
  inline bool  are_ssl_alerts_enabled()                  { return(enable_ssl_alerts);                };
  inline bool  are_alerts_syslog_enabled()               { return(enable_syslog_alerts);             };
  inline bool are_slack_notification_enabled()           { return(slack_notifications_enabled);  };
  inline bool do_dump_flow_alerts_when_iface_alerted()   { return(dump_flow_alerts_when_iface_alerted); };

  inline bool isCaptivePortalEnabled()                   { return(enable_captive_portal);  }

  inline int32_t   get_max_num_alerts_per_entity()       { return(max_num_alerts_per_entity); };
  inline int32_t   get_max_num_flow_alerts()             { return(max_num_flow_alerts); };

  inline u_int32_t get_max_num_packets_per_tiny_flow()  { return(max_num_packets_per_tiny_flow); }
  inline u_int32_t get_max_num_bytes_per_tiny_flow()    { return(max_num_bytes_per_tiny_flow); }

  inline u_int32_t get_safe_search_dns_ip()      { return(safe_search_dns_ip);                          };
  inline u_int32_t get_global_primary_dns_ip()   { return(global_primary_dns_ip);                       };
  inline u_int32_t get_global_secondary_dns_ip() { return(global_secondary_dns_ip);                     };
  inline bool isGlobalDNSDefined()               { return(global_primary_dns_ip ? true : false);        };
  inline HostMask getHostMask()                  { return(hostMask);                                    };
};

#endif /* _RUNTIME_PREFS_H_ */
