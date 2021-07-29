/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef _IP_ADDRESS_H_
#define _IP_ADDRESS_H_

#include "ntop_includes.h"

struct ipAddress {
  u_int8_t ipVersion:3 /* Either 4 or 6 */,
    loopbackIP:1, privateIP:1, multicastIP:1, broadcastIP:1,
    blacklistedIP:1,
    notUsed:1 /* Future use */;

  union {
    struct ndpi_in6_addr ipv6;
    u_int32_t ipv4; /* Host byte code */
  } ipType;
};

/* **************************************** */

class IpAddress {
 private:
  struct ipAddress addr;
  u_int32_t ip_key;

  char* intoa(char* buf, u_short bufLen, u_int8_t bitmask) const;
  void checkIP();
  void compute_key();

 public:
  IpAddress();
  IpAddress(const IpAddress& ipa);

  bool isEmpty() const;
  inline void reset()                                  { memset(&addr, 0, sizeof(addr));               }
  inline bool isIPv4() const                           { return((addr.ipVersion == 4) ? true : false); }
  inline bool isIPv6() const                           { return((addr.ipVersion == 6) ? true : false); }
  inline u_int32_t get_ipv4() const                    { return((addr.ipVersion == 4) ? addr.ipType.ipv4 : 0);     }
  inline const struct ndpi_in6_addr* get_ipv6() const  { return((addr.ipVersion == 6) ? &addr.ipType.ipv6 : NULL); }
  inline const struct ipAddress* getIP()        const  { return(&addr); };
  inline bool equal(u_int32_t ipv4_addr)        const  { if((addr.ipVersion == 4) && (addr.ipType.ipv4 == ipv4_addr)) return(true); else return(false); };
  inline bool equal(struct ndpi_in6_addr *ip6_addr) const { if((addr.ipVersion == 6) && (memcmp(&addr.ipType.ipv6, ip6_addr, sizeof(struct ndpi_in6_addr)) == 0)) return(true); else return(false); };
  inline bool equal(const IpAddress * const _ip) const { return(this->compare(_ip) == 0); };
  int compare(const IpAddress * const ip)        const;
  IpAddress* clone();
  inline u_int32_t key()                        const { return(ip_key);         };
  inline void set(u_int32_t _ipv4)                    { addr.ipVersion = 4, addr.ipType.ipv4 = _ipv4; compute_key(); }
  inline void set(struct ndpi_in6_addr *_ipv6)        { addr.ipVersion = 6, memcpy(&addr.ipType.ipv6, _ipv6, sizeof(struct ndpi_in6_addr));
							addr.privateIP = false; compute_key(); }
  inline void set(struct in6_addr *_ipv6)             { addr.ipVersion = 6, memcpy(&addr.ipType.ipv6.u6_addr, _ipv6->s6_addr, sizeof(_ipv6->s6_addr));
							addr.privateIP = false; compute_key(); }
  inline void set(const IpAddress * const ip)         { memcpy(&addr, &ip->addr, sizeof(struct ipAddress)); ip_key = ip->ip_key; };
  inline void set(const struct ipAddress * const ip)  { memcpy(&addr, ip, sizeof(struct ipAddress)); compute_key(); };
  void set(union usa *ip);
  void set(const char * const ip);
  void reloadBlacklist(ndpi_detection_module_struct* ndpi_struct);
  inline bool isLoopbackAddress()        const        { return(addr.loopbackIP);    };
  inline bool isPrivateAddress()         const        { return(addr.privateIP);     };
  inline bool isMulticastAddress()       const        { return(addr.multicastIP);   };
  inline bool isBroadcastAddress()       const        { return(addr.broadcastIP);   };
  inline bool isBlacklistedAddress()     const        { return(addr.blacklistedIP); };
  inline bool isBroadMulticastAddress()  const        { return(addr.broadcastIP || addr.multicastIP); };
  inline bool isNonEmptyUnicastAddress() const        { return(!isMulticastAddress() && !isBroadcastAddress() && !isEmpty()); };
  inline u_int8_t getVersion()           const        { return(addr.ipVersion); };
  inline void setVersion(u_int8_t version)            { addr.ipVersion = version; };
  char* print(char *str, u_int str_len, u_int8_t bitmask = 0xFF) const;
  char* printMask(char *str, u_int str_len, bool isLocalIP);
  bool isLocalHost(int16_t *network_id) const;
  bool isLocalInterfaceAddress();
  char* serialize();
  bool get_sockaddr(struct sockaddr ** const sa, ssize_t * const sa_len) const;
  json_object* getJSONObject();
  bool match(const AddressTree * const tree) const;
  void* findAddress(AddressTree *ptree);
  void dump();
  void incCardinality(Cardinality *c);
};

#endif /* _IP_ADDRESS_H_ */
