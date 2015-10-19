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

#include "../third-party/patricia/patricia.c"

/* **************************************** */

AddressTree::AddressTree() {
  numAddresses = 0;
  ptree = New_Patricia(128);
}

/* *********************************************** */

static int fill_prefix_v4(prefix_t *p, struct in_addr *a, int b, int mb) {
  do {
    if(b < 0 || b > mb)
      return(-1);

    memcpy(&p->add.sin, a, (mb+7)/8);
    p->family = AF_INET;
    p->bitlen = b;
    p->ref_count = 0;
  } while (0);

  return(0);
}

/* ******************************************* */

static int fill_prefix_v6(prefix_t *prefix, struct in6_addr *addr, int bits, int maxbits) {
  if(bits < 0 || bits > maxbits)
    return -1;

  memcpy(&prefix->add.sin6, addr, (maxbits + 7) / 8);
  prefix->family = AF_INET6;
  prefix->bitlen = bits;
  prefix->ref_count = 0;

  return 0;
}

/* ******************************************* */

static patricia_node_t* add_to_ptree(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;
  patricia_node_t *node;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  node = patricia_lookup(tree, &prefix);

  return(node);
}

/* ******************************************* */

static int remove_from_ptree(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;
  patricia_node_t *node;
  int rc;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  node = patricia_lookup(tree, &prefix);

  if((patricia_node_t *)0 != node)
    rc = 0, free(node);
  else
    rc = -1;
  
  return(rc);
}

/* ******************************************* */

patricia_node_t* ptree_match(patricia_tree_t *tree, int family, void *addr, int bits) {
  prefix_t prefix;

  if(family == AF_INET)
    fill_prefix_v4(&prefix, (struct in_addr*)addr, bits, tree->maxbits);
  else
    fill_prefix_v6(&prefix, (struct in6_addr*)addr, bits, tree->maxbits);

  return(patricia_search_best(tree, &prefix));
}

/* ******************************************* */

patricia_node_t* ptree_add_rule(patricia_tree_t *ptree, char *line) {
  char *ip, *bits, *slash = NULL;
  struct in_addr addr4;
  struct in6_addr addr6;
  patricia_node_t *node = NULL;

  ip = line;
  bits = strchr(line, '/');
  if(bits == NULL)
    bits = (char*)"/32";
  else {
    slash = bits;
    slash[0] = '\0';
  }

  bits++;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Rule %s/%s", ip, bits);

  if(strchr(ip, ':') != NULL) { /* IPv6 */
    if(inet_pton(AF_INET6, ip, &addr6) == 1)
      node = add_to_ptree(ptree, AF_INET6, &addr6, atoi(bits));
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv6 %s\n", ip);
  } else { /* IPv4 */
    /* inet_aton(ip, &addr4) fails parsing subnets */
    int num_octets;
    u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
    u_char *ip4 = (u_char *) &addr4;

    if((num_octets = sscanf(ip, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3)) >= 1) {
      int num_bits = atoi(bits);

      ip4[0] = ip4_0, ip4[1] = ip4_1, ip4[2] = ip4_2, ip4[3] = ip4_3;

      if(num_bits > 32) num_bits = 32;

      if(num_octets * 8 < num_bits)
	ntop->getTrace()->traceEvent(TRACE_INFO, "Found IP smaller than netmask [%s]", line);

      //addr4.s_addr = ntohl(addr4.s_addr);
      node = add_to_ptree(ptree, AF_INET, &addr4, num_bits);
    } else {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv4 %s\n", ip);
    }
  }

  if(slash) slash[0] = '/';

  return(node);
}

/* ******************************************* */

static int ptree_remove_rule(patricia_tree_t *ptree, char *line) {
  char *ip, *bits, *slash = NULL;
  struct in_addr addr4;
  struct in6_addr addr6;
  int rc = -1;
  
  ip = line;
  bits = strchr(line, '/');
  if(bits == NULL)
    bits = (char*)"/32";
  else {
    slash = bits;
    slash[0] = '\0';
  }

  bits++;

  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Rule %s/%s", ip, bits);

  if(strchr(ip, ':') != NULL) { /* IPv6 */
    if(inet_pton(AF_INET6, ip, &addr6) == 1)
      rc = remove_from_ptree(ptree, AF_INET6, &addr6, atoi(bits));
    else
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv6 %s\n", ip);
  } else { /* IPv4 */
    /* inet_aton(ip, &addr4) fails parsing subnets */
    int num_octets;
    u_int ip4_0 = 0, ip4_1 = 0, ip4_2 = 0, ip4_3 = 0;
    u_char *ip4 = (u_char *) &addr4;

    if((num_octets = sscanf(ip, "%u.%u.%u.%u", &ip4_0, &ip4_1, &ip4_2, &ip4_3)) >= 1) {
      int num_bits = atoi(bits);

      ip4[0] = ip4_0, ip4[1] = ip4_1, ip4[2] = ip4_2, ip4[3] = ip4_3;

      if(num_bits > 32) num_bits = 32;

      if(num_octets * 8 < num_bits)
	ntop->getTrace()->traceEvent(TRACE_INFO, "Found IP smaller than netmask [%s]", line);

      //addr4.s_addr = ntohl(addr4.s_addr);
      rc = remove_from_ptree(ptree, AF_INET, &addr4, num_bits);
    } else {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error parsing IPv4 %s\n", ip);
    }
  }

  if(slash) slash[0] = '/';

  return(rc);
}

/* ******************************************* */

bool AddressTree::removeAddress(char *net) {
  return(ptree_remove_rule(ptree, net) == 1 ? false /* not found */ : true /* found */);
}

/* ******************************************* */

int16_t AddressTree::addAddress(char *_net) {
  patricia_node_t *node;
  char *net;

  if(numAddresses >= CONST_MAX_NUM_NETWORKS) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Too many networks defined: ignored %s", _net);
    return -1;
  }
  
  if((net = strdup(_net)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Not enough memory");
    return -1;
  }

  node = ptree_add_rule(ptree, net);

  if(node) {
    node->user_data = numAddresses;
    addressString.push_back(strdup(net));
    numAddresses++;
    return node->user_data;
  }

  return -1;
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
bool AddressTree::addAddresses(char *rule) {
  char *net = strtok(rule, ",");
  int16_t rc = -1;
  
  while(net != NULL) {
    if((rc = addAddress(net)) < 0) return false;
    net = strtok(NULL, ",");
  }
  return true;
}

/* ******************************************* */

int16_t AddressTree::findAddress(int family, void *addr) {
  patricia_node_t *node = ptree_match(ptree, family, addr, (family == AF_INET) ? 32 : 128);

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
