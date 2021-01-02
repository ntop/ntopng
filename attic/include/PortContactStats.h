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

#ifndef _PORT_CONTACT_STATS_H_
#define _PORT_CONTACT_STATS_H_

#include "ntop_includes.h"

class PortContactStats {
  u_int16_t l7_proto;
  std::string last_peer, info;
  time_t last_seen; 

 public:
  PortContactStats() { l7_proto = 0, last_seen = 0; }
  PortContactStats(u_int16_t _l7_proto, Host *peer, const char *_info, time_t when);

  void update(Host *peer, const char *_info, time_t when);
  void lua(lua_State* vm, NetworkInterface *iface);
};


#endif
