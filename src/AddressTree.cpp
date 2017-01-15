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

#include "ntop_includes.h"

#include "../third-party/patricia/patricia.c"

/* **************************************** */

AddressTree::AddressTree() {
  numAddresses = 0;
  ptree_v4 = New_Patricia(32), ptree_v6 = New_Patricia(128), ptree_mac = New_Patricia(48);
}

/* **************************************** */

static void free_ptree_data(void *data) { ; }

/* **************************************** */

AddressTree::~AddressTree() {
  if(ptree_v4)  Destroy_Patricia(ptree_v4, free_ptree_data);
  if(ptree_v6)  Destroy_Patricia(ptree_v6, free_ptree_data);
  if(ptree_mac) Destroy_Patricia(ptree_mac, free_ptree_data);
}

/* ******************************************* */

patricia_tree_t* AddressTree::getPatricia(char* what) {
  u_int32_t _mac[6];

  if(sscanf(what, "%02X:%02X:%02X:%02X:%02X:%02X",
	    &_mac[0], &_mac[1], &_mac[2],
	    &_mac[3], &_mac[4], &_mac[5]) == 6)
    return(ptree_mac);
  else
    return(strchr(what, '.') ? ptree_v4 : ptree_v6);  
}

/* ******************************************* */

bool AddressTree::removeAddress(char *net) {
  bool rc = Utils::ptree_remove_rule(getPatricia(net), net) == 1 ? false /* not found */ : true /* found */;

  if(rc) numAddresses--;

  return(rc);
}

/* ******************************************* */

patricia_node_t* AddressTree::addAddress(char *_net) {
  patricia_node_t *node = Utils::ptree_add_rule(getPatricia(_net), _net);

  if(node) node->user_data = numAddresses++;
  return(node);
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
bool AddressTree::addAddresses(char *rule) {
  char *tmp, *net = strtok_r(rule, ",", &tmp);
  
  while(net != NULL) {
    if(!addAddress(net))
      return false;
    
    net = strtok_r(NULL, ",", &tmp);
  }
  
  return true;
}

/* ******************************************* */

int16_t AddressTree::findAddress(int family, void *addr) {
  patricia_node_t *node = Utils::ptree_match((family == AF_INET) ? ptree_v4 : ptree_v6,
					     family, addr,
					     (family == AF_INET) ? 32 : 128);
  
  if(node == NULL)
    return(-1);
  else
    return(node->user_data);
}

/* **************************************************** */

static void address_tree_dump_funct(prefix_t *prefix, void *data, void *user_data) {
  char address[64], ret[64], *a;

  if(!prefix) return;

  switch(prefix->family) {
  case AF_INET:
    a = Utils::intoaV4(ntohl(prefix->add.sin.s_addr), address, sizeof(address));
    snprintf(ret, sizeof(ret), "%s/%d", a, prefix->bitlen);
    break;

  case AF_INET6:
    a = Utils::intoaV6(*((struct ndpi_in6_addr*)&prefix->add.sin6), prefix->bitlen, address, sizeof(address));
    snprintf(ret, sizeof(ret), "%s/%d", a, prefix->bitlen);
    break;

  default: /* Mac */
    snprintf(ret, sizeof(ret), "%02X:%02X:%02X:%02X:%02X:%02X",
	     prefix->add.mac[0], prefix->add.mac[1], prefix->add.mac[2],
	     prefix->add.mac[3], prefix->add.mac[4], prefix->add.mac[5]);
    break;
  }

  if(user_data)
    lua_push_str_table_entry((lua_State*)user_data, ret, (char*)"");
  else
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[AddressTree] %s", ret);
}

/* **************************************************** */

void AddressTree::getAddresses(lua_State* vm) {
  if(ptree_v4->head)  patricia_walk_inorder(ptree_v4->head, address_tree_dump_funct, vm);
  if(ptree_v6->head)  patricia_walk_inorder(ptree_v6->head, address_tree_dump_funct, vm);
  if(ptree_mac->head) patricia_walk_inorder(ptree_mac->head, address_tree_dump_funct, vm);
}

/* **************************************************** */

void AddressTree::dump() {
  if(ptree_v4->head)  patricia_walk_inorder(ptree_v4->head, address_tree_dump_funct, NULL);
  if(ptree_v6->head)  patricia_walk_inorder(ptree_v6->head, address_tree_dump_funct, NULL);
  if(ptree_mac->head) patricia_walk_inorder(ptree_mac->head, address_tree_dump_funct, NULL);
}

