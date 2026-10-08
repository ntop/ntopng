/*
 *
 * (C) 2013-26 - ntop.org
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
#include "flow_checks_includes.h"

/* ***************************************************** */

ServerConfiguration::ServerConfiguration() {
  servers_shadow = NULL;
  servers = new (std::nothrow) ServersTree();
}

/* ***************************************************** */

ServerConfiguration::~ServerConfiguration() {
  if (servers_shadow) delete servers_shadow;
  if (servers) delete servers;
}

/* ***************************************************** */

void ServerConfiguration::reloadServersConfiguration() {
  ServersTree* new_servers = new (std::nothrow) ServersTree();

  if (new_servers == NULL) return;

  for (int type = 1; type < HOST_SERVICE_MAX; type++)
    loadConfiguration(new_servers, (HostService)type);

  /* Swap trees */
  if (servers) {
    if (servers_shadow) delete servers_shadow;
    servers_shadow = servers;
  }

  servers = new_servers;
}

/* ***************************************************** */

u_int32_t ServerConfiguration::getServerTypes(IpAddress* ip,
                                              u_int16_t vlan_id) {
  ServersTree* cur = servers;
  ndpi_patricia_node_t* found_node;

  if (!cur || !ip) return (0);

  found_node = (ndpi_patricia_node_t*)ip->findAddress(cur->tree.getAddressTree(vlan_id & 0xFFF));

  if (found_node) return ((u_int32_t)ndpi_patricia_get_node_u64(found_node));

  return (0);
}

/* ***************************************************** */

/* Add server to the tree. Note: the same address can be configured for multiple server types,
 * we merge the new type with the types already set for the address (bitmap) */
void ServerConfiguration::addServer(ServersTree* st, HostService type,
                                    u_int16_t vlan_id, const char* net) {
  AddressTree* t = st->tree.getAddressTree(vlan_id & 0xFFF);
  int64_t cur_types = t ? t->find(net) : -1 /* Not found */;
  u_int64_t types = (cur_types > 0) ? (u_int64_t) cur_types : 0;

  types |= ((u_int64_t)1 << type);

  if (!st->tree.addAddress(vlan_id, net, (int64_t)types)) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to add tree node in Server "
                                 "Configuration [vlan %i] [IP: %s]", vlan_id, net);
    return;
  }

  st->num_servers[type]++;
}

/* ***************************************************** */

/* Load the configured servers for the service from Redis
 * (see CONST_SERVICE_CONFIGURATION_REDIS_KEY) */
void ServerConfiguration::loadConfiguration(ServersTree* st, HostService type) {
  char* rsp = NULL;
  const char* service_name = Utils::hostService2str(type);
  char key[64];
  Redis* redis = ntop->getRedis();
  u_int actual_len;

  if (service_name == NULL) return;

  snprintf(key, sizeof(key), CONST_SERVICE_CONFIGURATION_REDIS_KEY, service_name);

  actual_len = redis->len(key);

  if (actual_len++ /* ++ for the \0 */ > 0 && (rsp = (char*)malloc(actual_len)) != NULL) {
    redis->get(key, rsp, actual_len);
    /* Get a list of Servers separated by commas */
    std::string ipStr(rsp);
    char charToRemove = ' ';

    /* Remove the spaces between the IPs */
    ipStr.erase(std::remove(ipStr.begin(), ipStr.end(), charToRemove), ipStr.end());

    /* Now iterate the string */
    std::stringstream ipList(ipStr);
    std::string ip;
    while (std::getline(ipList, ip, ',')) {
      u_int16_t vlan_id = 0;
      char* at = NULL;

      if (ip.empty()) continue;

      /* Check for the VLAN */
      if ((at = strchr((char*)ip.c_str(), '@'))) {
        vlan_id = atoi(at + 1);
        *at = '\0';
      } else
        vlan_id = 0;

      addServer(st, type, vlan_id, ip.c_str());
    }

    if (rsp) free(rsp);
  }
}

/* ***************************************************** */
