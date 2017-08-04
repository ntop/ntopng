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
  path[0] = tmp_path[0] = '\0';

  prefscache = NULL;
  prefscache_refreshed = false;
  if(!(rwlock = new RwLock()))
    throw 1;

  housekeeping_frequency = HOUSEKEEPING_FREQUENCY;
  local_host_cache_duration = LOCAL_HOSTS_CACHE_DURATION;
  local_host_max_idle = MAX_LOCAL_HOST_IDLE;
  non_local_host_max_idle = MAX_REMOTE_HOST_IDLE;
  flow_max_idle = MAX_FLOW_IDLE;
  active_local_hosts_cache_interval = CONST_DEFAULT_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL;

  intf_rrd_raw_days = INTF_RRD_RAW_DAYS;
  intf_rrd_1min_days = INTF_RRD_1MIN_DAYS;
  intf_rrd_1h_days = INTF_RRD_1H_DAYS;
  intf_rrd_1d_days = INTF_RRD_1D_DAYS;
  other_rrd_raw_days = OTHER_RRD_RAW_DAYS;
  other_rrd_1min_days = OTHER_RRD_1MIN_DAYS;
  other_rrd_1h_days = OTHER_RRD_1H_DAYS;
  other_rrd_1d_days = OTHER_RRD_1D_DAYS;

  enable_top_talkers = CONST_DEFAULT_TOP_TALKERS_ENABLED;
  enable_idle_local_hosts_cache   = CONST_DEFAULT_IS_IDLE_LOCAL_HOSTS_CACHE_ENABLED;
  enable_active_local_hosts_cache = CONST_DEFAULT_IS_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED;
  enable_tiny_flows_export = CONST_DEFAULT_IS_TINY_FLOW_EXPORT_ENABLED;

  max_num_alerts_per_entity = ALERTS_MANAGER_MAX_ENTITY_ALERTS;
  max_num_flow_alerts = ALERTS_MANAGER_MAX_FLOW_ALERTS;

  enable_flow_device_port_rrd_creation = false;

  disable_alerts = false;

  enable_probing_alerts = CONST_DEFAULT_ALERT_PROBING_ENABLED;
  enable_ssl_alerts = CONST_DEFAULT_ALERT_SSL_ENABLED;
  enable_syslog_alerts = CONST_DEFAULT_ALERT_SYSLOG_ENABLED;
  slack_notifications_enabled = false;
  dump_flow_alerts_when_iface_alerted = false;

  max_num_packets_per_tiny_flow = CONST_DEFAULT_MAX_NUM_PACKETS_PER_TINY_FLOW;
  max_num_bytes_per_tiny_flow = CONST_DEFAULT_MAX_NUM_BYTES_PER_TINY_FLOW;

  safe_search_dns_ip = inet_addr(DEFAULT_SAFE_SEARCH_DNS);
  global_primary_dns_ip = inet_addr(DEFAULT_GLOBAL_DNS);
  global_secondary_dns_ip = inet_addr(DEFAULT_GLOBAL_DNS);
  enable_captive_portal = false;

  max_ui_strlen = CONST_DEFAULT_MAX_UI_STRLEN;

  hostMask = no_host_mask;

  addToCache(CONST_RUNTIME_PREFS_HOUSEKEEPING_FREQUENCY, u_int32_t_ptr, (void*)&housekeeping_frequency);
  addToCache(CONST_LOCAL_HOST_CACHE_DURATION_PREFS, u_int32_t_ptr, (void*)&local_host_cache_duration);
  addToCache(CONST_LOCAL_HOST_IDLE_PREFS, u_int32_t_ptr, (void*)&local_host_max_idle);
  addToCache(CONST_REMOTE_HOST_IDLE_PREFS, u_int32_t_ptr, (void*)&non_local_host_max_idle);
  addToCache(CONST_FLOW_MAX_IDLE_PREFS, u_int32_t_ptr, (void*)&flow_max_idle);
  addToCache(CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_INTERVAL, u_int32_t_ptr, (void*)&active_local_hosts_cache_interval);
  addToCache(CONST_INTF_RRD_RAW_DAYS, u_int32_t_ptr, (void*)&intf_rrd_raw_days);
  addToCache(CONST_INTF_RRD_1MIN_DAYS, u_int32_t_ptr, (void*)&intf_rrd_1min_days);
  addToCache(CONST_INTF_RRD_1H_DAYS, u_int32_t_ptr, (void*)&intf_rrd_1h_days);
  addToCache(CONST_INTF_RRD_1D_DAYS, u_int32_t_ptr, (void*)&intf_rrd_1d_days);
  addToCache(CONST_OTHER_RRD_RAW_DAYS, u_int32_t_ptr, (void*)&other_rrd_raw_days);
  addToCache(CONST_OTHER_RRD_1MIN_DAYS, u_int32_t_ptr, (void*)&other_rrd_1min_days);
  addToCache(CONST_OTHER_RRD_1H_DAYS, u_int32_t_ptr, (void*)&other_rrd_1h_days);
  addToCache(CONST_OTHER_RRD_1D_DAYS, u_int32_t_ptr, (void*)&other_rrd_1d_days);
  addToCache(CONST_TOP_TALKERS_ENABLED, bool_ptr, (void*)&enable_top_talkers);
  addToCache(CONST_RUNTIME_IDLE_LOCAL_HOSTS_CACHE_ENABLED, bool_ptr, (void*)&enable_idle_local_hosts_cache);
  addToCache(CONST_RUNTIME_ACTIVE_LOCAL_HOSTS_CACHE_ENABLED, bool_ptr, (void*)&enable_active_local_hosts_cache);
  addToCache(CONST_IS_TINY_FLOW_EXPORT_ENABLED, bool_ptr, (void*)&enable_tiny_flows_export);
  addToCache(CONST_MAX_NUM_ALERTS_PER_ENTITY, int32_t_ptr, (void*)&max_num_alerts_per_entity);
  addToCache(CONST_MAX_NUM_FLOW_ALERTS, int32_t_ptr, (void*)&max_num_flow_alerts);
  addToCache(CONST_RUNTIME_PREFS_FLOW_DEVICE_PORT_RRD_CREATION, bool_ptr, (void*)&enable_flow_device_port_rrd_creation);
  addToCache(CONST_ALERT_DISABLED_PREFS, bool_ptr, (void*)&disable_alerts);
  addToCache(CONST_RUNTIME_PREFS_ALERT_PROBING, bool_ptr, (void*)&enable_probing_alerts);
  addToCache(CONST_RUNTIME_PREFS_ALERT_SSL, bool_ptr, (void*)&enable_ssl_alerts);
  addToCache(CONST_RUNTIME_PREFS_ALERT_SYSLOG, bool_ptr, (void*)&enable_syslog_alerts);
  addToCache(ALERTS_MANAGER_SLACK_NOTIFICATIONS_ENABLED, bool_ptr, (void*)&slack_notifications_enabled);
  addToCache(ALERTS_DUMP_DURING_IFACE_ALERTED, bool_ptr, (void*)&dump_flow_alerts_when_iface_alerted);
  addToCache(CONST_MAX_NUM_PACKETS_PER_TINY_FLOW, u_int32_t_ptr, (void*)&max_num_packets_per_tiny_flow);
  addToCache(CONST_MAX_NUM_BYTES_PER_TINY_FLOW, u_int32_t_ptr, (void*)&max_num_bytes_per_tiny_flow);
  addToCache(CONST_SAFE_SEARCH_DNS, u_int32_t_ptr, (void*)&safe_search_dns_ip);
  addToCache(CONST_GLOBAL_DNS, u_int32_t_ptr, (void*)&global_primary_dns_ip);
  addToCache(CONST_SECONDARY_DNS, u_int32_t_ptr, (void*)&global_secondary_dns_ip);
  addToCache(CONST_PREFS_CAPTIVE_PORTAL, bool_ptr, (void*)&enable_captive_portal);
  redirection_url = addToCache(CONST_PREFS_REDIRECTION_URL, str, strdup(DEFAULT_REDIRECTION_URL));
  addToCache(CONST_RUNTIME_MAX_UI_STRLEN, u_int32_t_ptr, (void*)&max_ui_strlen);
  addToCache(CONST_RUNTIME_PREFS_HOSTMASK, hostmask_ptr, (void*)&hostMask);
}

/* ******************************************* */

prefscache_t *RuntimePrefs::addToCache(const char *key, prefsptr_t value_ptr, void *value) {
  prefscache_t *m = (prefscache_t*)calloc(1, sizeof(prefscache_t));

  if(m) {
    m->key = strdup(key), m->value_ptr = value_ptr;

    if(value_ptr == str)
      m->value = strdup((char*)value);
    else
      m->value = value;

    if(value_ptr == str || value_ptr == str_ptr)
      if(!(m->rwlock = new RwLock()))
	throw 2;
    if(m->key) HASH_ADD_STR(prefscache, key, m); else free(m);
  }

  return m;
}

/* ******************************************* */

int RuntimePrefs::hashGet(char *key, char *rsp, u_int rsp_len) {
  int ret = -1;
  prefscache_t *m = NULL;

  rwlock->lock(__FILE__, __LINE__, true /* rdlock */);
  HASH_FIND_STR(prefscache, key, m);
  rwlock->unlock(__FILE__, __LINE__);

  if(m) {
    switch(m->value_ptr) {
    case str:
      m->rwlock->lock(__FILE__, __LINE__, true /* rdlock */);
      ret = snprintf(rsp, rsp_len, "%s", (char*)m->value);
      m->rwlock->unlock(__FILE__, __LINE__);
      break;

    case str_ptr:
      m->rwlock->lock(__FILE__, __LINE__, true /* rdlock */);
      ret = snprintf(rsp, rsp_len, "%s", *((char**)m->value));
      m->rwlock->unlock(__FILE__, __LINE__);
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
    if(cur->value_ptr == str)
      free(cur->value);
    else if(cur->value_ptr == str_ptr)
      free(*((char**)cur->value));

    if(cur->key)
      free(cur->key);

    if(cur->rwlock)
      delete cur->rwlock;

    HASH_DEL(prefscache, cur);  /* delete; users advances to next */
    free(cur);                  /* optional- if you want to free  */
  }

  delete rwlock;
}

/* ******************************************* */

json_object* RuntimePrefs::getJSONObject() {
  char *c = NULL;
  json_object *my_object;
  prefscache_t *m, *tmp;

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  rwlock->lock(__FILE__, __LINE__, true /* rdlock */);

  HASH_ITER(hh, prefscache, m, tmp) {
    switch(m->value_ptr) {
    case str:
      m->rwlock->lock(__FILE__, __LINE__, true /* rdlock */);

      c = (char*)m->value;
      if(c)
	json_object_object_add(my_object, m->key, json_object_new_string(c));

      m->rwlock->unlock(__FILE__, __LINE__);
      break;

    case str_ptr:
      m->rwlock->lock(__FILE__, __LINE__, true /* rdlock */);

      c = *((char**)m->value);
      if(c)
	json_object_object_add(my_object, m->key, json_object_new_string(c));

      m->rwlock->unlock(__FILE__, __LINE__);
      break;

    case u_int32_t_ptr:
      json_object_object_add(my_object, m->key, json_object_new_int64(*(u_int32_t*)m->value));
      break;

    case int32_t_ptr:
      json_object_object_add(my_object, m->key, json_object_new_int64(*(int32_t*)m->value));
      break;

    case bool_ptr:
      json_object_object_add(my_object, m->key, json_object_new_boolean(*(bool*)m->value));
      break;

    case hostmask_ptr:
      json_object_object_add(my_object, m->key, json_object_new_int(*((HostMask*)m->value)));
      break;

    default:
      break;
    }

  }

  rwlock->unlock(__FILE__, __LINE__);

  return my_object;
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
  json_object *o;
  enum json_tokener_error jerr = json_tokener_success;
  prefscache_t *m = NULL;

  if((o = json_tokener_parse_verbose(json_str, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] %s",
				 json_tokener_error_desc(jerr),
				 json_str);
    return false;
  }

  json_object_object_foreach(o, key, val) {

    HASH_FIND_STR(prefscache, key, m);

    if(m) {

      switch(m->value_ptr) {

      case str:
	if(m->value)
	  free(m->value);
	m->value = strdup(json_object_get_string(val));
	break;

      case str_ptr:
	if(*((char**)m->value))
	  free(*((char**)m->value));
	*((char**)m->value) = strdup(json_object_get_string(val));
	break;

      case u_int32_t_ptr:
	*((u_int32_t*)m->value) = json_object_get_int64(val);
	break;

      case int32_t_ptr:
	*((int32_t*)m->value) = json_object_get_int64(val);
	break;

      case bool_ptr:
	*((bool*)m->value) = json_object_get_boolean(val);
	break;

      case hostmask_ptr:
	*((HostMask*)m->value) = (HostMask)json_object_get_int(val);
	break;

      default:
	break;
      }
    } else {
#ifdef DEBUG
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deserializing [key: %s][val: %s]", key, json_object_get_string(val));
#endif
      addToCache(key, str, (void*)json_object_get_string(val));
    }
  }

  json_object_put(o);

  return true;
}

/* *************************************** */

void RuntimePrefs::setDumpPath(char *_path) {
  path[0] = tmp_path[0] = '\0';

  if(_path) {
    Utils::mkdir_tree(_path);
    snprintf(path, sizeof(path), "%s/%s",
	     _path, CONST_DEFAULT_PREFS_FILE);
    snprintf(tmp_path, sizeof(tmp_path), "%s/%s.temp",
	     _path, CONST_DEFAULT_PREFS_FILE);
  }
}

/* *************************************** */

bool RuntimePrefs::writeDump() {
  bool ret = true;
  char *rsp = serialize();
  size_t tmp_w = 0, w = 0;

  if(rsp) {
    if((tmp_w = Utils::file_write(tmp_path, rsp, strlen(rsp))))
      if((w = Utils::file_write(path, rsp, strlen(rsp))) == tmp_w)
	unlink(tmp_path), prefscache_refreshed = false;

    free(rsp);
  }

  return ret;
}

/* *************************************** */

bool RuntimePrefs::readDump() {
  size_t tmp_r = 0, r = 0;
  char *buffer = NULL;

  if((r = Utils::file_read(path, &buffer))
     && deserialize(buffer)) {
    free(buffer);
    return true;
  }
  
  if(buffer) free(buffer);

  if((tmp_r = Utils::file_read(tmp_path, &buffer))
     && deserialize(buffer)) {
    free(buffer);
    return true;
  }

  if(buffer) free(buffer);

  return false;
}

/* *************************************** */

void RuntimePrefs::lua(lua_State* vm) {
  char buf[32];

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

  if(redirection_url) {
    redirection_url->rwlock->lock(__FILE__, __LINE__, true /* rdlock */);
    lua_push_str_table_entry(vm, "redirection_url", (char*)redirection_url->value);
    redirection_url->rwlock->unlock(__FILE__, __LINE__);
  }

  lua_push_int_table_entry(vm, "max_ui_strlen",   max_ui_strlen);
}

/* *************************************** */

int RuntimePrefs::refresh(const char *pref_name, const char *pref_value) {
  prefscache_t *m = NULL;

  if(!pref_name || !pref_value)
    return -1;

  rwlock->lock(__FILE__, __LINE__, true /* rdlock */);
  HASH_FIND_STR(prefscache, pref_name, m);
  rwlock->unlock(__FILE__, __LINE__);

  if(m) {

    switch(m->value_ptr) {

    case str:
      m->rwlock->lock(__FILE__, __LINE__, false /* wrlock */);

      if(m->value)
	free(m->value);
      m->value = strdup(pref_value);

      m->rwlock->unlock(__FILE__, __LINE__);
      break;

    case str_ptr:
      m->rwlock->lock(__FILE__, __LINE__, false /* wrlock */);

      if(*((char**)m->value))
	free(*((char**)m->value));
      *((char**)m->value) = strdup(pref_value);

      m->rwlock->unlock(__FILE__, __LINE__);
      break;

    case u_int32_t_ptr:
      *((u_int32_t*)m->value) = atoi(pref_value);
      break;

    case int32_t_ptr:
      *((int32_t*)m->value) = atoi(pref_value);
      break;

    case bool_ptr:
      *((bool*)m->value) = pref_value[0] == '1' ? true : false;;
      break;

    case hostmask_ptr:
      *((HostMask*)m->value) = (HostMask)atoi(pref_value);
      break;

    default:
      break;
    }


  } else if(!strncmp(pref_name, "ntopng.prefs.", strlen("ntopng.prefs"))) {
    rwlock->lock(__FILE__, __LINE__, false /* wrlock */);

    addToCache(pref_name, str, (void*)pref_value);

    rwlock->unlock(__FILE__, __LINE__);
  } else
    return -1;

  prefscache_refreshed = true;
  return 0;
}
