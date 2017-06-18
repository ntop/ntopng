/*
 *
 * (C) 2013-17 - ntop.org
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
  int sock;
  
public:
  NetworkDiscovery(NetworkInterface *_iface);
  ~NetworkDiscovery();

  void discover(lua_State* vm);
};

#endif /* _NETWORK_DISCOVERY_H_ */
