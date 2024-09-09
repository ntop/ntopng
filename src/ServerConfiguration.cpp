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

#include "ntop_includes.h"
#include "flow_checks_includes.h"

/* ***************************************************** */

ServerConfiguration::ServerConfiguration() {
  /* Given the key, load the server configuration found on key */
  tree_shadow = NULL;

  tree = new (std::nothrow) VLANAddressTree;
  if(tree == NULL) {
    return;
  }
}

/* ***************************************************** */

ServerConfiguration::~ServerConfiguration() {
  if (tree_shadow) delete tree_shadow;
  if (tree) delete tree;
}

/* ***************************************************** */

void ServerConfiguration::reloadServerConfiguration(char *key) {
  VLANAddressTree *new_tree;

  new_tree = new (std::nothrow) VLANAddressTree;
  if(new_tree == NULL) {
    return;
  }
  loadConfiguration(new_tree, key);

  /* Swap address trees */
  if (new_tree) {
    if (tree) {
      if (tree_shadow) delete tree_shadow;
      tree_shadow = tree;
    }

    tree = new_tree;
  }
}

/* ***************************************************** */

bool ServerConfiguration::findAddress(IpAddress *ip, u_int16_t vlan_id) {
  VLANAddressTree *cur_tree; /* must use this as tree can be swapped */
  ndpi_patricia_node_t *found_node;
  if (!tree || !(cur_tree = tree) || !ip) return (false);
  
  found_node = (ndpi_patricia_node_t *)ip->findAddress(
      cur_tree->getAddressTree(vlan_id));
      
  if (found_node) {
    return (true);
  }

  return (false);
}

/* ***************************************************** */

void ServerConfiguration::loadConfiguration(VLANAddressTree *tree, char *key) {
  char *rsp = NULL;
  Redis *redis = ntop->getRedis();
  u_int actual_len = redis->len(key);

  if (actual_len++ /* ++ for the \0 */ > 0 &&
      (rsp = (char *)malloc(actual_len)) != NULL) {
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
      char *at = NULL;
      bool rc;
      
      /* Check for the VLAN */
      if ((at = strchr((char *) ip.c_str(), '@'))) {
        vlan_id = atoi(at + 1);
        *at = '\0';
      } else
        vlan_id = 0;
        
      if (!(rc = tree->addAddress(vlan_id, (char *) ip.c_str()))) {
        ntop->getTrace()->traceEvent(
            TRACE_WARNING, "Unable to add tree node in Server Configuration [vlan %i] [IP: %s]", 
              vlan_id, (char *) ip.c_str());
      }
    }

    if (rsp) free(rsp);
  }
}

/* ***************************************************** */
