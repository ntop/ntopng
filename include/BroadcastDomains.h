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

#ifndef _BROADCAST_DOMAINS_H_
#define _BROADCAST_DOMAINS_H_

class Host;

#include "ntop_includes.h"

class BroadcastDomains {
 private:
  NetworkInterface *iface;
  AddressTree *inline_broadcast_domains; /* Accessed inline */
  AddressTree *broadcast_domains, *broadcast_domains_shadow; /* Accessed concurrently non-inline */
  time_t next_update, last_update;
  u_int16_t next_domain_id;
  std::map<u_int16_t, struct bcast_domain_info> domains_info; /* Insertion: inline, read: non-inline */

 public:
  BroadcastDomains(NetworkInterface *_iface);
  ~BroadcastDomains();

  inline time_t getLastUpdate() const { return last_update; };
  bool addAddress(const IpAddress * const ipa, int network_bits);
  void reloadBroadcastDomains(bool force_immediate_reload = false);
  bool isLocalBroadcastDomain(const IpAddress * const ipa, int network_bits, bool isInlineCall) const;
  bool isLocalBroadcastDomainHost(const Host * const h, bool isInlineCall) const;
  bool isGhostLocalBroadcastDomain(bool is_interface_network) const;
  void lua(lua_State* vm) const;
};

#endif /* _BROADCAST_DOMAINS_H_ */

