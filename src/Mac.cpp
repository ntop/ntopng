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

#include "ntop_includes.h"

/* *************************************** */

Mac::Mac(NetworkInterface *_iface, u_int8_t _mac[6])
  : GenericHashEntry(_iface), GenericTrafficElement() {
  memcpy(mac, _mac, 6);
  memset(&arp_stats, 0, sizeof(arp_stats));
  special_mac = Utils::isSpecialMac(mac);
  source_mac = false, fingerprint = NULL, dhcpHost = false;
  bridge_seen_iface_id = 0, lockDeviceTypeChanges = false;
  device_type = device_unknown, os = os_unknown;
#ifdef NTOPNG_PRO
  captive_portal_notified = 0;
#endif
  ndpiStats = NULL, model = NULL, ssid = NULL;

  if(ntop->getMacManufacturers()) {
    manuf = ntop->getMacManufacturers()->getManufacturer(mac);
    if(manuf) checkDeviceTypeFromManufacturer();
  } else
    manuf = NULL;

#ifdef MANUF_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Assigned manufacturer [mac: %02x:%02x:%02x:%02x:%02x:%02x] [manufacturer: %s]",
			       mac[0], mac[1], mac[2], mac[3], mac[4], mac[5],
			       manuf ? manuf : "- not available -");
#endif

#ifdef DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created %s [total %u]",
			       Utils::formatMac(mac, buf, sizeof(buf)),
			       iface->getNumL2Devices());
#endif

  /*
   * Note: We do not load MAC data from redis right now.
   * We only need redis MAC data to show Unassigned Devices in host pools view.
   */
  if(!special_mac) {
    char redis_key[64], buf1[64], rsp[8];
    char *json = NULL;
    char *mac_ptr = Utils::formatMac(mac, buf1, sizeof(buf1));
    snprintf(redis_key, sizeof(redis_key), MAC_SERIALIZED_KEY, iface->get_id(), mac_ptr);

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
      setDeviceType((DeviceType) atoi(rsp));
  }

  updateHostPool(true /* Inline */);
}

/* *************************************** */

Mac::~Mac() {
  if(source_mac)
    iface->decNumL2Devices();

  if(!special_mac) {
    char key[64], buf1[64];
    char *json = serialize();

    snprintf(key, sizeof(key), MAC_SERIALIZED_KEY, iface->get_id(), Utils::formatMac(mac, buf1, sizeof(buf1)));
    ntop->getRedis()->set(key, json, ntop->getPrefs()->get_local_host_cache_duration());
    free(json);
  }

  /* Pool counters are updated both in and outside the datapath.
     So decPoolNumHosts must stay in the destructor to preserve counters
     consistency (no thread outside the datapath will change the last pool id) */
#ifdef HOST_POOLS_DEBUG
  char buf[32];
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Going to decrease the number of pool l2 devices for %s "
			       "[num pool l2 devices: %u]...",
			       Utils::formatMac(mac, buf, sizeof(buf)),
			       iface->getHostPools()->getNumPoolL2Devices(get_host_pool()));
#endif

  iface->decPoolNumL2Devices(get_host_pool(), true /* Mac is deleted inline */);

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Number of pool l2 devices decreased."
			       "[num pool l2 devices: %u]",
			       iface->getHostPools()->getNumPoolL2Devices(get_host_pool()));
#endif

  if(model) free((void*)model);
  if(ssid) free((void*)ssid);
  
  if(ndpiStats) {
    delete ndpiStats;
    ndpiStats = NULL;
  }

  if(fingerprint)
    free(fingerprint);

#ifdef DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted %s [total %u][%s]",
			       Utils::formatMac(mac, buf, sizeof(buf)),
			       iface->getNumL2Devices(),
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

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Is idle %s [uses %u][%s][last: %u][diff: %d]",
				 Utils::formatMac(mac, buf, sizeof(buf)),
				 num_uses,
				 rc ? "Idle" : "Not Idle",
				 last_seen, iface->getTimeLastPktRcvd() - (last_seen+MAX_LOCAL_HOST_IDLE));
  }
#endif

  return(rc);
}

/* *************************************** */

static const char* location2str(MacLocation location) {
  switch(location) {
    case located_on_lan_interface: return "lan";
    case located_on_wan_interface: return "wan";
    default: return "unknown";
  }
}

/* *************************************** */

void Mac::lua(lua_State* vm, bool show_details, bool asListElement) {
  char buf[32], *m;

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
    lua_push_str_table_entry(vm, "location", (char *) location2str(locate()));
    lua_push_int_table_entry(vm, "devtype", device_type);
    if(model) lua_push_str_table_entry(vm, "model", (char*)model);
    if(ssid) lua_push_str_table_entry(vm, "ssid", (char*)ssid);
    if(ndpiStats) ndpiStats->lua(iface, vm, true);
  }

  ((GenericTrafficElement*)this)->lua(vm, true);

  lua_push_bool_table_entry(vm, "dhcpHost", dhcpHost);
  lua_push_str_table_entry(vm, "fingerprint", fingerprint ? fingerprint : (char*)"");
  lua_push_int_table_entry(vm, "operatingSystem", os);
  lua_push_int_table_entry(vm, "seen.first", first_seen);
  lua_push_int_table_entry(vm, "seen.last", last_seen);
  lua_push_int_table_entry(vm, "duration", get_duration());

  lua_push_int_table_entry(vm, "num_hosts", getNumHosts());

  lua_push_int_table_entry(vm, "pool", get_host_pool());

  if(asListElement) {
    lua_pushstring(vm, m);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}

/* *************************************** */

bool Mac::equal(const u_int8_t _mac[6]) {
  if(!_mac)
    return(false);
  if(memcmp(mac, _mac, 6) == 0)
    return(true);
  else
    return(false);
}

/* *************************************** */

char* Mac::serialize() {
  json_object *my_object = getJSONObject();
  char *rsp = strdup(json_object_to_json_string(my_object));

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s", rsp);
  
  /* Free memory */
  json_object_put(my_object);

  return(rsp);
}

/* *************************************** */

void Mac::deserialize(char *key, char *json_str) {
  json_object *o, *obj;
  enum json_tokener_error jerr = json_tokener_success;

  ntop->getTrace()->traceEvent(TRACE_INFO, "%s", json_str);
  
  if((o = json_tokener_parse_verbose(json_str, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "JSON Parse error [%s] key: %s: %s",
				 json_tokener_error_desc(jerr),
				 key,
				 json_str);
    return;
  }

  if(json_object_object_get_ex(o, "seen.first", &obj))  first_seen = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "seen.last", &obj))   last_seen = json_object_get_int64(obj);
  if(json_object_object_get_ex(o, "devtype", &obj))     device_type = (DeviceType)json_object_get_int(obj);
  if(json_object_object_get_ex(o, "model", &obj))       setModel((char*)json_object_get_string(obj));
  if(json_object_object_get_ex(o, "ssid", &obj))        setSSID((char*)json_object_get_string(obj));
  if(json_object_object_get_ex(o, "fingerprint", &obj)) setFingerprint((char*)json_object_get_string(obj));
  if(json_object_object_get_ex(o, "operatingSystem", &obj)) setOperatingSystem((OperatingSystem)json_object_get_int(obj));
  if(json_object_object_get_ex(o, "dhcpHost", &obj))    dhcpHost = json_object_get_boolean(obj);
  if(ndpiStats && json_object_object_get_ex(o, "ndpiStats", &obj)) ndpiStats->deserialize(iface, obj);
  if(json_object_object_get_ex(o, "flows.dropped", &obj)) total_num_dropped_flows = json_object_get_int(obj);

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
  if(model) json_object_object_add(my_object, "model", json_object_new_string(model));
  if(ssid) json_object_object_add(my_object, "ssid", json_object_new_string(ssid));
  json_object_object_add(my_object, "dhcpHost", json_object_new_boolean(dhcpHost));
  json_object_object_add(my_object, "operatingSystem", json_object_new_int(os));
  if(fingerprint) json_object_object_add(my_object, "fingerprint", json_object_new_string(fingerprint));
  if(ndpiStats) json_object_object_add(my_object, "ndpiStats", ndpiStats->getJSONObject(iface));
  if(total_num_dropped_flows) json_object_object_add(my_object, "flows.dropped", json_object_new_int(total_num_dropped_flows));

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

/* *************************************** */

void Mac::updateHostPool(bool isInlineCall) {
  if(!iface)
    return;

#ifdef HOST_POOLS_DEBUG
  char buf[24];
  u_int16_t cur_pool_id = get_host_pool();

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Going to refresh pool for %s "
			       "[pool id: %u]"
			       "[pool num devices: %u]...",
			       Utils::formatMac(get_mac(), buf, sizeof(buf)),
			       cur_pool_id,
			       iface->getHostPools()->getNumPoolL2Devices(get_host_pool()));
#endif

  iface->decPoolNumL2Devices(get_host_pool(), isInlineCall);
  host_pool_id = iface->getHostPool(this);
  iface->incPoolNumL2Devices(get_host_pool(), isInlineCall);

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Refresh done. "
			       "[old pool id: %u]"
			       "[new pool id: %u]"
			       "[old pool num devices: %u]"
			       "[new pool num devices: %u]",
			       cur_pool_id,
			       get_host_pool(),
			       iface->getHostPools()->getNumPoolL2Devices(cur_pool_id),
			       iface->getHostPools()->getNumPoolL2Devices(get_host_pool()));
#endif
}

/* *************************************** */

void Mac::updateFingerprint() {
  /*
    Inefficient with many signatures but ok for the
    time being that we have little data
  */
  if(!fingerprint) return;

  if(!strcmp(fingerprint,      "017903060F77FC"))
    setOperatingSystem(os_ios);
  else if((!strcmp(fingerprint, "017903060F77FC5F2C2E"))
	  || (!strcmp(fingerprint, "0103060F775FFC2C2E2F"))
	  || (!strcmp(fingerprint, "0103060F775FFC2C2E"))
	  )
    setOperatingSystem(os_macos);
  else if((!strcmp(fingerprint, "0103060F1F212B2C2E2F79F9FC"))
	  || (!strcmp(fingerprint, "010F03062C2E2F1F2179F92B"))
	  )
    setOperatingSystem(os_windows);
  else if((!strcmp(fingerprint, "0103060C0F1C2A"))
	  || (!strcmp(fingerprint, "011C02030F06770C2C2F1A792A79F921FC2A"))
	  )
    setOperatingSystem(os_linux); /* Android is also linux */
  else if((!strcmp(fingerprint, "0603010F0C2C51452B1242439607"))
	  || (!strcmp(fingerprint, "01032C06070C0F16363A3B45122B7751999A"))
	  )
    setOperatingSystem(os_laserjet);
  else if(!strcmp(fingerprint, "0102030F060C2C"))
    setOperatingSystem(os_apple_airport);
  else if(!strcmp(fingerprint, "01792103060F1C333A3B77"))
    setOperatingSystem(os_android);

  /* Below you can find ambiguous signatures */
  if(manuf) {
    if(!strcmp(fingerprint, "0103063633")) {
      if(strstr(manuf, "Apple"))
	setOperatingSystem(os_macos);
      else if(device_type == device_unknown) {
	setOperatingSystem(os_windows);
      }
    }
  }
}
/*
  Missing OS mapping

  011C02030F06770C2C2F1A792A
  010F03062C2E2F1F2179F92BFC
*/

/* *************************************** */

void Mac::checkDeviceTypeFromManufacturer() {
  if(strstr(manuf, "Networks") /* Arista, Juniper... */
     || strstr(manuf, "Brocade")
     || strstr(manuf, "Routerboard")
     || strstr(manuf, "Alcatel-Lucent")
     || strstr(manuf, "AVM")
     )
    setDeviceType(device_networking);
  else if(strstr(manuf, "Xerox")
	   )
    setDeviceType(device_printer);
  else if(strstr(manuf, "Raspberry Pi")
	  || strstr(manuf, "PCS Computer Systems") /* VirtualBox */
	  )
    setDeviceType(device_workstation);
  else {
    /* https://www.techrepublic.com/blog/data-center/mac-address-scorecard-for-common-virtual-machine-platforms/ */

    if((!memcmp(mac, "\x00\x50\x56", 3))
       || (!memcmp(mac, "\x00\x0C\x29", 3))
       || (!memcmp(mac, "\x00\x05\x69", 3))
       || (!memcmp(mac, "\x00\x03\xFF", 3))
       || (!memcmp(mac, "\x00\x1C\x42", 3))
       || (!memcmp(mac, "\x00\x0F\x4B", 3))
       || (!memcmp(mac, "\x00\x16\x3E", 3))
       || (!memcmp(mac, "\x08\x00\x27", 3))
       )
      setDeviceType(device_workstation); /* VM */
  }
}

/* *************************************** */

void Mac::setModel(char* m) {
  if(model) free((void*)model);
  model = strdup(m);

  if(strstr(model, "AppleTV") != NULL) setDeviceType(device_multimedia);
  else if(strstr(model, "MacBook") != NULL) setDeviceType(device_laptop);
  else if(strstr(model, "AirPort") != NULL) setDeviceType(device_wifi);
  else if(strstr(model, "Mac")     != NULL) setDeviceType(device_workstation);
  else if(strstr(model, "TimeCapsule") != NULL) setDeviceType(device_nas);
}

/* *************************************** */

void Mac::setSSID(char* s) {
  if(ssid) free((void*)ssid);
  ssid = strdup(s);
  setDeviceType(device_wifi);
}
