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

#ifndef _MAC_H_
#define _MAC_H_

#include "ntop_includes.h"

class Mac : public GenericHashEntry {
 private:
  Mutex m;
  u_int8_t mac[6];
  u_int16_t host_pool_id;
  u_int32_t bridge_seen_iface_id; /* != 0 for bridge interfaces only */
  bool special_mac, lockDeviceTypeChanges, broadcast_mac;
  bool stats_reset_requested, data_delete_requested;
  const char *manuf;
  MacStats *stats, *stats_shadow;
  time_t last_stats_reset;

  struct {
    char *dhcp; /* Extracted from DHCP dissection */
  } names;

  char *fingerprint;
  char *model;
  char *ssid;

  bool source_mac;
  DeviceType device_type;
#ifdef NTOPNG_PRO
  time_t captive_portal_notified;
#endif

  /* END Mac data: */

#ifdef NTOPNG_PRO
  void dumpAssetInfo();
#endif
  void checkDeviceTypeFromManufacturer();
  void readDHCPCache();
  void freeMacData();
  void deleteMacData();
  bool statsResetRequested();
  void checkStatsReset();
  void dumpToRedis();

 public:
  Mac(NetworkInterface *_iface, u_int8_t _mac[6]);
  ~Mac();

  inline u_int16_t getNumHosts() { return getUses(); }
  inline void incUses() {
    GenericHashEntry::incUses();

    if (getUses() > CONST_MAX_NUM_HOST_USES) {
      setDeviceType(device_networking);
      lockDeviceTypeChanges = true;
    }
  }
  inline void decUses() { GenericHashEntry::decUses(); }
  inline bool isSpecialMac() { return (special_mac); }
  inline bool isSourceMac() { return (source_mac); }
  inline void setSourceMac() {
    if (!source_mac && !special_mac) {
      source_mac = true;
      iface->incNumL2Devices();
    }
  }

#ifdef HAVE_NEDGE
  MacLocation locate();
#endif

  inline u_int32_t key() { return (Utils::macHash(mac)); }
  inline const u_int8_t *const get_mac() const { return (mac); }

  static u_int64_t to64(u_int8_t mac[6]);
  u_int64_t get_mac64();

  inline const char *get_manufacturer() { return manuf ? manuf : NULL; }
  bool isNull() const;

  bool equal(const u_int8_t _mac[6]);
  bool equal(const Mac *m) {
    return ((memcmp(mac, m->mac, 6) == 0) ? true : false);
  };

#ifdef NTOPNG_PRO
  inline time_t getNotifiedTime() { return captive_portal_notified; };
  inline void setNotifiedTime() { captive_portal_notified = time(NULL); };
#endif
  inline void setSeenIface(u_int32_t idx) {
    bridge_seen_iface_id = idx;
    setSourceMac();
  }
  inline u_int32_t getSeenIface() { return (bridge_seen_iface_id); }
  inline void setDeviceType(DeviceType devtype) {
    if (isNull()) return;

    /* Called by ntopng when it can guess a device type during normal packet
     * processing */
    if (!lockDeviceTypeChanges) device_type = devtype;
  }
  inline void forceDeviceType(DeviceType devtype) {
    /* Called when a user, from the GUI, wants to change the device type and
     * specify a custom type */
    device_type = devtype;
    /* If the user specifies a custom type, then we want ntopng to stop guessing
       other types for the same device */
    if (!lockDeviceTypeChanges) lockDeviceTypeChanges = true;
  }
  inline DeviceType getDeviceType() { return (device_type); }
  char *getDHCPName(char *const buf, ssize_t buf_size);
  char *getDHCPNameNotLowerCase(char *const buf, ssize_t buf_size);
  void set_hash_entry_state_idle();
  void lua(lua_State *vm, bool show_details, bool asListElement);
  virtual char *get_string_key(char *buf, u_int buf_len) const {
    return (Utils::formatMac(mac, buf, buf_len));
  };
  inline int16_t findAddress(AddressTree *ptree) {
    return ptree ? ptree->findMac(mac) : -1;
  };
  inline char *print(char *str, u_int str_len) {
    return (Utils::formatMac(mac, str, str_len));
  };
  void updateHostPool(bool isInlineCall, bool firstUpdate = false);
  void inlineSetModel(const char *m);
  bool inlineSetFingerprint(const char *f);
  void inlineSetSSID(const char *s);
  void inlineSetDHCPName(const char *dhcp_name);
  inline u_int16_t get_host_pool() { return (host_pool_id); }
  inline const char *getFingerprint() { return (fingerprint); }

  inline void requestStatsReset() { stats_reset_requested = true; };
  inline void requestDataReset() {
    data_delete_requested = true;
    requestStatsReset();
  };
  void checkDataReset();

  inline void incSentStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes) {
    if (first_seen == 0) first_seen = t;
    stats->incSentStats(t, num_pkts, num_bytes), last_seen = t;
  }

  bool is_hash_entry_state_idle_transition_ready() {
    return ((getUses() == 0) && is_active_entry_now_idle(MAX_MAC_IDLE));
  }

  inline void incnDPIStats(time_t when, ndpi_protocol_category_t ndpi_category,
                           u_int64_t sent_packets, u_int64_t sent_bytes,
                           u_int64_t sent_goodput_bytes, u_int64_t rcvd_packets,
                           u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes) {
    stats->incnDPIStats(when, ndpi_category, sent_packets, sent_bytes,
                        sent_goodput_bytes, rcvd_packets, rcvd_bytes,
                        rcvd_goodput_bytes);
  }

  inline void incRcvdStats(time_t t, u_int64_t num_pkts, u_int64_t num_bytes) {
    stats->incRcvdStats(t, num_pkts, num_bytes);
  }

  char *getSerializationKey(char *buf, uint bufsize);

  inline u_int64_t getNumSentArp() { return (stats->getNumSentArp()); }
  inline u_int64_t getNumRcvdArp() { return (stats->getNumRcvdArp()); }
  inline void incNumDroppedFlows() { stats->incNumDroppedFlows(); }
  inline void incSentArpRequests() { stats->incSentArpRequests(); }
  inline void incSentArpReplies() { stats->incSentArpReplies(); }
  inline void incRcvdArpRequests() { stats->incRcvdArpRequests(); }
  inline void incRcvdArpReplies() { stats->incRcvdArpReplies(); }
  void periodic_stats_update(const struct timeval *tv);
  inline u_int64_t getNumBytes() { return (stats->getNumBytes()); }
  inline float getBytesThpt() { return (stats->getBytesThpt()); }
  inline bool isMulticast() { return Utils::isMulticastMac(mac); }
  inline u_int64_t getNumPktsSent() { return stats ? stats->getNumPktsSent() : 0; }
  inline u_int64_t getNumPktsRcvd() { return stats ? stats->getNumPktsRcvd() : 0; }
  inline u_int64_t getNumBytesSent() { return stats ? stats->getNumBytesSent() : 0; }
  inline u_int64_t getNumBytesRcvd() { return stats ? stats->getNumBytesRcvd() : 0; }

  inline bool isBroadcast() { return (broadcast_mac); }

  inline void incNumDHCPRequests() { stats->incNumDHCPRequests(); }
  inline void incNumDHCPReplies() { stats->incNumDHCPReplies(); }
};

#endif /* _MAC_H_ */
