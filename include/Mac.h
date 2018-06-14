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

#ifndef _MAC_H_
#define _MAC_H_

#include "ntop_includes.h"

class Mac : public GenericHashEntry, public GenericTrafficElement {
 private:
  u_int8_t mac[6];
  u_int32_t bridge_seen_iface_id; /* != 0 for bridge interfaces only */
  char *fingerprint;
  const char *manuf, *model, *ssid;
  OperatingSystem os;
  bool source_mac, special_mac, dhcpHost, lockDeviceTypeChanges;
  ArpStats arp_stats;
  DeviceType device_type;
#ifdef NTOPNG_PRO
  time_t captive_portal_notified;
#endif
  void checkDeviceTypeFromManufacturer();

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
  inline bool isNull()           { for(int i=0; i<6; i++) { if(mac[i] != 0) return(false); } return(true); }

  bool equal(const u_int8_t _mac[6]);
  inline void incSentStats(u_int64_t num_pkts, u_int64_t num_bytes)  {
    sent.incStats(num_pkts, num_bytes);
    if(first_seen == 0) first_seen = iface->getTimeLastPktRcvd();
    last_seen = iface->getTimeLastPktRcvd();
  }
  inline void incRcvdStats(u_int64_t num_pkts, u_int64_t num_bytes) {
    rcvd.incStats(num_pkts, num_bytes);
  }
  inline void incnDPIStats(u_int32_t when, u_int16_t protocol,
	    u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
	    u_int64_t rcvd_packets, u_int64_t rcvd_bytes, u_int64_t rcvd_goodput_bytes) {
    if(ndpiStats || (ndpiStats = new nDPIStats())) {
      //ndpiStats->incStats(when, protocol.master_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
      //ndpiStats->incStats(when, protocol.app_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);
      ndpiStats->incCategoryStats(when,
				  getInterface()->get_ndpi_proto_category(protocol),
				  sent_bytes, rcvd_bytes);
    }
  }

  inline void incSentArpRequests()   { arp_stats.sent_requests++;         }
  inline void incSentArpReplies()    { arp_stats.sent_replies++;          }
  inline void incRcvdArpRequests()   { arp_stats.rcvd_requests++;         }
  inline void incRcvdArpReplies()    { arp_stats.rcvd_replies++;          }
#ifdef NTOPNG_PRO
  inline time_t getNotifiedTime()    { return captive_portal_notified;       };
  inline void   setNotifiedTime()    { captive_portal_notified = time(NULL); };
  #endif
  inline void setSeenIface(u_int32_t idx)  { bridge_seen_iface_id = idx; setSourceMac(); }
  inline u_int32_t getSeenIface()     { return(bridge_seen_iface_id); }
  inline void setDeviceType(DeviceType devtype) { if(!lockDeviceTypeChanges) device_type = devtype; }
  inline DeviceType getDeviceType()        { return (device_type); }
  inline u_int64_t  getNumSentArp()   { return (u_int64_t)arp_stats.sent_requests + arp_stats.sent_replies; }
  inline u_int64_t  getNumRcvdArp()   { return (u_int64_t)arp_stats.rcvd_requests + arp_stats.rcvd_replies; }

  bool idle();
  void lua(lua_State* vm, bool show_details, bool asListElement);
  inline char* get_string_key(char *buf, u_int buf_len) { return(Utils::formatMac(mac, buf, buf_len)); };
  inline int16_t findAddress(AddressTree *ptree)        { return ptree ? ptree->findMac(mac) : -1;     };
  inline char* print(char *str, u_int str_len)          { return(Utils::formatMac(mac, str, str_len)); };
  char* serialize();
  void deserialize(char *key, char *json_str);
  json_object* getJSONObject();
  void updateFingerprint();
  void updateHostPool(bool isInlineCall);
  inline void setOperatingSystem(OperatingSystem _os) { os = _os;   }
  inline OperatingSystem getOperatingSystem()         { return(os); }
  inline char* getFingerprint()                       { return(fingerprint); }
  inline void setFingerprint(char *f) { if(f) { if(fingerprint) free(fingerprint); fingerprint = strdup(f); updateFingerprint(); } }
  void setModel(char* m);
  inline char* getModel() { return((char*)model); }
  void setSSID(char* s);
  inline char* getSSID()  { return((char*)ssid);  }
};

#endif /* _MAC_H_ */
