/*
 *
 * (C) 2013-24 - ntop.org
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
    : GenericHashEntry(_iface) {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  memcpy(mac, _mac, 6);

  broadcast_mac = Utils::isBroadcastMac(mac);
  special_mac = Utils::isSpecialMac(mac);
  source_mac = false, fingerprint = NULL;
  bridge_seen_iface_id = 0, lockDeviceTypeChanges = false;
  memset(&names, 0, sizeof(names));
  device_type = device_unknown;
  host_pool_id = NO_HOST_POOL_ID;
#ifdef NTOPNG_PRO
  captive_portal_notified = 0;
#endif
  model = NULL, ssid = NULL;
  stats_reset_requested = data_delete_requested = false;
  stats = new (std::nothrow) MacStats(_iface);
  stats_shadow = NULL;
  last_stats_reset = ntop->getLastStatsReset(); /* assume fresh stats, may be
                                                   changed by deserialize */

  if (ntop->getMacManufacturers()) {
    manuf = ntop->getMacManufacturers()->getManufacturer(mac);
    if (manuf) checkDeviceTypeFromManufacturer();
  } else
    manuf = NULL;

#ifdef MANUF_DEBUG
  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Assigned manufacturer [mac: %02x:%02x:%02x:%02x:%02x:%02x] "
      "[manufacturer: %s]",
      mac[0], mac[1], mac[2], mac[3], mac[4], mac[5],
      manuf ? manuf : "- not available -");
#endif

#ifdef DEBUG
  char buf[32];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Created %s [total %u]",
                               Utils::formatMac(mac, buf, sizeof(buf)),
                               iface->getNumL2Devices());
#endif

#ifdef NTOPNG_PRO
  if ((!special_mac) && (!broadcast_mac) &&
      ntop->getPrefs()->is_enterprise_xl_edition() &&
      (ntop->getPrefs()->isAssetInventoryEnabled() ||
       ntop->getPrefs()->isNetBoxEnabled()))
    dumpAssetInfo();
#endif

  updateHostPool(true /* inline with packet processing */,
                 true /* first inc */);
}

/* *************************************** */

Mac::~Mac() {
  if (trace_new_delete)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[delete] %s", __FILE__);

  /* Serialize Mac before shutdown */
  if ((!broadcast_mac) && (!special_mac)) dumpToRedis();

  if (!special_mac && ntop->getRedis() && ntop->getPrefs()->is_pro_edition()) {
    char mac_addr[64], mac_disconnection_key[128];
    snprintf(mac_disconnection_key, sizeof(mac_disconnection_key),
             (char *)MACS_DISCONNECTION, iface->get_id());
    ntop->getRedis()->lpush(mac_disconnection_key,
                            print(mac_addr, sizeof(mac_addr)), 0 /* No Trim */);
  }

  if (model) free(model);
  if (ssid) free(ssid);
  if (fingerprint) free(fingerprint);
  freeMacData();
  if (stats) delete (stats);
  if (stats_shadow) delete (stats_shadow);

#ifdef DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Deleted %s [total %u][%s]",
                               Utils::formatMac(mac, buf, sizeof(buf)),
                               iface->getNumL2Devices(),
                               source_mac ? "Host" : "Special");
#endif
}

/* *************************************** */

void Mac::set_hash_entry_state_idle() {
  if (source_mac) iface->decNumL2Devices();

    /* Pool counters are updated both in and outside the datapath.
       So decPoolNumHosts must stay in the destructor to preserve counters
       consistency (no thread outside the datapath will change the last pool id)
     */
#ifdef HOST_POOLS_DEBUG
  char buf[32];
  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Going to decrease the number of pool l2 devices for %s "
      "[num pool l2 devices: %u]...",
      Utils::formatMac(mac, buf, sizeof(buf)),
      iface->getHostPools()->getNumPoolL2Devices(get_host_pool()));
#endif

  iface->decPoolNumL2Devices(get_host_pool(), true /* Mac is deleted inline */);

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Number of pool l2 devices decreased."
      "[num pool l2 devices: %u]",
      iface->getHostPools()->getNumPoolL2Devices(get_host_pool()));
#endif

  GenericHashEntry::set_hash_entry_state_idle();
}

/* *************************************** */

#ifdef HAVE_NEDGE
static const char *location2str(MacLocation location) {
  switch (location) {
    case located_on_lan_interface:
      return "lan";
    case located_on_wan_interface:
      return "wan";
    default:
      return "unknown";
  }
}
#endif

/* *************************************** */

void Mac::lua(lua_State *vm, bool show_details, bool asListElement) {
  char buf[32], *m;

  lua_newtable(vm);

  lua_push_str_table_entry(vm, "mac",
                           m = Utils::formatMac(mac, buf, sizeof(buf)));
  lua_push_uint64_table_entry(vm, "bridge_seen_iface_id", bridge_seen_iface_id);

  if (show_details) {
    if (manuf) lua_push_str_table_entry(vm, "manufacturer", (char *)manuf);

    lua_push_bool_table_entry(vm, "source_mac", source_mac);
    lua_push_bool_table_entry(vm, "special_mac", special_mac);
#ifdef HAVE_NEDGE
    lua_push_str_table_entry(vm, "location", (char *)location2str(locate()));
#endif
    lua_push_uint64_table_entry(vm, "devtype", device_type);
    if (model) lua_push_str_table_entry(vm, "model", (char *)model);
    if (ssid) lua_push_str_table_entry(vm, "ssid", (char *)ssid);
  }

  stats->lua(vm, show_details);

  lua_push_str_table_entry(vm, "fingerprint",
                           fingerprint ? fingerprint : (char *)"");
  lua_push_uint64_table_entry(vm, "seen.first", first_seen);
  lua_push_uint64_table_entry(vm, "seen.last", last_seen);
  lua_push_uint64_table_entry(vm, "duration", get_duration());
  lua_push_uint64_table_entry(vm, "num_hosts", getNumHosts());
  lua_push_uint64_table_entry(vm, "pool", get_host_pool());

  if (asListElement) {
    lua_pushstring(vm, m);
    lua_insert(vm, -2);
    lua_settable(vm, -3);
  }
}
/* *************************************** */

bool Mac::isNull() const {
  u_int8_t zero_mac[3] = {0};

  /*
    We need to compare only the manufacturer (3 byets instead of 6)
    as there might be variations of 00:00:00:00:00:00
    such as 00:00:00:00:01:01 that are basically alike
  */
  return (!memcmp(mac, zero_mac, sizeof(zero_mac)));
}

/* *************************************** */

bool Mac::equal(const u_int8_t _mac[6]) {
  if (!_mac) return (false);
  if (memcmp(mac, _mac, 6) == 0)
    return (true);
  else
    return (false);
}

/* *************************************** */

char *Mac::getSerializationKey(char *buf, uint bufsize) {
  char buf1[32];
  char *mac_ptr = Utils::formatMac(mac, buf1, sizeof(buf1));

  snprintf(buf, bufsize, MAC_SERIALIZED_KEY, iface->get_id(), mac_ptr);
  return (buf);
}

/* *************************************** */

bool Mac::statsResetRequested() {
  return (stats_reset_requested ||
          (last_stats_reset < ntop->getLastStatsReset()));
}

/* *************************************** */

#ifdef HAVE_NEDGE
MacLocation Mac::locate() {
  if (iface->is_bridge_interface()) {
    InterfaceLocation location =
        iface->getInterfaceLocation(bridge_seen_iface_id);
    if (location == lan_interface)
      return (located_on_lan_interface);
    else if (location == wan_interface)
      return (located_on_wan_interface);
  } else {
    if (bridge_seen_iface_id == DUMMY_BRIDGE_INTERFACE_ID)
      return (located_on_lan_interface);
  }

  return (located_on_unknown_interface);
}
#endif

/* *************************************** */

void Mac::updateHostPool(bool isInlineCall, bool firstUpdate) {
  if (!iface) return;

#ifdef HOST_POOLS_DEBUG
  char buf[24];
  u_int16_t cur_pool_id = get_host_pool();

  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Going to refresh pool for %s "
      "[pool id: %u]"
      "[pool num devices: %u]...",
      Utils::formatMac(get_mac(), buf, sizeof(buf)), cur_pool_id,
      iface->getHostPools()->getNumPoolL2Devices(get_host_pool()));
#endif

  if (!firstUpdate) iface->decPoolNumL2Devices(get_host_pool(), isInlineCall);
  host_pool_id = iface->getHostPool(this);
  iface->incPoolNumL2Devices(get_host_pool(), isInlineCall);

#ifdef HOST_POOLS_DEBUG
  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Refresh done. "
      "[old pool id: %u]"
      "[new pool id: %u]"
      "[old pool num devices: %u]"
      "[new pool num devices: %u]",
      cur_pool_id, get_host_pool(),
      iface->getHostPools()->getNumPoolL2Devices(cur_pool_id),
      iface->getHostPools()->getNumPoolL2Devices(get_host_pool()));
#endif
}

/* *************************************** */

char *Mac::getDHCPName(char *const buf, ssize_t buf_size) {
  if (buf && buf_size) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_size, "%s", names.dhcp ? names.dhcp : "");
    m.unlock(__FILE__, __LINE__);
  }

  return Utils::stringtolower(buf);
}

/* *************************************** */

char *Mac::getDHCPNameNotLowerCase(char *const buf, ssize_t buf_size) {
  if (buf && buf_size) {
    m.lock(__FILE__, __LINE__);
    snprintf(buf, buf_size, "%s", names.dhcp ? names.dhcp : "");
    m.unlock(__FILE__, __LINE__);
  }

  return ((char *)buf);
}

/* *************************************** */

void Mac::checkDeviceTypeFromManufacturer() {
  if (isNull()) return;

  if (strstr(manuf, "Networks") /* Arista, Juniper... */
      || strstr(manuf, "Brocade") || strstr(manuf, "Routerboard") ||
      strstr(manuf, "Alcatel-Lucent") || strstr(manuf, "AVM"))
    setDeviceType(device_networking);
  else if (strstr(manuf, "Xerox"))
    setDeviceType(device_printer);
  else if (strstr(manuf, "Raspberry Pi") ||
           strstr(manuf, "PCS Computer Systems") /* VirtualBox */
  )
    setDeviceType(device_workstation);
  else {
    /* https://www.techrepublic.com/blog/data-center/mac-address-scorecard-for-common-virtual-machine-platforms/
     */

    if ((!memcmp(mac, "\x00\x50\x56", 3)) ||
        (!memcmp(mac, "\x00\x0C\x29", 3)) ||
        (!memcmp(mac, "\x00\x05\x69", 3)) ||
        (!memcmp(mac, "\x00\x03\xFF", 3)) ||
        (!memcmp(mac, "\x00\x1C\x42", 3)) ||
        (!memcmp(mac, "\x00\x0F\x4B", 3)) ||
        (!memcmp(mac, "\x00\x16\x3E", 3)) || (!memcmp(mac, "\x08\x00\x27", 3)))
      setDeviceType(device_workstation); /* VM */
  }
}

/* *************************************** */

void Mac::inlineSetModel(const char *the_model) {
  if (!model && the_model && (model = strdup(the_model))) {
    if (strstr(model, "AppleTV") != NULL)
      setDeviceType(device_multimedia);
    else if (strstr(model, "MacBook") != NULL)
      setDeviceType(device_laptop);
    else if (strstr(model, "AirPort") != NULL)
      setDeviceType(device_wifi);
    else if (strstr(model, "Mac") != NULL)
      setDeviceType(device_workstation);
    else if (strstr(model, "TimeCapsule") != NULL)
      setDeviceType(device_nas);
  }
}
/* *************************************** */

bool Mac::inlineSetFingerprint(const char *f) {
  if (!fingerprint && f) {
    fingerprint = strdup(f);
    return (true);
  }

  return (false);
}

/* *************************************** */

void Mac::inlineSetSSID(const char *s) {
  if (!ssid && s && (ssid = strdup(s))) setDeviceType(device_wifi);
}

/* *************************************** */

void Mac::inlineSetDHCPName(const char *dhcp_name) {
  if (!names.dhcp && dhcp_name && (names.dhcp = strdup(dhcp_name)))
    ;
}

/* *************************************** */

void Mac::checkDataReset() {
  if (data_delete_requested) {
    deleteMacData();
    data_delete_requested = false;
  }
}

/* *************************************** */

void Mac::checkStatsReset() {
  if (statsResetRequested()) {
    MacStats *new_stats = new (std::nothrow) MacStats(iface);
    stats_shadow = stats;
    stats = new_stats;
    last_stats_reset = ntop->getLastStatsReset();
    stats_reset_requested = false;
  }
}

/* *************************************** */

void Mac::periodic_stats_update(const struct timeval *tv) {
  checkDataReset();
  checkStatsReset();
  stats->updateStats(tv);
}

/* *************************************** */

void Mac::readDHCPCache() {
  /* Check DHCP cache */
  char mac_str[24], buf[64], key[CONST_MAX_LEN_REDIS_KEY];

  if (!names.dhcp && !isNull()) {
    Utils::formatMac(get_mac(), mac_str, sizeof(mac_str));

    snprintf(key, sizeof(key), DHCP_CACHE, iface->get_id(), mac_str);

    if (ntop->getRedis()->get(key, buf, sizeof(buf)) == 0) {
      names.dhcp = strdup(buf);
    }
  }
}

/* *************************************** */

void Mac::freeMacData() {
  // TODO: allow fingerprint, ssid, and model to be resettable
  if (names.dhcp) {
    free(names.dhcp);
    names.dhcp = NULL;
  }
}

/* *************************************** */

void Mac::deleteMacData() {
  m.lock(__FILE__, __LINE__);
  freeMacData();
  m.unlock(__FILE__, __LINE__);
  source_mac = false;
  device_type = device_unknown;
#ifdef NTOPNG_PRO
  captive_portal_notified = false;
#endif
  first_seen = last_seen;
}

/* *************************************** */

u_int64_t Mac::get_mac64() { return Utils::encodeMacTo64(mac); }

/* *************************************** */

void Mac::dumpToRedis() {
  char buf[32], *json_str = NULL;
  ndpi_serializer mac_json;
  u_int32_t json_str_len = 0;

  ndpi_init_serializer(&mac_json, ndpi_serialization_format_json);
  ndpi_serialize_string_string(&mac_json, "mac",
                               Utils::formatMac(get_mac(), buf, sizeof(buf)));

  ndpi_serialize_start_of_block(&mac_json, "seen");
  ndpi_serialize_string_uint32(&mac_json, "first", first_seen);
  ndpi_serialize_string_uint32(&mac_json, "last", last_seen);
  ndpi_serialize_end_of_block(&mac_json);

  ndpi_serialize_string_uint32(&mac_json, "devtype", device_type);
  if (model) ndpi_serialize_string_string(&mac_json, "model", model);
  if (ssid) ndpi_serialize_string_string(&mac_json, "ssid", ssid);
  if (fingerprint)
    ndpi_serialize_string_string(&mac_json, "fingerprint", fingerprint);

  if (stats) ((GenericTrafficElement *)stats)->serialize(&mac_json);

  json_str = ndpi_serializer_get_buffer(&mac_json, &json_str_len);
  if ((json_str != NULL) && (json_str_len > 0)) {
    u_int expire_secs = 30 * 86400; /* 1 month */
    char key[64];

    ntop->getTrace()->traceEvent(TRACE_INFO, "%s", json_str);
    ntop->getRedis()->set(getSerializationKey(key, sizeof(key)), json_str,
                          expire_secs);
  }

  ndpi_term_serializer(&mac_json);
}

/* *************************************** */

#ifdef NTOPNG_PRO
void Mac::dumpAssetInfo() {
  char buf[32], *json_str = NULL;
  ndpi_serializer device_json;
  u_int32_t json_str_len = 0;
  char *mac_ptr = Utils::formatMac(get_mac(), buf, sizeof(buf));

  ndpi_init_serializer(&device_json, ndpi_serialization_format_json);

  ndpi_serialize_string_string(&device_json, "key", mac_ptr);
  ndpi_serialize_string_string(&device_json, "mac", mac_ptr);
  ndpi_serialize_string_string(&device_json, "source", "traffic");
  ndpi_serialize_string_uint32(&device_json, "first_seen", first_seen);
  ndpi_serialize_string_uint32(&device_json, "last_seen", last_seen);
  ndpi_serialize_string_string(&device_json, "manufacturer",
                               manuf ? manuf : "n/a");
  ndpi_serialize_string_uint32(&device_json, "role", device_type);

  json_str = ndpi_serializer_get_buffer(&device_json, &json_str_len);

  if ((json_str != NULL) && (json_str_len > 0)) {
    char key[64];
    snprintf(key, sizeof(key), ASSET_LIST_INSERTION_KEY, iface->get_id());
    ntop->getRedis()->rpush(key, json_str, 1024);
  }

  ndpi_term_serializer(&device_json);
}
#endif

/* *************************************** */

bool Mac::is_hash_entry_state_idle_transition_ready() {
/*  ntop->getTrace()->traceEvent(
      TRACE_NORMAL,
      "Is idle, current time, last seen, configured expiration: "
      "[ %s | %d | %d | %d ]",
      is_active_entry_now_idle(ntop->getPrefs()->macAddressCacheDuration())
          ? "true"
          : "false",
      time(NULL), last_seen, ntop->getPrefs()->macAddressCacheDuration());
*/ 
  return ((getUses() == 0) && is_active_entry_now_idle(
                                  ntop->getPrefs()->macAddressCacheDuration()));
}
