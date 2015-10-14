/*
 *
 * (C) 2013-15 - ntop.org
 *
 *
 * This program is free software; you can addresstribute it and/or modify
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

#ifndef _ADDRESS_TREE_H_
#define _ADDRESS_TREE_H_

#include "ntop_includes.h"

class AddressTree {
  int numNetworks;
  patricia_tree_t *ptree;

  bool addNetwork(char *_net, int16_t networkId);
  
 public:
  AddressTree();
  ~AddressTree();

  inline u_int8_t getNumNetworks()     { return(numNetworks); };
  bool addNetworks(char *net, int16_t networkId);
  bool removeNetwork(char *net);
  int16_t findAddress(int family, void *addr); /* if(rc > 0) networdId else notfound */
  void getNetworks(lua_State* vm);
};

extern patricia_node_t* ptree_add_rule(patricia_tree_t *ptree, char *line);
extern patricia_node_t* ptree_match(patricia_tree_t *tree, int family, void *addr, int bits);
extern void free_ptree_data(void *data);

#endif /* _ADDRESS_TREE_H_ */
