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

#include "ntop_includes.h"
#include "FlowsManager.h"

FlowsManager::FlowsManager(NetworkInterface *intf)
{
  this->intf = intf;
}

static bool flows_select_walker(GenericHashEntry *h, void *user_data)
{
  struct flow_details_info *info = (struct flow_details_info*)user_data;
  Flow *flow = (Flow*)h;

  switch(info->field) {
    case FF_NONE: break;
    case FF_HOST: if((info->host != flow->get_cli_host())
                     && (info->host != flow->get_srv_host()))
                    return false;
                  break;
    case FF_CLIHOST: if (info->host != flow->get_cli_host())
                       return false;
                     break;
    case FF_SRVHOST: if (info->host != flow->get_srv_host())
                       return false;
                     break;
    case FF_PROTOCOL: if (info->protocol != flow->get_protocol())
                        return false;
                      break;
    case FF_NDPIPROTOCOL: if (info->ndpi_protocol != flow->get_detected_protocol())
                            return false;
                          break;
    default: ntop->getTrace()->traceEvent(TRACE_WARNING,
               "Wrong value to flow selection (walker)");
             return true;
  }

  flow->lua(info->vm, info->allowed_hosts, false /* Minimum details */);

  info->count++;
  if (info->limit > 0 && info->count > info->limit)
    return true;
  return false; /* false = keep on walking */
}

void FlowsManager::select(lua_State* vm,
                          patricia_tree_t *allowed_hosts,
                          enum flowsField field,
                          void *value,
                          void *auxiliary_value,
                          unsigned long limit)
{
  struct flow_details_info info;
  info.vm = vm, info.allowed_hosts = allowed_hosts;
  char * host_ip;
  u_int vlan_id;

  info.field = field;

  switch(field) {
    case FF_HOST:
    case FF_CLIHOST:
    case FF_SRVHOST: host_ip = (char *)value;
                     vlan_id = *((u_int *)auxiliary_value);
                     info.host = intf->getHost(host_ip, vlan_id);
                     break;
    case FF_PROTOCOL: info.protocol = *((u_int8_t *)value);
                      break;
    case FF_NDPIPROTOCOL: info.ndpi_protocol = *((u_int16_t *)value);
                          break;
    default: ntop->getTrace()->traceEvent(TRACE_WARNING,
               "Wrong value to flow selection");
             return;
  }

  if((field != FF_HOST && field != FF_CLIHOST && field != FF_SRVHOST) ||
     (info.host != NULL && info.host->match(allowed_hosts)))
    intf->get_flows_hash()->walk(flows_select_walker, (void*)&info);
}
