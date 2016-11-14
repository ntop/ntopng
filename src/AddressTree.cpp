/*
 *
 * (C) 2013-16 - ntop.org
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
  numAddresses = 0, memset(addressString, 0, sizeof(addressString));
  ptree = New_Patricia(128);
}

/* *********************************************** */

u_int8_t AddressTree::getNumAddresses() {
  return(numAddresses);
}

/* ******************************************* */

bool AddressTree::removeAddress(char *net) {
  return(Utils::ptree_remove_rule(ptree, net) == 1 ? false /* not found */ : true /* found */);
}

/* ******************************************* */

int16_t AddressTree::addAddress(char *_net) {
  patricia_node_t *node;
  char *net;

  if(numAddresses >= CONST_MAX_NUM_NETWORKS) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many networks defined (%d): ignored %s", numAddresses, _net);
    return -1;
  }
  
  if((net = strdup(_net)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    return -1;
  }

  node = Utils::ptree_add_rule(ptree, net);

  free(net);

  if(node) {
    node->user_data = numAddresses;
    addressString[numAddresses++] = strdup(_net);
    return node->user_data;
  }

  return -1;
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
bool AddressTree::addAddresses(char *rule) {
  char *net = strtok(rule, ",");
  
  while(net != NULL) {
    if(addAddress(net) < 0) return false;
    net = strtok(NULL, ",");
  }
  return true;
}

/* ******************************************* */

int16_t AddressTree::findAddress(int family, void *addr) {
  patricia_node_t *node = Utils::ptree_match(ptree, family, addr, (family == AF_INET) ? 32 : 128);

  if(node == NULL)
    return(-1);
  else
    return(node->user_data);
}

/* **************************************** */

void free_ptree_data(void *data) { ; }

/* **************************************** */

AddressTree::~AddressTree() {
  if(ptree) Destroy_Patricia(ptree, free_ptree_data);

  for(int i=0; i<numAddresses; i++)
    free(addressString[i]);
}

/* **************************************************** */

void print_funct(prefix_t *prefix, void *data, void *user_data) {
  char address[64], ret[64], *a;

  if(!prefix) return;

  if(prefix->family == AF_INET) {
    if((prefix->bitlen == 0) || (prefix->bitlen == 32)) return;

    a = Utils::intoaV4(ntohl(prefix->add.sin.s_addr), address, sizeof(address));
  } else {
    if((prefix->bitlen == 0) || (prefix->bitlen == 128)) return;

    a = Utils::intoaV6(*((struct ndpi_in6_addr*)&prefix->add.sin6), prefix->bitlen, address, sizeof(address));
  }

  snprintf(ret, sizeof(ret), "%s/%d", a, prefix->bitlen);
  lua_push_str_table_entry((lua_State*)user_data, ret, (char*)"");
}

/* **************************************************** */

void AddressTree::getAddresses(lua_State* vm) {
  patricia_walk_inorder(ptree->head, print_funct, vm);
}
