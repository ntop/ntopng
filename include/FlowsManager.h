/*
 *
 * (C) 2013-15 - ntop.org
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

#ifndef _FLOWS_MANAGER_H_
#define _FLOWS_MANAGER_H_

#include "ntop_includes.h"

enum flowsField { FF_CLIHOST, FF_SRVHOST, FF_HOST, FF_PROTOCOL, FF_NDPIPROTOCOL };

struct flow_details_info {
  lua_State* vm;
  patricia_tree_t *allowed_hosts;

  /* Selectors */
  enum flowsField field;
  Host *host;
  u_int8_t protocol;
  u_int16_t ndpi_protocol;

  unsigned long count;
  unsigned long limit;
};

class NetworkInterface;

class FlowsManager {
public:
  FlowsManager(NetworkInterface *intf);

  void select(lua_State* vm, patricia_tree_t *allowed_hosts,
              enum flowsField field,
              void *value, void *auxiliary_value,
              unsigned long limit);

private:
  NetworkInterface *intf;
};

#endif /* _FLOWS_MANAGER_H_ */
