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

/* *************************************** */

Mac::Mac(NetworkInterface *_iface, u_int8_t _mac[6], u_int16_t _vlanId)
  : GenericHashEntry(_iface), GenericTrafficElement() {
  memcpy(mac, _mac, 6), vlan_id = _vlanId;
  memset(&arp_stats, 0, sizeof(arp_stats));
  special_mac = Utils::isSpecialMac(mac);
  source_mac = false;
  bridge_seen_iface_id = 0;
  device_type = device_unknown;

  if(ntop->getMacManufacturers())
    manuf = ntop->getMacManufacturers()->getManufacturer(mac);
  else
    manuf = NULL;

#ifdef MANUF_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Assigned manufacturer [mac: %02x:%02x:%02x:%02x:%02x:%02x] [manufacturer: %s]",
			       mac[0], mac[1], mac[2], mac[3], mac[4], mac[5],
			       manuf ? manuf : "- not available -");
#endif

#ifdef DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created %s/%u [total %u]",
			       Utils::formatMac(mac, buf, sizeof(buf)),
			       vlan_id, iface->getNumL2Devices());
#endif

  /*
   * Note: We do not load MAC data from redis right now.
   * We only need redis MAC data to show Unassigned Devices in host pools view.
   */
  if(!special_mac) {
    char redis_key[64], buf1[64], rsp[8];
    char *json = NULL;
    char *mac_ptr = Utils::formatMac(mac, buf1, sizeof(buf1));
    snprintf(redis_key, sizeof(redis_key), MAC_SERIALIED_KEY, iface->get_id(), mac_ptr, vlan_id);

    if((json = (char*)malloc(HOST_MAX_SERIALIZED_LEN * sizeof(char))) == NULL) {
      ntop->getTrace()->traceEvent(TRACE_ERROR,
               "Unable to allocate memory to deserialize %s", redis_key);
    } else if(!ntop->getRedis()->get(redis_key, json, HOST_MAX_SERIALIZED_LEN)) {
      /* Found saved copy of the host so let's start from the previous state */
      // ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s => %s", redis_key, json);
      ntop->getTrace()->traceEvent(TRACE_INFO, "Deserializing %s", redis_key);
      deserialize(redis_key, json);
    }

    if(json) free(json);

    // Load the user defined device type, if available
    snprintf(redis_key, sizeof(redis_key), MAC_CUSTOM_DEVICE_TYPE, mac_ptr);
    if((ntop->getRedis()->get(redis_key, rsp, sizeof(rsp)) == 0) && rsp[0])
      device_type = (DeviceType) atoi(rsp);
  }
}

/* *************************************** */

Mac::~Mac() {
  if(!special_mac) {
    char key[64], buf1[64];
    char *json = serialize();
    
    snprintf(key, sizeof(key), MAC_SERIALIED_KEY, iface->get_id(), Utils::formatMac(mac, buf1, sizeof(buf1)), vlan_id);
    ntop->getRedis()->set(key, json, ntop->getPrefs()->get_local_host_cache_duration());
    free(json);
  }

#ifdef DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted %s/%u [total %u][%s]",
			       Utils::formatMac(mac, buf, sizeof(buf)),
			       vlan_id, iface->getNumL2Devices(),
			       source_mac ? "Host" : "Special");
#endif
}

/* *************************************** */

bool Mac::idle() {
  bool rc;
  
  if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);

  rc = isIdle(MAX_LOCAL_HOST_IDLE);

#ifdef DEBUG
  if(true) {
    char buf[32];
    
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Is idle %s/%u [uses %u][%s][last: %u][diff: %d]",
				 Utils::formatMac(mac, buf, sizeof(buf)),
				 vlan_id, num_uses,
				 rc ? "Idle" : "Not Idle",
				 last_seen, iface->getTimeLastPktRcvd() - (last_seen+MAX_LOCAL_HOST_IDLE));
  }
#endif
  
  return(rc);
}

/* *************************************** */

void Mac::lua(lua_State* vm, bool show_details, bool asListElement) {
  char buf[32], *m;
  u_int16_t host_pool = 0;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "mac", m = Utils::formatMac(mac, buf, sizeof(buf)));
  lua_push_int_table_entry(vm, "bridge_seen_iface_id", bridge_seen_iface_id);

  if(show_details) {
    if(manuf)
      lua_push_str_table_entry(vm, "manufacturer", (char*)manuf);

    lua_push_int_table_entry(vm, "arp_requests.sent", arp_stats.sent_requests);
    lua_push_int_table_entry(vm, "arp_requests.rcvd", arp_stats.rcvd_requests);
    lua_push_int_table_entry(vm, "arp_replies.sent", arp_stats.sent_replies);
    lua_push_int_table_entry(vm, "arp_replies.rcvd", arp_stats.rcvd_replies);

    lua_push_bool_table_entry(vm, "source_mac", source_mac);
    lua_push_bool_table_entry(vm, "special_mac", special_mac);
    lua_push_int_table_entry(vm, "devtype", device_type);
  }

  ((GenericTrafficElement*)this)->lua(vm, true);

  lua_push_int_table_entry(vm, "seen.first", first_seen);
  lua_push_int_table_entry(vm, "seen.last", last_seen);
  lua_push_int_table_entry(vm, "duration", get_duration());

  lua_push_int_table_entry(vm, "num_hosts", getNumHosts());

  getInterface()->getHostPools()->findMacPool(this, &host_pool);
  lua_push_int_table_entry(vm, "pool", host_pool);

  if(asListElement) {
    lua_pushstring(vm, m);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool Mac::equal(u_int16_t _vlanId, const u_int8_t _mac[6]) {
  if(!_mac)
    return(false);
  if((vlan_id == _vlanId) && (memcmp(mac, _mac, 6) == 0))
    return(true);
  else
    return(false);
}

/* *************************************** */

char* Mac::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* *************************************** */

void Mac::deserialize(char *key, char *json_str) {
  json_object *o, *obj;
  enum json_tokener_error jerr = json_tokener_success;

  if((o = json_tokener_parse_verbose(json_str, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] key: %s: %s",
				 json_tokener_error_desc(jerr),
				 key,
				 json_str);
    return;
  }

  if(json_object_object_get_ex(o, "seen.first", &obj)) first_seen = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "seen.last", &obj)) last_seen = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "devtype", &obj)) device_type = (DeviceType)json_object_get_int(obj);

  json_object_put(o);
}

/* *************************************** */

json_object* Mac::getJSONObject() {
  json_object *my_object;
  char buf[32];

  if((my_object = json_object_new_object()) == NULL) return(NULL);

  json_object_object_add(my_object, "mac", json_object_new_string(Utils::formatMac(get_mac(), buf, sizeof(buf))));
  json_object_object_add(my_object, "seen.first", json_object_new_int64(first_seen));
  json_object_object_add(my_object, "seen.last",  json_object_new_int64(last_seen));
  json_object_object_add(my_object, "devtype", json_object_new_int(device_type));

  if(vlan_id != 0) json_object_object_add(my_object, "vlan_id", json_object_new_int(vlan_id));

  return my_object;
}

/* *************************************** */

MacLocation Mac::locate() {
  if(iface->is_bridge_interface()) {
    if(bridge_seen_iface_id == iface->getBridgeLanInterfaceId())
      return(located_on_lan_interface);
    else if(bridge_seen_iface_id == iface->getBridgeWanInterfaceId())
      return(located_on_wan_interface);    
  } else {
    if(bridge_seen_iface_id == DUMMY_BRIDGE_INTERFACE_ID)
      return(located_on_lan_interface);
  }

  return(located_on_unknown_interface);
}
