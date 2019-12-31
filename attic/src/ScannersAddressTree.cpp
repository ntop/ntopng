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

/* **************************************** */

ScannersAddressTree::ScannersAddressTree() : AddressTree(true) {
}

/* **************************************** */

ScannersAddressTree::ScannersAddressTree(const ScannersAddressTree &at) : AddressTree(at) {
}

/* **************************************** */

ScannersAddressTree::~ScannersAddressTree() {
}

/* ******************************************* */

typedef struct {
  vector< pair<u_int32_t, prefix_t*> >weight_prefix;
} prune_tree_t;

/* ******************************************* */

static void node_data_to_weights_vector(patricia_node_t *node, void *data, void *user_data) {
  prefix_t *prefix;
  prune_tree_t *prune;

  if(!node || !data || !(prune = (prune_tree_t*)user_data) || !(prefix = node->prefix))
    return;

  prune->weight_prefix.push_back(make_pair(((scanner_node_data_t*)data)->weight, prefix));
}

/* **************************************** */

void ScannersAddressTree::prune(bool ip_v4) {
  patricia_tree_t *cur_ptree = getTree(ip_v4);
  prune_tree_t prune_tree;
  vector< pair<u_int32_t, prefix_t*> >::const_iterator it;

  /* Let's check if the number of addresses is above the high watermark */
  if((ip_v4 && getNumAddressesIPv4() < SCANNERS_ADDRESS_TREE_HIGH_WATERMARK)
     || (!ip_v4 && getNumAddressesIPv6() < SCANNERS_ADDRESS_TREE_HIGH_WATERMARK))
    return;

  /* If above the watermark, addresses are removed according to their weight
     so that until the low watermark is reached. */
  walk(cur_ptree, node_data_to_weights_vector, &prune_tree);
  sort(prune_tree.weight_prefix.rbegin(), prune_tree.weight_prefix.rend());

  it = prune_tree.weight_prefix.begin();
  /* Skip the first elements, that is, those with the highest weights */
  advance(it, SCANNERS_ADDRESS_TREE_LOW_WATERMARK - 1);

#if SCANNERS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[before pruning]");
  dump();
#endif
  
  /* Remove all the others */
  for(; it != prune_tree.weight_prefix.end(); ++it)
    removePrefix(ip_v4, it->second);

#if SCANNERS_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "[after pruning]");
  dump();
#endif
}

/* **************************************** */

void ScannersAddressTree::incHits(const IpAddress *ipa, u_int weight) {
  scanner_node_data_t *node_data;
  patricia_node_t* node = addAddress(ipa);

  prune(ipa->isIPv4());

  if(!node)
    return;

  if(!node->data && !(node->data = calloc(1, sizeof(scanner_node_data_t))))
    return;

  node_data = (scanner_node_data_t*)node->data;
  node_data->weight += weight;

#if SCANNERS_DEBUG
  char buf[64];

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Updated node [%s][weight: %u]", ipa->print(buf, sizeof(buf)), node_data->weight);
#endif
}

/* **************************************** */

static void get_scanners_walker(patricia_node_t *node, void *data, void *user_data) {
  char address[128];
  lua_State *vm = (lua_State*)user_data;
  scanner_node_data_t *scanner_node_data = NULL;

  if((!node->prefix) || !Utils::ptree_prefix_print(node->prefix, address, sizeof(address)))
    return;

  if(node->data)
    scanner_node_data = (scanner_node_data_t*)node->data;

  lua_newtable(vm);
  lua_push_uint64_table_entry(vm, "hits", scanner_node_data ? scanner_node_data->weight : 0);

  lua_pushstring(vm, address);
  lua_insert(vm, -2);
  lua_settable(vm, -3);

}

/* **************************************** */

void ScannersAddressTree::getScanners(lua_State *vm) {
  walk(get_scanners_walker, vm);
}
