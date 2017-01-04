/*
 *
 * (C) 2013-16 - ntop.org
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
  u_int16_t vlan_id;
  bool special_mac;

 public:
  Mac(NetworkInterface *_iface, u_int8_t _mac[6], u_int16_t _vlanId);
  ~Mac();

  inline u_int16_t getNumHosts() { return getUses();            }
  inline bool isSpecialMac()     { return(special_mac);         }
  inline u_int32_t key()         { return(Utils::macHash(mac)); }
  inline u_int8_t* get_mac()     { return(mac);                 }
  inline u_int16_t get_vlan_id() { return(vlan_id);             }
  bool equal(u_int16_t _vlanId, const u_int8_t _mac[6]);
  inline void incSentStats(u_int pkt_len)  {
    sent.incStats(pkt_len);
    if(first_seen == 0) first_seen = iface->getTimeLastPktRcvd();
    last_seen = iface->getTimeLastPktRcvd();
  }
  inline void incRcvdStats(u_int pkt_len)  { rcvd.incStats(pkt_len); }
  bool idle();
  void lua(lua_State* vm, bool show_details, bool asListElement);
  inline char* get_string_key(char *buf, u_int buf_len) { return(Utils::formatMac(mac, buf, buf_len)); }
};

#endif /* _MAC_H_ */
