/*
 *
 * (C) 2013-19 - ntop.org
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

AddressTree::AddressTree() { init(); }

/* **************************************** */

AddressTree::AddressTree(const AddressTree &at) {
  MacKey_t *current, *tmp;

  ptree_v4 = patricia_clone(at.ptree_v4);
  ptree_v6 = patricia_clone(at.ptree_v6);

  macs = NULL;
  HASH_ITER(hh, at.macs, current, tmp) {
    MacKey_t *s;
    
    if((s = (MacKey_t*)calloc(1, sizeof(MacKey_t))) != NULL)
      memcpy(s, current, sizeof(MacKey_t));
      HASH_ADD(hh, macs, mac, 6, s);
  }

  numAddresses = at.numAddresses;
}

/* **************************************** */

static void free_ptree_data(void *data) {
  if(data) free(data);
}

/* **************************************** */

void AddressTree::init() {
  numAddresses = 0;
  ptree_v4 = New_Patricia(32), ptree_v6 = New_Patricia(128), macs = NULL;
}

/* **************************************** */

AddressTree::~AddressTree() {
  cleanup();
}

/* ******************************************* */

patricia_node_t *AddressTree::addAddress(const IpAddress * const ipa) {
  if(!ipa)
    return NULL;

  bool is_v4 = ipa->isIPv4();
  patricia_tree_t *cur_ptree = is_v4 ? ptree_v4 : ptree_v6;
  int cur_family = is_v4 ? AF_INET : AF_INET6;
  int cur_bits = is_v4 ? 32 : 128;
  void *cur_addr = is_v4 ? (void*)&ipa->getIP()->ipType.ipv4 : (void*)&ipa->getIP()->ipType.ipv6;

  return Utils::add_to_ptree(cur_ptree, cur_family, cur_addr, cur_bits);
}

/* ******************************************* */

typedef struct {
  int cur_bitlen;
  vector<prefix_t*>larger_bitlens;
} compact_tree_t;

/* ******************************************* */

static void compact_tree_funct(prefix_t *prefix, void *data, void *user_data) {
  compact_tree_t *compact = (compact_tree_t*)user_data;

  if(!prefix) return;

  if(prefix->bitlen > compact->cur_bitlen)
    compact->larger_bitlens.push_back(prefix);
}

/* **************************************************** */

patricia_node_t *AddressTree::addAddress(const IpAddress * const ipa, int network_bits, bool compact_after_add) {
  if(!ipa)
    return NULL;

  bool is_v4 = ipa->isIPv4();
  patricia_node_t *res;
  patricia_tree_t *cur_ptree = is_v4 ? ptree_v4 : ptree_v6;
  int cur_family = is_v4 ? AF_INET : AF_INET6;
  int cur_bits = network_bits;

  if(network_bits < 0) network_bits = 0;
  else if(is_v4 && network_bits > 32) network_bits = 32;
  else if(!is_v4 && network_bits > 128) network_bits = 128;

  void *cur_addr = is_v4 ? (void*)&ipa->getIP()->ipType.ipv4 : (void*)&ipa->getIP()->ipType.ipv6;

  res = Utils::ptree_match(cur_ptree, cur_family, cur_addr, cur_bits);

  if(!res)
    res = Utils::add_to_ptree(cur_ptree, cur_family, cur_addr, cur_bits);

  if(compact_after_add && res) {
    compact_tree_t compact;
    compact.cur_bitlen = network_bits;

    /* navigate this subtree */
    patricia_walk_inorder(res, compact_tree_funct, &compact);

    for (std::vector<prefix_t*>::const_iterator it = compact.larger_bitlens.begin(); it != compact.larger_bitlens.end(); ++it) {
      patricia_node_t *compacted = patricia_search_exact(cur_ptree, *it);
      assert(compacted);
      patricia_remove(cur_ptree, compacted);
    }
  }


  return res;
}

/* ******************************************* */

bool AddressTree::addAddress(char *_what, const int16_t user_data) {
  u_int32_t _mac[6];
  int16_t id = (user_data == -1) ? numAddresses : user_data;
  
  if(sscanf(_what, "%02X:%02X:%02X:%02X:%02X:%02X",
	    &_mac[0], &_mac[1], &_mac[2],
	    &_mac[3], &_mac[4], &_mac[5]) == 6) {
    int16_t v;
    u_int8_t mac[6];

    for(int i=0; i<6; i++) mac[i] = (u_int8_t)_mac[i];

    if((v = findMac(mac)) == -1) {
      /* Not found: let's add it */
      MacKey_t *s;

      if((s = (MacKey_t*)malloc(sizeof(MacKey_t))) != NULL) {
	memcpy(s->mac, mac, 6), s->value = id;
	HASH_ADD(hh, macs, mac, 6, s);
      } else
	return(false);
    }
  } else {
    patricia_node_t *node = Utils::ptree_add_rule(strchr(_what, '.') ? ptree_v4 : ptree_v6, _what);

    if(node)
      node->user_data = id;
  }

  numAddresses++;
  
  return(true);
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
bool AddressTree::addAddresses(char *rule, const int16_t user_data) {
  char *tmp, *net = strtok_r(rule, ",", &tmp);
  
  while(net != NULL) {
    if(!addAddress(net, user_data))
      return false;
    
    net = strtok_r(NULL, ",", &tmp);
  }
  
  return true;
}

/* ******************************************* */

// TODO match MAC
bool AddressTree::match(char *addr) {
  IpAddress address;
  char *net_prefix = strchr(addr, '/');

  if(net_prefix) {
    int bits = atoi(net_prefix + 1);
    char tmp = *net_prefix;
    *net_prefix = '\0', address.set(addr), *net_prefix = tmp;

    if(address.isIPv4())
      return Utils::ptree_match(ptree_v4, AF_INET, &address.getIP()->ipType.ipv4, bits);
    else
      return Utils::ptree_match(ptree_v6, AF_INET6, (void*)&address.getIP()->ipType.ipv6, bits);
  } else {
    address.set(addr);
    return address.match(this);
  }
}

/* ******************************************* */

int16_t AddressTree::findAddress(int family, void *addr, u_int8_t *network_mask_bits) {
  patricia_tree_t *p;
  int bits;
  patricia_node_t *node;
  
  if(family == AF_INET)
    p = ptree_v4, bits = 32;
  else if(family == AF_INET6)
    p = ptree_v6, bits = 128;
  else
    return(-1);
    
  node = Utils::ptree_match(p, family, addr, bits);
  
  if(node == NULL)
    return(-1);
  else {
    if(network_mask_bits)
      *network_mask_bits = node->bit;
    return(node->user_data);
  }
}

/* ******************************************* */

int16_t AddressTree::findMac(u_int8_t addr[]) {
  MacKey_t *s = NULL;

  HASH_FIND(hh, macs, addr, 6, s);

  return(s ? s->value : -1);
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
  }

  if(user_data)
    lua_push_str_table_entry((lua_State*)user_data, ret, (char*)"");
  else
    ntop->getTrace()->traceEvent(TRACE_INFO, "[AddressTree] %s", ret);
}

/* **************************************************** */

void AddressTree::getAddresses(lua_State* vm) {
  if(ptree_v4->head)  patricia_walk_inorder(ptree_v4->head, address_tree_dump_funct, vm);
  if(ptree_v6->head)  patricia_walk_inorder(ptree_v6->head, address_tree_dump_funct, vm);

  if(macs) {
    MacKey_t *current, *tmp;

    HASH_ITER(hh, macs, current, tmp) {
      char key[32], val[8];

      snprintf(key, sizeof(key), "%02X:%02X:%02X:%02X:%02X:%02X",
	       current->mac[0], current->mac[1], current->mac[2],
	       current->mac[3], current->mac[4], current->mac[5]);

      snprintf(val, sizeof(val), "%u", current->value);

      lua_push_str_table_entry(vm, key, val);
    }
  }
}
/* **************************************************** */

void AddressTree::walk(void_fn3_t func, void * const user_data) const {
  if(ptree_v4->head)  patricia_walk_inorder(ptree_v4->head, func, user_data);
  if(ptree_v6->head)  patricia_walk_inorder(ptree_v6->head, func, user_data);
}

/* **************************************************** */

void AddressTree::dump() {
  if(ptree_v4->head)  patricia_walk_inorder(ptree_v4->head, address_tree_dump_funct, NULL);
  if(ptree_v6->head)  patricia_walk_inorder(ptree_v6->head, address_tree_dump_funct, NULL);

    if(macs) {
    MacKey_t *current, *tmp;

    HASH_ITER(hh, macs, current, tmp) {
      char key[32];

      snprintf(key, sizeof(key), "%02X:%02X:%02X:%02X:%02X:%02X",
	       current->mac[0], current->mac[1], current->mac[2],
	       current->mac[3], current->mac[4], current->mac[5]);

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[AddressTree] %s", key);
    }
  }
}

/* **************************************************** */

void AddressTree::cleanup() {
  if(ptree_v4)  Destroy_Patricia(ptree_v4, free_ptree_data);
  if(ptree_v6)  Destroy_Patricia(ptree_v6, free_ptree_data);

  if(macs) {
    MacKey_t *current, *tmp;
    
    HASH_ITER(hh, macs, current, tmp) {
      HASH_DEL(macs, current);  /* delete it */
      free(current);         /* free it */
    }
  }  
}
