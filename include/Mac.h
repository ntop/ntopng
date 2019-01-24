/*
 *
 * (C) 2013-19 - ntop.org
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
  u_int8_t mac[6];
  u_int16_t host_pool_id;
  u_int32_t bridge_seen_iface_id; /* != 0 for bridge interfaces only */
  bool special_mac, lockDeviceTypeChanges;
  bool stats_reset_requested, data_delete_requested;
  const char *manuf;
  MacStats *stats, *stats_shadow;
  time_t last_stats_reset;

  /* Mac data: update Mac::deleteMacData when adding new fields */
  char *fingerprint;
  const char *model;
  const char *ssid, *ssid_shadow;
  OperatingSystem os;
  bool source_mac, dhcpHost;
  DeviceType device_type;
#ifdef NTOPNG_PRO
  time_t captive_portal_notified;
#endif
  /* END Mac data: */

  void updateFingerprint();
  void checkDeviceTypeFromManufacturer();
  void deleteMacData();
  bool statsResetRequested();
  void checkStatsReset();

 public:
  Mac(NetworkInterface *_iface, u_int8_t _mac[6]);
  ~Mac();

  inline u_int16_t getNumHosts()   { return getUses();            }
  inline void incUses() {
    GenericHashEntry::incUses();

    if(getUses() > CONST_MAX_NUM_HOST_USES) {
      setDeviceType(device_networking);
      lockDeviceTypeChanges = true;
    }
  }
  inline void decUses()            { GenericHashEntry::decUses(); }
  inline bool isSpecialMac()       { return(special_mac);         }
  inline bool isDhcpHost()         { return(dhcpHost);            }
  inline void setDhcpHost()        { dhcpHost = true;             }
  inline bool isSourceMac()        { return(source_mac);          }
  inline void setSourceMac() {
    if(!source_mac && !special_mac) {
      source_mac = true;
      iface->incNumL2Devices();
    }
  }

  MacLocation locate();
  inline u_int32_t key()                       { return(Utils::macHash(mac)); }
  inline u_int8_t* get_mac()                   { return(mac);                 }
  inline const char * const get_manufacturer() { return manuf ? manuf : NULL; }
  bool isNull() const;

  bool equal(const u_int8_t _mac[6]);

#ifdef NTOPNG_PRO
  inline time_t getNotifiedTime()    { return captive_portal_notified;       };
  inline void   setNotifiedTime()    { captive_portal_notified = time(NULL); };
  #endif
  inline void setSeenIface(u_int32_t idx)  { bridge_seen_iface_id = idx; setSourceMac(); }
  inline u_int32_t getSeenIface()     { return(bridge_seen_iface_id); }
  inline void setDeviceType(DeviceType devtype) {
    if(isNull())
      return;

    /* Called by ntopng when it can guess a device type during normal packet processing */
    if(!lockDeviceTypeChanges)
      device_type = devtype;
  }
  inline void forceDeviceType(DeviceType devtype) {
    /* Called when a user, from the GUI, wants to change the device type and specify a custom type */
    device_type = devtype;
    /* If the user specifies a custom type, then we want ntopng to stop guessing other types for
       the same device */
    if(!lockDeviceTypeChanges) lockDeviceTypeChanges = true;
  }
  inline DeviceType getDeviceType()        { return (device_type); }

  bool idle();
  void lua(lua_State* vm, bool show_details, bool asListElement);
  inline char* get_string_key(char *buf, u_int buf_len) { return(Utils::formatMac(mac, buf, buf_len)); };
  inline int16_t findAddress(AddressTree *ptree)        { return ptree ? ptree->findMac(mac) : -1;     };
  inline char* print(char *str, u_int str_len)          { return(Utils::formatMac(mac, str, str_len)); };
  char* serialize();
  void deserialize(char *key, char *json_str);
  json_object* getJSONObject();
  void updateHostPool(bool isInlineCall);
  inline void setOperatingSystem(OperatingSystem _os) { os = _os;   }
  inline OperatingSystem getOperatingSystem()         { return(os); }
  inline char* getFingerprint()                       { return(fingerprint); }
  void inlineSetModel(const char * const m);
  void inlineSetFingerprint(const char * const f);
  void setSSID(char* s);
  inline char* getSSID()  { return((char*)ssid);  }
  inline u_int16_t get_host_pool() { return(host_pool_id); }

  inline void requestStatsReset()                        { stats_reset_requested = true; };
  inline void requestDataReset()                         { data_delete_requested = true; requestStatsReset(); };
  void checkDataReset();

  inline void incSentStats(u_int64_t num_pkts, u_int64_t num_bytes)  {
    if(first_seen == 0) first_seen = iface->getTimeLastPktRcvd();
    stats->incSentStats(num_pkts, num_bytes);
    last_seen = iface->getTimeLastPktRcvd();
  }
  inline void incnDPIStats(u_int32_t when, u_int16_t protocol,
	    u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
	    u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes) {
    stats->incnDPIStats(when, protocol, sent_packets, sent_bytes, sent_goodput_bytes,
      rcvd_packets, rcvd_bytes, rcvd_goodput_bytes);
  }
  inline void incRcvdStats(u_int64_t num_pkts, u_int64_t num_bytes)  { stats->incRcvdStats(num_pkts, num_bytes); }

  inline u_int64_t  getNumSentArp()  { return(stats->getNumSentArp());      }
  inline u_int64_t  getNumRcvdArp()  { return(stats->getNumRcvdArp());      }
  inline void incNumDroppedFlows()   { stats->incNumDroppedFlows(); }
  inline void incSentArpRequests()   { stats->incSentArpRequests(); }
  inline void incSentArpReplies()    { stats->incSentArpReplies();  }
  inline void incRcvdArpRequests()   { stats->incRcvdArpRequests(); }
  inline void incRcvdArpReplies()    { stats->incRcvdArpReplies();  }
  void updateStats(struct timeval *tv);
  inline u_int64_t getNumBytes()              { return(stats->getNumBytes());      }
  inline float getThptTrendDiff()             { return(stats->getThptTrendDiff()); }
  inline float getBytesThpt()                 { return(stats->getBytesThpt());     }
};

#endif /* _MAC_H_ */
