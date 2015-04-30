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

#ifndef _ADDRESS_RESOLUTION_H_
#define _ADDRESS_RESOLUTION_H_

#include "ntop_includes.h"

class AddressResolution {
  u_int32_t num_resolved_addresses, num_resolved_fails;
  pthread_t resolveThreadLoop;
  patricia_tree_t *ptree;
  char *local_networks[CONST_MAX_NUM_NETWORKS];
  u_int8_t num_local_networks;
  Mutex m;

 public:
  AddressResolution();
  ~AddressResolution();

  void startResolveAddressLoop();
  void resolveHostName(char *numeric_ip, char *rsp = NULL, u_int rsp_len = 0);

  inline u_int8_t get_num_local_networks()     { return(num_local_networks); };
  inline char *get_local_network(u_int8_t id) { return((id < num_local_networks) ? local_networks[id] : NULL); };
  void setLocalNetworks(char *rule);
  int16_t findAddress(int family, void *addr); /* if(rc > 0) networdId else notfound */
  void addLocalNetwork(char *net);
};

extern patricia_node_t* ptree_add_rule(patricia_tree_t *ptree, char *line);
extern patricia_node_t* ptree_match(patricia_tree_t *tree, int family, void *addr, int bits);
extern void free_ptree_data(void *data);

#endif /* _ADDRESS_RESOLUTION_H_ */
