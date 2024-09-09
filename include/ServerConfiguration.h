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

#ifndef _SERVER_CONFIGURATION_H
#define _SERVER_CONFIGURATION_H

#include "ntop_includes.h"

class ServerConfiguration {
 private:
  VLANAddressTree *tree, *tree_shadow;
  
  void loadConfiguration(VLANAddressTree *tree, char *key);
 public:
  ServerConfiguration();
  ~ServerConfiguration();

  bool findAddress(IpAddress *ip, u_int16_t vlan_id);
  void reloadServerConfiguration(char *key);
};

#endif /* _SERVER_CONFIGURATION_H */
