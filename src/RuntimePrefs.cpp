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

#include "ntop_includes.h"

/* ******************************************* */

RuntimePrefs::RuntimePrefs() {
  snprintf(path, sizeof(path), "%s/%s",
	   ntop->get_working_dir(), CONST_DEFAULT_PREFS_FILE);

  prefscache = NULL;
  prefscache_refreshed = false;

  housekeeping_frequency = HOUSEKEEPING_FREQUENCY,
    addToCache(CONST_RUNTIME_PREFS_HOUSEKEEPING_FREQUENCY, u_int32_t_ptr, (void*)&housekeeping_frequency);

  local_host_cache_duration = LOCAL_HOSTS_CACHE_DURATION,
    addToCache(CONST_LOCAL_HOST_CACHE_DURATION_PREFS, u_int32_t_ptr, (void*)&local_host_cache_duration);

  local_host_max_idle = MAX_LOCAL_HOST_IDLE,
    addToCache(CONST_LOCAL_HOST_IDLE_PREFS, u_int32_t_ptr, (void*)&local_host_max_idle);

  non_local_host_max_idle = MAX_REMOTE_HOST_IDLE,
    addToCache(CONST_REMOTE_HOST_IDLE_PREFS, u_int32_t_ptr, (void*)&non_local_host_max_idle);

  flow_max_idle = MAX_FLOW_IDLE,
    addToCache(CONST_FLOW_MAX_IDLE_PREFS, u_int32_t_ptr, (void*)&flow_max_idle);

  active_local_hosts_cache_interval = CONST_DEFAULT_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL,
    addToCache(CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL, u_int32_t_ptr, (void*)&active_local_hosts_cache_interval);


  intf_rrd_raw_days = INTF_RRD_RAW_DAYS, addToCache(CONST_INTF_RRD_RAW_DAYS, u_int32_t_ptr, (void*)&intf_rrd_raw_days);
  intf_rrd_1min_days = INTF_RRD_1MIN_DAYS, addToCache(CONST_INTF_RRD_1MIN_DAYS, u_int32_t_ptr, (void*)&intf_rrd_1min_days);
  intf_rrd_1h_days = INTF_RRD_1H_DAYS, addToCache(CONST_INTF_RRD_1H_DAYS, u_int32_t_ptr, (void*)&intf_rrd_1h_days);
  intf_rrd_1d_days = INTF_RRD_1D_DAYS, addToCache(CONST_INTF_RRD_1D_DAYS, u_int32_t_ptr, (void*)&intf_rrd_1d_days);
  other_rrd_raw_days = OTHER_RRD_RAW_DAYS, addToCache(CONST_OTHER_RRD_RAW_DAYS, u_int32_t_ptr, (void*)&other_rrd_raw_days);
  other_rrd_1min_days = OTHER_RRD_1MIN_DAYS, addToCache(CONST_OTHER_RRD_1MIN_DAYS, u_int32_t_ptr, (void*)&other_rrd_1min_days);
  other_rrd_1h_days = OTHER_RRD_1H_DAYS, addToCache(CONST_OTHER_RRD_1H_DAYS, u_int32_t_ptr, (void*)&other_rrd_1h_days);
  other_rrd_1d_days = OTHER_RRD_1D_DAYS, addToCache(CONST_OTHER_RRD_1D_DAYS, u_int32_t_ptr, (void*)&other_rrd_1d_days);

  
  enable_top_talkers = CONST_DEFAULT_TOP_TALKERS_ENABLED,
    addToCache(CONST_TOP_TALKERS_ENABLED, bool_ptr, (void*)&enable_top_talkers);

  enable_idle_local_hosts_cache   = CONST_DEFAULT_IS_IDLE_LOCAL_HOSTS_CACHE_ENABLED,
    addToCache(CONST_RUNTIME_IDLE_LOCAL_HOSTS_CACHE_ENABLED, bool_ptr, (void*)&enable_idle_local_hosts_cache);

  enable_active_local_hosts_cache = CONST_DEFAULT_IS_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED,
    addToCache(CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED, bool_ptr, (void*)&enable_active_local_hosts_cache);

  enable_tiny_flows_export = CONST_DEFAULT_IS_TINY_FLOW_EXPORT_ENABLED,
    addToCache(CONST_IS_TINY_FLOW_EXPORT_ENABLED, bool_ptr, (void*)&enable_tiny_flows_export);


  max_num_alerts_per_entity = ALERTS_MANAGER_MAX_ENTITY_ALERTS,
    addToCache(CONST_MAX_NUM_ALERTS_PER_ENTITY, int32_t_ptr, (void*)&max_num_alerts_per_entity);

  max_num_flow_alerts = ALERTS_MANAGER_MAX_FLOW_ALERTS,
    addToCache(CONST_MAX_NUM_FLOW_ALERTS, int32_t_ptr, (void*)&max_num_flow_alerts);


  enable_flow_device_port_rrd_creation = false,
    addToCache(CONST_RUNTIME_PREFS_FLOW_DEVICE_PORT_RRD_CREATION, bool_ptr, (void*)&enable_flow_device_port_rrd_creation);


  disable_alerts = false,
    addToCache(CONST_ALERT_DISABLED_PREFS, bool_ptr, (void*)&disable_alerts);

  enable_probing_alerts = CONST_DEFAULT_ALERT_PROBING_ENABLED,
    addToCache(CONST_RUNTIME_PREFS_ALERT_PROBING, bool_ptr, (void*)&enable_probing_alerts);

  enable_ssl_alerts = CONST_DEFAULT_ALERT_SSL_ENABLED,
    addToCache(CONST_RUNTIME_PREFS_ALERT_SSL, bool_ptr, (void*)&enable_ssl_alerts);

  enable_syslog_alerts = CONST_DEFAULT_ALERT_SYSLOG_ENABLED,
    addToCache(CONST_RUNTIME_PREFS_ALERT_SYSLOG, bool_ptr, (void*)&enable_syslog_alerts);

  slack_notifications_enabled = false,
    addToCache(ALERTS_MANAGER_SLACK_NOTIFICATIONS_ENABLED, bool_ptr, (void*)&slack_notifications_enabled);


  dump_flow_alerts_when_iface_alerted = false,
    addToCache(ALERTS_DUMP_DURING_IFACE_ALERTED, bool_ptr, (void*)&dump_flow_alerts_when_iface_alerted);


  max_num_packets_per_tiny_flow = CONST_DEFAULT_MAX_NUM_PACKETS_PER_TINY_FLOW,
    addToCache(CONST_MAX_NUM_PACKETS_PER_TINY_FLOW, u_int32_t_ptr, (void*)&max_num_packets_per_tiny_flow);

  max_num_bytes_per_tiny_flow = CONST_DEFAULT_MAX_NUM_BYTES_PER_TINY_FLOW,
    addToCache(CONST_MAX_NUM_BYTES_PER_TINY_FLOW, u_int32_t_ptr, (void*)&max_num_bytes_per_tiny_flow);


  safe_search_dns_ip = inet_addr(DEFAULT_SAFE_SEARCH_DNS),
    addToCache(CONST_SAFE_SEARCH_DNS, u_int32_t_ptr, (void*)&safe_search_dns_ip);

  global_primary_dns_ip = inet_addr(DEFAULT_GLOBAL_DNS),
    addToCache(CONST_GLOBAL_DNS, u_int32_t_ptr, (void*)&global_primary_dns_ip);

  global_secondary_dns_ip = inet_addr(DEFAULT_GLOBAL_DNS),
    addToCache(CONST_SECONDARY_DNS, u_int32_t_ptr, (void*)&global_secondary_dns_ip);


  enable_captive_portal = false,
    addToCache(CONST_PREFS_CAPTIVE_PORTAL, bool_ptr, (void*)&enable_captive_portal);

  redirection_url = strdup(DEFAULT_REDIRECTION_URL),
    addToCache(CONST_PREFS_REDIRECTION_URL, str_ptr, (void*)&redirection_url);
  redirection_url_shadow = NULL;


  hostMask = no_host_mask,
    addToCache(CONST_RUNTIME_PREFS_HOSTMASK, hostmask_ptr, (void*)&hostMask);

  readDump();
}

/* ******************************************* */

void RuntimePrefs::addToCache(const char *key, prefsptr_t value_ptr, void *value) {
  prefscache_t *m = (prefscache_t*)calloc(1, sizeof(prefscache_t));

  if(m) {
    m->key = key, m->value_ptr = value_ptr, m->value = value;
    if(m->key) HASH_ADD_STR(prefscache, key, m); else free(m);
  }
}

/* ******************************************* */

int RuntimePrefs::hashGet(char *key, char *rsp, u_int rsp_len) {
  int ret = -1;
  prefscache_t *m = NULL;

  HASH_FIND_STR(prefscache, key, m);

  if(m) {
    switch(m->value_ptr) {
    case str_ptr:
      ret = snprintf(rsp, rsp_len, "%s", (char*)m->value);
      break;

    case u_int32_t_ptr:
      ret = snprintf(rsp, rsp_len, "%u", *((u_int32_t*)m->value));
      break;

    case int32_t_ptr:
      ret = snprintf(rsp, rsp_len, "%i", *((int32_t*)m->value));
      break;

    case bool_ptr:
      ret = snprintf(rsp, rsp_len, "%s", *((bool*)m->value) ? (char*)"1" : (char*)"0");
      break;

    case hostmask_ptr:
      ret = snprintf(rsp, rsp_len, "%i", *((HostMask*)m->value));
      break;

    default:
      break;
    }
  }

#ifdef DEBUG
  if(ret > 0)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Found RuntimePrefs cache entry [key: %s][val: %s]", key, rsp);
  else
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Unable to find RuntimePrefs cache entry [key: %s]", key);
#endif

  return ret;
}

/* ******************************************* */

RuntimePrefs::~RuntimePrefs() {
  prefscache_t *cur, *tmp;

  writeDump();

  HASH_ITER(hh, prefscache, cur, tmp) {
    HASH_DEL(prefscache, cur);  /* delete; users advances to next */
    free(cur);                  /* optional- if you want to free  */
  }

  if(redirection_url_shadow)
    free(redirection_url_shadow);
  if(redirection_url)
    free(redirection_url);
}

/* ******************************************* */

json_object* RuntimePrefs::getJSONObject() {
  char *red_url = redirection_url;
  json_object *my_object;

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  json_object_object_add(my_object, "housekeeping_frequency", json_object_new_int(housekeeping_frequency));
  json_object_object_add(my_object, "local_host_cache_duration", json_object_new_int64(local_host_cache_duration));
  json_object_object_add(my_object, "local_host_max_idle", json_object_new_int64(local_host_max_idle));
  json_object_object_add(my_object, "non_local_host_max_idle", json_object_new_int64(non_local_host_max_idle));
  json_object_object_add(my_object, "flow_max_idle", json_object_new_int64(flow_max_idle));
  json_object_object_add(my_object, "active_local_hosts_cache_interval", json_object_new_int64(active_local_hosts_cache_interval));

  json_object_object_add(my_object, "intf_rrd_raw_days", json_object_new_int(intf_rrd_raw_days));
  json_object_object_add(my_object, "intf_rrd_1min_days", json_object_new_int(intf_rrd_1min_days));
  json_object_object_add(my_object, "intf_rrd_1h_days", json_object_new_int(intf_rrd_1h_days));
  json_object_object_add(my_object, "intf_rrd_1d_days", json_object_new_int(intf_rrd_1d_days));
  json_object_object_add(my_object, "other_rrd_raw_days", json_object_new_int(other_rrd_raw_days));
  json_object_object_add(my_object, "other_rrd_1min_days", json_object_new_int(other_rrd_1min_days));
  json_object_object_add(my_object, "other_rrd_1h_days", json_object_new_int(other_rrd_1h_days));

  json_object_object_add(my_object, "enable_top_talkers", json_object_new_boolean(enable_top_talkers));
  json_object_object_add(my_object, "enable_idle_local_hosts_cache", json_object_new_boolean(enable_idle_local_hosts_cache));
  json_object_object_add(my_object, "enable_active_local_hosts_cache", json_object_new_boolean(enable_active_local_hosts_cache));

  json_object_object_add(my_object, "enable_tiny_flows_export", json_object_new_boolean(enable_tiny_flows_export));
  json_object_object_add(my_object, "max_num_alerts_per_entity", json_object_new_int(max_num_alerts_per_entity));
  json_object_object_add(my_object, "max_num_flow_alerts", json_object_new_int(max_num_flow_alerts));

  json_object_object_add(my_object, "enable_flow_device_port_rrd_creation", json_object_new_boolean(enable_flow_device_port_rrd_creation));

  json_object_object_add(my_object, "disable_alerts", json_object_new_boolean(disable_alerts));
  json_object_object_add(my_object, "enable_probing_alerts", json_object_new_boolean(enable_probing_alerts));
  json_object_object_add(my_object, "enable_ssl_alerts", json_object_new_boolean(enable_ssl_alerts));
  json_object_object_add(my_object, "enable_syslog_alerts", json_object_new_boolean(enable_syslog_alerts));
  json_object_object_add(my_object, "slack_notifications_enabled", json_object_new_boolean(slack_notifications_enabled));  

  json_object_object_add(my_object, "max_num_packets_per_tiny_flow", json_object_new_int64(max_num_packets_per_tiny_flow));
  json_object_object_add(my_object, "max_num_bytes_per_tiny_flow", json_object_new_int64(max_num_bytes_per_tiny_flow));

  json_object_object_add(my_object, "safe_search_dns_ip", json_object_new_int64(safe_search_dns_ip));
  json_object_object_add(my_object, "global_primary_dns_ip", json_object_new_int64(global_primary_dns_ip));
  json_object_object_add(my_object, "global_secondary_dns_ip", json_object_new_int64(global_secondary_dns_ip));

  json_object_object_add(my_object, "enable_captive_portal", json_object_new_boolean(enable_captive_portal));
  json_object_object_add(my_object, "redirection_url", json_object_new_string(red_url));

  json_object_object_add(my_object, "intf_rrd_raw_days", json_object_new_int(intf_rrd_raw_days));

  json_object_object_add(my_object, "host_mask", json_object_new_int(hostMask));
  return my_object;
}

/* *************************************** */

void RuntimePrefs::int2redis(char *k, u_int32_t val) {
  char buf[32];
  snprintf(buf, sizeof(buf), "%u", val);
  ntop->getRedis()->set(k, buf);
}

/* *************************************** */

void RuntimePrefs::str2redis(char *k, char *val) {
  ntop->getRedis()->set(k, val);
}

/* *************************************** */

char* RuntimePrefs::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return rsp;
}

/* *************************************** */

bool RuntimePrefs::deserialize(char *json_str) {
  json_object *o, *obj;
  enum json_tokener_error jerr = json_tokener_success;

  if((o = json_tokener_parse_verbose(json_str, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] %s",
				 json_tokener_error_desc(jerr),
				 json_str);
    return false;
  }

  if(json_object_object_get_ex(o, "housekeeping_frequency", &obj)) { housekeeping_frequency = json_object_get_int(obj); }
  if(json_object_object_get_ex(o, "local_host_cache_duration", &obj)) local_host_cache_duration = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "local_host_max_idle", &obj)) local_host_max_idle = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "non_local_host_max_idle", &obj)) non_local_host_max_idle = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "flow_max_idle", &obj)) flow_max_idle = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "active_local_hosts_cache_interval", &obj)) active_local_hosts_cache_interval = json_object_get_int64(obj);

  if(json_object_object_get_ex(o, "intf_rrd_raw_days", &obj)) intf_rrd_raw_days = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "intf_rrd_1min_days", &obj)) intf_rrd_1min_days = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "intf_rrd_1h_days", &obj)) intf_rrd_1h_days = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "intf_rrd_1d_days", &obj)) intf_rrd_1d_days = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "other_rrd_raw_days", &obj)) other_rrd_raw_days = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "other_rrd_1min_days", &obj)) other_rrd_1min_days = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "other_rrd_1h_days", &obj)) other_rrd_1h_days = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "other_rrd_1d_days", &obj)) other_rrd_1d_days = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "enable_top_talkers", &obj)) enable_top_talkers = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "enable_idle_local_hosts_cache", &obj)) enable_idle_local_hosts_cache = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "enable_active_local_hosts_cache", &obj)) enable_active_local_hosts_cache = json_object_get_boolean(obj);

  if(json_object_object_get_ex(o, "enable_tiny_flows_export", &obj)) enable_tiny_flows_export = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "max_num_alerts_per_entity", &obj)) max_num_alerts_per_entity = json_object_get_int(obj);
  if(json_object_object_get_ex(o, "max_num_flow_alerts", &obj)) max_num_flow_alerts = json_object_get_int(obj);

  if(json_object_object_get_ex(o, "enable_flow_device_port_rrd_creation", &obj)) enable_flow_device_port_rrd_creation = json_object_get_boolean(obj);

  if(json_object_object_get_ex(o, "disable_alerts", &obj)) disable_alerts = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "enable_probing_alerts", &obj)) enable_probing_alerts = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "enable_ssl_alerts", &obj)) enable_ssl_alerts = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "enable_syslog_alerts", &obj)) enable_syslog_alerts = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "slack_notifications_enabled", &obj)) slack_notifications_enabled = json_object_get_boolean(obj);

  if(json_object_object_get_ex(o, "max_num_packets_per_tiny_flow", &obj)) max_num_packets_per_tiny_flow = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "max_num_bytes_per_tiny_flow", &obj)) max_num_bytes_per_tiny_flow = json_object_get_int64(obj);

  if(json_object_object_get_ex(o, "safe_search_dns_ip", &obj)) safe_search_dns_ip = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "global_primary_dns_ip", &obj)) global_primary_dns_ip = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "global_secondary_dns_ip", &obj)) global_secondary_dns_ip = json_object_get_int64(obj);

  if(json_object_object_get_ex(o, "enable_captive_portal", &obj)) enable_captive_portal = json_object_get_boolean(obj);
  if(json_object_object_get_ex(o, "redirection_url", &obj)) {
    if(redirection_url_shadow)
      free(redirection_url_shadow);
    redirection_url_shadow = redirection_url;
    redirection_url = strdup(json_object_get_string(obj));
  }

  if(json_object_object_get_ex(o, "host_mask", &obj)) hostMask = (HostMask)json_object_get_int64(obj);

  return true;
}

/* *************************************** */

bool RuntimePrefs::writeDump() {
  bool ret = true;
  char *rsp = serialize();

  if(rsp) {
    FILE *fd = fopen(path, "wb");

    if(fd == NULL) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to serialize runtime preferences %s", path);
      ret = false;
    } else {
      fwrite(rsp, strlen(rsp), 1, fd);
      fclose(fd);

      prefscache_refreshed = false;
    }
    free(rsp);
  }

  return ret;
}

/* *************************************** */

bool RuntimePrefs::readDump() {
  bool ret = true;
  char *buffer = NULL;
  u_int64_t length;
  FILE *f = fopen(path, "rb");

  if(!f) {
    ret = false;
  } else {
    fseek (f, 0, SEEK_END);
    length = ftell(f);
    fseek (f, 0, SEEK_SET);

    buffer = (char*)malloc(length);
    if(buffer)
      fread(buffer, 1, length, f);

    fclose(f);
  }

  if(buffer) {
    ret = deserialize(buffer);
    free(buffer);
  }

  return ret;
}

/* *************************************** */

void RuntimePrefs::lua(lua_State* vm) {
  char buf[32];
  char *redurl = redirection_url;

  lua_push_int_table_entry(vm, "housekeeping_frequency",    housekeeping_frequency);
  lua_push_int_table_entry(vm, "local_host_cache_duration", local_host_cache_duration);
  lua_push_int_table_entry(vm, "local_host_max_idle", local_host_max_idle);
  lua_push_int_table_entry(vm, "non_local_host_max_idle", non_local_host_max_idle);
  lua_push_int_table_entry(vm, "flow_max_idle", flow_max_idle);
  if(enable_active_local_hosts_cache)
    lua_push_int_table_entry(vm, "active_local_hosts_cache_interval", active_local_hosts_cache_interval);

  lua_push_int_table_entry(vm, "intf_rrd_raw_days", intf_rrd_raw_days);
  lua_push_int_table_entry(vm, "intf_rrd_1min_days", intf_rrd_1min_days);
  lua_push_int_table_entry(vm, "intf_rrd_1h_days", intf_rrd_1h_days);
  lua_push_int_table_entry(vm, "intf_rrd_1d_days", intf_rrd_1d_days);
  lua_push_int_table_entry(vm, "other_rrd_raw_days", other_rrd_raw_days);
  lua_push_int_table_entry(vm, "other_rrd_1min_days", other_rrd_1min_days);
  lua_push_int_table_entry(vm, "other_rrd_1h_days", other_rrd_1h_days);
  lua_push_int_table_entry(vm, "other_rrd_1d_days", other_rrd_1d_days);

  lua_push_bool_table_entry(vm, "are_top_talkers_enabled", enable_top_talkers);
  lua_push_bool_table_entry(vm, "is_active_local_hosts_cache_enabled", enable_active_local_hosts_cache);

  lua_push_bool_table_entry(vm,"is_tiny_flows_export_enabled",  enable_tiny_flows_export);
  lua_push_int_table_entry(vm, "max_num_alerts_per_entity", max_num_alerts_per_entity);
  lua_push_int_table_entry(vm, "max_num_flow_alerts", max_num_flow_alerts);

  lua_push_bool_table_entry(vm, "is_flow_device_port_rrd_creation_enabled", enable_flow_device_port_rrd_creation);

  lua_push_bool_table_entry(vm, "are_alerts_enabled", !disable_alerts);
  lua_push_bool_table_entry(vm, "slack_enabled", slack_notifications_enabled);

  lua_push_int_table_entry(vm, "max_num_packets_per_tiny_flow", max_num_packets_per_tiny_flow);
  lua_push_int_table_entry(vm, "max_num_bytes_per_tiny_flow",   max_num_bytes_per_tiny_flow);

  lua_push_str_table_entry(vm, "safe_search_dns", Utils::intoaV4(ntohl(safe_search_dns_ip), buf, sizeof(buf)));
  lua_push_str_table_entry(vm, "global_dns", global_primary_dns_ip ? Utils::intoaV4(ntohl(global_primary_dns_ip), buf, sizeof(buf)) : (char*)"");
  lua_push_str_table_entry(vm, "secondary_dns", global_secondary_dns_ip ? Utils::intoaV4(ntohl(global_secondary_dns_ip), buf, sizeof(buf)) : (char*)"");

  lua_push_bool_table_entry(vm, "is_captive_portal_enabled", enable_captive_portal);
  lua_push_str_table_entry(vm, "redirection_url", redurl);

}

/* *************************************** */

int RuntimePrefs::refresh(const char *pref_name, const char *pref_value) {
  if(!pref_name || !pref_value)
    return -1;

  if(!strncmp(pref_name,
	       (char*)CONST_RUNTIME_PREFS_HOUSEKEEPING_FREQUENCY,
	       strlen((char*)CONST_RUNTIME_PREFS_HOUSEKEEPING_FREQUENCY)))
    housekeeping_frequency = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_LOCAL_HOST_CACHE_DURATION_PREFS,
		    strlen((char*)CONST_LOCAL_HOST_CACHE_DURATION_PREFS)))
    local_host_cache_duration = atoi(pref_value);
  else if(!strncmp(pref_name,
		   (char*)CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL,
		   strlen((char*)CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL)))
    active_local_hosts_cache_interval = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_LOCAL_HOST_IDLE_PREFS,
		    strlen((char*)CONST_LOCAL_HOST_IDLE_PREFS)))
    local_host_max_idle = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_REMOTE_HOST_IDLE_PREFS,
		    strlen((char*)CONST_REMOTE_HOST_IDLE_PREFS)))
    non_local_host_max_idle = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_FLOW_MAX_IDLE_PREFS,
		    strlen((char*)CONST_FLOW_MAX_IDLE_PREFS)))
    flow_max_idle = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_INTF_RRD_RAW_DAYS,
		    strlen((char*)CONST_INTF_RRD_RAW_DAYS)))
    intf_rrd_raw_days = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_INTF_RRD_1MIN_DAYS,
		    strlen((char*)CONST_INTF_RRD_1MIN_DAYS)))
    intf_rrd_1min_days = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_INTF_RRD_1H_DAYS,
		    strlen((char*)CONST_INTF_RRD_1H_DAYS)))
    intf_rrd_1h_days = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_INTF_RRD_1D_DAYS,
		    strlen((char*)CONST_INTF_RRD_1D_DAYS)))
    intf_rrd_1d_days = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_OTHER_RRD_RAW_DAYS,
		    strlen((char*)CONST_OTHER_RRD_RAW_DAYS)))
    other_rrd_raw_days = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_OTHER_RRD_1MIN_DAYS,
		    strlen((char*)CONST_OTHER_RRD_1MIN_DAYS)))
    other_rrd_1min_days = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_OTHER_RRD_1H_DAYS,
		    strlen((char*)CONST_OTHER_RRD_1H_DAYS)))
    other_rrd_1h_days = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_OTHER_RRD_1D_DAYS,
		    strlen((char*)CONST_OTHER_RRD_1D_DAYS)))
    other_rrd_1d_days = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_ALERT_DISABLED_PREFS,
		    strlen((char*)CONST_ALERT_DISABLED_PREFS)))
    disable_alerts = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		    (char*)CONST_TOP_TALKERS_ENABLED,
		    strlen((char*)CONST_TOP_TALKERS_ENABLED)))
    enable_top_talkers = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		    (char*)CONST_RUNTIME_IDLE_LOCAL_HOSTS_CACHE_ENABLED,
		    strlen((char*)CONST_RUNTIME_IDLE_LOCAL_HOSTS_CACHE_ENABLED)))
    enable_idle_local_hosts_cache = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		    (char*)CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED,
		    strlen((char*)CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED)))
    enable_active_local_hosts_cache = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		    (char*)CONST_MAX_NUM_ALERTS_PER_ENTITY,
		    strlen((char*)CONST_MAX_NUM_ALERTS_PER_ENTITY)))
    max_num_alerts_per_entity = atoi(pref_value);
  else if(!strncmp(pref_name,
		    (char*)CONST_SAFE_SEARCH_DNS,
		    strlen((char*)CONST_SAFE_SEARCH_DNS))) {
    safe_search_dns_ip = inet_addr(pref_value);
  } else if(!strncmp(pref_name,
		    (char*)CONST_GLOBAL_DNS,
		    strlen((char*)CONST_GLOBAL_DNS))) {
    global_primary_dns_ip = pref_value[0] ? inet_addr(pref_value) : 0;
  } else if(!strncmp(pref_name,
		    (char*)CONST_SECONDARY_DNS,
		    strlen((char*)CONST_SECONDARY_DNS))) {
    global_secondary_dns_ip = pref_value[0] ? inet_addr(pref_value) : 0;
  } else if(!strncmp(pref_name,
		    (char*)CONST_PREFS_REDIRECTION_URL,
		    strlen((char*)CONST_PREFS_REDIRECTION_URL))) {
    if(redirection_url_shadow)
      free(redirection_url_shadow);
    redirection_url_shadow = redirection_url;
    redirection_url = strdup(pref_value);
  } else if(!strncmp(pref_name,
		    (char*)CONST_MAX_NUM_FLOW_ALERTS,
		    strlen((char*)CONST_MAX_NUM_FLOW_ALERTS)))
    max_num_flow_alerts = atoi(pref_value);
  else if(!strncmp(pref_name,
		   (char*)CONST_MAX_NUM_PACKETS_PER_TINY_FLOW,
		   strlen((char*)CONST_MAX_NUM_PACKETS_PER_TINY_FLOW)))
    max_num_packets_per_tiny_flow = atoi(pref_value);
  else if(!strncmp(pref_name,
		   (char*)CONST_MAX_NUM_BYTES_PER_TINY_FLOW,
		   strlen((char*)CONST_MAX_NUM_BYTES_PER_TINY_FLOW)))
    max_num_bytes_per_tiny_flow = atoi(pref_value);
  else if(!strncmp(pref_name,
		   (char*)CONST_IS_TINY_FLOW_EXPORT_ENABLED,
		   strlen((char*)CONST_IS_TINY_FLOW_EXPORT_ENABLED)))
    enable_tiny_flows_export = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		   (char*)CONST_RUNTIME_PREFS_FLOW_DEVICE_PORT_RRD_CREATION,
		   strlen((char*)CONST_RUNTIME_PREFS_FLOW_DEVICE_PORT_RRD_CREATION)))
    enable_flow_device_port_rrd_creation = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		    (char*)CONST_RUNTIME_PREFS_ALERT_PROBING,
		    strlen((char*)CONST_RUNTIME_PREFS_ALERT_PROBING)))
    enable_probing_alerts = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		    (char*)CONST_RUNTIME_PREFS_ALERT_SSL,
		    strlen((char*)CONST_RUNTIME_PREFS_ALERT_SSL)))
    enable_ssl_alerts = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		    (char*)CONST_RUNTIME_PREFS_ALERT_SYSLOG,
		    strlen((char*)CONST_RUNTIME_PREFS_ALERT_SYSLOG)))
    enable_syslog_alerts = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		   (char*)CONST_PREFS_CAPTIVE_PORTAL,
		   strlen((char*)CONST_PREFS_CAPTIVE_PORTAL)))
    enable_captive_portal = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		   (char*)ALERTS_MANAGER_SLACK_NOTIFICATIONS_ENABLED,
		   strlen((char*)ALERTS_MANAGER_SLACK_NOTIFICATIONS_ENABLED)))
    slack_notifications_enabled = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		   (char*)ALERTS_DUMP_DURING_IFACE_ALERTED,
		   strlen((char*)ALERTS_DUMP_DURING_IFACE_ALERTED)))
    dump_flow_alerts_when_iface_alerted = pref_value[0] == '1' ? true : false;
  else if(!strncmp(pref_name,
		   (char*)CONST_RUNTIME_PREFS_HOSTMASK,
		   strlen((char*)CONST_RUNTIME_PREFS_HOSTMASK)))
    hostMask = (HostMask)atoi(pref_value);
  else
    return -1;

  prefscache_refreshed = true;
  return 0;
}
