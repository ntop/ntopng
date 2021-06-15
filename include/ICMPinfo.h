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

#ifndef _ICMP_INFO_H_
#define _ICMP_INFO_H_

#include "ntop_includes.h"

typedef struct {
  IpAddress src_ip, dst_ip;
  u_int16_t src_port, dst_port;
  u_int16_t protocol;
} unreachable_t;

class ICMPinfo {
 private:
  u_int8_t icmp_type;
  u_int8_t icmp_code;
  u_int16_t icmp_identifier;
  unreachable_t *unreach;

  void reset();

 public:
  ICMPinfo();
  ICMPinfo(const ICMPinfo& _icmp_info);
  virtual ~ICMPinfo();
  unreachable_t *getUnreach() const { return unreach; };
  void dissectICMP(u_int16_t const payload_len, const u_int8_t * const payload_data);
  inline void setType(u_int8_t type) { icmp_type = type; };
  inline void setCode(u_int8_t code) { icmp_code = code; };
  void print() const;
  u_int32_t key() const;
  bool equal(const ICMPinfo * const icmp_info) const;
  void lua(lua_State* vm, AddressTree * ptree, NetworkInterface *iface, VLANid vlan_id) const;
  bool isPortUnreachable() const;
  bool isHostUnreachable(u_int8_t proto) const;
};

#endif /* _ICMP_INFO_H_ */
