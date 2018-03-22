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

#ifndef _NETWORK_DISCOVERY_H_
#define _NETWORK_DISCOVERY_H_

#include "ntop_includes.h"

/* ******************************* */

class NetworkDiscovery {
 private:
  int udp_sock;
  NetworkInterface *iface;
  pcap_t *pd;

  u_int32_t wrapsum(u_int32_t sum);
  u_int16_t in_cksum(u_int8_t *buf, u_int16_t buf_len, u_int32_t sum);
  u_int16_t buildMDNSDiscoveryDatagram(const char *query, u_int32_t sender_ip, u_int8_t *sender_mac,
				       char *datagram, u_int datagram_len);
  void dissectMDNS(u_char *buf, u_int buf_len, char *out, u_int out_len);
    
public:
  NetworkDiscovery(NetworkInterface *_iface);
  ~NetworkDiscovery();

  void discover(lua_State* vm, u_int timeout);
  void arpScan(lua_State* vm);
};

#endif /* _NETWORK_DISCOVERY_H_ */
