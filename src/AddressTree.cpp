/*
 *
 * (C) 2013-21 - ntop.org
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

/* **************************************** */

AddressTree::AddressTree(bool handleIPv6) { init(handleIPv6); }

/* **************************************** */

AddressTree::AddressTree(const AddressTree &at) {
  ptree_v4 = ndpi_patricia_clone(at.ptree_v4);

  if(at.ptree_v6)
    ptree_v6 = ndpi_patricia_clone(at.ptree_v6);
  else
    ptree_v6 = NULL;
  
  macs = at.macs;
  numAddresses = at.numAddresses;
  numAddressesIPv4 = at.numAddressesIPv4;
  numAddressesIPv6 = at.numAddressesIPv6;
}

/* **************************************** */

static void free_ptree_data(void *data) {
  if(data) free(data);
}

/* **************************************** */

void AddressTree::init(bool handleIPv6) {
  numAddresses = numAddressesIPv4 = numAddressesIPv6 = 0;
  ptree_v4 = ndpi_patricia_new(32), macs.clear();

  if(handleIPv6)
    ptree_v6 = ndpi_patricia_new(128);
  else
    ptree_v6 = NULL;
}

/* **************************************** */

AddressTree::~AddressTree() {
  cleanup();
}

/* ******************************************* */

ndpi_patricia_node_t *AddressTree::addAddress(const IpAddress * const ipa) {
  if(!ipa)
    return NULL;

  bool is_v4 = ipa->isIPv4();

  if((!is_v4) && (!ptree_v6))
    return(NULL);
  else {
    ndpi_patricia_tree_t *cur_ptree = is_v4 ? ptree_v4 : ptree_v6;
    int cur_family = is_v4 ? AF_INET : AF_INET6;
    int cur_bits = is_v4 ? 32 : 128;
    void *cur_addr = is_v4 ? (void*)&ipa->getIP()->ipType.ipv4 : (void*)&ipa->getIP()->ipType.ipv6;
    ndpi_patricia_node_t *res;

    res = Utils::ptree_match(cur_ptree, cur_family, cur_addr, cur_bits);

    if(!res) {
      res = Utils::add_to_ptree(cur_ptree, cur_family, cur_addr, cur_bits);

      if(res) {
	numAddresses++;
	if(is_v4)
	  numAddressesIPv4++;
	else
	  numAddressesIPv6++;
      }
    }

    return res;
  }
}

/* ******************************************* */

typedef struct {
  int cur_bitlen;
  vector<ndpi_prefix_t*>larger_bitlens;
} compact_tree_t;

/* ******************************************* */

static void compact_tree_funct(ndpi_patricia_node_t *node, void *data, void *user_data) {
  ndpi_prefix_t *prefix;
  compact_tree_t *compact = (compact_tree_t*)user_data;

  if(!node || !(prefix = ndpi_patricia_get_node_prefix(node)))
    return;

  if(prefix->bitlen > compact->cur_bitlen)
    compact->larger_bitlens.push_back(prefix);
}

/* **************************************************** */

ndpi_patricia_node_t *AddressTree::addAddress(const IpAddress * const ipa,
					 int network_bits, bool compact_after_add) {
  if(!ipa)
    return NULL;

  bool is_v4 = ipa->isIPv4();
  if((!is_v4) && (!ptree_v6))
    return(NULL);
  else {
    ndpi_patricia_node_t *res;
    ndpi_patricia_tree_t *cur_ptree = is_v4 ? ptree_v4 : ptree_v6;
    int cur_family = is_v4 ? AF_INET : AF_INET6;
    int cur_bits = network_bits;

    if(network_bits < 0) network_bits = 0;
    else if(is_v4 && network_bits > 32) network_bits = 32;
    else if(!is_v4 && network_bits > 128) network_bits = 128;

    void *cur_addr = is_v4 ? (void*)&ipa->getIP()->ipType.ipv4 : (void*)&ipa->getIP()->ipType.ipv6;

    res = Utils::ptree_match(cur_ptree, cur_family, cur_addr, cur_bits);

    if(!res) {
      res = Utils::add_to_ptree(cur_ptree, cur_family, cur_addr, cur_bits);

      if(compact_after_add && res) {
	compact_tree_t compact;
	compact.cur_bitlen = network_bits;

	/* navigate this subtree */
	ndpi_patricia_walk_inorder(res, compact_tree_funct, &compact);

	for(std::vector<ndpi_prefix_t*>::const_iterator it = compact.larger_bitlens.begin();
	    it != compact.larger_bitlens.end(); ++it)
	  removePrefix(is_v4, *it);
      }
    }

    return res;
  }
}

/* ******************************************* */

bool AddressTree::addAddressAndData(const char * const _what, void *user_data) {
  ndpi_patricia_node_t *node = Utils::ptree_add_rule(strchr(_what, '.') ? ptree_v4 : ptree_v6, _what);

  if(node)
    ndpi_patricia_set_node_data(node, user_data);
  else
    return(false);

  numAddresses++;

  return(true);
}

/* ******************************************* */

bool AddressTree::addAddress(const char * const _what, const int16_t user_data) {
  u_int32_t _mac[6];
  int16_t id = (user_data == -1) ? numAddresses : user_data;
  
  if(sscanf(_what, "%02X:%02X:%02X:%02X:%02X:%02X",
	    &_mac[0], &_mac[1], &_mac[2],
	    &_mac[3], &_mac[4], &_mac[5]) == 6) {
    u_int8_t mac[6];
    u_int64_t mac_num;

    for(int i=0; i<6; i++) mac[i] = (u_int8_t)_mac[i];

    mac_num = Utils::mac2int(mac);
    macs[mac_num] = id;
  } else {
    ndpi_patricia_node_t *node = Utils::ptree_add_rule(strchr(_what, '.') ? ptree_v4 : ptree_v6, _what);

    if(node)
      ndpi_patricia_set_node_u64(node, id);
    else
      return(false);
  }

  numAddresses++;
  
  return(true);
}

/* ******************************************* */

/* Format: 131.114.21.0/24,10.0.0.0/255.0.0.0 */
bool AddressTree::addAddresses(const char *rule, const int16_t user_data) {
  char *tmp, *net;
  char * _rule = strdup(rule);

  if(!_rule)
    return false;

  net = strtok_r(_rule, ",", &tmp);
  
  while(net != NULL) {
    addAddress(net, user_data);
    net = strtok_r(NULL, ",", &tmp);
  }

  free(_rule);
  return true;
}

/* ******************************************* */

// TODO match MAC
ndpi_patricia_node_t *AddressTree::matchAndGetNode(const char * const addr) {
  ndpi_patricia_node_t *node = NULL;
  char addr_cpy[48];
  IpAddress address;
  char *net_prefix;
  int bits;
 
  strncpy(addr_cpy, addr, sizeof(addr_cpy));

  net_prefix = strchr(addr_cpy, '/');
  if(net_prefix) {
    *net_prefix = '\0';
    address.set(addr_cpy);
    bits = atoi(net_prefix + 1);
  } else {
    address.set(addr);
    bits = address.isIPv4() ? 32 : 128;
  }

  if(address.isIPv4())
    node = Utils::ptree_match(ptree_v4, AF_INET, &address.getIP()->ipType.ipv4, bits);
  else
    node = Utils::ptree_match(ptree_v6, AF_INET6, (void*)&address.getIP()->ipType.ipv6, bits);

  return node;
}

/* ******************************************* */

void *AddressTree::matchAndGetData(const char * const addr) {
  ndpi_patricia_node_t *node = matchAndGetNode(addr);
  if (node) return ndpi_patricia_get_node_data(node);
  else return NULL;
}

/* ******************************************* */

bool AddressTree::match(char *addr) {
  return !!matchAndGetNode(addr);
}

/* ******************************************* */

ndpi_patricia_node_t* AddressTree::match(const IpAddress * const ipa, int network_bits) const {
  if(!ipa)
    return(NULL);

  bool is_v4 = ipa->isIPv4();
  if(!is_v4 && !ptree_v6)
    return(NULL);

  if(is_v4)
    return Utils::ptree_match(ptree_v4, AF_INET, &ipa->getIP()->ipType.ipv4, network_bits);
  else
    return Utils::ptree_match(ptree_v6, AF_INET6, &ipa->getIP()->ipType.ipv6, network_bits);
}

/* ******************************************* */

void *AddressTree::matchAndGetData(const IpAddress * const ipa) const {
  ndpi_patricia_node_t *node = match(ipa, ipa->isIPv4() ? 32 : 128);
  if (node) return ndpi_patricia_get_node_data(node);
  else return NULL;
}

/* ******************************************* */

/* NOTE: this does NOT accept a char* address! Use AddressTree::find() instead. */
int16_t AddressTree::findAddress(int family, void *addr, u_int8_t *network_mask_bits) {
  ndpi_patricia_tree_t *p;
  int bits;
  ndpi_patricia_node_t *node;
  
  if(family == AF_INET)
    p = ptree_v4, bits = 32;
  else if(family == AF_INET6)
    p = ptree_v6, bits = 128;
  else
    return(-1);

  if(p == NULL) return(-1);
  
  node = Utils::ptree_match(p, family, addr, bits);
  
  if(node == NULL)
    return(-1);
  else {
    if(network_mask_bits)
      *network_mask_bits = ndpi_patricia_get_node_bits(node);
    return(ndpi_patricia_get_node_u64(node));
  }
}

/* ******************************************* */

int16_t AddressTree::findMac(const u_int8_t addr[]) {
  std::map<u_int64_t, int16_t>::iterator it;
  u_int64_t mac_num = Utils::mac2int((u_int8_t *)addr);

  it = macs.find(mac_num);
  if(it != macs.end())
    return(it->second);

  return(-1);
}

/* **************************************************** */

/* Generic find with IPv4/IPv6/Mac */
int16_t AddressTree::find(const char *addr, u_int8_t *network_mask_bits) {
  u_int8_t mac[6];
  u_int32_t _mac[6];

  if(strchr(addr, '.')) {
    /* IPv4 */
    struct in_addr addr4;

    if(inet_pton(AF_INET, addr, &addr4) != 1)
      return(-1);

    return(findAddress(AF_INET, &addr4, network_mask_bits));
  } else if(sscanf(addr, "%02X:%02X:%02X:%02X:%02X:%02X",
	    &_mac[0], &_mac[1], &_mac[2], &_mac[3], &_mac[4], &_mac[5]) == 6) {
    /* MAC address */
    for(int i=0; i<6; i++) mac[i] = _mac[i];

    return(findMac(mac));
  } else {
    /* IPv6 */
    struct in6_addr addr6;

    if(inet_pton(AF_INET6, addr, &addr6) != 1)
      return(-1);

    return(findAddress(AF_INET6, &addr6, network_mask_bits));
  }
}

/* **************************************************** */

static void address_tree_dump_funct(ndpi_patricia_node_t * node, void *data, void *user_data) {
  char address[128];
  ndpi_prefix_t *prefix;

  if(!node || !(prefix = ndpi_patricia_get_node_prefix(node)))
    return;

  if(!Utils::ptree_prefix_print(prefix, address, sizeof(address)))
    return;

  if(user_data)
    lua_push_uint64_table_entry((lua_State*)user_data, address, ndpi_patricia_get_node_u64(node));
  else
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[AddressTree] %s", address);
}

/* **************************************************** */

void AddressTree::getAddresses(lua_State* vm) const {
  std::map<u_int64_t, int16_t>::const_iterator it;

  ndpi_patricia_walk_tree_inorder(ptree_v4, address_tree_dump_funct, vm);

  if(ptree_v6)
    ndpi_patricia_walk_tree_inorder(ptree_v6, address_tree_dump_funct, vm);

  for(it = macs.begin(); it != macs.end(); ++it) {
    char key[32], val[8];
    u_int8_t *mac = (u_int8_t*)&it->first;

    snprintf(key, sizeof(key), "%02X:%02X:%02X:%02X:%02X:%02X",
       mac[0], mac[1], mac[2],
       mac[3], mac[4], mac[5]);

    snprintf(val, sizeof(val), "%u", it->second);

    lua_push_str_table_entry(vm, key, val);
  }
}
/* **************************************************** */

void AddressTree::removePrefix(bool isV4, ndpi_prefix_t* prefix) {
  if(removePrefix(getTree(isV4), prefix)) {
    numAddresses--;

    if(isV4)
      numAddressesIPv4--;
    else
      numAddressesIPv6--;
  }
}

/* **************************************************** */

bool AddressTree::removePrefix(ndpi_patricia_tree_t *ptree, ndpi_prefix_t* prefix) {
  if(!ptree || !prefix)
    return false;

  ndpi_patricia_node_t *candidate = ndpi_patricia_search_exact(ptree, prefix);

  if(!candidate)
    return false;

  ndpi_patricia_remove(ptree, candidate);
  return true;
}

/* **************************************************** */

void AddressTree::walk(ndpi_patricia_tree_t *ptree, ndpi_void_fn3_t func, void * const user_data) {
  if(ptree)
    ndpi_patricia_walk_tree_inorder(ptree, func, user_data);
}


/* **************************************************** */

void AddressTree::walk(ndpi_void_fn3_t func, void * const user_data) const {
  walk(ptree_v4, func, user_data);
  walk(ptree_v6, func, user_data);
}

/* **************************************************** */

void AddressTree::dump() {
  std::map<u_int64_t, int16_t>::iterator it;

  ndpi_patricia_walk_tree_inorder(ptree_v4, address_tree_dump_funct, NULL);
  
  if(ptree_v6)
    ndpi_patricia_walk_tree_inorder(ptree_v6, address_tree_dump_funct, NULL);

  for(it = macs.begin(); it != macs.end(); ++it) {
    char key[32];
    u_int8_t *mac = (u_int8_t*)&it->first;
    
    snprintf(key, sizeof(key), "%02X:%02X:%02X:%02X:%02X:%02X",
       mac[0], mac[1], mac[2],
       mac[3], mac[4], mac[5]);

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "[AddressTree] %s", key);
  }
}

/* **************************************************** */

void AddressTree::cleanup(ndpi_void_fn_t free_func) {
  if(ptree_v4) {
    ndpi_patricia_destroy(ptree_v4, free_func);
    ptree_v4 = NULL;
  }

  if(ptree_v6) {
    ndpi_patricia_destroy(ptree_v6, free_func);
    ptree_v6 = NULL;
  }

  macs.clear();
}

/* **************************************************** */

void AddressTree::cleanup() {
  cleanup(free_ptree_data);
}

/* **************************************************** */
